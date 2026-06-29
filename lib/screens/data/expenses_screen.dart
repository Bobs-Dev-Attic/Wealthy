import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../state/providers.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/editor_fields.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(planDataProvider);
    return AppScaffold(
      title: 'Expenses',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.expenses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Add your expected retirement expenses: living costs, housing, '
                  'healthcare, travel. Healthcare grows at the healthcare inflation rate.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final total = data.expenses.fold(0.0, (s, e) => s + e.annualAmount);
          return PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'Total annual expenses (today\'s dollars)',
                  child: Text(money(total),
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                for (final e in data.expenses)
                  Card(
                    child: ListTile(
                      title: Text(e.name.isEmpty ? e.category.label : e.name),
                      subtitle: Text(
                          '${e.category.label} · inflation ${percent(e.inflationRate)}${e.startAge != null ? ' · from ${e.startAge}' : ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${money(e.annualAmount)}/yr',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref.read(dataServiceProvider).deleteExpense(e.id!);
                              ref.invalidate(planDataProvider);
                            },
                          ),
                        ],
                      ),
                      onTap: () => _edit(context, ref, e),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Expense? existing) async {
    final result = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExpenseEditor(existing: existing),
    );
    if (result != null) {
      await ref.read(dataServiceProvider).upsertExpense(result);
      ref.invalidate(planDataProvider);
    }
  }
}

class _ExpenseEditor extends StatefulWidget {
  const _ExpenseEditor({this.existing});
  final Expense? existing;
  @override
  State<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends State<_ExpenseEditor> {
  late String _name = widget.existing?.name ?? '';
  late ExpenseCategory _category = widget.existing?.category ?? ExpenseCategory.living;
  late double _amount = widget.existing?.annualAmount ?? 0;
  late double _inflation = widget.existing?.inflationRate ?? 0.03;
  late int? _startAge = widget.existing?.startAge;
  late int? _endAge = widget.existing?.endAge;

  @override
  Widget build(BuildContext context) {
    return EditorSheet(
      title: widget.existing == null ? 'Add expense' : 'Edit expense',
      onSave: () => Navigator.pop(
        context,
        (widget.existing ??
                const Expense(name: '', category: ExpenseCategory.living, annualAmount: 0))
            .copyWith(
          name: _name.trim(),
          category: _category,
          annualAmount: _amount,
          inflationRate: _inflation,
          startAge: _startAge,
          endAge: _endAge,
        ),
      ),
      children: [
        DropdownButtonFormField<ExpenseCategory>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final c in ExpenseCategory.values)
              DropdownMenuItem(value: c, child: Text(c.label)),
          ],
          onChanged: (c) => setState(() {
            _category = c ?? _category;
            if (_category == ExpenseCategory.healthcare) _inflation = 0.05;
          }),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _name,
          decoration: const InputDecoration(labelText: 'Label (optional)'),
          onChanged: (v) => _name = v,
        ),
        const SizedBox(height: 12),
        MoneyField(
            label: 'Annual amount (today\'s dollars)', value: _amount, onChanged: (v) => _amount = v),
        const SizedBox(height: 12),
        PercentField(label: 'Inflation rate', value: _inflation, onChanged: (v) => _inflation = v),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _startAge?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Start age (blank = retirement)'),
                onChanged: (v) => _startAge = int.tryParse(v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: _endAge?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'End age (blank = end)'),
                onChanged: (v) => _endAge = int.tryParse(v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
