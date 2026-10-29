import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mon5majeur_app/core/language/english.dart';
import 'package:mon5majeur_app/core/language/french.dart';
import 'package:mon5majeur_app/core/utils/team_save_error.dart';

class _Tr extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {'fr': FrenchTranslation.values, 'en': EnglishTranslation.values};
}

void main() {
  test('classification', () {
    expect(teamSaveFailureFor(null), TeamSaveFailure.offline);
    expect(teamSaveFailureFor(401), TeamSaveFailure.sessionExpired);
    expect(teamSaveFailureFor(500), TeamSaveFailure.server);
    expect(teamSaveFailureFor(422), TeamSaveFailure.server);
  });

  test('safeServerDetail never throws', () {
    expect(safeServerDetail(null), isNull);
    expect(safeServerDetail('<html>502</html>'), isNull);
    expect(safeServerDetail({'detail': 'locked'}), 'locked');
    expect(safeServerDetail({'detail': [{'msg': 'x'}]}), isA<String>());
    expect(safeServerDetail({}), isNull);
  });

  for (final lang in ['fr', 'en']) {
    for (final f in TeamSaveFailure.values) {
      testWidgets('snackbar fits 320x568 $lang $f', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(GetMaterialApp(
          translations: _Tr(),
          locale: Locale(lang),
          home: Scaffold(body: Builder(builder: (c) => TextButton(
            onPressed: () => ScaffoldMessenger.of(c).showSnackBar(
              SnackBar(content: Text(teamSaveFailureMessage(f)))),
            child: const Text('go')))),
        ));
        await tester.tap(find.text('go'));
        await tester.pump(); await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        final h = tester.getSize(find.text(teamSaveFailureMessage(f))).height;
        // ignore: avoid_print
        print('$lang $f snackbar height=$h');
        expect(h, lessThan(110));
      });
    }
  }
}
