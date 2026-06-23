// Tests for AuthController StateNotifier.
//
// Covers:
//  - loginParent success / failure / two-factor challenge
//  - loginChild success / failure
//  - registerParent pending-verification flow
//  - verifyParentEmailOtp success / failure
//  - logout resets state
//  - clearError clears error without touching other fields
//  - refreshUser updates user from repository
//  - derived helpers: isParent, isChild

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/api/auth_api.dart';
import 'package:kinder_world/core/messages/app_messages.dart';
import 'package:kinder_world/core/models/user.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

// ---------------------------------------------------------------------------
// Fake storage
// ---------------------------------------------------------------------------

class _FakeStorage extends SecureStorage {
  String? authToken;
  String? refreshToken;
  String? userRole;
  String? userId;
  String? userEmail;
  String? childSession;
  bool parentPinVerified = false;

  @override
  bool get hasCachedSessionSnapshot => false;

  @override
  Future<bool> clearAuthOnly() async {
    authToken = null;
    refreshToken = null;
    userRole = null;
    userId = null;
    userEmail = null;
    childSession = null;
    parentPinVerified = false;
    return true;
  }

  @override
  Future<bool> clearParentPinVerification() async {
    parentPinVerified = false;
    return true;
  }

  @override
  Future<String?> getAuthToken() async => authToken;

  @override
  Future<bool> saveAuthToken(String token) async {
    authToken = token;
    return true;
  }

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<bool> saveRefreshToken(String token) async {
    refreshToken = token;
    return true;
  }

  @override
  Future<bool> deleteRefreshToken() async {
    refreshToken = null;
    return true;
  }

  @override
  Future<String?> getUserId() async => userId;

  @override
  Future<bool> saveUserId(String value) async {
    userId = value;
    return true;
  }

  @override
  Future<String?> getUserEmail() async => userEmail;

  @override
  Future<bool> saveUserEmail(String value) async {
    userEmail = value;
    return true;
  }

