# SwiftMart Android

This project adapts the Flutter application from `SwiftMart-Frontend` for Android.
It is a work in progress, not a production release: standalone salary and
reports are not yet implemented.

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

The test preview covers **accounts, roles, stock, customers and sales**. It does
not synchronize data; salary and reporting workflows are not available in
standalone mode. Connected mode still uses the server.

## Customer catalog and order requests

The shop must enable the backend's opt-in customer catalog and tell customers
the server address and WhatsApp contact. See the backend README for its
configuration and network/security requirements. The existing native
installers and older backend releases do not include this endpoint. An Android
standalone shop cannot publish its local catalog through this feature.

On the customer phone, tap **Shop as a customer**, connect to the shop network
and enter the shop's server address once. A successful download saves the
catalog on the phone without a staff login. Reopening the customer view tries
to refresh it; if the shop server is unreachable, the previous catalog and
cart remain available offline. The customer may search, add items, enter a
name and delivery address, preview the message and choose WhatsApp and the
shop's contact in the Android share sheet. Sending requires internet access.
The name and address are included in the shared message but are not saved by
the customer screen. The shop must confirm receipt: opening the share sheet
does not prove an order was sent or accepted.

Prices and stock are snapshots, and tax and delivery charges may be extra.
The shop should confirm availability, delivery and the final amount before
sharing its own UPI QR or payment details with the customer. Customers should
verify the payee; sharing a QR or payment screenshot does not verify payment.
This feature does not create bills, reserve stock, generate payment QR codes,
or automatically confirm payment.

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