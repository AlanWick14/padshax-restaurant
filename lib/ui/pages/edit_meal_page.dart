import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:padshax_app/data/hive_menu_repository.dart';
import 'package:padshax_app/ui/widgets/loading_overlay.dart';
import 'package:padshax_app/utils/auth_gate.dart';

import '../../data/sync_service.dart';
import '../../domain/meal.dart';
import '../../domain/root_category.dart';
import '../../domain/category.dart';

class EditMealPage extends StatefulWidget {
  final int mealId;
  const EditMealPage({super.key, required this.mealId, required Meal meal});

  @override
  State<EditMealPage> createState() => _EditMealPageState();
}

class _EditMealPageState extends State<EditMealPage> {
  final _formKey = GlobalKey<FormState>();
  Meal? _meal;

  late TextEditingController _name;
  late TextEditingController _desc;
  late TextEditingController _price;
  late TextEditingController _subcategory;

  bool _loading = true;
  bool _saving = false;
  File? _newImageFile;
  RootCategory _root = RootCategory.food;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<HiveMenuRepository>();
    final m = await repo.getMeal(widget.mealId);
    setState(() {
      _meal = m;
      _name = TextEditingController(text: m?.name ?? '');
      _desc = TextEditingController(text: m?.description ?? '');
      _price = TextEditingController(text: m != null ? '${m.priceUzs}' : '');
      _subcategory = TextEditingController(text: m?.category ?? '');
      _root = m?.root ?? RootCategory.food;
      _loading = false;
    });
  }

  @override
  void dispose() {
    if (!_loading) {
      _name.dispose();
      _desc.dispose();
      _price.dispose();
      _subcategory.dispose();
    }
    super.dispose();
  }

  Future<void> _pickNewImage() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (img == null) return;
    setState(() {
      _newImageFile = File(img.path);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _meal == null) return;

    final parsed = int.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Narx butun son bo'lishi kerak (so'm)")),
      );
      return;
    }

    setState(() => _saving = true);
    LoadingOverlay.show(context, message: "O'zgartirishlar saqlanmoqda");
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
      final draft = _meal!.copyWith(
        name: _name.text.trim(),
        description: _desc.text.trim(),
        priceUzs: parsed,
        category: _subcategory.text.trim().isEmpty
            ? _meal!.category
            : _subcategory.text.trim(),
        root: _root,
      );

      final ok = await sync.upsertCloudThenLocal(
        draft: draft,
        pickedImageFile: _newImageFile,
      );

      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cloudga yozilmadi. Lokal o'zgarmadi.")),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saqlandi')));
      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        LoadingOverlay.hide(context);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("O'chirishni tasdiqlang"),
        content: Text("'${_meal?.name ?? ''}' o'chirilsinmi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    if (!mounted) return;
    LoadingOverlay.show(context, message: "Taom o'chirilmoqda");
    try {
      final authed = await ensureAdminSignedIn(context);
      if (!authed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Clouddan o'chirish uchun admin sifatida kiring."),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      final sync = context.read<SyncService>();
      final okRemote = await sync.deleteCloudThenLocal(widget.mealId);

      if (!mounted) return;
      if (!okRemote) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Firebase'dan o'chirilmadi.")),
        );
        return;
      }

      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        LoadingOverlay.hide(context);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_meal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Menyu – Tahrirlash')),
        body: const Center(child: Text('Taom topilmadi')),
      );
    }

    final repo = context
        .watch<
          HiveMenuRepository
        >(); // watch -> StreamBuilder will refresh reliably
    final path = _newImageFile?.path ?? _meal!.imagePath;
    final isAsset = path.startsWith('assets/');
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menyu – Tahrirlash'),
        surfaceTintColor: Colors.transparent,
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _saving ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
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
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            // Image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isAsset
                    ? Image.asset(path, fit: BoxFit.cover)
                    : Image.file(File(path), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickNewImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Rasmni o\'zgartirish'),
            ),
            const SizedBox(height: 16),

            // Name
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

            // Description (bounded height, finite lines)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96, maxHeight: 160),
              child: TextFormField(
                controller: _desc,
                minLines: 4,
                maxLines:
                    6, // <-- finite, avoids “infinite” growth in a ListView
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

            // Price
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

            // Root select
            Text(
              'Asosiy kategoriya',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
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
                  onSelectionChanged: (s) => setState(() => _root = s.first),
                );
                if (constraints.maxWidth < 400) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: seg,
                  );
                }
                return seg;
              },
            ),

            const SizedBox(height: 16),

            // Subcategory
            TextFormField(
              controller: _subcategory,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Sub-kategoriya',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Majburiy' : null,
            ),
            const SizedBox(height: 8),

            // Subcategory suggestions (bounded so they never “disappear” off-screen)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: StreamBuilder<List<SubCategory>>(
                stream: repo.watchSubCategories(_root),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final list = snapshot.data!;
                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in list)
                          ActionChip(
                            label: Text(c.name),
                            onPressed: () => _subcategory.text = c.name,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Small bottom breathing room (no huge spacer)
            const SizedBox(height: 24),
            SizedBox(
              height: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 0,
            ),
          ],
        ),
      ),
    );
  }
}
