import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'config.dart';
import 'models/chat_turn.dart';
import 'services/cloud_backend.dart';
import 'services/local_backend.dart';
import 'widgets/settings_dialog.dart';

void main() => runApp(const RoboMunchApp());

// ---------------------------------------------------------------------------
// Theme tokens (mirror miniproject3/static/css/style.css so the mobile app
// looks identical to the web frontend the user already designed for Project #3)
// ---------------------------------------------------------------------------
class T {
  static const Color cream    = Color(0xFFF7ECDC);
  static const Color creamDim = Color(0xFFE9D4B1);
  static const Color orange   = Color(0xFFD99A4E);

  // The shared dark-brown gradient used by all three cards in the web app.
  static const LinearGradient cardGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF672E10),
      Color(0xFF5B2D14),
      Color(0xFF46291A),
      Color(0xFF322013),
      Color(0xFF28180D),
    ],
    stops: [0.0, 0.28, 0.60, 0.88, 1.0],
  );

  // Body background (web).
  static const LinearGradient bodyGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0C0603),
      Color(0xFF3D2111),
      Color(0xFF753A1D),
      Color(0xFF8A5B3D),
      Color(0xFF6E4127),
      Color(0xFFB89D8B),
    ],
    stops: [0.0, 0.12, 0.28, 0.55, 0.80, 1.0],
  );

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x99000000),
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
  ];
}

