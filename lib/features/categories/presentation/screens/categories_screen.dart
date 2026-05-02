import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/category_entity.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _tab = 'expense';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final sections = _sectionsFor(state);
        final totalCategories =
            sections.fold<int>(0, (sum, section) => sum + section.categories.length);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _heroCard(totalCategories),
            const SizedBox(height: 14),
            _typeSwitcher(),
            const SizedBox(height: 16),
            if (sections.isEmpty) _emptySetupCard() else ...sections.map(_sectionCard),
          ],
        );
      },
    );
  }

  List<_SectionData> _sectionsFor(AppStateEntity state) {
    final budget = state.budgetSetup;
    final generalExpense = state.categories
        .where((c) => c.scope == 'expense' && c.incomeSourceId == null)
        .toList();
    final generalIncome = state.categories.where((c) => c.scope == 'income').toList();

    if (_tab == 'income') {
      return [
        _SectionData(
          key: 'income',
          title: 'فئات الدخل',
          subtitle: 'كل فئات الدخل هنا عامة وغير مرتبطة بأي مصدر دخل محدد.',
          target: const _CategoryTarget('income', 'income'),
          categories: generalIncome,
          accent: const Color(0xFF4B7F52),
        ),
      ];
    }

    return [
      _SectionData(
        key: 'general-expense',
        title: 'الفئات العامة',
        subtitle: 'للمعاملات خارج الميزانية أو غير المرتبطة بمخصص.',
        target: const _CategoryTarget('general-expense', 'general-expense'),
        categories: generalExpense,
        accent: const Color(0xFF8A6B3D),
      ),
      ...budget.allocations.map(
        (allocation) => _SectionData(
          key: 'allocation-${allocation.id}',
          title: allocation.name,
          subtitle: 'فئات مخصص "${allocation.name}" داخل الميزانية.',
          target: _CategoryTarget('allocation', allocation.id),
          categories: allocation.categories,
          accent: _parseColor(allocation.iconColor),
        ),
      ),
      ...budget.linkedWallets.map(
        (wallet) => _SectionData(
          key: 'linked-${wallet.id}',
          title: wallet.name,
          subtitle: 'فئات الحصالة أو الحساب المرتبط "${wallet.name}".',
          target: _CategoryTarget('linked-wallet', wallet.id),
          categories: wallet.categories,
          accent: _parseColor(wallet.iconColor),
        ),
      ),
    ];
  }

  Widget _heroCard(int totalCategories) {
    final theme = Theme.of(context);
    final accent =
        _tab == 'income' ? const Color(0xFF2F6F5E) : const Color(0xFF7A5D34);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.96),
            accent.withValues(alpha: 0.72),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.category_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tab == 'income' ? 'فئات الدخل' : 'فئات المصروف',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$totalCategories فئة منظمة داخل الأقسام الحالية',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeSwitcher() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _switchTile('expense', 'فئات المصروف', Icons.north_east_rounded),
          const SizedBox(width: 8),
          _switchTile('income', 'فئات الدخل', Icons.south_west_rounded),
        ],
      ),
    );
  }

  Widget _switchTile(String value, String label, IconData icon) {
    final selected = _tab == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = value),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.surface : null,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? const Color(0xFF2F6F5E) : null,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected ? const Color(0xFF2F6F5E) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(_SectionData section) {
    final theme = Theme.of(context);
    final accent = section.accent;
    final count = section.categories.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        Icons.folder_rounded,
                        color: accent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  section.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$count فئة',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            section.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(
                  color: theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.5),
                  height: 1,
                ),
                const SizedBox(height: 14),
                if (section.categories.isEmpty)
                  _emptySection('لا توجد فئات في هذا القسم حتى الآن.')
                else
                  _categoriesGrid(section.target, section.categories),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openCategoryEditor(section.target),
                    icon: Icon(
                      Icons.add_rounded,
                      color: accent,
                      size: 20,
                    ),
                    label: Text(
                      'إضافة فئة جديدة',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: accent.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoriesGrid(
    _CategoryTarget target,
    List<CategoryEntity> categories,
  ) {
    final rows = <Widget>[];
    for (var i = 0; i < categories.length; i += 2) {
      final left = categories[i];
      final right = i + 1 < categories.length ? categories[i + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(child: _categoryCard(target, left)),
            const SizedBox(width: 10),
            Expanded(
              child: right != null
                  ? _categoryCard(target, right)
                  : const SizedBox(),
            ),
          ],
        ),
      );
      if (i + 2 < categories.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _categoryCard(_CategoryTarget target, CategoryEntity category) {
    final color = _parseColor(category.color);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: AppIconPickerDialog.iconWidgetForName(
                    category.icon,
                    color: color,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _openCategoryEditor(target, editing: category),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: color.withValues(alpha: 0.75),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              GestureDetector(
                onTap: () => _deleteCategory(target, category),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySection(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptySetupCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const Column(
        children: [
          Icon(Icons.category_outlined, size: 46, color: Color(0xFF2F6F5E)),
          SizedBox(height: 12),
          Text(
            'لا توجد أقسام فئات بعد',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          SizedBox(height: 6),
          Text(
            'ابدأ بإعداد الميزانية الشهرية أو إضافة مصادر دخل ومخصصات حتى تظهر أقسام الفئات هنا.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _openCategoryEditor(
    _CategoryTarget target, {
    CategoryEntity? editing,
  }) async {
    final result = await Navigator.of(context).push<CategoryEntity>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CategoryEditorScreen(
          current: editing,
          scope: _tab,
          target: target,
        ),
      ),
    );
    if (result == null) return;
    await _saveCategory(target, result, editing: editing);
  }

  Future<void> _saveCategory(
    _CategoryTarget target,
    CategoryEntity category, {
    CategoryEntity? editing,
  }) async {
    final state = widget.cubit.state;
    final budget = state.budgetSetup;

    if (target.kind == 'allocation') {
      final allocation = budget.allocations.firstWhere((a) => a.id == target.id);
      final next = editing == null
          ? [...allocation.categories, category]
          : allocation.categories
              .map((c) => c.id == editing.id ? category : c)
              .toList();
      await widget.cubit.updateAllocationCategories(
        allocationId: target.id,
        categories: next,
      );
      return;
    }

    if (target.kind == 'linked-wallet') {
      final wallet = budget.linkedWallets.firstWhere((w) => w.id == target.id);
      final next = editing == null
          ? [...wallet.categories, category]
          : wallet.categories
              .map((c) => c.id == editing.id ? category : c)
              .toList();
      await widget.cubit.updateLinkedWalletCategories(
        linkedWalletId: target.id,
        categories: next,
      );
      return;
    }

    final current = state.categories;
    late final List<CategoryEntity> next;
    if (target.kind == 'income') {
      final source = current.where((c) => c.scope == 'income').toList();
      final updated = editing == null
          ? [...source, category]
          : source.map((c) => c.id == editing.id ? category : c).toList();
      final untouched = current.where((c) => c.scope != 'income').toList();
      next = [...untouched, ...updated];
    } else {
      final source = current
          .where((c) => c.scope == 'expense' && c.incomeSourceId == null)
          .toList();
      final updated = editing == null
          ? [...source, category]
          : source.map((c) => c.id == editing.id ? category : c).toList();
      final untouched = current
          .where((c) => !(c.scope == 'expense' && c.incomeSourceId == null))
          .toList();
      next = [...untouched, ...updated];
    }
    await widget.cubit.setCategories(next);
  }

  Future<void> _deleteCategory(
    _CategoryTarget target,
    CategoryEntity category,
  ) async {
    final state = widget.cubit.state;
    final budget = state.budgetSetup;

    if (target.kind == 'allocation') {
      final allocation = budget.allocations.firstWhere((a) => a.id == target.id);
      await widget.cubit.updateAllocationCategories(
        allocationId: target.id,
        categories:
            allocation.categories.where((c) => c.id != category.id).toList(),
      );
      return;
    }

    if (target.kind == 'linked-wallet') {
      final wallet = budget.linkedWallets.firstWhere((w) => w.id == target.id);
      await widget.cubit.updateLinkedWalletCategories(
        linkedWalletId: target.id,
        categories: wallet.categories.where((c) => c.id != category.id).toList(),
      );
      return;
    }

    await widget.cubit.setCategories(
      state.categories.where((c) => c.id != category.id).toList(),
    );
  }

  Color _parseColor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (value ?? 0x165B47));
  }
}

class _CategoryEditorScreen extends StatefulWidget {
  const _CategoryEditorScreen({
    required this.current,
    required this.scope,
    required this.target,
  });

  final CategoryEntity? current;
  final String scope;
  final _CategoryTarget target;

  @override
  State<_CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends State<_CategoryEditorScreen> {
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.current?.name ?? '');
    _selectedIcon = widget.current?.icon ?? 'category';
    _selectedColor = widget.current?.color ?? '#2f6f5e';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final picked = await AppIconPickerDialog.show(
      context,
      initialIconName: _selectedIcon,
      initialColorHex: _selectedColor,
      title: 'اختيار أيقونة الفئة',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedIcon = picked.iconName;
      _selectedColor = picked.colorHex;
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم الفئة أولًا.')),
      );
      return;
    }
    Navigator.of(context).pop(
      CategoryEntity(
        id: widget.current?.id ?? 'cat-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        icon: _selectedIcon,
        color: _selectedColor,
        scope: widget.scope,
        allocationId:
            widget.target.kind == 'allocation' ? widget.target.id : null,
        walletId:
            widget.target.kind == 'linked-wallet' ? widget.target.id : null,
        incomeSourceId: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = _parseColor(_selectedColor);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.current == null ? 'إضافة فئة' : 'تعديل الفئة'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: accent,
            ),
            child: Text(widget.current == null ? 'إضافة الفئة' : 'حفظ التعديل'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.95),
                  accent.withValues(alpha: 0.72),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: AppIconPickerDialog.iconWidgetForName(
                      _selectedIcon,
                      color: Colors.white,
                      size: 31,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.trim().isEmpty
                            ? 'فئة جديدة'
                            : _nameController.text.trim(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.scope == 'income' ? 'فئة دخل' : 'فئة مصروف',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _EditorSection(
            title: 'بيانات الفئة',
            subtitle: 'اكتب اسمًا واضحًا واختر أيقونة ولونًا يناسبان الفئة.',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الفئة',
                    hintText: 'مثل: مطاعم أو مواصلات أو مكافآت',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickIcon,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: AppIconPickerDialog.iconWidgetForName(
                              _selectedIcon,
                              color: accent,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'اختيار الأيقونة واللون',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'هذه الأيقونة ستظهر في المعاملات والقوائم.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (value ?? 0x2F6F5E));
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CategoryTarget {
  const _CategoryTarget(this.kind, this.id);

  final String kind;
  final String id;
}

class _SectionData {
  const _SectionData({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.target,
    required this.categories,
    required this.accent,
  });

  final String key;
  final String title;
  final String subtitle;
  final _CategoryTarget target;
  final List<CategoryEntity> categories;
  final Color accent;
}
