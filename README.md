# SwiftMart Android

This project adapts the Flutter application from `SwiftMart-Frontend` for Android.
It is a work in progress, not a production release: standalone salary and
reports are not yet implemented.

Each release provides one signed [APK](release/SwiftMart-1.0.10-android.apk). Publisher:
**Saravanakumar**. Verify them against [SHA256SUMS](release/SHA256SUMS); publishing
details are in [BUILD-INFO.txt](release/BUILD-INFO.txt). They have not been
validated on a physical Android device.

## Renewable licenses

The initial license starts on first app launch and applies to
offline/standalone, server and customer modes. Updates/reinstalls without clearing
data preserve the original expiry; new versions do not restart the license.
At expiry, login and application screens are blocked; existing standalone
sessions and API operations are checked too. The screen refreshes every 30
seconds and when returning to the app. Clock rollback beyond five minutes and
invalid/unwritable state block access. Stored business data is retained.

Open **License settings** in the top banner to see the exact UTC expiry and
remaining days, and paste a paid extension code from Saravanakumar. The activation
form remains available after expiry without login. Paid codes have fixed UTC
expiries, use Ed25519 signatures, and are reusable across Windows/Linux/Android
devices. Reapplying a code does not add more days. Publisher scripts in
`SwiftMart-Infra/native/LICENSING.md` generate days/calendar-year extensions.

Updates keep the existing application ID and release signing key, preserving
standalone accounts, stock and bills. **Do not uninstall or clear app data
when upgrading**. Android rejects downgrades to older version codes. This is
offline license enforcement, not tamper-proof licensing: clearing application
data, uninstalling or modifying/rebuilding the app can reset/bypass local license
state. Strong enforcement requires online activation and controlled distribution.
A licensed client still cannot use an expired backend; activate there too.
Android signing confirms package identity, not Windows-style
public publisher verification.

The current server-mode prototype asks for a SwiftMart server address before
login. Use HTTPS whenever possible. HTTP requires explicit confirmation because
passwords and business data are transmitted without encryption. A server bound
to `127.0.0.1` on a different device is not reachable by the phone; configure
secure network access on the server first.

Connected mode supports server-configured UPI QR checkout and payment history;
an administrator selects the provider in Settings. Google Pay is a customer's UPI
app, not a separate provider. Android standalone does not support provider
checkout. Configure and reconcile payments on the server as described in
`SwiftMart-Infra/native/PAYMENTS.md`. Live provider transactions have not been
tested with this release.

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

Sales can include **Sell without stock** items without changing inventory in
either mode; connected mode requires a tax-aware backend. In Stock, open a
product and select **Sales tax settings** for no tax recorded, tax included in
the entered price, or tax added separately. An optional MRP sets a maximum
final price. Direct-sale items have the same choices. Existing bill lines keep
their original pricing, and older drafts retain their original calculation.
In Stock, open a product and select
**Record purchase** to save supplier cost, quantity and purchase tax treatment.
The stock increase and purchase record are saved together. On an uncertain
result, retry unchanged in the same dialog or check before starting again.
The receipt can be shared through installed apps, including WhatsApp, SMS or
email, without printing. Connected mode can also send using configured SMS and
email providers. Sharing opens a chooser and does not confirm delivery; check
uncertain provider outcomes before retrying.

## Customer catalog and order requests

The shop must enable the backend's opt-in customer catalog and tell customers
the server address and WhatsApp contact. See the backend README for its
configuration and network/security requirements. Native installers before
version 1.0.3 and older backend releases do not include this endpoint. An Android
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
credentials are stored in this repository. To rebuild the signed licensed APK, set
`SWIFTMART_KEYSTORE` and `SWIFTMART_KEY_PASSWORD_FILE` to the external keystore
and password file, and optionally `SWIFTMART_KEY_ALIAS` (default: `swiftmart`):

```sh
bash build-release.sh
```

The script tests once and builds with `SWIFTMART_LICENSED=true` and the release
version from `pubspec.yaml`. It embeds only the publisher's verification key
from `assets/license-public-key.txt`, never its private signing key. Increment
both `version` and Android build number for a new release. Publish only the
latest APK, checksums and publishing information; older builds stay in Git
history. Keep the same APK signing key and application ID.
For manual licensed builds, pass `--dart-define=SWIFTMART_LICENSED=true` and
`--dart-define=SWIFTMART_VERSION=1.0.10` (matching `--build-name`).
Normal debug/source builds retain unrestricted development behavior.

Keep the keystore and password backed up securely: Android upgrades require the
same signing key. Never commit either file.