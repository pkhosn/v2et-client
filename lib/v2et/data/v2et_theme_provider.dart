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

  static Color appBg(BuildContext context) => isDark(context) ? const Color(0xFF141924) : const Color(0xFFF5F2F8);
  static Color sidebarBg(BuildContext context) => isDark(context) ? const Color(0xFF101520) : const Color(0xFFF0ECF4);
  static Color sidebarBorder(BuildContext context) => isDark(context) ? const Color(0xFF263042) : const Color(0xFFE4DFEB);
  static Color cardBg(BuildContext context) => isDark(context) ? const Color(0xFF1A2233) : const Color(0xFFF4F1F8);
  static Color cardSoftBg(BuildContext context) => isDark(context) ? const Color(0xFF1E2739) : const Color(0xFFF1EDF5);
  static Color cardBorder(BuildContext context) => isDark(context) ? const Color(0xFF2C3648) : const Color(0xFFE3DEE9);
}
