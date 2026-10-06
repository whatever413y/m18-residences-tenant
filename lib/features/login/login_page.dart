import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences/bloc/auth/auth_bloc.dart';
import 'package:m18_residences/bloc/auth/auth_event.dart';
import 'package:m18_residences/bloc/auth/auth_state.dart';
import 'package:m18_residences/utils/remembered_account.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import '../shell/tenant_shell.dart';

class LoginPage extends StatefulWidget {
  /// The URL the app was opened with (set in `main` before the router can rewrite it).
  static Uri? launchUrl;

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _accountIdError;

  /// Whether a successful login keeps the account ID in this browser ("Remember me").
  bool _remember = true;

  /// The account ID of the login in progress.
  String? _submittedId;

  @override
  void initState() {
    super.initState();

    // A link's account ID wins over the remembered one.
    final accountId = accountIdFromUrl(LoginPage.launchUrl ?? Uri.base);
    if (accountId != null) {
      _controller.text = accountId;
    } else {
      _prefillRemembered();
    }
  }

  Future<void> _prefillRemembered() async {
    final remembered = await RememberedAccount.read();
    if (remembered != null && mounted && _controller.text.isEmpty) _controller.text = remembered;
  }

  void _searchTenant() {
    setState(() {
      _accountIdError = null;
    });
    if (_formKey.currentState?.validate() ?? false) {
      final accountId = _controller.text.trim().toUpperCase();
      _submittedId = accountId;
      context.read<AuthBloc>().add(LoginWithAccountId(accountId));
    }
  }

  Future<void> _rememberOrForget() async {
    final accountId = _submittedId;
    if (_remember && accountId != null) {
      await RememberedAccount.save(accountId);
    } else {
      await RememberedAccount.forget();
    }
  }

  void _navigateToPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            setState(() {
              _accountIdError = state.message;
            });
            _formKey.currentState?.validate();
          } else if (state is Authenticated) {
            _rememberOrForget();
            _controller.clear();
            if (!Navigator.of(context).canPop()) {
              _navigateToPage(const TenantShell());
            }
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _buildContent(context)),
                  ),
                ),
              ),
              if (state is AuthLoading) const LoadingOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: BrandMark(size: 56)),
        const SizedBox(height: 20),
        Text('M18 Residences', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'See your bill, your electricity use and how to pay.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Log in', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Enter your account ID to continue.', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 20),
                  _buildAccountIDInput(),
                  const SizedBox(height: 4),
                  _buildRememberMe(),
                  const SizedBox(height: 12),
                  _buildSearchButton(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Your account ID is the name on the link the owner sent you.', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildAccountIDInput() {
    return CustomTextFormField(
      controller: _controller,
      labelText: 'Account ID',
      prefixIcon: const Icon(Icons.person_outline),
      errorMaxLines: 1,
      semanticsId: 'tenant-account-id',
      autofocus: true,
      onFieldSubmitted: (_) => _searchTenant(),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your Account ID';
        }
        return _accountIdError;
      },
    );
  }

  Widget _buildRememberMe() {
    return Semantics(
      container: true,
      identifier: 'tenant-remember-me',
      child: CheckboxListTile(
        value: _remember,
        onChanged: (value) => setState(() => _remember = value ?? false),
        title: const Text('Remember me on this device'),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
    );
  }

  Widget _buildSearchButton() {
    return Semantics(
      container: true,
      identifier: 'tenant-login-submit',
      child: FilledButton(onPressed: _searchTenant, child: const Text('Continue')),
    );
  }
}

/// The account ID a tenant link carries: the last path segment (`…/NAME`), or for links shared before the
/// move to path URLs, the last segment of the fragment (`…/#/NAME`).
String? accountIdFromUrl(Uri url) {
  String? lastSegment(List<String> segments) => segments.where((s) => s.trim().isNotEmpty).lastOrNull;
  if (url.fragment.isNotEmpty) {
    final fromFragment = lastSegment(Uri.parse(url.fragment).pathSegments);
    if (fromFragment != null) return fromFragment;
  }
  return lastSegment(url.pathSegments);
}
