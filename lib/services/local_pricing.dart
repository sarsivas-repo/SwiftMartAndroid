class LocalPricing {
  static const maxMinor = 9999999999;

  static ({int base, int tax, int total}) amounts(
      int unitPrice, int quantity, int rate, String mode, {int? mrpMinor}) {
    if (unitPrice < 0 || quantity <= 0 || quantity > 1000000 ||
        unitPrice > maxMinor ~/ quantity || rate < 0 || rate > 10000 ||
        !{'none', 'inclusive', 'additional'}.contains(mode) ||
        (mode == 'none' && rate != 0) ||
        (mrpMinor != null && (mrpMinor < 0 || mrpMinor > maxMinor))) {
      throw ArgumentError('Invalid price or tax settings.');
    }
    final amount = unitPrice * quantity;
    final base = mode == 'inclusive'
        ? (amount * 10000 + (10000 + rate) ~/ 2) ~/ (10000 + rate)
        : amount;
    final tax = mode == 'inclusive' ? amount - base :
        mode == 'additional' ? (amount * rate + 5000) ~/ 10000 : 0;
    final total = base + tax;
    if (total > maxMinor || (mrpMinor != null && total > mrpMinor * quantity)) {
      throw ArgumentError('Total is too large or exceeds the entered maximum final price.');
    }
    return (base: base, tax: tax, total: total);
  }
}
