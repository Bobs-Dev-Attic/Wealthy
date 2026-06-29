import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initError;
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    ).timeout(const Duration(seconds: 15));
  } catch (e) {
    // Never let a backend hiccup leave the app stuck on the loading screen —
    // paint a frame either way so the user sees an actionable message.
    initError = e;
  }
  runApp(ProviderScope(child: WealthyApp(initError: initError)));
}
