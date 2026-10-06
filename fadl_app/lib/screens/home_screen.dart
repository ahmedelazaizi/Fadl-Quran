import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/prayer_labels.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/local_user_data.dart';
import 'devotion/offline_next_prayer.dart';
import 'devotion/prayer_tracker_screen.dart';
import 'devotion/quick_prayer_record.dart';
import '../core/quran_data.dart';
import '../core/quran_storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/location_picker.dart';
import 'assistant_screen.dart';
import 'dua_screen.dart';
import 'hadith/hadith_books_screen.dart';
import 'khatma_screen.dart';
import 'prayer/qibla_screen.dart';
import 'prayer/ramadan_screen.dart';
import 'quran/mushaf_reader_screen.dart';
import 'quran/audio_library_screen.dart';
import 'settings_screen.dart';
import 'shell.dart';
import 'tasbeeh_screen.dart';

String _uiNum(BuildContext context, Object number) =>
    Localizations.localeOf(context).languageCode == 'en'
    ? '$number'
    : arNum(number);

String _uiTime(BuildContext context, String time) {
  if (Localizations.localeOf(context).languageCode == 'ar') return hm12(time);
  final parts = time.split(':');
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _view = GlobalKey<AsyncViewState<Map<String, dynamic>>>();

  @override
  void initState() {
    super.initState();
    LastReadStore.instance.loadLocal().then(
      (_) => LastReadStore.instance.refresh(),
    );
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final locationKey = context.select<AppState, Object?>(
      (s) => '${s.settings['latitude']}|${s.settings['calcMethod']}',
    );
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: FadlColors.emerald,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: FadlColors.goldLight,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Text('فضل', style: FadlFonts.heading(size: 24)),
          ],
        ),
        actions: [
          // The assistant search needs the backend.
          if (Api.hasBackend)
            IconButton(
              tooltip: prayerL(context).a11ySearch,
              icon: const Icon(Icons.search_rounded),
              onPressed: () => _open(const AssistantScreen()),
            ),
          IconButton(
            tooltip: prayerL(context).settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _open(const SettingsScreen()),
          ),
        ],
      ),
      body: !Api.hasBackend
          ? const OfflineHomeBody()
          : RefreshIndicator(
              onRefresh: () async => _view.currentState?.reload(),
              child: AsyncView<Map<String, dynamic>>(
                key: _view,
                reloadToken: locationKey,
                load: () async =>
                    await Api.instance.get('/me/dashboard')
                        as Map<String, dynamic>,
                builder: (context, data, reload) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _DedicationHeader(),
                    const SizedBox(height: 14),
                    data['prayer'] != null
                        ? _NextPrayerCard(
                            data['prayer'] as Map<String, dynamic>,
                            onExpired: reload,
                          )
                        : _SetLocationCard(),
                    _HomeShortcuts(
                      onKhatmaOpen: () => _open(const KhatmaScreen()),
                    ),
                    const SizedBox(height: 18),
                    if (data['dailyAyah'] != null) ...[
                      _DailyAyahCard(data['dailyAyah'] as Map<String, dynamic>),
                      const SizedBox(height: 14),
                    ],
                    _KhatmaCard(
                      data['khatma'] as Map<String, dynamic>?,
                      onOpen: () => _open(const KhatmaScreen()),
                    ),
                    const SizedBox(height: 14),
                    if (data['dailyHadith'] != null)
                      _DailyHadithCard(
                        data['dailyHadith'] as Map<String, dynamic>,
                        onMore: () => _open(const HadithBooksScreen()),
                      ),
                    const SizedBox(height: 14),
                    _DailyDedicationCard(),
                  ],
                ),
              ),
            ),
    );
  }
}

class _HomeShortcuts extends StatelessWidget {
  const _HomeShortcuts({required this.onKhatmaOpen});

  final VoidCallback onKhatmaOpen;

