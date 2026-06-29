import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/profile.dart';
import '../../state/providers.dart';
import '../../widgets/app_scaffold.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Profile? _draft;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(planDataProvider);
    return AppScaffold(
      title: 'Profile',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final p = _draft ??= data.profile;
          return PageBody(
            child: SectionCard(
              title: 'About you',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    initialValue: p.name ?? '',
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (v) => _draft = p.copyWith(name: v),
                  ),
                  const SizedBox(height: 12),
                  _BirthDateField(
                    value: p.birthDate,
                    onChanged: (d) => setState(() => _draft = p.copyWith(birthDate: d)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _IntField(
                          label: 'Retirement age',
                          value: p.retirementAge,
                          onChanged: (v) => _draft = p.copyWith(retirementAge: v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _IntField(
                          label: 'Plan to age',
                          value: p.lifeExpectancy,
                          onChanged: (v) => _draft = p.copyWith(lifeExpectancy: v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<FilingStatus>(
                    value: p.filingStatus,
                    decoration: const InputDecoration(labelText: 'Tax filing status'),
                    items: [
                      for (final f in FilingStatus.values)
                        DropdownMenuItem(value: f, child: Text(f.label)),
                    ],
                    onChanged: (f) =>
                        setState(() => _draft = p.copyWith(filingStatus: f ?? p.filingStatus)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: p.state ?? '',
                    decoration: const InputDecoration(
                        labelText: 'State (optional)', helperText: 'Used for context; state tax not modeled'),
                    onChanged: (v) => _draft = p.copyWith(state: v),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            await ref.read(dataServiceProvider).saveProfile(_draft!);
                            ref.invalidate(planDataProvider);
                            if (context.mounted) {
                              setState(() => _saving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile saved')));
                            }
                          },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BirthDateField extends StatelessWidget {
  const _BirthDateField({required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(now.year - 55),
          firstDate: DateTime(now.year - 100),
          lastDate: now,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Date of birth'),
        child: Text(value == null ? 'Tap to select' : DateFormat.yMMMMd().format(value!)),
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({required this.label, required this.value, required this.onChanged});
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
