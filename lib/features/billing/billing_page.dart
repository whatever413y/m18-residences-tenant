import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences/bloc/auth/auth_bloc.dart';
import 'package:m18_residences/bloc/auth/auth_event.dart';
import 'package:m18_residences/bloc/auth/auth_state.dart';
import 'package:m18_residences/bloc/billing/billing_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_event.dart';
import 'package:m18_residences/bloc/billing/billing_state.dart';
import 'package:m18_residences/features/billing/payment_section.dart';
import 'package:m18_residences/utils/widgets/widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class BillingPage extends StatefulWidget {
  @override
  BillingPageState createState() => BillingPageState();
}

class BillingPageState extends State<BillingPage> {
  late AuthBloc authBloc;
  late BillingBloc billingBloc;
  late Tenant tenant;
  Bill? bill;

  @override
  void initState() {
    super.initState();
    authBloc = context.read<AuthBloc>();
    authBloc.add(CheckAuthStatus());
    tenant = authBloc.cachedTenant!;
    billingBloc = context.read<BillingBloc>();
    billingBloc.add(FetchBillingByTenantId(tenant.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: CustomAppBar(
          title: "Billing Statement",
          subtitle: tenant.name,
          centerTitle: true,
          showRefresh: true,
          onRefresh: () {
            billingBloc.add(FetchBillingByTenantId(tenant.id));
          },
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final isMobile = WindowSize.fromWidth(maxWidth).isCompact;
            final contentWidth = isMobile ? maxWidth : 600.0;

            return BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                if (authState is Unauthenticated) {
                  return ErrorView(message: authState.message);
                }

                return BlocBuilder<BillingBloc, BillingState>(
                  builder: (context, billingState) {
                    if (billingState is BillingLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (billingState is BillingError) {
                      return ErrorView(message: billingState.message, onRetry: () => billingBloc.add(FetchBillingByTenantId(tenant.id)));
                    } else if (billingState is BillingLoaded) {
                      bill = billingState.bill;
                      if (bill == null) {
                        return const Center(
                          child: Padding(padding: EdgeInsets.all(24), child: Text('No bill yet. It shows here once it is posted.')),
                        );
                      }

                      return Center(
                        child: SingleChildScrollView(
                          child: Container(
                            width: contentWidth,
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 24.0, vertical: 16.0),
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Column(
                              children: [
                                _buildBillCard(bill!, isMobile),
                                const SizedBox(height: 16),
                                PaymentSection(
                                  bill: bill!,
                                  tenantName: tenant.name,
                                  authApi: authBloc.authApi,
                                  uploading: billingState.uploading,
                                  uploaded: billingState.uploaded,
                                  uploadError: billingState.uploadError,
                                  onUpload: (payment) => billingBloc.add(UploadPayment(bill!, payment)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return const SizedBox();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBillCard(Bill bill, bool isMobile) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    "Latest Bill",
                    style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(container: true, identifier: 'tenant-bill-status', child: BillStatusChip(bill.status)),
              ],
            ),

            Divider(thickness: 1.2),

            buildReadingItemWidget("Previous Reading", bill.prevReading),
            buildReadingItemWidget("Current Reading", bill.currReading),
            buildReadingItemWidget("Consumption", bill.consumption),

            Divider(thickness: 1.2),

            buildBillItemWidget("Room", bill.roomCharges),

            ...buildChargesDetails(bill.electricCharges, bill.additionalCharges),

            Divider(thickness: 1.2),

            buildBillItemWidget("Total Amount", bill.totalAmount, isTotal: true),

            SizedBox(height: isMobile ? 12 : 15),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "Date Posted: ${DateFormat.yMMMMd().format(bill.createdAt)}",
                style: TextStyle(fontSize: isMobile ? 14 : 18, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
