#!/usr/bin/env bash
# Vercel build script for the Wealthy Flutter web app.
# Kept as a script because vercel.json's buildCommand is capped at 256 chars.
set -euo pipefail

if [ ! -d flutter ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi
export PATH="$PWD/flutter/bin:$PATH"

flutter config --enable-web
flutter pub get
# --no-web-resources-cdn bundles CanvasKit locally instead of fetching it from
# gstatic.com at runtime, which avoids an indefinite "Loading…" on networks that
# block or throttle the CDN.
flutter build web --release --no-web-resources-cdn \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
