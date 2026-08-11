import 'package:flutter/material.dart';

/// Replays a soft fade-and-drop entrance when [trigger] changes.
class EntranceMotion extends StatefulWidget {
  final Widget child;
  final Object? trigger;
  final Duration duration;
  final Duration delay;
  final double offsetY;
  final Curve curve;

  const EntranceMotion({
    super.key,
    required this.child,
    this.trigger,
    this.duration = const Duration(milliseconds: 520),
    this.delay = Duration.zero,
    this.offsetY = -20,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<EntranceMotion> createState() => _EntranceMotionState();
}

class _EntranceMotionState extends State<EntranceMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _configureAnimations();
    _play();
  }

  @override
  void didUpdateWidget(covariant EntranceMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      _configureAnimations();
    }
    if (oldWidget.trigger != widget.trigger) {
      _play();
    }
  }

  void _configureAnimations() {
    final CurvedAnimation curved = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
      reverseCurve: Curves.easeInCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _translateY = Tween<double>(begin: widget.offsetY, end: 0).animate(curved);
  }

  Future<void> _play() async {
    _controller.reset();
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
      if (!mounted) {
        return;
      }
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _translateY.value),
            child: child,
          ),
        );
      },
    );
  }
}
