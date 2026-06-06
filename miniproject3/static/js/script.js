(() => {
    const promptInput = document.getElementById("promptInput");
    const paintBtn    = document.getElementById("paintBtn");
    const imageOutput = document.getElementById("imageOutput");

    const chatInput   = document.getElementById("chatInput");
    const sendBtn     = document.getElementById("sendBtn");
    const micBtn      = document.getElementById("micBtn");
    const chatOutput  = document.getElementById("chatOutput");

    const history = [];   // [{role: "user"|"assistant", content: ""}]

    // ---------------- helpers ----------------
    function setEmptyChatHint() {
        if (chatOutput.children.length === 0) {
            const hint = document.createElement("div");
            hint.className = "empty";
            hint.textContent = "Say hi to RoboMunch...";
            hint.dataset.empty = "1";
            chatOutput.appendChild(hint);
        }
    }
    function clearEmptyHint() {
        const hint = chatOutput.querySelector("[data-empty]");
        if (hint) hint.remove();
    }
    function appendTurn(role, text) {
        clearEmptyHint();
        const div = document.createElement("div");
        div.className = "turn " + (role === "user" ? "user" : "bot");
        const who = document.createElement("span");
        who.className = "who";
        who.textContent = role === "user" ? "YOU:" : "MUNCH:";
        const body = document.createElement("span");
        body.textContent = " " + text;
        div.appendChild(who);
        div.appendChild(body);
        chatOutput.appendChild(div);
        chatOutput.scrollTop = chatOutput.scrollHeight;
    }
    function showError(msg) {
        const banner = document.createElement("div");
        banner.className = "error-banner";
        banner.textContent = msg;
        chatOutput.appendChild(banner);
        chatOutput.scrollTop = chatOutput.scrollHeight;
        setTimeout(() => banner.remove(), 6000);
    }

    setEmptyChatHint();

    // ---------------- paint flow ----------------
    async function paint() {
        const prompt = promptInput.value.trim();
        if (!prompt) {
            promptInput.focus();
            return;
        }
        paintBtn.disabled = true;
        imageOutput.classList.add("loading");
        imageOutput.innerHTML = "";

        try {
            const res = await fetch("/api/generate-image", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ prompt }),
            });
            const text = await res.text();
            let data = {};
            try { data = JSON.parse(text); } catch (_) { /* not json */ }
            if (!res.ok) throw new Error(data.error || `HTTP ${res.status}: ${text.slice(0, 200)}`);
            imageOutput.classList.remove("loading");
            const img = document.createElement("img");
            img.src = data.image;
            img.alt = prompt;
            imageOutput.innerHTML = "";
            imageOutput.appendChild(img);
        } catch (err) {
            imageOutput.classList.remove("loading");
            const ph = document.createElement("div");
            ph.className = "placeholder";
            ph.textContent = "Could not paint: " + err.message;
            imageOutput.appendChild(ph);
        } finally {
            paintBtn.disabled = false;
        }
    }
    paintBtn.addEventListener("click", paint);
    promptInput.addEventListener("keydown", (e) => {
        if (e.key === "Enter") { e.preventDefault(); paint(); }
    });

    // ---------------- chat flow ----------------
    async function send() {
        const message = chatInput.value.trim();
        if (!message) return;
        appendTurn("user", message);
        history.push({ role: "user", content: message });
        chatInput.value = "";
        sendBtn.disabled = true;

        try {
            const res = await fetch("/api/chat", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ message, history: history.slice(0, -1) }),
            });
            const text = await res.text();
            let data = {};
            try { data = JSON.parse(text); } catch (_) { /* not json */ }
            if (!res.ok) throw new Error(data.error || `HTTP ${res.status}: ${text.slice(0, 200)}`);
            appendTurn("bot", data.reply);
            history.push({ role: "assistant", content: data.reply });
        } catch (err) {
            showError(err.message);
        } finally {
            sendBtn.disabled = false;
            chatInput.focus();
        }
    }
    sendBtn.addEventListener("click", send);
    chatInput.addEventListener("keydown", (e) => {
        if (e.key === "Enter") { e.preventDefault(); send(); }
    });

    // ---------------- voice input (Web Speech API) ----------------
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    let recognizer = null;
    let recording = false;

    function initRecognizer() {
        if (!SR) return null;
        const r = new SR();
        r.lang = "en-US";
        r.interimResults = true;
        r.continuous = false;

        r.onresult = (event) => {
            let transcript = "";
            for (let i = event.resultIndex; i < event.results.length; i++) {
                transcript += event.results[i][0].transcript;
            }
            chatInput.value = transcript;
        };
        r.onerror = (e) => {
            showError("Voice error: " + (e.error || "unknown"));
            stopRecording();
        };
        r.onend = () => stopRecording();
        return r;
    }
    function startRecording() {
        if (!SR) {
            showError("Speech recognition is not supported in this browser. Try Chrome.");
            return;
        }
        recognizer = recognizer || initRecognizer();
        try {
            recognizer.start();
            recording = true;
            micBtn.classList.add("recording");
        } catch (_) {/* already started */}
    }
    function stopRecording() {
        recording = false;
        micBtn.classList.remove("recording");
        if (recognizer) {
            try { recognizer.stop(); } catch (_) {}
        }
    }
    micBtn.addEventListener("click", () => {
        if (recording) stopRecording();
        else startRecording();
    });
})();
