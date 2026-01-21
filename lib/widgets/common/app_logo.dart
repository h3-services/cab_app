import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double width;
  final double height;
  
  const AppLogo({
    super.key,
    this.width = 250,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/chola_cabs_logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}