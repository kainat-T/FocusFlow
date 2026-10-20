with open('lib/screens/home_screen.dart', 'a') as f:
    f.write('''
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
''')
print("Done")