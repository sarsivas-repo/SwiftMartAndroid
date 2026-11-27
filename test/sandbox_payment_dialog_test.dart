import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:swiftmart_frontend/models/sandbox_payment.dart';
import 'package:swiftmart_frontend/widgets/sandbox_payment_dialog.dart';

class _PaymentClient implements SandboxPaymentClient {
  List<String> available = ['phonepe'];
  SandboxPayment? existing;
  SandboxPayment? checked;
  SandboxPaymentException? checkError;
  SandboxPayment? recovered;
  SandboxPaymentException? recoveryError;
  String? recoveredId;
  String? recoveredReference;
  bool creationFails = false;
  int createCalls = 0;
  int checkCalls = 0;

  @override
  Future<List<String>> providers() async => available;

  @override
  Future<List<SandboxPayment>> list() async =>
      existing == null ? [] : [existing!];

  @override
  Future<SandboxPayment?> forDraft(String draftId) async => existing;

  @override
  Future<SandboxPayment> create({
    required String draftId,
    required String provider,
    required int taxPaise,
    required String customerPhone,
    required String os,
    required String browser,
  }) async {
    createCalls++;
    if (creationFails) throw Exception('timeout');
    existing = _payment('ready', qr: true);
    return existing!;
  }

  @override
  Future<SandboxPayment> check(String id) async {
    checkCalls++;
    if (checkError != null) throw checkError!;
    return checked!;
  }

  @override
  Future<SandboxPayment> recoverRazorpay(String id, String reference) async {
    recoveredId = id;
    recoveredReference = reference;
    if (recoveryError != null) throw recoveryError!;
    return recovered!;
  }
}

SandboxPayment _payment(String state, {bool qr = false, int? billId}) =>
    SandboxPayment(
      id: 'attempt1',
      provider: 'phonepe',
      state: state,
      amountPaise: 2200,
      draftId: 1,
      billId: billId,
      providerReference: 'attempt1',
      qrFormat: qr ? 'upi_uri' : null,
      qrValue: qr ? 'upi://pay?pa=merchant%40upi&tr=attempt1&am=22' : null,
    );

SandboxPayment _razorpay(String state, {String? reference, int? billId}) =>
    SandboxPayment(
      id: 'attempt1',
      provider: 'razorpay',
      state: state,
      amountPaise: 2200,
      draftId: 1,
      billId: billId,
      providerReference: reference,
    );

Widget _app(_PaymentClient client,
        Future<void> Function(SandboxPayment) onCompleted) =>
    MaterialApp(
      home: Scaffold(
        body: SandboxPaymentDialog(
          draftId: '1',
          taxPaise: 200,
          client: client,
          onCompleted: onCompleted,
        ),
      ),
    );

