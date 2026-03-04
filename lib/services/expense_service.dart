import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _expensesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('expenses');

  DocumentReference _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Add expense and update summary atomically
  Future<void> addExpense(String uid, Expense expense) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(_userRef(uid));
        final userData = userDoc.data() as Map<String, dynamic>? ?? {};
        final summary =
            Map<String, dynamic>.from(userData['expenseSummary'] ?? {});

        final expenseDate = expense.date;
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final expenseDateStr = DateFormat('yyyy-MM-dd').format(expenseDate);
        final currentMonthStr = DateFormat('yyyy-MM').format(now);
        final currentWeekMonday = _getMonday(now);
        final weekMondayStr =
            DateFormat('yyyy-MM-dd').format(currentWeekMonday);

        // --- Today ---
        if (expenseDateStr == todayStr) {
          if (summary['todayDate'] == todayStr) {
            summary['todayTotal'] =
                ((summary['todayTotal'] ?? 0) as num).toDouble() +
                    expense.amount;
            summary['todayEntryCount'] =
                ((summary['todayEntryCount'] ?? 0) as num).toInt() + 1;
          } else {
            summary['todayDate'] = todayStr;
            summary['todayTotal'] = expense.amount;
            summary['todayEntryCount'] = 1;
          }
        }

        // --- Week ---
        final expenseWeekMonday = _getMonday(expenseDate);
        final expenseWeekMondayStr =
            DateFormat('yyyy-MM-dd').format(expenseWeekMonday);
        if (expenseWeekMondayStr == weekMondayStr) {
          if (summary['weekStartDate'] != weekMondayStr) {
            summary['weekStartDate'] = weekMondayStr;
            summary['weekTotal'] = 0.0;
            summary['weekDaysLogged'] = List.filled(7, false);
          }
          summary['weekTotal'] =
              ((summary['weekTotal'] ?? 0) as num).toDouble() + expense.amount;
          final dayIndex = expenseDate.weekday - 1;
          final weekDays = List<bool>.from(
              summary['weekDaysLogged'] ?? List.filled(7, false));
          weekDays[dayIndex] = true;
          summary['weekDaysLogged'] = weekDays;
        }

        // --- Month ---
        final expenseMonthStr = DateFormat('yyyy-MM').format(expenseDate);
        if (expenseMonthStr == currentMonthStr) {
          if (summary['monthYear'] != currentMonthStr) {
            final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
            summary['monthYear'] = currentMonthStr;
            summary['monthTotal'] = 0.0;
            summary['monthDaysLogged'] = List.filled(daysInMonth, false);
          }
          summary['monthTotal'] =
              ((summary['monthTotal'] ?? 0) as num).toDouble() +
                  expense.amount;
          final monthDays =
              List<bool>.from(summary['monthDaysLogged'] ?? []);
          if (expenseDate.day - 1 < monthDays.length) {
            monthDays[expenseDate.day - 1] = true;
          }
          summary['monthDaysLogged'] = monthDays;
        }

        final newExpenseRef = _expensesRef(uid).doc();
        transaction.set(newExpenseRef, expense.toFirestore());
        transaction.set(
            _userRef(uid), {'expenseSummary': summary}, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('Error adding expense: $e');
      rethrow;
    }
  }

  /// Normalize summary for current date, resetting stale periods
  Map<String, dynamic> _normalizeSummary(Map<String, dynamic> raw) {
    final summary = Map<String, dynamic>.from(raw);
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final currentMonthStr = DateFormat('yyyy-MM').format(now);
    final currentWeekMonday = _getMonday(now);
    final weekMondayStr = DateFormat('yyyy-MM-dd').format(currentWeekMonday);

    if (summary['todayDate'] != todayStr) {
      summary['todayTotal'] = 0.0;
      summary['todayEntryCount'] = 0;
    }
    if (summary['weekStartDate'] != weekMondayStr) {
      summary['weekTotal'] = 0.0;
      summary['weekDaysLogged'] = List.filled(7, false);
    }
    if (summary['monthYear'] != currentMonthStr) {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      summary['monthTotal'] = 0.0;
      summary['monthDaysLogged'] = List.filled(daysInMonth, false);
    }

    return summary;
  }

  /// Stream the expense summary with real-time updates (includes budget fields from user doc)
  Stream<Map<String, dynamic>> expenseSummaryStream(String uid) {
    return _userRef(uid).snapshots().map((doc) {
      final userData = doc.data() as Map<String, dynamic>? ?? {};
      final raw =
          Map<String, dynamic>.from(userData['expenseSummary'] ?? {});
      final summary = _normalizeSummary(raw);
      // Include budget fields from user profile
      final daily = userData['dailyBudget'];
      final weekly = userData['weeklyBudget'];
      final monthly = userData['monthlyBudget'];
      summary['dailyBudget'] = daily is num ? daily.toDouble() : null;
      summary['weeklyBudget'] = weekly is num ? weekly.toDouble() : null;
      summary['monthlyBudget'] = monthly is num ? monthly.toDouble() : null;
      return summary;
    });
  }

  /// One-shot fetch of expense summary
  Future<Map<String, dynamic>> getExpenseSummary(String uid) async {
    final userDoc = await _userRef(uid).get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final raw =
        Map<String, dynamic>.from(userData['expenseSummary'] ?? {});
    return _normalizeSummary(raw);
  }

  /// Query expenses for today
  Future<List<Expense>> getTodayExpenses(String uid) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _expensesRef(uid)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
  }

  /// Query expenses for current week (Monday to Sunday)
  Future<List<Expense>> getWeekExpenses(String uid) async {
    final monday = _getMonday(DateTime.now());
    final nextMonday = monday.add(const Duration(days: 7));

    final snapshot = await _expensesRef(uid)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monday))
        .where('date', isLessThan: Timestamp.fromDate(nextMonday))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
  }

  /// Query expenses for current month (1st to end)
  Future<List<Expense>> getMonthExpenses(String uid) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

    final snapshot = await _expensesRef(uid)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThan: Timestamp.fromDate(startOfNextMonth))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
  }

  /// Query expenses for last month
  Future<List<Expense>> getLastMonthExpenses(String uid) async {
    final now = DateTime.now();
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final startOfThisMonth = DateTime(now.year, now.month, 1);

    final snapshot = await _expensesRef(uid)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfLastMonth))
        .where('date', isLessThan: Timestamp.fromDate(startOfThisMonth))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
  }

  /// Query expenses for last week (previous Monday to Sunday)
  Future<List<Expense>> getLastWeekExpenses(String uid) async {
    final monday = _getMonday(DateTime.now());
    final lastMonday = monday.subtract(const Duration(days: 7));

    final snapshot = await _expensesRef(uid)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(lastMonday))
        .where('date', isLessThan: Timestamp.fromDate(monday))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
  }

  /// Query expenses between two arbitrary dates
  Future<List<Expense>> getExpensesBetween(
      String uid, DateTime start, DateTime end) async {
    final snapshot = await _expensesRef(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
  }

  DateTime _getMonday(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }
}
