import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../theme/providers/theme_provider.dart';
import '../../../core/services/model_service.dart';
import '../../auth/pages/auth_gate.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ));
    
    _animationController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load models in the background
    ModelService.instance.loadModels();
    
    // Wait for animation and minimum splash duration
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    // Get theme colors
    final backgroundColor = isDark 
        ? themeProvider.selectedTheme.darkColors.background
        : themeProvider.selectedTheme.lightColors.background;
    final dotColor = isDark
        ? themeProvider.selectedTheme.darkColors.border.withOpacity(0.3)
        : themeProvider.selectedTheme.lightColors.border.withOpacity(0.3);
    final textColor = isDark
        ? themeProvider.selectedTheme.darkColors.onBackground
        : themeProvider.selectedTheme.lightColors.onBackground;
    final accentColor = isDark
        ? themeProvider.selectedTheme.darkColors.primary
        : themeProvider.selectedTheme.lightColors.primary;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Dotted pattern background
          CustomPaint(
            painter: DottedPatternPainter(
              dotColor: dotColor,
              spacing: 20,
              dotRadius: 1.5,
            ),
            child: Container(),
          ),
          
          // Logo
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'अहम्',
                            style: GoogleFonts.poppins(
                              fontSize: 48,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: textColor,
                            ),
                          ),
                          TextSpan(
                            text: 'AI',
                            style: GoogleFonts.inter(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for dotted pattern background
class DottedPatternPainter extends CustomPainter {
  final Color dotColor;
  final double spacing;
  final double dotRadius;

  DottedPatternPainter({
    required this.dotColor,
    required this.spacing,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DottedPatternPainter oldDelegate) {
    return dotColor != oldDelegate.dotColor ||
        spacing != oldDelegate.spacing ||
        dotRadius != oldDelegate.dotRadius;
  }
}