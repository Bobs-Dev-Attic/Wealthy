import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account.dart';
import '../models/expense.dart';
import '../models/income_source.dart';
import '../models/plan_assumptions.dart';
import '../models/profile.dart';
import '../models/projection_result.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/engine/retirement_projection.dart';

final supabaseClientProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(ref.watch(supabaseClientProvider)));

final dataServiceProvider =
    Provider<DataService>((ref) => DataService(ref.watch(supabaseClientProvider)));

/// Streams Supabase auth changes so the router can react to login/logout.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authServiceProvider).onAuthStateChange,
);

/// All of a user's planning inputs, loaded together.
class PlanData {
  final Profile profile;
  final PlanAssumptions assumptions;
  final List<Account> accounts;
  final List<IncomeSource> incomes;
  final List<Expense> expenses;

  const PlanData({
    required this.profile,
    required this.assumptions,
    required this.accounts,
    required this.incomes,
    required this.expenses,
  });

  double get netWorth => accounts.fold(0.0, (s, a) => s + a.balance);
}

final planDataProvider = FutureProvider<PlanData>((ref) async {
  // Re-run whenever auth changes (e.g. fresh login).
  ref.watch(authStateProvider);
  final ds = ref.watch(dataServiceProvider);
  final results = await Future.wait([
    ds.loadProfile(),
    ds.loadAssumptions(),
    ds.listAccounts(),
    ds.listIncome(),
    ds.listExpenses(),
  ]);
  return PlanData(
    profile: results[0] as Profile,
    assumptions: results[1] as PlanAssumptions,
    accounts: results[2] as List<Account>,
    incomes: results[3] as List<IncomeSource>,
    expenses: results[4] as List<Expense>,
  );
});

/// Computes the projection from the loaded plan data.
final projectionProvider = Provider<ProjectionResult?>((ref) {
  final data = ref.watch(planDataProvider).valueOrNull;
  if (data == null) return null;
  final inputs = PlanInputs.from(
    profile: data.profile,
    assumptions: data.assumptions,
    accounts: data.accounts,
    incomes: data.incomes,
    expenses: data.expenses,
    now: DateTime.now(),
  );
  return RetirementProjection.project(inputs);
});
