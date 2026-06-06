import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Logo animation
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Text animation
  late AnimationController _textController;
  late Animation<double> _textOpacity;

  // Progress bar animation
  late AnimationController _progressController;
  late Animation<double> _progressValue;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    // Logo entrance
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Floating animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Text entrance
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    // Progress bar
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Sequence
    _logoController.forward().then((_) {
      _textController.forward();
      _progressController.forward();
    });
  }

  Future<void> _initializeApp() async {
    // Simply wait for initialization. The GoRouter redirect logic will handle navigation
    // once authNotifier.initialized and settings.initialized are true.
    await Future.delayed(const Duration(milliseconds: 2000)); // Faster splash time
    debugPrint('SplashScreen: Initialization check complete. Handing over to Router.');
  }

  @override
  void dispose() {
    _logoController.dispose();
    _floatController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                AnimatedBuilder(
                  animation: _floatController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -_floatAnimation.value),
                      child: Transform.scale(
                        scale:
                            1.0 +
                            (0.05 * (1.0 - (_floatAnimation.value / 15.0))),
                        child: Transform.rotate(
                          angle: 0.05 * (1.0 - (_floatAnimation.value / 15.0)),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Hero(
                        tag: 'app_logo',
                        child: Container(
                          width: 120,
                          height: 120,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // System Name
                FadeTransition(
                  opacity: _textOpacity,
                  child: Text(
                    'SomSafar',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Minimal Progress Bar
                AnimatedBuilder(
                  animation: _progressValue,
                  builder: (context, _) =>
                      _buildProgressBar(size, primaryColor),
                ),
              ],
            ),
          ),

          // Version removed
        ],
      ),
    );
  }

  Widget _buildProgressBar(Size size, Color primary) {
    final barWidth = size.width * 0.4;
    return Column(
      children: [
        Container(
          width: barWidth,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Container(
                width: barWidth * _progressValue.value,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
