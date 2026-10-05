import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences/bloc/auth/auth_bloc.dart';
import 'package:m18_residences/bloc/auth/auth_event.dart';
import 'package:m18_residences/bloc/auth/auth_state.dart';
import 'package:m18_residences/bloc/billing/billing_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_event.dart';
import 'package:m18_residences/bloc/billing/billing_state.dart';
import 'package:m18_residences/features/history/widgets/electric_consumption_bar_chart.dart';
import 'package:m18_residences/utils/widgets/widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class HistoryPage extends StatefulWidget {
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

  const _YearChart(this.bills, this.year, this.months, this.yMax);
}

class HistoryPageState extends State<HistoryPage> {
  late AuthBloc authBloc;
  late BillingBloc billingBloc;
  late Tenant tenant;

  /// The year shown in the chart; this year until the tenant picks another.
  int _selectedYear = DateTime.now().year;
  _YearChart? _chart;

  @override
  void initState() {
    super.initState();
    authBloc = context.read<AuthBloc>();
    authBloc.add(CheckAuthStatus());
    tenant = authBloc.cachedTenant!;
    billingBloc = context.read<BillingBloc>();
    _fetch();
  }

  void _fetch() => billingBloc.add(FetchBillingsByTenantId(tenant.id));

  _YearChart _chartFor(List<Bill> bills) {
    final cached = _chart;
    if (cached != null && identical(cached.bills, bills) && cached.year == _selectedYear) return cached;

    final months = List.generate(12, (index) {
      final month = 12 - index;
      // Bills come newest first, so a month with several bills shows its latest.
      final bill = bills.where((b) => b.createdAt.year == _selectedYear && b.createdAt.month == month).firstOrNull;
      return ConsumptionPoint(date: DateTime(_selectedYear, month), consumption: bill?.consumption ?? 0, currReading: bill?.currReading ?? 0);
    });
    final highest = months.map((m) => m.consumption).fold(0, math.max);
    // Rounded up to a multiple of 50, at least 50, so the axis has room and never collapses to zero.
    final yMax = math.max(50, (highest / 50).ceil() * 50);
    return _chart = _YearChart(bills, _selectedYear, months, yMax);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        appBar: CustomAppBar(title: "Billing History", subtitle: tenant.name, centerTitle: true, showRefresh: true, onRefresh: _fetch),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState is Unauthenticated) {
              return ErrorView(message: authState.message);
            }

            return BlocBuilder<BillingBloc, BillingState>(
              builder: (context, billingState) {
                if (billingState is BillingError) {
                  return ErrorView(message: billingState.message, onRetry: _fetch);
                }
                if (billingState is! BillingsLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }
                final bills = billingState.bills;
                if (bills.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No bills yet. They show here once they are posted.', textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(onPressed: _fetch, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
                        ],
                      ),
                    ),
                  );
                }

                final years = {DateTime.now().year, ...bills.map((b) => b.createdAt.year)}.toList()..sort((a, b) => b.compareTo(a));
                return ResponsiveCenter(
                  maxWidth: 900,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.windowSize.isCompact ? 12 : 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(alignment: Alignment.centerRight, child: _buildYearSelector(years)),
                        const SizedBox(height: 8),
                        _buildGraph(_chartFor(bills)),
                        const SizedBox(height: 8),
                        Expanded(child: _buildBillingHistory(bills)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildYearSelector(List<int> years) {
    return SizedBox(
      width: 120,
      child: CustomDropdownForm<int>(
        label: 'Year',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        value: _selectedYear,
        onChanged: (year) {
          if (year != null) setState(() => _selectedYear = year);
        },
        items: years.map((year) => DropdownMenuItem<int>(value: year, child: Text('$year'))).toList(),
      ),
    );
  }

  Widget _buildGraph(_YearChart chart) {
    return SizedBox(
      height: 180,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // All twelve months fit the width the chart gets: thinner bars and smaller labels on phones.
          final compact = WindowSize.fromWidth(constraints.maxWidth).isCompact;
          final barWidth = (constraints.maxWidth / 12 * 0.5).clamp(8.0, 30.0);
          return Padding(
            padding: const EdgeInsets.only(top: 5, right: 8),
            child: ElectricConsumptionBarChart(completeReadings: chart.months, yMax: chart.yMax, barWidth: barWidth, compact: compact),
          );
        },
      ),
    );
  }

  Widget _buildBillingHistory(List<Bill> bills) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final bill = bills[index];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => showDialog(context: context, builder: (_) => _buildBillDialog(context, bill)),
                child: buildBillCardWidget(bill, context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBillDialog(BuildContext context, Bill bill) {
    return AlertDialog(
      insetPadding: context.windowSize.isCompact ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      title: const Text("Billing Details", style: TextStyle(fontWeight: FontWeight.bold)),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600, maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      "Posting Date: ${DateFormat.yMMMMd().format(bill.createdAt)}",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        bill.paid ? "Paid" : "Unpaid",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: bill.paid ? Colors.green : Colors.red),
                      ),
                      if (bill.hasReceipt) ...[
                        const SizedBox(height: 8),
                        ReceiptLink(tenantName: tenant.name, receiptUrl: bill.receiptUrl, fetchSignedFile: authBloc.authApi.signedReceiptUrl),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(thickness: 1.2),
              const SizedBox(height: 12),

              buildReadingItemWidget("Previous Reading", bill.prevReading),
              const SizedBox(height: 8),
              buildReadingItemWidget("Current Reading", bill.currReading),
              const SizedBox(height: 8),
              buildReadingItemWidget("Consumption", bill.consumption),

              const SizedBox(height: 12),
              const Divider(thickness: 1.2),
              const SizedBox(height: 12),

              buildBillItemWidget("Room", bill.roomCharges),
              const SizedBox(height: 8),

              ...buildChargesDetails(bill.electricCharges, bill.additionalCharges),

              const SizedBox(height: 12),
              const Divider(thickness: 1.2),
              const SizedBox(height: 12),

              // Total
              buildBillItemWidget("Total Amount", bill.totalAmount, isTotal: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
