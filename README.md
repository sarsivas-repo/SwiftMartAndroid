# SwiftMart Android

This project adapts the Flutter application from `SwiftMart-Frontend` for Android.
It is a work in progress, not a release: standalone sales, inventory, customers,
reports and release signing are not yet implemented, and there is no release APK.

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

The test preview currently covers **accounts and roles only**. It does not
synchronize data, and no sales, stock, customer, salary or reporting workflows
are available in standalone mode. Connected mode still uses the server.

Build the prototype with Flutter:

```sh
flutter pub get
flutter test
flutter build apk --debug
```

The Android receipt action uses the system print dialog. No release signing
credentials are stored in this repository.