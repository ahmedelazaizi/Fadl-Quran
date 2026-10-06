import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/local_user_data.dart';
import '../../core/offline_athkar.dart';
import '../../core/offline_prayer.dart';
import '../../core/quran_data.dart';
import '../../core/theme.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';
import '../../widgets/location_picker.dart';

/// Returns null outside Ramadan or beyond the supported Umm al-Qura calendar.
Map<String, dynamic>? localRamadanImsakiya(
  Map<String, dynamic> settings,
  DateTime now,
) {
  try {
    final today = OfflinePrayer.today(
      (settings['timezone'] as String?) ?? 'Asia/Riyadh',
      now,
    );
    final adjustment = (settings['hijriAdjustment'] as num?)?.toInt() ?? 0;
    final hijri = OfflinePrayer.hijri(today, adjustment);
    if (hijri['month'] != 9) return null;
    final first = today.subtract(Duration(days: (hijri['day'] as int) - 1));
    final days = <Map<String, dynamic>>[];
    const weekdays = [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    for (var i = 0; i < 30; i++) {
      final date = first.add(Duration(days: i));
      if (OfflinePrayer.hijri(date, adjustment)['month'] != 9) break;
      final daily = OfflinePrayer.day(settings, date);
      final prayers = {
        for (final p in (daily['prayers'] as List).cast<Map<String, dynamic>>())
          p['name'] as String: p,
      };
      final fajr = prayers['fajr']!;
      final maghrib = prayers['maghrib']!;
      final isha = prayers['isha']!;
      final fajrLocal = fajr['local'] as String;
      // Imsak is a display convention (10 minutes before Fajr), not a prayer time.
      final fajrMinutes =
          int.parse(fajrLocal.substring(0, 2)) * 60 +
          int.parse(fajrLocal.substring(3));
      final imsakMinutes = (fajrMinutes - 10 + 1440) % 1440;
      final imsak =
          '${(imsakMinutes ~/ 60).toString().padLeft(2, '0')}:${(imsakMinutes % 60).toString().padLeft(2, '0')}';
      days.add({
        'ramadanDay': i + 1,
        'weekdayAr': weekdays[date.weekday % 7],
        'oddNightTonight': i + 1 >= 20 && (i + 1).isEven,
        'note': null,
        'imsak': imsak,
        'fajr': fajrLocal,
        'maghrib': maghrib['local'],
        'isha': isha['local'],
        'maghribAt': maghrib['time'],
      });
    }
    final index = (hijri['day'] as int) - 1;
    final current = days[index];
    final tomorrow = index + 1 < days.length ? days[index + 1] : null;
    return {
      'hijriYear': hijri['year'],
      'startDate': LocalUserData.ymd(first),
      'daysUntilRamadan': 0,
      'days': days,
      'today': {
        'ramadanDay': index + 1,
        'daysToEid': days.length - index,
        'secondsToIftar': DateTime.parse(
          current['maghribAt'] as String,
        ).difference(now).inSeconds,
        'iftar': current['maghrib'],
        'tomorrowImsak': tomorrow?['imsak'],
        'tomorrowFajr': tomorrow?['fajr'],
      },
    };
  } on RangeError {
    return null;
  }
}

const _periods = [
  ('first', 'العشر الأوائل', 1, 10),
  ('middle', 'العشر الأواسط', 11, 20),
  ('last', 'العشر الأواخر', 21, 30),
  ('all', 'كامل الشهر', 1, 30),
];

const _sunnahs = [
  ('suhoor', 'السحور', Icons.free_breakfast_outlined),
  ('iftar-dua', 'دعاء الفطر', Icons.front_hand_outlined),
  ('taraweeh', 'صلاة التراويح', Icons.mosque_outlined),
  ('feed-fasting', 'إطعام صائم', Icons.volunteer_activism_outlined),
];

/// Ramadan imsakiya — for viewing only (no export).
class RamadanScreen extends StatelessWidget {
  const RamadanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final query = <String, Object?>{
      'lat': s['latitude'],
      'lng': s['longitude'],
      'tz': state.timezone,
      'method': s['calcMethod'],
      'madhab': s['madhab'],
      'hijriAdjustment': s['hijriAdjustment'],
    };
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).ramadanTimetable)),
      body: !state.hasLocation
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.nightlight_round,
                      size: 56,
                      color: FadlColors.gold,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      prayerL(context).ramadanLocationPrompt,
                      style: FadlFonts.heading(size: 18),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => showLocationPicker(context),
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(prayerL(context).setLocation),
                    ),
                  ],
                ),
              ),
            )
          : !Api.hasBackend
          ? AsyncView<Map<String, dynamic>?>(
              reloadToken: query.values.join('|'),
              load: () async => localRamadanImsakiya({
                ...s,
                'timezone': state.timezone,
              }, DateTime.now()),
              builder: (context, data, reload) => data == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(prayerL(context).ramadanOfflineOnly),
                      ),
                    )
                  : _RamadanBody(
                      data: data,
                      reload: reload,
                      locationName: locationLabel(
                        prayerL(context),
                        s['locationName'] as String?,
                      ),
                    ),
            )
          : AsyncView<Map<String, dynamic>>(
              reloadToken: query.values.join('|'),
              load: () async =>
                  await Api.instance.get('/ramadan/imsakiya', {
                        ...query,
                        'period': 'all',
                      })
                      as Map<String, dynamic>,
              builder: (context, data, reload) => _RamadanBody(
                data: data,
                reload: reload,
                locationName: locationLabel(
                  prayerL(context),
                  s['locationName'] as String?,
                ),
              ),
            ),
    );
  }
}

