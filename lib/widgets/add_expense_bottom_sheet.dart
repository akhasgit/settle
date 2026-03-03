import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import 'currency_selection_bottom_sheet.dart';

class AddExpenseBottomSheet extends StatefulWidget {
  final String uid;

  const AddExpenseBottomSheet({super.key, required this.uid});

  @override
  State<AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<AddExpenseBottomSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _tagFocusNode = FocusNode();
  final GlobalKey _amountKey = GlobalKey();
  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _tagKey = GlobalKey();
  final ExpenseService _expenseService = ExpenseService();
  bool _isSaving = false;
  
  DateTime _selectedDate = DateTime.now();
  String? _selectedTag;
  Currency _selectedCurrency = Currency.currencies.firstWhere(
    (c) => c.code == 'SGD',
    orElse: () => Currency.currencies.first,
  );
  final List<String> _defaultTags = [
    'Food',
    'Transport',
    'Shopping',
    'Entertainment',
    'Bills',
    'Health',
    'Travel',
    'Other',
  ];
  final List<String> _customTags = [];
  bool _isAddingNewTag = false;
  
  // Username section
  final TextEditingController _usernameController = TextEditingController();
  final List<String> _selectedUsernames = [];
  
  // Split section
  String _splitMode = 'equal'; // 'equal', 'custom', 'omit'
  Map<String, double> _customAmounts = {}; // username -> amount
  List<String> _omittedUsernames = [];

