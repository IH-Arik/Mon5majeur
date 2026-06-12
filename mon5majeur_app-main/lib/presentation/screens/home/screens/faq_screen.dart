import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  int? _expandedIndex;

  final List<Map<String, String>> _faqItems = [
    {
      'question': AppString.whatIsThisGameQ,
      'answer': AppString.whatIsThisGameA,
    },
    {
      'question': AppString.howArePointsCalculatedQ,
      'answer': AppString.howArePointsCalculatedA,
    },
    {
      'question': AppString.canPlayMultipleLeaguesQ,
      'answer': AppString.canPlayMultipleLeaguesA,
    },
    {
      'question': AppString.howToJoinPrivateLeagueQ,
      'answer': AppString.howToJoinPrivateLeagueA,
    },
    {
      'question': AppString.canJoinPublicLeagueQ,
      'answer': AppString.canJoinPublicLeagueA,
    },
    {
      'question': AppString.canLeaveLeagueQ,
      'answer': AppString.canLeaveLeagueA,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Assets.icons.backButton.image(fit: BoxFit.contain),
          onPressed: () => context.go(RoutePath.home.addBasePath),
        ),
        title: Text(
          AppString.faqTitle.tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: _faqItems.length,
          itemBuilder: (context, index) {
            final isExpanded = _expandedIndex == index;
            final item = _faqItems[index];

            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFF333333),
                    width: 1.w,
                  ),
                ),
                child: Column(
                  children: [
                    /// Question Header
                    InkWell(
                      onTap: () {
                        setState(() {
                          _expandedIndex = isExpanded ? null : index;
                        });
                      },
                      borderRadius: BorderRadius.circular(12.r),
                      child: Padding(
                        padding: EdgeInsets.all(20.w),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['question']!.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 28.r,
                            ),
                          ],
                        ),
                      ),
                    ),

                    /// Answer Content (Expandable)
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                        child: Text(
                          item['answer']!.tr,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14.sp,
                            height: 1.5,
                          ),
                        ),
                      ),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
