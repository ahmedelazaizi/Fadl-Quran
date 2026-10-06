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
    if (month == 1 && day == 9) 'تاسوعاء',
    if (month == 1 && day == 10) 'عاشوراء',
    // Fasting the days of tashreeq is forbidden (Muslim 1141), so 13
    // Dhul-Hijjah is not one of that month's white days.
    if (month == 12 && day >= 11 && day <= 13) 'أيام التشريق',
    if (day >= 13 && day <= 15 && !(month == 12 && day == 13)) 'الأيام البيض',
    if (date.weekday == DateTime.monday) 'الاثنين',
    if (date.weekday == DateTime.thursday) 'الخميس',
  ];
}

/// Gold karats offered by the zakat calculator; purity is karat / 24.
const zakatGoldKarats = [24, 22, 21, 18];

/// Zakat on money, gold, silver and trade goods at 2.5% once the net
/// total reaches the nisab: 20 dinars ≈ 85 g pure gold or 200 dirhams
/// ≈ 595 g pure silver.
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
    this.goldKarat = 24,
    this.debts = 0,
  });

  final double cash, goldGrams, silverGrams, goldPrice, silverPrice;
  final double inventory, receivables;
  final bool useGoldNisab;

  /// Karat of [goldGrams]; [goldPrice] is the price of pure (24k) gold.
  final int goldKarat;

  /// Debts the owner must pay now, deducted before the nisab check.
  final double debts;

  double get pureGoldGrams => goldGrams * goldKarat / 24;
  double get goldValue => pureGoldGrams * goldPrice;
  double get silverValue => silverGrams * silverPrice;
  double get total => cash + goldValue + silverValue + inventory + receivables;
  double get net => total > debts ? total - debts : 0;
  double get nisab => useGoldNisab ? 85 * goldPrice : 595 * silverPrice;
  double get due => nisab > 0 && net >= nisab ? net * 0.025 : 0;
}
