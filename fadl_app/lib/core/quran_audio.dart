import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'audio_store.dart';
import 'memorization.dart';
import 'quran_data.dart';
import 'reciters.dart';

/// Streaming an ayah failed (typically no internet and no download).
class AudioStreamException implements Exception {
  AudioStreamException(this.message);
  final String message;
  @override
  String toString() => message;
}

bool usesContinuousPlaylist(MemorizationSettings settings) =>
    settings.ayahRepeats == 1 &&
    settings.pauseMode == 0 &&
    (!settings.hasRange || settings.rangeRepeats == 1);

Map<String, dynamic>? ayahAtAudioIndex(
  List<Map<String, dynamic>> ayahs,
  int? index,
) => index == null || index < 0 || index >= ayahs.length ? null : ayahs[index];

int? nextContinuousSurah(int surah, bool continuous, bool hasRange) =>
    continuous && !hasRange && surah < 114 ? surah + 1 : null;

class QuranAudio extends ChangeNotifier {
  QuranAudio._() {
    player.playerStateStream.listen((state) {
      notifyListeners();
      if (state.processingState == ProcessingState.completed) {
        unawaited(_completed());
      }
    });
    player.positionStream.listen((_) => notifyListeners());
    player.currentIndexStream.listen((currentIndex) {
      if (!_playlistMode || ayahAtAudioIndex(ayahs, currentIndex) == null) {
        return;
      }
      index = currentIndex!;
      notifyListeners();
    });
    player.errorStream.listen((_) {
      if (_playlistMode && !loading) {
        error = streamFailedMessage;
        notifyListeners();
      }
    });
  }
  static final instance = QuranAudio._();
  static const _settingsKey = 'fadl.memorization';
  final AudioPlayer player = AudioPlayer();
  MemorizationSettings settings = const MemorizationSettings();
  Map<String, dynamic>? playlist;
  int surahId = 0;
  int index = 0;
  String reciterId = '';
  bool continuous = true;
  bool loading = false;
  String? error;
  int countdown = 0;
  int _ayahPlay = 0;
  int _rangePlay = 1;
  int _request = 0;
  bool _transitioning = false;
  bool _playlistMode = false;
  int _playlistEnd = 0;
  Timer? _pauseTimer;

