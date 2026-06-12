import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TextInputBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const TextInputBox({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: const Color(0xFFB1B1B1), fontSize: 14.sp),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: const Color(0xFFB1B1B1), fontSize: 14.sp),
        hintText: hintText,
        hintStyle: TextStyle(color: const Color(0xFFB1B1B1), fontSize: 14.sp),
        suffixIcon: suffixIcon,
        errorStyle: TextStyle(color: Colors.red, fontSize: 12.sp),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: const Color(0xFFB1B1B1), width: 1.w),
          borderRadius: BorderRadius.circular(8.r),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: const Color(0xFFE8632C), width: 1.w),
          borderRadius: BorderRadius.circular(8.r),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 1.w),
          borderRadius: BorderRadius.circular(8.r),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 1.w),
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
    );
  }
}
