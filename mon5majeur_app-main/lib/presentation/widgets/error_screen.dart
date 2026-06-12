import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Error Page",
          style: TextStyle(fontSize: 20.sp),
        ),
        toolbarHeight: 56.h,
      ),
    );
  }
}
