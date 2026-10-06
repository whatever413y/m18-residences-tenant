import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences/bloc/auth/auth_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_event.dart';
import 'package:m18_residences/bloc/billing/billing_state.dart';
import 'package:m18_residences/features/billing/payment_section.dart';
import 'package:m18_residences/utils/widgets/widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// The latest bill's statement: status, readings, every charge and the total, then the payment section.
class BillingPage extends StatelessWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final tenant = authBloc.cachedTenant!;
    final billingBloc = context.read<BillingBloc>();
    void refresh() => billingBloc.add(FetchBillingsByTenantId(tenant.id));

    return Scaffold(
      appBar: CustomAppBar(title: 'Statement', subtitle: tenant.name, showRefresh: true, onRefresh: refresh),
      body: BlocConsumer<BillingBloc, BillingState>(
        // Announce a finished payment upload (it also shows under the buttons).
        listenWhen: (previous, current) => current is BillingLoaded && current.uploaded && !(previous is BillingLoaded && previous.uploaded),
        listener: (context, _) =>
            AppToast.show(context, 'The owner will confirm it and attach a receipt.', title: 'Payment uploaded', type: ToastType.success),
        builder: (context, state) {
          if (state is BillingError) return ErrorView(message: state.message, onRetry: refresh);
          if (state is! BillingLoaded) return const Center(child: CircularProgressIndicator());
          final bill = state.bill;
          if (bill == null) {
            return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No bill yet', message: 'Your bill shows here once it is posted.');
          }

          final theme = Theme.of(context);
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: context.windowSize.isCompact ? 16 : 24, vertical: 20),
            child: ResponsiveCenter(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(billMonth(bill), style: theme.textTheme.headlineSmall),
                                    const SizedBox(height: 4),
                                    Text('Posted ${DateFormat.yMMMMd().format(bill.createdAt)}', style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Semantics(container: true, identifier: 'tenant-bill-status', child: BillStatusChip(bill.status, large: true)),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                          BillBreakdown(bill),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PaymentSection(
                    bill: bill,
                    tenantName: tenant.name,
                    authApi: authBloc.authApi,
                    uploading: state.uploading,
                    uploaded: state.uploaded,
                    uploadError: state.uploadError,
                    onUpload: (payment) => billingBloc.add(UploadPayment(bill, payment)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
