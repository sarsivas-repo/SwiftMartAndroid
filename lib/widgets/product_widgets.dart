import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/app_utils.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const ProductCard({
    Key? key,
    required this.product,
    required this.onTap,
    this.onAdd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Icon(
                      Icons.shopping_bag,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Product Name: ${product.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Product Code: ${product.sku}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppUtils.formatCurrency(product.price),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: product.isLowStock ? Colors.red : Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.quantity.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const CustomerTile({
    Key? key,
    required this.customer,
    required this.onTap,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firstChar = customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                child: Text(firstChar, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 12),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        customer.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 12),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        customer.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        customer.address.isNotEmpty ? customer.address : 'N/A',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Edit customer',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    Key? key,
    required this.isLoading,
    required this.child,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeMore;

  const SectionHeader({
    Key? key,
    required this.title,
    this.onSeeMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onSeeMore != null)
            TextButton(
              onPressed: onSeeMore,
              child: const Text('See More'),
            ),
        ],
      ),
    );
  }
}

class BillItemCard extends StatelessWidget {
  final BillItem item;
  final VoidCallback? onRemove;
  final VoidCallback? onUpdateQuantity;

  const BillItemCard({
    Key? key,
    required this.item,
    this.onRemove,
    this.onUpdateQuantity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final actionStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(AppUtils.formatCurrency(item.subtotal),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            Row(
              children: [
                Expanded(child: Text('Qty: ${item.quantity}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                if (onUpdateQuantity != null)
                  TextButton(onPressed: onUpdateQuantity, style: actionStyle,
                      child: const Text('Update Qty')),
                if (onRemove != null)
                  TextButton(onPressed: onRemove, style: actionStyle,
                      child: const Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
