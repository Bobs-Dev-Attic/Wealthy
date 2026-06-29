import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../state/providers.dart';
import '../../widgets/app_scaffold.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});
  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Accepts either a raw access code or a full backup key (WLTH1|…|code).
  String _extractCode() {
    final decoded = AuthCredentials.decode(_code.text);
    return decoded?.accessCode ?? _code.text.trim();
  }

  Future<void> _setPassword() async {
    if (_password.text.length < 6) {
      setState(() {
        _ok = false;
        _msg = 'Password must be at least 6 characters.';
      });
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() {
        _ok = false;
        _msg = 'Passwords do not match.';
      });
      return;
    }
    await _run(() => ref
        .read(authServiceProvider)
        .setPassword(accessCode: _extractCode(), password: _password.text));
  }

  Future<void> _removePassword() async {
    await _run(() => ref.read(authServiceProvider).removePassword(accessCode: _extractCode()));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await action();
      ref.invalidate(planDataProvider);
      setState(() {
        _ok = true;
        _msg = 'Saved. Your login security settings were updated.';
        _password.clear();
        _confirm.clear();
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _msg = 'Could not update. Check that your access code is correct.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(planDataProvider);
    final hasPassword = data.valueOrNull?.profile.hasPassword ?? false;

    return AppScaffold(
      title: 'Security',
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: hasPassword ? 'Password is enabled' : 'Add a password',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hasPassword
                        ? 'Logging in requires your access code AND this password.'
                        : 'A password adds a second factor on top of your QR access code. '
                            'You will need both to log in.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _code,
                    decoration: const InputDecoration(
                      labelText: 'Your access code or backup key',
                      helperText: 'Required to confirm it is you',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New password'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm password'),
                  ),
                  const SizedBox(height: 16),
                  if (_msg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_msg!,
                          style: TextStyle(
                              color: _ok ? Colors.greenAccent : Colors.redAccent)),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : _setPassword,
                    child: Text(hasPassword ? 'Change password' : 'Enable password'),
                  ),
                  if (hasPassword)
                    TextButton(
                      onPressed: _busy ? null : _removePassword,
                      child: const Text('Remove password'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
