import 'package:flutter/material.dart';

class BudgetTrackingOverviewContent extends StatelessWidget {
  const BudgetTrackingOverviewContent({
    super.key,
    required this.monthBar,
    required this.heroSummaryCard,
    required this.pastMonthSummaryCard,
    required this.showSetupPromptOnly,
    required this.budgetSetupPromptCard,
    required this.incomeSectionTitle,
    required this.incomeSectionCard,
    required this.allocationsSectionTitle,
    required this.allocationTiles,
    required this.jarsSectionTitle,
    required this.jarTiles,
    required this.debtsSectionTitle,
    required this.debtCards,
    required this.subscriptionsSectionTitle,
    required this.subscriptionCards,
    required this.cycleSummarySectionTitle,
    required this.cycleSummaryCard,
    required this.showBudgetSetupButton,
    required this.budgetSetupButtonIcon,
    required this.budgetSetupButtonLabel,
    required this.onOpenBudgetSetupScreen,
  });

  final Widget monthBar;
  final Widget heroSummaryCard;
  final Widget? pastMonthSummaryCard;
  final bool showSetupPromptOnly;
  final Widget budgetSetupPromptCard;
  final Widget incomeSectionTitle;
  final Widget incomeSectionCard;
  final Widget allocationsSectionTitle;
  final List<Widget> allocationTiles;
  final Widget jarsSectionTitle;
  final List<Widget> jarTiles;
  final Widget debtsSectionTitle;
  final List<Widget> debtCards;
  final Widget subscriptionsSectionTitle;
  final List<Widget> subscriptionCards;
  final Widget cycleSummarySectionTitle;
  final Widget cycleSummaryCard;
  final bool showBudgetSetupButton;
  final IconData budgetSetupButtonIcon;
  final String budgetSetupButtonLabel;
  final VoidCallback onOpenBudgetSetupScreen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        monthBar,
        const SizedBox(height: 12),
        heroSummaryCard,
        if (pastMonthSummaryCard != null) ...[
          const SizedBox(height: 14),
          pastMonthSummaryCard!,
        ],
        if (showSetupPromptOnly) ...[
          const SizedBox(height: 18),
          budgetSetupPromptCard,
        ] else ...[
          const SizedBox(height: 18),
          incomeSectionTitle,
          const SizedBox(height: 12),
          incomeSectionCard,
          const SizedBox(height: 18),
          allocationsSectionTitle,
          const SizedBox(height: 12),
          ...allocationTiles,
          const SizedBox(height: 18),
          jarsSectionTitle,
          const SizedBox(height: 12),
          ...jarTiles,
          const SizedBox(height: 18),
          debtsSectionTitle,
          const SizedBox(height: 12),
          ...debtCards,
          const SizedBox(height: 18),
          subscriptionsSectionTitle,
          const SizedBox(height: 12),
          ...subscriptionCards,
          const SizedBox(height: 18),
          cycleSummarySectionTitle,
          const SizedBox(height: 12),
          cycleSummaryCard,
          if (showBudgetSetupButton) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpenBudgetSetupScreen,
              icon: Icon(budgetSetupButtonIcon),
              label: Text(budgetSetupButtonLabel),
            ),
          ],
        ],
      ],
    );
  }
}
