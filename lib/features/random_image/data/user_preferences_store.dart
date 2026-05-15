import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/shared_preferences_provider.dart';
import '../domain/image_query.dart';

final userPreferencesStoreProvider = Provider<UserPreferencesStore>((ref) {
  return UserPreferencesStore(ref.watch(sharedPreferencesProvider));
});

class UserPreferencesStore {
  UserPreferencesStore(this._preferences);

  static const _introSeenKey = 'nice_view.intro_seen';
  static const _defaultOrientationKey = 'nice_view.default_orientation';
  static const _defaultCategoryKey = 'nice_view.default_category';
  static const _defaultExcludedTagsKey = 'nice_view.default_excluded_tags';

  final SharedPreferences _preferences;

  bool loadIntroSeen() {
    return _preferences.getBool(_introSeenKey) ?? false;
  }

  Future<void> saveIntroSeen() {
    return _preferences.setBool(_introSeenKey, true);
  }

  ImageQuery loadDefaultQuery() {
    return ImageQuery(
      orientation: ImageOrientation.fromApiValue(
        _preferences.getString(_defaultOrientationKey),
      ),
      category: _normalizeString(_preferences.getString(_defaultCategoryKey)),
      excludeTags: _preferences.getStringList(_defaultExcludedTagsKey) ??
          const <String>[],
    );
  }

  Future<void> saveDefaultQuery(ImageQuery query) async {
    final orientation = query.orientation;
    if (orientation == null) {
      await _preferences.remove(_defaultOrientationKey);
    } else {
      await _preferences.setString(
        _defaultOrientationKey,
        orientation.apiValue,
      );
    }

    final category = _normalizeString(query.category);
    if (category == null) {
      await _preferences.remove(_defaultCategoryKey);
    } else {
      await _preferences.setString(_defaultCategoryKey, category);
    }

    await _preferences.setStringList(
      _defaultExcludedTagsKey,
      _normalizeList(query.excludeTags),
    );
  }

  Future<void> clearDefaultQuery() {
    return saveDefaultQuery(const ImageQuery());
  }

  String? _normalizeString(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  List<String> _normalizeList(List<String> values) {
    final normalized = <String>[];
    for (final value in values) {
      final item = value.trim();
      if (item.isEmpty) {
        continue;
      }
      if (!normalized.any((entry) => entry.toLowerCase() == item.toLowerCase())) {
        normalized.add(item);
      }
    }
    return normalized;
  }
}
