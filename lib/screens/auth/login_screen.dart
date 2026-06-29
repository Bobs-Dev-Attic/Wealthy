import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/auth_service.dart';
import '../../state/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _key = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _needPassword = false;
  bool _scanning = false;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _attempt() async {
    final creds = AuthCredentials.decode(_key.text);
    if (creds == null) {
      setState(() => _error = 'That does not look like a valid Wealthy login key or QR code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).login(
            userId: creds.userId,
            accessCode: creds.accessCode,
            password: _needPassword ? _password.text : null,
          );
      if (mounted) context.go('/');
    } on NeedsPasswordException {
      setState(() => _needPassword = true);
    } catch (e) {
      setState(() => _error = _needPassword
          ? 'Incorrect password for this access code.'
          : 'Could not log in. Check your code and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScan(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && AuthCredentials.decode(raw) != null) {
        _key.text = raw;
        setState(() => _scanning = false);
        _attempt();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.savings_outlined,
                    size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text('Welcome back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Scan your QR code or paste your backup login key.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                if (_scanning)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 260,
                      child: MobileScanner(onDetect: _onScan),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _scanning = true),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR code'),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _key,
                  decoration: const InputDecoration(
                    labelText: 'Backup login key',
                    hintText: 'WLTH1|…',
                  ),
                ),
                if (_needPassword) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _attempt(),
                  ),
                ],
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                FilledButton(
                  onPressed: _loading ? null : _attempt,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Log in'),
                ),
                TextButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text('Create a new account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
