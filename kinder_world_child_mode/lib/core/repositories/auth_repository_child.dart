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

      // Backfill the child's local-first progress from the server. Child mode
      // keeps xp/level/streak/activities in local storage only; on a fresh
      // device (or after the browser drops its storage / a logout-login cycle)
      // it would otherwise reset to zero with no way to recover, even though
      // the parent dashboard still shows the real totals. The backend now
      // returns the same all-time aggregate, and we merge it into the local
      // profile taking the max so a fresher local value is never regressed.
      await _backfillChildProgress(
        childId: resolvedChildId,
        childName: _extractChildName(data) ?? childName.trim(),
        data: data,
      );

      // Restore the child's completion history so the daily goal AND the "done"
      // badges on every lesson/game/story survive a logout/login cycle (and
      // fresh devices / web storage resets). The profile backfill above only
      // restores the all-time aggregate; the per-activity records that drive
      // `getTodayProgress` (daily goal) and `completedActivityIds` (badges) live
      // in a local-only Hive box, so without this they would read empty.
      await _restoreRecentActivity(childId: resolvedChildId, data: data);

      // Restore the server-backed snapshot of the child's full local-first state
      // (coins, badges, achievements, reward-store purchases, avatar, favorites,
      // mood history, coloring progress). These live in local-only storage, so
      // without this they reset on a fresh device / web storage reset even though
      // the child earned/made them. Last-write-wins keeps a fresher local state
      // from being clobbered.
      try {
        await _ref
            .read(clientStateSyncServiceProvider)
            .restore(resolvedChildId, data['gamification_state']);
      } catch (e) {
        _logger.w('Client state restore failed: $e');
      }

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

  /// Merges the server's all-time progress aggregate into the local child
  /// profile after login. Never regresses a fresher local value (takes the max
  /// of each counter), and seeds a minimal profile when none exists yet so a
  /// fresh device recovers the child's xp/level/streak/activities/time.
  Future<void> _backfillChildProgress({
    required String childId,
    required String childName,
    required Map<String, dynamic> data,
  }) async {
    final rawProgress = data['progress'];
    if (rawProgress is! Map) return;

    int readInt(String key) {
      final value = rawProgress[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final xp = readInt('xp');
    final level = readInt('level');
    final streak = readInt('streak');
    final activities = readInt('activities_completed');
    final timeSpent = readInt('total_time_spent');

    // Nothing meaningful to backfill (brand-new child with no analytics yet).
    if (xp <= 0 && level <= 1 && streak <= 0 && activities <= 0 &&
        timeSpent <= 0) {
      return;
    }

    int higher(int local, int server) => server > local ? server : local;

    try {
      final childRepo = _ref.read(childRepositoryProvider);
      final existing = await childRepo.getChildProfile(childId);
      final now = DateTime.now();

      if (existing != null) {
        final merged = existing.copyWith(
          xp: higher(existing.xp, xp),
          level: higher(existing.level, level),
          streak: higher(existing.streak, streak),
          activitiesCompleted: higher(existing.activitiesCompleted, activities),
          totalTimeSpent: higher(existing.totalTimeSpent, timeSpent),
          updatedAt: now,
        );
        if (merged != existing) {
          await childRepo.updateChildProfile(merged);
        }
        return;
      }

      // No local profile yet (fresh device): seed one with the server progress.
      // The login screen's ensureLocalChildProfile then fills in the real
      // name/avatar/picture-password and preserves these progress counters.
      final seeded = ChildProfile(
        id: childId,
        name: childName.isNotEmpty ? childName : childId,
        age: 0,
        avatar: AppConstants.defaultChildAvatar,
        avatarPath: AppConstants.defaultChildAvatar,
        interests: const [],
        level: level > 0 ? level : 1,
        xp: xp,
        streak: streak,
        favorites: const [],
        parentId: 'local',
        picturePassword: const [],
        createdAt: now,
        updatedAt: now,
        totalTimeSpent: timeSpent,
        activitiesCompleted: activities,
      );
      await childRepo.createChildProfile(seeded);
    } catch (e) {
      _logger.w('Child progress backfill failed: $e');
    }
  }

  /// Re-seeds the local progress box with the child's completion history
  /// returned by the login endpoint, so the daily goal and the all-time "done"
  /// badges recover on a fresh device / after a storage reset. Idempotent:
  /// records reuse their original `client_record_id` (falling back to a
  /// deterministic `srv-<eventId>`), so re-logins never duplicate a completion
  /// and a fresher local record is never overwritten.
  Future<void> _restoreRecentActivity({
    required String childId,
    required Map<String, dynamic> data,
  }) async {
    final rawRecords = data['recent_activity'];
    if (rawRecords is! List || rawRecords.isEmpty) return;

    try {
      final progressRepo = _ref.read(progressRepositoryProvider);
      var restored = 0;
      for (final raw in rawRecords) {
        if (raw is! Map) continue;
        final eventId = raw['event_id']?.toString();
        final occurredRaw = raw['occurred_at']?.toString();
        if (eventId == null || occurredRaw == null) continue;
        final occurred = DateTime.tryParse(occurredRaw)?.toLocal();
        if (occurred == null) continue;

        // Re-seed under the ORIGINAL local record id when the backend has it, so
        // restoring on a device that still holds the local record is a no-op
        // (idempotent) and never inflates the daily goal. Fresh devices fall
        // back to a deterministic server id.
        final clientRecordId = raw['client_record_id']?.toString();
        final recordId = (clientRecordId != null && clientRecordId.isNotEmpty)
            ? clientRecordId
            : 'srv-$eventId';
        final activityId =
            raw['activity_id']?.toString() ?? 'event_$eventId';
        // The human-readable title the child saw when completing this activity.
        // Stored as `notes` so the history feed shows the real name instead of a
        // raw (often numeric CMS) activity id when the activity can't be resolved
        // from the local content catalog.
        final activityName = raw['activity_name']?.toString().trim();
        final points = raw['points'] is num
            ? (raw['points'] as num).toInt()
            : int.tryParse('${raw['points']}') ?? 0;
        final durationSeconds = raw['duration_seconds'] is num
            ? (raw['duration_seconds'] as num).toInt()
            : int.tryParse('${raw['duration_seconds']}') ?? 0;

        final record = ProgressRecord(
          id: recordId,
          childId: childId,
          activityId: activityId,
          date: occurred,
          score: 100,
          duration: (durationSeconds / 60).round(),
          xpEarned: points,
          notes: (activityName != null && activityName.isNotEmpty)
              ? activityName
              : null,
          completionStatus: CompletionStatus.completed,
          syncStatus: SyncStatus.synced,
          createdAt: occurred,
          updatedAt: occurred,
        );
        if (await progressRepo.restoreRecord(record)) {
          restored++;
        }
      }
      if (restored > 0) {
        _logger.d('Restored $restored recent activity records on login');
      }
    } catch (e) {
      _logger.w('Recent activity restore failed: $e');
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
