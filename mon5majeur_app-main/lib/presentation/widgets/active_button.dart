import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ActiveButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double height;

  const ActiveButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.height = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height.h,
      width: double.infinity, // Full width across device
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8632C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(fontSize: 16.sp, color: Colors.white),
        ),
      ),
    );
  }
}
