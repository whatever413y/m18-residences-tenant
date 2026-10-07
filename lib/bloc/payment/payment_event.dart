import 'package:equatable/equatable.dart';

abstract class PaymentEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Loads (or reloads) the payment methods.
class LoadPaymentMethods extends PaymentEvent {}
