import 'package:flutter/material.dart';
import '../widgets/widgets.dart';

class TripPendingScreen extends StatefulWidget {
  const TripPendingScreen({super.key});

  @override
  State<TripPendingScreen> createState() => _TripPendingScreenState();
}

class _TripPendingScreenState extends State<TripPendingScreen> {
  // Sample pending trips data
  final List<Map<String, dynamic>> pendingTrips = [
    {
      'id': 'TRIP001',
      'pickup': 'Anna Nagar',
      'destination': 'T. Nagar',
      'distance': '12.5 km',
      'estimatedFare': '₹450',
      'customerName': 'Rajesh Kumar',
      'customerPhone': '+91 98765 43210',
      'bookingTime': '10:30 AM',
      'status': 'pending',
    },
    {
      'id': 'TRIP002',
      'pickup': 'Velachery',
      'destination': 'Adyar',
      'distance': '8.2 km',
      'estimatedFare': '₹320',
      'customerName': 'Priya Sharma',
      'customerPhone': '+91 87654 32109',
      'bookingTime': '11:15 AM',
      'status': 'pending',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: const CustomAppBar(
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  Icons.pending_actions,
                  color: Color(0xFF424242),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Active Trip Requests (${pendingTrips.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242),
                  ),
                ),
              ],
            ),
          ),

          // Trips List
          Expanded(
            child: pendingTrips.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: pendingTrips.length,
                    itemBuilder: (context, index) {
                      return _buildTripCard(pendingTrips[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Pending Trips',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All trip requests will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEBEBEB),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trip ID and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trip ID: ${trip['id']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF424242),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'PENDING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route Information
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip['pickup'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF424242),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flag, color: Color(0xFFFF5722), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip['destination'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF424242),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Trip Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem('Distance', trip['distance']),
              _buildDetailItem('Fare', trip['estimatedFare']),
              _buildDetailItem('Time', trip['bookingTime']),
            ],
          ),
          const SizedBox(height: 16),

          // Customer Information
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF424242), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip['customerName'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF424242),
                        ),
                      ),
                      Text(
                        trip['customerPhone'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _showCancelTripDialog(trip),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF424242)),
                    ),
                  ),
                  child: const Text(
                    'Cancel Trip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF424242),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptTrip(trip),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Accept Trip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF424242),
          ),
        ),
      ],
    );
  }

  void _showCancelTripDialog(Map<String, dynamic> trip) {
    CancelTripDialog.show(
      context,
      onConfirm: () {
        Navigator.of(context).pop(); // Close dialog
        _cancelTrip(trip);
      },
      onCancel: () {
        Navigator.of(context).pop(); // Close dialog
      },
    );
  }

  void _cancelTrip(Map<String, dynamic> trip) {
    setState(() {
      pendingTrips.removeWhere((t) => t['id'] == trip['id']);
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trip ${trip['id']} has been cancelled'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _acceptTrip(Map<String, dynamic> trip) {
    // Navigate to trip process screen
    Navigator.pushNamed(
      context,
      '/trip-process',
      arguments: trip,
    );
  }
}