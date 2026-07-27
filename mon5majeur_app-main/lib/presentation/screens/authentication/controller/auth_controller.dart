// lib/controllers/auth_controller.dart - Complete implementation
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/services/api_service.dart';
// import '../../../../data/services/api_url.dart' hide ApiUrl;
import '../../../../data/services/api_url.dart';

import '../../home/controllers/home_controller.dart';

final logger = Logger();

class AuthController extends GetxController {
  // Observable variables
  var rememberMe = false.obs;
  var passwordVisible = false.obs;
  var confirmPasswordVisible = false.obs;
  var isLoading = false.obs;

  // OTP Timer variables
  var otpCountdown = 2.obs; // 5 minutes in seconds
  var canResendOtp = false.obs;
  Timer? _otpTimer;

  // Text controllers
  final emailController = TextEditingController(text: 'arikittesaf@gmail.com');
  // final emailController = TextEditingController(
  //   text: 'abdullah.muhtasim@gmail.com',
  // );
  // final emailController = TextEditingController(text: 'fahad1001mir@gmail.com');
  // final emailController = TextEditingController(text: 'fahad1000mir@gmail.com');
  // final emailController = TextEditingController(text: 'admin@gmail.com');
  final passwordController = TextEditingController(text: '12345678');
  final confirmPasswordController = TextEditingController();

  // Form keys for validation
  final signUpFormKey = GlobalKey<FormState>();
  final signInFormKey = GlobalKey<FormState>();

