import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_store.dart';
import 'reciters.dart';

/// Optionally saves the surah being listened to or read for the chosen
/// reciter, so the next playback works offline. Off unless the user turns
/// it on; each surah is attempted once per session.
class AutoDownload {
  AutoDownload({AudioStore? store}) : _store = store ?? AudioStore.instance;

  static final AutoDownload instance = AutoDownload();
  static const preferenceKey = 'fadl.audio.autoDownload';

  final AudioStore _store;
  final Set<String> _attempted = {};

  static Future<bool> enabled() async =>
      (await SharedPreferences.getInstance()).getBool(preferenceKey) ?? false;

  static Future<void> setEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(preferenceKey, value);

  /// Starts a background download when enabled and the surah is not saved.
  Future<void> consider(String reciterId, int surah) async {
    if (surah < 1 || surah > 114 || reciterById(reciterId) == null) return;
    final key = '$reciterId/$surah';
    if (_attempted.contains(key) || !await enabled()) return;
    await _store.ready();
    if (_store.status(reciterId, surah) == DownloadStatus.complete) return;
    _attempted.add(key);
    unawaited(
      _store.downloadSurah(reciterId, surah).catchError((Object error) {
        // Offline or interrupted: allow another attempt later this session.
        _attempted.remove(key);
        debugPrint('AutoDownload: $key failed: $error');
      }),
    );
  }
}
