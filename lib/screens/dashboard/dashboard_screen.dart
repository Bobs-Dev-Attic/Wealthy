import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../state/providers.dart';
import '../../widgets/app_scaffold.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(planDataProvider);
    return AppScaffold(
      title: 'Wealthy',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final projection = ref.watch(projectionProvider);
          final name = data.profile.name;
          return PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(name == null || name.isEmpty ? 'Welcome' : 'Welcome, $name',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Net worth',
                        value: money(data.netWorth),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Plan success',
                        value: projection == null
                            ? '—'
                            : percent(projection.monteCarlo.successRate),
                        icon: Icons.verified_outlined,
                        color: projection == null
                            ? null
                            : _successColor(projection.monteCarlo.successRate),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (data.accounts.isEmpty)
                  _OnboardingCard()
                else if (projection != null) ...[
                  SectionCard(
                    title: 'Retirement outlook',
                    trailing: TextButton(
                      onPressed: () => context.go('/projections'),
                      child: const Text('Details'),
                    ),
                    child: Column(
                      children: [
                        _row('Monte Carlo success rate',
                            percent(projection.monteCarlo.successRate)),
                        _row('First-year withdrawal rate',
                            percent(projection.firstYearWithdrawalRate)),
                        _row('Median ending balance (age ${data.assumptions.endAge})',
                            money(projection.monteCarlo.endingP50)),
                        _row(
                          'Plan depletes at',
                          projection.depletionAge == null
                              ? 'Never (lasts the horizon)'
                              : 'age ${projection.depletionAge}',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _QuickLinks(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  static Color _successColor(double rate) {
    if (rate >= 0.85) return Colors.greenAccent;
    if (rate >= 0.6) return Colors.amberAccent;
    return Colors.redAccent;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Let\'s build your plan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add a few details to unlock Monte Carlo projections, '
              'withdrawal rates, RMDs and tax estimates:'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, 'Set your profile', '/profile'),
              _chip(context, 'Add accounts', '/accounts'),
              _chip(context, 'Add income', '/income'),
              _chip(context, 'Add expenses', '/expenses'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String route) => ActionChip(
        label: Text(label),
        onPressed: () => context.go(route),
      );
}

class _QuickLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Manage',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip(context, 'Profile', '/profile'),
          _chip(context, 'Accounts', '/accounts'),
          _chip(context, 'Income', '/income'),
          _chip(context, 'Expenses', '/expenses'),
          _chip(context, 'Assumptions', '/plan'),
          _chip(context, 'Projections', '/projections'),
          _chip(context, 'Security', '/security'),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String route) =>
      ActionChip(label: Text(label), onPressed: () => context.go(route));
}
