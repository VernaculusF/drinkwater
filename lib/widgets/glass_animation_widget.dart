import 'package:flutter/material.dart';
import 'dart:math' as Math;
import '../constants/app_constants.dart';

/// Виджет анимированного стакана с индикатором наполнения
class GlassAnimationWidget extends StatefulWidget {
  final double progress; // 0.0 - 1.0
  final int drankCount;
  final int totalCount;
  final VoidCallback onTap;
  final bool isAnimating;

  const GlassAnimationWidget({
    super.key,
    required this.progress,
    required this.drankCount,
    required this.totalCount,
    required this.onTap,
    this.isAnimating = false,
  });

  @override
  State<GlassAnimationWidget> createState() => _GlassAnimationWidgetState();
}

class _GlassAnimationWidgetState extends State<GlassAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _fillAnimationController;
  late Animation<double> _fillAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fillAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fillAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _fillAnimationController, curve: Curves.easeInOut),
        );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _fillAnimationController, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(GlassAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && oldWidget.drankCount != widget.drankCount) {
      _fillAnimationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _fillAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Center(
          child: CustomPaint(
            painter: GlassPainter(
              progress: widget.progress,
              fillAnimation: _fillAnimation.value,
            ),
            size: const Size(150, 280),
          ),
        ),
      ),
    );
  }
}

/// Рисовальщик для стакана
class GlassPainter extends CustomPainter {
  final double progress;
  final double fillAnimation;

  const GlassPainter({
    required this.progress,
    required this.fillAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    
    // Внешний контур стакана
    final glassPath = Path();
    glassPath.moveTo(width * 0.15, height * 0.15);
    glassPath.lineTo(width * 0.25, height * 0.95);
    glassPath.lineTo(width * 0.75, height * 0.95);
    glassPath.lineTo(width * 0.85, height * 0.15);
    glassPath.quadraticBezierTo(width * 0.5, height * 0.05, width * 0.15, height * 0.15);

    // Обводка стакана
    final strokePaint = Paint()
      ..color = AppConstants.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(glassPath, strokePaint);

    // Заливка стакана (вода)
    final liquidHeight = (height * 0.8) * progress * fillAnimation;
    final waterPath = Path();
    
    if (liquidHeight > 0) {
      waterPath.moveTo(width * 0.25, height * 0.95);
      
      // Волнистый край сверху
      const int wavePoints = 50;
      for (int i = 0; i <= wavePoints; i++) {
        double x = width * 0.25 + (width * 0.5) * (i / wavePoints);
        double waveAmplitude = 2 * (1 - (progress * fillAnimation).abs());
        double y = height * 0.95 - liquidHeight + 
                   Math.sin((i / wavePoints) * 6.28) * waveAmplitude;
        
        if (i == 0) {
          waterPath.moveTo(x, y);
        } else {
          waterPath.lineTo(x, y);
        }
      }
      
      waterPath.lineTo(width * 0.75, height * 0.95);
      waterPath.lineTo(width * 0.25, height * 0.95);
      waterPath.close();

      final waterPaint = Paint()
        ..color = AppConstants.primaryColor.withOpacity(0.7)
        ..style = PaintingStyle.fill;
      canvas.drawPath(waterPath, waterPaint);
    }

    // Блик на стакане  
    final glareGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white.withOpacity(0.3), Colors.transparent],
    );
    final glarePaint = Paint()
      ..shader = glareGradient.createShader(
        Rect.fromLTWH(width * 0.15, height * 0.1, width * 0.2, height * 0.3),
      );
    canvas.drawPath(glassPath, glarePaint);
  }

  @override
  bool shouldRepaint(GlassPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.fillAnimation != fillAnimation;
  }
}
