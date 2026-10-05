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
      _ => l.trackerReceivables,
    };
  }

  bool useGold = true;

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
            title: Text(prayerL(context).trackerNisab),
            trailing: Text(breakdown.nisab.toStringAsFixed(2)),
          ),
          ListTile(
            title: Text(prayerL(context).trackerEstimatedZakat),
            trailing: Text(breakdown.due.toStringAsFixed(2)),
          ),
          const Text(
            'مرجع شائع للنصاب: ٨٥ غراماً من الذهب أو ٥٩٥ غراماً من الفضة. تختلف أحكام النصاب والتقييم والحول والديون باختلاف الحال؛ راجع عالماً مؤهلاً قبل الاعتماد على النتيجة.',
          ),
        ],
      ),
    );
  }
}
