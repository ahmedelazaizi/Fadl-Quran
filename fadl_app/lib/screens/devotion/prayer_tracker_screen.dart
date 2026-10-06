import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_state.dart';
import '../../core/local_user_data.dart';
import '../../core/offline_prayer.dart';
import '../../core/worship_store.dart';
import '../../l10n/prayer_labels.dart';

class PrayerTrackerScreen extends StatefulWidget {
  const PrayerTrackerScreen({super.key});

  @override
  State<PrayerTrackerScreen> createState() => _PrayerTrackerScreenState();
}

class _PrayerTrackerScreenState extends State<PrayerTrackerScreen> {
  final store = WorshipStore();
  late DateTime date;
  Map<String, String> records = {};
  Map<String, int> qada = {};
  Map<String, int> weekly = {}, monthly = {};

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
    final firstWeek = date.subtract(Duration(days: date.weekday - 1));
    final nextRecords = await store.prayers();
    final nextQada = await store.qada();
    final nextWeekly = await store.prayerStats(
      firstWeek,
      firstWeek.add(const Duration(days: 6)),
    );
    final nextMonthly = await store.prayerStats(
      DateTime.utc(date.year, date.month),
      DateTime.utc(date.year, date.month + 1, 0),
    );
    if (!mounted) return;
    setState(() {
      records = nextRecords;
      qada = nextQada;
      weekly = nextWeekly;
      monthly = nextMonthly;
    });
  }

  Future<void> update(String prayer, String? status) async {
    await store.setPrayer(LocalUserData.ymd(date), prayer, status);
    await refresh();
  }

  Future<void> importJson() async {
    final controller = TextEditingController();
    final source = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prayerL(context).trackerImportJson),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: prayerL(context).trackerPasteBackup,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(prayerL(context).trackerCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(prayerL(context).trackerImport),
          ),
        ],
      ),
    );
    controller.dispose();
    if (source == null) return;
    try {
      await store.importPrayers(source);
      await refresh();
    } on FormatException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(prayerL(context).trackerInvalidJson)),
        );
      }
    } on TypeError catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(prayerL(context).trackerInvalidPrayerData)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = LocalUserData.ymd(date);
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).trackerPrayerTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          for (final prayer in obligatoryPrayers)
            Card(
              child: ListTile(
                title: Text(prayerLabel(prayerL(context), prayer)),
                subtitle: Text(
                  prayerStatusLabel(prayerL(context), records['$key/$prayer']),
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: prayerL(
                    context,
                  ).trackerRecordPrayer(prayerLabel(prayerL(context), prayer)),
                  onSelected: (status) =>
                      update(prayer, status == 'clear' ? null : status),
                  itemBuilder: (_) => [
                    for (final entry in prayerStatusLabels.entries)
                      PopupMenuItem(
                        value: entry.key,
                        child: Text(
                          prayerStatusLabel(prayerL(context), entry.key),
                        ),
                      ),
                    PopupMenuItem(
                      value: 'clear',
                      child: Text(prayerL(context).trackerClear),
                    ),
                  ],
                ),
              ),
            ),
          ListTile(title: Text(prayerL(context).trackerQadaHelp)),
          for (final prayer in obligatoryPrayers)
            ListTile(
              title: Text(prayerLabel(prayerL(context), prayer)),
              subtitle: Text(
                prayerL(
                  context,
                ).trackerRemaining(prayerNumber(context, qada[prayer] ?? 0)),
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: prayerL(context).trackerDecreaseQada(
                      prayerLabel(prayerL(context), prayer),
                    ),
                    onPressed: () async {
                      await store.adjustQada(prayer, -1);
                      await refresh();
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    tooltip: prayerL(context).trackerIncreaseQada(
                      prayerLabel(prayerL(context), prayer),
                    ),
                    onPressed: () async {
                      await store.adjustQada(prayer, 1);
                      await refresh();
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          Text(
            prayerL(context).trackerMissedCount(
              prayerNumber(
                context,
                records.values.where((status) => status == 'missed').length,
              ),
            ),
          ),
          Text(prayerL(context).trackerThisWeek(_summary(context, weekly))),
          Text(prayerL(context).trackerThisMonth(_summary(context, monthly))),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async => SharePlus.instance.share(
                  ShareParams(text: await store.exportPrayers()),
                ),
                child: Text(prayerL(context).trackerExportJson),
              ),
              OutlinedButton(
                onPressed: importJson,
                child: Text(prayerL(context).trackerImportJson),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _summary(
    BuildContext context,
    Map<String, int> counts,
  ) => prayerStatusLabels.entries
      .map(
        (entry) =>
            '${prayerStatusLabel(prayerL(context), entry.key)}: ${prayerNumber(context, counts[entry.key] ?? 0)}',
      )
      .join(' â€¢ ');
}
