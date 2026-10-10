import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports its child's height after each layout that changes it, so
/// content underneath a floating panel can leave room for it.
class MeasureHeight extends SingleChildRenderObjectWidget {
  const MeasureHeight({super.key, required this.onChange, super.child});

  final ValueChanged<double> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMeasureHeight(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMeasureHeight renderObject,
  ) => renderObject.onChange = onChange;
}

class RenderMeasureHeight extends RenderProxyBox {
  RenderMeasureHeight(this.onChange);

  ValueChanged<double> onChange;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    // Layout cannot rebuild widgets; report once this frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(height));
  }
}
