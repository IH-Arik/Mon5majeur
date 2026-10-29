import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import 'share_story_samples.dart';
import 'share_story_widget.dart';

/// Debug-only: every share story variant, one under the other. Reached from a
/// long press on the drawer's logo (see HomeDrawer); not shipped in release.
class ShareStoryPreviewScreen extends StatelessWidget {
  const ShareStoryPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final variants = ShareStorySamples.variants();
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        title: Text(AppString.sharePreviewTitle.tr),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: variants.length,
        separatorBuilder: (_, _) => const SizedBox(height: 24),
        itemBuilder: (context, i) {
          final v = variants[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${i + 1}. ${v.label.tr}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: ShareStoryWidget(data: v.data),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
