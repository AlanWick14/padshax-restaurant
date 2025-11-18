import 'package:flutter/material.dart';
import 'package:padshax_app/logic/image_provider.dart';
import '../../domain/meal.dart';

class MealCard extends StatefulWidget {
  final Meal meal;
  final VoidCallback onAdd;
  final VoidCallback? onImageTap;
  const MealCard({
    super.key,
    required this.meal,
    required this.onAdd,
    this.onImageTap,
  });

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> with TickerProviderStateMixin {
  late final AnimationController _hoverCtl;
  late final Animation<double> _scale;
  bool _hover = false;

  // brand colors (adjust if needed)
  static const _burgundy = Color(0xFF3B0F14);
  static const _gold = Color(0xFFFFC44D);
  static const _border = Color(0xFF8B5C2C);

  @override
  void initState() {
    super.initState();
    _hoverCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween(
      begin: 1.0,
      end: 1.01,
    ).animate(CurvedAnimation(parent: _hoverCtl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _hoverCtl.dispose();
    super.dispose();
  }

  void _onHover(bool v) {
    setState(() => _hover = v);
    v ? _hoverCtl.forward() : _hoverCtl.reverse();
  }

  void _showFullDescription() {
    final txt = widget.meal.description.trim();
    if (txt.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _burgundy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              txt,
              style: const TextStyle(
                color: Colors.white,
                height: 1.35,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final isTablet = w >= 600;
    final provider = resolveMealImageProvider(widget.meal.imagePath);

    // Responsive o'lchamlar - landscape uchun optimallashtirilgan
    final imgSize = isTablet ? 85.0 : 75.0; // kichraytirildi
    final radius = isTablet ? 14.0 : 12.0;
    final pad = isTablet ? 14.0 : 12.0; // kichraytirildi
    final titleSize = isTablet ? 15.0 : 14.0; // kichraytirildi
    final descSize = isTablet ? 12.0 : 11.0; // kichraytirildi
    final priceSize = isTablet ? 14.0 : 13.0; // kichraytirildi
    final buttonTextSize = isTablet ? 12.0 : 11.0; // kichraytirildi

    return AnimatedBuilder(
      animation: _hoverCtl,
      builder: (context, _) {
        return Transform.scale(
          scale: _scale.value,
          child: MouseRegion(
            onEnter: (_) => _onHover(true),
            onExit: (_) => _onHover(false),
            child: Card(
              color: _burgundy,
              surfaceTintColor: Colors.transparent,
              elevation: _hover ? 4 : 1,
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
                side: BorderSide(
                  color: _border.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CHAP TARF - RASM
                      ClipRRect(
                        borderRadius: BorderRadius.circular(radius - 6),
                        child: SizedBox(
                          width: imgSize,
                          height: imgSize,
                          child: GestureDetector(
                            onTap: widget
                                .onImageTap, // 👈 forward tap to open the viewer
                            child: Hero(
                              tag:
                                  'meal_img_${widget.meal.id}', // 👈 unique, image-only hero
                              placeholderBuilder: (_, _, child) => child,
                              child: Image(
                                image: provider,
                                fit: BoxFit.cover, // keep as-is for the card
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10), // kamaytirildi
                      // O'NG TARF - CONTENT
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, // min qilamiz
                          children: [
                            // TAOM NOMI
                            Text(
                              widget.meal.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),

                            // DESCRIPTION - maksimum 2 qator
                            if (widget.meal.description.isNotEmpty) ...[
                              const SizedBox(height: 2), // kamaytirildi
                              Flexible(
                                // Expanded o'rniga Flexible
                                child: GestureDetector(
                                  onTap: _showFullDescription,
                                  child: Text(
                                    widget.meal.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: descSize,
                                      height: 1.2, // kamaytirildi
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 4), // kamaytirildi
                            // NARX VA BUTTON - Row holatida
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // NARX
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    '${_fmt(widget.meal.priceUzs)} so\'m',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: priceSize,
                                      fontWeight: FontWeight.w700,
                                      color: _gold,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 6), // kamaytirildi
                                // BUTTON
                                OutlinedButton.icon(
                                  onPressed: widget.onAdd,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Savatga'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 1,
                                    ),
                                    backgroundColor: Colors.white.withValues(
                                      alpha: _hover ? 0.12 : 0.08,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet
                                          ? 10
                                          : 8, // kamaytirildi
                                      vertical: isTablet
                                          ? 6
                                          : 4, // kamaytirildi
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: buttonTextSize,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmt(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }
}
