import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mon5majeur_app/core/local_db/local_db.dart';

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
    } else if (lang == "French") {
      isEnglish.value = false;
      selectedLanguage.value = lang;
      Get.updateLocale(const Locale("fr", "FR"));
      await SharedPrefsHelper.setBool(AppConstants.language, false);
    }
    update();
  }
}
