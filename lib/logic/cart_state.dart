import '../domain/meal.dart';

class CartItem {
  final Meal meal;
  final int qty;
  const CartItem({required this.meal, required this.qty});
  CartItem copyWith({Meal? meal, int? qty}) =>
      CartItem(meal: meal ?? this.meal, qty: qty ?? this.qty);
  int get lineTotal => meal.priceUzs * qty;
}

class CartState {
  final List<CartItem> items;
  const CartState({this.items = const []});

  int get totalQty => items.fold(0, (s, it) => s + it.qty);
  int get totalUzs => items.fold(0, (s, it) => s + it.lineTotal);
  bool get isEmpty => items.isEmpty;
}
