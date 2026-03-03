import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';

class _PeriodData {
  final List<Expense> current;
  final List<Expense> previous;
  _PeriodData(this.current, this.previous);
}

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  AnalyticsTabState createState() => AnalyticsTabState();
}

class AnalyticsTabState extends State<AnalyticsTab>
    with TickerProviderStateMixin {
  static bool _hasAnimatedThisSession = false;

  final _expenseService = ExpenseService();
  late final String _uid;
  final _searchController = TextEditingController();

  String _selectedPeriod = 'Month';
  final Map<String, _PeriodData> _cache = {};
  final Map<String, bool> _loadingPeriod = {'Week': false, 'Month': false};

  late AnimationController _animController;
  late Animation<double> _anim;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;
  late PageController _pageController;

  static const _tagColors = <String, Color>{
    'Food': Color(0xFF43A047),
    'Transport': Color(0xFF1E88E5),
    'Shopping': Color(0xFFE53935),
    'Entertainment': Color(0xFF8E24AA),
    'Bills': Color(0xFFEF6C00),
    'Health': Color(0xFF00ACC1),
    'Travel': Color(0xFF6D4C41),
    'Other': Color(0xFF546E7A),
  };

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _pageController = PageController(initialPage: 1); // 0 = Week, 1 = Month
    _loadPeriod(_selectedPeriod);
  }

  @override
  void dispose() {
    _animController.dispose();
    _shimmerController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Called externally (e.g. after adding an expense) to invalidate cached data.
  void invalidateCache() {
    _cache.clear();
    _loadPeriod(_selectedPeriod);
  }

  Future<void> _loadPeriod(String period) async {
    if (_cache.containsKey(period)) return;

    setState(() => _loadingPeriod[period] = true);
    try {
      final List<Expense> current;
      final List<Expense> previous;

      if (period == 'Month') {
        current = await _expenseService.getMonthExpenses(_uid);
        previous = await _expenseService.getLastMonthExpenses(_uid);
      } else {
        current = await _expenseService.getWeekExpenses(_uid);
        previous = await _expenseService.getLastWeekExpenses(_uid);
      }

      if (!mounted) return;
      _cache[period] = _PeriodData(current, previous);
      setState(() => _loadingPeriod[period] = false);

      if (!_hasAnimatedThisSession) {
        _hasAnimatedThisSession = true;
        _animController.forward();
      } else {
        _animController.value = 1.0;
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() => _loadingPeriod[period] = false);
        _animController.value = 1.0;
      }
    }
  }

  List<Expense> _currentExpensesFor(String period) =>
      _cache[period]?.current ?? [];

  List<Expense> _previousExpensesFor(String period) =>
      _cache[period]?.previous ?? [];

  bool _isPeriodLoading(String period) =>
      _loadingPeriod[period] ?? false;

  // ─── Aggregation ─────────────────────────────────────────────

  double _total(List<Expense> expenses) =>
      expenses.fold(0.0, (sum, e) => sum + e.amount);

  int _activeDays(List<Expense> expenses) {
    return expenses
        .map((e) => DateFormat('yyyy-MM-dd').format(e.date))
        .toSet()
        .length;
  }

  int _elapsedDaysFor(String period) {
    if (period == 'Week') return DateTime.now().weekday;
    return DateTime.now().day;
  }

  int _totalDaysInPeriodFor(String period) {
    if (period == 'Week') return 7;
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0).day;
  }

  Map<String, double> _spendByTag(List<Expense> expenses) {
    final result = <String, double>{};
    for (final e in expenses) {
      final tag = e.tag ?? 'Other';
      result[tag] = (result[tag] ?? 0) + e.amount;
    }
    final sorted = result.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  List<double> _spendByDayOfWeek(List<Expense> expenses) {
    final result = List.filled(7, 0.0);
    for (final e in expenses) {
      result[e.date.weekday - 1] += e.amount;
    }
    return result;
  }

  List<Expense> _topExpenses(List<Expense> expenses, int n) {
    final sorted = List<Expense>.from(expenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return sorted.take(n).toList();
  }

  Map<String, Map<String, dynamic>> _splitSummary(List<Expense> expenses) {
    final result = <String, Map<String, dynamic>>{};
    for (final e in expenses) {
      for (final u in e.splitWith) {
        result.putIfAbsent(u, () => {'count': 0, 'total': 0.0});
        result[u]!['count'] = (result[u]!['count'] as int) + 1;
        result[u]!['total'] = (result[u]!['total'] as double) + e.amount;
      }
    }
    return result;
  }

  double _percentChange(double current, double previous) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  // ─── Helpers ─────────────────────────────────────────────────

  Color _getTagColor(String tag) =>
      _tagColors[tag] ?? const Color(0xFF546E7A);

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '\$${NumberFormat('#,##0.00').format(amount)}';
    }
    return '\$${amount.toStringAsFixed(2)}';
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            children: [
              _buildSearchCard(),
              const SizedBox(height: 20),
              _buildPeriodSelector(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              final period = index == 0 ? 'Week' : 'Month';
              if (_selectedPeriod != period) {
                setState(() => _selectedPeriod = period);
                _loadPeriod(period);
              }
            },
            children: [
              _buildPageForPeriod('Week'),
              _buildPageForPeriod('Month'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageForPeriod(String period) {
    if (_isPeriodLoading(period)) {
      return _buildShimmer(period);
    }
    return _buildContentFor(period);
  }

  // ─── Shimmer ─────────────────────────────────────────────────

  Widget _buildShimmer(String period) {
    return AnimatedBuilder(
      key: ValueKey('shimmer_$period'),
      animation: _shimmerAnim,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(_shimmerAnim.value - 1, 0),
              end: Alignment(_shimmerAnim.value + 1, 0),
              colors: const [
                Color(0xFFE8E8E8),
                Color(0xFFF5F5F5),
                Color(0xFFE8E8E8),
              ],
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _shimmerBlock(72)),
                const SizedBox(width: 12),
                Expanded(child: _shimmerBlock(72)),
                const SizedBox(width: 12),
                Expanded(child: _shimmerBlock(72)),
              ],
            ),
            const SizedBox(height: 20),
            _shimmerBlock(200),
            const SizedBox(height: 20),
            _shimmerBlock(80),
            const SizedBox(height: 20),
            _shimmerBlock(180),
            const SizedBox(height: 20),
            _shimmerBlock(160),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBlock(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // ─── Content ─────────────────────────────────────────────────

  Widget _buildContentFor(String period) {
    return AnimatedBuilder(
      key: ValueKey('content_$period'),
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(t, period),
              const SizedBox(height: 20),
              _buildCategoryBreakdown(t, period),
              const SizedBox(height: 20),
              _buildPeriodComparison(t, period),
              const SizedBox(height: 20),
              _buildDayOfWeekChart(t, period),
              const SizedBox(height: 20),
              _buildTopExpenses(t, period),
              if (_splitSummary(_currentExpensesFor(period)).isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSplitSummary(t, period),
              ],
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  // ─── Search Card ─────────────────────────────────────────────

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          icon: Icon(Icons.auto_awesome, color: Colors.grey[400], size: 20),
          hintText: 'Ask about your spending...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
          border: InputBorder.none,
        ),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  // ─── Period Selector ─────────────────────────────────────────

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['Week', 'Month'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedPeriod != period) {
                  final index = period == 'Week' ? 0 : 1;
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                  setState(() => _selectedPeriod = period);
                  _loadPeriod(period);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Summary Cards ───────────────────────────────────────────

  Widget _buildSummaryCards(double t, String period) {
    final expenses = _currentExpensesFor(period);
    final total = _total(expenses) * t;
    final avg = (_elapsedDaysFor(period) > 0
            ? _total(expenses) / _elapsedDaysFor(period)
            : 0.0) *
        t;
    final active = (_activeDays(expenses) * t).round();

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard('Total', _formatAmount(total), t),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard('Avg/Day', _formatAmount(avg), t),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Active',
            '$active/${_totalDaysInPeriodFor(period)} days',
            t,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, double t) {
    return Opacity(
      opacity: t,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Category Breakdown ──────────────────────────────────────

  Widget _buildCategoryBreakdown(double t, String period) {
    final expenses = _currentExpensesFor(period);
    final byTag = _spendByTag(expenses);
    final total = _total(expenses);

    if (byTag.isEmpty) {
      return _buildEmptySection(
        'Spending by Category',
        'Add expenses with tags to see a breakdown',
      );
    }

    final maxAmount = byTag.values.first;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending by Category',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...byTag.entries.map((entry) {
            final pct = total > 0 ? (entry.value / total * 100) : 0.0;
            final fraction = maxAmount > 0 ? entry.value / maxAmount : 0.0;
            return _buildCategoryBar(
              entry.key,
              entry.value,
              pct,
              fraction,
              t,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(
    String tag,
    double amount,
    double pct,
    double fraction,
    double t,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _getTagColor(tag),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Opacity(
                opacity: t,
                child: Text(
                  '${_formatAmount(amount)} · ${pct.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 8,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 8,
                    width: constraints.maxWidth * fraction * t,
                    decoration: BoxDecoration(
                      color: _getTagColor(tag),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Period Comparison ───────────────────────────────────────

  Widget _buildPeriodComparison(double t, String period) {
    final currentTotal = _total(_currentExpensesFor(period));
    final previousTotal = _total(_previousExpensesFor(period));

    if (currentTotal == 0 && previousTotal == 0) {
      return const SizedBox.shrink();
    }

    final change = _percentChange(currentTotal, previousTotal);
    final isUp = change >= 0;
    final periodLabel = period == 'Month' ? 'last month' : 'last week';

    return Opacity(
      opacity: t,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    isUp ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isUp ? Icons.trending_up : Icons.trending_down,
                color: isUp ? Colors.orange : Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isUp ? 'Up' : 'Down'} ${change.abs().toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'compared to $periodLabel',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatAmount(previousTotal),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatAmount(currentTotal * t),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Day of Week Chart ───────────────────────────────────────

  Widget _buildDayOfWeekChart(double t, String period) {
    final dailySpend = _spendByDayOfWeek(_currentExpensesFor(period));
    final maxSpend = dailySpend.reduce(max);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (maxSpend == 0) {
      return _buildEmptySection(
        'Daily Pattern',
        'Log expenses to see your spending pattern by day',
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Pattern',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final fraction =
                    maxSpend > 0 ? dailySpend[i] / maxSpend : 0.0;
                final barHeight = 92.0 * fraction * t;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dailySpend[i] > 0 && t > 0.5)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '\$${dailySpend[i].toInt()}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        Container(
                          height: max(barHeight, fraction > 0 ? 4.0 : 0.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          days[i],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top Expenses ────────────────────────────────────────────

  Widget _buildTopExpenses(double t, String period) {
    final top = _topExpenses(_currentExpensesFor(period), 5);
    if (top.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Expenses',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...top.asMap().entries.map((entry) {
            final i = entry.key;
            final expense = entry.value;
            final itemT = Curves.easeOut.transform(
              (t * 1.4 - i * 0.12).clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: itemT,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - itemT)),
                child: _buildExpenseRow(expense, i + 1),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(Expense expense, int rank) {
    final tag = expense.tag ?? 'Other';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey[400],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.name.isNotEmpty ? expense.name : 'Expense',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('MMM d').format(expense.date)} · $tag',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            _formatAmount(expense.amount),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Split Summary ───────────────────────────────────────────

  Widget _buildSplitSummary(double t, String period) {
    final splits = _splitSummary(_currentExpensesFor(period));
    if (splits.isEmpty) return const SizedBox.shrink();

    final sorted = splits.entries.toList()
      ..sort((a, b) => (b.value['total'] as double)
          .compareTo(a.value['total'] as double));

    return Opacity(
      opacity: t,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Split Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...sorted.map((entry) {
              final username = entry.key;
              final count = entry.value['count'] as int;
              final total = entry.value['total'] as double;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '@',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@$username',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$count expense${count == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatAmount(total * t),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Empty Section ───────────────────────────────────────────

  Widget _buildEmptySection(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                message,
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
