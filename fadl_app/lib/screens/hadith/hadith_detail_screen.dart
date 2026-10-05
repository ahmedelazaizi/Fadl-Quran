import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';
import 'hadith_card.dart';

/// Full hadith: Arabic text, English translation, reference, grade and
/// verification links.
class HadithDetailScreen extends StatefulWidget {
  const HadithDetailScreen({super.key, required this.hadith});
  final Map<String, dynamic> hadith;

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen> {
  bool _showEnglish = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.hadith;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final book = h['book'] as Map<String, dynamic>?;
    final links = h['links'] as Map<String, dynamic>?;
    final grade = (h['grade'] as String?)?.trim();
    final gradeSource = (h['gradeSource'] as String?)?.trim();
    final textEn = (h['textEn'] as String?)?.trim() ?? '';
    final narratorEn = (h['narratorEn'] as String?)?.trim() ?? '';
    final hasGrade = grade != null && grade.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(book?['nameAr'] as String? ?? prayerL(context).hadithUnit),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if ((h['chapterAr'] as String?)?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.bookmark_border_rounded,
                    size: 18,
                    color: FadlColors.gold,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      h['chapterAr'] as String,
                      textDirection: TextDirection.rtl,
                      style: FadlFonts.ui(size: 14, weight: FontWeight.w600),
                    ),
                  ),
                  if (h['number'] != null)
                    Badge2(
                      prayerL(
                        context,
                      ).hadithNumber(prayerNumber(context, h['number'])),
                      color: FadlColors.gold,
                    ),
                ],
              ),
            ),
          FadlCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  (h['textAr'] as String? ?? '').trim(),
                  textDirection: TextDirection.rtl,
                  style: FadlFonts.scripture(
                    size: 22,
                    height: 2.0,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  color: FadlColors.gold.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                if ((h['reference'] as String?)?.isNotEmpty ?? false)
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        size: 18,
                        color: FadlColors.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          h['reference'] as String,
                          textDirection: TextDirection.rtl,
                          style: FadlFonts.ui(
                            size: 14,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: gradeColor(grade).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasGrade
                            ? Icons.verified_rounded
                            : Icons.help_outline_rounded,
                        color: gradeColor(grade),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasGrade
                              ? prayerL(context).hadithGrade(grade) +
                                    (gradeSource != null &&
                                            gradeSource.isNotEmpty
                                        ? ' — $gradeSource'
                                        : '')
                              : prayerL(context).hadithGradeNotSpecified,
                          style: FadlFonts.ui(
                            size: 14,
                            weight: FontWeight.w700,
                            color: gradeColor(grade),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (textEn.isNotEmpty || narratorEn.isNotEmpty) ...[
            const SizedBox(height: 12),
            FadlCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.translate_rounded,
                      color: FadlColors.sage,
                    ),
                    title: Text(
                      prayerL(context).hadithEnglishTranslation,
                      style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                    ),
                    trailing: Icon(
                      _showEnglish
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    onTap: () => setState(() => _showEnglish = !_showEnglish),
                  ),
                  if (_showEnglish)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (narratorEn.isNotEmpty)
                              Text(
                                narratorEn,
                                style: FadlFonts.ui(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: dark
                                      ? FadlColors.mint
                                      : FadlColors.sage,
                                ),
                              ),
                            if (textEn.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              SelectableText(
                                textEn,
                                style: FadlFonts.ui(size: 15, height: 1.6),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => copyHadith(context, h),
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(prayerL(context).hadithCopy),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => shareHadith(h),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(prayerL(context).hadithShare),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (links?['dorar'] != null)
            FilledButton.icon(
              onPressed: () => openExternal(context, links!['dorar'] as String),
              icon: const Icon(Icons.verified_outlined),
              label: Text(prayerL(context).hadithVerify),
            ),
          if (links?['sunnah'] != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () =>
                  openExternal(context, links!['sunnah'] as String),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(prayerL(context).hadithViewSunnah),
            ),
          ],
          const SizedBox(height: 16),
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: FadlColors.goldSoft,
              foregroundColor: FadlColors.primary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: FadlColors.gold.withValues(alpha: 0.6)),
              ),
            ),
            onPressed: () => dedicate(
              context,
              'READING',
              refKey: h['id'] != null ? 'hadith:${h['id']}' : null,
            ),
            icon: const Icon(
              Icons.volunteer_activism_rounded,
              color: FadlColors.gold,
            ),
            label: Text(
              prayerL(context).hadithDedicate,
              style: FadlFonts.ui(
                size: 15,
                weight: FontWeight.w700,
                color: FadlColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
