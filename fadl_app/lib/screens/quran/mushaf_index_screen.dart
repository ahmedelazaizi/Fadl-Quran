import 'package:flutter/material.dart';

import '../../core/quran_data.dart';
import '../../core/format.dart';
import '../../core/quran_storage.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/common.dart';
import '../../widgets/live_search.dart';
import 'mushaf_reader_screen.dart';
import 'quran_learning_screen.dart';
import 'quran_widgets.dart';

/// Mushaf index: surahs and ajzaa with a "continue reading" card.
class MushafIndexScreen extends StatefulWidget {
  const MushafIndexScreen({super.key});

  @override
  State<MushafIndexScreen> createState() => _MushafIndexScreenState();
}

class _MushafIndexScreenState extends State<MushafIndexScreen> {
  String _query = '';
  @override
  void initState() {
    super.initState();
    LastReadStore.instance.loadLocal().then(
      (_) => LastReadStore.instance.refresh(),
    );
  }

  Future<void> _open(
    BuildContext context,
    int page, {
    String? highlight,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MushafReaderScreen(initialPage: page, highlightAyahKey: highlight),
      ),
    );
    // The reader updates the shared local position before returning.
  }

  Future<void> _openJuz(BuildContext context, int juz) async {
    final page = (await QuranData.load()).juzStartPage(juz);
    if (context.mounted) await _open(context, page);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.mushafTitle),
          bottom: TabBar(
            labelStyle: FadlFonts.ui(size: 15, weight: FontWeight.w700),
            unselectedLabelStyle: FadlFonts.ui(size: 15),
            indicatorColor: FadlColors.gold,
            tabs: [
              Tab(text: AppLocalizations.of(context)!.surahsTab),
              Tab(text: AppLocalizations.of(context)!.juzTab),
            ],
          ),
        ),
        body: Column(
          children: [
            _LastReadCard(
              onOpen: (page, key) => _open(context, page, highlight: key),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: FadlCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const QuranLearningScreen(),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.quiz_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.quizShortcut,
                        style: FadlFonts.ui(size: 16, weight: FontWeight.w700),
                      ),
                    ),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.arrow_forward_ios_rounded,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  AsyncView<List<Map<String, dynamic>>>(
                    load: QuranIndex.surahs,
                    builder: (context, surahs, reload) =>
                        _surahList(context, surahs),
                  ),
                  _juzList(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _surahList(BuildContext context, List<Map<String, dynamic>> surahs) {
    final l = AppLocalizations.of(context)!;
    String n(Object? number) =>
        Localizations.localeOf(context).languageCode == 'ar'
        ? arNum(number ?? 0)
        : '$number';
    final filtered = surahs
        .where((s) => matchesSurahSearch(s, _query))
        .toList();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: filtered.length + 1,
      separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 12 : 8),
      itemBuilder: (context, i) {
        if (i == 0) {
          return LiveSearch<Map<String, dynamic>>(
            hintText: l.searchMushaf,
            onChanged: (v) => setState(() => _query = v),
            search: (q) async => [
              for (final s in surahs)
                if (matchesSurahSearch(s, q))
                  LiveSearchSuggestion(
                    s,
                    l.surahName(s['nameAr'] as String),
                    subtitle: l.pageNumber(n(s['startPage'])),
                  ),
            ],
            onSelected: (s) => _open(context, s['startPage'] as int),
          );
        }
        final s = filtered[i - 1];
        final meccan = s['revelationType'] == 'MECCAN';
        return FadlCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => _open(context, s['startPage'] as int),
          child: Row(
            children: [
              NumberBadge(s['id'] as int),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.surahName(s['nameAr'] as String),
                      style: FadlFonts.heading(size: 18),
                    ),
                    Text(
                      l.surahSummary(n(s['ayahCount']), n(s['startPage'])),
                      style: FadlFonts.ui(
                        size: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Badge2(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? ((s['revelationTypeAr'] as String?) ??
                          (meccan ? l.meccan : l.medinan))
                    : (meccan ? l.meccan : l.medinan),
                color: meccan ? FadlColors.sage : const Color(0xFF8A6A1F),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _juzList(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: 30,
      itemBuilder: (context, i) => FadlCard(
        padding: const EdgeInsets.all(8),
        onTap: () => _openJuz(context, i + 1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NumberBadge(i + 1),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.juzName(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? juzNamesAr[i]
                    : '${i + 1}',
              ),
              style: FadlFonts.ui(size: 13, weight: FontWeight.w700),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _LastReadCard extends StatelessWidget {
  const _LastReadCard({required this.onOpen});
  final void Function(int page, String key) onOpen;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReadingPosition?>(
      valueListenable: LastReadStore.instance,
      builder: (context, position, _) {
        if (position == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: FadlCard(
            color: FadlColors.emerald,
            onTap: () => onOpen(position.page, position.key),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_stories_rounded,
                  color: FadlColors.goldLight,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.continueReading,
                        style: FadlFonts.ui(
                          size: 12,
                          color: FadlColors.onEmerald,
                        ),
                      ),
                      Text(
                        position.surahName == null
                            ? AppLocalizations.of(
                                context,
                              )!.verseNumber(position.key)
                            : AppLocalizations.of(context)!.surahAndVerse(
                                position.surahName!,
                                Localizations.localeOf(context).languageCode ==
                                        'ar'
                                    ? arNum(position.number ?? 1)
                                    : '${position.number ?? 1}',
                              ),
                        style: FadlFonts.heading(size: 16, color: Colors.white),
                      ),
                      Text(
                        position.juz == null
                            ? AppLocalizations.of(context)!.pageNumber(
                                Localizations.localeOf(context).languageCode ==
                                        'ar'
                                    ? arNum(position.page)
                                    : '${position.page}',
                              )
                            : AppLocalizations.of(context)!.readingPageJuz(
                                Localizations.localeOf(context).languageCode ==
                                        'ar'
                                    ? arNum(position.page)
                                    : '${position.page}',
                                Localizations.localeOf(context).languageCode ==
                                        'ar'
                                    ? arNum(position.juz!)
                                    : '${position.juz}',
                              ),
                        style: FadlFonts.ui(
                          size: 12,
                          color: FadlColors.onEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_back_ios_new_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: FadlColors.goldLight,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
