import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import 'billing_event.dart';
import 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final BillApi billApi;

  BillingBloc({required this.billApi}) : super(BillingInitial()) {
    on<FetchBillingsByTenantId>(_onFetchBillingsByTenantId);
    on<UploadPayment>(_onUploadPayment);
  }

  Future<void> _onFetchBillingsByTenantId(FetchBillingsByTenantId event, Emitter<BillingState> emit) async {
    emit(BillingLoading());
    final List<Bill> bills;
    try {
      bills = await billApi.listForTenant(event.tenantId);
    } catch (e) {
      return emit(BillingError(_failureMessage('Failed to load bills', e)));
    }

    emit(BillingLoaded(bills));
  }

  /// The bills stay on screen during the upload; the server's answer is the updated bill, swapped into the list
  /// (no refetch).
  Future<void> _onUploadPayment(UploadPayment event, Emitter<BillingState> emit) async {
    final payment = event.payment;
    final bills = state is BillingLoaded ? (state as BillingLoaded).bills : [event.bill];
    emit(BillingLoaded(bills, uploading: true));
    try {
      final updated = await billApi.uploadPayment(event.bill.id, bytes: payment.bytes, filename: payment.filename, contentType: payment.contentType);
      emit(BillingLoaded([for (final b in bills) b.id == updated.id ? updated : b], uploaded: true));
    } catch (e) {
      final message = e is ApiException && e.statusCode == 409
          ? 'This bill is already paid. Refresh to see the receipt.'
          : _failureMessage('The payment upload failed', e);
      emit(BillingLoaded(bills, uploadError: message));
    }
  }

  /// Load failures are shown to the user: the HTTP status and server message for API errors, the error itself otherwise (e.g. network).
  static String _failureMessage(String action, Object error) {
    if (error is! ApiException) return '$action: $error';
    final reason = error.message.trim();
    return reason.isEmpty ? '$action (HTTP ${error.statusCode})' : '$action (HTTP ${error.statusCode}): $reason';
  }
}
