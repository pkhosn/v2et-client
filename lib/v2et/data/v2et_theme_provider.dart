import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// Fixed brand color for build-time branding.
// Change this value before packaging when you need a different theme color.
const v2etBrandColor = Color(0xFF0665D0);

final v2etAccentColorProvider = Provider<Color>((ref) {
  return v2etBrandColor;
});

class V2etThemePalette {
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  // Light mode: 5% brand tint over white (opaque), Dark mode: slightly lighter than pure black.
  static Color appBg(BuildContext context) => isDark(context) ? const Color(0xFF111722) : const Color(0xFFF3F7FD);
  static Color sidebarBg(BuildContext context) => isDark(context) ? const Color(0xFF000000) : Colors.white;
  static Color sidebarBorder(BuildContext context) => isDark(context) ? const Color(0xFF1D2432) : const Color(0x260665D0);
  static Color cardBg(BuildContext context) => isDark(context) ? const Color(0xFF1A2233) : const Color(0xFFF4F1F8);
  static Color cardSoftBg(BuildContext context) => isDark(context) ? const Color(0xFF1E2739) : const Color(0xFFF1EDF5);
  static Color cardBorder(BuildContext context) => isDark(context) ? const Color(0xFF2C3648) : const Color(0xFFE3DEE9);
}