class RoboMunchApp extends StatelessWidget {
  const RoboMunchApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "RoboMunch",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: const TextTheme().apply(
          fontFamily: "Georgia",
          bodyColor: T.cream,
          displayColor: T.cream,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintStyle: TextStyle(
            color: T.creamDim,
            fontFamily: "Georgia",
            fontSize: 17,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _promptCtrl = TextEditingController();
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  late LocalBackend _local = LocalBackend(baseUrl: AppConfig.defaultLocalhostBackend);
  late CloudBackend _cloud = CloudBackend(baseUrl: AppConfig.defaultCloudBackend);

  final List<ChatTurn> _history = [];

  String? _imageDataUrl;
  Uint8List? _imageBytes;
  String? _resolutionLabel;

  bool _isPainting = false;
  bool _isChatting = false;
  bool _isColorizing = false;
  bool _isFetchingRes = false;
  bool _isListening = false;
  bool _speechReady = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initSpeech();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _local = LocalBackend(
        baseUrl: p.getString("local_url") ?? AppConfig.defaultLocalhostBackend,
      );
      _cloud = CloudBackend(
        baseUrl: p.getString("cloud_url") ?? AppConfig.defaultCloudBackend,
      );
    });
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onStatus: (s) => debugPrint("speech status: $s"),
      onError: (e) => debugPrint("speech error: $e"),
    );
    if (mounted) setState(() => _speechReady = ok);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: error ? Colors.red.shade900 : Colors.brown.shade800,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Uint8List _decodeDataUrl(String dataUrl) {
    final i = dataUrl.indexOf(",");
    return base64Decode(i == -1 ? dataUrl : dataUrl.substring(i + 1));
  }

  // ---------------- Paint ----------------
  Future<void> _paint() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      _snack("Type a prompt first.");
      return;
    }
    setState(() {
      _isPainting = true;
      _resolutionLabel = null;
    });
    try {
      final url = await _local.generateImage(prompt);
      if (!mounted) return;
      setState(() {
        _imageDataUrl = url;
        _imageBytes = _decodeDataUrl(url);
      });
    } catch (e) {
      _snack("Paint failed: $e", error: true);
    } finally {
      if (mounted) setState(() => _isPainting = false);
    }
  }

  // ---------------- Colorize (cloud) ----------------
  Future<void> _colorize() async {
    if (_imageDataUrl == null) {
      _snack("Generate an image first (Paint button).");
      return;
    }
    setState(() {
      _isColorizing = true;
      _isFetchingRes = true;
    });
    try {
      final res = await _cloud.getResolution(_imageDataUrl!);
      if (!mounted) return;
      setState(() {
        _resolutionLabel = "Original: ${res.width} × ${res.height}";
        _isFetchingRes = false;
      });
      final gray = await _cloud.convertGrayscale(_imageDataUrl!);
      if (!mounted) return;
      setState(() {
        _imageDataUrl = gray;
        _imageBytes = _decodeDataUrl(gray);
      });
      _snack("Colorize → grayscale done (${res.width}×${res.height}).");
    } catch (e) {
      _snack("Colorize failed: $e", error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isColorizing = false;
          _isFetchingRes = false;
        });
      }
    }
  }

  // ---------------- Chat ----------------
  Future<void> _send() async {
    final msg = _chatCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() {
      _history.add(ChatTurn(role: ChatRole.user, content: msg));
      _isChatting = true;
      _chatCtrl.clear();
    });
    _scrollChatToBottom();
    try {
      final reply = await _local.chat(
        message: msg,
        history: _history.sublist(0, _history.length - 1),
      );
      if (!mounted) return;
      setState(() => _history.add(ChatTurn(role: ChatRole.assistant, content: reply)));
      _scrollChatToBottom();
    } catch (e) {
      _snack("Chat failed: $e", error: true);
    } finally {
      if (mounted) setState(() => _isChatting = false);
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------- Voice ----------------
  Future<void> _toggleMic() async {
    if (!_speechReady) {
      _snack("Speech recognition not available. Grant mic permission.", error: true);
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (r) => setState(() => _chatCtrl.text = r.recognizedWords),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: "en_US",
    );
  }

  // ---------------- Settings ----------------
  Future<void> _openSettings() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => SettingsDialog(
        localUrl: _local.baseUrl,
        cloudUrl: _cloud.baseUrl,
      ),
    );
    if (result == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setString("local_url", result["local"]!);
    await p.setString("cloud_url", result["cloud"]!);
    setState(() {
      _local = LocalBackend(baseUrl: result["local"]!);
      _cloud = CloudBackend(baseUrl: result["cloud"]!);
    });
    _snack("Backend URLs updated.");
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: T.bodyGrad),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    _buildArtStudio(),
                    const SizedBox(height: 8),
                    _buildChatStudio(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "ROBO",
          style: TextStyle(
            color: T.cream,
            fontSize: 38,
            fontFamily: "Georgia",
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          "MUNCH",
          style: TextStyle(
            color: T.orange,
            fontSize: 20,
            fontFamily: "Georgia",
            fontWeight: FontWeight.w400,
            letterSpacing: 3.0,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x99D8A064), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x8C000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
            image: const DecorationImage(
              image: AssetImage("assets/munch.png"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Settings (not part of original mock but useful at runtime)
        IconButton(
          icon: const Icon(Icons.settings, color: T.creamDim, size: 22),
          onPressed: _openSettings,
          tooltip: "Backend URLs",
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _studioTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFF4E6D3),
          fontFamily: "Georgia",
          fontWeight: FontWeight.w400,
          fontSize: 30,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildArtStudio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _studioTitle("Art Studio"),
        // ----- Image output (16:9, dark with inset shadow) -----
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0502),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _imagePainted(),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // ----- Prompt card with paint button -----
        _PromptCard(
          controller: _promptCtrl,
          enabled: !_isPainting,
          onPaint: _paint,
          isPainting: _isPainting,
        ),
        const SizedBox(height: 14),
        // ----- "colorize" pill button (RGB → grayscale) -----
        GestureDetector(
          onTap: (_isColorizing || _imageDataUrl == null) ? null : _colorize,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              gradient: T.cardGrad,
              borderRadius: BorderRadius.circular(999),
              boxShadow: T.cardShadow,
            ),
            alignment: Alignment.center,
            child: _isColorizing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: T.cream,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isFetchingRes
                            ? "Getting resolution..."
                            : "Converting to grayscale...",
                        style: const TextStyle(
                          color: T.cream,
                          fontFamily: "Georgia",
                          fontStyle: FontStyle.italic,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    "colorize",
                    style: TextStyle(
                      color: T.cream,
                      fontFamily: "Georgia",
                      fontStyle: FontStyle.italic,
                      fontSize: 18,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _imagePainted() {
    if (_isPainting) {
      return const Center(
        child: Text(
          "Painting...",
          style: TextStyle(
            color: Color(0xFFF0C891),
            fontFamily: "Georgia",
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
        ),
      );
    }
    if (_imageBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_imageBytes!, fit: BoxFit.cover),
          if (_resolutionLabel != null)
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _resolutionLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: "Georgia",
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          "Your painting appears here.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF8A6A4F),
            fontFamily: "Georgia",
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildChatStudio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _studioTitle("Chat Studio"),
        // ----- Chat output -----
        Container(
          constraints: const BoxConstraints(minHeight: 150, maxHeight: 260),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: T.cardGrad,
            borderRadius: BorderRadius.circular(18),
            boxShadow: T.cardShadow,
          ),
          child: _history.isEmpty
              ? const Center(
                  child: Text(
                    "Say hi to RoboMunch...",
                    style: TextStyle(
                      color: Color(0xFFD6B791),
                      fontFamily: "Georgia",
                      fontStyle: FontStyle.italic,
                      fontSize: 16.5,
                    ),
                  ),
                )
              : ListView.separated(
                  controller: _chatScroll,
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final t = _history[i];
                    final isUser = t.role == ChatRole.user;
                    return RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: T.cream,
                          fontFamily: "Georgia",
                          fontStyle: FontStyle.italic,
                          fontSize: 16.5,
                          height: 1.45,
                        ),
                        children: [
                          TextSpan(
                            text: isUser ? "YOU: " : "MUNCH: ",
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFF4E0),
                            ),
                          ),
                          TextSpan(text: t.content),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        // ----- Chat input row: mic button + pill text field with send -----
        Row(
          children: [
            _MicButton(
              recording: _isListening,
              onTap: _toggleMic,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ChatInputPill(
                controller: _chatCtrl,
                enabled: !_isChatting,
                onSend: _send,
                isSending: _isChatting,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// Sub-widgets — kept as separate classes so the build method stays readable.
// ===========================================================================

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.controller,
    required this.enabled,
    required this.onPaint,
    required this.isPainting,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onPaint;
  final bool isPainting;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        gradient: T.cardGrad,
        borderRadius: BorderRadius.circular(18),
        boxShadow: T.cardShadow,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 64, 30),
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLines: null,
              style: const TextStyle(
                color: T.cream,
                fontFamily: "Georgia",
                fontSize: 19,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
              decoration: const InputDecoration(
                hintText: "Type your prompt here.",
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onSubmitted: (_) => onPaint(),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 12,
            child: _PaintButton(
              loading: isPainting,
              onTap: enabled ? onPaint : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaintButton extends StatelessWidget {
  const _PaintButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(-0.4, -0.4),
            radius: 0.95,
            colors: [
              Color(0xFFEEA35A),
              Color(0xFFC66A25),
              Color(0xFF7A330D),
            ],
            stops: [0.0, 0.65, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x8C000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: T.cream,
                  ),
                )
              : Image.asset("assets/palette.png", width: 24, height: 24),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.recording, required this.onTap});
  final bool recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.4, -0.4),
            radius: 0.95,
            colors: [
              Color(0xFFC97539),
              Color(0xFF823611),
              Color(0xFF4A1C06),
            ],
            stops: [0.0, 0.70, 1.0],
          ),
          boxShadow: [
            const BoxShadow(
              color: Color(0x8C000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
            if (recording)
              const BoxShadow(
                color: Color(0x8CFF6464),
                blurRadius: 0,
                spreadRadius: 3,
              ),
          ],
        ),
        child: Center(
          child: Image.asset("assets/mic.png", width: 22, height: 22),
        ),
      ),
    );
  }
}

class _ChatInputPill extends StatelessWidget {
  const _ChatInputPill({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.isSending,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: T.cardGrad,
        borderRadius: BorderRadius.circular(999),
        boxShadow: T.cardShadow,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 52, 0),
            child: Center(
              child: TextField(
                controller: controller,
                enabled: enabled,
                style: const TextStyle(
                  color: T.cream,
                  fontFamily: "Georgia",
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                decoration: const InputDecoration(
                  hintText: "Type your message here.",
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 7,
            child: GestureDetector(
              onTap: enabled ? onSend : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEAB787), width: 1.5),
                  gradient: const RadialGradient(
                    center: Alignment(-0.4, -0.4),
                    radius: 0.95,
                    colors: [
                      Color(0xFFB86A32),
                      Color(0xFF7A3414),
                      Color(0xFF4A1C06),
                    ],
                    stops: [0.0, 0.70, 1.0],
                  ),
                ),
                child: Center(
                  child: isSending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: T.cream,
                          ),
                        )
                      : Image.asset("assets/send.png", width: 16, height: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