  void _open(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(title),
      Text(subtitle, style: FadlFonts.ui(size: 12.5)),
      const SizedBox(height: 10),
    ],
  );

  Widget _tiles(List<Widget> shortcuts) => GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 0.78,
    children: shortcuts,
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        (AppLocalizations.of(context) ??
                lookupAppLocalizations(const Locale('ar')))
            .quranReading,
        (AppLocalizations.of(context) ??
                lookupAppLocalizations(const Locale('ar')))
            .quranReadingDescription,
      ),
      _tiles([
        IconTile(
          icon: Icons.menu_book_rounded,
          label:
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ar')))
                  .mushaf,
          onTap: () => AppShell.of(context)?.goTo(1),
        ),
        IconTile(
          icon: Icons.headphones_outlined,
          label:
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ar')))
                  .reciters,
          onTap: () => _open(context, const AudioLibraryScreen()),
        ),
        IconTile(
          icon: Icons.donut_large_rounded,
          label:
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ar')))
                  .quranCompletion,
          onTap: onKhatmaOpen,
        ),
      ]),
      const SizedBox(height: 10),
      _heading(
        (AppLocalizations.of(context) ??
                lookupAppLocalizations(const Locale('ar')))
            .worship,
        (AppLocalizations.of(context) ??
                lookupAppLocalizations(const Locale('ar')))
            .worshipDescription,
      ),
      const _WorshipHomeAction(),
      const SizedBox(height: 10),
      _tiles([
        IconTile(
          icon: Icons.schedule_rounded,
          label:
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ar')))
                  .prayerTimes,
          onTap: () => AppShell.of(context)?.goTo(3),
        ),
        IconTile(
          icon: Icons.verified_outlined,
          label:
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ar')))
                  .athkar,
          onTap: () => AppShell.of(context)?.goTo(2),
        ),
        IconTile(
          icon: Icons.explore_outlined,
          label:
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ar')))
                  .qibla,
          onTap: () => _open(context, const QiblaScreen()),
        ),
      ]),
      const SizedBox(height: 10),
      _heading(
        (AppLocalizations.of(context) ??
                lookupAppLocalizations(const Locale('ar')))
            .dailyTools,
        (AppLocalizations.of(context) ??
                lookupAppLocalizations(const Locale('ar')))
            .dailyToolsDescription,
      ),
      _tiles([
        IconTile(
          icon: Icons.touch_app_outlined,
          label:
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ar')))
                  .tasbeeh,
          onTap: () => _open(context, const TasbeehScreen()),
        ),
        IconTile(
          icon: Icons.volunteer_activism_outlined,
          label:
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ar')))
                  .parentDua,
          gold: true,
          onTap: () => _open(context, const DuaScreen()),
        ),
        IconTile(
          icon: Icons.nightlight_round,
          label:
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ar')))
                  .ramadan,
          onTap: () => _open(context, const RamadanScreen()),
        ),
      ]),
      TextButton.icon(
        onPressed: () => AppShell.of(context)?.goTo(4),
        icon: const Icon(Icons.apps_rounded),
        label: Text(
          (AppLocalizations.of(context) ??
                  lookupAppLocalizations(const Locale('ar')))
              .moreTools,
        ),
      ),
    ],
  );
}

class _WorshipHomeAction extends StatelessWidget {
  const _WorshipHomeAction();

