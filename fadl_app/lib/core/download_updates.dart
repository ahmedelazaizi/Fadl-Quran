import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum UpdateStatus { current, available, unknown }

class DownloadRecord {
  const DownloadRecord(
    this.url,
    this.downloadedAt,
    this.etag,
    this.lastModified,
  );
  final String url;
  final DateTime downloadedAt;
  final String? etag;
  final String? lastModified;
}

/// Validators belong to the exact URL used for the completed download.
class DownloadUpdates {
  DownloadUpdates({http.Client? client}) : _client = client ?? http.Client();

  static final instance = DownloadUpdates();
  final http.Client _client;

  String _key(String id) => 'fadl.downloadUpdates.$id';

  Future<DownloadRecord?> recordFor(String id) async {
    final stored = (await SharedPreferences.getInstance()).getString(_key(id));
    if (stored == null) return null;
    final fields = jsonDecode(stored) as Map<String, dynamic>;
    return DownloadRecord(
      fields['url'] as String,
      DateTime.parse(fields['date'] as String),
      fields['etag'] as String?,
      fields['lastModified'] as String?,
    );
  }

  Future<void> record(
    String id,
    String url,
    Map<String, String> headers,
  ) async {
    await (await SharedPreferences.getInstance()).setString(
      _key(id),
      jsonEncode({
        'url': url,
        'date': DateTime.now().toUtc().toIso8601String(),
        'etag': headers['etag'],
        'lastModified': headers['last-modified'],
      }),
    );
  }

  Future<void> remove(String id) async =>
      (await SharedPreferences.getInstance()).remove(_key(id));

  /// Only call on explicit user action. An absent baseline cannot prove freshness.
  Future<UpdateStatus> check(String id, String url) async {
    final previous = await recordFor(id);
    if (previous == null ||
        previous.url != url ||
        (previous.etag == null && previous.lastModified == null)) {
      return UpdateStatus.unknown;
    }
    final request = http.Request('HEAD', Uri.parse(url))
      ..followRedirects = false;
    if (previous.etag != null) {
      request.headers['If-None-Match'] = previous.etag!;
    }
    if (previous.lastModified != null) {
      request.headers['If-Modified-Since'] = previous.lastModified!;
    }
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    await response.stream.drain<void>();
    if (response.statusCode == 304) return UpdateStatus.current;
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', request.url);
    }
    final etag = response.headers['etag'];
    final modified = response.headers['last-modified'];
    if (etag == null && modified == null) return UpdateStatus.unknown;
    if (previous.etag != null && etag != null && previous.etag != etag ||
        previous.lastModified != null &&
            modified != null &&
            previous.lastModified != modified) {
      return UpdateStatus.available;
    }
    if (previous.etag != null && etag == null ||
        previous.lastModified != null && modified == null) {
      return UpdateStatus.unknown;
    }
    return UpdateStatus.current;
  }
}
