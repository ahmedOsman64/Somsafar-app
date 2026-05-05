import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/services/settings_repository.dart';
import '../shared/services/auth_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for animation to finish briefly
    await Future.delayed(const Duration(milliseconds: 800));

    // Wait for services to initialize if they haven't yet
    // This is crucial to avoid flickering or premature redirect to login
    int timeoutCount = 0;
    while (mounted &&
        (!ref.read(settingsProvider).initialized ||
            !ref.read(authServiceProvider).initialized) &&
        timeoutCount < 50) { // Max 5 seconds wait
      await Future.delayed(const Duration(milliseconds: 100));
      timeoutCount++;
    }

    // Check if services are initialized
    final settings = ref.read(settingsProvider);
    final auth = ref.read(authServiceProvider);

    // We don't necessarily need to check initialized flags here
    // because the direct navigation will handle the next state.
    // If not seen onboarding, go to /onboarding
    if (!settings.hasSeenOnboarding) {
      if (mounted) context.go('/onboarding');
    } else {
      // If logged in, go to home (redirect will handle role-based dashboards)
      // If not, go to /login
      if (auth.state == null) {
        if (mounted) context.go('/login');
      } else {
        // Just navigate to root, redirect logic in GoRouter will handle the rest
        if (mounted) context.go('/');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
