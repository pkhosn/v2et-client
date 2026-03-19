import 'package:flutter/material.dart';

void showV2etNotice(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: error ? const Color(0xFFC62828) : const Color(0xFF4F4A57),
    ),
  );
}
