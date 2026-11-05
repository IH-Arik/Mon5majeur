import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mon5majeur_app/core/constants/app_strings.dart';
import 'package:mon5majeur_app/core/language/english.dart';
import 'package:mon5majeur_app/core/language/french.dart';
import 'package:mon5majeur_app/core/utils/server_message.dart';

class _Tr extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'fr': FrenchTranslation.values,
        'en': EnglishTranslation.values,
      };
}

void main() {
  for (final lang in ['fr', 'en']) {
    for (final key in [
      AppString.otpSentSignup,
      AppString.otpSentForgotPassword,
      AppString.noLeaguesJoinedYet,
    ]) {
      testWidgets('$key fits 320 wide ($lang)', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(GetMaterialApp(
          translations: _Tr(),
          locale: Locale(lang),
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => ScaffoldMessenger.of(c).showSnackBar(SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppString.successGeneric.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(localizeServerMessage(key.tr)),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(10),
                )),
                child: const Text('go'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.text(key.tr), findsOneWidget);
        expect(key.tr, isNot(equals(key)));
        // ignore: avoid_print
        print('$lang $key height=${tester.getSize(find.text(key.tr)).height}');
      });
    }
  }
}
