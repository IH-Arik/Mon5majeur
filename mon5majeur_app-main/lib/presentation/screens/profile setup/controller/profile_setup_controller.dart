// lib/presentation/screens/profile setup/controller/profile_setup_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/profile_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';
import '../../home/controllers/home_controller.dart';

final logger = Logger();

class ProfileSetupController extends GetxController {
  final bool isEditMode;

  ProfileSetupController({this.isEditMode = false});

  // Observable variables
  var isLoading = false.obs;
  var selectedLogoIndex = 0.obs;
  var selectedFavoriteTeam = ''.obs;
  var selectedDate = Rx<DateTime?>(null);
  var termsAccepted = true.obs;
  var notificationsAccepted = false.obs;
  var showNotificationOptions = false.obs;

  // Text controller
  final teamNameController = TextEditingController();

  // Teams list - should match your app strings
  final List<String> teams = [
    'Los Angeles Lakers',
    'Boston Celtics',
    'Chicago Bulls',
    'Atlanta Hawks',
    'Miami Heat',
  ];

  @override
  void onInit() {
    super.onInit();
    // Initialize with a reasonable default (18 years ago)
    selectedDate.value = DateTime.now().subtract(
      const Duration(days: 365 * 18),
    );

    // ✅ If edit mode, load existing profile
    if (isEditMode) {
      loadExistingProfile();
    }
  }

  @override
  void onClose() {
    teamNameController.dispose();
    super.onClose();
  }

  Future<void> loadExistingProfile() async {
    final homeController = Get.find<HomeController>();
    if (homeController.userProfile.value != null) {
      final profile = homeController.userProfile.value!;
      teamNameController.text = profile.teamName;
      selectedFavoriteTeam.value = profile.favoriteTeam;
      selectedDate.value = DateTime.parse(profile.dateOfBirth);
      termsAccepted.value = profile.acceptTermsConditions;
      notificationsAccepted.value = profile.recivedNotifications;

      // Map team logo to index
      final logoMap = {
        'paris_fc': 0,
        'lakers': 1,
        'boston_celtics': 2,
        'chicago_bulls': 3,
        'atlanta_hawks': 4,
        'golden_state_warriors': 5,
      };
      selectedLogoIndex.value = logoMap[profile.teamLogo] ?? 0;
    }
  }

  // Toggle methods
  void toggleTermsAccepted() {
    termsAccepted.value = !termsAccepted.value;
  }

  void toggleNotificationsAccepted() {
    notificationsAccepted.value = !notificationsAccepted.value;
    if (!notificationsAccepted.value) {
      showNotificationOptions.value = false;
    }
  }

  void toggleNotificationOptions() {
    showNotificationOptions.value = !showNotificationOptions.value;
  }

  void updateSelectedLogo(int index) {
    selectedLogoIndex.value = index;
  }

  void updateFavoriteTeam(String team) {
    selectedFavoriteTeam.value = team;
  }

  void updateSelectedDate(DateTime date) {
    selectedDate.value = date;
  }

  // Show snackbar
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

  // Validation
  bool validateForm(BuildContext context) {
    if (teamNameController.text.trim().isEmpty) {
      showSnackbar(
        context,
        'Validation Error',
        'Please enter a team name',
        isError: true,
      );
      return false;
    }

    // if (selectedFavoriteTeam.value.isEmpty) {
    //   showSnackbar(
    //     context,
    //     'Validation Error',
    //     'Please select your favorite team',
    //     isError: true,
    //   );
    //   return false;
    // }

    if (selectedDate.value == null) {
      showSnackbar(
        context,
        'Validation Error',
        'Please select your date of birth',
        isError: true,
      );
      return false;
    }

    if (!termsAccepted.value) {
      showSnackbar(
        context,
        'Validation Error',
        'Please accept the terms and conditions',
        isError: true,
      );
      return false;
    }

    return true;
  }

