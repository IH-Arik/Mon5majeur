// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// import '../../../helper/local_db/local_db.dart';
// import '../../../utils/app_const/app_const.dart';
// import '../german/german.dart';
// import '../eng/eng.dart';

// class Language extends Translations {
//   @override
//   Map<String, Map<String, String>> get keys => {
//         "en_US": english,
//         "de_DE": german,
//       };
// }

// class LanguageController extends GetxController {
//   final List<String> languages = ["English", "German"];
//   RxString selectedLanguage = "English".obs;

//   RxBool isEnglish = true.obs;

//   @override
//   void onInit() {
//     super.onInit();
//     getLanguageType();
//   }

//   Future<void> getLanguageType() async {
//     isEnglish.value =
//         await SharedPrefsHelper.getBool(AppConstants.language) ?? true;

//     if (isEnglish.value) {
//       selectedLanguage.value = "English";
//       Get.updateLocale(const Locale("en", "US"));
//     } else {
//       selectedLanguage.value = "German";
//       Get.updateLocale(const Locale("de", "DE"));
//     }
//     update();
//   }

//   Future<void> changeLanguage(String lang) async {
//     if (lang == "English") {
//       isEnglish.value = true;
//       selectedLanguage.value = lang;
//       Get.updateLocale(const Locale("en", "US"));
//       await SharedPrefsHelper.setBool(AppConstants.language, true);
//     } else if (lang == "German") {
//       isEnglish.value = false;
//       selectedLanguage.value = lang;
//       Get.updateLocale(const Locale("de", "DE"));
//       await SharedPrefsHelper.setBool(AppConstants.language, false);
//     }
//     update();
//   }
// }
