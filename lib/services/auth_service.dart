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
    await _client.auth.signInWithPassword(
      email: _emailFor(creds.userId),
      password: creds.accessCode,
    );
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

  Future<void> signOut() => _client.auth.signOut();
}
