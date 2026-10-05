import 'offline_prayer.dart';

List<String> hijriOccasions(DateTime date, int adjustment) {
  final hijri = OfflinePrayer.hijri(date, adjustment);
  final month = hijri['month'] as int;
  final day = hijri['day'] as int;
  return [
    if (month == 9 && day == 1) 'بداية رمضان',
    if (month == 10 && day == 1) 'عيد الفطر',
    if (month == 12 && day == 9) 'يوم عرفة',
    if (month == 12 && day == 10) 'عيد الأضحى',
    if (month == 1 && day == 10) 'عاشوراء',
    if (day >= 13 && day <= 15) 'الأيام البيض',
    if (date.weekday == DateTime.monday) 'الاثنين',
    if (date.weekday == DateTime.thursday) 'الخميس',
  ];
}

class ZakatBreakdown {
  const ZakatBreakdown({
    required this.cash,
    required this.goldGrams,
    required this.silverGrams,
    required this.goldPrice,
    required this.silverPrice,
    required this.inventory,
    required this.receivables,
    required this.useGoldNisab,
  });

  final double cash, goldGrams, silverGrams, goldPrice, silverPrice;
  final double inventory, receivables;
  final bool useGoldNisab;

  double get goldValue => goldGrams * goldPrice;
  double get silverValue => silverGrams * silverPrice;
  double get total => cash + goldValue + silverValue + inventory + receivables;
  double get nisab => useGoldNisab ? 85 * goldPrice : 595 * silverPrice;
  double get due => nisab > 0 && total >= nisab ? total * 0.025 : 0;
}
