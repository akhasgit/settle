import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/savings_item.dart';
import '../models/currency.dart';
import '../services/savings_service.dart';
import 'savings_detail_screen.dart';

class SavingsTab extends StatefulWidget {
  const SavingsTab({super.key});

  @override
  State<SavingsTab> createState() => _SavingsTabState();
}

class _SavingsTabState extends State<SavingsTab> {
  final _savingsService = SavingsService();
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
  }

  String _getCurrencySymbol(String code) {
    final currency = Currency.currencies.cast<Currency?>().firstWhere(
          (c) => c!.code == code,
          orElse: () => null,
        );
    return currency?.symbol ?? '\$';
  }

  String _formatAmount(double amount, String currencyCode) {
    final symbol = _getCurrencySymbol(currencyCode);
    if (amount >= 1000) {
      if (amount == amount.truncateToDouble()) {
        return '$symbol${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
      }
    }
    if (amount == amount.truncateToDouble()) {
      return '$symbol${amount.toInt()}';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavingsItem>>(
      stream: _savingsService.savingsStream(_uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.savings_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No savings goals yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to create your first savings goal',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) {
              return const SizedBox(height: 80);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSavingsCard(items[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildSavingsCard(SavingsItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SavingsDetailScreen(
              uid: _uid,
              savingsId: item.id,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Emoji or icon
                if (item.emoji != null)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        item.emoji!,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  )
                else if (item.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      item.imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child:
                          Icon(Icons.savings, size: 24, color: Colors.black54),
                    ),
                  ),
                const SizedBox(width: 12),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Amount needed
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatAmount(item.amountNeeded, item.currency),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatAmount(item.amountSaved, item.currency)} saved',
                      style: TextStyle(
                        fontSize: 12,
                        color: item.isCompleted
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[600],
                        fontWeight: item.isCompleted
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFF5F5F5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  item.isCompleted
                      ? const Color(0xFF4CAF50)
                      : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
