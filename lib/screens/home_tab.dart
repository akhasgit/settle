import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildSpendCard(
            amount: 56,
            label: 'Today',
            dots: 1,
            isPrimary: true,
          ),
          const SizedBox(height: 16),
          _buildSpendCard(
            amount: 273,
            label: 'Week',
            dots: 5,
            isPrimary: false,
          ),
          const SizedBox(height: 16),
          _buildSpendCard(
            amount: 1397,
            label: 'Month',
            dots: 28,
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSpendCard({
    required int amount,
    required String label,
    required int dots,
    required bool isPrimary,
  }) {
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
              Text(
                '\$$amount',
                style: TextStyle(
                  fontSize: isPrimary ? 48 : (label == 'Week' ? 36 : 32),
                  fontWeight: FontWeight.bold,
                  color: isPrimary
                      ? Colors.black
                      : (label == 'Week'
                          ? const Color(0xFF424242)
                          : const Color(0xFF757575)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          _buildDots(dots),
        ],
      ),
    );
  }

  Widget _buildDots(int count) {
    if (count == 1) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFF424242),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else if (count == 5) {
      return Row(
        children: List.generate(
          5,
          (index) => Container(
            width: 8,
            height: 8,
            margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
            decoration: BoxDecoration(
              color: const Color(0xFF424242),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    } else {
      // 28 dots in 2 rows of 14
      return Column(
        children: [
          Row(
            children: List.generate(
              14,
              (index) => Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.only(
                  right: index < 13 ? 8 : 0,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF424242),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(
              14,
              (index) => Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.only(right: index < 13 ? 8 : 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF424242),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }
}
