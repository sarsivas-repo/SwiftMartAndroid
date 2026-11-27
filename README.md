# SwiftMart Android

This project adapts the Flutter application from `SwiftMart-Frontend` for Android.
It is a work in progress, not a release: standalone test mode, release signing
and the release APK are not yet implemented.

The current server-mode prototype asks for a SwiftMart server address before
login. Use HTTPS whenever possible. HTTP requires explicit confirmation because
passwords and business data are transmitted without encryption. A server bound
to `127.0.0.1` on a different device is not reachable by the phone; configure
secure network access on the server first.

The backend currently supports the admin, manager and cashier roles, with one
role per user. Standalone mode must support creating and testing these roles
without sharing or synchronizing its data with the server.

Build the prototype with Flutter:

```sh
flutter pub get
flutter test test/server_settings_test.dart
flutter build apk --debug
```

The Android receipt action uses the system print dialog. No release signing
credentials are stored in this repository.