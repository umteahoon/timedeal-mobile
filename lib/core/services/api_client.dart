import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// 웹 타임딜 서버(/api) 호출. 로그인돼 있으면 Supabase 액세스 토큰을 Bearer로 붙입니다.
class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  ApiException(this.status, this.code, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static Map<String, String> _headers() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _send(String method, String path, [Object? body]) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await http.get(uri, headers: _headers()),
      'POST' => await http.post(uri, headers: _headers(), body: encoded ?? '{}'),
      'PATCH' => await http.patch(uri, headers: _headers(), body: encoded),
      _ => throw ArgumentError(method),
    };
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode >= 400 || decoded['ok'] == false) {
      final error = (decoded['error'] as Map<String, dynamic>?) ?? {};
      throw ApiException(response.statusCode, error['code'] as String? ?? 'HTTP_${response.statusCode}', error['message'] as String? ?? '요청에 실패했어요');
    }
    return (decoded['data'] as Map<String, dynamic>?) ?? {};
  }

  static Future<Map<String, dynamic>> get(String path) => _send('GET', path);
  static Future<Map<String, dynamic>> post(String path, [Object? body]) => _send('POST', path, body);
  static Future<Map<String, dynamic>> patch(String path, Object body) => _send('PATCH', path, body);

  /// Supabase Storage 서명 URL로 이미지 바이트를 올립니다.
  static Future<void> putSigned(String signedUrl, List<int> bytes, String contentType) async {
    final response = await http.put(Uri.parse(signedUrl), headers: {'Content-Type': contentType}, body: bytes);
    if (response.statusCode >= 400) throw ApiException(response.statusCode, 'UPLOAD_FAILED', '이미지를 올리지 못했어요');
  }
}
