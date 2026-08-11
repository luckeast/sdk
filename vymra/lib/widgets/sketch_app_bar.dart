import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A hand-drawn title bar that keeps the app chrome playful and consistent.
class SketchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double toolbarBottomSpacing;
  final double titleBottomPadding;
  final double titleVerticalOffset;

  const SketchAppBar({
    super.key,
    required this.title,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.bottom,
    this.toolbarBottomSpacing = 12,
    this.titleBottomPadding = 10,
    this.titleVerticalOffset = 0,
  });

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + toolbarBottomSpacing + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      leadingWidth: leadingWidth,
      actions: actions,
      toolbarHeight: kToolbarHeight + toolbarBottomSpacing,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.sketchInk,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      title: Transform.translate(
        offset: Offset(0, titleVerticalOffset),
        child: _SketchTitle(text: title, bottomPadding: titleBottomPadding),
      ),
      bottom: bottom,
      flexibleSpace: const _SketchChrome(),
    );
  }
}

class _SketchTitle extends StatelessWidget {
  final String text;
  final double bottomPadding;

  const _SketchTitle({required this.text, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TitleUnderlinePainter(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 6, 14, bottomPadding),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.title.copyWith(
            color: AppColors.sketchInk,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _SketchChrome extends StatelessWidget {
  const _SketchChrome();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.sketchWashGradient),
      child: CustomPaint(
        painter: _SketchChromePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TitleUnderlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint sun = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final Path underline = Path()
      ..moveTo(4, size.height - 5)
      ..quadraticBezierTo(
        size.width * 0.32,
        size.height - 1,
        size.width * 0.62,
        size.height - 5,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height - 8,
        size.width - 4,
        size.height - 4,
      );
    canvas.drawPath(underline, sun);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SketchChromePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint ink = Paint()
      ..color = AppColors.sketchInk.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final Paint coral = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    final Paint teal = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;

    final double bottom = size.height - 1;
    canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom - 2), ink);

    final Path leftEar = Path()
      ..moveTo(20, bottom - 18)
      ..quadraticBezierTo(30, bottom - 34, 42, bottom - 18)
      ..quadraticBezierTo(31, bottom - 24, 20, bottom - 18);
    canvas.drawPath(leftEar, coral);

    final Path tail = Path()
      ..moveTo(size.width - 68, bottom - 18)
      ..cubicTo(
        size.width - 42,
        bottom - 40,
        size.width - 18,
        bottom - 10,
        size.width - 42,
        bottom - 9,
      );
    canvas.drawPath(tail, teal);

    for (final Offset point in <Offset>[
      Offset(size.width * 0.18, bottom - 13),
      Offset(size.width * 0.78, bottom - 24),
      Offset(size.width * 0.88, bottom - 32),
    ]) {
      canvas.drawCircle(point, 2.2, ink);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
