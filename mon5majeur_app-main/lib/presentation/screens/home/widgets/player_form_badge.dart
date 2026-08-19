import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/custom_assets/assets.gen.dart';

/// Display-only form-trajectory badge (spec Part 1 §4.0). Renders nothing
/// for `null`/neutral.
Widget buildFormBadge(String? form, {double size = 16}) {
  if (form == 'HOT') {
    return Assets.icons.fireball.image(width: size.r, height: size.r);
  }
  if (form == 'COLD') {
    return Container(
      width: size.r,
      height: size.r,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB9F2FF), Color(0xFF5AB7FF)],
        ),
        border: Border.all(color: const Color(0xFFE6FBFF), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5AB7FF).withValues(alpha: 0.28),
            blurRadius: size * 0.25,
          ),
        ],
      ),
      child: Text(
        'C',
        style: TextStyle(
          color: const Color(0xFF083B66),
          fontSize: (size * 0.55).r,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
  return const SizedBox.shrink();
}
