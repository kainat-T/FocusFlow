import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Subtle background pattern painter
// ---------------------------------------------------------------------------
class _BackgroundPatternPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double dotRadius;

  const _BackgroundPatternPainter({
    required this.color,
    this.spacing = 40.0,
    this.dotRadius = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw a subtle dot grid pattern
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Add slight offset to every other row for a more organic feel
        final offsetX = (y ~/ spacing) % 2 == 0 ? 0 : spacing / 2;
        canvas.drawCircle(
          Offset(x + offsetX, y),
          dotRadius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPatternPainter old) =>
      old.color != color ||
      old.spacing != spacing ||
      old.dotRadius != dotRadius;
}

// ---------------------------------------------------------------------------
// Background pattern widget
// ---------------------------------------------------------------------------
class BackgroundPattern extends StatelessWidget {
  final Color? color;
  final double spacing;
  final double dotRadius;

  const BackgroundPattern({
    super.key,
    this.color,
    this.spacing = 48.0,
    this.dotRadius = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _BackgroundPatternPainter(
        color: color ?? Theme.of(context).colorScheme.primary.withAlpha(15),
        spacing: spacing,
        dotRadius: dotRadius,
      ),
    );
  }
}