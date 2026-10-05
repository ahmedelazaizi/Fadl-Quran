import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/offline_prayer.dart';
import '../../l10n/prayer_labels.dart';

class OfflineNextPrayer extends StatefulWidget {
  const OfflineNextPrayer({super.key});

  @override
  State<OfflineNextPrayer> createState() => _OfflineNextPrayerState();
}

class _OfflineNextPrayerState extends State<OfflineNextPrayer> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.hasLocation) return const SizedBox.shrink();
    final now = DateTime.now();
    final next = OfflinePrayer.nextPrayer(state.settings, now);
    final at = tz.TZDateTime.from(
      DateTime.parse(next['time'] as String),
      OfflinePrayer.location(state.timezone),
    );
    final hijri = OfflinePrayer.hijri(
      OfflinePrayer.today(state.timezone, now),
      (state.settings['hijriAdjustment'] as num?)?.toInt() ?? 0,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prayerL(context).trackerNextPrayer(
                prayerLabel(
                  prayerL(context),
                  next['name'] as String? ?? next['nameAr'] as String,
                ),
              ),
            ),
            Text(
              prayerL(context).trackerLocalTime(
                '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
              ),
            ),
            Text(
              prayerL(
                context,
              ).trackerRemaining(countdown(next['secondsRemaining'] as int)),
            ),
            Text(prayerHijriDate(context, hijri)),
          ],
        ),
      ),
    );
  }
}
