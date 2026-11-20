import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AttendanceGraph extends StatelessWidget {
  final Map<int, double> weeklyHours;
  final Color cardColor;
  final Color textColor;
  final int? todayWeekday;
  final bool isIndonesian;

  const AttendanceGraph({
    super.key,
    required this.weeklyHours,
    required this.cardColor,
    required this.textColor,
    this.todayWeekday,
    this.isIndonesian = true,
  });

  @override
  Widget build(BuildContext context) {
    List<BarChartGroupData> barGroups = [];
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color barBgColor = isDark ? const Color(0xFF334155) : Colors.grey.shade100;

    double maxFound = 0;
    for (var h in weeklyHours.values) {
      if (h > maxFound) maxFound = h;
    }
    final double maxAssumed = maxFound > 10 ? (maxFound + 2).ceilToDouble() : 12.0;

    for (int i = 1; i <= 7; i++) {
      final hours = weeklyHours[i] ?? 0;
      final bool isToday = todayWeekday != null && i == todayWeekday;
      final Color rodColor = isToday
          ? const Color(0xFF10B981)
          : (hours > 0 ? Theme.of(context).colorScheme.primary : (isDark ? Colors.grey.shade700 : Colors.grey.shade300));

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: hours,
              color: rodColor,
              width: 18,
              borderRadius: BorderRadius.circular(6),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxAssumed,
                color: barBgColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAssumed,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              tooltipBorderRadius: BorderRadius.circular(8),
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String dayName;
                if (isIndonesian) {
                  const days = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
                  dayName = days[group.x.toInt()];
                } else {
                  const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                  dayName = days[group.x.toInt()];
                }
                final h = rod.toY;
                final textH = h == h.roundToDouble() ? '${h.toInt()} Jam' : '${h.toStringAsFixed(1)} Jam';
                return BarTooltipItem(
                  '$dayName\n$textH',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final isToday = todayWeekday != null && value.toInt() == todayWeekday;
                  final style = TextStyle(
                    color: isToday
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                    fontSize: 11.5,
                  );
                  String text;
                  if (isIndonesian) {
                    switch (value.toInt()) {
                      case 1: text = 'Sen'; break;
                      case 2: text = 'Sel'; break;
                      case 3: text = 'Rab'; break;
                      case 4: text = 'Kam'; break;
                      case 5: text = 'Jum'; break;
                      case 6: text = 'Sab'; break;
                      case 7: text = 'Min'; break;
                      default: text = ''; break;
                    }
                  } else {
                    switch (value.toInt()) {
                      case 1: text = 'Mon'; break;
                      case 2: text = 'Tue'; break;
                      case 3: text = 'Wed'; break;
                      case 4: text = 'Thu'; break;
                      case 5: text = 'Fri'; break;
                      case 6: text = 'Sat'; break;
                      case 7: text = 'Sun'; break;
                      default: text = ''; break;
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(text, style: style),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final hours = weeklyHours[value.toInt()] ?? 0;
                  if (hours <= 0) return const SizedBox.shrink();
                  final isToday = todayWeekday != null && value.toInt() == todayWeekday;
                  final text = hours == hours.roundToDouble()
                      ? '${hours.toInt()}h'
                      : '${hours.toStringAsFixed(1)}h';
                  return Text(
                    text,
                    style: TextStyle(
                      color: isToday
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    '${value.toInt()}h',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade500 : Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 4,
            getDrawingHorizontalLine: (value) {
              final bool isStandard8h = value == 8;
              return FlLine(
                color: isStandard8h
                    ? (isDark ? Colors.blue.withValues(alpha: 0.25) : Colors.blue.withValues(alpha: 0.2))
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                strokeWidth: isStandard8h ? 1.2 : 0.8,
                dashArray: isStandard8h ? [6, 4] : [4, 4],
              );
            },
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
