import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class BillingState extends Equatable {
  @override
  List<Object?> get props => [];
}

class BillingInitial extends BillingState {}

class BillingLoading extends BillingState {}

/// The tenant's bills, newest first; empty when there are none yet.
class BillingsLoaded extends BillingState {
  final List<Bill> bills;

  BillingsLoaded(this.bills);

  @override
  List<Object?> get props => [bills];
}

/// The tenant's latest bill; `null` when there is none yet.
class BillingLoaded extends BillingState {
  final Bill? bill;

  BillingLoaded(this.bill);

  @override
  List<Object?> get props => [bill];
}

class BillingError extends BillingState {
  final String message;

  BillingError(this.message);

  @override
  List<Object?> get props => [message];
}
