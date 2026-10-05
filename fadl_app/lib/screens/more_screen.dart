import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import 'assistant_screen.dart';
import 'downloads_screen.dart';
import 'devotion/fasting_tracker_screen.dart';
import 'devotion/hijri_calendar_screen.dart';
import 'devotion/prayer_tracker_screen.dart';
import 'devotion/zakat_screen.dart';
import 'dua_screen.dart';
import 'hadith/hadith_books_screen.dart';
import 'khatma_screen.dart';
import 'library_screen.dart';
import 'prayer/qibla_screen.dart';
import 'prayer/ramadan_screen.dart';
import 'quran/audio_library_screen.dart';
import 'settings_screen.dart';
import 'tasbeeh_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l =
        (AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('ar')));
    void open(Widget s) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));
    final items = <(IconData, String, String, Widget, bool)>[
      (
        Icons.check_circle_outline,
        l.prayerTracker,
        l.prayerTrackerMore,
        const PrayerTrackerScreen(),
        false,
      ),
      (
        Icons.calendar_month_outlined,
        l.hijriCalendar,
        l.hijriCalendarMore,
        const HijriCalendarScreen(),
        false,
      ),
      (
        Icons.restaurant_outlined,
        l.fastingTracker,
        l.fastingTrackerMore,
        const FastingTrackerScreen(),
        false,
      ),
      (
        Icons.calculate_outlined,
        l.zakatCalculator,
        l.zakatMore,
        const ZakatScreen(),
        false,
      ),
      (
        Icons.auto_stories_outlined,
        l.hadithLibrary,
        l.hadithMore,
        const HadithBooksScreen(),
        false,
      ),
      (
        Icons.smart_toy_outlined,
        l.quranAssistant,
        l.assistantMore,
        const AssistantScreen(),
        false,
      ),
      (
        Icons.headphones_outlined,
        l.audioLibrary,
        l.audioMore,
        const AudioLibraryScreen(),
        false,
      ),
      (
        Icons.local_library_outlined,
        l.library,
        l.libraryMore,
        const LibraryScreen(),
        false,
      ),
      (
        Icons.download_for_offline_outlined,
        l.downloads,
        l.downloadsMore,
        const DownloadsScreen(),
        false,
      ),
      (
        Icons.touch_app_outlined,
        l.tasbeehElectronic,
        l.tasbeehMore,
        const TasbeehScreen(),
        false,
      ),
      (
        Icons.donut_large_rounded,
        l.quranCompletion,
        l.planMore,
        const KhatmaScreen(),
        false,
      ),
      (
        Icons.explore_outlined,
        l.qiblaDirection,
        l.qiblaMore,
        const QiblaScreen(),
        false,
      ),
      (
        Icons.nightlight_round,
        l.ramadan,
        l.ramadanMore,
        const RamadanScreen(),
        false,
      ),
      (
        Icons.volunteer_activism_outlined,
        l.parentDua,
        l.parentMore,
        const DuaScreen(),
        true,
      ),
      (
        Icons.settings_outlined,
        l.settings,
        l.settingsMore,
        const SettingsScreen(),
        false,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.more)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (icon, title, subtitle, screen, gold) = items[i];
          return FadlCard(
            onTap: () => open(screen),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: gold ? FadlColors.goldLight : FadlColors.mintSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: gold ? FadlColors.primary : FadlColors.sage,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: FadlFonts.ui(size: 16, weight: FontWeight.w700),
                      ),
                      Text(subtitle, style: FadlFonts.ui(size: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded),
              ],
            ),
          );
        },
      ),
    );
  }
}
