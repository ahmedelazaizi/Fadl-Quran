import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/offline_prayer.dart';
import '../../core/worship_calendar.dart';
import '../../l10n/prayer_labels.dart';

String _occasionLabel(BuildContext context, String occasion) {
  final l = prayerL(context);
  return switch (occasion) {
    'بداية رمضان' => l.occasionRamadanBegins,
    'عيد الفطر' => l.occasionEidAlFitr,
    'يوم عرفة' => l.occasionArafah,
    'عيد الأضحى' => l.occasionEidAlAdha,
    'عاشوراء' => l.occasionAshura,
    'الأيام البيض' => l.occasionWhiteDays,
    'الاثنين' => l.occasionMonday,
    'الخميس' => l.occasionThursday,
    _ => occasion,
  };
}

class HijriCalendarScreen extends StatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  State<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends State<HijriCalendarScreen> {
  late DateTime month;
  DateTime? selected;

  @override
  void initState() {
    super.initState();
    final today = OfflinePrayer.today(
      context.read<AppState>().timezone,
      DateTime.now(),
    );
    month = DateTime.utc(today.year, today.month);
    selected = today;
  }

  @override
  Widget build(BuildContext context) {
    final adjustment =
        (context.watch<AppState>().settings['hijriAdjustment'] as num?)
            ?.toInt() ??
        0;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final firstOffset = (month.weekday % 7);
    final firstHijri = OfflinePrayer.hijri(month, adjustment);
    final lastHijri = OfflinePrayer.hijri(
      DateTime.utc(month.year, month.month, days),
      adjustment,
    );
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).trackerCalendarTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: prayerL(context).a11yPreviousMonth,
                onPressed: () => setState(
                  () => month = DateTime.utc(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${month.month}/${month.year} ${prayerL(context).trackerGregorianShort} • ${prayerHijriDate(context, firstHijri)} – ${prayerHijriDate(context, lastHijri)}',
                  ),
                ),
              ),
              IconButton(
                tooltip: prayerL(context).a11yNextMonth,
                onPressed: () => setState(
                  () => month = DateTime.utc(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final label in [
                prayerL(context).trackerSunShort,
                prayerL(context).trackerMonShort,
                prayerL(context).trackerTueShort,
                prayerL(context).trackerWedShort,
                prayerL(context).trackerThuShort,
                prayerL(context).trackerFriShort,
                prayerL(context).trackerSatShort,
              ])
                Expanded(
                  child: Center(
                    child: Text(label, style: TextStyle(fontSize: 11)),
                  ),
                ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
            ),
            itemCount: firstOffset + days,
            itemBuilder: (context, index) {
              if (index < firstOffset) return const SizedBox.shrink();
              final day = DateTime.utc(
                month.year,
                month.month,
                index - firstOffset + 1,
              );
              final hijri = OfflinePrayer.hijri(day, adjustment);
              final events = hijriOccasions(day, adjustment);
              return InkWell(
                onTap: () => setState(() => selected = day),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected == day
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    border: events.isEmpty
                        ? null
                        : Border.all(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${day.day}'),
                      Text(
                        '${hijri['day']} ${prayerL(context).trackerHijriShort}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (selected != null) ...[
            ListTile(
              title: Text(
                '${selected!.day}/${selected!.month}/${selected!.year} ${prayerL(context).trackerGregorianShort}',
              ),
              subtitle: Text(
                prayerHijriDate(
                  context,
                  OfflinePrayer.hijri(selected!, adjustment),
                ),
              ),
            ),
            for (final event in hijriOccasions(selected!, adjustment))
              ListTile(title: Text(_occasionLabel(context, event))),
          ],
          Text(prayerL(context).trackerCalendarNotice),
        ],
      ),
    );
  }
}
