import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class BillingEvent extends Equatable {
  @override
  List<Object> get props => [];
}

/// Loads all of the tenant's bills (one request; the home, statement and history all read them).
class FetchBillingsByTenantId extends BillingEvent {
  final int tenantId;

  FetchBillingsByTenantId(this.tenantId);

  @override
  List<Object> get props => [tenantId];
}

/// Uploads the tenant's proof of payment (picked and converted on the page) for the shown latest bill.
class UploadPayment extends BillingEvent {
  final Bill bill;
  final PreparedReceipt payment;

  UploadPayment(this.bill, this.payment);

  @override
  List<Object> get props => [bill, payment];
}
