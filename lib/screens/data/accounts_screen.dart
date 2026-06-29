import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/account.dart';
import '../../models/enums.dart';
import '../../state/providers.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/editor_fields.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(planDataProvider);
    return AppScaffold(
      title: 'Accounts',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.accounts.isEmpty) {
            return const _Empty(text: 'Add your savings, brokerage, 401(k)/IRA, Roth, HSA and cash.');
          }
          return PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'Total assets',
                  child: Text(money(data.netWorth),
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                for (final a in data.accounts)
                  Card(
                    child: ListTile(
                      title: Text(a.name),
                      subtitle: Text('${a.type.label} · return ${percent(a.expectedReturn)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(money(a.balance),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref.read(dataServiceProvider).deleteAccount(a.id!);
                              ref.invalidate(planDataProvider);
                            },
                          ),
                        ],
                      ),
                      onTap: () => _edit(context, ref, a),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Account? existing) async {
    final result = await showModalBottomSheet<Account>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountEditor(existing: existing),
    );
    if (result != null) {
      await ref.read(dataServiceProvider).upsertAccount(result);
      ref.invalidate(planDataProvider);
    }
  }
}

class _AccountEditor extends StatefulWidget {
  const _AccountEditor({this.existing});
  final Account? existing;
  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  late String _name = widget.existing?.name ?? '';
  late AccountType _type = widget.existing?.type ?? AccountType.taxable;
  late double _balance = widget.existing?.balance ?? 0;
  late double _basis = widget.existing?.costBasis ?? 0;
  late double _return = widget.existing?.expectedReturn ?? 0.06;
  late double _stdev = widget.existing?.returnStdev ?? 0.12;

  @override
  Widget build(BuildContext context) {
    return EditorSheet(
      title: widget.existing == null ? 'Add account' : 'Edit account',
      onSave: _name.trim().isEmpty
          ? null
          : () => Navigator.pop(
                context,
                (widget.existing ?? const Account(name: '', type: AccountType.taxable, balance: 0))
                    .copyWith(
                  name: _name.trim(),
                  type: _type,
                  balance: _balance,
                  costBasis: _type == AccountType.taxable ? _basis : 0,
                  expectedReturn: _return,
                  returnStdev: _stdev,
                ),
              ),
      children: [
        TextFormField(
          initialValue: _name,
          decoration: const InputDecoration(labelText: 'Account name'),
          onChanged: (v) => setState(() => _name = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AccountType>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            for (final t in AccountType.values) DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) => setState(() => _type = t ?? _type),
        ),
        const SizedBox(height: 12),
        MoneyField(label: 'Current balance', value: _balance, onChanged: (v) => _balance = v),
        if (_type == AccountType.taxable) ...[
          const SizedBox(height: 12),
          MoneyField(
            label: 'Cost basis (what you paid)',
            value: _basis,
            onChanged: (v) => _basis = v,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PercentField(
                  label: 'Expected return', value: _return, onChanged: (v) => _return = v),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PercentField(
                  label: 'Volatility (std dev)', value: _stdev, onChanged: (v) => _stdev = v),
            ),
          ],
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
