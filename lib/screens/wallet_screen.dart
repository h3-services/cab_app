import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int selectedFilter = 1; // 0: All, 1: Trip Income, 2: Platform Fee, 3: Returned Money

  final List<Map<String, dynamic>> allTransactions = [
    {
      'title': 'Trip Earning',
      'date': 'Today',
      'tripId': 'Trip ID: TRIP001',
      'amount': '+₹430',
      'type': 'earning',
    },
    {
      'title': 'Service Fee',
      'date': 'Today',
      'tripId': 'Trip ID: TRIP001',
      'amount': '-₹30',
      'type': 'fee',
    },
    {
      'title': 'Trip Earning',
      'date': 'Yesterday',
      'tripId': 'Trip ID: TRIP012',
      'amount': '+₹1,300',
      'type': 'earning',
    },
    {
      'title': 'Trip Earning',
      'date': '10 days before',
      'tripId': 'Trip ID: TRIP016',
      'amount': '+₹3,050',
      'type': 'earning',
    },
  ];
  
  final List<Map<String, dynamic>> tripIncomeTransactions = [
    {
      'title': 'Trip Earning',
      'date': 'Today',
      'tripId': 'Trip ID: TRIP001',
      'amount': '+₹430',
      'type': 'earning',
    },
    {
      'title': 'Trip Earning',
      'date': 'Yesterday',
      'tripId': 'Trip ID: TRIP012',
      'amount': '+₹1,300',
      'type': 'earning',
    },
    {
      'title': 'Trip Earning',
      'date': '10 days before',
      'tripId': 'Trip ID: TRIP016',
      'amount': '+₹3,050',
      'type': 'earning',
    },
  ];
  
  final List<Map<String, dynamic>> platformFeeTransactions = [
    {
      'title': 'Service Fee',
      'date': 'Today',
      'tripId': 'Trip ID: TRIP001',
      'amount': '-₹30',
      'type': 'fee',
    },
  ];
  
  final List<Map<String, dynamic>> returnedMoneyTransactions = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF424242),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              color: const Color(0xFF424242),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.grey),
                  ),
                  const Spacer(),
                  const Text(
                    'CHOLA CABS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.menu, color: Colors.white),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: GradientBackground(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppTheme.greenGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available Balance',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '₹4,300.00',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const AppLogo(width: 60, height: 60),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Today's Income",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const Text(
                                        '₹350',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add, color: Colors.white, size: 20),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Add Money',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Trips Completed
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.local_taxi, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Trips Completed',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              '15',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Filter Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterTab('All', 0, Colors.grey.shade600),
                            const SizedBox(width: 8),
                            _buildFilterTab('Trip Income', 1, AppTheme.greenLight),
                            const SizedBox(width: 8),
                            _buildFilterTab('Platform Fee', 2, Colors.grey.shade600),
                            const SizedBox(width: 8),
                            _buildFilterTab('Returned Money', 3, Colors.grey.shade600),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Transaction History
                      const Text(
                        'Transaction History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Transaction List
                      ..._getCurrentTransactions().map((transaction) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildTransactionItem(
                          transaction['title'],
                          transaction['date'],
                          transaction['tripId'],
                          transaction['amount'],
                          transaction['type'],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Navigation
            Container(
              color: const Color(0xFF9E9E9E),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.home,
                          color: Colors.grey.shade400,
                          size: 24,
                        ),
                        Text(
                          'Home',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.blue,
                        size: 24,
                      ),
                      const Text(
                        'Wallet',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String text, int index, Color color) {
    bool isSelected = selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade600,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check, color: Colors.white, size: 16),
              ),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getCurrentTransactions() {
    switch (selectedFilter) {
      case 0:
        return allTransactions;
      case 1:
        return tripIncomeTransactions;
      case 2:
        return platformFeeTransactions;
      case 3:
        return returnedMoneyTransactions;
      default:
        return tripIncomeTransactions;
    }
  }

  Widget _buildTransactionItem(String title, String date, String tripId, String amount, String type) {
    bool isEarning = type == 'earning';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEarning ? AppTheme.greenLight : Colors.red,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEarning ? Icons.directions_car : Icons.remove_circle_outline,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tripId,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isEarning ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}