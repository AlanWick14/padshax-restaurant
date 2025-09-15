import 'package:flutter/material.dart';

class CartButtonBar extends StatelessWidget {
  final int totalQty;
  final int totalUzs;
  final VoidCallback onPressed;
  const CartButtonBar({
    super.key,
    required this.totalQty,
    required this.totalUzs,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(blurRadius: 6, color: Colors.black.withOpacity(0.08)),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Savatcha • $totalQty ta"),
              Text("$totalUzs so'm"),
            ],
          ),
        ),
      ),
    );
  }
}
