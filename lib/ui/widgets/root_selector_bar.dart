import 'package:flutter/material.dart';
import '../../domain/root_category.dart';

class RootSelectorBar extends StatelessWidget {
  final RootCategory value;
  final ValueChanged<RootCategory> onChanged;
  final bool isTablet;

  const RootSelectorBar({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 24 : 16, isTablet ? 16 : 12, isTablet ? 24 : 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bo‘lim',
            style: TextStyle(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<RootCategory>(
            segments: const [
              ButtonSegment(
                value: RootCategory.food,
                label: Text('Mutfak (Yeguliklar)'),
                icon: Icon(Icons.restaurant_menu),
              ),
              ButtonSegment(
                value: RootCategory.drink,
                label: Text('Bar (Ichimliklar)'),
                icon: Icon(Icons.local_bar_outlined),
              ),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (sel) => onChanged(sel.first),
          ),
        ],
      ),
    );
  }
}
