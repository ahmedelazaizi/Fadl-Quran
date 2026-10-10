import 'package:flutter/material.dart';

/// Shows a dialog with text fields whose controllers live exactly as long
/// as the dialog. Disposing them as soon as `showDialog` returns breaks the
/// closing animation, which still draws the fields; here they are disposed
/// once the dialog has left the screen. The dialog returns what it needs
/// from the fields through `Navigator.pop`.
Future<T?> showTextDialog<T>({
  required BuildContext context,
  required List<String> initialTexts,
  required Widget Function(
    BuildContext context,
    List<TextEditingController> fields,
  )
  builder,
}) => showDialog<T>(
  context: context,
  builder: (_) => _OwnedFields(initialTexts: initialTexts, builder: builder),
);

class _OwnedFields extends StatefulWidget {
  const _OwnedFields({required this.initialTexts, required this.builder});

  final List<String> initialTexts;
  final Widget Function(BuildContext, List<TextEditingController>) builder;

  @override
  State<_OwnedFields> createState() => _OwnedFieldsState();
}

class _OwnedFieldsState extends State<_OwnedFields> {
  late final _fields = [
    for (final text in widget.initialTexts) TextEditingController(text: text),
  ];

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _fields);
}
