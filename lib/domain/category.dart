import 'root_category.dart';

class SubCategory {
  final int id;
  final RootCategory root;
  final String name;

  SubCategory({required this.id, required this.root, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'root': root.key, 'name': name};

  static SubCategory fromJson(Map<String, dynamic> j) => SubCategory(
    id: j['id'] as int,
    root: RootCategoryX.fromKey(j['root'] as String),
    name: j['name'] as String,
  );
}
