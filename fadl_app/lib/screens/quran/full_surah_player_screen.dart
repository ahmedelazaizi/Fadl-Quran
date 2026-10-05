import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/full_surah_reciters.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';

/// Independent streaming player; it never changes the ayah player or default reciter.
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      await _player.setUrl(widget.edition.urlForSurah(widget.surah)!);
      await _player.play();
    } on PlayerException {
      if (mounted) {
        setState(() => _error = 'play');
      }
    } on PlayerInterruptedException {
      if (mounted) {
        setState(() => _error = 'interrupted');
      }
    }
  }

  @override
  void dispose() {
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            Text(l.fullSurahOnlineNotice, textAlign: TextAlign.center),
            if (_error != null) ...[
              Text(
                _error == 'play'
                    ? l.fullSurahPlayError
                    : l.fullSurahInterrupted,
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
          ],
        ),
      ),
    );
  }
}
