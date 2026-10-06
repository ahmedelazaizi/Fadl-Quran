import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/full_surah_reciters.dart';
import '../../core/full_surah_store.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common.dart';

/// Independent whole-surah player; it never changes the ayah player or the
/// default reciter. Plays the saved copy when there is one, otherwise streams
/// and, unless turned off, keeps the stream for offline listening.
class FullSurahPlayerScreen extends StatefulWidget {
  const FullSurahPlayerScreen({
    super.key,
    required this.edition,
    required this.surah,
  });

  final FullSurahEdition edition;
  final int surah;

  @override
  State<FullSurahPlayerScreen> createState() => _FullSurahPlayerScreenState();
}

class _FullSurahPlayerScreenState extends State<FullSurahPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  final _store = FullSurahStore.instance;
  StreamSubscription<double>? _caching;
  bool _saveWhileListening = true;
  bool _offline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    _start();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      await _store.ready();
      _saveWhileListening = await FullSurahStore.saveWhileListening();
      final local = _store.localFile(widget.edition, widget.surah);
      _offline = local != null;
      if (local != null) {
        await _player.setFilePath(local.path);
      } else {
        await _setStream();
      }
      if (mounted) setState(() {});
      await _player.play();
    } on PlayerException {
      if (mounted) setState(() => _error = 'play');
    } on PlayerInterruptedException {
      if (mounted) setState(() => _error = 'interrupted');
    }
  }

  Future<void> _setStream() async {
    final url = Uri.parse(widget.edition.urlForSurah(widget.surah)!);
    if (!_saveWhileListening) {
      await _player.setUrl(url.toString());
      return;
    }
    try {
      // Experimental in just_audio; any failure falls back to plain streaming
      // below, so the only cost of a regression is the offline copy.
      // ignore: experimental_member_use
      final source = LockCachingAudioSource(
        url,
        cacheFile: await _store.cacheFile(widget.edition, widget.surah),
      );
      await _caching?.cancel();
      _caching = source.downloadProgressStream.listen((progress) {
        // The player renamed the finished cache into place: list it.
        if (progress >= 1) unawaited(_store.refresh());
      });
      await _player.setAudioSource(source);
    } on PlayerException {
      // Caching is best effort; plain streaming still plays the surah.
      await _caching?.cancel();
      await _player.setUrl(url.toString());
    }
  }

  Future<void> _download() async {
    try {
      await _store.download(widget.edition, widget.surah);
    } on FullSurahDownloadCancelled {
      // The user stopped it.
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          AppLocalizations.of(context)!.fullSurahDownloadFailed,
        );
      }
    }
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    _caching?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final number = Localizations.localeOf(context).languageCode == 'ar'
        ? arNum(widget.surah)
        : '${widget.surah}';
    return Scaffold(
      appBar: AppBar(title: Text(widget.edition.nameAr)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l.fullSurahHeading(number, widget.edition.editionName),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? fullSurahModeLabel
                : l.fullSurah,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _offline ? l.fullSurahPlayingOffline : l.fullSurahOnlineNotice,
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            Text(
              _error == 'play' ? l.fullSurahPlayError : l.fullSurahInterrupted,
              textAlign: TextAlign.center,
            ),
            TextButton(onPressed: _start, child: Text(l.retry)),
          ],
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) => IconButton(
              iconSize: 52,
              tooltip: _player.playing ? l.pause : l.play,
              onPressed: _error != null
                  ? null
                  : () {
                      if (_player.playing) {
                        _player.pause();
                      } else {
                        _player.play();
                      }
                    },
              icon: Icon(
                _player.playing ? Icons.pause_circle : Icons.play_circle,
              ),
            ),
          ),
          StreamBuilder<Duration?>(
            stream: _player.durationStream,
            builder: (context, _) => StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, position) {
                final duration = _player.duration ?? Duration.zero;
                final current = position.data ?? Duration.zero;
                return Slider(
                  value: current.inMilliseconds
                      .clamp(0, duration.inMilliseconds)
                      .toDouble(),
                  max: duration.inMilliseconds == 0
                      ? 1
                      : duration.inMilliseconds.toDouble(),
                  onChanged: duration == Duration.zero
                      ? null
                      : (milliseconds) => _player.seek(
                          Duration(milliseconds: milliseconds.round()),
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          _offlineCard(l),
        ],
      ),
    );
  }

  Widget _offlineCard(AppLocalizations l) {
    final edition = widget.edition;
    final surah = widget.surah;
    final saved = _store.isDownloaded(edition, surah);
    final downloading = _store.isDownloading(edition, surah);
    return Card(
      child: Column(
        children: [
          if (saved)
            ListTile(
              leading: const Icon(Icons.offline_pin_rounded),
              title: Text(l.availableOffline),
              trailing: IconButton(
                tooltip: l.delete,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _store.deleteSurah(edition, surah),
              ),
            )
          else if (downloading) ...[
            ListTile(
              leading: const Icon(Icons.downloading_rounded),
              title: Text(l.downloading),
              trailing: IconButton(
                tooltip: l.cancelDownload,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => _store.cancel(edition, surah),
              ),
            ),
            LinearProgressIndicator(value: _store.progress(edition, surah)),
          ] else
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: Text(l.downloadOffline),
              onTap: _download,
            ),
          SwitchListTile(
            value: _saveWhileListening,
            title: Text(l.fullSurahSaveWhileListening),
            subtitle: Text(l.fullSurahSaveHint),
            onChanged: (value) async {
              setState(() => _saveWhileListening = value);
              await FullSurahStore.setSaveWhileListening(value);
            },
          ),
        ],
      ),
    );
  }
}
