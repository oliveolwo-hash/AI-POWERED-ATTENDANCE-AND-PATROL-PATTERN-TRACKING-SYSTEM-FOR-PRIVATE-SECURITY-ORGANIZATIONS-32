import 'package:flutter/material.dart';

class DashboardBackground extends StatelessWidget {
  final Widget child;

  const DashboardBackground({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black, // Fallback
        image: DecorationImage(
          image: AssetImage('assets/images/dashboard_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      // Apply a subtle dark overlay so the white text pops more
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: child,
      ),
    );
  }
}
