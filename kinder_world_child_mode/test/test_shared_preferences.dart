import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<Override>> createSharedPreferencesOverrides([
  Map<String, Object> initialValues = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final preferences = await SharedPreferences.getInstance();
  return <Override>[
    loggerProvider.overrideWithValue(Logger()),
    sharedPreferencesProvider.overrideWithValue(preferences),
  ];
}
