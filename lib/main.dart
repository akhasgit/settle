import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:settle/firebase_options.dart';
import 'screens/home_tab.dart';
import 'screens/savings_tab.dart';
import 'screens/analytics_tab.dart';
import 'auth/login_screen.dart';
import 'auth/auth_service.dart';
import 'widgets/add_expense_bottom_sheet.dart';
// TODO: Run 'flutterfire configure' to generate this file
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: After running 'flutterfire configure', uncomment the import above
  // and replace the line below with:
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // await Firebase.initializeApp();
  runApp(const SettleApp());
}

class SettleApp extends StatelessWidget {
  const SettleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Settle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        useMaterial3: true,
        
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // If user is logged in, show main screen
        if (snapshot.hasData) {
          return const MainScreen();
        }
        
        // If user is not logged in, show login screen
        return const LoginScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content with TabBarView
          SafeArea(
            child: Column(
              children: [
                // Top bar with date and add button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(DateTime.now()),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const AddExpenseBottomSheet(),
                          );
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // TabBarView for content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      HomeTab(),
                      SavingsTab(),
                      AnalyticsTab(),
                    ],
                  ),
                ),
                // Spacer to push navigation bar up
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Custom floating glass navigation bar
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: MediaQuery.removeViewInsets(
              removeBottom: true,
              context: context,
              child: _buildFloatingGlassNavBar(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingGlassNavBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final navBarWidth = (screenWidth * 0.85) - 8;

    return Container(
      height: 80,
      alignment: Alignment.center,
      child: Container(
        width: navBarWidth,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Stack(
                children: [
                  // Animated selector
                  AnimatedBuilder(
                    animation: _tabController.animation!,
                    builder: (context, child) {
                      final animationValue = _tabController.animation!.value;
                      // Calculate position: animationValue goes from 0 to 2 (for 3 tabs)
                      // Each tab is navBarWidth / 3 wide
                      final selectorPosition = animationValue * navBarWidth / 3;
                      
                      return Positioned(
                        left: selectorPosition,
                        top: 2,
                        child: Container(
                          width: navBarWidth / 3,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      );
                    },
                  ),
                  // Tab items
                  Row(
                    children: [
                      _buildNavItem(
                        icon: Icons.account_balance_wallet_outlined,
                        filledIcon: Icons.account_balance_wallet,
                        index: 0,
                        label: 'Dashboard',
                      ),
                      _buildNavItem(
                        icon: Icons.savings_outlined,
                        filledIcon: Icons.savings,
                        index: 1,
                        label: 'Savings',
                      ),
                      _buildNavItem(
                        icon: Icons.bar_chart_outlined,
                        filledIcon: Icons.bar_chart,
                        index: 2,
                        label: 'Analytics',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData filledIcon,
    required int index,
    required String label,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
        },
        child: Container(
          height: 60,
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _tabController.animation!,
            builder: (context, child) {
              final isSelected = _tabController.index == index;
              return Icon(
                isSelected ? filledIcon : icon,
                color: isSelected ? Colors.black : Colors.grey,
                size: 24,
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekday = DateFormat('EEE', 'en_US').format(date);
    final day = date.day;
    final month = DateFormat('MMM', 'en_US').format(date).toLowerCase();
    final year = date.year;
    return '$weekday. $day $month $year';
  }
}
