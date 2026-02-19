import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class BottomNavigation extends StatelessWidget {
  final String currentRoute;
  final Function(String)? onTap;

  const BottomNavigation({
    super.key,
    required this.currentRoute,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            Icons.home,
            'Home',
            currentRoute == '/dashboard',
            () {
              if (onTap != null) {
                onTap!('/dashboard');
              } else {
                Navigator.pushReplacementNamed(context, '/dashboard');
              }
            },
          ),
          const SizedBox(width: 10),
          _buildNavItem(
            Icons.wallet,
            'Wallet',
            currentRoute == '/wallet',
            () {
              if (onTap != null) {
                onTap!('/wallet');
              } else {
                Navigator.pushReplacementNamed(context, '/wallet');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => isActive
                ? LinearGradient(
                    colors: [AppColors.bluePrimary, AppColors.blueDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds)
                : const LinearGradient(
                    colors: [Colors.black54, Colors.black54],
                  ).createShader(bounds),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.blueDark : Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
