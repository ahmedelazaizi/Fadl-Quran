import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/local_notifications.dart';
import '../../core/offline_prayer.dart';
import '../../core/theme.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';

/// Applies a settings patch, reschedules local notifications and reports errors.
Future<void> applyPrayerSetting(
  BuildContext context,
  Map<String, Object?> patch,
) async {
  final state = context.read<AppState>();
  try {
    await state.updateSettings(patch);
    LocalNotifications.instance.reschedule(state);
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message);
  }
}

Future<void> showCalcMethodSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final current = sheetContext.read<AppState>().settings['calcMethod'];
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                prayerL(sheetContext).calculationMethod,
                style: FadlFonts.heading(size: 20),
              ),
              const SizedBox(height: 8),
              for (final method in calcMethods.keys)
                ListTile(
                  title: Text(
                    calculationLabel(prayerL(sheetContext), method),
                    style: FadlFonts.ui(size: 15),
                  ),
                  trailing: method == current
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: FadlColors.sage,
                        )
                      : null,
                  selected: method == current,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    applyPrayerSetting(context, {
                      'calcMethod': method,
                      'calcMethodManual': true,
                    });
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showMadhabSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      final current =
          sheetContext.read<AppState>().settings['madhab'] ?? 'shafi';
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prayerL(sheetContext).asrCalculationSchool,
                style: FadlFonts.heading(size: 20),
              ),
              const SizedBox(height: 8),
              for (final madhab in ['shafi', 'hanafi'])
                ListTile(
                  title: Text(
                    madhabLabel(prayerL(sheetContext), madhab),
                    style: FadlFonts.ui(size: 15),
                  ),
                  trailing: madhab == current
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: FadlColors.sage,
                        )
                      : null,
                  selected: madhab == current,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    applyPrayerSetting(context, {'madhab': madhab});
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Per-prayer minute offsets (settings `adjustments`), to match the local
/// mosque or official calendar; every change reschedules the adhan.
Future<void> showTimeAdjustmentsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const _TimeAdjustments(),
  );
}

class _TimeAdjustments extends StatelessWidget {
  const _TimeAdjustments();

  static const limit = 30;

  @override
  Widget build(BuildContext context) {
    final l = prayerL(context);
    final adjustments = Map<String, dynamic>.from(
      context.select<AppState, Map?>(
            (s) => s.settings['adjustments'] as Map?,
          ) ??
          const {},
    );
    int minutes(String prayer) => (adjustments[prayer] as num?)?.toInt() ?? 0;
    void set(String prayer, int value) => applyPrayerSetting(context, {
      'adjustments': {...adjustments, prayer: value},
    });
    String signed(int value) => value == 0
        ? prayerNumber(context, 0)
        : value > 0
        ? '+${prayerNumber(context, value)}'
        : '−${prayerNumber(context, -value)}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.manualAdjustments, style: FadlFonts.heading(size: 20)),
            const SizedBox(height: 4),
            Text(l.manualAdjustmentsHint, style: FadlFonts.ui(size: 13)),
            const SizedBox(height: 8),
            for (final prayer in OfflinePrayer.adjustablePrayers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        prayerLabel(l, prayer),
                        style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: l.minuteEarlier,
                      onPressed: minutes(prayer) <= -limit
                          ? null
                          : () => set(prayer, minutes(prayer) - 1),
                      icon: const Icon(Icons.remove, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        l.minutesShort(signed(minutes(prayer))),
                        textAlign: TextAlign.center,
                        style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: l.minuteLater,
                      onPressed: minutes(prayer) >= limit
                          ? null
                          : () => set(prayer, minutes(prayer) + 1),
                      icon: const Icon(Icons.add, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: adjustments.values.every((v) => v == 0)
                    ? null
                    : () => applyPrayerSetting(context, {'adjustments': {}}),
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(l.resetAdjustments),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// −1 / 0 / +1 stepper for the Hijri date correction.
class HijriAdjustmentStepper extends StatelessWidget {
  const HijriAdjustmentStepper({super.key});

  @override
  Widget build(BuildContext context) {
    final value =
        (context.select<AppState, num?>(
                  (s) => s.settings['hijriAdjustment'] as num?,
                ) ??
                0)
            .toInt();
    final label = value == 0
        ? prayerNumber(context, 0)
        : (value > 0
              ? '+${prayerNumber(context, value)}'
              : '−${prayerNumber(context, -value)}');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          tooltip: prayerL(context).decreaseDay,
          onPressed: value <= -1
              ? null
              : () =>
                    applyPrayerSetting(context, {'hijriAdjustment': value - 1}),
          icon: const Icon(Icons.remove, size: 18),
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: 36,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: FadlFonts.ui(size: 16, weight: FontWeight.w700),
          ),
        ),
        IconButton.outlined(
          tooltip: prayerL(context).increaseDay,
          onPressed: value >= 1
              ? null
              : () =>
                    applyPrayerSetting(context, {'hijriAdjustment': value + 1}),
          icon: const Icon(Icons.add, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// Settings-style row: leading icon, title, subtitle, trailing.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: FadlColors.sage),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: FadlFonts.ui(
                        size: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
