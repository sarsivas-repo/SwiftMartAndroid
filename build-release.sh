#!/usr/bin/env bash
set -euo pipefail

: "${SWIFTMART_KEYSTORE:?Set SWIFTMART_KEYSTORE to the release keystore path}"
: "${SWIFTMART_KEY_PASSWORD_FILE:?Set SWIFTMART_KEY_PASSWORD_FILE to the password file path}"
test -r "$SWIFTMART_KEYSTORE"
test -r "$SWIFTMART_KEY_PASSWORD_FILE"
cd "$(dirname "$0")"
if [[ -f ../SwiftMart-Backend/licensing/public-key.txt ]]; then
  cmp ../SwiftMart-Backend/licensing/public-key.txt assets/license-public-key.txt
fi
flutter test
version=$(sed -nE 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+$/\1/p' pubspec.yaml)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid pubspec release version" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
flutter build apk --release --dart-define=SWIFTMART_LICENSED=true --dart-define="SWIFTMART_VERSION=$version"
install -m 0644 build/app/outputs/flutter-apk/app-release.apk "$work/SwiftMart-$version-android.apk"
mkdir -p release
for previous in release/SwiftMart-*.apk; do
  [[ -f "$previous" ]] && rm -- "$previous"
done
install -m 0644 "$work/SwiftMart-$version-android.apk" release/
{
  printf 'SwiftMart %s\nPublisher: Saravanakumar\n' "$version"
  printf 'Website: https://github.com/sarsivas-repo/SwiftMartAndroid\n'
  printf 'Licensing: initial installation license; reusable signed duration extensions. Updates preserve the license expiry.\n'
  printf 'Source commit: %s\n' "$(git rev-parse HEAD)"
  printf 'Built at: %s\n' "$(date -u +%FT%TZ)"
} > release/BUILD-INFO.txt
(cd release && sha256sum "SwiftMart-$version-android.apk" > SHA256SUMS)
echo "Licensed APK: release/SwiftMart-$version-android.apk"
