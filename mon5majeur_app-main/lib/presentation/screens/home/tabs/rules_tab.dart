import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:mon5majeur_app/core/constants/app_strings.dart';
import 'package:mon5majeur_app/data/services/api_service.dart';
import 'package:mon5majeur_app/data/services/api_url.dart';

class RulesTab extends StatefulWidget {
  const RulesTab({super.key});

  @override
  State<RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<RulesTab> {
  bool _isLoading = true;
  String? _error;
  List<_RuleSection> _sections = const [];

  @override
  void initState() {
    super.initState();
    _fetchRules();
  }

  Future<void> _fetchRules() async {
    try {
      final response = await ApiClient().get(
        url: '${ApiUrl.baseUrl}${ApiUrl.leagueRules}',
        showResult: true,
      );

      if (response.statusCode == 200 && response.body is Map<String, dynamic>) {
        final body = response.body as Map<String, dynamic>;
        final rawSections = body['sections'] as List<dynamic>? ?? const [];
        final sections = rawSections
            .whereType<Map<String, dynamic>>()
            .map(_RuleSection.fromJson)
            .where((section) => section.rules.isNotEmpty)
            .toList();

        if (!mounted) return;
        setState(() {
          _sections = sections;
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = 'Failed to load rules (${response.statusCode}).';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load rules: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14.sp),
          ),
        ),
      );
    }

    if (_sections.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text(
            'No rules available right now.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14.sp),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFF8C42),
      backgroundColor: const Color(0xFF1A1C2A),
      onRefresh: _fetchRules,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        itemCount: _sections.length,
        separatorBuilder: (_, index) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final section = _sections[index];
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1C2A),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFF2A2D3E)),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 6.h,
                ),
                childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                iconColor: const Color(0xFFFF8C42),
                collapsedIconColor: Colors.white70,
                title: Text(
                  section.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [
                  for (final rule in section.rules)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 7.h),
                            child: Container(
                              width: 6.r,
                              height: 6.r,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF8C42),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              rule,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13.sp,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RuleSection {
  final String title;
  final List<String> rules;

  const _RuleSection({
    required this.title,
    required this.rules,
  });

  factory _RuleSection.fromJson(Map<String, dynamic> json) {
    final rawRules = json['rules'] as List<dynamic>? ?? const [];
    return _RuleSection(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : AppString.rules.tr,
      rules: rawRules.map((rule) => rule.toString().trim()).where((rule) => rule.isNotEmpty).toList(),
    );
  }
}
