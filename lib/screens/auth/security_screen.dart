import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../state/plan_controller.dart';
import '../../state/providers.dart';

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

  Future<void> _removePassword() =>
      _run(() => ref.read(authServiceProvider).removePassword(accessCode: _extractCode()));

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await action();
      setState(() {
        _ok = true;
        _msg = 'Saved. Your login security was updated.';
        _password.clear();
        _confirm.clear();
      });
    } catch (_) {
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
    final hasPassword =
        ref.watch(planControllerProvider.select((s) => s.profile.hasPassword));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
        title: const Text('Security'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(hasPassword ? 'Password is enabled' : 'Add a password',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(hasPassword
                        ? 'Logging in requires your access code AND this password.'
                        : 'A password adds a second factor on top of your QR access code.'),
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
                            style: TextStyle(color: _ok ? Colors.greenAccent : Colors.redAccent)),
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _setPassword,
                      child: Text(hasPassword ? 'Change password' : 'Enable password'),
                    ),
                    if (hasPassword)
                      TextButton(
                          onPressed: _busy ? null : _removePassword,
                          child: const Text('Remove password')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
