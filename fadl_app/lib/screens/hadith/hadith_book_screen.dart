import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/offline_hadith.dart';
import '../../core/theme.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';
import '../../widgets/live_search.dart';
import 'hadith_list_screen.dart';

/// Chapters ("الكتب/الأبواب") of a hadith collection.
class HadithBookScreen extends StatefulWidget {
  const HadithBookScreen({super.key, required this.slug, required this.nameAr});
  final String slug;
  final String nameAr;

  @override
  State<HadithBookScreen> createState() => _HadithBookScreenState();
}

class _HadithBookScreenState extends State<HadithBookScreen> {
  String _filter = '';

  void _open(BuildContext context, String title, {int? chapterId}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HadithListScreen(
            slug: widget.slug,
            title: title,
            chapterId: chapterId,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(widget.nameAr)),
      body: AsyncView<Map<String, dynamic>>(
        load: () async => Api.hasBackend
            ? await Api.instance.get('/hadith/books/${widget.slug}')
                  as Map<String, dynamic>
            : await OfflineHadith.instance.book(widget.slug) ??
                  <String, dynamic>{
                    'nameAr': widget.nameAr,
                    'chapters': [],
                    'hadithCount': 0,
                  },
        builder: (context, book, _) {
          if (!Api.hasBackend &&
              !OfflineHadith.instance.isDownloaded(widget.slug)) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(prayerL(context).hadithMissingBook),
              ),
            );
          }
          final chapters = (book['chapters'] as List? ?? const [])
              .cast<Map<String, dynamic>>();
          final q = _filter.trim();
          final visible = q.isEmpty
              ? chapters
              : chapters
                    .where(
                      (c) => matchesLiveSearch(c['nameAr'] as String? ?? '', q),
                    )
                    .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              FadlCard(
                color: FadlColors.emerald,
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_stories_rounded,
                      color: FadlColors.goldLight,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book['nameAr'] as String? ?? widget.nameAr,
                            style: FadlFonts.heading(
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                          if (book['authorAr'] != null)
                            Text(
                              book['authorAr'] as String,
                              style: FadlFonts.ui(
                                size: 12.5,
                                color: FadlColors.onEmerald,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          prayerNumber(context, book['hadithCount'] ?? 0),
                          style: FadlFonts.heading(
                            size: 18,
                            color: FadlColors.goldLight,
                          ),
                        ),
                        Text(
                          prayerL(context).hadithUnit,
                          style: FadlFonts.ui(
                            size: 11,
                            color: FadlColors.onEmerald,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LiveSearch<Map<String, dynamic>>(
                hintText: prayerL(context).hadithChapterSearch,
                prefixIcon: Icons.filter_list_rounded,
                onChanged: (v) => setState(() => _filter = v),
                search: (q) async => [
                  for (final c in chapters)
                    if (matchesLiveSearch(c['nameAr'] as String? ?? '', q))
                      LiveSearchSuggestion(c, c['nameAr'] as String),
                ],
                onSelected: (c) => _open(
                  context,
                  c['nameAr'] as String? ?? widget.nameAr,
                  chapterId: (c['id'] as num).toInt(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _open(context, widget.nameAr),
                icon: const Icon(Icons.format_list_numbered_rtl_rounded),
                label: Text(prayerL(context).hadithShowAll),
              ),
              SectionTitle(
                prayerL(
                  context,
                ).hadithChapters(prayerNumber(context, chapters.length)),
              ),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    prayerL(context).hadithNoChapters,
                    textAlign: TextAlign.center,
                    style: FadlFonts.ui(color: scheme.onSurfaceVariant),
                  ),
                ),
              for (final c in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FadlCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    onTap: () => _open(
                      context,
                      c['nameAr'] as String? ?? widget.nameAr,
                      chapterId: (c['id'] as num).toInt(),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: dark
                                ? FadlColors.darkSurfaceHigh
                                : FadlColors.mintSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            prayerNumber(context, c['number'] ?? ''),
                            style: FadlFonts.ui(
                              size: 12.5,
                              weight: FontWeight.w700,
                              color: dark ? FadlColors.mint : FadlColors.sage,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            c['nameAr'] as String? ?? '',
                            style: FadlFonts.ui(
                              size: 15,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Badge2(
                          prayerL(
                            context,
                          ).hadithCount(prayerNumber(context, c['count'] ?? 0)),
                          color: FadlColors.gold,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
