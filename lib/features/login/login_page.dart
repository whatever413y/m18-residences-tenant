import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences/bloc/auth/auth_bloc.dart';
import 'package:m18_residences/bloc/auth/auth_event.dart';
import 'package:m18_residences/bloc/auth/auth_state.dart';
import 'package:m18_residences/utils/remembered_account.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import '../home/home_page.dart';

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
    final theme = AppTheme.lightTheme;

    return Theme(
      data: theme,
      child: Scaffold(
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
                _navigateToPage(HomePage());
              }
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return _buildLoading(
              isLoading,
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final cardWidth = maxWidth < 500 ? maxWidth * 0.9 : 400.0;

                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade900, Colors.blue.shade500],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: cardWidth),
                            child: Padding(padding: const EdgeInsets.all(16.0), child: _buildCard(context, maxWidth)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading(bool isLoading, Widget child) {
    return Stack(children: [child, if (isLoading) LoadingOverlay()]);
  }

  Widget _buildCard(BuildContext context, double maxWidth) {
    final isMobile = maxWidth < 400;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Welcome",
                style: TextStyle(fontSize: isMobile ? 22 : 26, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
              ),
              SizedBox(height: isMobile ? 8 : 10),
              Text(
                "Enter your Account ID to continue",
                style: TextStyle(fontSize: isMobile ? 14 : 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isMobile ? 16 : 20),
              _buildAccountIDInput(),
              _buildRememberMe(),
              SizedBox(height: isMobile ? 8 : 12),
              _buildSearchButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountIDInput() {
    return CustomTextFormField(
      controller: _controller,
      labelText: 'Account ID',
      prefixIcon: const Icon(Icons.person),
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _searchTenant,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            backgroundColor: Colors.blue.shade700,
            elevation: 5,
          ),
          child: const Text('Submit', style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
      ),
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
