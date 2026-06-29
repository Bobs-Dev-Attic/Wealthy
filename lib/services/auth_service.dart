import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';

/// Credentials carried by the login QR code.
class AuthCredentials {
  final String userId;
  final String accessCode;
  const AuthCredentials({required this.userId, required this.accessCode});

  /// Compact payload encoded into the QR code.
  String encode() => 'WLTH1|$userId|$accessCode';

  static AuthCredentials? decode(String raw) {
    final s = raw.trim();
    final parts = s.split('|');
    if (parts.length == 3 && parts[0] == 'WLTH1') {
      return AuthCredentials(userId: parts[1], accessCode: parts[2]);
    }
    return null;
  }
}

/// Thin error wrapper so the UI can distinguish "needs password" from "invalid".
class NeedsPasswordException implements Exception {}

class AuthService {
  AuthService(this._client);
  final SupabaseClient _client;

  Session? get session => _client.auth.currentSession;
  User? get user => _client.auth.currentUser;
  bool get isLoggedIn => session != null;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  String _emailFor(String userId) => '$userId@${AppConfig.authEmailDomain}';

  /// Creates a new account via the signup edge function, then signs in.
  /// Returns the credentials so the UI can render the QR code (shown once).
  Future<AuthCredentials> signUp({String? name}) async {
    final res = await _client.functions.invoke('signup', body: {'name': name});
    final data = res.data as Map?;
    if (data == null || data['userId'] == null || data['accessCode'] == null) {
      throw Exception(data?['error']?.toString() ?? 'Signup failed');
    }
    final creds = AuthCredentials(
      userId: data['userId'] as String,
      accessCode: data['accessCode'] as String,
    );
    // Intentionally do NOT sign in here. Signing in fires an auth-state change
    // that would redirect away from the signup screen before the user can save
    // their QR code. The screen signs in explicitly when the user continues.
    await _cache(creds);
    return creds;
  }

  /// Logs in with an access code. If the account has a password attached, the
  /// plain code fails — pass [password] to retry, or catch [NeedsPasswordException].
  Future<void> login({
    required String userId,
    required String accessCode,
    String? password,
  }) async {
    final email = _emailFor(userId);
    if (password == null || password.isEmpty) {
      try {
        await _client.auth.signInWithPassword(email: email, password: accessCode);
        await _cache(AuthCredentials(userId: userId, accessCode: accessCode));
        return;
      } on AuthException {
        // Could be wrong code OR a password is required. Signal the UI to ask.
        throw NeedsPasswordException();
      }
    }
    await _client.auth.signInWithPassword(
      email: email,
      password: '$accessCode${AppConfig.passwordSeparator}$password',
    );
    await _cache(AuthCredentials(userId: userId, accessCode: accessCode));
  }

  /// Attaches (or changes) a password second factor. Requires the original
  /// access code, which the UI holds from the current session's login.
  Future<void> setPassword({required String accessCode, required String password}) async {
    await _client.auth.updateUser(
      UserAttributes(password: '$accessCode${AppConfig.passwordSeparator}$password'),
    );
    final uid = user?.id;
    if (uid != null) {
      await _client.from('profiles').update({'has_password': true}).eq('user_id', uid);
    }
  }

  /// Removes the password second factor, reverting to access-code-only login.
  Future<void> removePassword({required String accessCode}) async {
    await _client.auth.updateUser(UserAttributes(password: accessCode));
    final uid = user?.id;
    if (uid != null) {
      await _client.from('profiles').update({'has_password': false}).eq('user_id', uid);
    }
  }

  Future<void> signOut() async {
    await _clearCache();
    await _client.auth.signOut();
  }

  // --- Access-code re-view / recovery -------------------------------------
  // The access code is the user's password and is only stored hashed on the
  // server, so it cannot be fetched back. We cache it locally on the device
  // where the user signed up / logged in, so the QR can be shown again.
  static const _kUser = 'wealthy_uid';
  static const _kCode = 'wealthy_code';
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<void> _cache(AuthCredentials c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUser, c.userId);
    await p.setString(_kCode, c.accessCode);
  }

  Future<void> _clearCache() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUser);
    await p.remove(_kCode);
  }

  /// The locally-cached credentials, if they belong to the current user.
  Future<AuthCredentials?> cachedCredentials() async {
    final p = await SharedPreferences.getInstance();
    final uid = p.getString(_kUser);
    final code = p.getString(_kCode);
    if (uid == null || code == null) return null;
    if (user != null && user!.id != uid) return null;
    return AuthCredentials(userId: uid, accessCode: code);
  }

  /// Generates a fresh access code for the signed-in user (recovery when the
  /// original was not saved). If [password] is given it is kept as the second
  /// factor; otherwise login becomes access-code-only.
  Future<AuthCredentials> regenerateAccessCode({String? password}) async {
    final uid = user?.id;
    if (uid == null) throw Exception('Not signed in');
    final newCode = generateAccessCode();
    final hasPw = password != null && password.isNotEmpty;
    final composite = hasPw ? '$newCode${AppConfig.passwordSeparator}$password' : newCode;
    await _client.auth.updateUser(UserAttributes(password: composite));
    await _client.from('profiles').update({'has_password': hasPw}).eq('user_id', uid);
    final creds = AuthCredentials(userId: uid, accessCode: newCode);
    await _cache(creds);
    return creds;
  }

  /// Crockford-ish base32 access code, grouped (e.g. ABCD-EFGH-JKLM-NPQR).
  String generateAccessCode({int groups = 4, int len = 4}) {
    final r = Random.secure();
    return List.generate(
      groups,
      (_) => List.generate(len, (_) => _alphabet[r.nextInt(_alphabet.length)]).join(),
    ).join('-');
  }
}
