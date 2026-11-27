# SwiftMart Android

This project adapts the Flutter application from `SwiftMart-Frontend` for Android.
It is a work in progress, not a production release: standalone sales,
customers and reports are not yet implemented.

The signed [preview APK](release/SwiftMart-android-preview.apk) is for testing
only. Verify it against [SHA256SUMS](release/SHA256SUMS). It has not been
validated on a physical Android device.

The current server-mode prototype asks for a SwiftMart server address before
login. Use HTTPS whenever possible. HTTP requires explicit confirmation because
passwords and business data are transmitted without encryption. A server bound
to `127.0.0.1` on a different device is not reachable by the phone; configure
secure network access on the server first.

The standalone test preview stores accounts in an app-private SQLite database,
separate from server data. Create a local admin at first launch. That admin can
create, edit, deactivate and delete admin, manager and cashier users, and reset
their passwords. Users can sign in and change their password; authorization for
user management is checked against the local account. There is one role per
user, matching the backend. Passwords are salted and hashed; no default test
password is bundled. Removing the app removes its local data.

The test preview currently covers **accounts, roles and stock**. It does not
synchronize data, and no sales, customer, salary or reporting workflows
are available in standalone mode. Connected mode still uses the server.

Build the prototype with Flutter:

```sh
flutter pub get
flutter test
flutter build apk --debug
```

The Android receipt action uses the system print dialog. No release signing
credentials are stored in this repository. To rebuild the signed preview, set
`SWIFTMART_KEYSTORE` and `SWIFTMART_KEY_PASSWORD_FILE` to the external keystore
and password file, and optionally `SWIFTMART_KEY_ALIAS` (default: `swiftmart`):

```sh
bash build-release.sh
```

Keep the keystore and password backed up securely: Android upgrades require the
same signing key. Never commit either file.