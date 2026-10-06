import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_state.dart';
import 'package:m18_residences/features/shell/tenant_shell.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// How to pay: the three steps, the payment methods (each opens its QR code) and a shortcut to upload the proof.
class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  static const _methods = [
    ('BPI', 'assets/icons/payments/bpi.png'),
    ('GCash', 'assets/icons/payments/gcash.png'),
    ('Maya', 'assets/icons/payments/maya.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = TenantShell.of(context);
    return Scaffold(
      appBar: const TenantAppBar(title: 'Pay', showRefresh: false),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: context.windowSize.isCompact ? 16 : 24, vertical: 20),
        child: ResponsiveCenter(
          maxWidth: 960,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlocBuilder<BillingBloc, BillingState>(
                builder: (context, state) {
                  final bill = state is BillingLoaded ? state.bill : null;
                  final due = bill != null && bill.status == BillStatus.unpaid;
                  return _Steps(amountDue: due ? bill.totalAmount : null);
                },
              ),
              const SizedBox(height: 24),
              const AppSection(title: 'Payment methods', subtitle: 'Tap one to see its QR code. Save it to pay from your banking or wallet app.'),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Compact rows on phones, three cards with the full logo side by side on wider screens.
                  final compact = constraints.maxWidth < WindowSize.mediumMin;
                  final columns = compact ? 1 : 3;
                  final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 16,
                    runSpacing: compact ? 12 : 16,
                    children: [
                      for (final (name, icon) in _methods)
                        SizedBox(
                          width: width,
                          child: _MethodCard(name: name, iconPath: icon, compact: compact),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.upload, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  title: const Text('Already paid?'),
                  subtitle: const Text('Upload your proof of payment on the statement.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: shell.openStatement,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  final int? amountDue;

  const _Steps({required this.amountDue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final steps = [
      ('Scan', 'Open a QR code below in your banking or wallet app.'),
      ('Pay', amountDue == null ? 'Send the amount of your bill.' : 'Send ${formatPeso(amountDue!)}, the amount of your bill.'),
      ('Upload proof', 'Upload a screenshot of the payment on your statement.'),
    ];
    Widget step(int i) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: scheme.primary,
          child: Text(
            '${i + 1}',
            style: theme.textTheme.labelMedium?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(steps[i].$1, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(steps[i].$2, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );

    return Card(
      color: scheme.primaryContainer.withValues(alpha: scheme.brightness == Brightness.light ? 0.45 : 0.35),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ResponsiveBuilder(
          compact: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < steps.length; i++) ...[if (i > 0) const SizedBox(height: 16), step(i)],
            ],
          ),
          medium: (_) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[if (i > 0) const SizedBox(width: 20), Expanded(child: step(i))],
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String name;
  final String iconPath;

  /// A row with a small logo (phones) instead of a card with the full logo.
  final bool compact;

  const _MethodCard({required this.name, required this.iconPath, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = TenantShell.of(context);
    final id = name.toLowerCase();
    return Semantics(
      container: true,
      identifier: 'tenant-payment-$id',
      child: Card(
        child: InkWell(
          onTap: () =>
              SignedImageDialog.show(context, fetchFile: () => shell.authApi.signedPaymentUrl(id), subject: '$name QR code', saveName: 'm18-$id-qr'),
          child: compact ? _row(theme) : _card(theme),
        ),
      ),
    );
  }

  /// The logo on white: the logos are made for a white background, also in dark mode.
  Widget _logo() => ColoredBox(
    color: Colors.white,
    child: AspectRatio(
      aspectRatio: 2.5,
      child: Image.asset(iconPath, fit: BoxFit.cover, semanticLabel: name),
    ),
  );

  Widget _showQr(ThemeData theme) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Show QR', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
      const SizedBox(width: 4),
      Icon(Icons.qr_code_2, size: 20, color: theme.colorScheme.primary),
    ],
  );

  Widget _card(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _logo(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(child: Text(name, style: theme.textTheme.titleSmall)),
            _showQr(theme),
          ],
        ),
      ),
    ],
  );

  Widget _row(ThemeData theme) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 90, child: _logo()),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(name, style: theme.textTheme.titleSmall)),
        _showQr(theme),
      ],
    ),
  );
}
