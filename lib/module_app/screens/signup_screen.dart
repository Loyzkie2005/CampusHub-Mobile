import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../validation/password_policy.dart';
import 'components/auth_form_shell.dart';
import 'components/campus_legal_dialog.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  bool _agreedToTerms = false;
  String? _firstNameError;
  String? _lastNameError;
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _termsError;
  String? _generalError;

  static const Color primaryNavy = AuthFormStyle.navy;
  static const Color accentGold = AuthFormStyle.gold;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp(BuildContext formContext) async {
    if (_isSubmitting) return;

    setState(_clearServerErrors);
    if (!Form.of(formContext).validate()) return;
    if (!_agreedToTerms) {
      setState(() {
        _termsError =
            'Please agree to the Terms and Conditions and Privacy Policy.';
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);

    final result = await AuthService.signUp(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      studentId: _studentIdController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      _showSignUpError(result.message ?? 'Account creation failed.');
      return;
    }

    setState(() => _isSubmitting = false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AccountCreatedDialog(),
    );

    if (!mounted) return;

    Navigator.pop(
      context,
      result.user?.studentId ?? _studentIdController.text.trim(),
    );
  }

  void _clearServerErrors() {
    _firstNameError = null;
    _lastNameError = null;
    _usernameError = null;
    _emailError = null;
    _passwordError = null;
    _confirmPasswordError = null;
    _termsError = null;
    _generalError = null;
  }

  void _showSignUpError(String message) {
    final normalized = message.toLowerCase();

    setState(() {
      _isSubmitting = false;
      _clearServerErrors();

      if (normalized.contains('username') && normalized.contains('email')) {
        _usernameError = message;
        _emailError = message;
      } else if (normalized.contains('username') ||
          normalized.contains('student id')) {
        _usernameError = message;
      } else if (normalized.contains('email')) {
        _emailError = message;
      } else if (normalized.contains('do not match') ||
          normalized.contains('confirm password')) {
        _confirmPasswordError = message;
      } else if (normalized.contains('password')) {
        _passwordError = message;
      } else if (normalized.contains('first name')) {
        _firstNameError = message;
      } else if (normalized.contains('last name')) {
        _lastNameError = message;
      } else {
        _generalError = message;
      }
    });
  }

  void _clearFieldError(VoidCallback clearError) {
    setState(() {
      clearError();
      _generalError = null;
    });
  }

  Widget _buildInlineError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTermsChanged(bool shouldAgree) async {
    if (!shouldAgree) {
      setState(() {
        _agreedToTerms = false;
        _termsError = null;
      });
      return;
    }

    final accepted = await showCampusLegalDialog(context);
    if (!mounted) return;

    setState(() {
      _agreedToTerms = accepted;
      if (accepted) _termsError = null;
    });
  }

  Future<void> _openTermsAndPrivacy() async {
    final accepted = await showCampusLegalDialog(context);
    if (!mounted || !accepted) return;

    setState(() {
      _agreedToTerms = true;
      _termsError = null;
    });
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

  @override
  Widget build(BuildContext context) => AuthFormShell(
    page: 'signup',
    onBack: () => Navigator.pop(context),
    child: Form(
      child: Builder(
        builder: (formContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuthFormHeading(
              title: 'Create Account',
              subtitle: 'Create your account to get started.',
            ),
            // First Name & Last Name Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildField(
                    controller: _firstNameController,
                    label: 'First Name',
                    hintText: 'First Name',
                    icon: null,
                    serverError: _firstNameError,
                    onChanged: (_) {
                      if (_firstNameError != null) {
                        _clearFieldError(() => _firstNameError = null);
                      }
                    },
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: const [_InitialUppercaseFormatter()],
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    hintText: 'Last Name',
                    icon: null,
                    serverError: _lastNameError,
                    onChanged: (_) {
                      if (_lastNameError != null) {
                        _clearFieldError(() => _lastNameError = null);
                      }
                    },
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: const [_InitialUppercaseFormatter()],
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),

            // Username Field
            _buildField(
              controller: _studentIdController,
              label: 'Username',
              icon: Icons.badge_outlined,
              serverError: _usernameError,
              onChanged: (_) {
                if (_usernameError != null) {
                  _clearFieldError(() => _usernameError = null);
                }
              },
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) {
                  return 'Please enter a username';
                }
                if (value.length < 3) {
                  return 'At least 3 characters';
                }
                return null;
              },
            ),

            // Email Field
            _buildField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              serverError: _emailError,
              onChanged: (_) {
                if (_emailError != null) {
                  _clearFieldError(() => _emailError = null);
                }
              },
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please enter your email';
                }
                if (!v.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),

            // Password Field
            _buildField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              serverError: _passwordError,
              onChanged: (_) {
                if (_passwordError != null) {
                  _clearFieldError(() => _passwordError = null);
                }
              },
              obscure: _obscurePassword,
              keyboardType: TextInputType.visiblePassword,
              supporting: _PasswordChecklist(controller: _passwordController),
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: PasswordPolicy.validate,
            ),

            // Confirm Password Field
            _buildField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              textInputAction: TextInputAction.done,
              icon: Icons.lock_outline,
              serverError: _confirmPasswordError,
              onChanged: (_) {
                if (_confirmPasswordError != null) {
                  _clearFieldError(() => _confirmPasswordError = null);
                }
              },
              obscure: _obscureConfirm,
              keyboardType: TextInputType.visiblePassword,
              onToggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please confirm your password';
                }
                if (v != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),

            Row(
              key: const Key('signup-terms-row'),
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 48,
                  child: Checkbox(
                    key: const Key('signup-terms-checkbox'),
                    value: _agreedToTerms,
                    onChanged: _isSubmitting
                        ? null
                        : (value) => _handleTermsChanged(value ?? false),
                    activeColor: Theme.of(formContext).colorScheme.primary,
                    checkColor: Theme.of(formContext).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextButton(
                    key: const Key('signup-terms-link'),
                    onPressed: _isSubmitting ? null : _openTermsAndPrivacy,
                    style: AuthFormStyle.linkButton(formContext).copyWith(
                      alignment: Alignment.centerLeft,
                      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          children: [
                            TextSpan(
                              text: 'Terms and Conditions',
                              style: AuthFormStyle.text(
                                size: 12,
                                weight: FontWeight.w600,
                                color: Theme.of(
                                  formContext,
                                ).colorScheme.onSurface,
                              ).copyWith(decoration: TextDecoration.underline),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: AuthFormStyle.text(
                                size: 12,
                                weight: FontWeight.w600,
                                color: Theme.of(
                                  formContext,
                                ).colorScheme.onSurface,
                              ).copyWith(decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                        key: const Key('signup-terms-label'),
                        maxLines: 1,
                        softWrap: false,
                        style: AuthFormStyle.text(
                          size: 12,
                          color: Theme.of(
                            formContext,
                          ).colorScheme.onSurfaceVariant,
                        ).copyWith(letterSpacing: 0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_termsError != null) _buildInlineError(_termsError!),
            if (_generalError != null) _buildInlineError(_generalError!),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSubmitting ? null : () => _signUp(formContext),
              style: AuthFormStyle.primaryButton,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: primaryNavy,
                      ),
                    )
                  : const Text('Sign Up'),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: AuthFormStyle.text(
                    size: 13,
                    color: Theme.of(formContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(context);
                        },
                  style: AuthFormStyle.linkButton(formContext),
                  child: const Text('Log In'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _InitialUppercaseFormatter extends TextInputFormatter {
  const _InitialUppercaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final formatted =
        newValue.text[0].toUpperCase() + newValue.text.substring(1);
    return newValue.copyWith(text: formatted, composing: TextRange.empty);
  }
}

class _PasswordChecklist extends StatelessWidget {
  const _PasswordChecklist({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final password = value.text;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: password.isEmpty
              ? const SizedBox.shrink(key: ValueKey('password-rules-hidden'))
              : Column(
                  key: const ValueKey('password-rules-visible'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PasswordRequirement(
                      label: '8+ characters and no spaces',
                      isMet:
                          password.length >= 8 &&
                          !RegExp(r'\s').hasMatch(password),
                    ),
                    _PasswordRequirement(
                      label: 'Uppercase and lowercase letters',
                      isMet:
                          RegExp(r'[A-Z]').hasMatch(password) &&
                          RegExp(r'[a-z]').hasMatch(password),
                    ),
                    _PasswordRequirement(
                      label: 'Number and special character',
                      isMet:
                          RegExp(r'[0-9]').hasMatch(password) &&
                          RegExp(r'[^A-Za-z0-9]').hasMatch(password) &&
                          !RegExp(r'\s').hasMatch(password),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  const _PasswordRequirement({required this.label, required this.isMet});

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final textColor = isMet
        ? (isLightMode ? _SignUpScreenState.primaryNavy : Colors.white)
        : const Color(0xFFDC2626);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Semantics(
            label: '$label: ${isMet ? 'complete' : 'incomplete'}',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isMet
                    ? _SignUpScreenState.accentGold
                    : (isLightMode ? Colors.transparent : Colors.white),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMet
                      ? _SignUpScreenState.accentGold
                      : const Color(0xFFDC2626),
                  width: 1.4,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  isMet ? Icons.check_rounded : Icons.close_rounded,
                  key: ValueKey(isMet),
                  size: 13,
                  color: isMet
                      ? _SignUpScreenState.primaryNavy
                      : const Color(0xFFDC2626),
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCreatedDialog extends StatefulWidget {
  const _AccountCreatedDialog();

  @override
  State<_AccountCreatedDialog> createState() => _AccountCreatedDialogState();
}

class _AccountCreatedDialogState extends State<_AccountCreatedDialog> {
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animate = true);
    });

    Future<void>.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _animate ? 1 : 0.2,
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              child: AnimatedOpacity(
                opacity: _animate ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF22C55E),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Account Created Successfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _SignUpScreenState.primaryNavy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
