import 'package:flutter/material.dart';
import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final v2etAccentColorProvider = Provider<Color>((ref) {
  final runtime = ref.watch(v2etRuntimeConfigProvider).valueOrNull;
  return _parseColorHex(runtime?.primaryColorHex) ?? const Color(0xFF573C87);
});

Color? _parseColorHex(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;
  var hex = value.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final intValue = int.tryParse(hex, radix: 16);
  if (intValue == null) return null;
  return Color(intValue);
}
