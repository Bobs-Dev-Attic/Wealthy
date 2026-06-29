import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account.dart';
import '../models/expense.dart';
import '../models/income_source.dart';
import '../models/liability.dart';
import '../models/plan_assumptions.dart';
import '../models/profile.dart';

/// CRUD over PostgREST. Every call is implicitly scoped to the signed-in user
/// by Row Level Security (`user_id = auth.uid()`). Insert helpers return the new
/// row id so the reactive controller can keep editing it without a reload.
class DataService {
  DataService(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  // --- Profile -------------------------------------------------------------
  Future<Profile> loadProfile() async {
    final row = await _client.from('profiles').select().eq('user_id', _uid).maybeSingle();
    return row == null ? Profile(userId: _uid) : Profile.fromJson(row);
  }

  Future<void> saveProfile(Profile profile) =>
      _client.from('profiles').update(profile.toUpdate()).eq('user_id', _uid);

  // --- Plan assumptions ----------------------------------------------------
  Future<PlanAssumptions> loadAssumptions() async {
    final row = await _client.from('plan_assumptions').select().eq('user_id', _uid).maybeSingle();
    return row == null ? PlanAssumptions(userId: _uid) : PlanAssumptions.fromJson(row);
  }

  Future<void> saveAssumptions(PlanAssumptions a) =>
      _client.from('plan_assumptions').update(a.toUpdate()).eq('user_id', _uid);

  // --- Accounts ------------------------------------------------------------
  Future<List<Account>> listAccounts() async {
    final rows = await _client.from('accounts').select().eq('user_id', _uid).order('created_at');
    return (rows as List).map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> insertAccount(Account a) async {
    final row = await _client.from('accounts').insert(a.toInsert(_uid)).select('id').single();
    return row['id'] as String;
  }

  Future<void> updateAccount(Account a) =>
      _client.from('accounts').update(a.toInsert(_uid)).eq('id', a.id!);

  Future<void> deleteAccount(String id) => _client.from('accounts').delete().eq('id', id);

  // --- Income sources ------------------------------------------------------
  Future<List<IncomeSource>> listIncome() async {
    final rows =
        await _client.from('income_sources').select().eq('user_id', _uid).order('created_at');
    return (rows as List).map((e) => IncomeSource.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> insertIncome(IncomeSource i) async {
    final row = await _client.from('income_sources').insert(i.toInsert(_uid)).select('id').single();
    return row['id'] as String;
  }

  Future<void> updateIncome(IncomeSource i) =>
      _client.from('income_sources').update(i.toInsert(_uid)).eq('id', i.id!);

  Future<void> deleteIncome(String id) => _client.from('income_sources').delete().eq('id', id);

  // --- Expenses ------------------------------------------------------------
  Future<List<Expense>> listExpenses() async {
    final rows = await _client.from('expenses').select().eq('user_id', _uid).order('created_at');
    return (rows as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> insertExpense(Expense e) async {
    final row = await _client.from('expenses').insert(e.toInsert(_uid)).select('id').single();
    return row['id'] as String;
  }

  Future<void> updateExpense(Expense e) =>
      _client.from('expenses').update(e.toInsert(_uid)).eq('id', e.id!);

  Future<void> deleteExpense(String id) => _client.from('expenses').delete().eq('id', id);

  // --- Liabilities ---------------------------------------------------------
  Future<List<Liability>> listLiabilities() async {
    try {
      final rows =
          await _client.from('liabilities').select().eq('user_id', _uid).order('created_at');
      return (rows as List).map((e) => Liability.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const []; // table may not exist yet in older environments
    }
  }

  Future<String> insertLiability(Liability l) async {
    final row = await _client.from('liabilities').insert(l.toInsert(_uid)).select('id').single();
    return row['id'] as String;
  }

  Future<void> updateLiability(Liability l) =>
      _client.from('liabilities').update(l.toInsert(_uid)).eq('id', l.id!);

  Future<void> deleteLiability(String id) => _client.from('liabilities').delete().eq('id', id);
}
