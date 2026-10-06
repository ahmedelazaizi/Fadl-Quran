import 'package:flutter/material.dart';

/// Window width from which the tabs move into a side rail (Material's
/// "expanded" size: iPad landscape, large tablets).
const sideNavigationBreakpoint = 840.0;

/// Widest the app grows; beyond it, it stays centred so lines of text and
/// lists keep a readable length on large iPads.
const maxAppWidth = 1000.0;

bool useSideNavigation(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= sideNavigationBreakpoint;

/// Centres the whole app at [maxAppWidth] on wide screens. The reported
/// MediaQuery size shrinks with it, so sheets and layouts that measure the
/// screen measure the frame instead.
class TabletFrame extends StatelessWidget {
  const TabletFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxAppWidth) return child;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: maxAppWidth,
          child: MediaQuery(
            data: media.copyWith(
              size: Size(maxAppWidth, media.size.height),
              padding: media.padding.copyWith(left: 0, right: 0),
              viewPadding: media.viewPadding.copyWith(left: 0, right: 0),
              viewInsets: media.viewInsets.copyWith(left: 0, right: 0),
            ),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
