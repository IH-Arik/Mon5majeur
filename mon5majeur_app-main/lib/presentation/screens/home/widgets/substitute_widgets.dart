import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The mark of a substitute who came in: the "swap" icon (🔄), no background, to
/// the right of his jersey. A drawn icon, not the emoji: the same on every phone
/// and on the share image.
class SubstituteEnteredMark extends StatelessWidget {
  const SubstituteEnteredMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.sync,
      size: 22.sp,
      color: Colors.white,
      // readable on the pale lines of the court
      shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
    );
  }
}