class _RamadanBody extends StatefulWidget {
  const _RamadanBody({
    required this.data,
    required this.reload,
    required this.locationName,
  });
  final Map<String, dynamic> data;
  final Future<void> Function() reload;
  final String locationName;

  @override
  State<_RamadanBody> createState() => _RamadanBodyState();
}

class _RamadanBodyState extends State<_RamadanBody> {
  late String _period = _initialPeriod();

  String _initialPeriod() {
    final today = widget.data['today'] as Map<String, dynamic>?;
    if (today == null) return 'all';
    final d = today['ramadanDay'] as int;
    return d <= 10 ? 'first' : (d <= 20 ? 'middle' : 'last');
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final today = data['today'] as Map<String, dynamic>?;
    final days = (data['days'] as List).cast<Map<String, dynamic>>();
    final (_, _, from, to) = _periods.firstWhere((p) => p.$1 == _period);
    final visible = days
        .where(
          (d) =>
              (d['ramadanDay'] as int) >= from &&
              (d['ramadanDay'] as int) <= to,
        )
        .toList();

    return RefreshIndicator(
      onRefresh: widget.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Header(data: data, locationName: widget.locationName),
          if (today != null) ...[
            const SizedBox(height: 14),
            _IftarCard(today: today),
            const SizedBox(height: 14),
            const _SunnahChecklist(),
          ],
          const SizedBox(height: 18),
          SectionTitle(
            prayerL(context).imsakiyaTable,
            trailing: Text(
              widget.locationName,
              style: FadlFonts.ui(size: 12, color: FadlColors.outline),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in _periods)
                  PillChip(
                    label: switch (p.$1) {
                      'first' => prayerL(context).periodFirst,
                      'middle' => prayerL(context).periodMiddle,
                      'last' => prayerL(context).periodLast,
                      _ => prayerL(context).periodAll,
                    },
                    selected: _period == p.$1,
                    onTap: () => setState(() => _period = p.$1),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!Api.hasBackend)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(prayerL(context).imsakEstimate),
            ),
          _ImsakiyaTable(days: visible, todayDay: today?['ramadanDay'] as int?),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: FadlColors.gold),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  prayerL(context).oddNightHint,
                  style: FadlFonts.ui(
                    size: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FadlCard(
            onTap: () => _showRamadanDuas(context),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FadlColors.goldSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: FadlColors.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prayerL(context).ramadanDuas,
                        style: FadlFonts.heading(size: 16),
                      ),
                      Text(
                        prayerL(context).ramadanDuasHint,
                        style: FadlFonts.ui(
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.locationName});
  final Map<String, dynamic> data;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final today = data['today'] as Map<String, dynamic>?;
    final year = prayerNumber(context, data['hijriYear']);
    final start = _formatDate(context, data['startDate'] as String);
    final String headline;
    final String caption;
    if (today != null) {
      headline = prayerL(
        context,
      ).ramadanDayYear(prayerNumber(context, today['ramadanDay']), year);
      final toEid = today['daysToEid'] as int;
      caption = prayerL(context).daysToEid(prayerNumber(context, toEid));
    } else {
      headline = prayerL(context).ramadanYear(year);
      final until = data['daysUntilRamadan'] as int;
      caption = until > 0
          ? prayerL(
              context,
            ).ramadanStartsIn(prayerNumber(context, until), start)
          : prayerL(context).ramadanStarts(start);
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FadlColors.emerald, FadlColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FadlColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayerL(context).ramadanGreeting,
                  style: FadlFonts.ui(size: 13, color: FadlColors.goldLight),
                ),
                Text(
                  headline,
                  style: FadlFonts.heading(size: 22, color: Colors.white),
                ),
                Text(
                  caption,
                  style: FadlFonts.ui(size: 13, color: FadlColors.onEmerald),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: FadlColors.onEmerald,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        locationName,
                        style: FadlFonts.ui(
                          size: 12,
                          color: FadlColors.onEmerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.nightlight_round,
            size: 54,
            color: FadlColors.goldLight,
          ),
        ],
      ),
    );
  }
}

