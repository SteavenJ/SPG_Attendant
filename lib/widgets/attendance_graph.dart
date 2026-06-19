import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AttendanceGraph extends StatelessWidget {
  final Map<int, double> weeklyHours;
  final Color cardColor;
  final Color textColor;

  const AttendanceGraph({
    Key? key,
    required this.weeklyHours,
    required this.cardColor,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<BarChartGroupData> barGroups = [];
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color barBgColor = isDark ? const Color(0xFF334155) : Colors.grey.shade100;
    
    for (int i = 1; i <= 7; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: weeklyHours[i] ?? 0,
              color: Theme.of(context).colorScheme.primary,
              width: 16,
              borderRadius: BorderRadius.circular(6),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 12, // Max assumed hours
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
            color: isDark ? Colors.black54 : Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 12,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final style = TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12);
                  String text;
                  switch (value.toInt()) {
                    case 1: text = 'M'; break;
                    case 2: text = 'T'; break;
                    case 3: text = 'W'; break;
                    case 4: text = 'T'; break;
                    case 5: text = 'F'; break;
                    case 6: text = 'S'; break;
                    case 7: text = 'S'; break;
                    default: text = ''; break;
                  }
                  return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(text, style: style));
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}h', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey, fontSize: 10));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false), // Clean look, no grid lines
          borderData: FlBorderData(show: false), // No borders
        ),
      ),
    );
  }
}
