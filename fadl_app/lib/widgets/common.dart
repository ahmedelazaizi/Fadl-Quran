import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/offline_athkar.dart';
import '../core/theme.dart';
import '../l10n/prayer_labels.dart';

/// Loads data with [load] and renders it with [builder]; shows a spinner,
/// and an error card with retry on failure. Call `key.currentState.reload()`
/// or pass a new [reloadToken] to refresh.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.reloadToken,
  });
  final Future<T> Function() load;
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() reload,
  )
  builder;
  final Object? reloadToken;

  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  Future<void> reload() async {
    final f = widget.load();
    // A block body: an arrow would return the Future to setState.
    setState(() {
      _future = f;
    });
    await f.catchError((_) => null as T);
  }

  @override
  void didUpdateWidget(covariant AsyncView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) _future = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError) {
          return ErrorCard(
            message: '${snap.error}',
            error: snap.error,
            onRetry: reload,
          );
        }
        return widget.builder(context, snap.data as T, reload);
      },
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message, this.error, this.onRetry});
  final String message;

  /// The original error, when available; used to detect the offline case.
  final Object? error;
  final VoidCallback? onRetry;

  /// True for the immediate rejection thrown when no backend is configured.
  /// Screens that pass only the message are matched by its API_BASE hint.
  bool get _backendMissing {
    if (Api.hasBackend) return false;
    final e = error;
    if (e != null) return e is ApiException && e.statusCode == 0;
    return message.contains('API_BASE');
  }

  @override
  Widget build(BuildContext context) {
    final offline = _backendMissing;
    final onRetry = offline ? null : this.onRetry;
    // Friendly text shown instead of the "server not configured" error.
    final message = offline
        ? prayerL(context).offlineFeatureMessage
        : this.message;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FadlFonts.ui(size: 15),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(prayerL(context).retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Level-1 card from the design system: white, 16px radius, hairline border.
class FadlCard extends StatelessWidget {
  const FadlCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius = 16,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: FadlColors.emerald.withValues(alpha: dark ? 0.3 : 0.07),
            ),
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF17382E).withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? FadlColors.darkText
        : FadlColors.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: FadlFonts.heading(size: 19, color: color),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Rounded icon tile used in the quick-access grid.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.gold = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FadlCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: gold
                  ? FadlColors.goldLight
                  : (dark ? FadlColors.darkSurfaceHigh : FadlColors.mintSoft),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: gold
                  ? FadlColors.primary
                  : (dark ? FadlColors.mint : FadlColors.sage),
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: FadlFonts.ui(size: 12.5, weight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped filter chip (selected = solid sage).
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: selected ? FadlColors.sage : scheme.surfaceContainerLowest,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? FadlColors.sage : scheme.outlineVariant,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: FadlFonts.ui(
                size: 13,
                weight: FontWeight.w600,
                color: selected ? Colors.white : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded badge, e.g. "صحيح" or "مكية".
class Badge2 extends StatelessWidget {
  const Badge2(
    this.text, {
    super.key,
    this.color = FadlColors.sage,
    this.background,
  });
  final String text;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: FadlFonts.ui(size: 12, weight: FontWeight.w700, color: color),
    ),
  );
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: FadlFonts.ui(size: 14, color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: FadlColors.emerald,
      ),
    );
}

/// Records "إهداء الثواب" for the configured dedicatee and shows a toast.
Future<void> dedicate(
  BuildContext context,
  String type, {
  int amount = 1,
  String? refKey,
}) async {
  try {
    if (Api.hasBackend) {
      await Api.instance.post('/me/dedications', {
        'type': type,
        'amount': amount,
        'refKey': ?refKey,
      });
    } else {
      await OfflineAthkarStore.dedicate(type, amount: amount);
    }
    if (context.mounted) {
      showToast(
        context,
        prayerL(
          context,
        ).athkarDedicationRecorded(context.read<AppState>().dedicatee),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message);
  }
}

/// Banner "صدقة جارية عن المرحوم ..." shown on devotional screens.
class DedicationBanner extends StatelessWidget {
  const DedicationBanner({super.key, required this.type, this.label});
  final String type;

  /// Button text; defaults to the localized "Dedicate the reward".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AppState>().dedicatee;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FadlColors.emerald,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FadlColors.gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.volunteer_activism_rounded,
            color: FadlColors.goldLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayerL(context).dedicationLabel,
                  style: FadlFonts.ui(size: 12, color: FadlColors.onEmerald),
                ),
                Text(
                  name,
                  style: FadlFonts.heading(size: 16, color: Colors.white),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: FadlColors.gold.withValues(alpha: 0.2),
              foregroundColor: FadlColors.goldLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => dedicate(context, type),
            child: Text(
              label ?? prayerL(context).dedicateRewardAction,
              style: FadlFonts.ui(
                size: 13,
                weight: FontWeight.w700,
                color: FadlColors.goldLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative ayah-end marker with the ayah number: ﴿٥﴾
String ayahMarker(int n) {
  const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  final digits = n
      .toString()
      .split('')
      .map((d) => eastern[int.parse(d)])
      .join();
  return '\u06DD$digits';
}
