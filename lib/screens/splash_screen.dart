import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'signin_screen.dart';
import '../shell/patient_shell.dart';
import '../services/auth_service.dart';
import '../services/inactivity_service.dart';
import '../utils/brand_assets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _particleController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 2800));

    if (!mounted) return;

    final authService = AuthService.instance;
    final validToken = await authService.getValidAccessToken();
    if (!mounted) return;

    if (validToken != null && authService.patientData != null) {
      final data = authService.patientData!;
      final mrn = data['MRN'] ?? data['mrn'] ?? '';
      final cnic = data['cnic'] ?? data['CNIC'] ?? '';
      final identifier = mrn.toString().isNotEmpty
          ? mrn.toString()
          : cnic.toString();
      InactivityService.instance.resetActivity();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PatientShell(patientIdentifier: identifier),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bannerWidth = width.clamp(280.0, 520.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFDFEDE4),
              Color(0xFFF0F5F2),
              Color(0xFFF6F8F7),
            ],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: Stack(
          children: [
            ...List.generate(6, (index) => _buildFloatingParticle(index)),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Image.asset(
                    BrandAssets.banner,
                    width: bannerWidth,
                    fit: BoxFit.contain,
                    semanticLabel: 'My Health Record',
                    errorBuilder: (_, __, ___) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          BrandAssets.logo,
                          width: 140,
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'My Health Record',
                          style: TextStyle(
                            color: Color(0xFF0A3F2C),
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  SizedBox(
                    width: 35,
                    height: 35,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF0B4D35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: const Color(0xFF0B4D35).withValues(alpha: 0.75),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingParticle(int index) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        final angle =
            (_particleController.value * 2 * math.pi + index * math.pi / 3) %
            (2 * math.pi);
        final radius = 180.0 + (index % 3) * 40.0;
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        return Positioned(
          left: screenWidth / 2 + radius * math.cos(angle) - 6,
          top: screenHeight / 2 + radius * math.sin(angle) - 6,
          child: Opacity(
            opacity: 0.2 + 0.15 * math.sin(angle * 2),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF009091),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF009091).withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
