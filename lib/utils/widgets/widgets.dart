import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

Widget buildBillItemWidget(String label, int amount, {bool isTotal = false}) {
  final currencyFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: isTotal ? 18 : 16, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal),
            softWrap: true,
          ),
        ),

        const SizedBox(width: 8),

        Text(
          currencyFormat.format(amount),
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.blue.shade900 : Colors.black87,
          ),
        ),
      ],
    ),
  );
}

Widget buildReadingItemWidget(String label, int value) {
  final numberFormat = NumberFormat.decimalPattern();

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700]), softWrap: true),
        ),
        const SizedBox(width: 8),
        Text("${numberFormat.format(value)} kWh", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

/// [totalSemanticsId] tags the "Total Amount" row for browser e2e tests (`flt-semantics-identifier`).
Widget buildBillCardWidget(Bill bill, BuildContext context, {String? totalSemanticsId}) {
  final total = buildBillItemWidget("Total Amount", bill.totalAmount, isTotal: true);

  return Card(
    elevation: 4,
    margin: EdgeInsets.symmetric(vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "Posting Date: ${DateFormat.yMMMMd().format(bill.createdAt)}",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
              ),
              const SizedBox(width: 8),
              BillStatusChip(bill.status),
            ],
          ),
          Divider(),
          buildReadingItemWidget("Consumption", bill.consumption),
          Divider(),
          if (totalSemanticsId == null) total else Semantics(container: true, identifier: totalSemanticsId, child: total),
        ],
      ),
    ),
  );
}

List<Widget> buildChargesDetails(int electricCharges, List<AdditionalCharge> charges) {
  final currencyFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);
  final additionalCharges = charges.where((c) => c.amount >= 0).toList();
  final discounts = charges.where((c) => c.amount < 0).toList();

  List<Widget> detailRows = [];

  detailRows.add(const SizedBox(height: 12));
  detailRows.add(const Text('Additional Charges', style: TextStyle(fontWeight: FontWeight.normal, fontSize: 16)));
  detailRows.add(const SizedBox(height: 8));
  detailRows.add(buildChargeRow("Electricity", currencyFormat.format(electricCharges)));

  for (final charge in additionalCharges) {
    detailRows.add(buildChargeRow(charge.description, currencyFormat.format(charge.amount)));
  }

  if (discounts.isNotEmpty) {
    detailRows.add(const SizedBox(height: 16));
    detailRows.add(const Text('Discounts', style: TextStyle(fontWeight: FontWeight.normal, fontSize: 16)));
    detailRows.add(const SizedBox(height: 8));

    for (final charge in discounts) {
      detailRows.add(buildChargeRow(charge.description, currencyFormat.format(charge.amount.abs())));
    }
  }

  if (electricCharges > 0 || charges.isNotEmpty) {
    final subtotal = electricCharges + charges.fold<double>(0.0, (sum, c) => sum + c.amount);

    detailRows.add(const SizedBox(height: 8));

    detailRows.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Subtotal", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(currencyFormat.format(subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  return detailRows;
}

Widget buildChargeRow(String description, String amount) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            description.isNotEmpty ? description : '-',
            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
        Text(amount),
      ],
    ),
  );
}
