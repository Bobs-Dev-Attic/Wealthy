import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/enums.dart';
import '../../models/income_source.dart';
import '../../state/providers.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/editor_fields.dart';

class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(planDataProvider);
    return AppScaffold(
      title: 'Income',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add income'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.incomes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Add guaranteed income: Social Security, pensions, annuities. '
                  'Enter the annual amount and the age it starts.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final i in data.incomes)
                  Card(
                    child: ListTile(
                      title: Text(i.name.isEmpty ? i.type.label : i.name),
                      subtitle: Text(
                          '${i.type.label} · from age ${i.startAge}${i.endAge != null ? ' to ${i.endAge}' : ''} · COLA ${percent(i.colaRate)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${money(i.annualAmount)}/yr',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref.read(dataServiceProvider).deleteIncome(i.id!);
                              ref.invalidate(planDataProvider);
                            },
                          ),
                        ],
                      ),
                      onTap: () => _edit(context, ref, i),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, IncomeSource? existing) async {
    final result = await showModalBottomSheet<IncomeSource>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IncomeEditor(existing: existing),
    );
    if (result != null) {
      await ref.read(dataServiceProvider).upsertIncome(result);
      ref.invalidate(planDataProvider);
    }
  }
}

class _IncomeEditor extends StatefulWidget {
  const _IncomeEditor({this.existing});
  final IncomeSource? existing;
  @override
  State<_IncomeEditor> createState() => _IncomeEditorState();
}

class _IncomeEditorState extends State<_IncomeEditor> {
  late String _name = widget.existing?.name ?? '';
  late IncomeType _type = widget.existing?.type ?? IncomeType.socialSecurity;
  late double _amount = widget.existing?.annualAmount ?? 0;
  late int _startAge = widget.existing?.startAge ?? 67;
  late int? _endAge = widget.existing?.endAge;
  late double _cola = widget.existing?.colaRate ?? 0.02;

  @override
  Widget build(BuildContext context) {
    return EditorSheet(
      title: widget.existing == null ? 'Add income' : 'Edit income',
      onSave: () => Navigator.pop(
        context,
        (widget.existing ??
                const IncomeSource(name: '', type: IncomeType.socialSecurity, annualAmount: 0))
            .copyWith(
          name: _name.trim(),
          type: _type,
          annualAmount: _amount,
          startAge: _startAge,
          endAge: _endAge,
          colaRate: _cola,
        ),
      ),
      children: [
        DropdownButtonFormField<IncomeType>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            for (final t in IncomeType.values) DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) => setState(() {
            _type = t ?? _type;
            if (_type == IncomeType.socialSecurity && _name.isEmpty) _name = 'Social Security';
          }),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _name,
          decoration: const InputDecoration(labelText: 'Label (optional)'),
          onChanged: (v) => _name = v,
        ),
        const SizedBox(height: 12),
        MoneyField(label: 'Annual amount', value: _amount, onChanged: (v) => _amount = v),
        if (_type == IncomeType.socialSecurity)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Enter your estimated annual benefit (e.g. from ssa.gov) and the age you plan to claim.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: IntField(
                  label: 'Start age', value: _startAge, onChanged: (v) => _startAge = v),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: _endAge?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'End age (blank = lifetime)'),
                onChanged: (v) => _endAge = int.tryParse(v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PercentField(label: 'Annual increase (COLA)', value: _cola, onChanged: (v) => _cola = v),
      ],
    );
  }
}
