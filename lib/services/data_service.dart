import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account.dart';
import '../models/expense.dart';
import '../models/income_source.dart';
import '../models/plan_assumptions.dart';
import '../models/profile.dart';

/// CRUD over PostgREST. Every call is implicitly scoped to the signed-in user
/// by Row Level Security (`user_id = auth.uid()`).
class DataService {
  DataService(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  // --- Profile -------------------------------------------------------------
  Future<Profile> loadProfile() async {
    final row = await _client.from('profiles').select().eq('user_id', _uid).maybeSingle();
    if (row == null) return Profile(userId: _uid);
    return Profile.fromJson(row);
  }

  Future<void> saveProfile(Profile profile) =>
      _client.from('profiles').update(profile.toUpdate()).eq('user_id', _uid);

  // --- Plan assumptions ----------------------------------------------------
  Future<PlanAssumptions> loadAssumptions() async {
    final row = await _client.from('plan_assumptions').select().eq('user_id', _uid).maybeSingle();
    if (row == null) return PlanAssumptions(userId: _uid);
    return PlanAssumptions.fromJson(row);
  }

  Future<void> saveAssumptions(PlanAssumptions a) =>
      _client.from('plan_assumptions').update(a.toUpdate()).eq('user_id', _uid);

  // --- Accounts ------------------------------------------------------------
  Future<List<Account>> listAccounts() async {
    final rows = await _client.from('accounts').select().eq('user_id', _uid).order('created_at');
    return (rows as List).map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> upsertAccount(Account a) async {
    if (a.id == null) {
      await _client.from('accounts').insert(a.toInsert(_uid));
    } else {
      await _client.from('accounts').update(a.toInsert(_uid)).eq('id', a.id!);
    }
  }

  Future<void> deleteAccount(String id) => _client.from('accounts').delete().eq('id', id);

  // --- Income sources ------------------------------------------------------
  Future<List<IncomeSource>> listIncome() async {
    final rows =
        await _client.from('income_sources').select().eq('user_id', _uid).order('created_at');
    return (rows as List).map((e) => IncomeSource.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> upsertIncome(IncomeSource i) async {
    if (i.id == null) {
      await _client.from('income_sources').insert(i.toInsert(_uid));
    } else {
      await _client.from('income_sources').update(i.toInsert(_uid)).eq('id', i.id!);
    }
  }

  Future<void> deleteIncome(String id) => _client.from('income_sources').delete().eq('id', id);

  // --- Expenses ------------------------------------------------------------
  Future<List<Expense>> listExpenses() async {
    final rows = await _client.from('expenses').select().eq('user_id', _uid).order('created_at');
    return (rows as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> upsertExpense(Expense e) async {
    if (e.id == null) {
      await _client.from('expenses').insert(e.toInsert(_uid));
    } else {
      await _client.from('expenses').update(e.toInsert(_uid)).eq('id', e.id!);
    }
  }

  Future<void> deleteExpense(String id) => _client.from('expenses').delete().eq('id', id);
}
