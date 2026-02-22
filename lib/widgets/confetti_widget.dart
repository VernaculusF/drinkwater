import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Виджет конфетти для празднования достижения цели
class ConfettiWidget extends StatefulWidget {
  final bool show;
  final Duration duration;
  final VoidCallback onComplete;

  const ConfettiWidget({
    super.key,
    required this.show,
    this.duration = const Duration(seconds: 3),
    required this.onComplete,
  });

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    if (widget.show) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(ConfettiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _startAnimation();
    }
  }

  void _startAnimation() async {
    await _controller.forward();
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: ConfettiPainter(
            animation: _controller,
          ),
        ),
      ),
    );
  }
}

/// Рисовальщик конфетти
class ConfettiPainter extends CustomPainter {
  final Animation<double> animation;
  final List<Confetti> confetti;

  ConfettiPainter({required this.animation})
      : confetti = List.generate(50, (index) => _createConfetti(index)) {
    animation.addListener(() {});
  }

  static Confetti _createConfetti(int index) {
    final random = math.Random(index);
    return Confetti(
      x: random.nextDouble(),
      y: -0.1,
      vx: (random.nextDouble() - 0.5) * 2,
      vy: random.nextDouble() * 0.5 + 0.5,
      rotation: random.nextDouble() * 360,
      color: [
        Colors.red,
        Colors.blue,
        Colors.yellow,
        Colors.purple,
        Colors.green,
        Colors.pink,
      ][random.nextInt(6)],
      size: random.nextDouble() * 8 + 4,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;

    for (final conf in confetti) {
      // Движение вниз
      final y = conf.y + conf.vy * progress;
      final x = conf.x + conf.vx * progress * 0.5;

      // Затухание в конце
      final opacity = (1 - progress).clamp(0, 1).toDouble();

      // Вращение
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate((conf.rotation + progress * 360) * math.pi / 180);

      final paint = Paint()
        ..color = conf.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset.zero, conf.size, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return animation.value != oldDelegate.animation.value;
  }
}

/// Модель конфетти
class Confetti {
  double x;
  double y;
  final double vx;
  final double vy;
  final double rotation;
  final Color color;
  final double size;

  Confetti({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.color,
    required this.size,
  });
}
