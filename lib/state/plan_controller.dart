import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/income_source.dart';
import '../models/liability.dart';
import '../models/plan_assumptions.dart';
import '../models/profile.dart';
import '../services/data_service.dart';
import 'providers.dart';

/// The full set of planning inputs, held in memory and mutated synchronously so
/// the results update in real time. Persistence happens in the background.
@immutable
class PlanState {
  final bool loaded;
  final Profile profile;
  final PlanAssumptions assumptions;
  final List<Account> accounts;
  final List<IncomeSource> incomes;
  final List<Expense> expenses;
  final List<Liability> liabilities;

  const PlanState({
    required this.loaded,
    required this.profile,
    required this.assumptions,
    required this.accounts,
    required this.incomes,
    required this.expenses,
    required this.liabilities,
  });

  factory PlanState.initial(String uid) => PlanState(
        loaded: false,
        profile: Profile(userId: uid),
        assumptions: PlanAssumptions(userId: uid),
        accounts: const [],
        incomes: const [],
        expenses: const [],
        liabilities: const [],
      );

  double get totalAssets => accounts.fold(0.0, (s, a) => s + a.balance);
  double get totalLiabilities => liabilities.fold(0.0, (s, l) => s + l.balance);
  double get netWorth => totalAssets - totalLiabilities;
  double get annualIncome => incomes.fold(0.0, (s, i) => s + i.annualAmount);
  double get annualExpenses => expenses.fold(0.0, (s, e) => s + e.annualAmount);

  PlanState copyWith({
    bool? loaded,
    Profile? profile,
    PlanAssumptions? assumptions,
    List<Account>? accounts,
    List<IncomeSource>? incomes,
    List<Expense>? expenses,
    List<Liability>? liabilities,
  }) =>
      PlanState(
        loaded: loaded ?? this.loaded,
        profile: profile ?? this.profile,
        assumptions: assumptions ?? this.assumptions,
        accounts: accounts ?? this.accounts,
        incomes: incomes ?? this.incomes,
        expenses: expenses ?? this.expenses,
        liabilities: liabilities ?? this.liabilities,
      );
}

class PlanController extends StateNotifier<PlanState> {
  PlanController(this._ds, String uid) : super(PlanState.initial(uid)) {
    _load();
  }

