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
#   gstatic.com at runtime (avoids an indefinite "Loading…" if the CDN is blocked).
# --pwa-strategy=none disables the Flutter service worker, which otherwise caches
#   the app shell and can keep serving a stale/broken build after a redeploy.
flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

# Stamp the loading page with a build id so we can confirm which build is live.
BUILD_ID="${VERCEL_GIT_COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
BUILD_ID="${BUILD_ID:0:7} $(date -u +%Y-%m-%dT%H:%MZ)"
sed -i "s|__BUILD_ID__|${BUILD_ID}|g" build/web/index.html