  @override
  void initState() {
    super.initState();
    _amountFocusNode.addListener(_onFocusChange);
    _nameFocusNode.addListener(_onFocusChange);
    _tagFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_amountFocusNode.hasFocus) {
      _scrollToField(_amountKey);
    } else if (_nameFocusNode.hasFocus) {
      _scrollToField(_nameKey);
    } else if (_tagFocusNode.hasFocus) {
      _scrollToField(_tagKey);
    }
  }

  void _scrollToField(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1, // Position field 10% from top of visible area
        );
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _tagController.dispose();
    _usernameController.dispose();
    _scrollController.dispose();
    _amountFocusNode.dispose();
    _nameFocusNode.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }
  
  void _addUsername(String username) {
    final trimmed = username.trim().toLowerCase();
    if (trimmed.isNotEmpty && 
        !trimmed.contains(' ') && 
        !_selectedUsernames.contains(trimmed)) {
      setState(() {
        _selectedUsernames.add(trimmed);
        // Initialize custom amounts if in custom mode
        if (_splitMode == 'custom') {
          _customAmounts[trimmed] = 0.0;
        }
      });
    }
  }
  
  void _processUsernameInput(String value) {
    // Split by spaces and add each non-empty part as a username
    final parts = value.split(' ');
    if (parts.length > 1) {
      // Add all parts except the last one (which is still being typed or empty)
      for (int i = 0; i < parts.length - 1; i++) {
        final part = parts[i].trim();
        if (part.isNotEmpty) {
          _addUsername(part);
        }
      }
      // Keep only the last part in the controller (or empty if it was just a space)
      final lastPart = parts.last;
      _usernameController.value = TextEditingValue(
        text: lastPart,
        selection: TextSelection.collapsed(offset: lastPart.length),
      );
    }
  }
  
  void _removeUsername(String username) {
    setState(() {
      _selectedUsernames.remove(username);
      _customAmounts.remove(username);
      _omittedUsernames.remove(username);
    });
  }
  
  void _updateCustomAmount(String username, String value) {
    setState(() {
      final amount = double.tryParse(value) ?? 0.0;
      _customAmounts[username] = amount;
    });
  }
  
  void _toggleOmitUsername(String username) {
    setState(() {
      if (_omittedUsernames.contains(username)) {
        _omittedUsernames.remove(username);
      } else {
        _omittedUsernames.add(username);
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _toggleAddNewTag() {
    setState(() {
      _isAddingNewTag = !_isAddingNewTag;
      if (!_isAddingNewTag) {
        _tagController.clear();
      }
    });
  }

  void _addCustomTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_customTags.contains(tag) && !_defaultTags.contains(tag)) {
      setState(() {
        _customTags.add(tag);
        _selectedTag = tag;
        _isAddingNewTag = false;
        _tagController.clear();
      });
    }
  }

  Future<void> _saveExpense() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final expense = Expense(
        id: '',
        amount: amount,
        name: _nameController.text.trim(),
        tag: _selectedTag,
        currency: _selectedCurrency.code,
        date: _selectedDate,
        createdAt: DateTime.now(),
        splitWith: _selectedUsernames,
        splitMode: _splitMode,
        customAmounts: _customAmounts,
        omittedUsernames: _omittedUsernames,
      );

      await _expenseService.addExpense(widget.uid, expense);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save expense: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectCurrency(BuildContext context) async {
    final Currency? selected = await showModalBottomSheet<Currency>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CurrencySelectionBottomSheet(
        selectedCurrency: _selectedCurrency,
      ),
    );
    if (selected != null) {
      setState(() {
        _selectedCurrency = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final maxHeight = screenHeight - topPadding - 60;

    return Container(
      height: maxHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Expense',
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
          // Form content
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Dismiss keyboard when tapping outside text fields
                FocusScope.of(context).unfocus();
              },
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Spending Amount
                  const Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: _amountKey,
                    controller: _amountController,
                    focusNode: _amountFocusNode,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: '${_selectedCurrency.symbol} ',
                      prefixStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _selectCurrency(context),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedCurrency.code,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Name of Expense
                  const Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: _nameKey,
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Enter expense name',
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
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Tag Selection
                  const Text(
                    'Tag',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Default tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._defaultTags.map((tag) => _buildTagChip(tag)),
                      ..._customTags.map((tag) => _buildTagChip(tag)),
                    ],
                  ),
                  
                  // Add new tag option
                  const SizedBox(height: 12),
                  if (!_isAddingNewTag)
                    GestureDetector(
                      onTap: _toggleAddNewTag,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add,
                              size: 20,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add New Tag',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: _tagKey,
                            controller: _tagController,
                            focusNode: _tagFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Enter tag name',
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            style: const TextStyle(fontSize: 14),
                            onSubmitted: (_) => _addCustomTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: _addCustomTag,
                          color: Colors.black,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _toggleAddNewTag,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Date Selection
                  const Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMM dd, yyyy').format(_selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Username Section
                  const Text(
                    'Split With',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Username chips
                  if (_selectedUsernames.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedUsernames.map((username) {
                        return Chip(
                          label: Text('@$username'),
                          onDeleted: () => _removeUsername(username),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          backgroundColor: const Color(0xFFF5F5F5),
                          labelStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                  // Username input
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      hintText: 'Add username...',
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
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _addUsername(value);
                        _usernameController.clear();
                      }
                    },
                    onChanged: (value) {
                      // Process usernames when space is pressed
                      if (value.endsWith(' ')) {
                        _processUsernameInput(value);
                      }
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Split Options Section
                  if (_selectedUsernames.isNotEmpty) ...[
                    const Text(
                      'Split Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Split mode selection
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSplitModeButton('equal', 'Equal'),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildSplitModeButton('custom', 'Custom'),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildSplitModeButton('omit', 'Omit'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Split content based on mode
                    if (_splitMode == 'equal')
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20, color: Colors.black87),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Expense will be split equally among ${_selectedUsernames.length + 1} ${(_selectedUsernames.length + 1) == 1 ? 'person' : 'people'} (including you)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_splitMode == 'custom')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _selectedUsernames.map((username) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '@$username',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      prefixText: '${_selectedCurrency.symbol} ',
                                      prefixStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                    onChanged: (value) => _updateCustomAmount(username, value),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    else if (_splitMode == 'omit')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _selectedUsernames.map((username) {
                          final isOmitted = _omittedUsernames.contains(username);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () => _toggleOmitUsername(username),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isOmitted
                                      ? Colors.black.withOpacity(0.05)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isOmitted ? Colors.black : Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isOmitted
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isOmitted ? Colors.black : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '@$username',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isOmitted ? Colors.black : Colors.grey[700],
                                        decoration: isOmitted
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isOmitted)
                                      Text(
                                        'Omitted',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Save Expense',
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
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    final isSelected = _selectedTag == tag;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTag = isSelected ? null : tag;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
  
  Widget _buildSplitModeButton(String mode, String label) {
    final isSelected = _splitMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _splitMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
