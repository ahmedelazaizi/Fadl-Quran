import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';

const juzNamesAr = [
  'الأول',
  'الثاني',
  'الثالث',
  'الرابع',
  'الخامس',
  'السادس',
  'السابع',
  'الثامن',
  'التاسع',
  'العاشر',
  'الحادي عشر',
  'الثاني عشر',
  'الثالث عشر',
  'الرابع عشر',
  'الخامس عشر',
  'السادس عشر',
  'السابع عشر',
  'الثامن عشر',
  'التاسع عشر',
  'العشرون',
  'الحادي والعشرون',
  'الثاني والعشرون',
  'الثالث والعشرون',
  'الرابع والعشرون',
  'الخامس والعشرون',
  'السادس والعشرون',
  'السابع والعشرون',
  'الثامن والعشرون',
  'التاسع والعشرون',
  'الثلاثون',
];

/// Strips tashkeel and unifies alef/ya/ta-marbuta for name matching.
String normalizeArabicName(String s) => s
    .replaceAll(RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
    .replaceAll(RegExp('[آأإٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'^سوره\s*'), '')
    .trim();

/// Octagon (rub el hizb style) badge with an Eastern-digit number.
class NumberBadge extends StatelessWidget {
  const NumberBadge(this.number, {super.key, this.size = 40});
  final int number;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OctagonPainter(dark ? FadlColors.goldLight : FadlColors.gold),
        child: Center(
          child: Text(
            arNum(number),
            style: FadlFonts.ui(
              size: size * (number > 99 ? 0.3 : 0.36),
              weight: FontWeight.w700,
              color: dark ? FadlColors.goldLight : FadlColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OctagonPainter extends CustomPainter {
  _OctagonPainter(this.color);
  final Color color;

  Path _square(Size size, double rotation) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.86;
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = rotation + i * math.pi / 2 + math.pi / 4;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color.withValues(alpha: 0.12);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final rot in [0.0, math.pi / 4]) {
      final p = _square(size, rot);
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    }
  }

  @override
  bool shouldRepaint(_OctagonPainter old) => old.color != color;
}
