import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/user_repository.dart';
import '../../shared/models/user_model.dart';
import '../core/theme/app_colors.dart';
import '../../shared/widgets/form_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController(text: '+252');
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Check if email already exists
      final isRegistered = await ref
          .read(userProvider.notifier)
          .isEmailRegistered(_emailController.text.trim());
      if (isRegistered) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This email already exists.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final error = await ref
          .read(authServiceProvider)
          .signup(
            name: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
            role: UserRole.traveler,
            phone: _phoneController.text.trim(),
          );

      if (mounted) setState(() => _isLoading = false);

      if (error == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_email', _emailController.text.trim());
        } catch (e) {
          debugPrint('Failed to save email for pre-fill: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Registration successful! Please check your email to activate your account.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
          context.pop(); // Return to Login
        }
      } else if (error == 'AUTO_LOGIN') {
        // Supabase logged us in directly (Email Confirmation is disabled)
        // The router will automatically redirect to the home screen.
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $error'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traveler Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 24),
                  AppTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Enter your name',
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final emailRegex = RegExp(
                        r'^[\w\.\+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$',
                      );
                      if (!emailRegex.hasMatch(v.trim())) {
                        return 'Enter a valid email (e.g. name@gmail.com)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Create a password',
                    obscureText: true,
                    validator: (v) =>
                        (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: '+252xxxxxx',
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final phoneVal = v.trim();
                      if (!phoneVal.startsWith('+252')) {
                        return 'Phone number must start with +252';
                      }
                      if (phoneVal.length < 9) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Already have an account? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
