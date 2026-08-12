import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/custom_assets/assets.gen.dart';

/// Display-only form-trajectory badge (spec Part 1 §4.0). Renders nothing
/// for `null`/neutral — there is no neutral asset, per spec.
///
/// HOT uses the supplied `fireball.png` asset. COLD has no supplied asset
/// yet — this renders a TEMPORARY Material-icon placeholder (ice-blue
/// snowflake) until a matching iceball PNG is provided; swap the `else if`
/// branch for an `Assets.icons.<iceball>.image(...)` once it exists.
Widget buildFormBadge(String? form, {double size = 16}) {
  if (form == 'HOT') {
    return Assets.icons.fireball.image(width: size.r, height: size.r);
  }
  if (form == 'COLD') {
    return Icon(Icons.ac_unit, color: const Color(0xFF6EC6FF), size: size.r);
  }
  return const SizedBox.shrink();
}
