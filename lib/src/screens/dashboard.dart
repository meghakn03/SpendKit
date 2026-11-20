import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

import '../core.dart';
import '../data.dart';
import 'bank_widgets.dart';
import 'screen_body.dart';
import 'spending_panel.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final items = ref.watch(transactionsProvider);
    return ScreenBody(
      children: [
        const SpendHeading(
          'Business overview',
          subtitle: 'Studio North Ltd · Business credit account',
        ),
        CreditCardSummary(
          available: repo.availablePence,
          limit: repo.limitPence,
          frozen: ref.watch(sessionProvider).frozen,
          onManage: () => context.go('/card'),
        ),
        TransactionData(
          items: items,
          onRetry: () => ref.invalidate(transactionsProvider),
          builder: (transactions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SpendingPanel(transactions: transactions, today: repo.today),
                const SizedBox(height: 16),
                SpendPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SpendHeading('Recent activity'),
                      for (final transaction in filterTransactions(
                        transactions,
                      ).take(4))
                        TransactionRow(transaction),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SpendButton(
                          label: 'View all activity',
                          icon: Icons.arrow_forward,
                          onPressed: () => context.go('/activity'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
