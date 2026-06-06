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

class RoboMunchApp extends StatelessWidget {
  const RoboMunchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "RoboMunch",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB97A56),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6E0C7),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontFamily: "serif",
            fontWeight: FontWeight.bold,
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

  String? _imageDataUrl;          // most recent generated image
  Uint8List? _imageBytes;
  String? _resolutionLabel;       // shown overlay on image after /get/resolution

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
    setState(() => _speechReady = ok);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : null,
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

  // ---------------- Colorize button: 2 cloud calls ----------------
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
      setState(() {
        _resolutionLabel = "Original: ${res.width} × ${res.height}";
        _isFetchingRes = false;
      });
      final gray = await _cloud.convertGrayscale(_imageDataUrl!);
      setState(() {
        _imageDataUrl = gray;
        _imageBytes = _decodeDataUrl(gray);
      });
      _snack("Colorize → grayscale done (${res.width}x${res.height}).");
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildArtStudio(),
              const SizedBox(height: 16),
              _buildChatStudio(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: const [
            Text(
              "ROBO",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28,
                fontFamily: "serif",
                color: Color(0xFF2B1810),
              ),
            ),
            SizedBox(width: 6),
            Text(
              "MUNCH",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 28,
                fontFamily: "serif",
                color: Color(0xFFB97A56),
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: _openSettings,
          icon: const Icon(Icons.settings),
          tooltip: "Backend URLs",
        ),
      ],
    );
  }

  Widget _buildArtStudio() {
    return _Card(
      title: "Art Studio",
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: _isPainting
                ? const CircularProgressIndicator()
                : _imageBytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                          ),
                          if (_resolutionLabel != null)
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _resolutionLabel!,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      )
                    : const Text(
                        "Your painting appears here.",
                        style: TextStyle(color: Colors.black54),
                      ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promptCtrl,
                decoration: const InputDecoration(
                  hintText: "Type your prompt here.",
                  filled: true,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _paint(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isPainting ? null : _paint,
              icon: const Icon(Icons.brush),
              tooltip: "Paint",
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_isColorizing || _imageDataUrl == null) ? null : _colorize,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6B3B22),
            ),
            icon: _isColorizing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.invert_colors),
            label: Text(
              _isFetchingRes
                  ? "Getting resolution..."
                  : _isColorizing
                      ? "Converting to grayscale..."
                      : "colorize  (RGB → grayscale)",
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatStudio() {
    return _Card(
      title: "Chat Studio",
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: _history.isEmpty
              ? const Center(
                  child: Text(
                    "Say hi to RoboMunch...",
                    style: TextStyle(color: Colors.black45),
                  ),
                )
              : ListView.separated(
                  controller: _chatScroll,
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t = _history[i];
                    final isUser = t.role == ChatRole.user;
                    return RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black87, fontSize: 14),
                        children: [
                          TextSpan(
                            text: isUser ? "YOU: " : "MUNCH: ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isUser
                                  ? Colors.brown.shade700
                                  : Colors.deepOrange.shade900,
                            ),
                          ),
                          TextSpan(text: t.content),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: _toggleMic,
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              tooltip: "Voice input",
              style: IconButton.styleFrom(
                backgroundColor: _isListening ? Colors.red.shade100 : null,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _chatCtrl,
                decoration: const InputDecoration(
                  hintText: "Type your message here.",
                  filled: true,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _isChatting ? null : _send,
              icon: _isChatting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              tooltip: "Send",
            ),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFC9A4),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: "serif",
                fontSize: 18,
                color: Color(0xFF2B1810),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
