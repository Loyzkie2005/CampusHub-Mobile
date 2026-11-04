import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../session/session_service.dart';
import 'components/account_recovery_dialog.dart';
import 'components/auth_form_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _studentIdOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _studentIdOrEmail = '';
  bool _obscurePassword = true;
  bool _isNavigating = false;
  bool _rememberMe = true;
  String? _loginError;

  static const Color primaryNavy = AuthFormStyle.navy;

  @override
  void dispose() {
    _studentIdOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login(BuildContext formContext) async {
    if (_isNavigating) return;
    if (!Form.of(formContext).validate()) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isNavigating = true;
      _loginError = null;
    });

    final result = await AuthService.login(
      studentIdOrEmail: _studentIdOrEmailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    final user = result.user;
    if (!result.success || user == null) {
      setState(() {
        _isNavigating = false;
        _loginError = result.message ?? 'Unable to log in.';
      });
      return;
    }

    await SessionService.saveUser(
      user,
      chatToken: result.chatToken,
      remember: _rememberMe,
    );
    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(AppRoutes.forUser(user));
  }

  Future<void> _showAccountRecoveryDialog() async {
    final success = await showDialog<bool>(
      context: context,
      builder: (_) => AccountRecoveryDialog(initialEmail: _studentIdOrEmail),
    );

    if (!mounted || success != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account recovery complete. You can return to login.'),
        backgroundColor: primaryNavy,
      ),
    );
  }

  Future<void> _openSignUp() async {
    if (_isNavigating) return;

    FocusManager.instance.primaryFocus?.unfocus();
    final createdIdentifier = await Navigator.of(
      context,
    ).pushNamed<String>(AppRoutes.signup);

    if (!mounted || createdIdentifier == null || createdIdentifier.isEmpty) {
      return;
    }

    setState(() {
      _studentIdOrEmail = createdIdentifier;
      _studentIdOrEmailController.text = createdIdentifier;
    });
  }

  Widget _buildInlineError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData? icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    Widget? supporting,
    String? serverError,
    String? hintText,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
    TextInputAction textInputAction = TextInputAction.next,
  }) => AuthFormField(
    controller: controller,
    label: label,
    icon: icon,
    obscure: obscure,
    onToggleObscure: onToggleObscure,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    inputFormatters: inputFormatters,
    supporting: supporting,
    serverError: serverError,
    hintText: hintText,
    onChanged: onChanged,
    validator: validator,
    textInputAction: textInputAction,
  );

  Widget _buildLoginOptions(BuildContext formContext) => LayoutBuilder(
    builder: (context, constraints) {
      final colors = Theme.of(formContext).colorScheme;
      final rememberStyle = AuthFormStyle.text(
        size: 12,
        color: colors.onSurface,
      ).copyWith(letterSpacing: 0);
      final recoveryStyle = AuthFormStyle.text(
        size: 12,
        weight: FontWeight.w600,
        color: AuthFormStyle.gold,
      ).copyWith(letterSpacing: 0, height: 1.2);
      const recoveryLabel = 'Forgot Username or Password?';

      double textWidth(String value, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: value, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      final fitsRow =
          textWidth('Remember me', rememberStyle) +
              28 +
              8 +
              textWidth(recoveryLabel, recoveryStyle) <=
          constraints.maxWidth;
      final remember = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
        child: InkWell(
          key: const Key('login-remember-control'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 48,
                child: Checkbox(
                  value: _rememberMe,
                  activeColor: colors.primary,
                  checkColor: colors.onPrimary,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                ),
              ),
              Flexible(child: Text('Remember me', style: rememberStyle)),
            ],
          ),
        ),
      );
      final recovery = TextButton(
        key: const Key('login-recovery-link'),
        onPressed: _showAccountRecoveryDialog,
        style: AuthFormStyle.linkButton(formContext, color: AuthFormStyle.gold)
            .copyWith(
              alignment: Alignment.centerRight,
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              textStyle: WidgetStatePropertyAll(recoveryStyle),
            ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            recoveryLabel,
            maxLines: 1,
            softWrap: false,
            style: recoveryStyle,
          ),
        ),
      );
      if (fitsRow) {
        return Row(
          children: [
            remember,
            const SizedBox(width: 8),
            Expanded(child: recovery),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: remember),
          recovery,
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => AuthFormShell(
    page: 'login',
    child: Form(
      child: Builder(
        builder: (formContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuthFormHeading(
              title: 'Login',
              subtitle: 'Sign in to your account to continue.',
            ),
            _buildField(
              controller: _studentIdOrEmailController,
              label: 'Username or Email',
              hintText: 'Enter your username or email',
              icon: Icons.person_outline,
              onChanged: (value) {
                _studentIdOrEmail = value.trim();
                if (_loginError != null) {
                  setState(() => _loginError = null);
                }
              },
              validator: (v) {
                if ((v ?? '').trim().isEmpty) {
                  return 'Please enter your username or email';
                }
                return null;
              },
            ),
            _buildField(
              controller: _passwordController,
              label: 'Password',
              hintText: 'Enter your password',
              icon: Icons.lock_outline,
              obscure: _obscurePassword,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              onChanged: (_) {
                if (_loginError != null) {
                  setState(() => _loginError = null);
                }
              },
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            if (_loginError != null) _buildInlineError(_loginError!),
            _buildLoginOptions(formContext),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isNavigating ? null : () => _login(formContext),
              style: AuthFormStyle.primaryButton,
              child: _isNavigating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: primaryNavy,
                      ),
                    )
                  : const Text('Log In'),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Don't have an account?",
                  style: AuthFormStyle.text(
                    size: 13,
                    color: Theme.of(formContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: _isNavigating ? null : _openSignUp,
                  style: AuthFormStyle.linkButton(formContext),
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
