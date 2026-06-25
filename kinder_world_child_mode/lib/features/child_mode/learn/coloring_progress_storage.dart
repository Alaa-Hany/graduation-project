import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kinder_world/core/utils/color_serialization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColoringProgressData {
  const ColoringProgressData({
    required this.colors,
    required this.isCompleted,
  });

  final Map<String, Color> colors;
  final bool isCompleted;
}

class ColoringProgressStorage {
  static const String _prefix = 'coloring_progress_v1_';

  /// Prefix scoping every key for a single child. Used by the cross-device sync
  /// so one child's snapshot never carries another child's coloring.
  static String childPrefix(String childId) => '$_prefix$childId.';

  static Future<ColoringProgressData> load(
    String svgAssetPath, {
    required String childId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_key(svgAssetPath, childId));
    if (raw == null || raw.isEmpty) {
      // One-time migration: earlier builds stored coloring progress under a
      // child-agnostic key shared by every child on the device. Claim it for
      // the first child that opens this drawing, then drop the legacy key so a
      // second child doesn't inherit it.
      final legacyKey = _legacyKey(svgAssetPath);
      final legacyRaw = prefs.getString(legacyKey);
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        await prefs.setString(_key(svgAssetPath, childId), legacyRaw);
        await prefs.remove(legacyKey);
        raw = legacyRaw;
      }
    }
    if (raw == null || raw.isEmpty) {
      return const ColoringProgressData(
          colors: <String, Color>{}, isCompleted: false);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const ColoringProgressData(
            colors: <String, Color>{}, isCompleted: false);
      }

      final colors = <String, Color>{};
      final colorMap = decoded['colors'];
      if (colorMap is Map) {
        colorMap.forEach((key, value) {
          if (key is String && value is String) {
            final parsed = _parseColor(value);
            if (parsed != null && parsed != Colors.white) {
              colors[key] = parsed;
            }
          }
        });
      }

      final completed = decoded['completed'] == true;
      return ColoringProgressData(colors: colors, isCompleted: completed);
    } catch (_) {
      return const ColoringProgressData(
          colors: <String, Color>{}, isCompleted: false);
    }
  }

  static Future<void> save({
    required String svgAssetPath,
    required String childId,
    required Map<String, Color> colors,
    required bool isCompleted,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'completed': isCompleted,
      'colors': colors.map(
        (key, value) => MapEntry(key, _toHex(value)),
      ),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await prefs.setString(_key(svgAssetPath, childId), jsonEncode(payload));
  }

  // The `.` separator is not part of the base64url alphabet, so a child-scoped
  // key can never be confused with a legacy (child-agnostic) one.
  static String _key(String svgAssetPath, String childId) =>
      '${childPrefix(childId)}${base64Url.encode(utf8.encode(svgAssetPath))}';

  static String _legacyKey(String svgAssetPath) =>
      '$_prefix${base64Url.encode(utf8.encode(svgAssetPath))}';

  static Color? _parseColor(String hex) {
    final normalized = hex.replaceAll('#', '').toUpperCase();
    if (normalized.length != 6 && normalized.length != 8) return null;

    final argb = normalized.length == 8 ? normalized : 'FF$normalized';
    final value = int.tryParse(argb, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  static String _toHex(Color color) {
    final argb = colorToArgb32(color);
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}
