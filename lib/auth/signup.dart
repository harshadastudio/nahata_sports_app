import 'package:flutter/material.dart';

import '../core/navigation/role_router.dart';
import '../repositories/auth_repository.dart';
import 'login.dart' show LoginScreen, ApiService;
import 'registration.dart';

/// Quick sign-up — `POST /auth/register`.
///
/// Four fields and you are in. It sits beside [RegisterScreen], which is the
/// full student enrolment (sports complex, date of birth, photo, referral) and
/// is what somebody joining a coaching batch needs. This one is for a person
/// who just wants an account to book a court, so it asks for nothing the
/// endpoint does not require.
///
/// The endpoint returns tokens with the new user, so a successful sign-up is
/// already a signed-in session: the screen routes straight into the app by
/// role rather than sending the user back to Login to type it all again.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const brandBlue = Color(0xFF1A237E);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthRepository.instance.signUp(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phoneNumber: _phoneController.text,
      );

      if (!mounted) return;

      if (!result.success || result.profile == null) {
        _showMessage(result.message ?? 'Sign up failed. Please try again.');
        return;
      }

      // The session is live, so the legacy `ApiService.currentUser` map every
      // older screen still reads is refreshed before anything navigates.
      await ApiService.loadUserFromPrefs();
      if (!mounted) return;

      final profile = result.profile!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome, ${profile.displayName.isEmpty ? 'to Nahata Sports' : profile.displayName}!',
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => RoleRouter.screenFor(profile.roleLabel),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Image.asset("assets/ns.png", height: 90),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Create your\nAccount",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Just the basics — you can complete your profile later.",
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _field(
                      controller: _nameController,
                      hint: 'Full name',
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    _field(
                      controller: _emailController,
                      hint: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) return 'Please enter your email';
                        if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$')
                            .hasMatch(text)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _field(
                      controller: _phoneController,
                      hint: 'Phone number (10 digits)',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        final digits =
                            (value ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (digits.length != 10) {
                          return 'Enter a 10-digit phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _field(
                      controller: _passwordController,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signUp(),
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      validator: (value) {
                        final text = value ?? '';
                        if (text.isEmpty) return 'Password is required';
                        if (text.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 50,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                "Sign Up",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // The other way in: the full enrolment form, for somebody
                    // joining a coaching batch rather than just booking a court.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Joining a coaching batch? "),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RegisterScreen(),
                                    ),
                                  ),
                          child: const Text(
                            "Full registration",
                            style: TextStyle(
                              color: brandBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account? "),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  ),
                          child: const Text(
                            "Log In",
                            style: TextStyle(
                              color: brandBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The login screen's field styling, so the two screens look like one flow.
  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      obscureText: obscureText,
      enabled: !_isLoading,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}