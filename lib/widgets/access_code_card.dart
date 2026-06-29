import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/auth_service.dart';

/// Displays an access code as a QR plus the human code and a copyable backup
/// key. Used on signup and re-shown from the Security page.
class AccessCodeCard extends StatelessWidget {
  const AccessCodeCard({super.key, required this.creds, this.warn = true});

  final AuthCredentials creds;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final key = creds.encode();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Center(child: QrImageView(data: key, size: 200)),
        ),
        const SizedBox(height: 14),
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
        if (warn) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '⚠️ Save this now. It is your key to log in and cannot be recovered '
              'from our servers. Screenshot the QR or copy the backup key.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}
