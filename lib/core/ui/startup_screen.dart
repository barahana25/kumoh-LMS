import 'package:flutter/material.dart';

/// Shows the full square artwork without the launcher's adaptive icon mask.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Image.asset(
        'assets/branding/kumoh-lms-logo-v4.png',
        width: 240,
        height: 240,
        fit: BoxFit.contain,
        semanticLabel: '금오공과대학교 LMS 시작 중',
      ),
    ),
  );
}
