import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/offline_tafsir.dart';
import '../../core/quran_audio.dart';
import '../../core/quran_data.dart';
import '../../core/reciters.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common.dart';
import 'memorization_sheet.dart';

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({
    super.key,
    this.surahId = 1,
    this.startAyah = 1,
    this.reciterId,
    this.useCurrent = false,
  });
  final int surahId;
  final int startAyah;
  final String? reciterId;
  final bool useCurrent;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  String _number(Object? number) =>
      Localizations.localeOf(context).languageCode == 'ar'
      ? arNum(number ?? 0)
      : '$number';
  final audio = QuranAudio.instance;
  Map<String, dynamic>? surah;
  Timer? sleepTimer;
  DateTime? sleepAt;
  int _surahRequest = 0;
  int? _surahLoadingId;
  int? _surahFailedId;

  @override
  void initState() {
    super.initState();
    audio.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await audio.loadSettings();
      if (!mounted) return;
      if (!widget.useCurrent || audio.playlist == null) {
        await _start(widget.surahId, widget.startAyah, widget.reciterId);
      } else {
        await _loadSurah(audio.surahId);
      }
    });
  }

  @override
  void dispose() {
    audio.removeListener(_refresh);
    sleepTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    if (audio.surahId != 0 &&
        _surahLoadingId != audio.surahId &&
        _surahFailedId != audio.surahId &&
        surah?['surah']?['id'] != audio.surahId) {
      unawaited(_loadSurah(audio.surahId));
    }
    setState(() {});
  }

  Future<void> _loadSurah(int id) async {
    if (_surahLoadingId == id) return;
    _surahLoadingId = id;
    final request = ++_surahRequest;
    try {
      final quran = await QuranData.load();
      if (mounted && request == _surahRequest) {
        setState(
          () => surah = {
            'surah': quran.surahs[id - 1],
            'ayahs': quran.surahAyahs(id),
          },
        );
      }
      _surahFailedId = null;
      if (Api.hasBackend) {
        unawaited(_loadTafsir(id, request));
      } else if (mounted) {
        final preferred =
            context.read<AppState>().settings['tafsirSlug'] as String?;
        unawaited(_loadOfflineTafsir(id, request, preferred));
      }
    } catch (_) {
      _surahFailedId = id;
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.surahLoadError);
      }
    } finally {
      _surahLoadingId = null;
    }
  }

  /// Optional server tafsir merged into the local text; failures are silent.
  Future<void> _loadTafsir(int id, int request) async {
    try {
      final response =
          await Api.instance.get('/quran/surahs/$id', {'tafsir': 'ar.muyassar'})
              as Map<String, dynamic>;
      _mergeTafsir({
        for (final ayah in (response['ayahs'] as List).cast<Map>())
          ayah['key'] as String: ayah['tafsir'],
      }, request);
    } catch (_) {
      // The surah text stays available offline without tafsir.
    }
  }

  /// Tafsir the user downloaded for offline reading (none is bundled).
  Future<void> _loadOfflineTafsir(
    int id,
    int request,
    String? preferred,
  ) async {
    try {
      final slug = await OfflineTafsir.instance.resolve(preferred);
      if (slug == null) return;
      final tafsir = await OfflineTafsir.instance.surah(slug, id);
      if (tafsir != null) _mergeTafsir(tafsir, request);
    } catch (_) {
      // The surah text stays available without tafsir.
    }
  }

  void _mergeTafsir(Map<String, Object?> tafsir, int request) {
    if (!mounted || request != _surahRequest || surah == null) return;
    setState(
      () => surah = {
        ...surah!,
        'ayahs': [
          for (final ayah in surah!['ayahs'] as List<Map<String, dynamic>>)
            {...ayah, 'tafsir': tafsir[ayah['key']]},
        ],
      },
    );
  }

  Future<void> _start(int id, int ayah, String? reciter) async {
    final state = context.read<AppState>();
    try {
      await audio.start(
        id,
        ayah,
        reciter ?? state.reciterId,
        continuousPlay: (state.settings['continuousPlay'] as bool?) ?? true,
      );
      if (mounted) await _loadSurah(id);
    } catch (_) {
      // The shared controller exposes the error for retry on both screens.
    }
  }

  Future<void> _changeReciter(String id) async {
    try {
      await context.read<AppState>().updateSettings({'reciterId': id});
      if (mounted) await _start(audio.surahId, audio.ayahNumber, id);
    } on ApiException catch (failure) {
      if (mounted) showToast(context, failure.message);
    }
  }

  void _setSleep(int? minutes) {
    sleepTimer?.cancel();
    setState(() {
      sleepAt = minutes == null
          ? null
          : DateTime.now().add(Duration(minutes: minutes));
      sleepTimer = minutes == null
          ? null
          : Timer(Duration(minutes: minutes), () {
              audio.pause();
              if (mounted) {
                setState(() {
                  sleepTimer = null;
                  sleepAt = null;
                });
              }
            });
    });
  }

  void _pickSleep() => showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)!.sleepTimer,
            style: FadlFonts.heading(size: 18),
          ),
          for (final minutes in [15, 30, 60])
            ListTile(
              title: Text(
                AppLocalizations.of(context)!.minutesShort(_number(minutes)),
              ),
              onTap: () {
                Navigator.pop(sheet);
                _setSleep(minutes);
              },
            ),
          if (sleepTimer != null)
            ListTile(
              title: Text(AppLocalizations.of(context)!.cancelTimer),
              onTap: () {
                Navigator.pop(sheet);
                _setSleep(null);
              },
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ayahs =
        (surah?['ayahs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final index = ayahs.isEmpty ? 0 : audio.index.clamp(0, ayahs.length - 1);
    final ayah = ayahs.isEmpty ? null : ayahs[index];
    final title = surah?['surah'] as Map<String, dynamic>?;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.listenToQuran)),
      body: audio.error != null && audio.playlist == null
          ? ErrorCard(
              message: audio.error!,
              onRetry: () =>
                  _start(widget.surahId, widget.startAyah, widget.reciterId),
            )
          : _surahFailedId == audio.surahId
          ? ErrorCard(
              message: AppLocalizations.of(context)!.surahLoadError,
              onRetry: () => _loadSurah(audio.surahId),
            )
          : audio.playlist == null ||
                title == null ||
                title['id'] != audio.surahId
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                FadlCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.record_voice_over_outlined,
                        color: FadlColors.sage,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                allReciters.any(
                                  (r) => r['id'] == audio.reciterId,
                                )
                                ? audio.reciterId
                                : null,
                            hint: Text(
                              '${audio.reciter?['nameAr'] ?? audio.reciterId}',
                            ),
                            isExpanded: true,
                            items: [
                              for (final r in allReciters)
                                DropdownMenuItem(
                                  value: r['id'] as String,
                                  child: Text(
                                    '${r['nameAr']} (${r['style']})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: audio.loading
                                ? null
                                : (id) {
                                    if (id != null) _changeReciter(id);
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [FadlColors.emerald, FadlColors.primary],
                      ),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 72,
                      color: FadlColors.goldLight,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.previousSurah,
                      onPressed: audio.surahId > 1
                          ? () => _start(audio.surahId - 1, 1, null)
                          : null,
                      icon: const Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.surahName(title['nameAr'] as String),
                        textAlign: TextAlign.center,
                        style: FadlFonts.heading(size: 25),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.nextSurah,
                      onPressed: audio.surahId < 114
                          ? () => _start(audio.surahId + 1, 1, null)
                          : null,
                      icon: const Icon(
                        Icons.keyboard_double_arrow_left_rounded,
                      ),
                    ),
                  ],
                ),
                Center(
                  child: Text(
                    '${AppLocalizations.of(context)!.versesCount(_number(title['ayahCount']))} • ${audio.reciter?['riwaya'] ?? ''}',
                    style: FadlFonts.ui(size: 13),
                  ),
                ),
                const SizedBox(height: 16),
                if (audio.error != null)
                  Text(
                    audio.error!,
                    textAlign: TextAlign.center,
                    style: FadlFonts.ui(size: 13, color: FadlColors.error),
                  ),
                if (ayah != null)
                  FadlCard(
                    child: Column(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.currentVerse(
                            _number(ayah['number']),
                            _number(ayahs.length),
                          ),
                          style: FadlFonts.ui(size: 14, color: FadlColors.sage),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${ayah['text']} ${ayahMarker(ayah['number'] as int)}',
                          textAlign: TextAlign.center,
                          style: FadlFonts.quran(
                            size: 24,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (ayah['tafsir'] is String) ...[
                          const Divider(),
                          Text(
                            ayah['tafsir'] as String,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: FadlFonts.ui(
                              size: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (audio.countdown > 0)
                  Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.repeatNow(_number(audio.countdown)),
                      style: FadlFonts.heading(
                        size: 18,
                        color: FadlColors.sage,
                      ),
                    ),
                  ),
                StreamBuilder<Duration>(
                  stream: audio.player.positionStream,
                  builder: (context, snapshot) {
                    final duration = audio.player.duration ?? Duration.zero;
                    final position = snapshot.data ?? Duration.zero;
                    final maximum = duration.inMilliseconds
                        .clamp(1, 1 << 31)
                        .toDouble();
                    return Column(
                      children: [
                        Slider(
                          value: position.inMilliseconds
                              .clamp(0, maximum.toInt())
                              .toDouble(),
                          max: maximum,
                          onChanged: duration == Duration.zero
                              ? null
                              : (value) => audio.player.seek(
                                  Duration(milliseconds: value.round()),
                                ),
                        ),
                        Row(
                          children: [
                            Text(mmss(position)),
                            const Spacer(),
                            Text(mmss(duration)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.previousVerse,
                      onPressed: audio.ayahNumber > 1
                          ? () => audio.seekAyah(audio.ayahNumber - 1)
                          : null,
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.skip_next_rounded
                            : Icons.skip_previous_rounded,
                        size: 32,
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.rewindTen,
                      onPressed: () => audio.player.seek(
                        audio.player.position - const Duration(seconds: 10),
                      ),
                      icon: const Icon(Icons.replay_10_rounded),
                    ),
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: audio.loading
                            ? null
                            : () => audio.playing
                                  ? audio.pause()
                                  : audio.resume(),
                        child: Icon(
                          audio.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 38,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.forwardTen,
                      onPressed: () => audio.player.seek(
                        audio.player.position + const Duration(seconds: 10),
                      ),
                      icon: const Icon(Icons.forward_10_rounded),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.nextVerse,
                      onPressed: audio.ayahNumber < audio.ayahs.length
                          ? () => audio.seekAyah(audio.ayahNumber + 1)
                          : null,
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.skip_previous_rounded
                            : Icons.skip_next_rounded,
                        size: 32,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.repeat_rounded),
                      label: Text(
                        AppLocalizations.of(context)!.memorizationSettings,
                      ),
                      onPressed: () => openMemorizationSheet(context),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.bedtime_outlined),
                      label: Text(
                        sleepAt == null
                            ? AppLocalizations.of(context)!.sleepTimer
                            : AppLocalizations.of(context)!.timerEndsAt(
                                MaterialLocalizations.of(
                                  context,
                                ).formatTimeOfDay(
                                  TimeOfDay.fromDateTime(sleepAt!),
                                ),
                              ),
                      ),
                      onPressed: _pickSleep,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DedicationBanner(
                  type: 'LISTENING',
                  label: AppLocalizations.of(context)!.dedicateListening,
                ),
              ],
            ),
    );
  }
}
