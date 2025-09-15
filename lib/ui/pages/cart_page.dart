import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padshax_app/ui/widgets/image_any.dart';
import '../../logic/cart_cubit.dart';
import '../../logic/cart_state.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mq = MediaQuery.of(context);
    final isTablet = mq.size.width > 600;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Savatcha',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          BlocBuilder<CartCubit, CartState>(
            builder: (context, state) {
              if (state.isEmpty) return const SizedBox.shrink();
              return IconButton(
                onPressed: () => _showClearDialog(context),
                icon: Icon(Icons.delete_outline, color: scheme.error),
                tooltip: 'Savatni tozalash',
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return _buildEmptyCart(context, scheme, isTablet);
          }
          return _buildCartContent(context, state, isTablet, scheme);
        },
      ),
      bottomNavigationBar: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          return _buildBottomBar(context, state, scheme, isTablet);
        },
      ),
    );
  }

  Widget _buildEmptyCart(
    BuildContext context,
    ColorScheme scheme,
    bool isTablet,
  ) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 48 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer.withOpacity(0.3),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: isTablet ? 80 : 64,
                color: scheme.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Savatcha bo\'sh',
              style: TextStyle(
                fontSize: isTablet ? 28 : 24,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hali hech qanday taom tanlanmagan.\nMenyuga qaytib taomlarni tanlang.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                color: scheme.onSurface.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Menyuga qaytish'),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 32 : 24,
                  vertical: isTablet ? 16 : 12,
                ),
                textStyle: TextStyle(fontSize: isTablet ? 18 : 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(
    BuildContext context,
    CartState state,
    bool isTablet,
    ColorScheme scheme,
  ) {
    if (isTablet) {
      return _buildTabletLayout(context, state, scheme);
    } else {
      return _buildMobileLayout(context, state, scheme);
    }
  }

  Widget _buildTabletLayout(
    BuildContext context,
    CartState state,
    ColorScheme scheme,
  ) {
    return Row(
      children: [
        // Cart Items - Left side
        Expanded(
          flex: 3,
          child: _buildCartList(context, state, scheme, isTablet: true),
        ),
        // Order Summary - Right side
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withOpacity(0.3),
            border: Border(
              left: BorderSide(color: scheme.outline.withOpacity(0.2)),
            ),
          ),
          child: _buildOrderSummary(context, state, scheme, isTablet: true),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    CartState state,
    ColorScheme scheme,
  ) {
    return _buildCartList(context, state, scheme, isTablet: false);
  }

  Widget _buildCartList(
    BuildContext context,
    CartState state,
    ColorScheme scheme, {
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: Row(
            children: [
              Text(
                'Tanlangan taomlar',
                style: TextStyle(
                  fontSize: isTablet ? 22 : 20,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${state.items.length} turi',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Items List
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
            itemCount: state.items.length,
            separatorBuilder: (_, _) => SizedBox(height: isTablet ? 16 : 12),
            itemBuilder: (context, index) {
              final item = state.items[index];
              return _buildCartItem(context, item, scheme, isTablet);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    dynamic item,
    ColorScheme scheme,
    bool isTablet,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Row(
          children: [
            // Meal Image
            Container(
              width: isTablet ? 80 : 60,
              height: isTablet ? 80 : 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                color: scheme.surfaceContainerHighest,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                child: ImageAny(
                  item.meal.imagePath,
                  fit: BoxFit.cover,
                  // falls back to 'assets/images/meals/padshax_defaultImage.webp' if missing
                ),
              ),
            ),
            SizedBox(width: isTablet ? 20 : 16),

            // Meal Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.meal.name,
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_formatPrice(item.meal.priceUzs)} so'm",
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: scheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Jami: ${_formatPrice(item.meal.priceUzs * item.qty)} so'm",
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity Controls
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () =>
                        context.read<CartCubit>().decrement(item.meal),
                    icon: Icon(Icons.remove, size: isTablet ? 24 : 20),
                    style: IconButton.styleFrom(
                      foregroundColor: scheme.primary,
                      padding: EdgeInsets.all(isTablet ? 12 : 8),
                    ),
                  ),
                  Container(
                    constraints: BoxConstraints(minWidth: isTablet ? 48 : 40),
                    child: Text(
                      '${item.qty}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 18 : 16,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.read<CartCubit>().add(item.meal),
                    icon: Icon(Icons.add, size: isTablet ? 24 : 20),
                    style: IconButton.styleFrom(
                      foregroundColor: scheme.primary,
                      padding: EdgeInsets.all(isTablet ? 12 : 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(
    BuildContext context,
    CartState state,
    ColorScheme scheme, {
    required bool isTablet,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buyurtma xulasasi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // Summary items
          ...state.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.meal.name} x${item.qty}',
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                  Text(
                    '${_formatPrice(item.meal.priceUzs * item.qty)} so\'m',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 32),

          // Total
          Row(
            children: [
              Text(
                'Jami:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${_formatPrice(state.totalUzs)} so\'m',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.isEmpty
                  ? null
                  : () {
                      // TODO: implement order processing
                    },
              icon: const Icon(Icons.receipt_long),
              label: const Text('Buyurtma berish'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    CartState state,
    ColorScheme scheme,
    bool isTablet,
  ) {
    if (isTablet) {
      return const SizedBox.shrink(); // Summary is already shown on the right side
    }

    if (state.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Order Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outline.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Jami taomlar: ${state.items.length}',
                          style: TextStyle(
                            fontSize: 16,
                            color: scheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Miqdor: ${state.items.fold(0, (sum, item) => sum + item.qty)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: scheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Umumiy narx:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_formatPrice(state.totalUzs)} so\'m',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showClearDialog(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Tozalash'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error.withOpacity(0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        // TODO: implement order processing
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Buyurtma berish'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
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

  void _showClearDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: scheme.error, size: 28),
        title: const Text('Savatni tozalash'),
        content: const Text(
          'Barcha taomlar savatdan olib tashlanadi. Davom etasizmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              context.read<CartCubit>().clear();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            child: const Text('Tozalash'),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
