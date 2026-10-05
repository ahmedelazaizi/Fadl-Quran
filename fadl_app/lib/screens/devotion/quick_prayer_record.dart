import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/worship_store.dart';
import '../../l10n/prayer_labels.dart';

class QuickPrayerRecord extends StatelessWidget {
  const QuickPrayerRecord({super.key, this.prayer});

  final String? prayer;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: prayer == null
        ? prayerL(context).trackerToday
        : prayerL(
            context,
          ).trackerRecordPrayer(prayerLabel(prayerL(context), prayer!)),
    icon: const Icon(Icons.check_circle_outline),
    onSelected: (name) async {
      final status = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final choice in prayerStatusLabels.entries)
                ListTile(
                  title: Text(prayerStatusLabel(prayerL(context), choice.key)),
                  onTap: () => Navigator.pop(context, choice.key),
                ),
            ],
          ),
        ),
      );
      if (status == null || !context.mounted) return;
      await WorshipStore().setPrayer(
        selectedLocalDate(context.read<AppState>().timezone, DateTime.now()),
        name,
        status,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              prayerL(context).trackerRecordedPrayer(
                prayerLabel(prayerL(context), name),
                prayerStatusLabel(prayerL(context), status),
              ),
            ),
          ),
        );
      }
    },
    itemBuilder: (_) => [
      for (final name in prayer == null ? obligatoryPrayers : [prayer!])
        PopupMenuItem(
          value: name,
          child: Text(prayerLabel(prayerL(context), name)),
        ),
    ],
  );
}
