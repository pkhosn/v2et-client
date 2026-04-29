import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// Fixed brand color for build-time branding.
// Change this value before packaging when you need a different theme color.
const v2etBrandColor = Color(0xFF573C87);

final v2etAccentColorProvider = Provider<Color>((ref) {
  return v2etBrandColor;
});
