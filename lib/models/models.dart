enum BillStatus { pending, completed, cancelled }

enum UserRole { admin, manager, cashier }

class User {
  final String id;
  final String username;
  final String email;
  final String mobile;
  final UserRole role;
  final List<UserRole> roles;
  final bool isActive;
  final bool mustChangePassword;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.mobile,
    required this.role,
    required this.roles,
    required this.isActive,
    required this.mustChangePassword,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final roles = _parseRoles(json['roles'], fallbackRole: json['role']?.toString());
    return User(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      mobile: json['mobile'] ?? '',
      role: roles.first,
      roles: roles,
      isActive: json['is_active'] as bool? ?? true,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'mobile': mobile,
    'role': role.name,
    'roles': roles.map((item) => item.name).toList(),
    'is_active': isActive,
    'must_change_password': mustChangePassword,
    'created_at': createdAt.toIso8601String(),
  };

  bool hasRole(UserRole userRole) => roles.contains(userRole);

  String get roleSummary => roles.map((item) => item.name.toUpperCase()).join(', ');
}

UserRole _parseRole(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return UserRole.admin;
    case 'manager':
      return UserRole.manager;
    default:
      return UserRole.cashier;
  }
}

List<UserRole> _parseRoles(dynamic rawRoles, {String? fallbackRole}) {
  final parsedRoles = <UserRole>[];

  if (rawRoles is List) {
    for (final rawRole in rawRoles) {
      final role = _parseRole(rawRole?.toString() ?? 'cashier');
      if (!parsedRoles.contains(role)) {
        parsedRoles.add(role);
      }
    }
  }

  if (parsedRoles.isEmpty) {
    parsedRoles.add(_parseRole(fallbackRole ?? 'cashier'));
  }

  return parsedRoles;
}

