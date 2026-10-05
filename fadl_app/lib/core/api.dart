import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The backend is optional; opt in with --dart-define=API_BASE=https://...
const String apiBase = String.fromEnvironment('API_BASE', defaultValue: '');

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

/// JSON client with an invisible anonymous identity: the app has no sign-in.
/// On first launch it creates an identity and stores the device secret; the
/// short-lived access token is renewed transparently on 401.
class Api {
  Api._();
  static final Api instance = Api._();
  static bool get hasBackend => apiBase.isNotEmpty;

  static void _requireBackend() {
    if (!hasBackend) {
      throw ApiException(
        0,
        'الخادم غير مهيأ. استخدم التطبيق دون اتصال أو حدد API_BASE.',
      );
    }
  }

  static const _secretKey = 'fadl.deviceSecret';
  static const _tokenKey = 'fadl.accessToken';

  final http.Client _client = http.Client();
  String? _token;
  String? _secret;
  Future<void>? _initializing;

  Future<void> ensureIdentity({String? timezone}) {
    _requireBackend();
    final pending = _initializing ??= _init(timezone);
    // Don't cache a failure: the next call retries.
    return pending.catchError((Object e) {
      _initializing = null;
      throw e;
    });
  }

  /// Forgets the in-memory identity (after the user deletes their data).
  void reset() {
    _secret = null;
    _token = null;
    _initializing = null;
  }

  Future<void> _init(String? timezone) async {
    final prefs = await SharedPreferences.getInstance();
    _secret = prefs.getString(_secretKey);
    _token = prefs.getString(_tokenKey);
    if (_secret == null) {
      final res = await _send(
        'POST',
        '/auth/anonymous',
        body: {'timezone': ?timezone},
        auth: false,
      );
      _secret = res['deviceSecret'] as String;
      _token = res['accessToken'] as String;
      await prefs.setString(_secretKey, _secret!);
      await prefs.setString(_tokenKey, _token!);
    }
  }

  Future<void> _renewToken() async {
    final res = await _send(
      'POST',
      '/auth/token',
      body: {'deviceSecret': _secret},
      auth: false,
    );
    _token = res['accessToken'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
  }

  Future<dynamic> get(String path, [Map<String, Object?>? query]) =>
      _request('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) =>
      _request('POST', path, body: body ?? {});
  Future<dynamic> patch(String path, Object body) =>
      _request('PATCH', path, body: body);
  Future<dynamic> put(String path, Object body) =>
      _request('PUT', path, body: body);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
  }) async {
    _requireBackend();
    final needsAuth = path.startsWith('/me') || path == '/duas/amen';
    if (needsAuth) await ensureIdentity();
    try {
      return await _send(
        method,
        path,
        query: query,
        body: body,
        auth: needsAuth,
      );
    } on ApiException catch (e) {
      if (e.statusCode != 401 || !needsAuth || _secret == null) rethrow;
      await _renewToken();
      return _send(method, path, query: query, body: body, auth: true);
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    required bool auth,
  }) async {
    final params = <String, String>{
      for (final e in (query ?? const <String, Object?>{}).entries)
        if (e.value != null) e.key: '${e.value}',
    };
    final uri = Uri.parse(
      '$apiBase$path',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final headers = <String, String>{
      if (body != null) 'content-type': 'application/json; charset=utf-8',
      if (auth && _token != null) 'authorization': 'Bearer $_token',
    };
    final req = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    late http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 25)),
      );
    } catch (_) {
      throw ApiException(
        0,
        'تعذّر الاتصال بالخادم. تحقق من الاتصال بالإنترنت.',
      );
    }
    final text = utf8.decode(res.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      final message = decoded is Map && decoded['message'] is String
          ? decoded['message'] as String
          : 'خطأ ${res.statusCode}';
      throw ApiException(res.statusCode, message);
    }
    return decoded;
  }
}