  @override
  Future<bool> deleteUserEmail() async {
    userEmail = null;
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

// ---------------------------------------------------------------------------
// Fake auth repository
// ---------------------------------------------------------------------------

typedef _LoginParentFn = Future<User?> Function({
  required String email,
  required String password,
  String? twoFactorCode,
});

typedef _LoginChildFn = Future<User?> Function({
  required String childId,
  required String childName,
  required List<String> picturePassword,
});

typedef _RegisterParentFn = Future<PendingParentVerification?> Function({
  required String name,
  required String email,
  required String password,
  required String confirmPassword,
});

typedef _VerifyOtpFn = Future<User?> Function({
  required String email,
  required String otp,
});

final _testRefProvider = Provider<Ref>((ref) => ref);
Ref _testRef() => ProviderContainer().read(_testRefProvider);

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(SecureStorage storage)
      : super(
          secureStorage: storage,
          authApi: AuthApi(
            NetworkService(secureStorage: storage, logger: Logger()),
          ),
          logger: Logger(),
          ref: _testRef(),
        );

  _LoginParentFn? onLoginParent;
  _LoginChildFn? onLoginChild;
  _RegisterParentFn? onRegisterParent;
  _VerifyOtpFn? onVerifyOtp;

  User? _storedUser;

  @override
  Future<void> clearParentPinVerification() async {}

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<User?> getCurrentUser() async => _storedUser;

  @override
  Future<bool> logout() async {
    _storedUser = null;
    return true;
  }

  @override
  Future<User?> loginParent({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    final result = await onLoginParent!(
      email: email,
      password: password,
      twoFactorCode: twoFactorCode,
    );
    _storedUser = result;
    return result;
  }

  @override
  Future<User?> loginChild({
    required String childId,
    required String childName,
    required List<String> picturePassword,
  }) async {
    final result = await onLoginChild!(
      childId: childId,
      childName: childName,
      picturePassword: picturePassword,
    );
    _storedUser = result;
    return result;
  }

  @override
  Future<PendingParentVerification?> registerParent({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    return onRegisterParent!(
      name: name,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );
  }

  @override
  Future<User?> verifyParentEmailOtp({
    required String email,
    required String otp,
  }) async {
    final result = await onVerifyOtp!(email: email, otp: otp);
    _storedUser = result;
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

User _makeParent({String id = 'parent-1'}) => User(
      id: id,
      email: 'parent@test.com',
      role: UserRoles.parent,
      name: 'Test Parent',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      isActive: true,
    );

User _makeChild({String id = 'child-1'}) => User(
      id: id,
      email: '$id@child.local',
      role: UserRoles.child,
      name: 'Test Child',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      isActive: true,
    );

ProviderContainer _makeContainer(_FakeAuthRepository repo) {
  final container = ProviderContainer(
    overrides: [
      loggerProvider.overrideWithValue(Logger()),
      authRepositoryProvider.overrideWithValue(repo),
      appNavigationControllerProvider
          .overrideWithValue(AppNavigationController()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeStorage storage;
  late _FakeAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    storage = _FakeStorage();
    repo = _FakeAuthRepository(storage);
    container = _makeContainer(repo);
  });

  // ─── loginParent ──────────────────────────────────────────────────────────

  group('loginParent', () {
    test('success sets isAuthenticated and user', () async {
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async =>
          _makeParent();

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete

      final result = await ctrl.loginParent(
        email: 'parent@test.com',
        password: 'Password1!',
      );

      expect(result, isTrue);
      final state = container.read(authControllerProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.role, UserRoles.parent);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('null return from repository sets error and keeps unauthenticated',
        () async {
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async =>
          null;

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete

      final result = await ctrl.loginParent(
        email: 'parent@test.com',
        password: 'wrong',
      );

      expect(result, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
    });

    test('ParentAuthException with two-factor surfaces requiresTwoFactor flag',
        () async {
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async {
        throw const ParentAuthException(
          message: '2FA required',
          statusCode: 401,
          requiresTwoFactor: true,
          twoFactorMethod: 'totp',
        );
      };

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      final result = await ctrl.loginParent(
        email: 'parent@test.com',
        password: 'Password1!',
      );

      expect(result, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.requiresTwoFactor, isTrue);
      expect(state.twoFactorMethod, 'totp');
      expect(state.isAuthenticated, isFalse);
    });

    test('unexpected exception sets generic error message', () async {
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async {
        throw Exception('network error');
      };

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      final result = await ctrl.loginParent(
        email: 'parent@test.com',
        password: 'Password1!',
      );

      expect(result, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.error, AuthUiMessages.loginFailedTryAgain);
      expect(state.isLoading, isFalse);
    });

    test('isLoading is false after completing (success path)', () async {
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async =>
          _makeParent();

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      await ctrl.loginParent(email: 'p@test.com', password: 'P1!');

      expect(container.read(authControllerProvider).isLoading, isFalse);
    });

    test('ParentAuthException with email-verification flag is surfaced', () async {
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async {
        throw const ParentAuthException(
          message: 'Email verification required',
          statusCode: 403,
          requiresEmailVerification: true,
          pendingEmail: 'parent@test.com',
        );
      };

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      await ctrl.loginParent(email: 'parent@test.com', password: 'P1!');

      final state = container.read(authControllerProvider);
      expect(state.requiresEmailVerification, isTrue);
      expect(state.pendingVerificationEmail, 'parent@test.com');
    });
  });

  // ─── loginChild ───────────────────────────────────────────────────────────

  group('loginChild', () {
    test('success sets isAuthenticated and child user', () async {
      repo.onLoginChild = ({required childId, required childName, required picturePassword}) async =>
          _makeChild();

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      final result = await ctrl.loginChild(
        childId: 'child-1',
        childName: 'Mira',
        picturePassword: ['a', 'b', 'c'],
      );

      expect(result, isTrue);
      final state = container.read(authControllerProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.role, UserRoles.child);
    });

    test('ChildLoginException 401 sets mapped error', () async {
      repo.onLoginChild = ({required childId, required childName, required picturePassword}) async {
        throw const ChildLoginException(statusCode: 401);
      };

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      final result = await ctrl.loginChild(
        childId: 'child-1',
        childName: 'Mira',
        picturePassword: ['a', 'b', 'c'],
      );

      expect(result, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.error, isNotNull);
      expect(state.isAuthenticated, isFalse);
    });

    test('ChildLoginException 404 sets mapped error', () async {
      repo.onLoginChild = ({required childId, required childName, required picturePassword}) async {
        throw const ChildLoginException(statusCode: 404);
      };

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      final result = await ctrl.loginChild(
        childId: 'child-x',
        childName: 'Nobody',
        picturePassword: ['a', 'b', 'c'],
      );

      expect(result, isFalse);
      expect(container.read(authControllerProvider).error, isNotNull);
    });

    test('unexpected exception sets generic child login error', () async {
      repo.onLoginChild = ({required childId, required childName, required picturePassword}) async {
        throw Exception('timeout');
      };

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      await ctrl.loginChild(
          childId: 'c1', childName: 'X', picturePassword: ['a', 'b', 'c']);

      expect(container.read(authControllerProvider).error,
          AuthUiMessages.childLoginFailed);
    });
  });

  // ─── registerParent ───────────────────────────────────────────────────────

  group('registerParent', () {
    test('returns pending verification and sets requiresEmailVerification',
        () async {
      repo.onRegisterParent =
          ({required name, required email, required password, required confirmPassword}) async =>
              PendingParentVerification(
                email: email,
                message: 'Check your inbox',
                otpExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
              );

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      final pending = await ctrl.registerParent(
        name: 'Alice',
        email: 'alice@test.com',
        password: 'Secure1!',
        confirmPassword: 'Secure1!',
      );

      expect(pending, isNotNull);
      final state = container.read(authControllerProvider);
      expect(state.requiresEmailVerification, isTrue);
      expect(state.pendingVerificationEmail, 'alice@test.com');
      expect(state.isLoading, isFalse);
    });

    test('null return sets registration failure error', () async {
      repo.onRegisterParent =
          ({required name, required email, required password, required confirmPassword}) async =>
              null;

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      final pending = await ctrl.registerParent(
        name: 'Bob',
        email: 'bob@test.com',
        password: 'Pass1!',
        confirmPassword: 'Pass1!',
      );

      expect(pending, isNull);
      expect(container.read(authControllerProvider).error, isNotNull);
    });
  });

  // ─── verifyParentEmailOtp ────────────────────────────────────────────────

  group('verifyParentEmailOtp', () {
    test('success sets isAuthenticated', () async {
      repo.onVerifyOtp = ({required email, required otp}) async => _makeParent();

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      final result = await ctrl.verifyParentEmailOtp(
        email: 'parent@test.com',
        otp: '123456',
      );

      expect(result, isTrue);
      final state = container.read(authControllerProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.requiresEmailVerification, isFalse);
    });

    test('null return sets invalid OTP error', () async {
      repo.onVerifyOtp = ({required email, required otp}) async => null;

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      final result = await ctrl.verifyParentEmailOtp(
        email: 'parent@test.com',
        otp: 'wrong',
      );

      expect(result, isFalse);
      expect(container.read(authControllerProvider).error, isNotNull);
    });
  });

  // ─── logout ───────────────────────────────────────────────────────────────

  group('logout', () {
    test('resets state to unauthenticated', () async {
      // Pre-seed an authenticated state
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async =>
          _makeParent();
      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      await ctrl.loginParent(email: 'p@test.com', password: 'P1!');
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);

      await ctrl.logout();

      final state = container.read(authControllerProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });
  });

  // ─── clearError ───────────────────────────────────────────────────────────

  group('clearError', () {
    test('clears error and two-factor flags without affecting user', () async {
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async {
        throw const ParentAuthException(
          message: 'bad creds',
          requiresTwoFactor: true,
          twoFactorMethod: 'totp',
        );
      };

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      await ctrl.loginParent(email: 'p@test.com', password: 'wrong');

      expect(container.read(authControllerProvider).error, isNotNull);

      ctrl.clearError();

      final state = container.read(authControllerProvider);
      expect(state.error, isNull);
      expect(state.requiresTwoFactor, isFalse);
      expect(state.twoFactorMethod, isNull);
      expect(state.requiresEmailVerification, isFalse);
    });
  });

  // ─── refreshUser ─────────────────────────────────────────────────────────

  group('refreshUser', () {
    test('updates user from repository', () async {
      repo._storedUser = _makeParent(id: 'refreshed-parent');

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      await ctrl.refreshUser();

      expect(container.read(authControllerProvider).user?.id, 'refreshed-parent');
    });

    test('sets isAuthenticated false when user is null', () async {
      repo._storedUser = null;

      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      await ctrl.refreshUser();

      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    });
  });

  // ─── derived state helpers ────────────────────────────────────────────────

  group('derived state', () {
    test('isParent is true when authenticated user role is parent', () async {
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async =>
          _makeParent();
      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      await ctrl.loginParent(email: 'p@test.com', password: 'P1!');

      expect(container.read(authControllerProvider).isParent, isTrue);
      expect(container.read(authControllerProvider).isChild, isFalse);
    });

    test('isChild is true when authenticated user role is child', () async {
      repo.onLoginChild = ({required childId, required childName, required picturePassword}) async =>
          _makeChild();
      final ctrl = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      await ctrl.loginChild(
          childId: 'c1', childName: 'Kid', picturePassword: ['a', 'b', 'c']);

      expect(container.read(authControllerProvider).isChild, isTrue);
      expect(container.read(authControllerProvider).isParent, isFalse);
    });
  });

  // ─── helper providers ────────────────────────────────────────────────────

  group('helper providers', () {
    test('isAuthenticatedProvider reflects auth state', () async {
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async =>
          _makeParent();
      container.read(authControllerProvider.notifier); // trigger initialization
      await Future<void>.delayed(Duration.zero); // let _initialize complete

      expect(container.read(isAuthenticatedProvider), isFalse);

      await container.read(authControllerProvider.notifier).loginParent(
            email: 'p@test.com',
            password: 'P1!',
          );

      expect(container.read(isAuthenticatedProvider), isTrue);
    });

    test('currentUserProvider returns null before login', () async {
      container.read(authControllerProvider.notifier); // trigger initialization
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      expect(container.read(currentUserProvider), isNull);
    });

    test('currentUserProvider returns user after login', () async {
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async =>
          _makeParent(id: 'p-99');
      final ctrl2 = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      await ctrl2.loginParent(email: 'p@test.com', password: 'P!');
      expect(container.read(currentUserProvider)?.id, 'p-99');
    });

    test('isParentProvider and isChildProvider are exclusive', () async {
      repo.onLoginParent = ({required email, required password, twoFactorCode}) async =>
          _makeParent();
      final ctrl3 = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete
      await ctrl3.loginParent(email: 'p@test.com', password: 'P!');
      expect(container.read(isParentProvider), isTrue);
      expect(container.read(isChildProvider), isFalse);
    });

    test('authLoadingProvider reflects loading state during async operation',
        () async {
      final completer = Future<User?>.delayed(
        const Duration(milliseconds: 100),
        () => _makeParent(),
      );
      repo.onLoginParent =
          ({required email, required password, twoFactorCode}) => completer;
      final ctrlLoad = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _initialize complete

      final fut = ctrlLoad.loginParent(
            email: 'p@test.com',
            password: 'P!',
          );

      // Right after call starts, isLoading should be true
      expect(container.read(authLoadingProvider), isTrue);
      await fut;
      expect(container.read(authLoadingProvider), isFalse);
    });
  });
}
