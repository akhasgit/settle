import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/savings_service.dart';
import 'settle_agent_service.dart';

SettleAgentService createSettleAgent({
  required ExpenseService expenseService,
  required SavingsService savingsService,
  required String uid,
  required String userName,
  required String username,
  required String defaultCurrency,
  Map<String, double>? budgets,
}) {
  return SettleAgentService(
    uid: uid,
    userName: userName,
    username: username,
    defaultCurrency: defaultCurrency.toUpperCase(),
    budgets: budgets,

    onAddExpense: (input) async {
      final expense = Expense(
        id: '',
        amount: (input['amount'] as num).toDouble(),
        name: input['name'] as String,
        tag: input['tag'] as String,
        currency: (input['currency'] as String?) ?? 'SGD',
        date: DateTime.parse(input['date'] as String),
        createdAt: DateTime.now(),
        splitWith: List<String>.from(input['splitWith'] ?? []),
        splitMode: (input['splitMode'] as String?) ?? 'equal',
        customAmounts: Map<String, double>.from(
          (input['customAmounts'] as Map?)?.map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()),
              ) ??
              {},
        ),
        omittedUsernames: List<String>.from(input['omittedUsernames'] ?? []),
      );
      await expenseService.addExpense(uid, expense);
    },

    onAddSavings: (goalName, amount, currency) async {
      await savingsService.addContributionByName(uid, goalName, amount);
    },

    onGetSummary: (period, {start, end, groupBy}) async {
      final dates = _periodToDates(period, start, end);
      final expenses = await expenseService.getExpensesBetween(
          uid, dates.$1, dates.$2);

      final grouped = groupBy == 'tag'
          ? _groupByTag(expenses)
          : groupBy == 'day'
              ? _groupByDay(expenses)
              : {'expenses': expenses.map((e) => e.toJson()).toList()};

      return {
        'period': period,
        'totalSpent': expenses.fold(0.0, (sum, e) => sum + e.amount),
        'expenseCount': expenses.length,
        'breakdown': grouped,
        'currency': defaultCurrency.toUpperCase(),
      };
    },
  );
}

(DateTime, DateTime) _periodToDates(
    String period, String? start, String? end) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (period) {
    case 'today':
      return (today, today.add(const Duration(days: 1)));

    case 'week':
      final monday =
          today.subtract(Duration(days: today.weekday - 1));
      return (monday, monday.add(const Duration(days: 7)));

    case 'month':
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfNext = DateTime(now.year, now.month + 1, 1);
      return (startOfMonth, startOfNext);

    case 'last_month':
      final startOfLast = DateTime(now.year, now.month - 1, 1);
      final startOfThis = DateTime(now.year, now.month, 1);
      return (startOfLast, startOfThis);

    case 'custom':
      return (
        DateTime.parse(start ?? today.toIso8601String()),
        DateTime.parse(end ?? today.add(const Duration(days: 1)).toIso8601String()),
      );

    default:
      return (today, today.add(const Duration(days: 1)));
  }
}

Map<String, dynamic> _groupByTag(List<Expense> expenses) {
  final result = <String, double>{};
  for (final e in expenses) {
    final tag = e.tag ?? 'Other';
    result[tag] = (result[tag] ?? 0) + e.amount;
  }
  return result;
}

Map<String, dynamic> _groupByDay(List<Expense> expenses) {
  final result = <String, double>{};
  for (final e in expenses) {
    final day = DateFormat('yyyy-MM-dd').format(e.date);
    result[day] = (result[day] ?? 0) + e.amount;
  }
  return result;
}
