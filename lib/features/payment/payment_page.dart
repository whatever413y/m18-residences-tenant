import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_state.dart';
import 'package:m18_residences/bloc/payment/payment_bloc.dart';
import 'package:m18_residences/bloc/payment/payment_event.dart';
import 'package:m18_residences/bloc/payment/payment_state.dart';
import 'package:m18_residences/features/shell/tenant_shell.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// How to pay: the three steps, the owner's payment methods (each with its account and QR code) and a shortcut to
/// upload the proof.
class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = TenantShell.of(context);
    return Scaffold(
      appBar: const TenantAppBar(title: 'Pay'),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: context.windowSize.isCompact ? 16 : 24, vertical: 20),
        child: ResponsiveCenter(
          maxWidth: context.windowSize.isLarge ? 1200 : 960,
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
              const AppSection(
                title: 'Payment methods',
                subtitle: 'Tap one to see its QR code (save it to pay from your banking or wallet app), or send to its account number.',
              ),
              BlocBuilder<PaymentBloc, PaymentState>(
                builder: (context, state) {
                  if (state is PaymentMethodsError) {
                    return ErrorView(message: state.message, onRetry: () => context.read<PaymentBloc>().add(LoadPaymentMethods()));
                  }
                  if (state is! PaymentMethodsLoaded) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (state.methods.isEmpty) {
                    return const EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No payment methods yet',
                      message: 'Ask the owner how to pay this month.',
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Compact rows on phones, cards with the full logo side by side on wider screens.
                      final compact = constraints.maxWidth < WindowSize.mediumMin;
                      final columns = compact ? 1 : 3;
                      final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 16,
                        runSpacing: compact ? 12 : 16,
                        children: [
                          for (final method in state.methods)
                            SizedBox(
                              width: width,
                              child: _MethodCard(method: method, compact: compact),
                            ),
                        ],
                      );
                    },
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
      ('Scan or send', 'Open a QR code below in your banking or wallet app, or send to the account number.'),
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
  final PaymentMethod method;

  /// A row with a small logo (phones) instead of a card with the full logo.
  final bool compact;

  const _MethodCard({required this.method, this.compact = false});

  /// Logos bundled for the usual methods, by their slug; others get a tile with their name.
  static const _logos = {
    'bpi': 'assets/icons/payments/bpi.png',
    'gcash': 'assets/icons/payments/gcash.png',
    'maya': 'assets/icons/payments/maya.png',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = TenantShell.of(context);
    final slug = method.slug;
    return Semantics(
      container: true,
      identifier: 'tenant-payment-$slug',
      child: Card(
        child: InkWell(
          onTap: method.hasImage
              ? () => SignedImageDialog.show(
                  context,
                  fetchFile: () => shell.authApi.signedPaymentMethodUrl(method.id),
                  subject: '${method.name} QR code',
                  saveName: 'm18-$slug-qr',
                )
              : null,
          child: compact ? _row(context, theme) : _card(context, theme),
        ),
      ),
    );
  }

  /// The bundled logo on white (the logos are made for a white background, also in dark mode), or a tile with the
  /// method's name.
  Widget _logo(ThemeData theme, {required bool small}) {
    final asset = _logos[method.slug];
    if (asset != null) {
      return ColoredBox(
        color: Colors.white,
        child: AspectRatio(
          aspectRatio: 2.5,
          child: Image.asset(asset, fit: BoxFit.cover, semanticLabel: method.name),
        ),
      );
    }
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: scheme.primaryContainer,
      child: AspectRatio(
        aspectRatio: 2.5,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: small
                ? Icon(Icons.account_balance_outlined, color: scheme.onPrimaryContainer)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_outlined, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          method.name,
                          style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// "Show QR" (just the QR icon in a phone's row, so the account number keeps its line).
  Widget _showQr(ThemeData theme) {
    if (!method.hasImage) {
      if (compact) return Icon(Icons.qr_code_2, color: theme.colorScheme.outlineVariant, semanticLabel: 'No QR code');
      return Text('No QR code', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    if (compact) return Icon(Icons.qr_code_2, color: theme.colorScheme.primary, semanticLabel: 'Show QR');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Show QR', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(width: 4),
        Icon(Icons.qr_code_2, size: 20, color: theme.colorScheme.primary),
      ],
    );
  }

  /// The name with the account to send to (copy button on the number).
  Widget _details(BuildContext context, ThemeData theme) {
    final number = method.accountNumber;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(method.name, style: theme.textTheme.titleSmall),
        if (method.accountName != null) Text(method.accountName!, style: muted),
        if (number != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(number, style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: AppTheme.tabularFigures)),
              ),
              IconButton(
                tooltip: 'Copy account number',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: number));
                  if (context.mounted) AppToast.show(context, 'Account number copied', type: ToastType.success);
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _card(BuildContext context, ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _logo(theme, small: false),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _details(context, theme)),
            Padding(padding: const EdgeInsets.only(top: 2), child: _showQr(theme)),
          ],
        ),
      ),
    ],
  );

  Widget _row(BuildContext context, ThemeData theme) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 90, child: _logo(theme, small: true)),
        ),
        const SizedBox(width: 14),
        Expanded(child: _details(context, theme)),
        _showQr(theme),
      ],
    ),
  );
}
