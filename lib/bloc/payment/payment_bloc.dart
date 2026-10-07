import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import 'payment_event.dart';
import 'payment_state.dart';

/// The payment methods the owner set up (name, account, QR code), for the Pay tab.
class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PaymentApi paymentApi;

  PaymentBloc({required this.paymentApi}) : super(PaymentInitial()) {
    on<LoadPaymentMethods>((event, emit) async {
      emit(PaymentLoading());
      try {
        emit(PaymentMethodsLoaded(await paymentApi.list()));
      } catch (e) {
        emit(PaymentMethodsError('Could not load the payment methods: ${e is ApiException ? e.message : e}'));
      }
    });
  }
}
