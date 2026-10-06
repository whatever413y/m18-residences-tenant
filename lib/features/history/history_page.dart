import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_state.dart';
import 'package:m18_residences/features/history/widgets/electric_consumption_bar_chart.dart';
import 'package:m18_residences/features/shell/tenant_shell.dart';
import 'package:m18_residences/utils/widgets/widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// A year of electricity use as a chart, and that year's bills.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  HistoryPageState createState() => HistoryPageState();
}

/// The year's chart data, recomputed only when the bills or the year change.
class _YearChart {
  final List<Bill> bills;
  final int year;

  /// Twelve points, December first (zeros for months without a bill).
  final List<ConsumptionPoint> months;
  final int yMax;

  /// The year's bills, newest first.
  final List<Bill> yearBills;

  const _YearChart(this.bills, this.year, this.months, this.yMax, this.yearBills);

  int get total => yearBills.fold(0, (sum, b) => sum + b.consumption);
}

class HistoryPageState extends State<HistoryPage> {
  /// The year shown; this year until the tenant picks another.
  int _selectedYear = DateTime.now().year;
  _YearChart? _chart;

  _YearChart _chartFor(List<Bill> bills) {
    final cached = _chart;
    if (cached != null && identical(cached.bills, bills) && cached.year == _selectedYear) return cached;

    final yearBills = bills.where((b) => b.createdAt.year == _selectedYear).toList();
    final months = List.generate(12, (index) {
      final month = 12 - index;
      // Bills come newest first, so a month with several bills shows its latest.
      final bill = yearBills.where((b) => b.createdAt.month == month).firstOrNull;
      return ConsumptionPoint(date: DateTime(_selectedYear, month), consumption: bill?.consumption ?? 0, currReading: bill?.currReading ?? 0);
    });
    final highest = months.map((m) => m.consumption).fold(0, math.max);
    // Rounded up to a multiple of 50, at least 50, so the axis has room and never collapses to zero.
    final yMax = math.max(50, (highest / 50).ceil() * 50);
    return _chart = _YearChart(bills, _selectedYear, months, yMax, yearBills);
  }

  @override
  Widget build(BuildContext context) {
    final shell = TenantShell.of(context);
    return Scaffold(
      appBar: const TenantAppBar(title: 'History'),
      body: BlocBuilder<BillingBloc, BillingState>(
        builder: (context, state) {
          if (state is BillingError) return ErrorView(message: state.message, onRetry: shell.refresh);
          if (state is! BillingLoaded) return const Center(child: CircularProgressIndicator());
          final bills = state.bills;
          if (bills.isEmpty) {
            return EmptyState(
              icon: Icons.insights_outlined,
              title: 'No bills yet',
              message: 'Your bills and electricity use show here once they are posted.',
              action: OutlinedButton.icon(onPressed: shell.refresh, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
            );
          }

          final years = {DateTime.now().year, ...bills.map((b) => b.createdAt.year)}.toList()..sort((a, b) => b.compareTo(a));
          final chart = _chartFor(bills);
          final compact = context.windowSize.isCompact;
          final yearBills = chart.yearBills;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24, vertical: 20),
            child: ResponsiveCenter(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildYearChips(years),
                  const SizedBox(height: 16),
                  _buildChartCard(context, chart),
                  const SizedBox(height: 24),
                  AppSection(title: 'Bills in ${chart.year}', subtitle: '${yearBills.length} ${yearBills.length == 1 ? 'bill' : 'bills'}'),
                  // At most twelve bills a year, so one card (not a lazy list).
                  Card(
                    child: yearBills.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('No bills in ${chart.year}.', style: Theme.of(context).textTheme.bodyMedium),
                          )
                        : Column(
                            children: [
                              for (final (i, bill) in yearBills.indexed) ...[
                                if (i > 0) const Divider(indent: 16, endIndent: 16),
                                BillListTile(
                                  bill,
                                  onTap: () => showBillDetails(context, bill: bill, tenantName: shell.tenant.name, authApi: shell.authApi),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildYearChips(List<int> years) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final year in years)
          ChoiceChip(label: Text('$year'), selected: year == _selectedYear, onSelected: (_) => setState(() => _selectedYear = year)),
      ],
    );
  }

  Widget _buildChartCard(BuildContext context, _YearChart chart) {
    final theme = Theme.of(context);
    final months = chart.yearBills.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Electricity use', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text('${kwh(chart.total)} in ${chart.year}', style: theme.textTheme.bodySmall),
                if (months > 0) Text('avg ${kwh((chart.total / months).round())} a month', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // All twelve months fit the width the chart gets: thinner bars and smaller labels on phones.
                  final compact = WindowSize.fromWidth(constraints.maxWidth).isCompact;
                  final barWidth = (constraints.maxWidth / 12 * 0.55).clamp(8.0, 28.0);
                  return ElectricConsumptionBarChart(completeReadings: chart.months, yMax: chart.yMax, barWidth: barWidth, compact: compact);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
