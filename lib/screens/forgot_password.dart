import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Define enum outside the class
enum ResetStep { emailInput, verificationCode, newPassword }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController verificationCodeController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String responseMessage = '';
  bool hasError = false;

  // Track the current step of the password reset flow
  ResetStep currentStep = ResetStep.emailInput;

  // Store user ID from backend
  String? userId;

  final Color backgroundColor = const Color(0xFF2F2E2E);
  final Color inputColor = const Color(0xFFADADAD);
  final Color accentColor = const Color(0xFFFFC740);

  Future<void> requestVerificationCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      responseMessage = '';
      hasError = false;
    });

    try {
      final response = await http.post(
        Uri.parse('http://pacific-condocare.com/public/forgot_password.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': emailController.text.trim(),
          'action': 'request_code'
        }),
      );

      final data = json.decode(response.body);

      setState(() {
        isLoading = false;
        responseMessage = data['message'] ?? 'Request processed';
        hasError = !data['success'];
      });

      if (data['success'] == true) {
        // Move to verification code entry step
        setState(() {
          currentStep = ResetStep.verificationCode;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        responseMessage = 'Network error: $e';
        hasError = true;
      });
    }
  }

  Future<void> verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      responseMessage = '';
      hasError = false;
    });

    try {
      final response = await http.post(
        Uri.parse('http://pacific-condocare.com/public/forgot_password.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': emailController.text.trim(),
          'verification_code': verificationCodeController.text.trim(),
          'action': 'verify_code'
        }),
      );

      final data = json.decode(response.body);

      setState(() {
        isLoading = false;
        responseMessage = data['message'] ?? 'Verification processed';
        hasError = !data['success'];
      });

      if (data['success'] == true) {
        // Store the user ID for the reset request
        userId = data['userid'];

        // Move to new password step
        setState(() {
          currentStep = ResetStep.newPassword;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        responseMessage = 'Network error: $e';
        hasError = true;
      });
    }
  }

  Future<void> resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      responseMessage = '';
      hasError = false;
    });

    try {
      final response = await http.post(
        Uri.parse('http://pacific-condocare.com/public/forgot_password.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': emailController.text.trim(),
          'verification_code': verificationCodeController.text.trim(),
          'new_password': newPasswordController.text,
          'userid': userId,
          'action': 'reset_password'
        }),
      );

      final data = json.decode(response.body);

      setState(() {
        isLoading = false;
        responseMessage = data['message'] ?? 'Password reset processed';
        hasError = !data['success'];
      });

      if (data['success'] == true) {
        // Display success message for a moment before navigating back
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context, true); // Pass true to indicate successful reset
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        responseMessage = 'Network error: $e';
        hasError = true;
      });
    }
  }

  Widget buildEmailStep() {
    return Column(
      children: [
        Text(
          'Enter the exact email address associated with your account',
          style: TextStyle(color: inputColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: emailController,
          decoration: InputDecoration(
            hintText: 'Enter Exact Email Address',
            helperStyle: TextStyle(color: inputColor.withOpacity(0.7), fontSize: 12),
            filled: true,
            fillColor: inputColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
            if (!emailRegex.hasMatch(value)) {
              return 'Please enter a valid email';
            }
            // Convert to lowercase for display but keep original case for backend
            value = value.trim();
            return null;
          },
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : requestVerificationCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
                : const Text(
              'Send Verification Code',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildVerificationStep() {
    return Column(
      children: [
        Text(
          'A verification code has been sent to ${emailController.text}',
          style: TextStyle(color: inputColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: verificationCodeController,
          decoration: InputDecoration(
            hintText: 'Enter Verification Code',
            filled: true,
            fillColor: inputColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the verification code';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
                : const Text(
              'Verify Code',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: isLoading ? null : () {
            setState(() {
              currentStep = ResetStep.emailInput;
              verificationCodeController.clear();
              responseMessage = '';
            });
          },
          child: Text(
            'Change Email',
            style: TextStyle(color: inputColor),
          ),
        ),
      ],
    );
  }

  Widget buildNewPasswordStep() {
    return Column(
      children: [
        TextFormField(
          controller: newPasswordController,
          decoration: InputDecoration(
            hintText: 'New Password',
            filled: true,
            fillColor: inputColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a new password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: confirmPasswordController,
          decoration: InputDecoration(
            hintText: 'Confirm Password',
            filled: true,
            fillColor: inputColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != newPasswordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
                : const Text(
              'Reset Password',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(30),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentStep == ResetStep.emailInput
                        ? 'Forgot Password'
                        : currentStep == ResetStep.verificationCode
                        ? 'Verify Code'
                        : 'Reset Password',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (responseMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasError ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasError ? Colors.red.shade300 : Colors.green.shade300,
                        ),
                      ),
                      child: Text(
                        responseMessage,
                        style: TextStyle(
                          color: hasError ? Colors.red.shade300 : Colors.green.shade300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (currentStep == ResetStep.emailInput)
                    buildEmailStep()
                  else if (currentStep == ResetStep.verificationCode)
                    buildVerificationStep()
                  else
                    buildNewPasswordStep(),
                  if (currentStep == ResetStep.emailInput) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Back to Login',
                        style: TextStyle(color: inputColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
