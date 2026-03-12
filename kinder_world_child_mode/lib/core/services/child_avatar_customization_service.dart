import 'package:kinder_world/core/models/child_avatar_customization.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChildAvatarCustomizationService {
  ChildAvatarCustomizationService({
    required SharedPreferences sharedPreferences,
    required Logger logger,
  })  : _sharedPreferences = sharedPreferences,
        _logger = logger;

  final SharedPreferences _sharedPreferences;
  final Logger _logger;

  String _keyFor(String childId) => 'child_avatar_customization_$childId';

  Future<ChildAvatarCustomization> load(String childId) async {
    try {
      final raw = _sharedPreferences.getString(_keyFor(childId));
      if (raw == null || raw.isEmpty) {
        return ChildAvatarCustomization.defaults();
      }
      return ChildAvatarCustomization.decode(raw);
    } catch (e) {
      _logger.e('Error loading child avatar customization: $e');
      return ChildAvatarCustomization.defaults();
    }
  }

  Future<bool> save(
    String childId,
    ChildAvatarCustomization customization,
  ) async {
    try {
      return _sharedPreferences.setString(
        _keyFor(childId),
        customization.encode(),
      );
    } catch (e) {
      _logger.e('Error saving child avatar customization: $e');
      return false;
    }
  }
}
