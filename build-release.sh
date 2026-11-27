#!/usr/bin/env bash
set -euo pipefail

: "${SWIFTMART_KEYSTORE:?Set SWIFTMART_KEYSTORE to the release keystore path}"
: "${SWIFTMART_KEY_PASSWORD_FILE:?Set SWIFTMART_KEY_PASSWORD_FILE to the password file path}"
test -r "$SWIFTMART_KEYSTORE"
test -r "$SWIFTMART_KEY_PASSWORD_FILE"
cd "$(dirname "$0")"
flutter test
flutter build apk --release
mkdir -p release
install -m 0644 build/app/outputs/flutter-apk/app-release.apk release/SwiftMart-android-preview.apk
(cd release && sha256sum SwiftMart-android-preview.apk > SHA256SUMS)
echo "Preview APK: release/SwiftMart-android-preview.apk"
