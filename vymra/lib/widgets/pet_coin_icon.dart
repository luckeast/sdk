import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A gold coin with a stylized puppy face for all PawCoins UI.
class PetCoinIcon extends StatelessWidget {
  final double size;
  final Color? shadowColor;

  const PetCoinIcon({super.key, this.size = 24, this.shadowColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF0A8), Color(0xFFF4B544), Color(0xFFE18D2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (shadowColor ?? AppColors.primary).withValues(alpha: 0.28),
              blurRadius: size * 0.18,
              offset: Offset(0, size * 0.08),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFD78622),
            width: size * 0.06,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.1),
          child: CustomPaint(painter: _PetCoinPainter()),
        ),
      ),
    );
  }
}

class _PetCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final faceFill = Paint()..color = const Color(0xFFF7E7C0);
    final accentFill = Paint()..color = const Color(0xFFB36A2F);
    final linePaint = Paint()
      ..color = const Color(0xFF74411C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final eyePaint = Paint()..color = const Color(0xFF5A2E14);

    final faceRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + size.height * 0.05),
      width: size.width * 0.52,
      height: size.height * 0.46,
    );
    final faceRRect = RRect.fromRectAndRadius(
      faceRect,
      Radius.circular(size.width * 0.18),
    );
    canvas.drawRRect(faceRRect, faceFill);
    canvas.drawRRect(faceRRect, linePaint);

    final leftEar = Path()
      ..moveTo(size.width * 0.26, size.height * 0.36)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.08,
        size.width * 0.38,
        size.height * 0.22,
      )
      ..lineTo(size.width * 0.43, size.height * 0.34)
      ..close();
    final rightEar = Path()
      ..moveTo(size.width * 0.74, size.height * 0.36)
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.08,
        size.width * 0.62,
        size.height * 0.22,
      )
      ..lineTo(size.width * 0.57, size.height * 0.34)
      ..close();
    canvas.drawPath(leftEar, accentFill);
    canvas.drawPath(rightEar, accentFill);
    canvas.drawPath(leftEar, linePaint);
    canvas.drawPath(rightEar, linePaint);

    final muzzleRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + size.height * 0.14),
      width: size.width * 0.3,
      height: size.height * 0.18,
    );
    final muzzleRRect = RRect.fromRectAndRadius(
      muzzleRect,
      Radius.circular(size.width * 0.12),
    );
    canvas.drawRRect(muzzleRRect, Paint()..color = const Color(0xFFFFF3D8));
    canvas.drawRRect(muzzleRRect, linePaint);

    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.43),
      size.width * 0.035,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.6, size.height * 0.43),
      size.width * 0.035,
      eyePaint,
    );

    final nose = Path()
      ..moveTo(center.dx, size.height * 0.5)
      ..lineTo(size.width * 0.46, size.height * 0.57)
      ..lineTo(size.width * 0.54, size.height * 0.57)
      ..close();
    canvas.drawPath(nose, eyePaint);

    canvas.drawLine(
      Offset(center.dx, size.height * 0.57),
      Offset(center.dx, size.height * 0.64),
      linePaint,
    );
    final smile = Path()
      ..moveTo(size.width * 0.43, size.height * 0.63)
      ..quadraticBezierTo(
        center.dx,
        size.height * 0.7,
        size.width * 0.57,
        size.height * 0.63,
      );
    canvas.drawPath(smile, linePaint);

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    canvas.drawCircle(center, size.width * 0.42, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
