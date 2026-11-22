import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

import '../data.dart';

class CreditCardSummary extends StatelessWidget {
  const CreditCardSummary({
    super.key,
    required this.available,
    required this.limit,
    required this.frozen,
    this.onManage,
  });
  final int available;
  final int limit;
  final bool frozen;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const RadialGradient(
        colors: [Color(0xFF378266), Color(0xFF163D31), Color(0xFF102B23)],
        stops: [0, 0.60, 1],
        center: Alignment(0.95, -1.1),
        radius: 1.65,
      ),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.credit_card, color: SpendColors.mint),
              const Text(
                'Business credit  ••  4821',
                style: TextStyle(color: Colors.white),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: SpendColors.mint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Text(
                    frozen ? 'Frozen' : 'Active',
                    style: const TextStyle(
                      color: SpendColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text('Available credit', style: TextStyle(color: Colors.white)),
          Text(
            pounds(available),
            style: Theme.of(context).textTheme.displaySmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (limit - available) / limit,
              minHeight: 7,
              color: SpendColors.mint,
              backgroundColor: const Color(0xFF527868),
              semanticsLabel: 'Credit limit used',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${pounds(limit - available)} used of ${pounds(limit)}',
            style: const TextStyle(color: Colors.white),
          ),
          if (onManage case final manage?) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: manage,
              child: const Text('Manage card'),
            ),
          ],
        ],
      ),
    ),
  );
}

class TransactionData extends StatelessWidget {
  const TransactionData({
    super.key,
    required this.items,
    required this.onRetry,
    required this.builder,
  });
  final AsyncValue<List<Transaction>> items;
  final VoidCallback onRetry;
  final Widget Function(List<Transaction>) builder;

  @override
  Widget build(BuildContext context) => items.when(
    data: builder,
    loading: () => const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading transactions',
        ),
      ),
    ),
    error: (_, _) => SpendPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SpendNotice(
            message: 'Transactions could not be loaded.',
            error: true,
          ),
          const SizedBox(height: 12),
          SpendButton(label: 'Try again', onPressed: onRetry),
        ],
      ),
    ),
  );
}

IconData categoryIcon(SpendCategory category) => switch (category) {
  SpendCategory.software => Icons.widgets_outlined,
  SpendCategory.travel => Icons.train_outlined,
  SpendCategory.food => Icons.local_cafe_outlined,
  SpendCategory.operations => Icons.inventory_2_outlined,
};

class TransactionRow extends StatelessWidget {
  const TransactionRow(this.item, {super.key});
  final Transaction item;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.merchant, style: style.textTheme.titleSmall),
        Text(
          '${item.category.label} · ${shortDate(item.date)} ${item.date.year}',
          style: style.textTheme.bodySmall,
        ),
        Text(pounds(-item.pence), style: style.textTheme.titleSmall),
      ],
    );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: style.colorScheme.secondaryContainer,
              foregroundColor: style.colorScheme.onSecondaryContainer,
              child: Icon(categoryIcon(item.category), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: details),
          ],
        ),
      ),
    );
  }
}
