import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mon5majeur_app/core/constants/app_strings.dart';
import 'package:mon5majeur_app/core/language/english.dart';
import 'package:mon5majeur_app/core/language/french.dart';
import 'package:mon5majeur_app/core/utils/server_message.dart';
import 'package:mon5majeur_app/core/utils/datetime_format.dart';

void main() {
  test('next 9:00 Paris', () {
    // Oct 29 2026 (CET after DST end on Oct 25): 9h Paris = 08:00 UTC
    expect(nextParisNineAm(DateTime.utc(2026, 10, 29, 20)), DateTime.utc(2026, 10, 30, 8));
    expect(nextParisNineAm(DateTime.utc(2026, 10, 29, 7)), DateTime.utc(2026, 10, 29, 8));
    // July (CEST): 9h Paris = 07:00 UTC
    expect(nextParisNineAm(DateTime.utc(2026, 7, 10, 12)), DateTime.utc(2026, 7, 11, 7));
  });
  publicationTextTests();
}

class _Tr extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'fr': FrenchTranslation.values,
        'en': EnglishTranslation.values,
      };
}

void publicationTextTests() {
  for (final lang in ['fr', 'en']) {
    testWidgets('publication texts use the local time ($lang)', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(translations: _Tr(), locale: Locale(lang), home: const SizedBox()),
      );
      final time = publicationTimeParams()['time']!;
      for (final text in [
        AppString.lineupLocked.trParams(publicationTimeParams()),
        AppString.lockClosed.trParams(publicationTimeParams()),
        AppString.scoreAvailableAt9.trParams(publicationTimeParams()),
        AppString.officialResultsLiveHint.trParams(publicationTimeParams()),
        localizeServerMessage(AppString.serverLineupLocked),
      ]) {
        expect(text, contains(time));
        expect(text, isNot(contains('@time')));
      }
      expect(AppString.bonusRevealTime.trParams(publicationTimeParams()), time);
    });
  }
}
