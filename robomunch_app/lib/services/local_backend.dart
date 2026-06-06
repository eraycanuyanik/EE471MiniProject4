import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_turn.dart';

/// Talks to Backend Server 1 (Flask, localhost / LAN).
class LocalBackend {
  LocalBackend({required this.baseUrl});

  String baseUrl;

  Uri _u(String path) {
    final b = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse("$b$path");
  }

  Future<String> chat({
    required String message,
    required List<ChatTurn> history,
  }) async {
    final res = await http
        .post(
          _u("/api/chat"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "message": message,
            "history": history.map((t) => t.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 120));
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception(body["error"] ?? "HTTP ${res.statusCode}");
    }
    return (body["reply"] as String?)?.trim() ?? "(no reply)";
  }

  /// Returns a data URL like "data:image/png;base64,..." that the UI can
  /// display via `Image.memory(base64Decode(stripPrefix(url)))`.
  Future<String> generateImage(String prompt) async {
    final res = await http
        .post(
          _u("/api/generate-image"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"prompt": prompt}),
        )
        .timeout(const Duration(seconds: 180));
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception(body["error"] ?? "HTTP ${res.statusCode}");
    }
    return body["image"] as String;
  }
}
