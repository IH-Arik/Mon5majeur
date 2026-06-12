import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/custom_assets/assets.gen.dart';

class PasswordInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const PasswordInput({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscurePassword,
      style: TextStyle(color: Colors.white, fontSize: 16.sp),
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: Colors.white54, fontSize: 14.sp),
        hintText: "********",
        hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
        errorStyle: TextStyle(color: Colors.red, fontSize: 12.sp),
        suffixIcon: InkWell(
          onTap: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          child: Padding(
            padding: EdgeInsets.all(12.0.w),
            child: _obscurePassword
                ? Assets.icons.eyeOff.image(width: 20.r, height: 20.r)
                : Assets.icons.eye.image(width: 20.r, height: 20.r),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey, width: 1.w),
          borderRadius: BorderRadius.circular(8.r),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE8632C), width: 1.w),
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
