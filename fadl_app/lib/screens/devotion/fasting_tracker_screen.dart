import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/local_user_data.dart';
import '../../core/offline_prayer.dart';
import '../../core/worship_store.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/text_dialog.dart';

class FastingTrackerScreen extends StatefulWidget {
  const FastingTrackerScreen({super.key});

  @override
  State<FastingTrackerScreen> createState() => _FastingTrackerScreenState();
}

class _FastingTrackerScreenState extends State<FastingTrackerScreen> {
  final store = WorshipStore();
  late DateTime date;
  Map<String, Map<String, String>> records = {};
  Map<String, int> summary = {};
  int qada = 0;

  @override
  void initState() {
    super.initState();
    date = OfflinePrayer.today(
      context.read<AppState>().timezone,
      DateTime.now(),
    );
    refresh();
  }

  Future<void> refresh() async {
    final nextRecords = await store.fasts();
    final nextSummary = await store.fastingYear(date.year);
    final nextQada = await store.ramadanQada();
    if (mounted) {
      setState(() {
        records = nextRecords;
        summary = nextSummary;
        qada = nextQada;
      });
    }
  }

  Future<void> chooseFast() async {
    String? selected = records[LocalUserData.ymd(date)]?['type'];
    final result = await showTextDialog<(String, String)>(
      context: context,
      initialTexts: [records[LocalUserData.ymd(date)]?['notes'] ?? ''],
      builder: (context, fields) => StatefulBuilder(
        builder: (context, rebuild) => AlertDialog(
          title: Text(
            prayerL(context).trackerFastingDay(LocalUserData.ymd(date)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selected,
                hint: Text(prayerL(context).trackerFastingType),
                items: [
                  for (final type in fastingTypes.entries)
                    DropdownMenuItem(
                      value: type.key,
                      child: Text(fastingTypeLabel(prayerL(context), type.key)),
                    ),
                ],
                onChanged: (value) => rebuild(() => selected = value),
              ),
              TextField(
                controller: fields[0],
                decoration: InputDecoration(
                  labelText: prayerL(context).trackerNotes,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ('delete', '')),
              child: Text(prayerL(context).trackerDelete),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ('save', fields[0].text)),
              child: Text(prayerL(context).trackerSave),
            ),
          ],
        ),
      ),
    );
    final action = result?.$1;
    if (action == 'save' && selected != null) {
      await store.setFast(LocalUserData.ymd(date), selected, notes: result!.$2);
    } else if (action == 'delete') {
      await store.setFast(LocalUserData.ymd(date), null);
    }
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final key = LocalUserData.ymd(date);
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).trackerFastingTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(prayerL(context).trackerManualFast),
          Row(
            children: [
              IconButton(
                tooltip: prayerL(context).a11yPreviousDay,
                onPressed: () {
                  date = DateTime.utc(date.year, date.month, date.day - 1);
                  refresh();
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(child: Center(child: Text(key))),
              IconButton(
                tooltip: prayerL(context).a11yNextDay,
                onPressed: () {
                  date = DateTime.utc(date.year, date.month, date.day + 1);
                  refresh();
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Card(
            child: ListTile(
              title: Text(
                fastingTypeLabel(prayerL(context), records[key]?['type']),
              ),
              subtitle: Text(records[key]?['notes'] ?? ''),
              trailing: const Icon(Icons.edit_outlined),
              onTap: chooseFast,
            ),
          ),
          ListTile(title: Text(prayerL(context).trackerRamadanQada)),
          ListTile(
            title: Text(
              prayerL(context).trackerRemaining(prayerNumber(context, qada)),
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: prayerL(context).a11yQadaDecrease,
                  onPressed: () async {
                    await store.adjustRamadanQada(-1);
                    await refresh();
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  tooltip: prayerL(context).a11yQadaIncrease,
                  onPressed: () async {
                    await store.adjustRamadanQada(1);
                    await refresh();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          Text(
            prayerL(
              context,
            ).trackerYearSummary(prayerNumber(context, date.year)),
          ),
          for (final type in fastingTypes.entries)
            ListTile(
              title: Text(fastingTypeLabel(prayerL(context), type.key)),
              trailing: Text(prayerNumber(context, summary[type.key] ?? 0)),
            ),
          Text(prayerL(context).trackerFastingNotice),
        ],
      ),
    );
  }
}
