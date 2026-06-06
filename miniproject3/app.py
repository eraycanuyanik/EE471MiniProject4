import os
import base64
import threading
from io import BytesIO

from flask import Flask, render_template, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from huggingface_hub import InferenceClient

load_dotenv()

HF_TOKEN = os.getenv("HF_TOKEN")
IMAGE_MODEL = os.getenv("IMAGE_MODEL", "black-forest-labs/FLUX.1-schnell")
TEXT_MODEL = os.getenv("TEXT_MODEL", "HuggingFaceTB/SmolLM2-360M-Instruct")
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "5000"))

app = Flask(__name__)
CORS(app)

image_client = InferenceClient(token=HF_TOKEN) if HF_TOKEN else None

SYSTEM_PROMPT = (
    "You are RoboMunch, an artist chatbot inspired by Edvard Munch. "
    "You help users craft vivid, imaginative prompts for digital art and "
    "discuss art in a friendly, concise way. Keep replies short."
)

_chat_pipe = None
_chat_lock = threading.Lock()


def get_chat_pipe():
    global _chat_pipe
    if _chat_pipe is not None:
        return _chat_pipe
    with _chat_lock:
        if _chat_pipe is None:
            from transformers import pipeline
            _chat_pipe = pipeline(
                "text-generation",
                model=TEXT_MODEL,
                token=HF_TOKEN,
                device_map="cpu",
                torch_dtype="auto",
            )
    return _chat_pipe


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "backend-server-1"})


@app.route("/api/generate-image", methods=["POST"])
def generate_image():
    data = request.get_json(silent=True) or {}
    prompt = (data.get("prompt") or "").strip()
    if not prompt:
        return jsonify({"error": "Prompt is empty."}), 400
    if not image_client:
        return jsonify({"error": "HF_TOKEN missing. Set it in .env"}), 500
    try:
        image = image_client.text_to_image(prompt, model=IMAGE_MODEL)
        buf = BytesIO()
        image.save(buf, format="PNG")
        b64 = base64.b64encode(buf.getvalue()).decode("ascii")
        return jsonify({"image": f"data:image/png;base64,{b64}"})
    except Exception as exc:
        app.logger.exception("image generation failed")
        return jsonify({"error": f"{type(exc).__name__}: {exc}"}), 500


@app.route("/api/chat", methods=["POST"])
def chat():
    data = request.get_json(silent=True) or {}
    history = data.get("history") or []
    user_msg = (data.get("message") or "").strip()
    if not user_msg:
        return jsonify({"error": "Message is empty."}), 400

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    for turn in history[-8:]:
        role = turn.get("role")
        content = turn.get("content", "")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": user_msg})

    try:
        pipe = get_chat_pipe()
        out = pipe(
            messages,
            max_new_tokens=160,
            do_sample=True,
            temperature=0.7,
            top_p=0.9,
        )
        gen = out[0]["generated_text"]
        if isinstance(gen, list):
            last = gen[-1]
            reply = last["content"] if isinstance(last, dict) else str(last)
        else:
            reply = str(gen)
        reply = reply.strip() or "(no reply)"
        return jsonify({"reply": reply})
    except Exception as exc:
        app.logger.exception("chat failed")
        return jsonify({"error": f"{type(exc).__name__}: {exc}"}), 500


if __name__ == "__main__":
    app.run(host=HOST, port=PORT, debug=True)
