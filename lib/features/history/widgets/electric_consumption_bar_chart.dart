import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One bar of the chart: a bill's posting date with its reading's consumption and current meter value.
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
    final labelStyle = TextStyle(fontSize: compact ? 10 : 14);

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
                color: Colors.blue,
                width: barWidth,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: yMax.toDouble(), color: Colors.grey.withAlpha(50)),
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
                  return Text(DateFormat("MMM").format(date).toUpperCase(), style: labelStyle);
                }
                return Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        gridData: FlGridData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: EdgeInsets.all(4),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem("${rod.toY.toInt()} kWh", TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
            },
          ),
        ),
      ),
    );
  }
}
