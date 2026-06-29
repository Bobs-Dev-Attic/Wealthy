import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}

const _navItems = [
  _NavItem('Dashboard', Icons.dashboard_outlined, '/'),
  _NavItem('Profile', Icons.person_outline, '/profile'),
  _NavItem('Accounts', Icons.account_balance_outlined, '/accounts'),
  _NavItem('Income', Icons.payments_outlined, '/income'),
  _NavItem('Expenses', Icons.receipt_long_outlined, '/expenses'),
  _NavItem('Assumptions', Icons.tune_outlined, '/plan'),
  _NavItem('Projections', Icons.show_chart_outlined, '/projections'),
  _NavItem('Security', Icons.lock_outline, '/security'),
];

/// Shared scaffold: app bar + responsive navigation (rail on wide screens,
/// drawer on narrow) used by every authenticated screen.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final loc = GoRouterState.of(context).matchedLocation;
    final selected = _navItems.indexWhere((n) => n.route == loc);

    void go(int i) => context.go(_navItems[i].route);

    Future<void> logout() async {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go('/login');
    }

    final content = Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  children: [
                    const SizedBox(height: 8),
                    for (var i = 0; i < _navItems.length; i++)
                      ListTile(
                        leading: Icon(_navItems[i].icon),
                        title: Text(_navItems[i].label),
                        selected: i == selected,
                        onTap: () {
                          Navigator.pop(context);
                          go(i);
                        },
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: floatingActionButton,
      body: body,
    );

    if (!wide) return content;

    return Row(
      children: [
        NavigationRail(
          selectedIndex: selected < 0 ? 0 : selected,
          onDestinationSelected: go,
          labelType: NavigationRailLabelType.all,
          destinations: [
            for (final n in _navItems)
              NavigationRailDestination(icon: Icon(n.icon), label: Text(n.label)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: content),
      ],
    );
  }
}

/// A titled card section.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Constrains content width and adds padding for comfortable reading on web.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: child,
        ),
      ),
    );
  }
}
