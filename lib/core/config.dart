/// Compile-time configuration.
///
/// Values can be overridden at build time with `--dart-define`, e.g.:
///   flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// The defaults point at the provisioned `Wealthy` Supabase project. The anon
/// key is a publishable client key (safe to ship); all data access is still
/// gated by Row Level Security tied to the authenticated user.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bdnvnyqvikcaujhjqemr.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJkbnZueXF2aWtjYXVqaGpxZW1yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI2NzgzNDMsImV4cCI6MjA5ODI1NDM0M30.6eZMETWsZ-SH77-YY8DBOzkcwlKBYj9bIuC8rz9qbww',
  );

  /// Domain used to synthesize per-user login emails (`<userId>@<domain>`).
  static const String authEmailDomain = 'wealthy.local';

  /// Separator joining the access code and an optional user password into the
  /// composite auth password: `<accessCode>:<password>`.
  static const String passwordSeparator = ':';
}
