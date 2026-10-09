import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n_ext.dart';
import 'auth_repository.dart';
import '../../core/app_message.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _auth = AuthRepository();

  bool _isSignUp = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isSignUp) {
        await _auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          fullName: _fullName.text.trim(),
        );
        if (mounted) {
          showAppMessage(context, context.l10n.loginAccountCreated,
              type: AppMessageType.success);
        }
      } else {
        await _auth.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (e) {
      debugPrint('auth: ${e.code} ${e.message}');
      if (mounted) _showError(_authErrorText(e));
    } catch (e) {
      debugPrint('auth: $e');
      if (mounted) _showError(context.l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Ошибки Supabase Auth приходят на английском и с техническими
  /// подробностями — показываем понятный текст на языке интерфейса.
  String _authErrorText(AuthException e) {
    final l = context.l10n;
    final code = e.code ?? '';
    final m = e.message.toLowerCase();
    if (code == 'invalid_credentials' ||
        m.contains('invalid login credentials')) {
      return l.loginErrorInvalidCredentials;
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        m.contains('already registered')) {
      return l.loginErrorAlreadyRegistered;
    }
    if (code == 'email_not_confirmed' || m.contains('email not confirmed')) {
      return l.loginErrorEmailNotConfirmed;
    }
    return l.errorGeneric;
  }

  void _showError(String msg) {
    if (!mounted) return;
    showAppMessage(context, msg, type: AppMessageType.error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.appName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.appTagline,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _fullName,
                        decoration: InputDecoration(
                          labelText: l.loginName,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: l.loginEmail,
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? l.loginEmailInvalid
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l.loginPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? l.loginPasswordTooShort
                          : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? l.loginSignUp : l.loginSignIn),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                          _isSignUp ? l.loginHaveAccount : l.loginNoAccount),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
