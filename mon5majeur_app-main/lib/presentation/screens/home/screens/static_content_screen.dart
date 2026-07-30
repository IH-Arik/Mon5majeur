// lib/presentation/screens/home/screens/static_content_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

/// Reusable page for the GDPR-required static pages (About Us, Legal
/// Notices, Privacy Policy) — each is just a {title, body} fetched from
/// the backend's content endpoints.
class StaticContentScreen extends StatefulWidget {
  final String screenTitle;
  final String endpoint;

  const StaticContentScreen({
    super.key,
    required this.screenTitle,
    required this.endpoint,
  });

  @override
  State<StaticContentScreen> createState() => _StaticContentScreenState();
}

class _StaticContentScreenState extends State<StaticContentScreen> {
  bool _isLoading = true;
  String? _body;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    try {
      final apiClient = ApiClient();
      final response = await apiClient.get(
        url: '${ApiUrl.baseUrl}${widget.endpoint}',
        showResult: true,
      );

      if (response.statusCode == 200 && response.body != null) {
        setState(() {
          _body = response.body['body'] as String?;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load content (${response.statusCode}).';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load content: $e';
        _isLoading = false;
      });
    }
  }

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
          widget.screenTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      _body ?? '',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14.sp,
                        height: 1.6,
                      ),
                    ),
                  ),
      ),
    );
  }
}