  @override
  Widget build(BuildContext context) => Card(
    child: Row(
      children: [
        const QuickPrayerRecord(),
        Expanded(
          child: ListTile(
            title: Text(
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ar')))
                  .prayerTracker,
            ),
            subtitle: Text(
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ar')))
                  .prayerTrackerDescription,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const PrayerTrackerScreen(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DedicationHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final name = context.watch<AppState>().dedicatee;
    return FadlCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: FadlColors.surfaceLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'فضل',
                style: FadlFonts.heading(size: 22, color: FadlColors.sage),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('فضل', style: FadlFonts.heading(size: 20)),
                    ),
                    Badge2(
                      (AppLocalizations.of(context) ??
                              lookupAppLocalizations(const Locale('ar')))
                          .appTagline,
                    ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    style: FadlFonts.ui(size: 13),
                    children: [
                      TextSpan(
                        text:
                            (AppLocalizations.of(context) ??
                                    lookupAppLocalizations(const Locale('ar')))
                                .dedicationPrefix,
                      ),
                      TextSpan(
                        text: name,
                        style: FadlFonts.ui(
                          size: 13,
                          weight: FontWeight.w800,
                          color: FadlColors.sage,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'اللهم اجعل هذا العمل نوراً في قبره ورفعةً لدرجاته',
                  style: FadlFonts.ui(size: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks the same short ayah for everyone on a given calendar [date].
Map<String, dynamic> pickDailyAyah(QuranData quran, DateTime date) {
  final candidates = <Map<String, dynamic>>[];
  for (var n = 1; n <= 6236; n++) {
    final ayah = quran.globalAyah(n);
    final length = (ayah?['text'] as String?)?.length ?? 0;
    if (length >= 40 && length <= 110) candidates.add(ayah!);
  }
  final day = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(2000)).inDays;
  // A prime stride spreads consecutive days across the whole mushaf.
  return candidates[(day * 7919) % candidates.length];
}

/// Home content built only from local data, used when no backend is set.
class OfflineHomeBody extends StatefulWidget {
  const OfflineHomeBody({super.key});

  @override
  State<OfflineHomeBody> createState() => _OfflineHomeBodyState();
}

class _OfflineHomeBodyState extends State<OfflineHomeBody> {
  Future<List<Map<String, dynamic>>> _plans = LocalUserData.instance.khatmas(
    status: 'ACTIVE',
  );
  late final Future<Map<String, dynamic>> _dailyAyah = QuranData.load().then((
    quran,
  ) {
    final ayah = pickDailyAyah(quran, DateTime.now());
    final surah = quran.surahs[(ayah['surahId'] as int) - 1];
    return {'ayah': ayah, 'surah': surah};
  });

  Future<void> _openKhatma() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const KhatmaScreen()));
    if (mounted) {
      setState(() => _plans = LocalUserData.instance.khatmas(status: 'ACTIVE'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _DedicationHeader(),
        ValueListenableBuilder<ReadingPosition?>(
          valueListenable: LastReadStore.instance,
          builder: (context, position, _) => position == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _ContinueReadingCard(position),
                ),
        ),
        const SizedBox(height: 14),
        const OfflineNextPrayer(),
        _HomeShortcuts(onKhatmaOpen: _openKhatma),
        const SizedBox(height: 18),
        FutureBuilder<Map<String, dynamic>>(
          future: _dailyAyah,
          builder: (context, snap) => snap.hasData
              ? _DailyAyahCard(
                  snap.data!,
                  title:
                      (AppLocalizations.of(context) ??
                              lookupAppLocalizations(const Locale('ar')))
                          .dailyAyah,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _plans,
          builder: (context, snapshot) => snapshot.hasData
              ? _KhatmaCard(
                  snapshot.data!.isEmpty ? null : snapshot.data!.first,
                  onOpen: _openKhatma,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard(this.position);
  final ReadingPosition position;

  @override
  Widget build(BuildContext context) {
    final surah = position.surahName;
    return FadlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FadlColors.emerald,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bookmark_added_outlined,
                  color: FadlColors.goldLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (AppLocalizations.of(context) ??
                              lookupAppLocalizations(const Locale('ar')))
                          .continueReading,
                      style: FadlFonts.heading(size: 18),
                    ),
                    Text(
                      surah == null
                          ? (AppLocalizations.of(context) ??
                                    lookupAppLocalizations(const Locale('ar')))
                                .pageNumber(_uiNum(context, position.page))
                          : (AppLocalizations.of(context) ??
                                    lookupAppLocalizations(const Locale('ar')))
                                .surahPage(
                                  surah,
                                  _uiNum(context, position.page),
                                ),
                      style: FadlFonts.ui(size: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MushafReaderScreen(
                    initialPage: position.page,
                    highlightAyahKey: position.key,
                  ),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                (AppLocalizations.of(context) ??
                        lookupAppLocalizations(const Locale('ar')))
                    .continueReading,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyAyahCard extends StatelessWidget {
  const _DailyAyahCard(this.data, {this.title});
  final Map<String, dynamic> data;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ayah = data['ayah'] as Map<String, dynamic>;
    final surah = data['surah'] as Map<String, dynamic>;
    final ref =
        (AppLocalizations.of(context) ??
                lookupAppLocalizations(const Locale('ar')))
            .surahVerse('${surah['nameAr']}', _uiNum(context, ayah['number']));
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FadlCard(
      color: dark ? FadlColors.darkSurface : FadlColors.surfaceLow,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.format_quote_rounded, color: FadlColors.gold),
              const SizedBox(width: 6),
              Text(
                title ??
                    (AppLocalizations.of(context) ??
                            lookupAppLocalizations(const Locale('ar')))
                        .dailyBlessing,
                style: FadlFonts.ui(size: 13, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '﴿${ayah['text']}﴾',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: FadlFonts.scripture(
              size: 24,
              color: dark ? FadlColors.darkText : FadlColors.primary,
            ),
          ),
          if (ayah['tafsir'] != null) ...[
            const SizedBox(height: 6),
            Text(
              ayah['tafsir'] as String,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: FadlFonts.ui(size: 12.5),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge2(ref, color: FadlColors.textMuted),
              IconButton(
                tooltip:
                    (AppLocalizations.of(context) ??
                            lookupAppLocalizations(const Locale('ar')))
                        .share,
                icon: const Icon(Icons.share_outlined, size: 20),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: '﴿${ayah['text']}﴾\n[$ref]\n— من تطبيق فضل',
                  ),
                ),
              ),
              IconButton(
                tooltip:
                    (AppLocalizations.of(context) ??
                            lookupAppLocalizations(const Locale('ar')))
                        .openMushaf,
                icon: const Icon(Icons.menu_book_outlined, size: 20),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MushafReaderScreen(
                      initialPage: ayah['page'] as int,
                      highlightAyahKey: ayah['key'] as String,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextPrayerCard extends StatefulWidget {
  const _NextPrayerCard(this.prayer, {required this.onExpired});
  final Map<String, dynamic> prayer;
  final Future<void> Function() onExpired;

  @override
  State<_NextPrayerCard> createState() => _NextPrayerCardState();
}

class _NextPrayerCardState extends State<_NextPrayerCard> {
  Timer? _timer;
  late DateTime _at;

  @override
  void initState() {
    super.initState();
    _at = DateTime.parse((widget.prayer['next'] as Map)['time'] as String);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(_at)) {
        _timer?.cancel();
        widget.onExpired();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.prayer['next'] as Map;
    final local =
        (widget.prayer['prayers'] as List).cast<Map>().firstWhere(
              (p) => p['name'] == next['name'],
            )['local']
            as String;
    final remaining = _at.difference(DateTime.now()).inSeconds;
    final hijri = (widget.prayer['hijri'] as Map)['formattedAr'] as String;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FadlColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: FadlColors.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: FadlColors.onEmerald,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${widget.prayer['locationName'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                        style: FadlFonts.ui(
                          size: 12,
                          color: FadlColors.onEmerald,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .nextPrayer('${next['nameAr']}'),
                  style: FadlFonts.heading(size: 26, color: Colors.white),
                ),
                Text(
                  _uiTime(context, local),
                  style: FadlFonts.ui(
                    size: 18,
                    weight: FontWeight.w700,
                    color: FadlColors.goldLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hijri,
                  style: FadlFonts.ui(size: 12, color: FadlColors.onEmerald),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                (AppLocalizations.of(context) ??
                        lookupAppLocalizations(const Locale('ar')))
                    .nextPrayerIn,
                style: FadlFonts.ui(size: 12, color: FadlColors.onEmerald),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  countdown(remaining),
                  textDirection: TextDirection.ltr,
                  style: FadlFonts.ui(
                    size: 26,
                    weight: FontWeight.w800,
                    color: FadlColors.goldLight,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => AppShell.of(context)?.goTo(3),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .allPrayerTimes,
                  style: FadlFonts.ui(size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetLocationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FadlCard(
      color: FadlColors.emerald,
      onTap: () => showLocationPicker(context),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: FadlColors.goldLight,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .setLocation,
                  style: FadlFonts.heading(size: 18, color: Colors.white),
                ),
                Text(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .setLocationDescription,
                  style: FadlFonts.ui(size: 13, color: FadlColors.onEmerald),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _KhatmaCard extends StatelessWidget {
  const _KhatmaCard(this.khatma, {required this.onOpen});
  final Map<String, dynamic>? khatma;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final k = khatma;
    return FadlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FadlColors.emerald,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bookmark_added_outlined,
                  color: FadlColors.goldLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (AppLocalizations.of(context) ??
                              lookupAppLocalizations(const Locale('ar')))
                          .dailyProgress,
                      style: FadlFonts.heading(size: 18),
                    ),
                    Text(
                      k == null
                          ? (AppLocalizations.of(context) ??
                                    lookupAppLocalizations(const Locale('ar')))
                                .noActivePlan
                          : (AppLocalizations.of(context) ??
                                    lookupAppLocalizations(const Locale('ar')))
                                .currentPlan('${k['title']}'),
                      style: FadlFonts.ui(size: 12.5),
                    ),
                  ],
                ),
              ),
              if (k != null)
                Badge2(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .percentComplete(_uiNum(context, k['percent'])),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (k != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    k['position'] == null
                        ? (AppLocalizations.of(context) ??
                                  lookupAppLocalizations(const Locale('ar')))
                              .planCompleted
                        : (AppLocalizations.of(context) ??
                                  lookupAppLocalizations(const Locale('ar')))
                              .surahPage(
                                '${k['position']['surahNameAr']}',
                                _uiNum(context, k['position']['page']),
                              ),
                    style: FadlFonts.ui(size: 13, weight: FontWeight.w700),
                  ),
                ),
                Text(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .remainingPages(
                        _uiNum(context, (k['today'] as Map)['remaining']),
                      ),
                  style: FadlFonts.ui(size: 12.5),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (k['percent'] as num) / 100,
                minHeight: 8,
                color: FadlColors.sage,
                backgroundColor: FadlColors.surfaceHigh,
              ),
            ),
            const SizedBox(height: 14),
          ],
          ValueListenableBuilder<ReadingPosition?>(
            valueListenable: LastReadStore.instance,
            builder: (context, position, _) => SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: position != null
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MushafReaderScreen(
                            initialPage: position.page,
                            highlightAyahKey: position.key,
                          ),
                        ),
                      )
                    : k?['position'] != null
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MushafReaderScreen(
                            initialPage: (k!['position'] as Map)['page'] as int,
                          ),
                        ),
                      )
                    : onOpen,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  position != null || k != null
                      ? (AppLocalizations.of(context) ??
                                lookupAppLocalizations(const Locale('ar')))
                            .continueReading
                      : (AppLocalizations.of(context) ??
                                lookupAppLocalizations(const Locale('ar')))
                            .startPlan,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyHadithCard extends StatelessWidget {
  const _DailyHadithCard(this.hadith, {required this.onMore});
  final Map<String, dynamic> hadith;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return FadlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_outlined, color: FadlColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .hadithToday,
                  style: FadlFonts.heading(size: 18),
                ),
              ),
              TextButton(
                onPressed: onMore,
                child: Text(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .hadithLibrary,
                ),
              ),
            ],
          ),
          Text(
            hadith['textAr'] as String,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: FadlFonts.scripture(size: 18, height: 1.9),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${hadith['reference'] ?? ''}',
                  style: FadlFonts.ui(size: 12.5, weight: FontWeight.w700),
                ),
              ),
              if (hadith['grade'] != null) Badge2(hadith['grade'] as String),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyDedicationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final name = context.watch<AppState>().dedicatee;
    final dua =
        'اللهم اجعل ثواب ما قرأت وما سبّحت به اليوم نوراً وسكينةً في قبر والدي الحبيب $name، واغفر له وارحمه.';
    return FadlCard(
      color: FadlColors.goldSoft,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: FadlColors.goldLight,
                child: Icon(
                  Icons.favorite_border_rounded,
                  color: FadlColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .dedicateToday,
                  style: FadlFonts.heading(size: 18, color: FadlColors.primary),
                ),
              ),
              Text(
                (AppLocalizations.of(context) ??
                        lookupAppLocalizations(const Locale('ar')))
                    .honoringParents,
                style: FadlFonts.ui(
                  size: 12,
                  color: FadlColors.gold,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"$dua"',
            style: FadlFonts.ui(
              size: 14,
              color: FadlColors.textMuted,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    SharePlus.instance.share(ShareParams(text: dua)),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: Text(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .shareDua,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => dedicate(context, 'READING'),
                icon: const Icon(Icons.favorite_border_rounded, size: 18),
                label: Text(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .dedicatedReward,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
