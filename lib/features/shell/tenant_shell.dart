import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences/bloc/auth/auth_bloc.dart';
import 'package:m18_residences/bloc/auth/auth_state.dart';
import 'package:m18_residences/bloc/billing/billing_bloc.dart';
import 'package:m18_residences/bloc/billing/billing_event.dart';
import 'package:m18_residences/features/billing/billing_page.dart';
import 'package:m18_residences/features/history/history_page.dart';
import 'package:m18_residences/features/home/home_page.dart';
import 'package:m18_residences/features/payment/payment_page.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// The tenant's app after login: Home, History and Pay, as a bottom bar on phones and a rail on wider screens.
/// It loads the tenant's bills once; every tab reads them from [BillingBloc].
class TenantShell extends StatefulWidget {
  const TenantShell({super.key});

  /// The shell around [context], for switching tabs or opening the statement from a page.
  static TenantShellState of(BuildContext context) => context.findAncestorStateOfType<TenantShellState>()!;

  @override
  State<TenantShell> createState() => TenantShellState();
}

enum TenantTab { home, history, pay }

class TenantShellState extends State<TenantShell> {
  late final Tenant tenant;
  late final AuthApi authApi;
  late final BillingBloc _billingBloc;
  TenantTab _tab = TenantTab.home;

  @override
  void initState() {
    super.initState();
    final authBloc = context.read<AuthBloc>();
    tenant = authBloc.cachedTenant!;
    authApi = authBloc.authApi;
    _billingBloc = context.read<BillingBloc>();
    refresh();
  }

  void refresh() => _billingBloc.add(FetchBillingsByTenantId(tenant.id));

  void select(TenantTab tab) => setState(() => _tab = tab);

  /// The latest bill's statement, where the tenant also uploads their payment.
  void openStatement() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BillingPage()));

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is Unauthenticated) {
          return Scaffold(body: ErrorView(message: authState.message));
        }
        return AdaptiveScaffold(
          selectedIndex: _tab.index,
          onDestinationSelected: (i) => select(TenantTab.values[i]),
          railHeader: (context, extended) => BrandMark(label: extended ? 'M18 Residences' : null),
          destinations: const [
            AdaptiveDestination(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home),
            AdaptiveDestination(label: 'History', icon: Icons.insights_outlined, selectedIcon: Icons.insights),
            AdaptiveDestination(label: 'Pay', icon: Icons.qr_code_2_outlined, selectedIcon: Icons.qr_code_2),
          ],
          // Each tab selects its own text only (a hidden tab's text is not picked up by a drag).
          body: IndexedStack(
            index: _tab.index,
            children: [
              for (final page in const [HomePage(), HistoryPage(), PaymentPage()]) SelectablePage(child: page),
            ],
          ),
        );
      },
    );
  }
}

/// The app bar of a tab: its title, the tenant's name, Refresh (optional) and Logout.
class TenantAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showRefresh;

  const TenantAppBar({super.key, required this.title, this.showRefresh = true});

  @override
  Widget build(BuildContext context) {
    final shell = TenantShell.of(context);
    return CustomAppBar(
      title: title,
      subtitle: shell.tenant.name,
      showLeading: false,
      actions: [
        if (showRefresh) IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: shell.refresh),
        IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: () => LogoutScope.logout(context)),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
