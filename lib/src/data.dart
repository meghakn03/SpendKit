enum SpendCategory {
  software('Software'),
  travel('Travel'),
  food('Food & drink'),
  operations('Operations');

  const SpendCategory(this.label);
  final String label;
}

class Transaction {
  const Transaction(this.merchant, this.category, this.date, this.pence);
  final String merchant;
  final SpendCategory category;
  final DateTime date;
  final int pence;
}

String pounds(int pence) {
  final whole = (pence.abs() ~/ 100).toString();
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final pennies = (pence.abs() % 100).toString().padLeft(2, '0');
  return '${pence < 0 ? '−' : ''}£$grouped.$pennies';
}

int? parsePounds(String? value) {
  final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,2}))?$')
      .firstMatch(value?.trim() ?? '');
  if (match == null) return null;
  return int.parse(match[1]!) * 100 +
      int.parse((match[2] ?? '').padRight(2, '0'));
}

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String shortDate(DateTime date) =>
    '${date.day} ${monthNames[date.month - 1].substring(0, 3)}';

bool sameMonth(DateTime date, DateTime other) =>
    date.year == other.year && date.month == other.month;

List<Transaction> filterTransactions(
  Iterable<Transaction> transactions, {
  String merchant = '',
  SpendCategory? category,
  DateTime? start,
  DateTime? end,
}) {
  final query = merchant.trim().toLowerCase();
  return transactions.where((item) {
    final day = DateTime(item.date.year, item.date.month, item.date.day);
    return item.merchant.toLowerCase().contains(query) &&
        (category == null || item.category == category) &&
        (start == null ||
            !day.isBefore(DateTime(start.year, start.month, start.day))) &&
        (end == null || !day.isAfter(DateTime(end.year, end.month, end.day)));
  }).toList()..sort((a, b) => b.date.compareTo(a.date));
}

Map<SpendCategory, int> spendingByCategory(
  Iterable<Transaction> items,
  DateTime month,
) {
  final totals = {for (final category in SpendCategory.values) category: 0};
  for (final item in items.where((item) => sameMonth(item.date, month))) {
    totals.update(item.category, (total) => total + item.pence);
  }
  return totals;
}
