import 'package:flutter/material.dart';

OverlayEntry? _v2etNoticeEntry;

void showV2etNotice(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
  bool error = false,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _v2etNoticeEntry?.remove();
  _v2etNoticeEntry = OverlayEntry(
    builder: (overlayContext) {
      final top = MediaQuery.of(overlayContext).padding.top + 12;
      return Positioned(
        top: top,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: error ? const Color(0xFFC62828) : const Color(0xFF4F4A57),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(_v2etNoticeEntry!);
  Future<void>.delayed(duration, () {
    _v2etNoticeEntry?.remove();
    _v2etNoticeEntry = null;
  });
}
