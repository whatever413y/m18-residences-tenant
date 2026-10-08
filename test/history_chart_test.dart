import 'package:flutter_test/flutter_test.dart';
import 'package:m18_residences/features/history/history_page.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

Bill _bill(int id, DateTime posted, int consumption) => Bill(
  id: id,
  tenantId: 1,
  readingId: id,
  roomCharges: 4500,
  electricCharges: consumption * 11,
  totalAmount: 4500 + consumption * 11,
  paid: false,
  createdAt: posted,
  reading: Reading(id: id, tenantId: 1, roomId: 1, prevReading: 0, currReading: consumption, consumption: consumption, createdAt: posted),
);

int _used(YearChart chart, int month) => chart.months.firstWhere((m) => m.date.month == month).consumption;

void main() {
  // Newest first, as the tenant's bills come.
  final bills = [_bill(3, DateTime(2027, 1, 5), 130), _bill(2, DateTime(2026, 10, 3), 120), _bill(1, DateTime(2026, 1, 4), 90)];

  test('a bill counts toward the month before it was posted', () {
    final chart = YearChart.of(bills, 2026);
    expect(_used(chart, 12), 130);
    expect(_used(chart, 9), 120);
    expect(_used(chart, 10), 0);
    expect(_used(chart, 1), 0);
    expect(chart.total, 250);
    expect(chart.usedMonths, 2);
    // The list stays by posting date.
    expect(chart.yearBills.map((b) => b.id), [2, 1]);
  });

  test('a January bill is the previous year\'s December', () {
    final chart = YearChart.of(bills, 2025);
    expect(_used(chart, 12), 90);
    expect(chart.yearBills, isEmpty);
  });

  test('years include usage years', () {
    expect(YearChart.yearsOf(bills, thisYear: 2026), [2027, 2026, 2025]);
  });
}
