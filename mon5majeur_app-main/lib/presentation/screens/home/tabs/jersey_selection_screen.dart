import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/constants/app_strings.dart';

class JerseySelectionScreen extends StatefulWidget {
  const JerseySelectionScreen({super.key});

  @override
  State<JerseySelectionScreen> createState() => _JerseySelectionScreenState();
}

class _JerseySelectionScreenState extends State<JerseySelectionScreen> {
  int? selectedJerseyIndex;

  final List<AssetGenImage> jerseys = [
    Assets.icons.jerseyDevil,
    Assets.icons.jerseyFlower,
    Assets.icons.jerseyUfo,
    Assets.icons.jerseyShark,
    Assets.icons.jerseySnake,
    Assets.icons.jerseyZebra,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Assets.icons.backButton.image(
            fit: BoxFit.contain,
            width: 24.r,
            height: 24.r,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 20.h),
          Text(
            AppString.chooseYourJersey.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 40.h),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16.w,
                  mainAxisSpacing: 16.h,
                  childAspectRatio: 0.85,
                ),
                itemCount: jerseys.length,
                itemBuilder: (context, index) {
                  final isSelected = selectedJerseyIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedJerseyIndex = index;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF8C42)
                            : const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF8C42)
                              : const Color(0xFF1A1A1A),
                          width: 2.r,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.r),
                        child: jerseys[index].image(
                          fit: BoxFit.contain,
                          width: 48.r,
                          height: 48.r,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24.w),
            child: SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: selectedJerseyIndex != null
                    ? () {
                        Navigator.pop(context, selectedJerseyIndex);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C42),
                  disabledBackgroundColor: const Color(0xFF2C2C2C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  AppString.confirm.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