class Product {
  final String id;
  final String name;
  final String sku;
  final String category;
  final double price;
  final int quantity;
  final int reorderLevel;
  final String taxMode;
  final int taxBasisPoints;
  final int? mrpMinor;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.price,
    required this.quantity,
    required this.reorderLevel,
    this.taxMode = 'none',
    this.taxBasisPoints = 0,
    this.mrpMinor,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final reorderRaw =
        json['reorder_level'] ?? json['low_stock_threshold'] ?? json['reorderLevel'] ?? json['min_qty'];

    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      sku: json['sku'] ?? '',
      category: json['category'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 0,
      reorderLevel: reorderRaw is int ? reorderRaw : int.tryParse('${reorderRaw ?? ''}') ?? 10,
      taxMode: json['tax_mode'] as String? ?? 'none',
      taxBasisPoints: json['tax_basis_points'] as int? ?? 0,
      mrpMinor: json['mrp_minor'] as int?,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'category': category,
    'price': price,
    'quantity': quantity,
    'reorder_level': reorderLevel,
    'tax_mode': taxMode,
    'tax_basis_points': taxBasisPoints,
    'mrp_minor': mrpMinor,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  bool get isLowStock => quantity <= reorderLevel;

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    double? price,
    int? quantity,
    int? reorderLevel,
    String? taxMode,
    int? taxBasisPoints,
    int? mrpMinor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      taxMode: taxMode ?? this.taxMode,
      taxBasisPoints: taxBasisPoints ?? this.taxBasisPoints,
      mrpMinor: mrpMinor ?? this.mrpMinor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BillItem {
  final String id;
  final String billId;
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double subtotal;
  final String taxMode;
  final int taxBasisPoints;
  final int taxMinor;

  String get taxDescription {
    if (taxMode == 'none') return '';
    final rate = (taxBasisPoints / 100).toStringAsFixed(2);
    return taxMode == 'inclusive' ? '$rate% tax included' : '$rate% tax added';
  }

  BillItem({
    required this.id,
    required this.billId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.taxMode = 'none',
    this.taxBasisPoints = 0,
    this.taxMinor = 0,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'] ?? '',
      billId: json['bill_id'] ?? '',
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxMode: json['tax_mode'] as String? ?? 'none',
      taxBasisPoints: json['tax_basis_points'] as int? ?? 0,
      taxMinor: json['tax_minor'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bill_id': billId,
    'product_id': productId,
    'product_name': productName,
    'price': price,
    'quantity': quantity,
    'subtotal': subtotal,
    'tax_mode': taxMode,
    'tax_basis_points': taxBasisPoints,
    'tax_minor': taxMinor,
  };

  BillItem copyWith({
    String? id,
    String? billId,
    String? productId,
    String? productName,
    double? price,
    int? quantity,
    double? subtotal,
    String? taxMode,
    int? taxBasisPoints,
    int? taxMinor,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      taxMode: taxMode ?? this.taxMode,
      taxBasisPoints: taxBasisPoints ?? this.taxBasisPoints,
      taxMinor: taxMinor ?? this.taxMinor,
    );
  }
}

class Bill {
  final String id;
  final String customerId;
  final double subtotal;
  final double taxAmount;
  final double total;
  final BillStatus status;
  final String paymentMethod;
  final DateTime createdAt;
  final List<BillItem> items;
  final int pricingVersion;

  Bill({
    required this.id,
    required this.customerId,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    required this.items,
    this.pricingVersion = 0,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    List<BillItem> items = [];
    if (json['items'] is List) {
      items = (json['items'] as List)
          .map((item) => BillItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return Bill(
      id: json['id'] ?? '',
      customerId: json['customer_id'] ?? '',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      status: _parseBillStatus(json['status'] ?? 'completed'),
      paymentMethod: json['payment_method'] ?? 'cash',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      items: items,
      pricingVersion: json['pricing_version'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'subtotal': subtotal,
    'tax_amount': taxAmount,
    'total': total,
    'status': status.toString().split('.').last,
    'payment_method': paymentMethod,
    'created_at': createdAt.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
    'pricing_version': pricingVersion,
  };

  Bill copyWith({
    String? id,
    String? customerId,
    double? subtotal,
    double? taxAmount,
    double? total,
    BillStatus? status,
    String? paymentMethod,
    DateTime? createdAt,
    List<BillItem>? items,
  }) {
    return Bill(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      pricingVersion: pricingVersion,
    );
  }
}

BillStatus _parseBillStatus(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return BillStatus.pending;
    case 'cancelled':
      return BillStatus.cancelled;
    default:
      return BillStatus.completed;
  }
}

class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final DateTime createdAt;
  final double totalSpent;
  final int billCount;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.createdAt,
    required this.totalSpent,
    required this.billCount,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      billCount: json['bill_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'created_at': createdAt.toIso8601String(),
    'total_spent': totalSpent,
    'bill_count': billCount,
  };
}

class StockLog {
  final String id;
  final String productId;
  final String productName;
  final String username;
  final String role;
  final String type;
  final int quantity;
  final String notes;
  final DateTime createdAt;

  StockLog({
    required this.id,
    required this.productId,
    required this.productName,
    required this.username,
    required this.role,
    required this.type,
    required this.quantity,
    required this.notes,
    required this.createdAt,
  });

  factory StockLog.fromJson(Map<String, dynamic> json) {
    return StockLog(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      username: json['username'] ?? 'System',
      role: json['role'] ?? 'UNKNOWN',
      type: json['type'] ?? 'manual',
      quantity: json['quantity'] as int? ?? 0,
      notes: json['notes'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'username': username,
    'role': role,
    'type': type,
    'quantity': quantity,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };
}

class MonthlySalary {
  final String id;
  final String userId;
  final String username;
  final String role;
  final int salaryYear;
  final int salaryMonth;
  final double basicSalary;
  final double transportAllowance;
  final double bonus;
  final double totalSalary;
  final DateTime createdAt;
  final DateTime updatedAt;

  MonthlySalary({
    required this.id,
    required this.userId,
    required this.username,
    required this.role,
    required this.salaryYear,
    required this.salaryMonth,
    required this.basicSalary,
    required this.transportAllowance,
    required this.bonus,
    required this.totalSalary,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MonthlySalary.fromJson(Map<String, dynamic> json) {
    return MonthlySalary(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      salaryYear: json['salary_year'] as int? ?? 0,
      salaryMonth: json['salary_month'] as int? ?? 0,
      basicSalary: (json['basic_salary'] as num?)?.toDouble() ?? 0,
      transportAllowance: (json['transport_allowance'] as num?)?.toDouble() ?? 0,
      bonus: (json['bonus'] as num?)?.toDouble() ?? 0,
      totalSalary: (json['total_salary'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'username': username,
    'role': role,
    'salary_year': salaryYear,
    'salary_month': salaryMonth,
    'basic_salary': basicSalary,
    'transport_allowance': transportAllowance,
    'bonus': bonus,
    'total_salary': totalSalary,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class SalesReport {
  final DateTime date;
  final double totalSales;
  final int billCount;
  final double averageBillAmount;
  final double taxCollected;

  SalesReport({
    required this.date,
    required this.totalSales,
    required this.billCount,
    required this.averageBillAmount,
    required this.taxCollected,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    return SalesReport(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0.0,
      billCount: json['bill_count'] as int? ?? 0,
      averageBillAmount: (json['average_bill_amount'] as num?)?.toDouble() ?? 0.0,
      taxCollected: (json['tax_collected'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'total_sales': totalSales,
    'bill_count': billCount,
    'average_bill_amount': averageBillAmount,
    'tax_collected': taxCollected,
  };
}
