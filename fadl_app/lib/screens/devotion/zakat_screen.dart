import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/worship_calendar.dart';
import '../../l10n/prayer_labels.dart';

class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});

  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  final fields = <String, TextEditingController>{
    for (final key in [
      'cash',
      'goldGrams',
      'goldPrice',
      'silverGrams',
      'silverPrice',
      'inventory',
      'receivables',
      'debts',
    ])
      key: TextEditingController(),
  };

  String fieldLabel(BuildContext context, String key) {
    final l = prayerL(context);
    return switch (key) {
      'cash' => l.trackerCash,
      'goldGrams' => l.trackerGoldGrams,
      'goldPrice' => l.trackerGoldPrice,
      'silverGrams' => l.trackerSilverGrams,
      'silverPrice' => l.trackerSilverPrice,
      'inventory' => l.trackerInventory,
      'receivables' => l.trackerReceivables,
      _ => l.trackerDebts,
    };
  }

  bool useGold = true;
  int goldKarat = 24;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        fields['goldPrice']!.text =
            prefs.getString('fadl.zakat.goldPrice') ?? '';
        fields['silverPrice']!.text =
            prefs.getString('fadl.zakat.silverPrice') ?? '';
        useGold = prefs.getBool('fadl.zakat.goldNisab') ?? true;
        final karat = prefs.getInt('fadl.zakat.goldKarat');
        if (zakatGoldKarats.contains(karat)) goldKarat = karat!;
      });
    });
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double amount(String label) =>
      double.tryParse(
        fields[label]!.text.replaceAll(',', '.'),
      )?.clamp(0, double.infinity).toDouble() ??
      0;

  @override
  Widget build(BuildContext context) {
    final breakdown = ZakatBreakdown(
      cash: amount('cash'),
      goldGrams: amount('goldGrams'),
      goldPrice: amount('goldPrice'),
      silverGrams: amount('silverGrams'),
      silverPrice: amount('silverPrice'),
      inventory: amount('inventory'),
      receivables: amount('receivables'),
      useGoldNisab: useGold,
      goldKarat: goldKarat,
      debts: amount('debts'),
    );
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).trackerZakatTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final field in fields.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: field.value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: fieldLabel(context, field.key),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (text) async {
                  if (field.key == 'goldPrice' || field.key == 'silverPrice') {
                    final key = field.key == 'goldPrice'
                        ? 'fadl.zakat.goldPrice'
                        : 'fadl.zakat.silverPrice';
                    await (await SharedPreferences.getInstance()).setString(
                      key,
                      text,
                    );
                  }
                  if (mounted) setState(() {});
                },
              ),
            ),
          DropdownButtonFormField<int>(
            initialValue: goldKarat,
            decoration: InputDecoration(
              labelText: prayerL(context).trackerGoldKarat,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final karat in zakatGoldKarats)
                DropdownMenuItem(
                  value: karat,
                  child: Text(
                    prayerL(context).trackerKarat(prayerNumber(context, karat)),
                  ),
                ),
            ],
            onChanged: (karat) async {
              if (karat == null) return;
              setState(() => goldKarat = karat);
              await (await SharedPreferences.getInstance()).setInt(
                'fadl.zakat.goldKarat',
                karat,
              );
            },
          ),
          const SizedBox(height: 10),
          Text(prayerL(context).trackerCurrencyHint),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(prayerL(context).trackerGoldNisab),
              ),
              ButtonSegment(
                value: false,
                label: Text(prayerL(context).trackerSilverNisab),
              ),
            ],
            selected: {useGold},
            onSelectionChanged: (choice) async {
              setState(() => useGold = choice.first);
              await (await SharedPreferences.getInstance()).setBool(
                'fadl.zakat.goldNisab',
                useGold,
              );
            },
          ),
          ListTile(
            title: Text(prayerL(context).trackerGoldValue),
            trailing: Text(breakdown.goldValue.toStringAsFixed(2)),
          ),
          ListTile(
            title: Text(prayerL(context).trackerSilverValue),
            trailing: Text(breakdown.silverValue.toStringAsFixed(2)),
          ),
          ListTile(
            title: Text(prayerL(context).trackerTotalAssets),
            trailing: Text(breakdown.total.toStringAsFixed(2)),
          ),
          ListTile(
            title: Text(prayerL(context).trackerNetAssets),
            trailing: Text(breakdown.net.toStringAsFixed(2)),
          ),
          ListTile(
            title: Text(prayerL(context).trackerNisab),
            trailing: Text(breakdown.nisab.toStringAsFixed(2)),
          ),
          ListTile(
            title: Text(prayerL(context).trackerEstimatedZakat),
            trailing: Text(breakdown.due.toStringAsFixed(2)),
          ),
          Text(prayerL(context).trackerZakatNotice),
        ],
      ),
    );
  }
}
