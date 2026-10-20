import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/api_constants.dart';
import '../constants/app_strings.dart';

/// Invitation text: league name + code, then one line per store link that is
/// set (an empty link adds no line).
String buildLeagueInviteMessage({required String name, required String code}) {
  final lines = <String>[
    AppString.shareLeagueMessage.trParams({'name': name, 'code': code}),
  ];
  if (AppConstants.appStoreUrl.isNotEmpty) {
    lines.add(
      AppString.shareLeagueIosLine.trParams({'url': AppConstants.appStoreUrl}),
    );
  }
  if (AppConstants.playStoreUrl.isNotEmpty) {
    lines.add(
      AppString.shareLeagueAndroidLine.trParams({
        'url': AppConstants.playStoreUrl,
      }),
    );
  }
  return lines.join('\n');
}

/// Copies the code, then opens the system share sheet with the invitation.
/// [context] must belong to the tapped button (iPad popover anchor).
Future<void> shareLeagueInvite(
  BuildContext context, {
  required String name,
  required String? code,
}) async {
  final joinCode = code?.trim() ?? '';
  if (joinCode.isEmpty) return;

  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;

  await Clipboard.setData(ClipboardData(text: joinCode));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppString.codeCopied.tr),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  await SharePlus.instance.share(
    ShareParams(
      text: buildLeagueInviteMessage(name: name, code: joinCode),
      sharePositionOrigin: origin,
    ),
  );
}
