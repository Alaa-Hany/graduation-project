import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/api/auth_api.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/user.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/services/child_profiles_view_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/features/auth/child_login_screen.dart';
import 'package:logger/logger.dart';

class _TestSecureStorage extends SecureStorage {
  String? authToken;
  String? userId;
  String? userRole;
  String? childSession;
  String? userEmail;
  bool parentPinVerified = false;

  @override
  Future<String?> getAuthToken() async => authToken;

  @override
  bool get hasCachedAuthToken => authToken != null;

  @override
  String? get cachedAuthToken => authToken;

  @override
  Future<bool> saveAuthToken(String token) async {
    authToken = token;
    return true;
  }

  @override
  Future<String?> getUserId() async => userId;

  @override
  bool get hasCachedUserId => userId != null;

  @override
  String? get cachedUserId => userId;

  @override
  Future<bool> saveUserId(String value) async {
    userId = value;
    return true;
  }

  @override
  Future<String?> getUserRole() async => userRole;

  @override
  Future<bool> saveUserRole(String value) async {
    userRole = value;
    return true;
  }

  @override
  Future<String?> getChildSession() async => childSession;

  @override
  Future<bool> saveChildSession(String childId) async {
    childSession = childId;
    return true;
  }

  @override
  Future<bool> clearChildSession() async {
    childSession = null;
    return true;
  }

  @override
  Future<String?> getUserEmail() async => userEmail;

  @override
  Future<String?> getParentEmail() async => userEmail;

  @override
  Future<bool> saveUserEmail(String email) async {
    userEmail = email;
    return true;
  }

  @override
  Future<bool> clearParentPinVerification() async {
    parentPinVerified = false;
    return true;
  }

  @override
  Future<bool> saveParentPinVerified(bool isVerified) async {
    parentPinVerified = isVerified;
    return true;
  }

  @override
  Future<bool> isParentPinVerified() async => parentPinVerified;

  @override
  Future<bool> isAuthenticated() async =>
      authToken != null && authToken!.isNotEmpty;
}

class _DummyBox implements Box<dynamic> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuthApi extends AuthApi {
  _TestAuthApi(SecureStorage storage)
      : super(
          NetworkService(
            secureStorage: storage,
            logger: Logger(),
          ),
        );
}

final _testRefProvider = Provider<Ref>((ref) => ref);
Ref _testRef() => ProviderContainer().read(_testRefProvider);

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required SecureStorage storage,
    this.loginChildHandler,
  }) : super(
          secureStorage: storage,
          authApi: _TestAuthApi(storage),
          logger: Logger(),
          ref: _testRef(),
        );

  Future<User?> Function({
    required String childId,
    required String childName,
    required List<String> picturePassword,
  })? loginChildHandler;

  @override
  Future<void> clearParentPinVerification() async {}

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<User?> loginChild({
    required String childId,
    required String childName,
    required List<String> picturePassword,
  }) async {
    return loginChildHandler!(
      childId: childId,
      childName: childName,
      picturePassword: picturePassword,
    );
  }
}

class _MemoryChildRepository extends ChildRepository {
  _MemoryChildRepository()
      : super(
          childBox: _DummyBox(),
          logger: Logger(),
        );

  final Map<String, ChildProfile> profiles = <String, ChildProfile>{};

  @override
  Future<List<ChildProfile>> getAllChildProfiles() async {
    return profiles.values.toList(growable: false);
  }

  @override
  Future<ChildProfile?> getChildProfile(String childId) async {
    return profiles[childId];
  }

  @override
  Future<ChildProfile?> createChildProfile(ChildProfile profile) async {
    profiles[profile.id] = profile;
    return profile;
  }

  @override
  Future<ChildProfile?> updateChildProfile(ChildProfile profile) async {
    profiles[profile.id] = profile;
    return profile;
  }
}

/// A minimal ChildProfilesViewService that delegates to a ChildRepository
/// without making any network calls. Used in tests to avoid real HTTP traffic.
class _LocalOnlyChildProfilesViewService extends ChildProfilesViewService {
  _LocalOnlyChildProfilesViewService(ChildRepository repo)
      : super(
          childRepository: repo,
          networkService: NetworkService(
            secureStorage: _NoNetworkSecureStorage(),
            logger: Logger(),
          ),
          secureStorage: _NoNetworkSecureStorage(),
          logger: Logger(),
        );
}

class _NoNetworkSecureStorage extends SecureStorage {
  @override
  bool get hasCachedAuthToken => true;
  @override
  String? get cachedAuthToken => null; // null → skip remote sync
  @override
  Future<String?> getAuthToken() async => null;
  @override
  Future<String?> getUserRole() async => null;
  @override
  Future<String?> getChildSession() async => null;
  @override
  Future<bool> isAuthenticated() async => false;
  @override
  Future<bool> isParentPinVerified() async => false;
  @override
  Future<bool> clearParentPinVerification() async => true;
}

