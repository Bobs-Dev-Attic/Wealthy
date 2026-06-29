import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/plan_controller.dart';
import '../../state/providers.dart';
import 'input_tabs.dart';
import 'result_tabs.dart';

/// The whole experience on one screen: tabbed inputs on top, tabbed live
/// results on the bottom, separated by a draggable divider. Editing any field
/// updates the results in real time.
class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});
  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  /// Fraction of the available height given to the top (inputs) half.
  double _topFraction = 0.5;

  @override
  Widget build(BuildContext context) {
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          const handleHeight = 18.0;
          final avail = constraints.maxHeight - handleHeight;
          final minH = math.min(120.0, avail / 3);
          final topH = (avail * _topFraction).clamp(minH, avail - minH);
          return Column(
            children: [
              SizedBox(
                height: topH,
                child: const _Half(
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
              _ResizeHandle(
                height: handleHeight,
                onDelta: (dy) {
                  setState(() {
                    final newTop = (topH + dy).clamp(minH, avail - minH);
                    _topFraction = (newTop / avail).clamp(0.0, 1.0);
                  });
                },
              ),
              const Expanded(
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
          );
        },
      ),
    );
  }
}

/// Draggable divider between the two halves.
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDelta, required this.height});
  final void Function(double dy) onDelta;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => onDelta(d.delta.dy),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 44,
            height: 4,
            decoration:
                BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
        ),
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
