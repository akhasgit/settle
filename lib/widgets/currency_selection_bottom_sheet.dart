import 'package:flutter/material.dart';
import '../models/currency.dart';

class CurrencySelectionBottomSheet extends StatefulWidget {
  final Currency selectedCurrency;

  const CurrencySelectionBottomSheet({
    super.key,
    required this.selectedCurrency,
  });

  @override
  State<CurrencySelectionBottomSheet> createState() =>
      _CurrencySelectionBottomSheetState();
}

class _CurrencySelectionBottomSheetState
    extends State<CurrencySelectionBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Currency> _filteredCurrencies = Currency.currencies;
  Currency _selectedCurrency = Currency.currencies.first;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.selectedCurrency;
    _searchController.addListener(_filterCurrencies);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCurrencies);
    _searchController.dispose();
    super.dispose();
  }

  void _filterCurrencies() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCurrencies = Currency.currencies;
      } else {
        _filteredCurrencies = Currency.currencies.where((currency) {
          return currency.code.toLowerCase().contains(query) ||
              currency.name.toLowerCase().contains(query) ||
              currency.symbol.toLowerCase().contains(query);
        }).toList();
      }
    });
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
                  'Select Currency',
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
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search currency...',
                prefixIcon: const Icon(Icons.search),
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
            ),
          ),
          const SizedBox(height: 16),
          // Currency list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filteredCurrencies.length,
              itemBuilder: (context, index) {
                final currency = _filteredCurrencies[index];
                final isSelected = _selectedCurrency.code == currency.code;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCurrency = currency;
                    });
                    Navigator.of(context).pop(currency);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.black.withOpacity(0.05)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.black
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Currency symbol
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.black
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            currency.symbol,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Currency info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currency.code,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currency.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? Colors.black87
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Selected indicator
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.black,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
