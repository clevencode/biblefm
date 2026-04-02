#!/usr/bin/env bash
# Build Flutter Web no Vercel (Linux). Output: build/web
set -euo pipefail

FLUTTER_DIR="${VERCEL_FLUTTER_HOME:-$HOME/flutter}"

if [[ -x "${FLUTTER_DIR}/bin/flutter" ]]; then
  echo "Using existing Flutter at ${FLUTTER_DIR}"
else
  echo "Cloning Flutter SDK (stable, shallow)..."
  rm -rf "${FLUTTER_DIR}"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
export FLUTTER_SUPPRESS_ANALYTICS=true
export PUB_CACHE="${PUB_CACHE:-${HOME}/.pub-cache}"

flutter config --no-analytics --enable-web
flutter precache --web
flutter pub get
flutter build web --release --no-web-resources-cdn

echo "Build web OK → build/web"
