import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';

/// 14250 → ١٤٬٢٥٠
String arInt(num value) =>
    arNum(NumberFormat('#,##0', 'en').format(value)).replaceAll(',', '٬');

/// Random id used to make offline uploads idempotent.
String randomEventId() {
  final r = math.Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

const _ordinals = [
  'الأولى',
  'الثانية',
  'الثالثة',
  'الرابعة',
  'الخامسة',
  'السادسة',
  'السابعة',
  'الثامنة',
  'التاسعة',
  'العاشرة',
];

/// 1 → الأولى, 11 → ١١
String arOrdinal(int n) =>
    n >= 1 && n <= _ordinals.length ? _ordinals[n - 1] : arNum(n);

bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color headingColor(BuildContext context) =>
    isDark(context) ? FadlColors.darkText : FadlColors.primary;

/// Circular progress ring with a centered child.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.size,
    required this.child,
    this.stroke = 10,
    this.color = FadlColors.sage,
    this.track,
  });

  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color? track;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0, 1).toDouble(),
          stroke: stroke,
          color: color,
          track: track ?? Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.track,
  });
  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inner = rect.deflate(stroke / 2);
    canvas.drawArc(
      inner,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (value <= 0) return;
    canvas.drawArc(
      inner,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

/// Small round icon button used in card action rows.
class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainerLow,
        foregroundColor: isDark(context) ? FadlColors.mint : FadlColors.sage,
      ),
    );
  }
}

/// Stat tile: big number + label (used on khatma / dua stats).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });
  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, color: FadlColors.gold, size: 22),
        Text(
          value,
          style: FadlFonts.heading(size: 20, color: headingColor(context)),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: FadlFonts.ui(
            size: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
