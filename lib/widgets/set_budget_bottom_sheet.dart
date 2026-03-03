import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_service.dart';

class SetBudgetBottomSheet extends StatefulWidget {
  final String uid;
  final double? initialDailyBudget;
  final double? initialWeeklyBudget;
  final double? initialMonthlyBudget;

  const SetBudgetBottomSheet({
    super.key,
    required this.uid,
    this.initialDailyBudget,
    this.initialWeeklyBudget,
    this.initialMonthlyBudget,
  });

  @override
  State<SetBudgetBottomSheet> createState() => _SetBudgetBottomSheetState();
}

class _SetBudgetBottomSheetState extends State<SetBudgetBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dailyController = TextEditingController();
  final _weeklyController = TextEditingController();
  final _monthlyController = TextEditingController();
  final _userService = UserService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDailyBudget != null && widget.initialDailyBudget! > 0) {
      _dailyController.text = _formatBudget(widget.initialDailyBudget!);
    }
    if (widget.initialWeeklyBudget != null && widget.initialWeeklyBudget! > 0) {
      _weeklyController.text = _formatBudget(widget.initialWeeklyBudget!);
    }
    if (widget.initialMonthlyBudget != null && widget.initialMonthlyBudget! > 0) {
      _monthlyController.text = _formatBudget(widget.initialMonthlyBudget!);
    }
  }

  String _formatBudget(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _weeklyController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }

  double? _parseBudget(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    return parsed;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final daily = _parseBudget(_dailyController.text);
    final weekly = _parseBudget(_weeklyController.text);
    final monthly = _parseBudget(_monthlyController.text);

    if (daily == null && weekly == null && monthly == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter at least one budget amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _userService.updateBudgets(
        uid: widget.uid,
        dailyBudget: daily,
        weeklyBudget: weekly,
        monthlyBudget: monthly,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final topPadding = mediaQuery.padding.top;
    final baseHeight = screenHeight * 0.58;
    final bottomSheetHeight = keyboardHeight > 0
        ? screenHeight - keyboardHeight - topPadding - 80
        : baseHeight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: bottomSheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Set your budgets',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  color: Colors.black,
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBudgetField(
                        label: 'Daily budget',
                        controller: _dailyController,
                        hint: 'e.g. 50',
                      ),
                      const SizedBox(height: 20),
                      _buildBudgetField(
                        label: 'Weekly budget',
                        controller: _weeklyController,
                        hint: 'e.g. 350',
                      ),
                      const SizedBox(height: 20),
                      _buildBudgetField(
                        label: 'Monthly budget',
                        controller: _monthlyController,
                        hint: 'e.g. 1500',
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Save budgets',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: '\$ ',
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: const TextStyle(fontSize: 16),
          validator: (value) {
            final parsed = _parseBudget(value ?? '');
            if (value != null && value.trim().isNotEmpty && parsed != null && parsed < 0) {
              return 'Amount must be 0 or greater';
            }
            return null;
          },
        ),
      ],
    );
  }
}
