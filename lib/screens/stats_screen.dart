import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../services/theme_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static Color get surface => ThemeService().currentTheme.surface;
  static Color get border  => ThemeService().currentTheme.border;
  static Color get text    => ThemeService().currentTheme.text;
  static Color get sub     => ThemeService().currentTheme.subText;
  static Color get dim     => ThemeService().currentTheme.subText.withAlpha(153);
  static Color get accent  => ThemeService().currentTheme.accent;
  static const green   = Color(0xFF4CAF7D);
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class StatsScreen extends StatefulWidget {
  final String uid;
  const StatsScreen({super.key, required this.uid});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<TaskModel> _allTasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    TaskService().tasksStream(widget.uid).listen((tasks) {
      if (!mounted) return;
      setState(() {
        _allTasks = tasks;
        _loading = false;
      });
    });
  }

  // ── derived ───────────────────────────────────────────────────────────────
  static DateTime _dayOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  List<TaskModel> get _done =>
      _allTasks.where((t) => t.isDone).toList();

  /// Count of tasks completed on each of the last 7 days (oldest → newest)
  List<int> get _weekCounts {
    final today = _dayOnly(DateTime.now());
    return List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return _done
          .where((t) =>
              t.completedAt != null && _dayOnly(t.completedAt!) == d)
          .length;
    });
  }

  int get _weekTotal =>
      _weekCounts.fold(0, (a, b) => a + b);

  int get _bestDay =>
      _weekCounts.fold(0, math.max);

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: _C.accent, strokeWidth: 2));
    }

    final counts  = _weekCounts;
    final maxVal  = counts.fold(0, math.max).toDouble();
    final todayWD = DateTime.now().weekday; // 1=Mon … 7=Sun
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [

        // ── Header ────────────────────────────────────────────────────────
        Text(
          'Weekly Stats',
          style: TextStyle(
              color: _C.text,
              fontSize: 22,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Tasks you completed in the last 7 days',
          style: TextStyle(color: _C.sub, fontSize: 13),
        ),

        const SizedBox(height: 24),

        // ── Summary row ───────────────────────────────────────────────────
        Row(
          children: [
            _summaryCard('$_weekTotal', 'This week', _C.accent),
            const SizedBox(width: 12),
            _summaryCard('$_bestDay', 'Best day', _C.green),
          ],
        ),

        const SizedBox(height: 24),

        // ── Bar chart ─────────────────────────────────────────────────────
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.border),
          ),
          child: BarChart(
            BarChartData(
              maxY: maxVal < 1 ? 4 : maxVal + 1,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => _C.surface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final n = rod.toY.toInt();
                    return BarTooltipItem(
                      n == 0 ? '—' : '$n task${n == 1 ? '' : 's'}',
                      TextStyle(
                          color: _C.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (val, meta) {
                      final i = val.toInt();
                      if (i < 0 || i > 6) return const SizedBox();
                      // index 0 = 6 days ago, index 6 = today
                      final wdIndex = (todayWD - 1 - (6 - i) + 7) % 7;
                      final isToday = i == 6;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          dayLetters[wdIndex],
                          style: TextStyle(
                            color: isToday ? _C.accent : _C.dim,
                            fontSize: 12,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (i) {
                final count  = counts[i].toDouble();
                final isToday = i == 6;
                final isBest  = count > 0 && count == maxVal;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: count,
                      width: 28,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6)),
                      color: count == 0
                          ? _C.border
                          : isToday
                              ? _C.accent
                              : isBest
                                  ? _C.green
                                  : _C.accent.withAlpha(102),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(_C.accent, 'Today'),
            const SizedBox(width: 16),
            _legend(_C.green, 'Best day'),
            const SizedBox(width: 16),
            _legend(_C.accent.withAlpha(102), 'Other days'),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: _C.dim, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: _C.dim, fontSize: 11)),
      ],
    );
  }
}
