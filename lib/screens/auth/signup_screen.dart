import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/auth_service.dart';
import '../../state/providers.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  bool _loading = false;
  String? _error;
  AuthCredentials? _creds;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final creds = await ref.read(authServiceProvider).signUp(
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
          );
      setState(() => _creds = creds);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
            child: _creds == null ? _createView() : _qrView(_creds!),
          ),
        ),
      ),
    );
  }

  Widget _createView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Logo(),
        const SizedBox(height: 8),
        Text('Create your account',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'No email needed. We generate a private access code shown as a QR. '
          'Save it — it is your key to log back in.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Your name (optional)'),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        FilledButton(
          onPressed: _loading ? null : _create,
          child: _loading
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Generate my access code'),
        ),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('I already have a code'),
        ),
      ],
    );
  }

  Widget _qrView(AuthCredentials creds) {
    final key = creds.encode();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Save your access code',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: QrImageView(data: key, size: 220),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Access code', textAlign: TextAlign.center),
        SelectableText(
          creds.accessCode,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: key));
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Backup login key copied')));
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy backup login key'),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '⚠️ This code cannot be recovered. Screenshot the QR or copy the '
            'backup key and keep it somewhere safe. You can add a password next.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Continue to my dashboard'),
        ),
        TextButton(
          onPressed: () => context.go('/security'),
          child: const Text('Add a password for extra security'),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.savings_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        const Text('Wealthy',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }
}
