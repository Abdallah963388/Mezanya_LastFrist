import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';

class JarsListPage extends StatefulWidget {
  const JarsListPage({
    super.key,
    required this.cubit,
    this.onJarTap,
  });

  final AppCubit cubit;
  final void Function(LinkedWalletEntity)? onJarTap;

  @override
  State<JarsListPage> createState() => _JarsListPageState();
}

class _JarsListPageState extends State<JarsListPage> {
  bool _reorderMode = false;
  final Set<String> _coloredJars = {};

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFF0F766E);
  }

  Widget _buildCard(List<LinkedWalletEntity> allJars, LinkedWalletEntity jar) {
    final accent = _parseColor(jar.iconColor);
    final isColored = _coloredJars.contains(jar.id);
    final index = allJars.indexOf(jar);

    final card = Padding(
      key: ValueKey(jar.id),
      padding: const EdgeInsets.only(bottom: 12),
      child: Ink(
        decoration: BoxDecoration(
          color: isColored
              ? accent.withValues(alpha: 0.88)
              : accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: accent.withValues(alpha: isColored ? 0.0 : 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isColored ? 0.28 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isColored
                      ? Colors.white.withValues(alpha: 0.22)
                      : accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: AppIconPickerDialog.iconWidgetForName(
                    jar.icon,
                    color: isColored ? Colors.white : accent,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jar.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color:
                            isColored ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${jar.balance.toStringAsFixed(2)} • شهري ${jar.monthlyAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isColored
                            ? Colors.white.withValues(alpha: 0.85)
                            : accent.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              if (_reorderMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        if (_coloredJars.contains(jar.id)) {
                          _coloredJars.remove(jar.id);
                        } else {
                          _coloredJars.add(jar.id);
                        }
                      }),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isColored
                              ? Colors.white.withValues(alpha: 0.22)
                              : accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isColored
                              ? Icons.invert_colors_off_rounded
                              : Icons.color_lens_rounded,
                          size: 16,
                          color: isColored ? Colors.white : accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isColored
                              ? Colors.white.withValues(alpha: 0.15)
                              : accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          size: 18,
                          color: isColored ? Colors.white : accent,
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

    return _reorderMode
        ? card
        : InkWell(
            onTap: () => widget.onJarTap?.call(jar),
            borderRadius: BorderRadius.circular(26),
            child: card,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF1),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFBF1),
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'كل الحصالات',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _reorderMode ? Icons.check_rounded : Icons.tune_rounded,
                color: _reorderMode ? const Color(0xFF0F766E) : null,
              ),
              tooltip: _reorderMode ? 'تم' : 'إعدادات',
              onPressed: () => setState(() => _reorderMode = !_reorderMode),
            ),
          ],
        ),
        body: StreamBuilder<AppStateEntity>(
          stream: widget.cubit.stream,
          initialData: widget.cubit.state,
          builder: (context, snapshot) {
            final state = snapshot.data ?? widget.cubit.state;
            final jars = List<LinkedWalletEntity>.from(
              state.budgetSetup.linkedWallets,
            );

            if (_reorderMode) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.drag_handle_rounded,
                          size: 16,
                          color: Color(0xFF0F766E),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'اسحب الكروت لتغيير ترتيب الحصالات. اضغط أيقونة اللون لتبديل مظهر الكارت.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: jars.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        final reordered = List<LinkedWalletEntity>.from(jars);
                        final item = reordered.removeAt(oldIndex);
                        reordered.insert(newIndex, item);
                        widget.cubit.reorderJars(reordered);
                      },
                      itemBuilder: (context, index) =>
                          _buildCard(jars, jars[index]),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: jars.length,
              itemBuilder: (context, index) => _buildCard(jars, jars[index]),
            );
          },
        ),
      ),
    );
  }
}