void main() {
  testWidgets(
      'Android checkout keeps provider selection and hides browser fields',
      (tester) async {
    final client = _PaymentClient()..available = ['cashfree'];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SandboxPaymentDialog(
          draftId: '1',
          taxPaise: 0,
          client: client,
          mode: 'live',
          mobile: true,
          preferredProvider: 'cashfree',
          onCompleted: (_) async {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('Customer phone (10 digits)'), findsOneWidget);
    expect(find.text('Checkout device OS'), findsNothing);
    expect(find.text('Browser'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('live checkout is labeled and honors selected provider',
      (tester) async {
    final client = _PaymentClient();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SandboxPaymentDialog(
          draftId: '1',
          taxPaise: 0,
          client: client,
          mode: 'live',
          preferredProvider: 'phonepe',
          onCompleted: (_) async {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('UPI payment - LIVE'), findsOneWidget);
    expect(find.textContaining('Real payments.'), findsOneWidget);
    await tester.tap(find.text('Generate QR'));
    await tester.pumpAndSettle();
    expect(client.createCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('generates QR and confirms only after provider status',
      (tester) async {
    final client = _PaymentClient();
    var completed = 0;
    await tester.pumpWidget(_app(client, (_) async => completed++));
    await tester.pumpAndSettle();
    expect(find.text('UPI payment - SANDBOX ONLY'), findsOneWidget);
    await tester.tap(find.text('Generate QR'));
    await tester.pumpAndSettle();
    expect(client.createCalls, 1);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Waiting for provider confirmation.'), findsOneWidget);
    expect(completed, 0);

    client.checked = _payment('completed', billId: 12);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(find.text('Payment confirmed. Bill #12 completed.'), findsOneWidget);
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unknown creation does not offer a second QR', (tester) async {
    final client = _PaymentClient()..creationFails = true;
    await tester.pumpWidget(_app(client, (_) async {}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate QR'));
    await tester.pumpAndSettle();
    expect(client.createCalls, 1);
    expect(
        find.textContaining('Do not collect another payment'), findsOneWidget);
    expect(find.text('Generate QR'), findsNothing);
    expect(find.text('Reload'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('confirmed payment with a failed bill can be retried',
      (tester) async {
    final client = _PaymentClient()
      ..existing = _payment('ready', qr: true)
      ..checkError = SandboxPaymentException(
        'Insufficient stock',
        payment: _payment('verified'),
      );
    await tester.pumpWidget(_app(client, (_) async {}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check status'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Payment confirmed, but the bill is not complete'),
        findsOneWidget);
    expect(find.text('Insufficient stock'), findsOneWidget);
    expect(find.text('Retry bill completion'), findsOneWidget);

    client.checkError = null;
    client.checked = _payment('completed', billId: 12);
    await tester.tap(find.text('Retry bill completion'));
    await tester.pumpAndSettle();
    expect(find.text('Payment confirmed. Bill #12 completed.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('recovers ambiguous Razorpay payment and completes the bill',
      (tester) async {
    final client = _PaymentClient()
      ..existing = _razorpay('creating')
      ..recovered = _razorpay('completed', reference: 'qr_1', billId: 42);
    var completed = 0;
    await tester.pumpWidget(_app(client, (_) async => completed++));
    await tester.pumpAndSettle();
    expect(find.text('Reference: attempt1'), findsOneWidget);
    await tester.ensureVisible(find.text('Recover Razorpay payment'));
    await tester.tap(find.text('Recover Razorpay payment'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the Razorpay QR ID to recover this payment.'),
        findsOneWidget);
    expect(client.recoveredId, isNull);
    await tester.enterText(find.byType(TextField), ' qr_1 ');
    await tester.ensureVisible(find.text('Recover Razorpay payment'));
    await tester.tap(find.text('Recover Razorpay payment'));
    await tester.pumpAndSettle();
    expect(client.recoveredId, 'attempt1');
    expect(client.recoveredReference, 'qr_1');
    expect(find.text('Payment confirmed. Bill #42 completed.'), findsOneWidget);
    expect(find.text('Generate QR'), findsNothing);
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('recovery failure retains verified payment for bill retry',
      (tester) async {
    final client = _PaymentClient()
      ..existing = _razorpay('creating')
      ..recoveryError = SandboxPaymentException(
        'Insufficient stock',
        payment: _razorpay('verified', reference: 'qr_1'),
      );
    await tester.pumpWidget(_app(client, (_) async {}));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'qr_1');
    await tester.ensureVisible(find.text('Recover Razorpay payment'));
    await tester.tap(find.text('Recover Razorpay payment'));
    await tester.pumpAndSettle();
    expect(find.text('Insufficient stock'), findsOneWidget);
    expect(find.text('Retry bill completion'), findsOneWidget);
    expect(find.text('Recover Razorpay payment'), findsNothing);
    expect(find.text('Generate QR'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('recovery conflict reports an already completed bill',
      (tester) async {
    final client = _PaymentClient()
      ..existing = _razorpay('creating')
      ..recoveryError = SandboxPaymentException(
        'Payment state changed',
        payment: _razorpay('completed', reference: 'qr_1', billId: 42),
      );
    var completed = 0;
    await tester.pumpWidget(_app(client, (_) async => completed++));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'qr_1');
    await tester.ensureVisible(find.text('Recover Razorpay payment'));
    await tester.tap(find.text('Recover Razorpay payment'));
    await tester.pumpAndSettle();
    expect(find.text('Payment confirmed. Bill #42 completed.'), findsOneWidget);
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('history opens unresolved payment for recovery', (tester) async {
    final client = _PaymentClient()..existing = _payment('verified');
    SandboxPayment? opened;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SandboxPaymentHistoryDialog(
          client: client,
          onOpenDraft: (payment) => opened = payment,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Status: verified'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opened?.id, 'attempt1');
  });

  testWidgets('recovery cannot create a new payment when draft lookup is empty',
      (tester) async {
    final client = _PaymentClient();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SandboxPaymentDialog(
          draftId: '1',
          taxPaise: 0,
          client: client,
          resumeOnly: true,
          onCompleted: (_) async {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('no longer attached'), findsOneWidget);
    expect(find.text('Generate QR'), findsNothing);
    expect(client.createCalls, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