  // Save profile
  Future<void> saveProfile(BuildContext context) async {
    if (isLoading.value) return;

    if (!validateForm(context)) return;

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      // Format date as YYYY-MM-DD
      final formattedDate = DateFormat(
        'yyyy-MM-dd',
      ).format(selectedDate.value!);

      // Get team logo based on selected index
      final teamLogo = TeamLogoChoices.getTeamLogoByIndex(
        selectedLogoIndex.value,
      );

      // Create profile model
      final profileData = UserProfileModel(
        teamLogo: teamLogo,
        teamName: teamNameController.text.trim(),
        favoriteTeam: selectedFavoriteTeam.value,
        dateOfBirth: formattedDate,
        acceptTermsConditions: termsAccepted.value,
        recivedNotifications: notificationsAccepted.value,
      );

      logger.i('Profile Setup Request: ${profileData.toJson()}');

      // ✅ CHECK IF PROFILE EXISTS FIRST
      final checkResponse = await apiClient.get(
        url: ApiUrl.baseUrl + ApiUrl.userProfiles,
        isBasic: false,
        showResult: true,
      );

      Response response;

      // If profile exists, use PATCH to update (but exclude team_name)
      if (checkResponse.statusCode == 200 &&
          checkResponse.body is List &&
          (checkResponse.body as List).isNotEmpty) {
        final profileId = (checkResponse.body as List).first['id'];
        logger.i('Profile exists with ID: $profileId, updating...');

        // ✅ Remove team_name from updates to avoid unique constraint issues
        Map<String, dynamic> updateData = profileData.toJson();
        updateData.remove(
          'team_name',
        ); // Team name cannot be changed after creation

        logger.i('Updating profile without team_name field');

        response = await apiClient.patch(
          url: '${ApiUrl.baseUrl}${ApiUrl.userProfiles}$profileId/',
          isBasic: false,
          body: updateData,
          showResult: true,
        );
      } else {
        // No profile exists, create new one
        logger.i('No profile found, creating new...');

        response = await apiClient.post(
          url: ApiUrl.baseUrl + ApiUrl.userProfiles,
          isBasic: false,
          body: profileData.toJson(),
          showResult: true,
        );
      }

      logger.i('Profile Setup Response: ${response.statusCode}');
      logger.i('Profile Setup Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final savedProfile = UserProfileModel.fromJson(response.body);

        logger.i('Profile saved successfully: $savedProfile');

        // ✅ Save profile completion flag to local storage
        await SharedPrefsHelper.setBool(AppConstants.isProfileCompleted, true);

        showSnackbar(
          context,
          'Success',
          'Profile setup completed successfully!',
        );

        // Navigate to home screen
        Future.delayed(const Duration(seconds: 1), () {
          if (context.mounted) {
            context.go(RoutePath.home.addBasePath);
          }
        });
      } else if (response.statusCode == 400) {
        // Handle validation errors
        final errorBody = response.body;
        String errorMsg = 'Please check your input and try again.';

        if (errorBody is Map) {
          if (errorBody['team_name'] != null) {
            errorMsg = errorBody['team_name'] is List
                ? errorBody['team_name'].first
                : errorBody['team_name'].toString();
          } else if (errorBody['detail'] != null) {
            errorMsg = errorBody['detail'];
          } else if (errorBody['error'] != null) {
            errorMsg = errorBody['error'];
          }
        }

        showSnackbar(context, "Error", errorMsg, isError: true);
      } else if (response.statusCode == 500) {
        // Handle server errors specifically
        showSnackbar(
          context,
          "Server Error",
          "The server encountered an error. Please try again or contact support.",
          isError: true,
        );
      } else {
        showSnackbar(
          context,
          "Error",
          "Failed to save profile. Please try again.",
          isError: true,
        );
      }
    } catch (e) {
      logger.e('Profile Setup Error: $e');
      showSnackbar(
        context,
        'Error',
        'Failed to save profile. Please try again.',
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
