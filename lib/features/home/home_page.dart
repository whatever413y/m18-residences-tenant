import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences/bloc/billing/billing_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_state.dart';
import 'package:m18_residences/features/shell/tenant_shell.dart';
import 'package:m18_residences/utils/widgets/widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// The tenant's home: the latest bill up front (amount, status, the next step), this month's electricity against
/// last month's, and the most recent bills.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = TenantShell.of(context);
    return Scaffold(
      appBar: const TenantAppBar(title: 'Home'),
      body: BlocBuilder<BillingBloc, BillingState>(
        builder: (context, state) {
          if (state is BillingError) return ErrorView(message: state.message, onRetry: shell.refresh);
          if (state is! BillingLoaded) return const Center(child: CircularProgressIndicator());
          final bill = state.bill;
          if (bill == null) {
            return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No bill yet', message: 'Your bill shows here once it is posted.');
          }

          final hero = [_BillHero(bill: bill, onTap: shell.openStatement), const SizedBox(height: 16), _NextStep(bill: bill)];
          final side = [
            _UsageTiles(bill: bill, previous: state.previous),
            const SizedBox(height: 24),
            _RecentBills(bills: state.bills.take(4).toList()),
          ];
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: context.windowSize.isCompact ? 16 : 24, vertical: 20),
            child: ResponsiveCenter(
              maxWidth: 1100,
              child: ResponsiveBuilder(
                compact: (_) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...hero, const SizedBox(height: 24), ...side]),
                  ),
                ),
                expanded: (_) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hero),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 5,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: side),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The latest bill's amount and status on the brand color; tapping it opens the statement.
class _BillHero extends StatelessWidget {
  final Bill bill;
  final VoidCallback onTap;

  const _BillHero({required this.bill, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The brand color on light; its deep container on dark (the bright dark-theme primary would glare).
    final dark = scheme.brightness == Brightness.dark;
    final heroColor = dark ? scheme.primaryContainer : scheme.primary;
    final onHero = dark ? scheme.onPrimaryContainer : scheme.onPrimary;
    final paid = bill.status == BillStatus.paid;

    return Semantics(
      container: true,
      identifier: 'tenant-latest-total',
      child: Material(
        color: heroColor,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${billMonth(bill)} bill', style: theme.textTheme.titleSmall?.copyWith(color: onHero.withValues(alpha: 0.85))),
                    ),
                    BillStatusChip(bill.status),
                  ],
                ),
                const SizedBox(height: 14),
                Text(paid ? 'Paid in full' : 'Amount due', style: theme.textTheme.bodyMedium?.copyWith(color: onHero.withValues(alpha: 0.8))),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(bill.totalAmount, style: theme.textTheme.displaySmall?.copyWith(color: onHero, fontSize: 40)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Posted ${DateFormat.yMMMd().format(bill.createdAt)} · ${kwh(bill.consumption)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: onHero.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 12),
                Divider(color: onHero.withValues(alpha: 0.2)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('View statement', style: theme.textTheme.labelLarge?.copyWith(color: onHero)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 18, color: onHero),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the tenant should do next for the latest bill: pay and upload proof, wait for confirmation, or nothing.
class _NextStep extends StatelessWidget {
  final Bill bill;

  const _NextStep({required this.bill});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = TenantShell.of(context);
    final (container, onContainer) = StatusColors.of(context).forStatus(bill.status);

    final (IconData icon, String title, String message, List<Widget> actions) = switch (bill.status) {
      BillStatus.unpaid => (
        Icons.qr_code_scanner,
        'Pay ${formatPeso(bill.totalAmount)}',
        'Scan a QR code under Pay with GCash, Maya or BPI, then upload a screenshot of your payment.',
        [
          FilledButton.icon(onPressed: () => shell.select(TenantTab.pay), icon: const Icon(Icons.qr_code_2), label: const Text('Pay now')),
          OutlinedButton.icon(onPressed: shell.openStatement, icon: const Icon(Icons.upload), label: const Text('Upload proof')),
        ],
      ),
      BillStatus.forVerification => (
        Icons.hourglass_top,
        'Payment sent',
        'We received your proof of payment. The bill turns Paid once the owner confirms it.',
        [
          BillFileButton(
            kind: BillFileKind.payment,
            tenantName: shell.tenant.name,
            fileUrl: bill.paymentUrl,
            fetchSignedFile: shell.authApi.signedTenantPaymentUrl,
          ),
          TextButton(onPressed: shell.openStatement, child: const Text('Change payment')),
        ],
      ),
      BillStatus.paid => (
        Icons.check_circle_outline,
        'All paid',
        'Thank you! Your receipt for this bill is ready.',
        [
          BillFileButton(
            kind: BillFileKind.receipt,
            tenantName: shell.tenant.name,
            fileUrl: bill.receiptUrl,
            fetchSignedFile: shell.authApi.signedReceiptUrl,
          ),
        ],
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: container,
                  child: Icon(icon, color: onContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }
}

/// This month's consumption (with the change against the previous bill) and electricity charge.
class _UsageTiles extends StatelessWidget {
  final Bill bill;
  final Bill? previous;

  const _UsageTiles({required this.bill, required this.previous});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);
    final before = previous;

    Widget? change;
    if (before != null && before.consumption > 0) {
      final percent = ((bill.consumption - before.consumption) / before.consumption * 100).round();
      final up = percent > 0;
      final color = percent == 0 ? scheme.onSurfaceVariant : (up ? status.onVerification : status.onPaid);
      change = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(percent == 0 ? Icons.remove : (up ? Icons.arrow_upward : Icons.arrow_downward), size: 16, color: color),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              '${percent.abs()}% vs ${DateFormat.MMM().format(before.createdAt)}',
              style: theme.textTheme.labelMedium?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Tile(
            icon: Icons.bolt,
            label: 'Electricity used',
            value: kwh(bill.consumption),
            footer: change ?? Text('This month', style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Tile(
            icon: Icons.receipt_outlined,
            label: 'Electricity charge',
            value: formatPeso(bill.electricCharges),
            footer: Text(
              'Room ${formatPeso(bill.roomCharges)}',
              style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget footer;

  const _Tile({required this.icon, required this.label, required this.value, required this.footer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text(label, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontFeatures: AppTheme.tabularFigures)),
            ),
            const SizedBox(height: 6),
            footer,
          ],
        ),
      ),
    );
  }
}

class _RecentBills extends StatelessWidget {
  final List<Bill> bills;

  const _RecentBills({required this.bills});

  @override
  Widget build(BuildContext context) {
    final shell = TenantShell.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSection(
          title: 'Recent bills',
          trailing: TextButton(onPressed: () => shell.select(TenantTab.history), child: const Text('See all')),
        ),
        Card(
          child: Column(
            children: [
              for (final (i, bill) in bills.indexed) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                BillListTile(
                  bill,
                  onTap: () => showBillDetails(context, bill: bill, tenantName: shell.tenant.name, authApi: shell.authApi),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
