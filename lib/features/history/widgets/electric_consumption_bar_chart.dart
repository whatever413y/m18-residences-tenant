import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One bar of the chart: a usage month (the month before its bill was posted) with its consumption and current meter value.
class ConsumptionPoint {
  final DateTime date;
  final int consumption;
  final int currReading;

  const ConsumptionPoint({required this.date, required this.consumption, required this.currReading});
}

class ElectricConsumptionBarChart extends StatelessWidget {
  final List<ConsumptionPoint> completeReadings;

  /// The top of the y axis; above zero (a year without consumption still gets an axis).
  final int yMax;
  final double barWidth;

  /// Smaller axis labels, so twelve months fit on a phone.
  final bool compact;

  const ElectricConsumptionBarChart({super.key, required this.completeReadings, required this.yMax, required this.barWidth, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final reversedReadings = completeReadings.reversed.toList();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall!.copyWith(fontSize: compact ? 10 : 12, color: scheme.onSurfaceVariant);

    return BarChart(
      BarChartData(
        maxY: yMax.toDouble(),
        minY: 0,
        barGroups: reversedReadings.asMap().entries.map((entry) {
          int index = entry.key;
          int value = entry.value.consumption;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value.toDouble(),
                color: scheme.primary,
                width: barWidth,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: yMax.toDouble(), color: scheme.surfaceContainer),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            axisNameWidget: Text('kWh', style: labelStyle),
            axisNameSize: compact ? 14 : 18,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: compact ? 30 : 40,
              // yMax is a multiple of 50, so fifths are round numbers.
              interval: yMax / 5,
              getTitlesWidget: (value, meta) => Text("${value.toInt()}", style: labelStyle),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < reversedReadings.length) {
                  DateTime date = reversedReadings[index].date;
                  final label = DateFormat('MMM').format(date);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: labelStyle),
                  );
                }
                return Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yMax / 5,
          getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant, strokeWidth: 1, dashArray: [4, 4]),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${DateFormat.MMM().format(reversedReadings[group.x].date)} · ${rod.toY.toInt()} kWh',
                theme.textTheme.labelMedium!.copyWith(color: scheme.onInverseSurface, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
      ),
    );
  }
}
