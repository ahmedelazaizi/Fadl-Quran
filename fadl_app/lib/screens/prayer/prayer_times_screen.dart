import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/adhan_service.dart';
import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/offline_prayer.dart';
import '../../core/theme.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';
import '../../widgets/location_picker.dart';
import '../devotion/quick_prayer_record.dart';
import 'adhan_settings_screen.dart';
import 'prayer_settings_sheets.dart';
import 'qibla_screen.dart';

const _prayerIcons = <String, IconData>{
  'fajr': Icons.nights_stay_outlined,
  'sunrise': Icons.wb_twilight_rounded,
  'dhuhr': Icons.wb_sunny_outlined,
  'asr': Icons.light_mode_outlined,
  'maghrib': Icons.wb_twighlight,
  'isha': Icons.bedtime_outlined,
};

class PrayerTimesScreen extends StatelessWidget {
  const PrayerTimesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    // Any change to these settings changes the payload, so reload.
    final token = [
      s['latitude'],
      s['longitude'],
      s['timezone'],
      s['calcMethod'],
      s['madhab'],
      s['hijriAdjustment'],
      s['highLatRule'],
      s['adjustments'],
    ].join('|');
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).prayerTimes)),
      body: !state.hasLocation
          ? const _LocationPrompt()
          : AsyncView<Map<String, dynamic>>(
              reloadToken: token,
              load: () async => Api.hasBackend
                  ? await Api.instance.get('/me/prayer') as Map<String, dynamic>
                  : OfflinePrayer.payload(state.settings, DateTime.now()),
              builder: (context, data, reload) =>
                  _PrayerBody(data: data, reload: reload),
            ),
    );
  }
}

class _LocationPrompt extends StatelessWidget {
  const _LocationPrompt();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 56,
            color: FadlColors.sage,
          ),
          const SizedBox(height: 12),
          Text(
            prayerL(context).prayerLocationPrompt,
            style: FadlFonts.heading(size: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            prayerL(context).locationPurpose,
            style: FadlFonts.ui(size: 13),
            textAlign: TextAlign.center,
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
  );
}

class _PrayerBody extends StatefulWidget {
  const _PrayerBody({required this.data, required this.reload});
  final Map<String, dynamic> data;
  final Future<void> Function() reload;

  @override
  State<_PrayerBody> createState() => _PrayerBodyState();
}

class _PrayerBodyState extends State<_PrayerBody> {
  Timer? _timer;
  bool _reloading = false;

