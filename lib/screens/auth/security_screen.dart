import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../state/plan_controller.dart';
import '../../state/providers.dart';
import '../../widgets/access_code_card.dart';

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

  AuthCredentials? _viewCreds;
  bool _loadingCreds = true;

  @override
  void initState() {
    super.initState();
    _loadCreds();
  }

  Future<void> _loadCreds() async {
    final creds = await ref.read(authServiceProvider).cachedCredentials();
    if (mounted) {
      setState(() {
        _viewCreds = creds;
        _loadingCreds = false;
      });
    }
  }

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

  Future<void> _regenerate(bool hasPassword) async {
    String? pw;
    if (hasPassword) {
      pw = await _promptPassword();
      if (pw == null) return; // cancelled
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Generate a new access code?'),
            content: const Text(
                'Your old access code and QR will stop working. Make sure to save the new one.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final creds = await ref.read(authServiceProvider).regenerateAccessCode(password: pw);
      ref.invalidate(planControllerProvider);
      if (mounted) setState(() => _viewCreds = creds);
    } catch (_) {
      if (mounted) {
        setState(() {
          _ok = false;
          _msg = 'Could not generate a new code. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptPassword() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm your password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Continue')),
        ],
      ),
    );
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _accessCodeCard(hasPassword),
                const SizedBox(height: 16),
                _passwordCard(hasPassword),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _accessCodeCard(bool hasPassword) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your access code', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_loadingCreds)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            else if (_viewCreds != null) ...[
              AccessCodeCard(creds: _viewCreds!, warn: false),
              const SizedBox(height: 8),
              Text('Shown from this device. Save it somewhere safe.',
                  style: Theme.of(context).textTheme.bodySmall),
              TextButton(
                onPressed: _busy ? null : () => _regenerate(hasPassword),
                child: const Text('Replace with a new code'),
              ),
            ] else ...[
              const Text(
                  'Your original code is stored encrypted and cannot be shown again. '
                  'You can generate a new one to get a fresh QR — your old code will stop working.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : () => _regenerate(hasPassword),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Generate a new access code'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _passwordCard(bool hasPassword) {
    return Card(
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
    );
  }
}
