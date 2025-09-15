enum RootCategory { food, drink, dessert }

extension RootCategoryX on RootCategory {
  String get key => this == RootCategory.drink ? 'drink' : 'food';
  String get labelUz =>
      this == RootCategory.drink ? 'Ichimliklar' : 'Yeguliklar';

  static RootCategory fromKey(String v) =>
      v == 'drink' ? RootCategory.drink : RootCategory.food;
}
