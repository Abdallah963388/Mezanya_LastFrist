import 'package:flutter/material.dart';

class BudgetTrackingMonthBar extends StatelessWidget {
  const BudgetTrackingMonthBar({
    super.key,
    required this.rangeLabel,
    required this.isCurrent,
    required this.onPrevious,
    required this.onNext,
  });

  final String rangeLabel;
  final bool isCurrent;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF165B47).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF165B47).withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF165B47),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  rangeLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF165B47),
                  ),
                ),
                if (isCurrent)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF165B47).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'الدورة الحالية',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF165B47),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF165B47),
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetTrackingHeroSummaryCard extends StatelessWidget {
  const BudgetTrackingHeroSummaryCard({
    super.key,
    required this.totalIncomeActual,
    required this.totalExpenseActual,
    required this.remainingIncome,
  });

  final double totalIncomeActual;
  final double totalExpenseActual;
  final double remainingIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthRatio = totalIncomeActual <= 0
        ? 1.0
        : (remainingIncome / totalIncomeActual).clamp(-0.5, 1.0);

    const cGreen1 = Color(0xFF165B47);
    const cGreen2 = Color(0xFF2F7D5E);
    const cGreen3 = Color(0xFF8DCB9B);
    const cYellow1 = Color(0xFF8B6C14);
    const cYellow2 = Color(0xFFAA8C20);
    const cYellow3 = Color(0xFFD4B040);
    const cRed1 = Color(0xFF8E4A37);
    const cRed2 = Color(0xFFC96B47);
    const cRed3 = Color(0xFFE07055);

    Color g1, g2, g3, shadow;
    if (healthRatio <= 0.0) {
      g1 = cRed1;
      g2 = cRed2;
      g3 = cRed3;
      shadow = cRed1;
    } else if (healthRatio < 0.35) {
      final t = healthRatio / 0.35;
      g1 = Color.lerp(cRed1, cYellow1, t)!;
      g2 = Color.lerp(cRed2, cYellow2, t)!;
      g3 = Color.lerp(cRed3, cYellow3, t)!;
      shadow = g1;
    } else if (healthRatio < 0.65) {
      final t = (healthRatio - 0.35) / 0.30;
      g1 = Color.lerp(cYellow1, cGreen1, t)!;
      g2 = Color.lerp(cYellow2, cGreen2, t)!;
      g3 = Color.lerp(cYellow3, cGreen3, t)!;
      shadow = g1;
    } else {
      g1 = cGreen1;
      g2 = cGreen2;
      g3 = cGreen3;
      shadow = cGreen1;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [g1, g2, g3],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: shadow.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -14,
            start: -4,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 92,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          PositionedDirectional(
            bottom: -18,
            end: -4,
            child: Icon(
              Icons.auto_graph_rounded,
              size: 82,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الباقي من الدخل الشهري',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.96),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                remainingIncome.toStringAsFixed(2),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _HeroMiniStat(
                      label: 'الدخل',
                      value: totalIncomeActual,
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroMiniStat(
                      label: 'المصروف',
                      value: totalExpenseActual,
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  const _HeroMiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetTrackingSetupPromptCard extends StatelessWidget {
  const BudgetTrackingSetupPromptCard({
    super.key,
    required this.futureMonth,
    required this.isDisabled,
    required this.onTap,
  });

  final bool futureMonth;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFD8F3E5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 42,
              color: Color(0xFF0F9D7A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            futureMonth
                ? 'خطط لهذا الشهر بشكل مسبق'
                : 'ابدأ إعداد الميزانية الشهرية',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            futureMonth
                ? 'هذا الشهر لم يبدأ بعد. يمكنك تجهيز خطته الآن، لكنها لن تتحول إلى عرض الميزانية والمعاملات إلا عندما يبدأ الشهر فعليًا.'
                : 'أضف أي عنصر في الخطة مثل دخل أو مخصص أو حصالة أو التزام، وبعدها ستظهر لك شاشة متابعة الميزانية هنا.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: isDisabled ? null : onTap,
            icon: const Icon(Icons.tune_rounded),
            label: Text(
              futureMonth
                  ? 'إعداد هذا الشهر مسبقًا'
                  : 'إعداد الميزانية الشهرية',
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetTrackingSectionTitle extends StatelessWidget {
  const BudgetTrackingSectionTitle({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF165B47);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: accent.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetTrackingSectionEmptyCard extends StatelessWidget {
  const BudgetTrackingSectionEmptyCard({
    super.key,
    required this.text,
    this.onTap,
  });

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.open_in_new_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
