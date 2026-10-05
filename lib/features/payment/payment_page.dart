import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences/bloc/auth/auth_bloc.dart';
import 'package:m18_residences/bloc/auth/auth_event.dart';
import 'package:m18_residences/bloc/auth/auth_state.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class PaymentPage extends StatefulWidget {
  @override
  PaymentPageState createState() => PaymentPageState();
}

class PaymentPageState extends State<PaymentPage> {
  late AuthBloc authBloc;

  final List<Map<String, String>> paymentMethods = [
    {"name": "BPI", "icon": "assets/icons/payments/bpi.png"},
    {"name": "GCash", "icon": "assets/icons/payments/gcash.png"},
    {"name": "Maya", "icon": "assets/icons/payments/maya.png"},
  ];

  @override
  void initState() {
    super.initState();
    authBloc = context.read<AuthBloc>();
    authBloc.add(CheckAuthStatus());
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: CustomAppBar(title: "Payment Methods", centerTitle: true),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState is Unauthenticated) {
              return ErrorView(message: authState.message);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ResponsiveCenter(
                maxWidth: 960,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Tap a payment method to see its QR code. Save it to pay from your banking or wallet app.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // One card per row on phones, side by side on wider screens.
                        final cardWidth = constraints.maxWidth < WindowSize.mediumMin ? constraints.maxWidth : 280.0;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final method in paymentMethods)
                              SizedBox(width: cardWidth, child: _buildPaymentCard(context, method["name"]!, method["icon"]!)),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, String name, String iconPath) {
    final id = name.toLowerCase();
    return Semantics(
      container: true,
      identifier: 'tenant-payment-$id',
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => SignedImageDialog.show(
            context,
            fetchFile: () => authBloc.authApi.signedPaymentUrl(id),
            subject: '$name QR code',
            saveName: 'm18-$id-qr',
          ),
          child: AspectRatio(
            aspectRatio: 2.5,
            child: Image.asset(iconPath, fit: BoxFit.cover, semanticLabel: name),
          ),
        ),
      ),
    );
  }
}
