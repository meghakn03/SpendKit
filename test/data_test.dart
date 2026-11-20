import 'package:flutter_test/flutter_test.dart';
import 'package:spendkit/src/data.dart';

void main() {
  final items = [
    Transaction(
      'Figma',
      SpendCategory.software,
      DateTime(2026, 11, 20, 16),
      7200,
    ),
    Transaction('Figma', SpendCategory.software, DateTime(2025, 11, 20), 5500),
    Transaction(
      'National Rail',
      SpendCategory.travel,
      DateTime(2026, 11, 19),
      12450,
    ),
  ];

  test('combines case-insensitive merchant, category and inclusive dates', () {
    final result = filterTransactions(
      items,
      merchant: ' FIG ',
      category: SpendCategory.software,
      start: DateTime(2026, 11, 20),
      end: DateTime(2026, 11, 20),
    );
    expect(result, [items.first]);
  });

  test('monthly totals match both month and year', () {
    final totals = spendingByCategory(items, DateTime(2026, 11));
    expect(totals[SpendCategory.software], 7200);
    expect(totals[SpendCategory.travel], 12450);
    expect(totals[SpendCategory.food], 0);
  });

  test('formats pounds without floating-point rounding', () {
    expect(pounds(-842560), '−£8,425.60');
    expect(pounds(1), '£0.01');
  });
}
