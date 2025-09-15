import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/meal.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  void add(Meal meal) {
    final items = [...state.items];
    final i = items.indexWhere((e) => e.meal.id == meal.id);
    if (i == -1) {
      items.add(CartItem(meal: meal, qty: 1));
    } else {
      items[i] = items[i].copyWith(qty: items[i].qty + 1);
    }
    emit(CartState(items: items));
  }

  void decrement(Meal meal) {
    final items = [...state.items];
    final i = items.indexWhere((e) => e.meal.id == meal.id);
    if (i == -1) return;
    final it = items[i];
    if (it.qty <= 1) {
      items.removeAt(i);
    } else {
      items[i] = it.copyWith(qty: it.qty - 1);
    }
    emit(CartState(items: items));
  }

  void remove(Meal meal) {
    final items = state.items.where((e) => e.meal.id != meal.id).toList();
    emit(CartState(items: items));
  }

  void clear() => emit(const CartState(items: []));
}