  String? lastRegisteredEmail; // To store email for OTP verification

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _otpTimer?.cancel();
    super.onClose();
  }

  // Start OTP countdown timer
  void startOtpTimer() {
    otpCountdown.value = 2; // Reset to 5 minutes
    canResendOtp.value = false;

    _otpTimer?.cancel(); // Cancel any existing timer
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (otpCountdown.value > 0) {
        otpCountdown.value--;
      } else {
        canResendOtp.value = true;
        timer.cancel();
      }
    });
  }

  // Format countdown for display (MM:SS)
  String get formattedCountdown {
    final minutes = (otpCountdown.value ~/ 60).toString().padLeft(2, '0');
    final seconds = (otpCountdown.value % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Toggle password visibility
  void togglePasswordVisibility() {
    passwordVisible.value = !passwordVisible.value;
  }

  // Toggle confirm password visibility
  void toggleConfirmPasswordVisibility() {
    confirmPasswordVisible.value = !confirmPasswordVisible.value;
  }

  // Toggle remember me
  void toggleRememberMe(bool? value) {
    rememberMe.value = value ?? false;
  }

  // Validation functions
  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Email is required";
    }
    // Simple email regex
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return "Enter a valid email";
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Password is required";
    }
    if (value.length < 6) {
      return "Password must be at least 6 characters";
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Confirm password is required";
    }
    if (value != passwordController.text) {
      return "Passwords do not match";
    }
    return null;
  }

  // Show snackbar - Updated to use ScaffoldMessenger for better reliability
  void showSnackbar(
    BuildContext context,
    String title,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Sign Up method
  Future<void> signUp(BuildContext context) async {
    if (isLoading.value) return;

    if (!signUpFormKey.currentState!.validate()) {
      showSnackbar(
        context,
        "Validation Error",
        "Please fix the errors",
        isError: true,
      );
      return;
    }

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      final body = {
        "email": emailController.text.trim(),
        "password": passwordController.text,
        "password2": confirmPasswordController.text,
      };

      logger.i("Sign Up Request: $body");

      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.register,
        isBasic: true,
        body: body,
        showResult: true,
      );

      logger.i("Sign Up Response: ${response.statusCode}");
      logger.i("Sign Up Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.body;
        lastRegisteredEmail = emailController.text.trim();

        showSnackbar(
          context,
          "Success",
          data['message'] ??
              "OTP sent to your email. Verify to complete registration.",
        );

        // Start OTP timer
        startOtpTimer();

        // Navigate to OTP verification screen with email
        // DON'T clear form here - we need password for resend OTP
        Future.delayed(const Duration(seconds: 1), () {
          GoRouter.of(context).pushNamed(
            RoutePath.verifyRegistration,
            extra: {'email': emailController.text.trim(), 'from': 'signup'},
          );
        });
      } else {
        final errorMessage =
            response.body['message'] ??
            response.body['email']?.toString() ??
            response.body['error']?.toString() ??
            "Registration failed";
        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Sign Up Error: $e");
      showSnackbar(
        context,
        "Error",
        "Failed to create account. Please try again.",
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // OTP Verification method
  Future<void> verifyOtp(
    BuildContext context,
    String otp, {
    String? email,
  }) async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      final body = {"email": email ?? lastRegisteredEmail, "otp": otp};

      logger.i("Verify OTP Request: $body");

      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.verifyOtp,
        isBasic: true,
        body: body,
        showResult: true,
      );

      logger.i("Verify OTP Response: ${response.statusCode}");
      logger.i("Verify OTP Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.body;

        _otpTimer?.cancel(); // Stop the timer

        showSnackbar(
          context,
          "Success",
          data['message'] ?? "Registration complete. You can now log in.",
        );

        // Navigate first, then clear form
        Future.delayed(const Duration(seconds: 1), () {
          context.go(RoutePath.signInScreen.addBasePath);

          // Clear form after navigation
          emailController.clear();
          passwordController.clear();
          confirmPasswordController.clear();
          lastRegisteredEmail = null;
        });
      } else {
        final errorMessage =
            response.body['message'] ??
            response.body['email']?.toString() ??
            response.body['otp']?.toString() ??
            response.body['error']?.toString() ??
            "OTP verification failed";
        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Verify OTP Error: $e");
      showSnackbar(context, "Error", "OTP verification failed", isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  // Resend OTP method
  Future<void> resendOtp(BuildContext context, {String? email}) async {
    if (isLoading.value || !canResendOtp.value) return;
    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      final body = {
        "email": email ?? lastRegisteredEmail ?? emailController.text.trim(),
        "password": passwordController.text,
        "password2": confirmPasswordController.text,
      };

      logger.i("Resend OTP Request: $body");

      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.register,
        isBasic: true,
        body: body,
        showResult: true,
      );

      logger.i("Resend OTP Response: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.body;

        showSnackbar(
          context,
          "Success",
          data['message'] ?? "OTP resent successfully.",
        );

        // Restart the timer
        startOtpTimer();
      } else {
        final errorMessage = response.body['message'] ?? "Failed to resend OTP";
        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Resend OTP Error: $e");
      showSnackbar(context, "Error", "Failed to resend OTP", isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  // Login method
  Future<void> login(BuildContext context) async {
    if (isLoading.value) return;

    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    // Basic validation
    if (email.isEmpty) {
      showSnackbar(
        context,
        "Warning",
        "Please enter your email",
        isError: true,
      );
      return;
    }
    if (password.isEmpty) {
      showSnackbar(
        context,
        "Warning",
        "Please enter your password",
        isError: true,
      );
      return;
    }

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      final body = {"email": email, "password": password};

      logger.i("Login Request: $body");

      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.login,
        isBasic: true,
        body: body,
        showResult: true,
      );

      logger.i("Login Response: ${response.statusCode}");
      logger.i("Login Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = response.body;

        // Save tokens to local storage
        await SharedPrefsHelper.setString(
          AppConstants.token,
          data['access'] ?? '',
        );
        await SharedPrefsHelper.setString(
          AppConstants.refreshToken,
          data['refresh'] ?? '',
        );

        // Save user data
        if (data['user'] != null) {
          await SharedPrefsHelper.setString(
            AppConstants.userId,
            data['user']['id'].toString(),
          );
          await SharedPrefsHelper.setString(
            AppConstants.userEmail,
            data['user']['email'],
          );
        }

        showSnackbar(context, "Success", "Login successful!");

        // Check profile and navigate
        Future.delayed(const Duration(milliseconds: 100), () async {
          if (context.mounted) {
            try {
              final homeController = Get.put(HomeController());

              // Check if profile exists
              final hasProfile = await homeController.checkProfileExists();

              if (hasProfile) {
                logger.i('✅ Profile exists, navigating to home');
                if (context.mounted) {
                  context.go(RoutePath.home.addBasePath);
                }
              } else {
                logger.i('ℹ️ No profile found, navigating to profile setup');
                if (context.mounted) {
                  context.go(RoutePath.profileSetup.addBasePath);
                }
              }
            } catch (e) {
              logger.e('❌ Navigation error: $e');
              if (context.mounted) {
                context.go(RoutePath.profileSetup.addBasePath);
              }
            }
          }
        });
      } else {
        final errorMessage =
            response.body?['message']?.toString() ??
            response.body?['detail']?.toString() ??
            response.body?['error']?.toString() ??
            (response.statusCode == null
                ? "Connection failed. Check your internet."
                : "Invalid credentials (${response.statusCode})");
        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Login Error: $e");
      showSnackbar(
        context,
        "Error",
        "Connection error. Make sure you have internet.",
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Forgot Password - Send OTP
  Future<void> sendForgotPasswordOtp(BuildContext context, String email) async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      final body = {"email": email};

      logger.i("Forgot Password Request: $body");

      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.forgotPassword,
        isBasic: true,
        body: body,
        showResult: true,
      );

      logger.i("Forgot Password Response: ${response.statusCode}");
      logger.i("Forgot Password Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = response.body;

        // Store email for later use
        lastRegisteredEmail = email;

        showSnackbar(
          context,
          "Success",
          data['message'] ?? "OTP sent to your email.",
        );

        // Start OTP timer
        startOtpTimer();

        // Navigate to OTP verification screen
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            GoRouter.of(context).pushNamed(
              RoutePath.verifyRegistration,
              extra: {'email': email, 'from': 'forgot'},
            );
          }
        });
      } else {
        final errorMessage =
            response.body['message'] ??
            response.body['email']?.toString() ??
            "Failed to send OTP";
        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Forgot Password Error: $e");
      showSnackbar(
        context,
        "Error",
        "Failed to send OTP. Please try again.",
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Verify Forgot Password OTP
  Future<void> verifyForgotPasswordOtp(
    BuildContext context,
    String otp,
    String email,
  ) async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      final body = {"email": email, "otp": otp};

      logger.i("Verify Forgot Password OTP Request: $body");

      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.verifyForgotPasswordOtp,
        isBasic: true,
        body: body,
        showResult: true,
      );

      logger.i("Verify Forgot Password OTP Response: ${response.statusCode}");
      logger.i("Verify Forgot Password OTP Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = response.body;

        showSnackbar(
          context,
          "Success",
          data['message'] ?? "OTP verified successfully.",
        );

        // Cancel the timer
        _otpTimer?.cancel();

        // Navigate to password reset screen
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            GoRouter.of(
              context,
            ).pushNamed(RoutePath.passwordReset, extra: {'email': email});
          }
        });
      } else {
        final errorMessage =
            response.body['message'] ??
            response.body['otp']?.toString() ??
            response.body['error']?.toString() ??
            "Invalid OTP";
        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Verify Forgot Password OTP Error: $e");
      showSnackbar(
        context,
        "Error",
        "OTP verification failed. Please try again.",
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Change Password
  Future<void> changePassword(
    BuildContext context,
    String email,
    String newPassword,
    String confirmPassword,
  ) async {
    if (isLoading.value) return;

    // Validate passwords match
    if (newPassword != confirmPassword) {
      showSnackbar(context, "Error", "Passwords do not match", isError: true);
      return;
    }

    // Validate password length
    // if (newPassword.length < 6) {
    //   showSnackbar(
    //     context,
    //     "Error",
    //     "Password must be at least 6 characters",
    //     isError: true,
    //   );
    //   return;
    // }

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      final body = {
        "email": email,
        "new_password": newPassword,
        "confirm_password": confirmPassword,
      };

      logger.i("Change Password Request: ${body.keys}");

      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.changePassword,
        isBasic: true,
        body: body,
        showResult: true,
      );

      logger.i("Change Password Response: ${response.statusCode}");
      logger.i("Change Password Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = response.body;

        showSnackbar(
          context,
          "Success",
          data['message'] ?? "Password changed successfully.",
        );

        // Clear stored email
        lastRegisteredEmail = null;

        // Navigate to sign in screen
        Future.delayed(const Duration(seconds: 1), () {
          if (context.mounted) {
            context.go(RoutePath.signInScreen.addBasePath);
          }
        });
      } else {
        final errorMessage =
            response.body['message'] ??
            response.body['new_password']?.toString() ??
            response.body['error']?.toString() ??
            "Failed to change password";
        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Change Password Error: $e");
      showSnackbar(
        context,
        "Error",
        "Failed to change password. Please try again.",
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Resend Forgot Password OTP
  Future<void> resendForgotPasswordOtp(
    BuildContext context,
    String email,
  ) async {
    if (isLoading.value || !canResendOtp.value) return;
    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      final body = {"email": email};

      logger.i("Resend Forgot Password OTP Request: $body");

      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.forgotPassword,
        isBasic: true,
        body: body,
        showResult: true,
      );

      logger.i("Resend Forgot Password OTP Response: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = response.body;

        showSnackbar(
          context,
          "Success",
          data['message'] ?? "OTP resent successfully.",
        );

        // Restart the timer
        startOtpTimer();
      } else {
        final errorMessage = response.body['message'] ?? "Failed to resend OTP";
        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Resend Forgot Password OTP Error: $e");
      showSnackbar(
        context,
        "Error",
        "Failed to resend OTP. Please try again.",
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────────

  Future<void> loginWithGoogle(BuildContext context) async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId:
            '814440155142-nk7uuemujlkr6jlbs2fa378kjcidn9d9.apps.googleusercontent.com',
      );

      // Sign out first to force account picker on every tap
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();

      if (account == null) {
        // User cancelled
        isLoading.value = false;
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        showSnackbar(
          context,
          "Error",
          "Failed to get Google token",
          isError: true,
        );
        return;
      }

      logger.i("Google id_token obtained, sending to backend");

      final apiClient = ApiClient();
      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.googleAuth,
        isBasic: true,
        body: {"id_token": idToken},
        showResult: true,
      );

      logger.i("Google auth response: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = response.body;

        await SharedPrefsHelper.setString(
          AppConstants.token,
          data['access'] ?? '',
        );
        await SharedPrefsHelper.setString(
          AppConstants.refreshToken,
          data['refresh'] ?? '',
        );
        if (data['user'] != null) {
          await SharedPrefsHelper.setString(
            AppConstants.userId,
            data['user']['id'].toString(),
          );
          await SharedPrefsHelper.setString(
            AppConstants.userEmail,
            data['user']['email'] ?? '',
          );
        }

        showSnackbar(context, "Success", "Google login successful!");

        Future.delayed(const Duration(milliseconds: 100), () async {
          if (context.mounted) {
            try {
              final homeController = Get.put(HomeController());
              final hasProfile = await homeController.checkProfileExists();
              if (context.mounted) {
                context.go(
                  hasProfile
                      ? RoutePath.home.addBasePath
                      : RoutePath.profileSetup.addBasePath,
                );
              }
            } catch (e) {
              logger.e("Navigation error after Google login: $e");
              if (context.mounted)
                context.go(RoutePath.profileSetup.addBasePath);
            }
          }
        });
      } else {
        if (!context.mounted) return;
        final error =
            response.body['detail'] ??
            response.body['message'] ??
            "Google login failed";
        showSnackbar(context, "Error", error.toString(), isError: true);
      }
    } catch (e) {
      logger.e("Google sign-in error: $e");
      if (!context.mounted) return;
      showSnackbar(
        context,
        "Error",
        "Google sign-in failed: $e",
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
