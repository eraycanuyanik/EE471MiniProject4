import 'dart:convert';

import 'package:http/http.dart' as http;

class ResolutionResult {
  ResolutionResult(this.width, this.height);
  final int width;
  final int height;
  @override
  String toString() => "${width}x$height";
}

/// Talks to Backend Server 2 (Django, cloud VM).
class CloudBackend {
  CloudBackend({required this.baseUrl});

  String baseUrl;

  Uri _u(String path) {
    final b = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse("$b$path");
  }

  String _stripDataUrl(String dataUrl) {
    final i = dataUrl.indexOf(",");
    return i == -1 ? dataUrl : dataUrl.substring(i + 1);
  }

  Future<ResolutionResult> getResolution(String imageDataUrl) async {
    final res = await http
        .post(
          _u("/get/resolution"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"image": _stripDataUrl(imageDataUrl)}),
        )
        .timeout(const Duration(seconds: 30));
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception(body["error"] ?? "HTTP ${res.statusCode}");
    }
    return ResolutionResult(body["width"] as int, body["height"] as int);
  }

  Future<String> convertGrayscale(String imageDataUrl) async {
    final res = await http
        .post(
          _u("/convert/grayscale"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"image": _stripDataUrl(imageDataUrl)}),
        )
        .timeout(const Duration(seconds: 60));
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception(body["error"] ?? "HTTP ${res.statusCode}");
    }
    return body["image"] as String;
  }
}
