import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../agent/app_navigation_service.dart';
import 'growth_screen.dart';
import 'health_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/entrance_motion.dart';

/// Main bottom navigation container with 4 tabs.
class MainNavigation extends StatefulWidget {
  final bool showVoiceAgentReminder;

  const MainNavigation({super.key, this.showVoiceAgentReminder = false});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late final PageController _pageController;
  late final List<int> _animationSeeds;

  final List<IconData> _icons = <IconData>[
    Icons.cottage_outlined,
    Icons.favorite_border_rounded,
    Icons.park_outlined,
    Icons.tune_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationSeeds = <int>[1, 0, 0, 0];
    AppNavigationService.instance.registerTabSelector(_selectTab);
    if (widget.showVoiceAgentReminder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showVoiceAgentReminderDialog();
      });
    }
  }

  @override
  void dispose() {
    AppNavigationService.instance.unregisterTabSelector();
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> _buildScreens() {
    return <Widget>[
      HomeScreen(animationTrigger: _animationSeeds[0]),
      HealthScreen(
        animationTrigger: _animationSeeds[1],
        onRequestPreviousMainTab: () => _selectTab(_currentIndex - 1),
        onRequestNextMainTab: () => _selectTab(_currentIndex + 1),
      ),
      GrowthScreen(animationTrigger: _animationSeeds[2]),
      SettingsScreen(animationTrigger: _animationSeeds[3]),
    ];
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _icons.length || _currentIndex == index) {
      return;
    }

    final int distance = (index - _currentIndex).abs();
    if (distance > 1) {
      _pageController.jumpToPage(index);
      return;
    }

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _animationSeeds[index] = _animationSeeds[index] + 1;
    });
  }

  Future<void> _showVoiceAgentReminderDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.tr('Voice Assistant Ready')),
          content: Text(
            context.tr(
              'Use the voice assistant button on the right side of the Home title bar to create pets, open games, or log health hands-free.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Got it')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = _buildScreens();
    final List<String> labels = <String>[
      context.tr('Home'),
      context.tr('Health'),
      context.tr('Growth'),
      context.tr('Settings'),
    ];

    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _handlePageChanged,
        itemCount: screens.length,
        itemBuilder: (BuildContext context, int index) {
          return EntranceMotion(
            trigger: _animationSeeds[index],
            child: screens[index],
          );
        },
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.sketchWashGradient,
          border: Border(
            top: BorderSide(
              color: AppColors.sketchInk.withValues(alpha: 0.16),
              width: 1.4,
            ),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.secondaryDark.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
            child: Row(
              children: List.generate(screens.length, (index) {
                final isSelected = _currentIndex == index;
                return Expanded(
                  child: Semantics(
                    identifier: 'tab_${_icons[index].codePoint}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectTab(index),
                      child: SizedBox(
                        height: 66,
                        child: Center(
                          child: CustomPaint(
                            painter: _SketchTabPainter(active: isSelected),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  AnimatedScale(
                                    scale: isSelected ? 1.14 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      _icons[index],
                                      color: isSelected
                                          ? AppColors.sketchInk
                                          : AppColors.textSecondary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        labels[index],
                                        maxLines: 1,
                                        softWrap: false,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          height: 1,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? AppColors.sketchInk
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchTabPainter extends CustomPainter {
  final bool active;

  const _SketchTabPainter({required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) {
      return;
    }

    final Paint wash = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[AppColors.accent, AppColors.mint, AppColors.rose],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final Path underline = Path()
      ..moveTo(size.width * 0.23, size.height - 8)
      ..quadraticBezierTo(
        size.width * 0.46,
        size.height - 2,
        size.width * 0.75,
        size.height - 9,
      );
    canvas.drawPath(underline, wash);
  }

  @override
  bool shouldRepaint(covariant _SketchTabPainter oldDelegate) {
    return oldDelegate.active != active;
  }
}
