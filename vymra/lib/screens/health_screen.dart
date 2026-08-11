import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/health_record.dart';
import '../providers/health_data_provider.dart';
import '../providers/pet_profile_provider.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/entrance_motion.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/loading_widget.dart';
import '../widgets/reminder_form_dialog.dart';
import '../widgets/sketch_app_bar.dart';
import 'health_vaccine_tab.dart';
import 'quick_record_screen.dart';

/// Health tracking screen with charts and history.
class HealthScreen extends StatefulWidget {
  final int animationTrigger;
  final VoidCallback? onRequestPreviousMainTab;
  final VoidCallback? onRequestNextMainTab;

  const HealthScreen({
    super.key,
    this.animationTrigger = 0,
    this.onRequestPreviousMainTab,
    this.onRequestNextMainTab,
  });

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final List<GlobalKey> _tabKeys;
  final List<String> _recordTypes = <String>[
    'weight',
    'water',
    'exercise',
    'sleep',
    'meal',
  ];
  final List<String> _tabLabels = <String>[
    'weight',
    'water',
    'exercise',
    'sleep',
    'meal',
    'vaccine',
  ];

  String? _insightMessage;
  bool _showInsight = false;
  bool _isForwardingEdgeSwipe = false;
  Timer? _insightTimer;
  int _lastCenteredIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabKeys = List<GlobalKey>.generate(_tabLabels.length, (_) => GlobalKey());
    _tabController.addListener(_handleTabSelection);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _centerSelectedTab(_tabController.index, animated: false);
    });
  }

  Future<void> _loadData() async {
    final PetProfileProvider petProvider = context.read<PetProfileProvider>();
    if (!petProvider.hasProfile) {
      await petProvider.loadDefaultProfile();
    }

    if (!mounted || !petProvider.hasProfile) {
      return;
    }

    await context.read<HealthDataProvider>().loadRecords(
      petProvider.profile!.petId,
    );
  }

  void _handleTabSelection() {
    if (_lastCenteredIndex == _tabController.index) {
      return;
    }

    _lastCenteredIndex = _tabController.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerSelectedTab(_tabController.index);
    });
  }

  void _centerSelectedTab(int index, {bool animated = true}) {
    final BuildContext? tabContext = _tabKeys[index].currentContext;
    if (tabContext == null) {
      return;
    }

    Scrollable.ensureVisible(
      tabContext,
      alignment: 0.5,
      duration: animated ? const Duration(milliseconds: 260) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  void _showAddReminderDialog(BuildContext context) {
    final petId = context.read<PetProfileProvider>().profile?.petId;
    if (petId == null) return;
    showDialog(
      context: context,
      builder: (context) => ReminderFormDialog(petId: petId),
    );
  }

  Future<void> _showNoPetProfileDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.tr('No Pet Profile')),
          content: Text(dialogContext.tr('Create a pet profile first')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                widget.onRequestPreviousMainTab?.call();
              },
              child: Text(dialogContext.tr('Add Pet')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openRecordFlow({
    required String recordType,
    HealthRecord? record,
  }) async {
    final PetProfileProvider petProvider = context.read<PetProfileProvider>();
    if (!petProvider.hasProfile) {
      await _showNoPetProfileDialog();
      return;
    }

    final QuickRecordResult? result = await Navigator.push<QuickRecordResult>(
      context,
      MaterialPageRoute(
        builder: (_) => QuickRecordScreen(
          petId: petProvider.profile!.petId,
          initialRecordType: recordType,
          existingRecord: record,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _showAiInsight(result.aiSummary);
  }

  void _showAiInsight(String message) {
    _insightTimer?.cancel();
    setState(() {
      _insightMessage = message;
      _showInsight = true;
    });

    _insightTimer = Timer(const Duration(seconds: 5), _hideAiInsight);
  }

  void _hideAiInsight() {
    if (!mounted) {
      return;
    }

    setState(() {
      _showInsight = false;
    });

    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (!mounted || _showInsight) {
        return;
      }

      setState(() {
        _insightMessage = null;
      });
    });
  }

  bool _handleHorizontalOverscroll(OverscrollNotification notification) {
    if (_isForwardingEdgeSwipe ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }

    final bool atLeadingEdge =
        _tabController.index == 0 && notification.overscroll < -10;
    final bool atTrailingEdge =
        _tabController.index == _tabLabels.length - 1 &&
        notification.overscroll > 10;

    if (!atLeadingEdge && !atTrailingEdge) {
      return false;
    }

    _isForwardingEdgeSwipe = true;
    if (atLeadingEdge) {
      widget.onRequestPreviousMainTab?.call();
    } else {
      widget.onRequestNextMainTab?.call();
    }

    Future<void>.delayed(const Duration(milliseconds: 280), () {
      _isForwardingEdgeSwipe = false;
    });
    return false;
  }

  @override
  void dispose() {
    _insightTimer?.cancel();
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final HealthDataProvider healthProvider = context
        .watch<HealthDataProvider>();

    return Scaffold(
      appBar: SketchAppBar(
        title: context.tr('Health'),
        toolbarBottomSpacing: 0,
        titleBottomPadding: 0,
        titleVerticalOffset: 6,
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              if (!context.read<PetProfileProvider>().hasProfile) {
                await _showNoPetProfileDialog();
                return;
              }

              final tabIndex = _tabController.index;
              if (tabIndex == _tabLabels.length - 1) {
                _showAddReminderDialog(context);
              } else {
                _openRecordFlow(recordType: _recordTypes[tabIndex]);
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: context.tr('Add record'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              onTap: (int index) => _centerSelectedTab(index),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.95),
                  width: 4,
                ),
                insets: const EdgeInsets.symmetric(horizontal: 16),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.sketchInk,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w500,
              ),
              tabs: List<Widget>.generate(_tabLabels.length, (int index) {
                final String type = _tabLabels[index];
                return KeyedSubtree(
                  key: _tabKeys[index],
                  child: Tab(text: context.tr(_recordTypeDisplay(type))),
                );
              }),
            ),
          ),
        ),
      ),
      body: EntranceMotion(
        trigger: widget.animationTrigger,
        child: Stack(
          children: <Widget>[
            healthProvider.isLoading
                ? Center(
                    child: LoadingWidget(
                      message: context.tr('Loading health data...'),
                    ),
                  )
                : NotificationListener<OverscrollNotification>(
                    onNotification: _handleHorizontalOverscroll,
                    child: TabBarView(
                      controller: _tabController,
                      children: _tabLabels.map((String type) {
                        if (type == 'vaccine') {
                          return const HealthVaccineTabView();
                        }
                        return _HealthTypeView(
                          recordType: type,
                          onOpenRecord:
                              ({
                                required String recordType,
                                HealthRecord? record,
                              }) {
                                return _openRecordFlow(
                                  recordType: recordType,
                                  record: record,
                                );
                              },
                        );
                      }).toList(),
                    ),
                  ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: IgnorePointer(
                ignoring: !_showInsight,
                child: AnimatedSlide(
                  offset: _showInsight ? Offset.zero : const Offset(0, -0.2),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _showInsight ? 1 : 0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    child: _insightMessage == null
                        ? const SizedBox.shrink()
                        : _AiInsightBanner(
                            message: _insightMessage!,
                            onClose: _hideAiInsight,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef HealthRecordFlowOpener =
    Future<void> Function({required String recordType, HealthRecord? record});

class _HealthTypeView extends StatelessWidget {
  final String recordType;
  final HealthRecordFlowOpener onOpenRecord;

  const _HealthTypeView({required this.recordType, required this.onOpenRecord});

  @override
  Widget build(BuildContext context) {
    final HealthDataProvider healthProvider = context
        .watch<HealthDataProvider>();
    final List<HealthRecord> records = healthProvider.getRecordsByType(
      recordType,
    );
    final List<HealthRecord> trendRecords = records
        .take(7)
        .toList()
        .reversed
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: <Widget>[
          _TrendChart(recordType: recordType, records: trendRecords),
          const SizedBox(height: 18),
          if (records.isEmpty)
            EmptyStateWidget(
              title: context.tr(
                'No {recordType} records',
                params: <String, String>{
                  'recordType': context.tr(_recordTypeDisplay(recordType)),
                },
              ),
              message: context.tr(
                'Start tracking your pet\'s {recordType} to see trends here.',
                params: <String, String>{
                  'recordType': context
                      .tr(_recordTypeDisplay(recordType))
                      .toLowerCase(),
                },
              ),
              actionLabel: context.tr('Add Record'),
              onAction: () => onOpenRecord(recordType: recordType),
            )
          else
            ...records.take(10).map((HealthRecord record) {
              return _RecordItem(
                record: record,
                onTap: () =>
                    onOpenRecord(recordType: recordType, record: record),
              );
            }),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final String recordType;
  final List<HealthRecord> records;

  const _TrendChart({required this.recordType, required this.records});

  @override
  Widget build(BuildContext context) {
    final PetProfileProvider petProvider = context.watch<PetProfileProvider>();
    final String avatarPath = petProvider.profile?.avatarPath ?? '';
    final String title = context.tr(
      '{recordType} Trend',
      params: <String, String>{
        'recordType': context.tr(_recordTypeDisplay(recordType)),
      },
    );

    if (records.isEmpty) {
      return AppCard(
        borderRadius: 32,
        padding: EdgeInsets.zero,
        gradient: LinearGradient(
          colors: <Color>[
            const Color(0xFFFFF7F0),
            AppColors.sky.withValues(alpha: 0.08),
            AppColors.accent.withValues(alpha: 0.16),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: IgnorePointer(child: _PetSketchBackdrop()),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _TrendSketchLabel(recordType: recordType),
                        const SizedBox(height: 14),
                        Text(title, style: AppTextStyles.title),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(
                            'Add a few more health snapshots and this board will turn into a comic-style progress strip.',
                          ),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AvatarPaperclipBadge(avatarPath: avatarPath),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final List<FlSpot> spots = records.asMap().entries.map((
      MapEntry<int, HealthRecord> entry,
    ) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    final double rawMinY = records
        .map((HealthRecord record) => record.value)
        .reduce(_minDouble);
    final double rawMaxY = records
        .map((HealthRecord record) => record.value)
        .reduce(_maxDouble);
    final double spread = rawMaxY - rawMinY;
    final double padding = spread == 0
        ? _fallbackPadding(rawMaxY)
        : spread * 0.2;
    final double minY = rawMinY - padding;
    final double maxY = rawMaxY + padding;
    final double interval = _computeYInterval(minY, maxY);

    final HealthRecord latestRecord = records.first;
    final HealthRecord oldestRecord = records.last;
    final double delta = latestRecord.value - oldestRecord.value;
    final bool isUpward = delta >= 0;
    final Color trendColor = isUpward ? AppColors.secondary : AppColors.primary;

    return AppCard(
      borderRadius: 32,
      padding: EdgeInsets.zero,
      gradient: LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.98),
          AppColors.surfaceTint,
          AppColors.sky.withValues(alpha: 0.12),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: IgnorePointer(child: _PetSketchBackdrop()),
          ),
          Positioned(
            top: 20,
            right: 18,
            child: Transform.rotate(
              angle: 0.08,
              child: Container(
                width: 118,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.textDisabled.withValues(alpha: 0.25),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.tr(isUpward ? 'Trend up' : 'Trend dip'),
                      style: AppTextStyles.label.copyWith(
                        color: trendColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${delta >= 0 ? '+' : ''}${_formatNumber(delta)} ${latestRecord.unit}',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('vs first snap'),
                      style: AppTextStyles.label.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _TrendSketchLabel(recordType: recordType),
                          const SizedBox(height: 12),
                          Text(title, style: AppTextStyles.title),
                          const SizedBox(height: 6),
                          Text(
                            context.tr(
                              'Range {min} - {max} {unit}',
                              params: <String, String>{
                                'min': _formatNumber(rawMinY),
                                'max': _formatNumber(rawMaxY),
                                'unit': records.first.unit,
                              },
                            ),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _AvatarPaperclipBadge(avatarPath: avatarPath),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _TrendComicChip(
                        label: context.tr('Latest'),
                        value:
                            '${_formatNumber(latestRecord.value)} ${latestRecord.unit}',
                        icon: Icons.photo_camera_back_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TrendComicChip(
                        label: context.tr('Moments'),
                        value: context.tr(
                          '{count} frames',
                          params: <String, String>{
                            'count': '${records.length}',
                          },
                        ),
                        icon: Icons.auto_awesome_motion_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: AppColors.textDisabled.withValues(alpha: 0.22),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (spots.length - 1).toDouble(),
                        minY: minY,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: interval,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: AppColors.textDisabled.withValues(
                              alpha: 0.2,
                            ),
                            strokeWidth: 1.2,
                            dashArray: const <int>[5, 4],
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            left: BorderSide(
                              color: AppColors.textDisabled.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            bottom: BorderSide(
                              color: AppColors.textDisabled.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            right: BorderSide.none,
                            top: BorderSide.none,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: interval,
                              reservedSize: 42,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                return Text(
                                  _formatNumber(value),
                                  style: AppTextStyles.label.copyWith(
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: _bottomInterval(spots.length),
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final int index = value.round();
                                if (index < 0 || index >= records.length) {
                                  return const SizedBox.shrink();
                                }

                                final DateTime date = records[index].recordedAt;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${date.month}/${date.day}',
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => AppColors.secondaryDark,
                            getTooltipItems: (List<LineBarSpot> touchedSpots) {
                              return touchedSpots.map((LineBarSpot spot) {
                                final HealthRecord record =
                                    records[spot.x.toInt()];
                                return LineTooltipItem(
                                  '${_formatNumber(record.value)} ${record.unit}\n${record.recordedAt.month}/${record.recordedAt.day}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: <LineChartBarData>[
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            gradient: LinearGradient(
                              colors: <Color>[
                                AppColors.primary,
                                AppColors.rose,
                                AppColors.accent,
                              ],
                            ),
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter:
                                  (
                                    FlSpot spot,
                                    double percent,
                                    LineChartBarData bar,
                                    int index,
                                  ) {
                                    return FlDotCirclePainter(
                                      radius: 4.2,
                                      color: AppColors.surface,
                                      strokeColor: AppColors.primaryDark,
                                      strokeWidth: 2.4,
                                    );
                                  },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: <Color>[
                                  AppColors.primary.withValues(alpha: 0.18),
                                  AppColors.accent.withValues(alpha: 0.02),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double _minDouble(double first, double second) =>
      first < second ? first : second;

  static double _maxDouble(double first, double second) =>
      first > second ? first : second;

  static double _fallbackPadding(double value) {
    final double absoluteValue = value.abs();
    if (absoluteValue >= 100) {
      return 10;
    }
    if (absoluteValue >= 10) {
      return 2;
    }
    return 0.6;
  }

  static double _computeYInterval(double minY, double maxY) {
    final double range = (maxY - minY).abs();
    if (range <= 1) {
      return 0.5;
    }
    if (range <= 5) {
      return 1;
    }
    if (range <= 20) {
      return 5;
    }
    if (range <= 100) {
      return 10;
    }
    return range / 4;
  }

  static double _bottomInterval(int spotCount) {
    if (spotCount <= 2) {
      return 1;
    }
    if (spotCount <= 4) {
      return 1;
    }
    return ((spotCount - 1) / 2).ceilToDouble();
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _TrendSketchLabel extends StatelessWidget {
  final String recordType;

  const _TrendSketchLabel({required this.recordType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.secondary.withValues(alpha: 0.42),
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.auto_stories_rounded,
            size: 14,
            color: AppColors.secondaryDark,
          ),
          const SizedBox(width: 6),
          Text(
            context.tr(
              '{recordType} story board',
              params: <String, String>{
                'recordType': context.tr(_recordTypeDisplay(recordType)),
              },
            ),
            style: AppTextStyles.label.copyWith(
              color: AppColors.secondaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendComicChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TrendComicChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sketchPaper.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.sketchInk.withValues(alpha: 0.16),
          width: 1.4,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.sketchInk),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetSketchBackdrop extends StatelessWidget {
  const _PetSketchBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PetSketchBackdropPainter());
  }
}

class _PetSketchBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint ink = Paint()
      ..color = AppColors.sketchInk.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final Paint coral = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final Paint teal = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final Path tail = Path()
      ..moveTo(size.width - 92, 42)
      ..cubicTo(size.width - 48, 4, size.width - 22, 56, size.width - 58, 62);
    canvas.drawPath(tail, teal);

    final Path ear = Path()
      ..moveTo(22, 76)
      ..quadraticBezierTo(40, 34, 62, 76)
      ..quadraticBezierTo(42, 62, 22, 76);
    canvas.drawPath(ear, coral);

    for (final Offset point in <Offset>[
      Offset(size.width - 46, 94),
      Offset(size.width - 30, 112),
      Offset(size.width - 62, 116),
      Offset(size.width - 46, 132),
    ]) {
      canvas.drawCircle(point, 4, ink);
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width - 46, 116),
        width: 22,
        height: 16,
      ),
      ink,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AvatarPaperclipBadge extends StatefulWidget {
  final String avatarPath;

  const _AvatarPaperclipBadge({required this.avatarPath});

  @override
  State<_AvatarPaperclipBadge> createState() => _AvatarPaperclipBadgeState();
}

class _AvatarPaperclipBadgeState extends State<_AvatarPaperclipBadge> {
  final ImageService _imageService = ImageService();
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(covariant _AvatarPaperclipBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarPath != widget.avatarPath) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    if (widget.avatarPath.isEmpty) {
      if (mounted) {
        setState(() {
          _avatarFile = null;
        });
      }
      return;
    }

    final File? avatarFile = await _imageService.loadImage(widget.avatarPath);
    if (!mounted) {
      return;
    }

    setState(() {
      _avatarFile = avatarFile;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.28),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _avatarFile != null
                ? Image.file(_avatarFile!, fit: BoxFit.cover)
                : Container(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.pets,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
          ),
        ),
        Positioned(
          top: -6,
          left: -8,
          child: Transform.rotate(
            angle: -0.3,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textDisabled.withValues(alpha: 0.7),
                ),
              ),
              child: const Icon(
                Icons.attach_file,
                size: 16,
                color: AppColors.secondaryDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordItem extends StatefulWidget {
  final HealthRecord record;
  final VoidCallback onTap;

  const _RecordItem({required this.record, required this.onTap});

  @override
  State<_RecordItem> createState() => _RecordItemState();
}

class _RecordItemState extends State<_RecordItem> {
  final ImageService _imageService = ImageService();
  File? _photoFile;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _RecordItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.photoPath != widget.record.photoPath) {
      _loadPhoto();
    }
  }

  Future<void> _loadPhoto() async {
    if (widget.record.photoPath.isEmpty) {
      if (mounted) {
        setState(() {
          _photoFile = null;
        });
      }
      return;
    }

    final File? photoFile = await _imageService.loadImage(
      widget.record.photoPath,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _photoFile = photoFile;
    });
  }

  @override
  Widget build(BuildContext context) {
    final HealthRecord record = widget.record;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: widget.onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForType(record.recordType),
                color: AppColors.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${_formatValue(record.value)} ${record.unit}',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (record.photoPath.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.photo_camera_outlined,
                                size: 12,
                                color: AppColors.secondaryDark,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('Photo'),
                                style: AppTextStyles.label,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (record.note.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(record.note, style: AppTextStyles.caption),
                  ],
                  if (_photoFile != null) ...<Widget>[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        _photoFile!,
                        height: 92,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Text(
                        _formatDate(record.recordedAt),
                        style: AppTextStyles.label,
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('Tap to edit'),
                        style: AppTextStyles.label,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'weight':
        return Icons.monitor_weight;
      case 'water':
        return Icons.water_drop;
      case 'exercise':
        return Icons.directions_run;
      case 'sleep':
        return Icons.bedtime;
      case 'meal':
        return Icons.restaurant;
      default:
        return Icons.favorite;
    }
  }

  String _formatDate(DateTime date) {
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '${date.month}/${date.day}  $hour:$minute';
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _AiInsightBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _AiInsightBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFFFE0B5),
            Color(0xFFF6F5FF),
            Color(0xFFDDF4EF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.secondaryDark.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.secondaryDark,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.tr('AI Health Note'),
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              splashRadius: 18,
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

String _recordTypeDisplay(String type) {
  switch (type) {
    case 'weight':
      return 'Weight';
    case 'water':
      return 'Water';
    case 'exercise':
      return 'Exercise';
    case 'sleep':
      return 'Sleep';
    case 'meal':
      return 'Meal';
    case 'vaccine':
      return 'Vaccine';
    default:
      return type.capitalize();
  }
}
