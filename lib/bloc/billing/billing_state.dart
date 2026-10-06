import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class BillingState extends Equatable {
  @override
  List<Object?> get props => [];
}

class BillingInitial extends BillingState {}

class BillingLoading extends BillingState {}

/// The tenant's bills, newest first (empty when there are none yet); [bill] is the latest. While a payment image is
/// uploaded [uploading] is set; afterwards [uploaded] (it worked) or [uploadError] says how it went.
class BillingLoaded extends BillingState {
  final List<Bill> bills;
  final bool uploading;
  final bool uploaded;
  final String? uploadError;

  BillingLoaded(this.bills, {this.uploading = false, this.uploaded = false, this.uploadError});

  /// The latest bill, or `null` before the first one is posted.
  Bill? get bill => bills.firstOrNull;

  /// The bill before the latest one (for "vs last month").
  Bill? get previous => bills.length > 1 ? bills[1] : null;

  @override
  List<Object?> get props => [bills, uploading, uploaded, uploadError];
}

class BillingError extends BillingState {
  final String message;

  BillingError(this.message);

  @override
  List<Object?> get props => [message];
}
