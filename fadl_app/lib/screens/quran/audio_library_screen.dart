import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/audio_store.dart';
import '../../core/format.dart';
import '../../core/full_surah_reciters.dart';
import '../../core/quran_storage.dart';
import '../../core/reciters.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/live_search.dart';
import 'audio_player_screen.dart';
import 'full_surah_player_screen.dart';

String _uiNum(BuildContext context, Object number) =>
    Localizations.localeOf(context).languageCode == 'en'
    ? '$number'
    : arNum(number);

class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({super.key});

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  AppLocalizations get l =>
      (AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('ar')));

  final store = AudioStore.instance;
  final fullCatalog = FullSurahCatalog();
  bool fullSurahMode = false;
  int? fullReciterId;
  FullSurahEdition? fullEdition;
  String fullQuery = '';
  List<FullSurahEdition>? matchingFull;
  String style = 'الكل';
  List<Map<String, dynamic>> matchingReciters = reciters;
  String reciterQuery = '';
  Map<String, dynamic>? selected;
  String query = '';

  @override
  void initState() {
    super.initState();
    store.ready().catchError((_) {});
  }

  @override
  void dispose() {
    fullCatalog.dispose();
    super.dispose();
  }

  Future<void> _download(String reciterId, int surahId) async {
    try {
      await store.downloadSurah(reciterId, surahId);
    } on AudioDownloadException catch (failure) {
      if (mounted) showToast(context, failure.message);
    }
  }

  Future<void> _deleteDownload(String reciterId, Map<String, dynamic> surah) =>
      store.deleteSurah(reciterId, surah['id'] as int);

  Widget _downloadControl(String reciterId, Map<String, dynamic> surah) {
    final id = surah['id'] as int;
    final task = store.progress(reciterId, id);
    if (task != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              value: task.fraction,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_uiNum(context, (task.fraction * 100).floor())}${l.localeName == 'en' ? '%' : '٪'}',
            style: FadlFonts.ui(size: 12, color: FadlColors.sage),
          ),
          IconButton(
            tooltip: l.cancelDownload,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => store.cancel(reciterId, id),
          ),
        ],
      );
    }
    return switch (store.status(reciterId, id)) {
      DownloadStatus.complete => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_done_rounded,
            color: FadlColors.sage,
            semanticLabel: l.downloaded,
          ),
          IconButton(
            tooltip: l.deleteDownload,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _deleteDownload(reciterId, surah),
          ),
        ],
      ),
      DownloadStatus.partial => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.downloading_rounded,
            color: FadlColors.gold,
            semanticLabel: l.partiallyDownloaded,
          ),
          IconButton(
            tooltip: l.resumeDownload,
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _download(reciterId, id),
          ),
          IconButton(
            tooltip: l.deleteDownload,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _deleteDownload(reciterId, surah),
          ),
        ],
      ),
      DownloadStatus.none => IconButton(
        tooltip: l.downloadOffline,
        icon: const Icon(Icons.download_for_offline_outlined),
        onPressed: () => _download(reciterId, id),
      ),
    };
  }

  void _openSurah(Map<String, dynamic> surah) async {
    final reciter = selected!;
    try {
      await context.read<AppState>().updateSettings({
        'reciterId': reciter['id'] as String,
      });
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AudioPlayerScreen(
            surahId: surah['id'] as int,
            reciterId: reciter['id'] as String,
          ),
        ),
      );
    } on ApiException catch (failure) {
      if (mounted) showToast(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        fullSurahMode
            ? fullEdition?.nameAr ?? l.audioLibrary
            : selected?['nameAr'] as String? ?? l.audioLibrary,
      ),
      leading: (fullSurahMode ? fullReciterId != null : selected != null)
          ? IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => setState(() {
                if (fullSurahMode) {
                  if (fullEdition != null) {
                    fullEdition = null;
                  } else {
                    fullReciterId = null;
                  }
                } else {
                  selected = null;
                  matchingReciters = reciters;
                  reciterQuery = '';
                  query = '';
                }
              }),
            )
          : null,
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l.verseByVerse),
                selected: !fullSurahMode,
                onSelected: (_) => setState(() => fullSurahMode = false),
              ),
              ChoiceChip(
                label: Text(l.fullSurah),
                selected: fullSurahMode,
                onSelected: (_) => setState(() => fullSurahMode = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: fullSurahMode
              ? _fullSurahList()
              : selected == null
              ? _reciterList()
              : _surahList(),
        ),
      ],
    ),
  );

  String _styleLabel(String option) => switch (option) {
    'الكل' => l.all,
    'مرتل' => l.murattal,
    'مجود' => l.mujawwad,
    'معلم' => l.muallim,
    _ => option,
  };

  Widget _reciterList() => Builder(
    builder: (context) {
      final visible = matchingReciters
          .where((reciter) => style == 'الكل' || reciter['style'] == style)
          .toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: LiveSearch<Map<String, dynamic>>(
              hintText: l.searchReciter,
              onChanged: (text) => reciterQuery = text,
              search: (text) async => [
                for (final reciter in reciters)
                  if (matchesReciterSearch(reciter, text))
                    LiveSearchSuggestion(
                      reciter,
                      (l.localeName == 'en'
                              ? reciter['nameEn']
                              : reciter['nameAr'])
                          as String,
                      subtitle: reciter['nameEn'] as String,
                    ),
              ],
              onResults: (found) => setState(() {
                matchingReciters = reciterQuery.isEmpty
                    ? reciters
                    : [for (final suggestion in found) suggestion.value];
              }),
              onSelected: (reciter) => setState(() => selected = reciter),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                for (final option in [
                  'الكل',
                  'مرتل',
                  'مجود',
                  'معلم',
                  ...reciters
                      .map((r) => r['style'] as String)
                      .where((s) => !['مرتل', 'مجود', 'معلم'].contains(s))
                      .toSet(),
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(_styleLabel(option)),
                      selected: style == option,
                      labelStyle: style == option
                          ? null
                          : FadlFonts.ui(
                              size: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      side: style == option
                          ? null
                          : BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                      onSelected: (_) => setState(() => style = option),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final reciter = visible[index];
                final current =
                    reciter['id'] == context.watch<AppState>().reciterId;
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.headphones_outlined),
                  ),
                  title: Text(
                    reciter['nameAr'] as String,
                    style: FadlFonts.ui(size: 16, weight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${_styleLabel(reciter['style'] as String)} • ${reciter['riwaya']}',
                  ),
                  trailing: current
                      ? const Icon(Icons.check_circle, color: FadlColors.sage)
                      : const Icon(Icons.chevron_left),
                  onTap: () => setState(() => selected = reciter),
                );
              },
            ),
          ),
        ],
      );
    },
  );

  Widget _fullSurahList() => FutureBuilder<List<FullSurahEdition>>(
    future: fullCatalog.load(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorCard(
          message: l.fullSurahLoadError('${snapshot.error}'),
          onRetry: () => setState(() {}),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final editions = snapshot.data!;
      if (fullEdition != null) return _fullSurahChapters(fullEdition!);
      if (fullReciterId != null) {
        final reciterEditions = editions.where(
          (e) => e.reciterId == fullReciterId,
        );
        return ListView(
          children: [
            ListTile(title: Text(l.chooseEdition)),
            for (final edition in reciterEditions)
              ListTile(
                title: Text(edition.nameAr),
                subtitle: Text(edition.editionName),
                onTap: () => setState(() => fullEdition = edition),
              ),
          ],
        );
      }
      final shown = matchingFull ?? editions;
      final grouped = <int, List<FullSurahEdition>>{};
      for (final edition in shown) {
        grouped.putIfAbsent(edition.reciterId, () => []).add(edition);
      }
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(l.streamingNotice),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: LiveSearch<FullSurahEdition>(
              hintText: l.searchReciterBoth,
              onChanged: (text) => fullQuery = text,
              search: (text) async => [
                for (final edition in editions)
                  if (edition.matches(text))
                    LiveSearchSuggestion(
                      edition,
                      edition.nameAr,
                      subtitle: edition.editionName,
                    ),
              ],
              onResults: (found) => setState(
                () => matchingFull = fullQuery.isEmpty
                    ? null
                    : [for (final suggestion in found) suggestion.value],
              ),
              onSelected: (edition) => setState(() {
                fullReciterId = edition.reciterId;
                fullEdition = edition;
              }),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final entry in grouped.entries)
                  ListTile(
                    title: Text(entry.value.first.nameAr),
                    subtitle: Text(
                      l.editionsCount(
                        '${entry.value.length}',
                        entry.value.first.editionName,
                      ),
                    ),
                    onTap: () => setState(() => fullReciterId = entry.key),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _fullSurahChapters(FullSurahEdition edition) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: QuranIndex.surahs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorCard(
              message: '${snapshot.error}',
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              ListTile(
                title: Text(edition.editionName),
                subtitle: Text(l.fullSurah),
              ),
              for (final surah in snapshot.data!)
                if (edition.surahs.contains(surah['id']))
                  ListTile(
                    title: Text(surah['nameAr'] as String),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => FullSurahPlayerScreen(
                          edition: edition,
                          surah: surah['id'] as int,
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      );

  Widget _surahList() => FutureBuilder<List<Map<String, dynamic>>>(
    future: QuranIndex.surahs(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorCard(
          message: '${snapshot.error}',
          onRetry: () => setState(() {}),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final surahs = snapshot.data!
          .where((surah) => matchesSurahSearch(surah, query))
          .toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: LiveSearch<Map<String, dynamic>>(
              hintText: l.searchSurah,
              onChanged: (text) => setState(() => query = text),
              search: (q) async => [
                for (final s in snapshot.data!)
                  if (matchesSurahSearch(s, q))
                    LiveSearchSuggestion(
                      s,
                      l.surahName('${s['nameAr']}'),
                      subtitle: l.versesCount(_uiNum(context, s['ayahCount'])),
                    ),
              ],
              onSelected: _openSurah,
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) => ListView.builder(
                itemCount: surahs.length,
                itemBuilder: (context, index) {
                  final surah = surahs[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(_uiNum(context, surah['id'])),
                    ),
                    title: Text(
                      l.surahName('${surah['nameAr']}'),
                      style: FadlFonts.heading(size: 17),
                    ),
                    subtitle: Text(
                      l.versesCount(_uiNum(context, surah['ayahCount'])),
                    ),
                    trailing: _downloadControl(
                      selected!['id'] as String,
                      surah,
                    ),
                    onTap: () => _openSurah(surah),
                  );
                },
              ),
            ),
          ),
        ],
      );
    },
  );
}
