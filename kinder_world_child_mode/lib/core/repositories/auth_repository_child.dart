part of 'auth_repository.dart';

mixin _AuthRepositoryChildMixin on _AuthRepositorySupportMixin {
  /// Login child via picture password
  Future<User?> loginChild({
    required String childId,
    required String childName,
    required List<String> picturePassword,
  }) async {
    try {
      _logger.d('Attempting child login for: $childId');

      if (childId.trim().isEmpty ||
          childName.trim().isEmpty ||
          picturePassword.length != 3) {
        _logger.w('Child login failed: Missing or invalid credentials');
        throw const ChildLoginException(statusCode: 422);
      }

      final payload = await _authApi.childLogin(
        childId: childId,
        name: childName,
        picturePassword: picturePassword,
      );
      if (!payload.success) {
        _logger.w('Child login failed: Invalid credentials');
        throw const ChildLoginException(statusCode: 401);
      }

      final data = payload.raw;
      final resolvedChildId = payload.childId?.trim().isNotEmpty == true
          ? payload.childId!
          : childId;
      final sessionToken = payload.sessionToken?.trim();
      if (sessionToken == null || sessionToken.isEmpty) {
        _logger.e('Child login failed: missing session token');
        throw const ChildLoginException();
      }

      await _persistChildSessionState(
        sessionToken: sessionToken,
        childId: resolvedChildId,
      );

      final childUser = _buildChildUser(
        childId: resolvedChildId,
        childName: _extractChildName(data),
      );
      _logger.d('Child login successful: ${childUser.id}');
      return childUser;
    } on DioException catch (e) {
      _logger.e(
        'Child login error: ${e.response?.statusCode} - ${e.response?.data}',
      );
      throw ChildLoginException(
        statusCode: e.response?.statusCode,
        detailCode: _extractErrorDetailCode(e),
      );
    } catch (e) {
      _logger.e('Child login error: $e');
      throw const ChildLoginException();
    }
  }

  /// Register child via picture password
  Future<ChildRegisterResponse?> registerChild({
    required String name,
    required List<String> picturePassword,
    required String parentEmail,
    required int age,
    String? avatar,
  }) async {
    try {
      final trimmedName = name.trim();
      final trimmedEmail = parentEmail.trim().toLowerCase();
      final parentAccessToken = await _resolveParentRegistrationToken();

      if (trimmedName.isEmpty ||
          trimmedEmail.isEmpty ||
          picturePassword.length != 3 ||
          age < 5 ||
          age > 12) {
        _logger.w('Child register failed: Missing or invalid data');
        throw const ChildRegisterException(statusCode: 422);
      }
      if (parentAccessToken == null) {
        _logger.w('Child register blocked: parent authentication is required');
        throw const ChildRegisterException(
          statusCode: 401,
          message: AuthUiMessages.parentAuthenticationRequired,
        );
      }

      final data = await _authApi.childRegister(
        name: trimmedName,
        picturePassword: picturePassword,
        parentAccessToken: parentAccessToken,
        parentEmail: trimmedEmail,
        age: age,
        avatar: avatar,
      );
      if (data.isEmpty) {
        _logger.e('Child register failed: empty response');
        return null;
      }

      final response = _parseChildRegisterResponse(data);
      if (response == null) {
        _logger.e('Child register failed: missing child id');
      }
      return response;
    } on DioException catch (e) {
      throw _childRegisterExceptionFromDio(e);
    } on ChildRegisterException {
      rethrow;
    } catch (e) {
      _logger.e('Child register error: $e');
      throw const ChildRegisterException();
    }
  }
}
