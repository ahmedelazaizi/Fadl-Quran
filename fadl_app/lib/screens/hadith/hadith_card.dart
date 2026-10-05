import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';
import 'hadith_detail_screen.dart';

const _amber = Color(0xFFB7791F);

/// Color for a hadith grade: green for sahih/hasan, red for weak/fabricated,
/// amber when the source gives no (or an unknown) grade.
Color gradeColor(String? grade) {
  if (grade == null || grade.trim().isEmpty) return _amber;
  if (RegExp('ضعيف|موضوع|منكر|شاذ|باطل|لا أصل').hasMatch(grade)) {
    return FadlColors.error;
  }
  if (RegExp('صحيح|حسن').hasMatch(grade)) return FadlColors.sage;
  return _amber;
}

/// "صحيح" badge, or "غير محدد" when the source has no grade.
class GradeBadge extends StatelessWidget {
  const GradeBadge(this.grade, {super.key});
  final String? grade;

  @override
  Widget build(BuildContext context) {
    final g = grade?.trim();
    return Badge2(
      g == null || g.isEmpty ? prayerL(context).hadithUnknownGrade : g,
      color: gradeColor(g),
    );
  }
}

/// Opens an external link (dorar.net / sunnah.com) in the browser.
Future<void> openExternal(BuildContext context, String? url) async {
  final uri = url == null ? null : Uri.tryParse(url);
  final ok =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    showToast(context, prayerL(context).hadithLinkError);
  }
}

String hadithShareText(Map<String, dynamic> h) =>
    '${h['textAr'] ?? ''}\n\n[${h['reference'] ?? ''}]${h['grade'] != null ? ' — ${h['grade']}' : ''}\n— من تطبيق فضل';

Future<void> copyHadith(BuildContext context, Map<String, dynamic> h) async {
  await Clipboard.setData(ClipboardData(text: hadithShareText(h)));
  if (context.mounted) showToast(context, prayerL(context).hadithCopied);
}

void shareHadith(Map<String, dynamic> h) =>
    SharePlus.instance.share(ShareParams(text: hadithShareText(h)));

/// Hadith card used in the hadith library, search results and the assistant.
class HadithCard extends StatefulWidget {
  const HadithCard({
    super.key,
    required this.hadith,
    this.maxLines = 8,
    this.showActions = false,
    this.showBook = true,
  });
  final Map<String, dynamic> hadith;
  final int maxLines;

  /// Shows copy / share / dorar / sunnah.com buttons under the text.
  final bool showActions;
  final bool showBook;

  @override
  State<HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<HadithCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.hadith;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = (h['textAr'] as String? ?? '').trim();
    final book = h['book'] as Map<String, dynamic>?;
    final links = h['links'] as Map<String, dynamic>?;
    final textStyle = FadlFonts.scripture(
      size: 19,
      height: 1.9,
      color: scheme.onSurface,
    );

    return FadlCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => HadithDetailScreen(hadith: h))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (h['number'] != null)
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dark
                        ? FadlColors.darkSurfaceHigh
                        : FadlColors.goldSoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: FadlColors.gold.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    arNum(h['number']),
                    style: FadlFonts.ui(
                      size: 12,
                      weight: FontWeight.w700,
                      color: dark ? FadlColors.goldLight : FadlColors.primary,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showBook && book != null)
                      Text(
                        book['nameAr'] as String? ?? '',
                        textDirection: TextDirection.rtl,
                        style: FadlFonts.ui(
                          size: 13,
                          weight: FontWeight.w700,
                          color: dark ? FadlColors.mint : FadlColors.sage,
                        ),
                      ),
                    if ((h['chapterAr'] as String?)?.isNotEmpty ?? false)
                      Text(
                        h['chapterAr'] as String,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FadlFonts.ui(
                          size: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              GradeBadge(h['grade'] as String?),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: textStyle),
                maxLines: widget.maxLines,
                textDirection: TextDirection.rtl,
              )..layout(maxWidth: constraints.maxWidth);
              final overflows = painter.didExceedMaxLines;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text,
                    textDirection: TextDirection.rtl,
                    style: textStyle,
                    maxLines: _expanded ? null : widget.maxLines,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                  ),
                  if (overflows)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          _expanded
                              ? prayerL(context).hadithShowLess
                              : prayerL(context).hadithReadMore,
                          style: FadlFonts.ui(
                            size: 13,
                            weight: FontWeight.w700,
                            color: FadlColors.gold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if ((h['reference'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 15,
                  color: FadlColors.gold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    h['reference'] as String,
                    textDirection: TextDirection.rtl,
                    style: FadlFonts.ui(
                      size: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (widget.showActions) ...[
            const Divider(height: 20),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _ActionChip(
                  icon: Icons.copy_rounded,
                  label: prayerL(context).hadithCopy,
                  onTap: () => copyHadith(context, h),
                ),
                _ActionChip(
                  icon: Icons.share_outlined,
                  label: prayerL(context).hadithShare,
                  onTap: () => shareHadith(h),
                ),
                if (links?['dorar'] != null)
                  _ActionChip(
                    icon: Icons.verified_outlined,
                    label: prayerL(context).hadithVerify,
                    onTap: () =>
                        openExternal(context, links!['dorar'] as String),
                  ),
                if (links?['sunnah'] != null)
                  _ActionChip(
                    icon: Icons.open_in_new_rounded,
                    label: 'sunnah.com',
                    onTap: () =>
                        openExternal(context, links!['sunnah'] as String),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).brightness == Brightness.dark
          ? FadlColors.mint
          : FadlColors.sage,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      visualDensity: VisualDensity.compact,
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(
      label,
      style: FadlFonts.ui(size: 12.5, weight: FontWeight.w600),
    ),
  );
}
