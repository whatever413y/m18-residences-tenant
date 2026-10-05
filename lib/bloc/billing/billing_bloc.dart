import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import 'billing_event.dart';
import 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final BillApi billApi;

  BillingBloc({required this.billApi}) : super(BillingInitial()) {
    on<FetchBillingsByTenantId>(_onFetchBillingsByTenantId);
    on<FetchBillingByTenantId>(_onFetchBillingByTenantId);
  }

  Future<void> _onFetchBillingsByTenantId(FetchBillingsByTenantId event, Emitter<BillingState> emit) async {
    emit(BillingLoading());
    final List<Bill> bills;
    try {
      bills = await billApi.listForTenant(event.tenantId);
    } catch (e) {
      return emit(BillingError(_failureMessage('Failed to load bills', e)));
    }

    emit(BillingsLoaded(bills));
  }

  Future<void> _onFetchBillingByTenantId(FetchBillingByTenantId event, Emitter<BillingState> emit) async {
    emit(BillingLoading());
    final Bill? bill;
    try {
      bill = await billApi.latestForTenant(event.tenantId);
    } catch (e) {
      return emit(BillingError(_failureMessage('Failed to load bill', e)));
    }

    emit(BillingLoaded(bill));
  }

  /// Load failures are shown to the user: the HTTP status and server message for API errors, the error itself otherwise (e.g. network).
  static String _failureMessage(String action, Object error) {
    if (error is! ApiException) return '$action: $error';
    final reason = error.message.trim();
    return reason.isEmpty ? '$action (HTTP ${error.statusCode})' : '$action (HTTP ${error.statusCode}): $reason';
  }
}
