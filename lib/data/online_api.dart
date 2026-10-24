import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'http_native.dart' if (dart.library.js_interop) 'http_web.dart';

class OnlineError implements Exception {
  OnlineError(this.status, this.data);
  final int status;
  final Map<String, dynamic> data;
  @override
  String toString() => data['error'] as String? ?? '온라인 연결 오류';
}

class OnlineApi {
  OnlineApi({http.Client? client, String? base})
    : client = client ?? createClient(),
      base = base ?? defaultBase;
  static String get defaultBase {
    const configured = String.fromEnvironment('ONLINE_API');
    return configured.isNotEmpty
        ? configured
        : (kIsWeb
              ? Uri.base.origin
              : 'https://shootingstar-online.chikinx1.workers.dev');
  }

  final http.Client client;
  final String base;
  String? token;
  final storage = const FlutterSecureStorage();
  Future<void> initialize() async {
    if (!kIsWeb) token = await storage.read(key: 'shootingstar.session');
  }

  Future<void> setToken(String? value) async {
    token = value;
    if (!kIsWeb) {
      if (value == null) {
        await storage.delete(key: 'shootingstar.session');
      } else {
        await storage.write(key: 'shootingstar.session', value: value);
      }
    }
  }

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> data = const {},
  ]) async {
    final response = await client
        .post(
          Uri.parse('$base/api/$path'),
          headers: {
            'Content-Type': 'application/json',
            'X-Client': kIsWeb ? 'web' : 'native',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 10));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw OnlineError(502, {'error': '서버 응답을 읽지 못했습니다.'});
    }
    if (response.statusCode != 200) {
      throw OnlineError(response.statusCode, decoded);
    }
    return decoded;
  }

  static String salt() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static Future<String> passwordKey(String password, String salt) async {
    final bytes = [
      for (int i = 0; i < salt.length; i += 2)
        int.parse(salt.substring(i, i + 2), radix: 16),
    ];
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 600000,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: bytes);
    return (await key.extractBytes())
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
