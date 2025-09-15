// lib/ui/widgets/cart_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/cart_cubit.dart';
import '../../logic/cart_state.dart';
import 'image_any.dart';

class CartBottomSheet extends StatelessWidget {
  /// Optional callback when user confirms the order.
  final VoidCallback? onConfirm;

  const CartBottomSheet({super.key, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          elevation: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: BlocBuilder<CartCubit, CartState>(
            builder: (context, state) {
              return Column(
                children: [
                  // Grab handle
                  Container(
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Header with total
                  ListTile(
                    title: const Text('Buyurtmangiz'),
                    trailing: Text(
                      "${state.totalUzs} so'm",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Divider(height: 1),
                  // Items
                  Expanded(
                    child: state.items.isEmpty
                        ? const Center(child: Text("Savatcha bo'sh"))
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: state.items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final it = state.items[i];
                              return ListTile(
                                leading: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: ImageAny(it.meal.imagePath),
                                  ),
                                ),
                                title: Text(it.meal.name),
                                subtitle: Text(
                                  "${it.meal.priceUzs} so'm x ${it.qty}",
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: "Kamaytirish",
                                      onPressed: () => context
                                          .read<CartCubit>()
                                          .decrement(it.meal),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    Text(
                                      '${it.qty}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: "Ko'paytirish",
                                      onPressed: () => context
                                          .read<CartCubit>()
                                          .add(it.meal),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: state.isEmpty
                                ? null
                                : () => context.read<CartCubit>().clear(),
                            child: const Text("Tozalash"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: state.isEmpty
                                ? null
                                : () {
                                    onConfirm?.call();
                                    Navigator.of(context).maybePop();
                                  },
                            child: Text("Tasdiqlash • ${state.totalUzs} so'm"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
