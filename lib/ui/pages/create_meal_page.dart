import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:padshax_app/domain/meal.dart';
import 'package:padshax_app/ui/widgets/loading_overlay.dart';
import 'package:padshax_app/utils/auth_gate.dart';
import 'package:provider/provider.dart';

import '../../data/hive_menu_repository.dart';
import '../../data/sync_service.dart';
import '../../domain/root_category.dart';
import '../../domain/category.dart';
import 'menu_page.dart';

class CreateMealPage extends StatefulWidget {
  final bool firstRun;
  const CreateMealPage({super.key, this.firstRun = false});

  @override
  State<CreateMealPage> createState() => _CreateMealPageState();
}

class _CreateMealPageState extends State<CreateMealPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _subcategory = TextEditingController();

  RootCategory _root = RootCategory.food;
  XFile? _picked;
  bool _saving = false;

  @override
  void dispose() {
    _name
      ..removeListener(() {})
      ..dispose();
    _desc.dispose();
    _price.dispose();
    _subcategory.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final p = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (p != null) setState(() => _picked = p);
  }

  void _clearImage() => setState(() => _picked = null);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final price = int.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Narx butun son bo'lishi kerak (so'm)")),
      );
      return;
    }

    setState(() => _saving = true);
    LoadingOverlay.show(context, message: 'Taom saqlanmoqda');
    try {
      final authed = await ensureAdminSignedIn(context);
      if (!authed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cloudga yozish uchun admin sifatida kiring.'),
            ),
          );
        }
        return;
      }
      if (!mounted) return;

      final sync = context.read<SyncService>();
      final newId = DateTime.now().microsecondsSinceEpoch;

      final draft = Meal(
        id: newId,
        name: _name.text.trim(),
        description: _desc.text.trim(),
        priceUzs: price,
        imagePath:
            _picked?.path ?? 'assets/images/meals/padshax_defaultImage.webp',
        imageUrl: null,
        category: _subcategory.text.trim().isEmpty
            ? 'Other'
            : _subcategory.text.trim(),
        root: _root,
        isAvailable: true,
        updatedAt: DateTime.now(),
      );

      final ok = await sync.upsertCloudThenLocal(
        draft: draft,
        pickedImageFile: _picked != null ? File(_picked!.path) : null,
      );

      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cloudga yozilmadi. Lokal o'zgarmadi.")),
        );
        return;
      }

      if (widget.firstRun) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const MenuPage()));
      } else {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        LoadingOverlay.hide(context);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<HiveMenuRepository>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Yangi taom qo'shish"),
        surfaceTintColor: Colors.transparent,
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: widget.firstRun
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saqlanyapti…' : 'Saqlash'),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  // 🔴 NO IntrinsicHeight here; just a plain Column
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image picker preview
                      GestureDetector(
                        onTap: _pickImage,
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _picked == null
                                ? const Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(Icons.image_outlined, size: 48),
                                      Positioned(
                                        bottom: 12,
                                        child: Text('Rasm tanlash'),
                                      ),
                                    ],
                                  )
                                : Image.file(
                                    File(_picked!.path),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_picked != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _clearImage,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Rasmni olib tashlash'),
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Nomi
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nomi',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Majburiy' : null,
                      ),
                      const SizedBox(height: 12),

                      // Tavsif
                      SizedBox(
                        height: 120,
                        child: TextFormField(
                          controller: _desc,
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            labelText: 'Tavsif',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Narx
                      TextFormField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: "Narx (so'm)",
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Majburiy' : null,
                      ),
                      const SizedBox(height: 16),

                      // ROOT tanlash
                      Text(
                        'Asosiy kategoriya',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),

                      LayoutBuilder(
                        builder: (context, segmentConstraints) {
                          final seg = SegmentedButton<RootCategory>(
                            segments: const [
                              ButtonSegment(
                                value: RootCategory.food,
                                label: Text('Mutfak (Yeguliklar)'),
                              ),
                              ButtonSegment(
                                value: RootCategory.drink,
                                label: Text('Bar (Ichimliklar)'),
                              ),
                            ],
                            selected: {_root},
                            onSelectionChanged: (s) =>
                                setState(() => _root = s.first),
                          );
                          if (segmentConstraints.maxWidth < 400) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: seg,
                            );
                          }
                          return seg;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Sub-kategoriya
                      TextFormField(
                        controller: _subcategory,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Sub-kategoriya',
                          hintText:
                              'Masalan: Salatlar, Burgerlar, Issiq ichimliklar…',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Majburiy' : null,
                      ),
                      const SizedBox(height: 18),

                      // Sub-kategoriya takliflari
                      StreamBuilder<List<SubCategory>>(
                        stream: repo.watchSubCategories(_root),
                        builder: (context, snap) {
                          if (!snap.hasData || snap.data!.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final list = snap.data!;
                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final c in list)
                                    ActionChip(
                                      label: Text(c.name),
                                      onPressed: () =>
                                          _subcategory.text = c.name,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // small breathing room at the bottom (no Expanded!)
                      const SizedBox(height: 24),
                      SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom > 0
                            ? 12
                            : 0,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
