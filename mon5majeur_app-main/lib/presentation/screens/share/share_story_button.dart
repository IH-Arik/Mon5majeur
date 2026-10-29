import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import 'share_story_capture.dart';
import 'share_story_model.dart';

/// "Share my result": builds the story with [buildStory] (null = nothing to
/// share), draws it and opens the share sheet. As soon as it is tapped the
/// icon turns into a spinner and the label says the image is being made; it
/// stays disabled while it works. Shows a failure message if it fails. Callers decide whether to show it at all
/// (see `kShareStoryEnabled`).
class ShareStoryButton extends StatefulWidget {
  final Future<ShareStoryData?> Function() buildStory;

  const ShareStoryButton({super.key, required this.buildStory});

  @override
  State<ShareStoryButton> createState() => _ShareStoryButtonState();
}

class _ShareStoryButtonState extends State<ShareStoryButton> {
  bool _sharing = false;

  Future<void> _share(BuildContext buttonContext) async {
    setState(() => _sharing = true);
    try {
      final story = await widget.buildStory();
      if (story == null || !buttonContext.mounted) return;
      await shareShareStory(buttonContext, story);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppString.shareStoryError.tr)),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF8C42);
    return Builder(
      builder: (buttonContext) => TextButton.icon(
        onPressed: _sharing ? null : () => _share(buttonContext),
        icon: _sharing
            ? SizedBox(
                width: 18.r,
                height: 18.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: orange,
                ),
              )
            : Icon(Icons.ios_share, color: orange, size: 18.r),
        label: Text(
          (_sharing ? AppString.shareStoryPreparing : AppString.shareStoryButton)
              .tr,
          style: TextStyle(
            color: orange,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
