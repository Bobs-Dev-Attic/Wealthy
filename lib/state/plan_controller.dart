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

/// Background-save status surfaced to the UI as a small indicator.
enum SaveStatus { idle, saving, saved }

class SaveStatusNotifier extends StateNotifier<SaveStatus> {
  SaveStatusNotifier() : super(SaveStatus.idle);
  int _pending = 0;
  Timer? _idle;

  void begin() {
    _pending++;
    _idle?.cancel();
    state = SaveStatus.saving;
  }

  void end() {
    if (_pending > 0) _pending--;
    if (_pending == 0) {
      state = SaveStatus.saved;
      _idle?.cancel();
      _idle = Timer(const Duration(milliseconds: 1800), () {
        if (_pending == 0 && mounted) state = SaveStatus.idle;
      });
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }
}

final saveStatusProvider =
    StateNotifierProvider<SaveStatusNotifier, SaveStatus>((_) => SaveStatusNotifier());

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
  PlanController(this._ds, String uid, this._save) : super(PlanState.initial(uid)) {
    _load();
  }

  final DataService _ds;
  final SaveStatusNotifier _save;
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

  /// Runs a persistence future while tracking the save indicator.
  Future<void> _trackVoid(Future<void> Function() fn) async {
    _save.begin();
    try {
      await fn();
    } catch (_) {
    } finally {
      _save.end();
    }
  }

  Future<String?> _trackInsert(Future<String> Function() fn) async {
    _save.begin();
    try {
      return await fn();
    } catch (_) {
      return null;
    } finally {
      _save.end();
    }
  }

  void _debounce(String key, Future<void> Function() action, {int ms = 900}) {
    _timers[key]?.cancel();
    _timers[key] = Timer(Duration(milliseconds: ms), () => _trackVoid(action));
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
    final id = await _trackInsert(() => _ds.insertAccount(a));
    state = state.copyWith(accounts: [...state.accounts, id != null ? a.copyWith(id: id) : a]);
  }

  /// Adds a fully-formed account immediately (optimistic), then patches its id
  /// once persisted. Used by the guided interview.
  Future<void> createAccount(Account a) async {
    state = state.copyWith(accounts: [...state.accounts, a]);
    final id = await _trackInsert(() => _ds.insertAccount(a));
    if (id != null) {
      state = state.copyWith(
          accounts: [for (final x in state.accounts) identical(x, a) ? x.copyWith(id: id) : x]);
    }
  }

  void updateAccount(Account a) {
    state = state.copyWith(accounts: [for (final x in state.accounts) x.id == a.id ? a : x]);
    if (a.id != null) _debounce('acc:${a.id}', () => _ds.updateAccount(a));
  }

  Future<void> removeAccount(Account a) async {
    state = state.copyWith(accounts: state.accounts.where((x) => x.id != a.id).toList());
    if (a.id != null) await _trackVoid(() => _ds.deleteAccount(a.id!));
  }

  // --- Income --------------------------------------------------------------
  Future<void> addIncome() async {
    const i = IncomeSource(name: 'Social Security', type: IncomeType.socialSecurity, annualAmount: 0);
    final id = await _trackInsert(() => _ds.insertIncome(i));
    state = state.copyWith(incomes: [...state.incomes, id != null ? i.copyWith(id: id) : i]);
  }

  Future<void> createIncome(IncomeSource i) async {
    state = state.copyWith(incomes: [...state.incomes, i]);
    final id = await _trackInsert(() => _ds.insertIncome(i));
    if (id != null) {
      state = state.copyWith(
          incomes: [for (final x in state.incomes) identical(x, i) ? x.copyWith(id: id) : x]);
    }
  }

  void updateIncome(IncomeSource i) {
    state = state.copyWith(incomes: [for (final x in state.incomes) x.id == i.id ? i : x]);
    if (i.id != null) _debounce('inc:${i.id}', () => _ds.updateIncome(i));
  }

  Future<void> removeIncome(IncomeSource i) async {
    state = state.copyWith(incomes: state.incomes.where((x) => x.id != i.id).toList());
    if (i.id != null) await _trackVoid(() => _ds.deleteIncome(i.id!));
  }

  // --- Expenses ------------------------------------------------------------
  Future<void> addExpense() async {
    const e = Expense(name: 'New expense', category: ExpenseCategory.living, annualAmount: 0);
    final id = await _trackInsert(() => _ds.insertExpense(e));
    state = state.copyWith(expenses: [...state.expenses, id != null ? e.copyWith(id: id) : e]);
  }

  Future<void> createExpense(Expense e) async {
    state = state.copyWith(expenses: [...state.expenses, e]);
    final id = await _trackInsert(() => _ds.insertExpense(e));
    if (id != null) {
      state = state.copyWith(
          expenses: [for (final x in state.expenses) identical(x, e) ? x.copyWith(id: id) : x]);
    }
  }

  void updateExpense(Expense e) {
    state = state.copyWith(expenses: [for (final x in state.expenses) x.id == e.id ? e : x]);
    if (e.id != null) _debounce('exp:${e.id}', () => _ds.updateExpense(e));
  }

  Future<void> removeExpense(Expense e) async {
    state = state.copyWith(expenses: state.expenses.where((x) => x.id != e.id).toList());
    if (e.id != null) await _trackVoid(() => _ds.deleteExpense(e.id!));
  }

  // --- Liabilities ---------------------------------------------------------
  Future<void> addLiability() async {
    const l = Liability(name: 'New debt', type: LiabilityType.mortgage, balance: 0);
    final id = await _trackInsert(() => _ds.insertLiability(l));
    state = state.copyWith(liabilities: [...state.liabilities, id != null ? l.copyWith(id: id) : l]);
  }

  Future<void> createLiability(Liability l) async {
    state = state.copyWith(liabilities: [...state.liabilities, l]);
    final id = await _trackInsert(() => _ds.insertLiability(l));
    if (id != null) {
      state = state.copyWith(
          liabilities: [for (final x in state.liabilities) identical(x, l) ? x.copyWith(id: id) : x]);
    }
  }

  void updateLiability(Liability l) {
    state =
        state.copyWith(liabilities: [for (final x in state.liabilities) x.id == l.id ? l : x]);
    if (l.id != null) _debounce('lia:${l.id}', () => _ds.updateLiability(l));
  }

  Future<void> removeLiability(Liability l) async {
    state = state.copyWith(liabilities: state.liabilities.where((x) => x.id != l.id).toList());
    if (l.id != null) await _trackVoid(() => _ds.deleteLiability(l.id!));
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
  final save = ref.watch(saveStatusProvider.notifier);
  return PlanController(ds, uid, save);
});