  DateTime get _nextAt => DateTime.parse(widget.data['next']['time'] as String);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final settings = context.read<AppState>().settings;
    final timezone = (settings['timezone'] as String?) ?? 'Asia/Riyadh';
    final currentDate = OfflinePrayer.today(timezone, now);
    final dateKey =
        '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
    if (!_reloading &&
        (dateKey != widget.data['date'] || !now.isBefore(_nextAt))) {
      _reloading = true;
      Future.delayed(Duration(seconds: Api.hasBackend ? 2 : 0), () async {
        try {
          if (mounted) await widget.reload();
        } finally {
          _reloading = false;
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final prayers = (data['prayers'] as List).cast<Map<String, dynamic>>();
    final next = data['next'] as Map<String, dynamic>;
    final now = DateTime.now();
    final remaining = _nextAt.difference(now).inSeconds;

    // The most recent prayer whose time has passed today ("الآن").
    String? current;
    for (final p in prayers) {
      if (!DateTime.parse(p['time'] as String).isAfter(now)) {
        current = p['name'] as String;
      }
    }

    return RefreshIndicator(
      onRefresh: widget.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _LocationHeader(data: data),
          const SizedBox(height: 14),
          _NextPrayerCard(next: next, remaining: remaining),
          const SizedBox(height: 18),
          FadlCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        prayerL(context).todayPrayerTimes,
                        style: FadlFonts.heading(size: 18),
                      ),
                    ),
                    Text(
                      prayerL(context).timingMethod(
                        calculationLabel(
                          prayerL(context),
                          (data['method'] as Map)['key'] as String,
                        ),
                      ),
                      style: FadlFonts.ui(
                        size: 11.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final p in prayers)
                  _PrayerRow(
                    prayer: p,
                    isNext:
                        p['name'] == next['name'] && p['time'] == next['time'],
                    isCurrent: p['name'] == current,
                    now: now,
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => openAdhanSettings(context),
                    icon: const Icon(Icons.campaign_outlined),
                    label: Text(prayerL(context).adhanSettings),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _QiblaMiniCard(qibla: data['qibla'] as Map<String, dynamic>),
          const SizedBox(height: 16),
          _CalcSettingsCard(
            methodName: calculationLabel(
              prayerL(context),
              (data['method'] as Map)['key'] as String,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  '﴿إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَّوْقُوتًا﴾',
                  textAlign: TextAlign.center,
                  style: FadlFonts.scripture(size: 20),
                ),
                Text(
                  'سورة النساء • الآية ١٠٣',
                  style: FadlFonts.ui(size: 12, color: FadlColors.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationHeader extends StatelessWidget {
  const _LocationHeader({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hijri = prayerHijriDate(context, data['hijri'] as Map);
    final gregorian = englishPrayerUi(context)
        ? MaterialLocalizations.of(
            context,
          ).formatMediumDate(DateTime.parse(data['date'] as String))
        : data['gregorianAr'] as String;
    return FadlCard(
      onTap: () => showLocationPicker(context),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: FadlColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: FadlColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationLabel(
                    prayerL(context),
                    data['locationName'] as String?,
                  ),
                  style: FadlFonts.heading(size: 18),
                ),
                Text(
                  '$hijri • $gregorian',
                  style: FadlFonts.ui(
                    size: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_location_alt_outlined, color: scheme.outline),
        ],
      ),
    );
  }
}

class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({required this.next, required this.remaining});
  final Map<String, dynamic> next;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final at = DateTime.parse(next['time'] as String);
    final timezone = context.read<AppState>().timezone;
    final zone = OfflinePrayer.location(timezone);
    final zoned = tz.TZDateTime.from(at, zone);
    final local =
        '${zoned.hour.toString().padLeft(2, '0')}:${zoned.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FadlColors.emerald, FadlColors.primary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Badge2(
                prayerL(context).nextPrayerLabel,
                color: FadlColors.mint,
                background: Colors.white.withValues(alpha: 0.12),
              ),
              const Spacer(),
              Text(
                '${prayerLabel(prayerL(context), next['name'] as String)}  ${prayerTime(context, local)}',
                style: FadlFonts.ui(
                  size: 14,
                  weight: FontWeight.w700,
                  color: FadlColors.goldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            prayerL(context).timeUntilAdhan,
            style: FadlFonts.ui(size: 13, color: FadlColors.onEmerald),
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              countdown(remaining),
              style: FadlFonts.ui(
                size: 44,
                weight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            prayerL(context).prayerAfter(
              prayerLabel(prayerL(context), next['name'] as String),
              _humanize(context, remaining),
            ),
            style: FadlFonts.ui(size: 13, color: FadlColors.onEmerald),
          ),
        ],
      ),
    );
  }
}

String _humanize(BuildContext context, int seconds) {
  final l = prayerL(context);
  final minutes = (seconds / 60).ceil();
  if (minutes < 1) return l.moments;
  final h = minutes ~/ 60, m = minutes % 60;
  if (englishPrayerUi(context)) {
    if (h == 0) return l.minutesOnly('$m');
    if (m == 0) return l.hoursOnly('$h');
    return l.hoursMinutes('$h', '$m');
  }
  String hours(int v) => v == 1
      ? 'ساعة'
      : v == 2
      ? 'ساعتين'
      : '${arNum(v)} ${v <= 10 ? 'ساعات' : 'ساعة'}';
  String mins(int v) => v == 1
      ? 'دقيقة'
      : v == 2
      ? 'دقيقتين'
      : '${arNum(v)} ${v <= 10 ? 'دقائق' : 'دقيقة'}';
  if (h == 0) return mins(m);
  if (m == 0) return hours(h);
  return '${hours(h)} و${mins(m)}';
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.prayer,
    required this.isNext,
    required this.isCurrent,
    required this.now,
  });
  final Map<String, dynamic> prayer;
  final bool isNext;
  final bool isCurrent;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = prayer['name'] as String;
    final at = DateTime.parse(prayer['time'] as String);
    final state = context.watch<AppState>();
    final mode = prayerMode(state.notifications, name);

    final String status;
    if (at.isAfter(now)) {
      status = prayerL(
        context,
      ).afterDuration(_humanize(context, at.difference(now).inSeconds));
    } else if (isCurrent) {
      status = prayerL(context).nowLabel;
    } else {
      status = prayerL(context).elapsed;
    }
    final highlight = isNext || isCurrent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? (dark
                  ? FadlColors.gold.withValues(alpha: 0.12)
                  : FadlColors.goldSoft)
            : null,
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? Border.all(
                color: FadlColors.gold.withValues(alpha: isNext ? 0.9 : 0.45),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isNext ? FadlColors.emerald : scheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _prayerIcons[name] ?? Icons.access_time,
              color: isNext ? Colors.white : FadlColors.sage,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      prayerLabel(prayerL(context), name),
                      style: FadlFonts.ui(size: 16, weight: FontWeight.w700),
                    ),
                    if (isNext) ...[
                      const SizedBox(width: 6),
                      Badge2(prayerL(context).upcoming, color: FadlColors.gold),
                    ],
                    if (isCurrent && !isNext) ...[
                      const SizedBox(width: 6),
                      Badge2(prayerL(context).nowLabel),
                    ],
                  ],
                ),
                Text(
                  status,
                  style: FadlFonts.ui(size: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (name != 'sunrise') QuickPrayerRecord(prayer: name),
          Text(
            prayerTime(context, prayer['local'] as String),
            style: FadlFonts.ui(size: 17, weight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: prayerL(context).prayerAlertMode(
              prayerLabel(prayerL(context), name),
              adhanModeLabel(prayerL(context), mode),
            ),
            icon: Icon(
              adhanModeIcons[mode],
              color: mode == 'silent' ? scheme.outline : FadlColors.sage,
            ),
            onSelected: (value) => value == 'settings'
                ? openAdhanSettings(context)
                : _setMode(context, name, value),
            itemBuilder: (_) => [
              for (final m in adhanModeValues)
                if (name != 'sunrise' || m != 'adhan')
                  CheckedPopupMenuItem(
                    value: m,
                    checked: m == mode,
                    child: Text(adhanModeLabel(prayerL(context), m)),
                  ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'settings',
                child: Text(prayerL(context).adhanSettings),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setMode(BuildContext context, String name, String mode) async {
    final state = context.read<AppState>();
    try {
      await setPrayerMode(state, name, mode);
      if (context.mounted) {
        final fajrFallback =
            mode == 'adhan' &&
            effectivePrayerMode(state.notifications, name) == 'notify';
        showToast(
          context,
          fajrFallback
              ? prayerL(context).fajrSoundFallback
              : prayerL(context).prayerAlertMode(
                  prayerLabel(prayerL(context), name),
                  adhanModeLabel(prayerL(context), mode),
                ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }
}

class _QiblaMiniCard extends StatelessWidget {
  const _QiblaMiniCard({required this.qibla});
  final Map<String, dynamic> qibla;

  @override
  Widget build(BuildContext context) {
    final bearing = (qibla['bearing'] as num).round();
    return FadlCard(
      color: Theme.of(context).colorScheme.surfaceContainer,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QiblaScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FadlColors.emerald,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.explore_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayerL(context).qiblaCompass,
                  style: FadlFonts.heading(size: 17),
                ),
                Text(
                  prayerL(context).qiblaSummary(
                    prayerNumber(context, qibla['distanceKm']),
                    prayerNumber(context, bearing),
                    compassLabel(
                      prayerL(context),
                      qibla['direction'] as String?,
                    ),
                  ),
                  style: FadlFonts.ui(
                    size: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _CalcSettingsCard extends StatelessWidget {
  const _CalcSettingsCard({required this.methodName});
  final String methodName;

  @override
  Widget build(BuildContext context) {
    final madhab = context.select<AppState, String>(
      (s) => (s.settings['madhab'] as String?) ?? 'shafi',
    );
    return FadlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prayerL(context).calculationTiming,
            style: FadlFonts.heading(size: 18),
          ),
          const SizedBox(height: 6),
          SettingRow(
            icon: Icons.calculate_outlined,
            title: prayerL(context).calculationMethod,
            subtitle: methodName,
            onTap: () => showCalcMethodSheet(context),
          ),
          SettingRow(
            icon: Icons.schedule_rounded,
            title: prayerL(context).asrSchool,
            subtitle: madhabLabel(prayerL(context), madhab),
            onTap: () => showMadhabSheet(context),
          ),
          SettingRow(
            icon: Icons.calendar_month_outlined,
            title: prayerL(context).hijriCalendarAdjustment,
            subtitle: prayerL(context).hijriAdjustmentHint,
            trailing: HijriAdjustmentStepper(),
          ),
        ],
      ),
    );
  }
}
