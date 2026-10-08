import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// "October 2026": the month a bill was posted in (its room charge is for this month).
String billMonth(Bill bill) => DateFormat.yMMMM().format(bill.createdAt);

/// The month a bill's electricity was used: bills are posted early in a month for the month before's usage.
DateTime usageMonth(Bill bill) => DateTime(bill.createdAt.year, bill.createdAt.month - 1);

/// "September 2026": [usageMonth] as text.
String usageMonthLabel(Bill bill) => DateFormat.yMMMM().format(usageMonth(bill));

/// One line of a breakdown: [label] (and an optional [detail] under it) with an amount on the right.
class AmountRow extends StatelessWidget {
  final String label;
  final String? detail;
  final num amount;
  final bool emphasized;

  const AmountRow({super.key, required this.label, required this.amount, this.detail, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasized ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (detail != null) Text(detail!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          MoneyText(amount, style: style),
        ],
      ),
    );
  }
}

/// A label with a value on the right, e.g. a meter reading.
class ValueRow extends StatelessWidget {
  final String label;
  final String value;

  const ValueRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontFeatures: AppTheme.tabularFigures),
          ),
        ],
      ),
    );
  }
}

String kwh(int value) => '${formatCount(value)} kWh';

/// The bill's meter readings and every charge down to the total; [totalSemanticsId] tags the total for e2e tests.
class BillBreakdown extends StatelessWidget {
  final Bill bill;
  final String? totalSemanticsId;

  const BillBreakdown(this.bill, {super.key, this.totalSemanticsId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final charges = bill.additionalCharges.where((c) => c.amount >= 0);
    final discounts = bill.additionalCharges.where((c) => c.amount < 0);
    final total = AmountRow(label: 'Total', amount: bill.totalAmount, emphasized: true);
    final rate = bill.consumption > 0 ? bill.electricCharges / bill.consumption : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Electricity · ${usageMonthLabel(bill)}', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        ValueRow('Previous reading', kwh(bill.prevReading)),
        ValueRow('Current reading', kwh(bill.currReading)),
        ValueRow('Consumption', kwh(bill.consumption)),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
        Text('Charges', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        AmountRow(label: 'Room', amount: bill.roomCharges),
        AmountRow(
          label: 'Electricity',
          detail: rate == null ? null : '${kwh(bill.consumption)} × ${formatPeso(rate)}/kWh',
          amount: bill.electricCharges,
        ),
        for (final c in charges) AmountRow(label: c.description.isEmpty ? 'Other charge' : c.description, amount: c.amount),
        for (final c in discounts) AmountRow(label: c.description.isEmpty ? 'Discount' : c.description, detail: 'Discount', amount: c.amount),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
        if (totalSemanticsId == null) total else Semantics(container: true, identifier: totalSemanticsId, child: total),
      ],
    );
  }
}

/// A bill in a list: month, consumption, total and status; [onTap] opens it.
class BillListTile extends StatelessWidget {
  final Bill bill;
  final VoidCallback? onTap;

  const BillListTile(this.bill, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(billMonth(bill), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text('${kwh(bill.consumption)} · ${DateFormat.MMM().format(usageMonth(bill))} usage', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(bill.totalAmount, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                BillStatusChip(bill.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A bill's details in a modal (a bottom sheet on phones): status, the tenant's payment and the receipt (if any) and
/// the full breakdown.
Future<void> showBillDetails(BuildContext context, {required Bill bill, required String tenantName, required AuthApi authApi}) {
  return showAppModal<void>(
    context,
    builder: (context) => AppModal(
      overline: 'Bill',
      title: billMonth(bill),
      subtitle: 'Posted ${DateFormat.yMMMd().format(bill.createdAt)}',
      trailing: BillStatusChip(bill.status),
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bill.hasPayment || bill.hasReceipt) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BillFileButton(
                  kind: BillFileKind.payment,
                  tenantName: tenantName,
                  billId: bill.id,
                  fileUrl: bill.paymentUrl,
                  fetchSignedFile: authApi.signedBillFileUrl,
                ),
                BillFileButton(
                  kind: BillFileKind.receipt,
                  tenantName: tenantName,
                  billId: bill.id,
                  fileUrl: bill.receiptUrl,
                  fetchSignedFile: authApi.signedBillFileUrl,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          BillBreakdown(bill),
        ],
      ),
    ),
  );
}
