import 'package:flutter/material.dart';
import '../core/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeLogo;
  late Animation<double> _scaleLogo;
  late Animation<double> _fadeTitle;
  late Animation<double> _fadeSlogan;
  late Animation<double> _fadePowered;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

    _fadeLogo = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _scaleLogo = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );
    _fadeTitle = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.25, 0.6, curve: Curves.easeIn)),
    );
    _fadeSlogan = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.45, 0.75, curve: Curves.easeIn)),
    );
    _fadePowered = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.65, 0.9, curve: Curves.easeIn)),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.welcome);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFFFF8FB)],
          ),
        ),
        child: Column(
          children: [
            const Spacer(flex: 3),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _fadeLogo.value,
                child: Transform.scale(
                  scale: _scaleLogo.value,
                  child: child,
                ),
              ),
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFE91E63).withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 6)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _fadeTitle,
              child: const Text(
                'MamaGuard',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2D2D),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 14),
            FadeTransition(
              opacity: _fadeSlogan,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Votre santé et celle de votre bébé méritent une attention de chaque instant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
            FadeTransition(
              opacity: _fadePowered,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Text(
                    'Powered by AI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[400],
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}