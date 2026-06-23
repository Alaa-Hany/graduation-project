import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/cache/app_cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String meta(CacheSyncState state) => jsonEncode({'sync_state': state.name});

  test('migrate purges synced payloads and stamps the schema version',
      () async {
    SharedPreferences.setMockInitialValues({
      'cache.payload.content.items': '[{"title_ar":"old"}]',
      'cache.meta.content.items': meta(CacheSyncState.synced),
      'unrelated.key': 'keep-me',
    });
    final prefs = await SharedPreferences.getInstance();

    final purged = await AppCacheStore.migrate(prefs);

    expect(purged, 1);
    expect(prefs.containsKey('cache.payload.content.items'), isFalse);
    expect(prefs.containsKey('cache.meta.content.items'), isFalse);
    expect(prefs.getString('unrelated.key'), 'keep-me');
    expect(prefs.getInt('cache.schema_version'),
        AppCacheStore.cacheSchemaVersion);
  });

  test('migrate keeps unsynced local mutations', () async {
    SharedPreferences.setMockInitialValues({
      'cache.payload.progress.local': '[{"x":1}]',
      'cache.meta.progress.local': meta(CacheSyncState.pendingSync),
    });
    final prefs = await SharedPreferences.getInstance();

    final purged = await AppCacheStore.migrate(prefs);

    expect(purged, 0);
    expect(prefs.containsKey('cache.payload.progress.local'), isTrue);
  });

  test('migrate is a no-op once the schema version is current', () async {
    SharedPreferences.setMockInitialValues({
      'cache.schema_version': AppCacheStore.cacheSchemaVersion,
      'cache.payload.content.items': '[{"title_ar":"fresh"}]',
      'cache.meta.content.items': meta(CacheSyncState.synced),
    });
    final prefs = await SharedPreferences.getInstance();

    final purged = await AppCacheStore.migrate(prefs);

    expect(purged, 0);
    expect(prefs.containsKey('cache.payload.content.items'), isTrue);
  });
}
