import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mon5majeur_app/core/constants/app_strings.dart';
import 'package:mon5majeur_app/core/language/english.dart';
import 'package:mon5majeur_app/core/language/french.dart';
import 'package:mon5majeur_app/core/utils/datetime_format.dart';
import 'package:mon5majeur_app/presentation/widgets/match_widgets.dart';

class _Tr extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'fr': FrenchTranslation.values,
        'en': EnglishTranslation.values,
      };
}

void main() {
  for (final lang in ['fr', 'en']) {
    testWidgets('texts resolve and the score label fits 320 wide ($lang)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(402, 874),
        builder: (context, child) => GetMaterialApp(
          translations: _Tr(),
          locale: Locale(lang),
          home: Builder(builder: (context) {
            final p = publicationTimeParams();
            final texts = [
              AppString.scoreNotStarted.tr,
              AppString.officialResultsLiveHint.trParams(p),
              AppString.liveScoreOfficialNote.trParams(p),
              AppString.liveScoreLockedDesc.tr,
              AppString.noLiveMatchHint.tr,
            ];
            for (final t in texts) {
              expect(t, isNot(contains('@')));
              expect(t, isNot(equals(t.split(' ').first)));
            }
            return Scaffold(
              body: Row(children: [
                const Expanded(child: Text('Team name A', maxLines: 2)),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 110.w),
                  child: ScoreLockedLabel(text: texts[0]),
                ),
                const Expanded(child: Text('Team name B', maxLines: 2)),
              ]),
            );
          }),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // ignore: avoid_print
      print('$lang label size: ${tester.getSize(find.byType(ScoreLockedLabel))}');
    });
  }
}
