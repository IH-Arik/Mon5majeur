import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mon5majeur_app/core/local_db/local_db.dart';

import '../../data/services/api_service.dart';
import '../../data/services/api_url.dart';
import '../constants/api_constants.dart';
import 'english.dart';
import 'french.dart';

class Language extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    "en_US": EnglishTranslation.values,
    "fr_FR": FrenchTranslation.values,
  };
}

class LanguageController extends GetxController {
  final List<String> languages = ["English", "French"];
  RxString selectedLanguage = "English".obs;

  RxBool isEnglish = true.obs;

  @override
  void onInit() {
    super.onInit();
    getLanguageType();
  }

  Future<void> getLanguageType() async {
    isEnglish.value =
        await SharedPrefsHelper.getBool(AppConstants.language) ?? true;

    if (isEnglish.value) {
      selectedLanguage.value = "English";
      Get.updateLocale(const Locale("en", "US"));
    } else {
      selectedLanguage.value = "French";
      Get.updateLocale(const Locale("fr", "FR"));
    }
    update();
  }

  Future<void> changeLanguage(String lang) async {
    if (lang == "English") {
      isEnglish.value = true;
      selectedLanguage.value = lang;
      Get.updateLocale(const Locale("en", "US"));
      await SharedPrefsHelper.setBool(AppConstants.language, true);
      syncCurrentLanguageToBackend();
    } else if (lang == "French") {
      isEnglish.value = false;
      selectedLanguage.value = lang;
      Get.updateLocale(const Locale("fr", "FR"));
      await SharedPrefsHelper.setBool(AppConstants.language, false);
      syncCurrentLanguageToBackend();
    }
    update();
  }

  /// Persists the current locale to the backend User record (dashboard QA
  /// #5: the admin panel's Language field always showed "EN" because this
  /// was purely local GetX/SharedPreferences state before, never sent to
  /// the server). Best-effort and fire-and-forget — a failed sync just
  /// means the admin-facing field is stale until the next attempt, it must
  /// never block or fail the in-app language switch itself. Skipped when
  /// there is no token yet (e.g. the pre-login onboarding language picker)
  /// since there is no user record to update — called again right after
  /// login/signup (see auth_controller._persistAuthSession) to cover
  /// whatever was chosen during onboarding.
  Future<void> syncCurrentLanguageToBackend() async {
    await _syncLanguageToBackend(isEnglish.value ? "en" : "fr");
  }

  Future<void> _syncLanguageToBackend(String langCode) async {
    try {
      final token = await SharedPrefsHelper.getString(AppConstants.token);
      if (token == null || token.isEmpty) return;
      await ApiClient().patch(
        url: '${ApiUrl.baseUrl}${ApiUrl.updateLanguage}',
        body: {'language': langCode},
      );
    } catch (_) {
      // Best-effort — see docstring above.
    }
  }
}