  final DataService _ds;
  final Map<String, Timer> _timers = {};

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        _ds.loadProfile(),
        _ds.loadAssumptions(),
        _ds.listAccounts(),
        _ds.listIncome(),
        _ds.listExpenses(),
        _ds.listLiabilities(),
      ]);
      state = PlanState(
        loaded: true,
        profile: r[0] as Profile,
        assumptions: r[1] as PlanAssumptions,
        accounts: r[2] as List<Account>,
        incomes: r[3] as List<IncomeSource>,
        expenses: r[4] as List<Expense>,
        liabilities: r[5] as List<Liability>,
      );
    } catch (_) {
      state = state.copyWith(loaded: true);
    }
  }

  void _debounce(String key, Future<void> Function() action, {int ms = 900}) {
    _timers[key]?.cancel();
    _timers[key] = Timer(Duration(milliseconds: ms), () {
      action().catchError((_) {});
    });
  }

  // --- Profile / assumptions ----------------------------------------------
  void setProfile(Profile p) {
    state = state.copyWith(profile: p);
    _debounce('profile', () => _ds.saveProfile(state.profile));
  }

  /// Convenience: set current age by storing an approximate birth date.
  void setCurrentAge(int age, DateTime now) {
    final birth = DateTime(now.year - age, now.month, now.day);
    setProfile(state.profile.copyWith(birthDate: birth));
  }

  void setAssumptions(PlanAssumptions a) {
    state = state.copyWith(assumptions: a);
    _debounce('assumptions', () => _ds.saveAssumptions(state.assumptions));
  }

  // --- Accounts ------------------------------------------------------------
  Future<void> addAccount() async {
    const a = Account(name: 'New account', type: AccountType.taxable, balance: 0);
    try {
      final id = await _ds.insertAccount(a);
      state = state.copyWith(accounts: [...state.accounts, a.copyWith(id: id)]);
    } catch (_) {
      state = state.copyWith(accounts: [...state.accounts, a]);
    }
  }

  void updateAccount(Account a) {
    state = state.copyWith(accounts: [for (final x in state.accounts) x.id == a.id ? a : x]);
    if (a.id != null) _debounce('acc:${a.id}', () => _ds.updateAccount(a));
  }

  Future<void> removeAccount(Account a) async {
    state = state.copyWith(accounts: state.accounts.where((x) => x.id != a.id).toList());
    if (a.id != null) {
      try {
        await _ds.deleteAccount(a.id!);
      } catch (_) {}
    }
  }

  // --- Income --------------------------------------------------------------
  Future<void> addIncome() async {
    const i = IncomeSource(name: 'Social Security', type: IncomeType.socialSecurity, annualAmount: 0);
    try {
      final id = await _ds.insertIncome(i);
      state = state.copyWith(incomes: [...state.incomes, i.copyWith(id: id)]);
    } catch (_) {
      state = state.copyWith(incomes: [...state.incomes, i]);
    }
  }

  void updateIncome(IncomeSource i) {
    state = state.copyWith(incomes: [for (final x in state.incomes) x.id == i.id ? i : x]);
    if (i.id != null) _debounce('inc:${i.id}', () => _ds.updateIncome(i));
  }

  Future<void> removeIncome(IncomeSource i) async {
    state = state.copyWith(incomes: state.incomes.where((x) => x.id != i.id).toList());
    if (i.id != null) {
      try {
        await _ds.deleteIncome(i.id!);
      } catch (_) {}
    }
  }

  // --- Expenses ------------------------------------------------------------
  Future<void> addExpense() async {
    const e = Expense(name: 'New expense', category: ExpenseCategory.living, annualAmount: 0);
    try {
      final id = await _ds.insertExpense(e);
      state = state.copyWith(expenses: [...state.expenses, e.copyWith(id: id)]);
    } catch (_) {
      state = state.copyWith(expenses: [...state.expenses, e]);
    }
  }

  void updateExpense(Expense e) {
    state = state.copyWith(expenses: [for (final x in state.expenses) x.id == e.id ? e : x]);
    if (e.id != null) _debounce('exp:${e.id}', () => _ds.updateExpense(e));
  }

  Future<void> removeExpense(Expense e) async {
    state = state.copyWith(expenses: state.expenses.where((x) => x.id != e.id).toList());
    if (e.id != null) {
      try {
        await _ds.deleteExpense(e.id!);
      } catch (_) {}
    }
  }

  // --- Liabilities ---------------------------------------------------------
  Future<void> addLiability() async {
    const l = Liability(name: 'New debt', type: LiabilityType.mortgage, balance: 0);
    try {
      final id = await _ds.insertLiability(l);
      state = state.copyWith(liabilities: [...state.liabilities, l.copyWith(id: id)]);
    } catch (_) {
      state = state.copyWith(liabilities: [...state.liabilities, l]);
    }
  }

  void updateLiability(Liability l) {
    state =
        state.copyWith(liabilities: [for (final x in state.liabilities) x.id == l.id ? l : x]);
    if (l.id != null) _debounce('lia:${l.id}', () => _ds.updateLiability(l));
  }

  Future<void> removeLiability(Liability l) async {
    state = state.copyWith(liabilities: state.liabilities.where((x) => x.id != l.id).toList());
    if (l.id != null) {
      try {
        await _ds.deleteLiability(l.id!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }
}

final planControllerProvider = StateNotifierProvider<PlanController, PlanState>((ref) {
  final ds = ref.watch(dataServiceProvider);
  final uid = ref.watch(supabaseClientProvider).auth.currentUser?.id ?? '';
  return PlanController(ds, uid);
});
