import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class PaymentState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Not loaded yet: the Pay tab loads them when first opened.
class PaymentInitial extends PaymentState {}

class PaymentLoading extends PaymentState {}

/// The ways to pay, in the owner's order.
class PaymentMethodsLoaded extends PaymentState {
  final List<PaymentMethod> methods;

  PaymentMethodsLoaded(this.methods);

  @override
  List<Object?> get props => [methods];
}

class PaymentMethodsError extends PaymentState {
  final String message;

  PaymentMethodsError(this.message);

  @override
  List<Object?> get props => [message];
}
