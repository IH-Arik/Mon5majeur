import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:logger/logger.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/local_db/local_db.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/api_url.dart';
import '../home/controllers/home_controller.dart';
import 'profile_controller.dart';

final _log = Logger();

// ── Logo key ↔ asset path helpers ─────────────────────────────────────────────

const _logoKeyToPath = {
  'paris_fc': 'assets/icons/logo1.png',
  'lakers': 'assets/icons/logo2.png',
  'boston_celtics': 'assets/icons/logo3.png',
  'chicago_bulls': 'assets/icons/logo4.png',
  'atlanta_hawks': 'assets/icons/logo5.png',
  'golden_state_warriors': 'assets/icons/logo6.png',
};

const _pathToLogoKey = {
  'assets/icons/logo1.png': 'paris_fc',
  'assets/icons/logo2.png': 'lakers',
  'assets/icons/logo3.png': 'boston_celtics',
  'assets/icons/logo4.png': 'chicago_bulls',
  'assets/icons/logo5.png': 'atlanta_hawks',
  'assets/icons/logo6.png': 'golden_state_warriors',
};

// ── ProfileSettingsScreen ──────────────────────────────────────────────────────

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  int? _profileId;
  String _teamName = '';
  String _email = '';
  int _sinceYear = DateTime.now().year;
  bool _notificationsEnabled = false;
  String selectedTeam = '';
  String selectedLogo = 'assets/icons/logo1.png';
  bool isTeamExpanded = false;
  bool _isSaving = false;

  final List<Map<String, String>> logoOptions = [
    {'name': AppString.logo1.tr, 'path': 'assets/icons/logo1.png'},
    {'name': AppString.logo2.tr, 'path': 'assets/icons/logo2.png'},
    {'name': AppString.logo3.tr, 'path': 'assets/icons/logo3.png'},
    {'name': AppString.logo4.tr, 'path': 'assets/icons/logo4.png'},
    {'name': AppString.logo5.tr, 'path': 'assets/icons/logo5.png'},
    {'name': AppString.logo6.tr, 'path': 'assets/icons/logo6.png'},
  ];

  final List<String> teams = [
    AppString.lakers.tr,
    AppString.bostonCeltics.tr,
    AppString.chicagoBulls.tr,
    AppString.atlantaHawks.tr,
  ];

  @override
  void initState() {
    super.initState();
    _hydrateScreen();
  }

  Future<void> _hydrateScreen() async {
    await _loadCurrentProfile();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCurrentProfile() async {
    _email = await SharedPrefsHelper.getString(AppConstants.userEmail);
    try {
      final homeController = Get.find<HomeController>();
      if (homeController.userProfile.value == null) {
        await homeController.fetchUserProfile();
      }
      final profile = homeController.userProfile.value;
      if (profile != null) {
        _profileId = profile.id;
        _teamName = profile.teamName.isNotEmpty
            ? profile.teamName
            : AppString.defaultTeamName;
        selectedTeam = profile.favoriteTeam.isNotEmpty
            ? profile.favoriteTeam
            : (teams.isNotEmpty ? teams.first : '');
        selectedLogo =
            _logoKeyToPath[profile.teamLogo] ?? 'assets/icons/logo1.png';
        _notificationsEnabled = profile.recivedNotifications;
        if ((profile.createdAt ?? '').isNotEmpty) {
          _sinceYear =
              DateTime.tryParse(profile.createdAt!)?.year ?? _sinceYear;
        }
      } else {
        selectedTeam = teams.isNotEmpty ? teams.first : '';
        _teamName = selectedTeam;
      }
    } catch (_) {
      selectedTeam = teams.isNotEmpty ? teams.first : '';
      _teamName = selectedTeam;
    }
  }

  // ── API helpers ──────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    if (_profileId == null) {
      _showSnack('Profile not loaded yet', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final apiClient = ApiClient();
      final response = await apiClient.patch(
        url: ApiUrl.baseUrl + ApiUrl.updateProfile(_profileId!),
        body: {
          'team_logo': _pathToLogoKey[selectedLogo] ?? 'paris_fc',
          'team_name': _teamName,
          'favorite_team': selectedTeam,
          'recived_notifications': _notificationsEnabled,
        },
      );
      if (response.statusCode == 200) {
        _showSnack('Profile saved');
        // Refresh HomeController so other screens reflect the change
        try {
          await Get.find<HomeController>().fetchUserProfile();
        } catch (_) {}
        await _loadCurrentProfile();
        if (mounted) {
          setState(() {});
        }
      } else {
        final msg = response.body?['detail'] ?? 'Failed to save profile';
        _showSnack(msg.toString(), isError: true);
      }
    } catch (e) {
      _log.e('Save profile error: $e');
      _showSnack('Network error', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearTokens() async {
    await SharedPrefsHelper.remove(AppConstants.token);
    await SharedPrefsHelper.remove(AppConstants.refreshToken);
    await SharedPrefsHelper.remove(AppConstants.userId);
    await SharedPrefsHelper.remove(AppConstants.userEmail);
    await SharedPrefsHelper.setBool(AppConstants.isProfileCompleted, false);
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().resetSessionState();
    }
    if (Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().resetSessionState();
      Get.delete<ProfileController>(force: true);
    }
  }

  Future<void> _logout() async {
    await _clearTokens();
    if (mounted) context.go(RoutePath.signInScreen.addBasePath);
  }

  Future<void> _deleteAccountConfirmed() async {
    final apiClient = ApiClient();
    final success = await apiClient.delete(
      url: ApiUrl.baseUrl + ApiUrl.userProfiles,
      code: 204,
    );
    if (success) {
      await _clearTokens();
      if (mounted) context.go(RoutePath.signInScreen.addBasePath);
    } else {
      if (mounted) _showSnack('Failed to delete account', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF4CAF50),
      ),
    );
  }

  Future<void> _toggleNotifications() async {
    setState(() => _notificationsEnabled = !_notificationsEnabled);
    await _saveProfile();
  }

  Future<void> _refreshFromBackend() async {
    try {
      await Get.find<HomeController>().fetchUserProfile();
      await _loadCurrentProfile();
      if (mounted) {
        setState(() {});
      }
      _showSnack('Profile updated');
    } catch (e) {
      _showSnack('Refresh failed', isError: true);
      _log.e('Refresh profile error: $e');
    }
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────

  void _showLogoPickerDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppString.chooseLogo.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD32F2F),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 18.r),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 1,
                ),
                itemCount: logoOptions.length,
                itemBuilder: (context, index) {
                  final logo = logoOptions[index];
                  final isSelected = selectedLogo == logo['path'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedLogo = logo['path']!);
                      Navigator.pop(context);
                      _saveProfile();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFE8632C)
                              : Colors.transparent,
                          width: 2.w,
                        ),
                      ),
                      padding: EdgeInsets.all(12.w),
                      child: Image.asset(logo['path']!, fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppString.areYouSureLogout.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFB0B0B0)),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Text(
                        AppString.cancel.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Text(
                        AppString.yes.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Delete your account? This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFB0B0B0)),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Text(
                        AppString.cancel.tr,
                        style: TextStyle(color: Colors.white, fontSize: 15.sp),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteAccountConfirmed();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Text(
                        AppString.yes.tr,
                        style: TextStyle(color: Colors.white, fontSize: 15.sp),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build helpers ─────────────────────────────────────────────────────────────

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    Color iconColor = const Color(0xFF2196F3),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0x7FB0B0B0), width: 1.w),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.07,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: SizedBox(
            width: 30.w,
            height: 30.h,
            child: Assets.icons.backButton.image(fit: BoxFit.contain),
          ),
          onPressed: () => context.go(RoutePath.profileScreen.addBasePath),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(22.w),
            child: Column(
              children: [
                SizedBox(height: 20.h),

                // Profile Header — logo + team name from API
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 67.w,
                      height: 67.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1A1A),
                        border: Border.all(
                          color: const Color(0xFF2C2C2C),
                          width: 1.w,
                        ),
                      ),
                      padding: EdgeInsets.all(12.r),
                      child: Image.asset(selectedLogo, fit: BoxFit.contain),
                    ),
                    Positioned(
                      bottom: 0.h,
                      right: 0.w,
                      child: GestureDetector(
                        onTap: _showLogoPickerDialog,
                        child: Container(
                          width: 21.w,
                          height: 21.h,
                          decoration: const BoxDecoration(
                            color: Color(0xFF777777),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add, color: Colors.white, size: 13.r),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Text(
                  _teamName.isNotEmpty ? _teamName : AppString.defaultTeamName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Since $_sinceYear',
                  style: TextStyle(
                    color: const Color(0xFFB0B0B0),
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 30.h),

                // Email
                _buildSettingItem(
                  icon: Icons.email_outlined,
                  title: _email.isNotEmpty ? _email : AppString.emailLabel,
                ),

                // Password → Change Password screen
                _buildSettingItem(
                  icon: Icons.lock_outline,
                  title: AppString.password.tr,
                  trailing: Icon(
                    Icons.edit,
                    color: const Color(0xFF2196F3),
                    size: 16.r,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),

                // Username
                _buildSettingItem(
                  icon: Icons.person_outline,
                  title: _teamName.isNotEmpty ? _teamName : AppString.defaultTeamName,
                ),

                // Favorite Team — saves on selection
                Column(
                  children: [
                    _buildSettingItem(
                      icon: Icons.sports_basketball,
                      title: selectedTeam.isNotEmpty
                          ? selectedTeam
                          : AppString.lakers.tr,
                      iconColor: const Color(0xFFE8632C),
                      trailing: Icon(
                        isTeamExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 24.r,
                      ),
                      onTap: () =>
                          setState(() => isTeamExpanded = !isTeamExpanded),
                    ),
                    if (isTeamExpanded)
                      Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0x7FB0B0B0),
                            width: 1.w,
                          ),
                        ),
                        child: Column(
                          children: teams.map((team) {
                            return ListTile(
                              title: Text(
                                team,
                                style: TextStyle(
                                  color: const Color(0xFFB0B0B0),
                                  fontSize: 14.sp,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  selectedTeam = team.toUpperCase();
                                  isTeamExpanded = false;
                                });
                                _saveProfile();
                              },
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),

                // Other Settings (display only)
                _buildSettingItem(
                  icon: Icons.notifications_outlined,
                  title:
                      '${AppString.notifications.tr} ${_notificationsEnabled ? "ON" : "OFF"}',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (_) => _toggleNotifications(),
                    activeColor: const Color(0xFFE8632C),
                  ),
                  onTap: _toggleNotifications,
                ),
                _buildSettingItem(
                  icon: Icons.sync,
                  title: AppString.update.tr,
                  onTap: _refreshFromBackend,
                ),
                _buildSettingItem(
                  icon: Icons.cookie_outlined,
                  title: AppString.cookiesAds.tr,
                  onTap: () =>
                      context.go(RoutePath.termsOfUseScreen.addBasePath),
                ),
                _buildSettingItem(
                  icon: Icons.shield_outlined,
                  title: AppString.dataProtection.tr,
                  onTap: () =>
                      context.go(RoutePath.privacyPolicyScreen.addBasePath),
                ),
                _buildSettingItem(
                  icon: Icons.article_outlined,
                  title: AppString.legalNotice.tr,
                  onTap: () =>
                      context.go(RoutePath.legalNoticesScreen.addBasePath),
                ),

                SizedBox(height: 24.h),

                // Save indicator
                if (_isSaving)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE8632C),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Saving...',
                          style: TextStyle(
                            color: const Color(0xFFB0B0B0),
                            fontSize: 13.sp,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showDeleteAccountDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 20.r,
                        ),
                        label: Text(
                          AppString.deleteAccount.tr,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showLogoutDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        icon: Icon(
                          Icons.logout,
                          color: const Color(0xFF1A1A1A),
                          size: 20.r,
                        ),
                        label: Text(
                          AppString.logOut.tr,
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── ChangePasswordScreen ───────────────────────────────────────────────────────

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.changePasswordAuth,
        body: {
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
          'confirm_new_password': _confirmPasswordController.text,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppString.passwordUpdated.tr),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context);
      } else {
        final body = response.body;
        String errorMsg = 'Failed to update password';
        if (body is Map) {
          errorMsg = body['detail']?.toString() ??
              body['old_password']?.toString() ??
              body['new_password']?.toString() ??
              errorMsg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0x7FB0B0B0), width: 1.w),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock, color: Colors.white, size: 16.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: TextFormField(
                controller: controller,
                obscureText: !isVisible,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: const Color(0xFF777777),
                    fontSize: 14.sp,
                  ),
                  border: InputBorder.none,
                  errorStyle: TextStyle(
                    color: const Color(0xFFD32F2F),
                    fontSize: 12.sp,
                  ),
                ),
                validator: validator,
              ),
            ),
            IconButton(
              onPressed: onToggleVisibility,
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF777777),
                size: 22.r,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: SizedBox(
            width: 30.w,
            height: 30.h,
            child: Assets.icons.backButton.image(fit: BoxFit.contain),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppString.changePassword.tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  SizedBox(height: 80.h),
                  _buildPasswordField(
                    controller: _oldPasswordController,
                    hint: AppString.oldPassword.tr,
                    isVisible: _isOldPasswordVisible,
                    onToggleVisibility: () => setState(
                      () => _isOldPasswordVisible = !_isOldPasswordVisible,
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? AppString.pleaseEnterOldPassword.tr
                        : null,
                  ),
                  _buildPasswordField(
                    controller: _newPasswordController,
                    hint: AppString.newPassword.tr,
                    isVisible: _isNewPasswordVisible,
                    onToggleVisibility: () => setState(
                      () => _isNewPasswordVisible = !_isNewPasswordVisible,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return AppString.pleaseEnterNewPassword.tr;
                      }
                      if (v.length < 6) return AppString.passwordMinLength.tr;
                      if (v == _oldPasswordController.text) {
                        return AppString.passwordDifferent.tr;
                      }
                      return null;
                    },
                  ),
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    hint: AppString.confirmNewPassword.tr,
                    isVisible: _isConfirmPasswordVisible,
                    onToggleVisibility: () => setState(
                      () =>
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return AppString.pleaseConfirmNewPassword.tr;
                      }
                      if (v != _newPasswordController.text) {
                        return AppString.passwordsDoNotMatch.tr;
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 40.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8632C),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              AppString.updatePassword.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
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
