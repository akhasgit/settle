import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/expense_service.dart';
import '../widgets/set_budget_bottom_sheet.dart';
import 'expense_list_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _expenseService = ExpenseService();
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
  }

  void _openExpenseList(String period) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseListScreen(period: period, uid: _uid),
      ),
    );
  }

  void _openSetBudgetSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SetBudgetBottomSheet(uid: _uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _expenseService.expenseSummaryStream(_uid),
      builder: (context, snapshot) {
        final summary = snapshot.data ?? {};
        final todayTotal =
            ((summary['todayTotal'] ?? 0) as num).toDouble();
        final todayEntryCount =
            ((summary['todayEntryCount'] ?? 0) as num).toInt();
        final weekTotal =
            ((summary['weekTotal'] ?? 0) as num).toDouble();
        final weekDaysLogged =
            List<bool>.from(summary['weekDaysLogged'] ?? List.filled(7, false));
        final monthTotal =
            ((summary['monthTotal'] ?? 0) as num).toDouble();
        final monthDaysLogged = List<bool>.from(
            summary['monthDaysLogged'] ??
                List.filled(
                    DateTime(DateTime.now().year, DateTime.now().month + 1, 0)
                        .day,
                    false));
        final dailyBudget = summary['dailyBudget'] as double?;
        final weeklyBudget = summary['weeklyBudget'] as double?;
        final monthlyBudget = summary['monthlyBudget'] as double?;
        final hasAllBudgets = (dailyBudget != null && dailyBudget > 0) &&
            (weeklyBudget != null && weeklyBudget > 0) &&
            (monthlyBudget != null && monthlyBudget > 0);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openExpenseList('Today'),
                child: _buildSpendCard(
                  amount: todayTotal,
                  label: 'Today',
                  isPrimary: true,
                  dotWidget: _buildTodayDots(todayEntryCount),
                  budget: dailyBudget,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _openExpenseList('Week'),
                child: _buildSpendCard(
                  amount: weekTotal,
                  label: 'Week',
                  isPrimary: false,
                  dotWidget: _buildWeekDots(weekDaysLogged),
                  budget: weeklyBudget,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _openExpenseList('Month'),
                child: _buildSpendCard(
                  amount: monthTotal,
                  label: 'Month',
                  isPrimary: false,
                  dotWidget: _buildMonthDots(monthDaysLogged),
                  budget: monthlyBudget,
                ),
              ),
              if (!hasAllBudgets) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _openSetBudgetSheet,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF424242)),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Add budget',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF424242),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpendCard({
    required double amount,
    required String label,
    required bool isPrimary,
    required Widget dotWidget,
    double? budget,
  }) {
    final displayAmount = amount == amount.truncateToDouble()
        ? '\$${amount.toInt()}'
        : '\$${amount.toStringAsFixed(2)}';
    final displayBudget = (budget != null && budget > 0)
        ? (budget == budget.truncateToDouble()
            ? '\$${budget.toInt()}'
            : '\$${budget.toStringAsFixed(2)}')
        : null;
    final amountFontSize = isPrimary ? 48.0 : (label == 'Week' ? 36.0 : 32.0);
    final amountColor = isPrimary
        ? Colors.black
        : (label == 'Week' ? const Color(0xFF424242) : const Color(0xFF757575));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    displayAmount,
                    style: TextStyle(
                      fontSize: amountFontSize,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                  if (displayBudget != null) ...[
                    Text(
                      ' / $displayBudget',
                      style: TextStyle(
                        fontSize: amountFontSize * 0.6,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          dotWidget,
        ],
      ),
    );
  }

  Widget _buildTodayDots(int entryCount) {
    if (entryCount <= 0) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        entryCount,
        (index) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF424242),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekDots(List<bool> daysLogged) {
    final today = DateTime.now();
    final dayOfWeek = today.weekday; // 1=Mon .. 7=Sun
    return Row(
      children: List.generate(dayOfWeek, (index) {
        final isFilled = index < daysLogged.length && daysLogged[index];
        return Container(
          width: 8,
          height: 8,
          margin: EdgeInsets.only(right: index < dayOfWeek - 1 ? 8 : 0),
          decoration: BoxDecoration(
            color: isFilled ? const Color(0xFF424242) : Colors.transparent,
            border: isFilled
                ? null
                : Border.all(color: const Color(0xFF424242), width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildMonthDots(List<bool> daysLogged) {
    final today = DateTime.now();
    final dayOfMonth = today.day;
    final dotsPerRow = 14;
    final totalRows = (dayOfMonth / dotsPerRow).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(totalRows, (rowIndex) {
        final rowStart = rowIndex * dotsPerRow;
        final rowEnd = (rowStart + dotsPerRow).clamp(0, dayOfMonth);
        final dotsInRow = rowEnd - rowStart;

        return Padding(
          padding: EdgeInsets.only(bottom: rowIndex < totalRows - 1 ? 8 : 0),
          child: Row(
            children: List.generate(dotsInRow, (dotIndex) {
              final dayIndex = rowStart + dotIndex;
              final isFilled =
                  dayIndex < daysLogged.length && daysLogged[dayIndex];
              return Container(
                width: 8,
                height: 8,
                margin:
                    EdgeInsets.only(right: dotIndex < dotsInRow - 1 ? 8 : 0),
                decoration: BoxDecoration(
                  color: isFilled
                      ? const Color(0xFF424242)
                      : Colors.transparent,
                  border: isFilled
                      ? null
                      : Border.all(
                          color: const Color(0xFF424242), width: 1.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