Widget _buildApp(
  List<Override> overrides, {
  ChildRepository? childRepo,
}) {
  final router = GoRouter(
    initialLocation: '/child/login',
    routes: [
      GoRoute(
        path: '/child/login',
        builder: (context, state) => const ChildLoginScreen(),
      ),
      GoRoute(
        path: '/child/home',
        builder: (context, state) => const Scaffold(body: Text('child-home')),
      ),
      GoRoute(
        path: '/child/forgot-password',
        builder: (context, state) => const Scaffold(body: Text('forgot')),
      ),
      GoRoute(
        path: '/select-user-type',
        builder: (context, state) => const Scaffold(body: Text('select-user')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      loggerProvider.overrideWithValue(Logger()),
      appNavigationControllerProvider.overrideWithValue(
        AppNavigationController(),
      ),
      // Override childProfilesViewService to avoid real network calls.
      // We resolve the repo from the passed overrides if possible.
      if (childRepo != null)
        childProfilesViewServiceProvider.overrideWithValue(
          _LocalOnlyChildProfilesViewService(childRepo),
        ),
      ...overrides,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.lightTheme(palette: ThemePalettes.defaultPalette),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
    ),
  );
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1.0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryChildRepository childRepository;
  late _TestSecureStorage storage;

  setUp(() async {
    childRepository = _MemoryChildRepository();
    storage = _TestSecureStorage();
  });

  testWidgets('shows loading indicator while child login is pending',
      (tester) async {
    _setLargeViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final completer = Completer<User?>();
    final authRepository = _FakeAuthRepository(
      storage: storage,
      loginChildHandler: ({
        required childId,
        required childName,
        required picturePassword,
      }) {
        return completer.future;
      },
    );

    await tester.pumpWidget(
      _buildApp(
        [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(authRepository),
          childRepositoryProvider.overrideWithValue(childRepository),
        ],
        childRepo: childRepository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final l10n =
        AppLocalizations.of(tester.element(find.byType(ChildLoginScreen)))!;
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mira');
    await tester.enterText(fields.at(1), 'child-7');
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.tap(find.byIcon(Icons.pets).first);
    await tester.tap(find.byIcon(Icons.emoji_nature).first);
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, l10n.login));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(
      User(
        id: 'child-7',
        email: 'child-7@child.local',
        role: UserRoles.child,
        name: 'Mira',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('shows mapped error when child login fails with 401',
      (tester) async {
    _setLargeViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final authRepository = _FakeAuthRepository(
      storage: storage,
      loginChildHandler: ({
        required childId,
        required childName,
        required picturePassword,
      }) async {
        throw const ChildLoginException(statusCode: 401);
      },
    );

    await tester.pumpWidget(
      _buildApp(
        [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(authRepository),
          childRepositoryProvider.overrideWithValue(childRepository),
        ],
        childRepo: childRepository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final l10n =
        AppLocalizations.of(tester.element(find.byType(ChildLoginScreen)))!;
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mira');
    await tester.enterText(fields.at(1), 'child-7');
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.tap(find.byIcon(Icons.pets).first);
    await tester.tap(find.byIcon(Icons.emoji_nature).first);
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, l10n.login));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(l10n.childLoginIncorrectPictures), findsAtLeastNWidgets(1));
    expect(find.text('child-home'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('successful child login starts session and navigates home',
      (tester) async {
    _setLargeViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final authRepository = _FakeAuthRepository(
      storage: storage,
      loginChildHandler: ({
        required childId,
        required childName,
        required picturePassword,
      }) async {
        return User(
          id: childId,
          email: '$childId@child.local',
          role: UserRoles.child,
          name: 'Ayla',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );
      },
    );

    await tester.pumpWidget(
      _buildApp(
        [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(authRepository),
          childRepositoryProvider.overrideWithValue(childRepository),
        ],
        childRepo: childRepository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final l10n =
        AppLocalizations.of(tester.element(find.byType(ChildLoginScreen)))!;
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ayla');
    await tester.enterText(fields.at(1), 'child-9');
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.tap(find.byIcon(Icons.pets).first);
    await tester.tap(find.byIcon(Icons.emoji_nature).first);
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, l10n.login));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('child-home'), findsOneWidget);
    expect(storage.childSession, 'child-9');
    final savedProfile = await childRepository.getChildProfile('child-9');
    expect(savedProfile, isNotNull);
    expect(savedProfile!.name, 'Ayla');
    expect(savedProfile.picturePassword, ['apple', 'cat', 'dog']);
  });
}