  List<Map<String, dynamic>> get ayahs =>
      ((playlist?['ayahs'] as List?) ?? const []).cast<Map<String, dynamic>>();
  Map<String, dynamic>? get reciter =>
      playlist?['reciter'] as Map<String, dynamic>?;
  String? get ayahKey =>
      ayahs.isEmpty ? null : ayahAtAudioIndex(ayahs, index)!['key'] as String?;
  int get ayahNumber =>
      ayahs.isEmpty ? 0 : ayahAtAudioIndex(ayahs, index)!['number'] as int;
  bool get playing => player.playing || countdown > 0;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_settingsKey);
    if (saved != null) {
      try {
        settings = MemorizationSettings.fromJson(
          jsonDecode(saved) as Map<String, dynamic>,
        );
      } on FormatException {
        settings = const MemorizationSettings();
      }
    }
    await player.setSpeed(settings.speed);
    notifyListeners();
  }

  Future<void> updateSettings(MemorizationSettings next) async {
    final rebuild =
        playlist != null &&
        (usesContinuousPlaylist(settings) != usesContinuousPlaylist(next) ||
            (_playlistMode && settings.rangeEnd != next.rangeEnd));
    final wasPlaying = playing;
    settings = next;
    _ayahPlay = 0;
    _rangePlay = 1;
    await player.setSpeed(next.speed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(next.toJson()));
    if (rebuild) {
      await start(
        surahId,
        ayahNumber,
        reciterId,
        continuousPlay: continuous,
        autoplay: wasPlaying,
      );
    }
    notifyListeners();
  }

  Future<void> start(
    int surah,
    int ayah,
    String reciter, {
    required bool continuousPlay,
    bool autoplay = true,
  }) async {
    final request = ++_request;
    _cancelPause();
    if (surahId != 0 && surah != surahId && settings.hasRange) {
      settings = settings.copyWith(clearRange: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    }
    _playlistMode = false;
    await player.stop();
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await _localPlaylist(surah, reciter);
      if (request != _request) return;
      final entries = (response['ayahs'] as List).cast<Map<String, dynamic>>();
      if (entries.isEmpty) throw StateError('لا توجد تلاوة لهذه السورة');
      playlist = response;
      surahId = surah;
      reciterId = reciter;
      continuous = continuousPlay;
      index = (ayah - 1).clamp(0, entries.length - 1);
      _ayahPlay = 0;
      _rangePlay = 1;
      if (usesContinuousPlaylist(settings)) {
        await _openPlaylist(autoplay: autoplay);
      } else {
        await _openAyah(autoplay: autoplay);
      }
    } catch (failure) {
      if (request == _request) {
        error = _describe(failure);
        notifyListeners();
      }
      rethrow;
    } finally {
      if (request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  static const streamFailedMessage =
      'تعذّر بث التلاوة، يبدو أنه لا يوجد اتصال بالإنترنت. '
      'نزّل السورة من المكتبة الصوتية للاستماع إليها دون إنترنت.';

  static String _describe(Object failure) => switch (failure) {
    AudioStreamException(:final message) => message,
    ApiException(:final message) => message,
    StateError(:final message) => message,
    _ => 'تعذّر تشغيل التلاوة.',
  };

  /// Same shape as the server's `GET /quran/audio/surahs/{n}` response; each
  /// ayah also carries its global number (`id`) to find downloaded files.
  static Future<Map<String, dynamic>> _localPlaylist(
    int surah,
    String reciterId,
  ) async {
    final reciter = reciterById(reciterId);
    if (reciter == null) throw StateError('القارئ غير متوفر');
    final quran = await QuranData.load();
    if (surah < 1 || surah > quran.surahs.length) {
      throw StateError('السورة غير موجودة');
    }
    final bitrate = pickBitrate((reciter['verseBitrates'] as List).cast<int>());
    final surahBitrate = reciter['surahBitrate'] as int?;
    return {
      'surah': quran.surahs[surah - 1],
      'reciter': {
        'id': reciter['id'],
        'nameAr': reciter['nameAr'],
        'style': reciter['style'],
        'riwaya': reciter['riwaya'],
      },
      'bitrate': bitrate,
      'surahUrl': surahBitrate == null
          ? null
          : surahAudioUrl(reciterId, surahBitrate, surah),
      'ayahs': [
        for (final ayah in quran.surahAyahs(surah))
          <String, dynamic>{
            'id': ayah['id'],
            'key': ayah['key'],
            'number': ayah['number'],
            'url': ayahAudioUrl(
              reciterId,
              ayah['id'] as int,
              surah: surah,
              ayah: ayah['number'] as int,
            ),
          },
      ],
    };
  }

  Future<void> _openPlaylist({required bool autoplay}) async {
    final request = _request;
    _playlistEnd = settings.hasRange
        ? settings.rangeEnd!.clamp(index + 1, ayahs.length)
        : ayahs.length;
    final sources = <AudioSource>[];
    for (final entry in ayahs.take(_playlistEnd)) {
      final local = await AudioStore.instance.localFile(
        reciterId,
        entry['id'] as int,
      );
      sources.add(
        local == null
            ? AudioSource.uri(Uri.parse(entry['url'] as String))
            : AudioSource.file(local.path),
      );
    }
    if (request != _request) return;
    _playlistMode = true;
    try {
      await player.setAudioSources(sources, initialIndex: index, preload: true);
    } on PlayerException {
      if (request != _request) return;
      if (await AudioStore.instance.localFile(
            reciterId,
            ayahs[index]['id'] as int,
          ) ==
          null) {
        throw AudioStreamException(streamFailedMessage);
      }
      rethrow;
    }
    if (request != _request) return;
    await player.setSpeed(settings.speed);
    notifyListeners();
    if (autoplay) unawaited(player.play());
  }

  Future<void> _openAyah({required bool autoplay}) async {
    final entry = ayahs[index];
    final local = await AudioStore.instance.localFile(
      reciterId,
      entry['id'] as int,
    );
    if (local != null) {
      await player.setFilePath(local.path);
    } else {
      try {
        await player.setUrl(entry['url'] as String);
      } catch (_) {
        error = streamFailedMessage;
        notifyListeners();
        throw AudioStreamException(streamFailedMessage);
      }
    }
    if (error == streamFailedMessage) error = null;
    await player.setSpeed(settings.speed);
    notifyListeners();
    if (autoplay) unawaited(player.play());
  }

  Future<void> seekAyah(int number) async {
    if (number < 1 || number > ayahs.length) return;
    _cancelPause();
    _ayahPlay = 0;
    _rangePlay = 1;
    if (_playlistMode && number <= _playlistEnd) {
      await player.seek(Duration.zero, index: number - 1);
      if (!player.playing) unawaited(player.play());
    } else {
      index = number - 1;
      if (usesContinuousPlaylist(settings)) {
        await player.stop();
        await _openPlaylist(autoplay: true);
      } else {
        await _openAyah(autoplay: true);
      }
    }
  }

  Future<void> pause() async {
    if (countdown > 0) {
      _pauseTimer?.cancel();
      _pauseTimer = null;
      countdown = 0;
    } else {
      await player.pause();
    }
    notifyListeners();
  }

  Future<void> resume() async {
    if (_pending != null) {
      await _advancePending();
    } else if (player.processingState == ProcessingState.completed) {
      if (_playlistMode) {
        await _completed();
      } else {
        await seekAyah(ayahNumber);
      }
    } else {
      unawaited(player.play());
    }
    notifyListeners();
  }

  MemorizationMove? _pending;
  Future<void> _completed() async {
    if (_transitioning || loading || ayahs.isEmpty || countdown > 0) return;
    _transitioning = true;
    try {
      if (_playlistMode) {
        final next = nextContinuousSurah(
          surahId,
          continuous,
          settings.hasRange,
        );
        if (next == null) {
          await player.stop();
        } else {
          await start(next, 1, reciterId, continuousPlay: continuous);
        }
        return;
      }
      _ayahPlay++;
      final decision = nextMemorizationAction(
        settings: settings,
        ayah: ayahNumber,
        ayahCount: ayahs.length,
        ayahPlay: _ayahPlay,
        rangePlay: _rangePlay,
        ayahDuration: player.duration ?? Duration.zero,
      );
      _pending = decision.move;
      if (decision.pause > Duration.zero) {
        countdown = (decision.pause.inMilliseconds / 1000).ceil();
        notifyListeners();
        _pauseTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          countdown--;
          notifyListeners();
          if (countdown <= 0) {
            _pauseTimer?.cancel();
            unawaited(_advancePending());
          }
        });
      } else {
        await _advancePending();
      }
    } catch (failure) {
      error = _describe(failure);
      notifyListeners();
    } finally {
      _transitioning = false;
    }
  }

  Future<void> _advancePending() async {
    final move = _pending;
    _pending = null;
    if (move == null) return;
    try {
      switch (move) {
        case MemorizationMove.replay:
          await _openAyah(autoplay: true);
        case MemorizationMove.advance:
          index++;
          _ayahPlay = 0;
          await _openAyah(autoplay: true);
        case MemorizationMove.rangeStart:
          _rangePlay++;
          _ayahPlay = 0;
          index = settings.rangeStart! - 1;
          await _openAyah(autoplay: true);
        case MemorizationMove.stop:
          final next = nextContinuousSurah(
            surahId,
            continuous,
            settings.hasRange,
          );
          if (next == null) {
            await player.stop();
          } else {
            await start(next, 1, reciterId, continuousPlay: continuous);
          }
      }
    } catch (failure) {
      error = _describe(failure);
      notifyListeners();
    }
  }

  void _cancelPause() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    countdown = 0;
    _pending = null;
    notifyListeners();
  }
}