String _formatDate(BuildContext context, String ymd) {
  if (englishPrayerUi(context)) {
    final p = ymd.split('-').map(int.parse).toList();
    return MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateTime(p[0], p[1], p[2]));
  }
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  final p = ymd.split('-').map(int.parse).toList();
  return '${arNum(p[2])} ${months[p[1] - 1]} ${arNum(p[0])}';
}

class _IftarCard extends StatefulWidget {
  const _IftarCard({required this.today});
  final Map<String, dynamic> today;

  @override
  State<_IftarCard> createState() => _IftarCardState();
}

class _IftarCardState extends State<_IftarCard> {
  late DateTime _iftarAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _IftarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.today != widget.today) _sync();
  }

  void _sync() => _iftarAt = DateTime.now().add(
    Duration(seconds: widget.today['secondsToIftar'] as int),
  );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _iftarAt.difference(DateTime.now()).inSeconds;
    final passed = remaining <= 0;
    final t = widget.today;
    return FadlCard(
      color: FadlColors.goldSoft,
      child: Column(
        children: [
          Text(
            passed
                ? prayerL(context).fastAccepted
                : prayerL(context).untilIftar,
            style: FadlFonts.ui(size: 13, color: FadlColors.textMuted),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              countdown(remaining),
              style: FadlFonts.ui(
                size: 38,
                weight: FontWeight.w800,
                color: FadlColors.primary,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniTime(prayerL(context).iftar, t['iftar'] as String?),
              _miniTime(
                prayerL(context).tomorrowImsak,
                t['tomorrowImsak'] as String?,
              ),
              _miniTime(
                prayerL(context).tomorrowFajr,
                t['tomorrowFajr'] as String?,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniTime(String label, String? hm) => Expanded(
    child: Column(
      children: [
        Text(label, style: FadlFonts.ui(size: 12, color: FadlColors.textMuted)),
        Text(
          hm == null ? '—' : prayerTime(context, hm),
          style: FadlFonts.ui(
            size: 15,
            weight: FontWeight.w700,
            color: FadlColors.primary,
          ),
        ),
      ],
    ),
  );
}

class _SunnahChecklist extends StatefulWidget {
  const _SunnahChecklist();

  @override
  State<_SunnahChecklist> createState() => _SunnahChecklistState();
}

class _SunnahChecklistState extends State<_SunnahChecklist> {
  Set<String>? _done;

  @override
  void initState() {
    super.initState();
    (Api.hasBackend
            ? Api.instance.get('/me/checklist')
            : OfflineAthkarStore.reads().then(
                (counts) => {
                  'done': [
                    for (final item in _sunnahs)
                      if ((counts['ramadan-checklist:${item.$1}'] ?? 0) > 0)
                        item.$1,
                  ],
                },
              ))
        .then((res) {
          if (mounted) {
            setState(
              () =>
                  _done = ((res as Map)['done'] as List).cast<String>().toSet(),
            );
          }
        })
        .catchError((Object _) {
          if (mounted) setState(() => _done = {});
        });
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => value ? _done!.add(key) : _done!.remove(key));
    try {
      if (Api.hasBackend) {
        await Api.instance.put('/me/checklist', {'key': key, 'done': value});
      } else {
        await OfflineAthkarStore.setRead(
          'ramadan-checklist:$key',
          value ? 1 : 0,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => value ? _done!.remove(key) : _done!.add(key));
      showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    return FadlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  prayerL(context).dailySunnahs,
                  style: FadlFonts.heading(size: 17),
                ),
              ),
              if (done != null)
                Badge2(
                  prayerL(context).checklistProgress(
                    prayerNumber(context, done.length),
                    prayerNumber(context, _sunnahs.length),
                  ),
                ),
            ],
          ),
          if (done == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final (key, _, icon) in _sunnahs)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: done.contains(key),
                onChanged: (v) => _toggle(key, v ?? false),
                secondary: Icon(icon, color: FadlColors.sage),
                title: Text(switch (key) {
                  'suhoor' => prayerL(context).sunnahSuhoor,
                  'iftar-dua' => prayerL(context).sunnahIftarDua,
                  'taraweeh' => prayerL(context).sunnahTaraweeh,
                  _ => prayerL(context).sunnahFeedFasting,
                }, style: FadlFonts.ui(size: 15)),
                activeColor: FadlColors.sage,
              ),
        ],
      ),
    );
  }
}

