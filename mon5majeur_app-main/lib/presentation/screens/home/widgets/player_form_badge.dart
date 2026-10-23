import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';

/// Display-only form-trajectory badge (spec Part 1 §4.0): the hot (flaming
/// ball) or cold (iced ball) artwork, fitted in a square box. Renders nothing
/// for `null`/neutral. The artwork is detailed, so it needs ~28px to read.
Widget buildFormBadge(String? form, {double size = 28}) {
  final isHot = form == 'HOT';
  if (!isHot && form != 'COLD') return const SizedBox.shrink();

  final icon = isHot ? Assets.icons.iconHot : Assets.icons.iconCold;
  return Semantics(
    label: (isHot ? AppString.playerFormHot : AppString.playerFormCold).tr,
    image: true,
    excludeSemantics: true,
    child: SizedBox(
      width: size.r,
      height: size.r,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: size * 0.2,
            ),
          ],
        ),
        child: icon.image(fit: BoxFit.contain, filterQuality: FilterQuality.medium),
      ),
    ),
  );
}
