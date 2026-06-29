import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/plan_controller.dart';
import '../../state/providers.dart';
import 'input_tabs.dart';
import 'result_tabs.dart';

/// The whole experience on one screen: tabbed inputs on top, tabbed live
/// results on the bottom. Editing any field updates the results in real time.
class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(planControllerProvider.select((s) => s.loaded));

    Future<void> logout() async {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go('/login');
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          Icon(Icons.savings_outlined, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          const Text('Wealthy', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          if (!loaded)
            const SizedBox(
                width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'security') context.go('/security');
              if (v == 'logout') logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'security', child: Text('Security & password')),
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: const Column(
        children: [
          Expanded(
            child: _Half(
              label: 'YOUR INFORMATION',
              icon: Icons.edit_note,
              tabs: ['You', 'Investments', 'Income', 'Expenses', 'Liabilities', 'Taxes', 'Assumptions'],
              views: [
                YouTab(),
                InvestmentsTab(),
                IncomeTab(),
                ExpensesTab(),
                LiabilitiesTab(),
                TaxesTab(),
                AssumptionsTab(),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1),
          Expanded(
            child: _Half(
              label: 'RESULTS',
              icon: Icons.insights,
              tabs: ['Summary', 'Net worth', 'Retirement', 'Cash flow', 'Taxes', 'RMD', 'Healthcare'],
              views: [
                SummaryView(),
                NetWorthView(),
                RetirementView(),
                CashFlowView(),
                TaxesView(),
                RmdView(),
                HealthcareView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({required this.label, required this.icon, required this.tabs, required this.views});
  final String label;
  final IconData icon;
  final List<String> tabs;
  final List<Widget> views;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Container(
            color: scheme.surface,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  child: Row(children: [
                    Icon(icon, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant)),
                  ]),
                ),
                Expanded(
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: [for (final t in tabs) Tab(text: t, height: 40)],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: TabBarView(children: views)),
        ],
      ),
    );
  }
}