class _ImsakiyaTable extends StatelessWidget {
  const _ImsakiyaTable({required this.days, required this.todayDay});
  final List<Map<String, dynamic>> days;
  final int? todayDay;

  static const _cols = [
    ('imsak', 'إمساك'),
    ('fajr', 'فجر'),
    ('maghrib', 'مغرب'),
    ('isha', 'عشاء'),
    ('taraweeh', 'تراويح'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget cell(
      String text, {
      double width = 64,
      FontWeight weight = FontWeight.w500,
      Color? color,
    }) => SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: FadlFonts.ui(size: 13, weight: weight, color: color),
      ),
    );
    final columns = Api.hasBackend
        ? _cols
        : _cols.where((c) => c.$1 != 'taraweeh');
    return FadlCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  cell(
                    prayerL(context).day,
                    width: 120,
                    weight: FontWeight.w700,
                  ),
                  for (final c in columns)
                    cell(switch (c.$1) {
                      'imsak' => prayerL(context).imsak,
                      'fajr' => prayerL(context).prayerFajr,
                      'maghrib' => prayerL(context).prayerMaghrib,
                      'isha' => prayerL(context).prayerIsha,
                      _ => prayerL(context).taraweeh,
                    }, weight: FontWeight.w700),
                ],
              ),
            ),
            for (final d in days)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: d['ramadanDay'] == todayDay
                    ? BoxDecoration(
                        color: dark
                            ? FadlColors.gold.withValues(alpha: 0.12)
                            : FadlColors.goldSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: FadlColors.gold),
                      )
                    : null,
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${prayerNumber(context, d['ramadanDay'])} ',
                                  style: FadlFonts.ui(
                                    size: 15,
                                    weight: FontWeight.w800,
                                    color: FadlColors.sage,
                                  ),
                                ),
                                Text(
                                  _weekdayLabel(
                                    prayerL(context),
                                    d['weekdayAr'] as String,
                                  ),
                                  style: FadlFonts.ui(size: 13),
                                ),
                                if (d['oddNightTonight'] == true) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: FadlColors.gold,
                                  ),
                                ],
                              ],
                            ),
                            if (d['note'] != null)
                              Text(
                                d['note'] as String,
                                maxLines: 2,
                                style: FadlFonts.ui(
                                  size: 10.5,
                                  color: FadlColors.gold,
                                  weight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    for (final c in columns)
                      cell(
                        _tableTime(context, d[c.$1] as String),
                        weight: c.$1 == 'maghrib' || c.$1 == 'imsak'
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: c.$1 == 'maghrib' || c.$1 == 'imsak'
                            ? FadlColors.sage
                            : null,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showRamadanDuas(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
        ),
        child: AsyncView<Map<String, dynamic>>(
          load: () async {
            if (!Api.hasBackend) {
              final athkar = await OfflineAthkar.load();
              final quran = await QuranData.load();
              return athkar.duaCollection('ramadan', quran)!;
            }
            return await Api.instance.get('/duas/collections/ramadan')
                as Map<String, dynamic>;
          },
          builder: (context, data, _) {
            final items = (data['items'] as List).cast<Map<String, dynamic>>();
            return ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text(
                    data['nameAr'] as String,
                    style: FadlFonts.heading(size: 20),
                  );
                }
                final it = items[i - 1];
                return FadlCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it['text'] as String,
                        style: FadlFonts.scripture(size: 19, height: 1.9),
                      ),
                      if (it['virtue'] != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          it['virtue'] as String,
                          style: FadlFonts.ui(
                            size: 12.5,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (it['reference'] != null)
                            Expanded(
                              child: Text(
                                it['reference'] as String,
                                style: FadlFonts.ui(
                                  size: 12,
                                  color: FadlColors.gold,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          if ((it['repeat'] as int? ?? 1) > 1)
                            Badge2('×${prayerNumber(context, it['repeat'])}'),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

String _weekdayLabel(dynamic l, String day) => switch (day) {
  'الأحد' => l.weekdaySun,
  'الاثنين' => l.weekdayMon,
  'الثلاثاء' => l.weekdayTue,
  'الأربعاء' => l.weekdayWed,
  'الخميس' => l.weekdayThu,
  'الجمعة' => l.weekdayFri,
  'السبت' => l.weekdaySat,
  _ => day,
};

String _tableTime(BuildContext context, String hm) => englishPrayerUi(context)
    ? hm
    : hm12(hm).replaceAll(' ص', '').replaceAll(' م', '');
