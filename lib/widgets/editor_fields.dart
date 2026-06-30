import 'package:flutter/material.dart';

import '../core/formatters.dart';

/// A bottom-sheet editor scaffold with a title, scrollable body, and Save button.
class EditorSheet extends StatelessWidget {
  const EditorSheet({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ...children,
                const SizedBox(height: 20),
                FilledButton(onPressed: onSave, child: const Text('Save')),
                const SizedBox(height: 4),
                TextButton(
                    onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A text field for dollar amounts. Reports a parsed [double]. When [help] is
/// set, an info icon is shown that reveals the text on hover (web) or tap.
class MoneyField extends StatelessWidget {
  const MoneyField(
      {super.key, required this.label, required this.value, required this.onChanged, this.help});
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value == 0 ? '' : value.toStringAsFixed(0),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\$ ',
        suffixIcon: help == null ? null : HelpIcon(message: help!),
      ),
      onChanged: (v) => onChanged(parseMoney(v)),
    );
  }
}

/// A small info icon whose tooltip appears on hover (web) or tap (touch).
class HelpIcon extends StatelessWidget {
  const HelpIcon({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 8),
      preferBelow: false,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Icon(Icons.info_outline,
          size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

/// A text field for percentages. Stores/returns a fraction (0.04 for "4").
class PercentField extends StatelessWidget {
  const PercentField({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value == 0 ? '' : (value * 100).toStringAsFixed(1),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: '%'),
      onChanged: (v) => onChanged(parsePercent(v)),
    );
  }
}

/// A simple integer field (e.g. an age).
class IntField extends StatelessWidget {
  const IntField({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => onChanged(int.tryParse(v) ?? value),
    );
  }
}
