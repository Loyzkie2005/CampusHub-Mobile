import 'package:flutter/material.dart';

/// The web product uploader's 24x24 rounded upload-arrow SVG, drawn natively.
class ProductUploadIcon extends StatelessWidget {
  const ProductUploadIcon({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 34,
      child: CustomPaint(
        painter: _ProductUploadPainter(IconTheme.of(context).color!),
      ),
    ),
  );
}

class _ProductUploadPainter extends CustomPainter {
  const _ProductUploadPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final path = Path()
      ..moveTo(3, 16.5)
      ..lineTo(3, 18.75)
      ..arcToPoint(
        const Offset(5.25, 21),
        radius: const Radius.circular(2.25),
        clockwise: false,
      )
      ..lineTo(18.75, 21)
      ..arcToPoint(
        const Offset(21, 18.75),
        radius: const Radius.circular(2.25),
        clockwise: false,
      )
      ..lineTo(21, 16.5)
      ..moveTo(7.5, 7.5)
      ..lineTo(12, 3)
      ..lineTo(16.5, 7.5)
      ..moveTo(12, 3)
      ..lineTo(12, 16.5);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProductUploadPainter oldDelegate) =>
      oldDelegate.color != color;
}
