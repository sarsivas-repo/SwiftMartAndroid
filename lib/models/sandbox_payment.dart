class SandboxPayment {
  const SandboxPayment({
    required this.id,
    required this.provider,
    required this.state,
    required this.amountPaise,
    this.draftId,
    this.billId,
    this.providerReference,
    this.qrFormat,
    this.qrValue,
  });

  final String id;
  final String provider;
  final String state;
  final int amountPaise;
  final int? draftId;
  final int? billId;
  final String? providerReference;
  final String? qrFormat;
  final String? qrValue;

  factory SandboxPayment.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final provider = json['provider'];
    final state = json['state'];
    final amount = json['amount_paise'];
    if (id is! String ||
        id.isEmpty ||
        provider is! String ||
        !const {'razorpay', 'cashfree', 'phonepe'}.contains(provider) ||
        state is! String ||
        !const {'creating', 'ready', 'verified', 'completed'}.contains(state) ||
        amount is! int ||
        amount <= 0 ||
        (json['draft_id'] != null && json['draft_id'] is! int) ||
        (json['bill_id'] != null && json['bill_id'] is! int) ||
        (state == 'completed' &&
            (json['bill_id'] is! int || (json['bill_id'] as int) <= 0)) ||
        (json['provider_reference'] != null &&
            json['provider_reference'] is! String) ||
        (json['qr_format'] != null && json['qr_format'] is! String) ||
        (json['qr_value'] != null && json['qr_value'] is! String)) {
      throw const FormatException('Invalid payment response');
    }
    return SandboxPayment(
      id: id,
      provider: provider,
      state: state,
      amountPaise: amount,
      draftId: json['draft_id'] as int?,
      billId: json['bill_id'] as int?,
      providerReference: json['provider_reference'] as String?,
      qrFormat: json['qr_format'] as String?,
      qrValue: json['qr_value'] as String?,
    );
  }
}

class SandboxPaymentException implements Exception {
  const SandboxPaymentException(this.message, {this.statusCode, this.payment});

  final String message;
  final int? statusCode;
  final SandboxPayment? payment;

  @override
  String toString() => message;
}
