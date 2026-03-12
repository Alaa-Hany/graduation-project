// ignore_for_file: prefer_const_constructors
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/picture_password_row.dart';
import 'package:kinder_world/features/child_mode/paywall/child_paywall_screen.dart';
import 'package:kinder_world/router.dart';

class _AvatarOption {
  final String id;
  final String assetPath;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const _AvatarOption({
    required this.id,
    required this.assetPath,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });
}

class ChildLoginScreen extends ConsumerStatefulWidget {
  const ChildLoginScreen({super.key});

  @override
  ConsumerState<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends ConsumerState<ChildLoginScreen> {
  final TextEditingController _childNameController = TextEditingController();
  final TextEditingController _childIdController = TextEditingController();
  late Future<List<ChildProfile>> _childrenFuture;
  int _childrenRequestId = 0;

  final List<String> _selectedPictures = [];
  String? _selectedChildId;
  ChildProfile? _selectedChildProfile;
  bool _isLoading = false;
  String? _error;
  OverlayEntry? _topMessageEntry;

  final List<_AvatarOption> _avatarOptions = const [
    _AvatarOption(
      id: 'assets/images/avatars/boy1.png',
      assetPath: 'assets/images/avatars/boy1.png',
      icon: Icons.face,
      backgroundColor: Color(0xFFE3F2FD),
      iconColor: Color(0xFF1E88E5),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/boy2.png',
      assetPath: 'assets/images/avatars/boy2.png',
      icon: Icons.sentiment_satisfied_alt,
      backgroundColor: Color(0xFFFFF3E0),
      iconColor: Color(0xFFFB8C00),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/boy3.png',
      assetPath: 'assets/images/avatars/boy3.png',
      icon: Icons.face,
      backgroundColor: Color(0xFFE1F5FE),
      iconColor: Color(0xFF0277BD),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/boy4.png',
      assetPath: 'assets/images/avatars/boy4.png',
      icon: Icons.child_care,
      backgroundColor: Color(0xFFFFE0B2),
      iconColor: Color(0xFFF57C00),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/girl1.png',
      assetPath: 'assets/images/avatars/girl1.png',
      icon: Icons.emoji_emotions,
      backgroundColor: Color(0xFFF3E5F5),
      iconColor: Color(0xFF8E24AA),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/girl2.png',
      assetPath: 'assets/images/avatars/girl2.png',
      icon: Icons.mood,
      backgroundColor: Color(0xFFE8F5E9),
      iconColor: Color(0xFF43A047),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/girl3.png',
      assetPath: 'assets/images/avatars/girl3.png',
      icon: Icons.face_retouching_natural,
      backgroundColor: Color(0xFFFCE4EC),
      iconColor: Color(0xFFC2185B),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/girl4.png',
      assetPath: 'assets/images/avatars/girl4.png',
      icon: Icons.girl,
      backgroundColor: Color(0xFFF8BBD0),
      iconColor: Color(0xFFE91E63),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/av1.png',
      assetPath: 'assets/images/avatars/av1.png',
      icon: Icons.face_2_rounded,
      backgroundColor: Color(0xFFEDE7F6),
      iconColor: Color(0xFF7E57C2),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/av2.png',
      assetPath: 'assets/images/avatars/av2.png',
      icon: Icons.tag_faces_rounded,
      backgroundColor: Color(0xFFE8F5E9),
      iconColor: Color(0xFF2E7D32),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/av3.png',
      assetPath: 'assets/images/avatars/av3.png',
      icon: Icons.cruelty_free_rounded,
      backgroundColor: Color(0xFFFFF3E0),
      iconColor: Color(0xFFEF6C00),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/av4.png',
      assetPath: 'assets/images/avatars/av4.png',
      icon: Icons.auto_awesome_rounded,
      backgroundColor: Color(0xFFE1F5FE),
      iconColor: Color(0xFF0277BD),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/av5.png',
      assetPath: 'assets/images/avatars/av5.png',
      icon: Icons.pets_rounded,
      backgroundColor: Color(0xFFFCE4EC),
      iconColor: Color(0xFFAD1457),
    ),
    _AvatarOption(
      id: 'assets/images/avatars/av6.png',
      assetPath: 'assets/images/avatars/av6.png',
      icon: Icons.emoji_emotions_rounded,
      backgroundColor: Color(0xFFFFF8E1),
      iconColor: Color(0xFFF9A825),
    ),
  ];

  final List<PicturePasswordOption> _pictureOptions = picturePasswordOptions;

  OutlineInputBorder _loginBorder(ColorScheme colors) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outlineVariant),
      );

  InputDecoration _buildLoginDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: colors.onSurfaceVariant),
      suffixIcon: suffix,
      filled: true,
      fillColor: colors.surfaceContainerHighest,
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      enabledBorder: _loginBorder(colors),
      focusedBorder: _loginBorder(colors).copyWith(
        borderSide: BorderSide(color: colors.primary, width: 1.6),
      ),
      errorBorder: _loginBorder(colors).copyWith(
        borderSide: BorderSide(color: colors.error, width: 1.6),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _childrenFuture = _loadChildren();
  }

  @override
  void dispose() {
    _topMessageEntry?.remove();
    _topMessageEntry = null;
    _childNameController.dispose();
    _childIdController.dispose();
    super.dispose();
  }

  Future<List<ChildProfile>> _loadChildren() async {
    final repo = ref.read(childRepositoryProvider);
    final secureStorage = ref.read(secureStorageProvider);
    final requestId = ++_childrenRequestId;
    final localChildren = await repo.getAllChildProfiles();
    final childrenById = {
      for (final child in localChildren) child.id: child,
    };

    final token = secureStorage.hasCachedAuthToken
        ? secureStorage.cachedAuthToken
        : await secureStorage.getAuthToken();
    if (token == null || token.startsWith('child_session_')) {
      return childrenById.values.toList();
    }

    final parentId = secureStorage.hasCachedUserId
        ? secureStorage.cachedUserId
        : await secureStorage.getParentId();
    final parentEmail = secureStorage.hasCachedUserEmail
        ? secureStorage.cachedUserEmail
        : await secureStorage.getParentEmail();
    unawaited(
      _syncChildrenFromParentSession(
        requestId: requestId,
        initialChildren: childrenById,
        parentId: parentId ?? 'local',
        parentEmail: parentEmail,
      ),
    );

    return childrenById.values.toList();
  }

  Future<void> _syncChildrenFromParentSession({
    required int requestId,
    required Map<String, ChildProfile> initialChildren,
    required String parentId,
    required String? parentEmail,
  }) async {
    final repo = ref.read(childRepositoryProvider);
    final childrenById = Map<String, ChildProfile>.from(initialChildren);

    try {
      final response = await ref.read(networkServiceProvider).get<dynamic>(
            '/children',
          );
      final apiChildren = _extractChildrenList(response.data);
      final writeOperations = <Future<Object?>>[];
      for (final childData in apiChildren) {
        final childId = _parseChildId(childData);
        if (childId == null || childId.isEmpty) continue;
        final existing = childrenById[childId];
        final merged = _mergeChildProfileFromApi(
          childData,
          existing: existing,
          parentId: parentId,
          parentEmail: parentEmail,
        );
        if (merged == null) continue;
        childrenById[childId] = merged;
        writeOperations.add(
          existing == null
              ? repo.createChildProfile(merged)
              : repo.updateChildProfile(merged),
        );
      }
      if (writeOperations.isNotEmpty) {
        await Future.wait(writeOperations);
      }
      if (!mounted || requestId != _childrenRequestId) return;
      setState(() {
        _childrenFuture = Future<List<ChildProfile>>.value(
          childrenById.values.toList(growable: false),
        );
      });
    } catch (_) {
      // Keep the locally cached list when background sync fails.
    }
  }

  void _refreshChildren() {
    setState(() {
      _childrenFuture = _loadChildren();
    });
  }

  void _showTopMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    _topMessageEntry?.remove();
    final textDirection = Directionality.of(context);
    _topMessageEntry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: MediaQuery.of(overlayContext).padding.top + 12,
          left: 16,
          right: 16,
          child: Directionality(
            textDirection: textDirection,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isError ? Theme.of(context).colorScheme.error : context.successColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .shadow
                          .withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.surface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = _topMessageEntry!;
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (_topMessageEntry == entry) {
        entry.remove();
        _topMessageEntry = null;
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _error = message;
    });
    _showTopMessage(message);
  }

  void _resetSelection() {
    setState(() {
      _selectedChildId = null;
      _selectedChildProfile = null;
      _selectedPictures.clear();
      _error = null;
    });
  }

  void _selectChild(ChildProfile child) {
    setState(() {
      _selectedChildId = child.id;
      _selectedChildProfile = child;
      _selectedPictures.clear();
      _error = null;
    });
  }

  void _queueSelectChild(ChildProfile child) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedChildId != null) return;
      _selectChild(child);
    });
  }

  void _togglePicture(String pictureId) {
    if (_isLoading) return;
    setState(() {
      if (_selectedPictures.contains(pictureId)) {
        _selectedPictures.remove(pictureId);
      } else if (_selectedPictures.length < 3) {
        _selectedPictures.add(pictureId);
      }
    });
  }

  _AvatarOption? _avatarForValue(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final option in _avatarOptions) {
      if (option.id == value || option.assetPath == value) {
        return option;
      }
    }
    return null;
  }

  ChildProfile? _resolveSelectedChild(List<ChildProfile> children) {
    if (_selectedChildId == null) return null;
    if (_selectedChildProfile != null &&
        _selectedChildProfile!.id == _selectedChildId) {
      return _selectedChildProfile;
    }
    for (final child in children) {
      if (child.id == _selectedChildId) {
        return child;
      }
    }
    return null;
  }

  String _mapChildLoginError(AppLocalizations l10n, String? error) {
    switch (error) {
      case 'child_login_404':
        return l10n.childLoginNotFound;
      case 'child_login_401':
        return l10n.childLoginIncorrectPictures;
      case 'child_login_422':
        return l10n.childLoginMissingData;
      default:
        return l10n.loginError;
    }
  }

  String _mapChildRegisterError(AppLocalizations l10n, String? error) {
    switch (error) {
      case 'child_register_404':
        return l10n.childRegisterParentNotFound;
      case 'child_register_401':
        return l10n.childRegisterForbidden;
      case 'child_register_422':
        return l10n.childLoginMissingData;
      case 'child_register_limit':
        return l10n.childRegisterLimitReached;
      default:
        return l10n.registerError;
    }
  }

  Future<bool> _openPaywall() async {
    if (!mounted) return false;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const ChildPaywallScreen(),
      ),
    );
    return result == true;
  }

  bool _samePictures(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<Map<String, dynamic>> _extractChildrenList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map) {
      final listData =
          data['children'] ?? data['data'] ?? data['results'] ?? data['items'];
      if (listData is List) {
        return listData
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return [];
  }

  String? _parseChildId(Map<String, dynamic> data) {
    final raw = data['id'] ?? data['child_id'] ?? data['childId'];
    return raw?.toString();
  }

  int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTime _parseDate(dynamic value, DateTime fallback) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return fallback;
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  List<String>? _parseNullableStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return null;
  }

  DateTime? _parseBirthDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  int _ageFromBirthDate(DateTime? birthDate) {
    if (birthDate == null) return 0;
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hasHadBirthday = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasHadBirthday) age -= 1;
    return age.clamp(0, 120);
  }

  int _resolveAgeFromApi(Map<String, dynamic> data, ChildProfile? existing) {
    // Prioritize existing age if it's valid
    final existingAge = existing?.age ?? 0;
    if (existingAge > 0) return existingAge;

    final apiAge = _parseInt(data['age'], 0);
    final birthDate = _parseBirthDate(
      data['birthdate'] ??
          data['birth_date'] ??
          data['date_of_birth'] ??
          data['dob'],
    );
    final computedAge = _ageFromBirthDate(birthDate);

    if (kDebugMode) {
      debugPrint(
        'Child age resolve: apiAge=$apiAge, birthDate=$birthDate, computedAge=$computedAge, existing=$existingAge',
      );
    }

    if (apiAge > 0) return apiAge;
    if (computedAge > 0) return computedAge;
    return 0;
  }

  ChildProfile? _mergeChildProfileFromApi(
    Map<String, dynamic> data, {
    ChildProfile? existing,
    String? parentId,
    String? parentEmail,
  }) {
    final childId = _parseChildId(data);
    if (childId == null || childId.isEmpty) return null;

    final now = DateTime.now();
    final apiName = data['name']?.toString().trim();
    final existingName = existing?.name;
    // Don't use existing name if it's the same as the ID (default placeholder)
    final hasRealName = existingName != null &&
        existingName.isNotEmpty &&
        existingName != childId &&
        existingName.toLowerCase() != 'child';
    final resolvedName = (apiName != null &&
            apiName.isNotEmpty &&
            apiName != childId &&
            apiName.toLowerCase() != 'child')
        ? apiName
        : (hasRealName ? existingName : childId);
    final age = _resolveAgeFromApi(data, existing);
    final existingLevel = existing?.level ?? 0;
    final level =
        existingLevel > 0 ? existingLevel : _parseInt(data['level'], 1);
    final avatar = existing?.avatar ??
        data['avatar']?.toString() ??
        _avatarOptions.first.id;
    final resolvedAvatarPath = existing?.avatarPath.isNotEmpty == true
        ? existing!.avatarPath
        : (avatar.isNotEmpty ? avatar : AppConstants.defaultChildAvatar);
    final picturePassword = (existing?.picturePassword.isNotEmpty ?? false)
        ? existing!.picturePassword
        : _parseStringList(data['picture_password']);
    final createdAt =
        existing?.createdAt ?? _parseDate(data['created_at'], now);
    final updatedAt = _parseDate(data['updated_at'], now);
    final lastSession =
        existing?.lastSession ?? _parseNullableDate(data['last_session']);

    return ChildProfile(
      id: childId,
      name: resolvedName,
      age: age,
      avatar: avatar,
      avatarPath: resolvedAvatarPath,
      interests: existing?.interests ?? _parseStringList(data['interests']),
      level: level,
      xp: existing?.xp ?? _parseInt(data['xp'], 0),
      streak: existing?.streak ?? _parseInt(data['streak'], 0),
      favorites: existing?.favorites ?? _parseStringList(data['favorites']),
      parentId: parentId ?? existing?.parentId ?? 'local',
      parentEmail: existing?.parentEmail ??
          parentEmail ??
          data['parent_email']?.toString(),
      picturePassword: picturePassword,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastSession: lastSession,
      totalTimeSpent:
          existing?.totalTimeSpent ?? _parseInt(data['total_time_spent'], 0),
      activitiesCompleted: existing?.activitiesCompleted ??
          _parseInt(data['activities_completed'], 0),
      currentMood: existing?.currentMood ?? data['current_mood']?.toString(),
      learningStyle:
          existing?.learningStyle ?? data['learning_style']?.toString(),
      specialNeeds: existing?.specialNeeds ??
          _parseNullableStringList(data['special_needs']),
      accessibilityNeeds: existing?.accessibilityNeeds ??
          _parseNullableStringList(data['accessibility_needs']),
    );
  }

  List<ChildProfile> _dedupeChildren(List<ChildProfile> children) {
    final seen = <String, ChildProfile>{};
    for (final child in children) {
      if (!seen.containsKey(child.id)) {
        seen[child.id] = child;
      }
    }
    return seen.values.toList();
  }

  Future<ChildProfile?> _ensureLocalChildProfile(
    String childId,
    ChildProfile? childProfile, {
    String? fallbackName,
  }) async {
    final repo = ref.read(childRepositoryProvider);
    final existing = childProfile ?? await repo.getChildProfile(childId);
    final selectedPassword = _selectedPictures.length == 3
        ? List<String>.from(_selectedPictures)
        : const <String>[];
    final resolvedFallback =
        (fallbackName != null && fallbackName.trim().isNotEmpty)
            ? fallbackName.trim()
            : null;
    final isDefaultName = resolvedFallback != null &&
        (resolvedFallback == childId || resolvedFallback == 'Child $childId');

    if (existing != null) {
      var updatedProfile = existing;
      if ((existing.avatarPath.isEmpty) && (existing.avatar.isNotEmpty)) {
        updatedProfile = updatedProfile.copyWith(
          avatarPath: existing.avatar,
          updatedAt: DateTime.now(),
        );
      }
      if (selectedPassword.isNotEmpty &&
          !_samePictures(existing.picturePassword, selectedPassword)) {
        updatedProfile = updatedProfile.copyWith(
          picturePassword: selectedPassword,
          updatedAt: DateTime.now(),
        );
      }
      if (resolvedFallback != null &&
          !isDefaultName &&
          existing.name != resolvedFallback) {
        updatedProfile = updatedProfile.copyWith(
          name: resolvedFallback,
          updatedAt: DateTime.now(),
        );
      }
      if (updatedProfile != existing) {
        final saved = await repo.updateChildProfile(updatedProfile);
        if (saved != null) {
          _refreshChildren();
          return saved;
        }
      }
      return updatedProfile;
    }

    final now = DateTime.now();

    // Ensure we have a valid name - use childId as fallback if needed
    String finalName;
    if (childProfile != null &&
        childProfile.name.isNotEmpty &&
        childProfile.name != childId &&
        childProfile.name.toLowerCase() != 'child') {
      finalName = childProfile.name;
    } else if (!isDefaultName &&
        resolvedFallback != null &&
        resolvedFallback.toLowerCase() != 'child') {
      finalName = resolvedFallback;
    } else {
      // Use child ID as a final fallback to allow login
      finalName = childId;
    }

    final newProfile = ChildProfile(
      id: childId,
      name: finalName,
      age: childProfile?.age ?? 0,
      avatar: childProfile?.avatar ?? _avatarOptions.first.id,
      avatarPath: childProfile?.avatarPath.isNotEmpty == true
          ? childProfile!.avatarPath
          : (childProfile?.avatar ?? _avatarOptions.first.id),
      interests: childProfile?.interests ?? const [],
      level: childProfile?.level ?? 1,
      xp: childProfile?.xp ?? 0,
      streak: childProfile?.streak ?? 0,
      favorites: childProfile?.favorites ?? const [],
      parentId: childProfile?.parentId ?? 'local',
      parentEmail: childProfile?.parentEmail,
      picturePassword: selectedPassword,
      createdAt: childProfile?.createdAt ?? now,
      updatedAt: now,
      lastSession: childProfile?.lastSession,
      totalTimeSpent: childProfile?.totalTimeSpent ?? 0,
      activitiesCompleted: childProfile?.activitiesCompleted ?? 0,
      currentMood: childProfile?.currentMood,
      learningStyle: childProfile?.learningStyle,
      specialNeeds: childProfile?.specialNeeds,
      accessibilityNeeds: childProfile?.accessibilityNeeds,
    );

    final created = await repo.createChildProfile(newProfile);
    if (created != null) {
      _refreshChildren();
    }
    return created;
  }

  Future<void> _loginWithChildId({
    required String childId,
    required String childName,
    ChildProfile? childProfile,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final trimmedId = childId.trim();
    final trimmedName = childName.trim();

    if (trimmedId.isEmpty ||
        trimmedName.isEmpty ||
        _selectedPictures.length != 3) {
      _showError(l10n.childLoginMissingData);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authController = ref.read(authControllerProvider.notifier);
      final authSuccess = await authController.loginChild(
        childId: trimmedId,
        childName: trimmedName,
        picturePassword: List<String>.from(_selectedPictures),
      );

      if (!authSuccess) {
        final authError = ref.read(authControllerProvider).error;
        _showError(_mapChildLoginError(l10n, authError));
        return;
      }

      final loggedInName = ref.read(authControllerProvider).user?.name;
      final storedProfile = await _ensureLocalChildProfile(
        trimmedId,
        childProfile,
        fallbackName: loggedInName ?? trimmedName,
      );
      if (storedProfile == null) {
        _showError(l10n.childProfileNotFound);
        return;
      }

      final sessionController =
          ref.read(childSessionControllerProvider.notifier);
      final sessionSuccess = await sessionController.startChildSession(
        childId: trimmedId,
        childProfile: storedProfile,
      );

      if (!sessionSuccess) {
        _showError(l10n.failedToStartSession);
        return;
      }

      if (mounted) {
        context.go('/child/home');
      }
    } catch (_) {
      _showError(l10n.loginError);
    }
  }

  Future<void> _showCreateProfileDialog(AppLocalizations l10n) async {
    if (!mounted) return;
    final parentContext = context;
    final storedParentEmail =
        await ref.read(secureStorageProvider).getParentEmail();
    if (!mounted) return;
    final parentEmailController =
        TextEditingController(text: storedParentEmail ?? '');
    final childNameController = TextEditingController();
    final repo = ref.read(childRepositoryProvider);
    int? age;
    String selectedAvatar = _avatarOptions.first.id;
    final selectedPassword = <String>[];
    bool nameTouched = false;
    bool emailTouched = false;
    bool passwordTouched = false;
    bool isSaving = false;

    bool isValidEmail(String value) {
      final trimmed = value.trim().toLowerCase();
      if (trimmed.isEmpty || !trimmed.contains('@')) return false;
      final domain = trimmed.split('@').last;
      return domain == 'gmail.com' ||
          domain == 'outlook.com' ||
          domain == 'hotmail.com' ||
          domain == 'live.com';
    }

    void togglePicture(
      String pictureId,
      void Function(void Function()) setDialogState,
    ) {
      if (isSaving) return;
      setDialogState(() {
        passwordTouched = true;
        if (selectedPassword.contains(pictureId)) {
          selectedPassword.remove(pictureId);
        } else if (selectedPassword.length < 3) {
          selectedPassword.add(pictureId);
        }
      });
    }

    // ignore: use_build_context_synchronously
    await showDialog<void>(
      // ignore: use_build_context_synchronously
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final childName = childNameController.text.trim();
            final parentEmail = parentEmailController.text.trim();
            final isValidName = childName.isNotEmpty &&
                childName.toLowerCase() != 'child' &&
                childName.length >= 2;
            final canSave = isValidName &&
                isValidEmail(parentEmail) &&
                selectedPassword.length == 3 &&
                !isSaving;
            final nameError = nameTouched
                ? (childName.isEmpty
                    ? l10n.fieldRequired
                    : (childName.toLowerCase() == 'child'
                        ? l10n.pleaseEnterRealName
                        : (childName.length < 2 ? l10n.nameTooShort : null)))
                : null;
            final emailError = emailTouched && !isValidEmail(parentEmail)
                ? (parentEmail.isEmpty ? l10n.fieldRequired : l10n.invalidEmail)
                : null;
            final showPasswordError =
                passwordTouched && selectedPassword.length != 3;

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.createChildProfile,
                          style: TextStyle(
                            fontSize: AppConstants.fontSize,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: childNameController,
                          decoration: InputDecoration(
                            labelText: l10n.childName,
                            errorText: nameError,
                            prefixIcon: const Icon(Icons.person),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setDialogState(() {
                            nameTouched = true;
                          }),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: parentEmailController,
                          decoration: InputDecoration(
                            labelText: l10n.parentEmail,
                            errorText: emailError,
                            prefixIcon: const Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          onChanged: (_) => setDialogState(() {
                            emailTouched = true;
                          }),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text('${l10n.childAge}:'),
                            const SizedBox(width: 12),
                            DropdownButton<int>(
                              value: age,
                              hint: Text('-'),
                              items: List.generate(8, (i) => i + 5)
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text('$value'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setDialogState(() {
                                age = value;
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(l10n.avatar),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 320,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _avatarOptions.map((option) {
                              final isSelected = selectedAvatar == option.id;
                              return InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    selectedAvatar = option.id;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.2)
                                        : Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: ClipOval(
                                      child: option.assetPath.isNotEmpty
                                          ? Image.asset(
                                              option.assetPath,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(
                                                option.icon,
                                                color: option.iconColor,
                                                size: 26,
                                              ),
                                            )
                                          : Icon(
                                              option.icon,
                                              color: option.iconColor,
                                              size: 26,
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.selectPicturePassword),
                        const SizedBox(height: 8),
                        PicturePasswordRow(
                          picturePassword: selectedPassword,
                          size: 22,
                          showPlaceholders: true,
                        ),
                        if (showPasswordError) ...[
                          const SizedBox(height: 6),
                          Text(
                            l10n.picturePasswordError,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 320,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _pictureOptions.map((option) {
                              final isSelected =
                                  selectedPassword.contains(option.id);
                              final optionColor =
                                  resolvePicturePasswordColor(context, option);
                              return InkWell(
                                onTap: () =>
                                    togglePicture(option.id, setDialogState),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? optionColor.withValues(alpha: 0.2)
                                        : Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? optionColor
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    option.icon,
                                    size: 26,
                                    color: optionColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                child: Text(l10n.cancel),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: canSave
                                    ? () async {
                                        setDialogState(() {
                                          isSaving = true;
                                          nameTouched = true;
                                          emailTouched = true;
                                          passwordTouched = true;
                                        });

                                        final trimmedName =
                                            childNameController.text.trim();
                                        final trimmedEmail =
                                            parentEmailController.text.trim();

                                        if (trimmedName.isEmpty ||
                                            trimmedName.toLowerCase() ==
                                                'child' ||
                                            trimmedName.length < 2 ||
                                            !isValidEmail(trimmedEmail) ||
                                            age == null ||
                                            age! < 5 ||
                                            age! > 12 ||
                                            selectedPassword.length != 3) {
                                          setDialogState(() {
                                            isSaving = false;
                                          });
                                          _showTopMessage(
                                            l10n.childLoginMissingData,
                                          );
                                          return;
                                        }

                                        final authController = ref.read(
                                            authControllerProvider.notifier);
                                        var response =
                                            await authController.registerChild(
                                          name: trimmedName,
                                          picturePassword: List<String>.from(
                                              selectedPassword),
                                          parentEmail: trimmedEmail,
                                          age: age ?? 0,
                                          avatar: selectedAvatar,
                                        );

                                        if (response == null &&
                                            ref
                                                    .read(
                                                        authControllerProvider)
                                                    .error ==
                                                'child_register_limit') {
                                          setDialogState(() {
                                            isSaving = false;
                                          });
                                          _showTopMessage(
                                            l10n.childRegisterLimitReached,
                                          );
                                          final upgraded = await _openPaywall();
                                          if (!upgraded) {
                                            return;
                                          }
                                          if (!mounted) return;
                                          setDialogState(() {
                                            isSaving = true;
                                          });
                                          response = await authController
                                              .registerChild(
                                            name: trimmedName,
                                            picturePassword: List<String>.from(
                                              selectedPassword,
                                            ),
                                            parentEmail: trimmedEmail,
                                            age: age ?? 0,
                                            avatar: selectedAvatar,
                                          );
                                        }

                                        if (response == null) {
                                          setDialogState(() {
                                            isSaving = false;
                                          });
                                          final error = ref
                                              .read(authControllerProvider)
                                              .error;
                                          _showTopMessage(
                                            _mapChildRegisterError(l10n, error),
                                          );
                                          return;
                                        }

                                        await ref
                                            .read(secureStorageProvider)
                                            .saveUserEmail(trimmedEmail);

                                        final resolvedName =
                                            response.name?.trim().isNotEmpty ==
                                                    true
                                                ? response.name!.trim()
                                                : trimmedName;
                                        final now = DateTime.now();
                                        final existing =
                                            await repo.getChildProfile(
                                          response.childId,
                                        );
                                        final updatedProfile = (existing ??
                                                ChildProfile(
                                                  id: response.childId,
                                                  name: resolvedName,
                                                  age: age ?? 0,
                                                  avatar: selectedAvatar,
                                                  avatarPath: selectedAvatar,
                                                  interests: const [],
                                                  level: 1,
                                                  xp: 0,
                                                  streak: 0,
                                                  favorites: const [],
                                                  parentId: trimmedEmail,
                                                  parentEmail: trimmedEmail,
                                                  picturePassword:
                                                      List<String>.from(
                                                    selectedPassword,
                                                  ),
                                                  createdAt: now,
                                                  updatedAt: now,
                                                  lastSession: null,
                                                  totalTimeSpent: 0,
                                                  activitiesCompleted: 0,
                                                  currentMood: null,
                                                  learningStyle: null,
                                                  specialNeeds: null,
                                                  accessibilityNeeds: null,
                                                ))
                                            .copyWith(
                                          name: resolvedName,
                                          age: age ?? existing?.age ?? 0,
                                          avatar: selectedAvatar,
                                          avatarPath: selectedAvatar,
                                          parentId: trimmedEmail,
                                          parentEmail: trimmedEmail,
                                          picturePassword: List<String>.from(
                                            selectedPassword,
                                          ),
                                          updatedAt: now,
                                        );

                                        final saved = existing == null
                                            ? await repo.createChildProfile(
                                                updatedProfile,
                                              )
                                            : await repo.updateChildProfile(
                                                updatedProfile,
                                              );

                                        if (saved == null) {
                                          setDialogState(() {
                                            isSaving = false;
                                          });
                                          _showTopMessage(
                                              l10n.childProfileAddFailed);
                                          return;
                                        }

                                        if (mounted) {
                                          // Pop dialog first while dialogContext is valid
                                          // ignore: use_build_context_synchronously
                                          Navigator.of(dialogContext).pop();
                                        }
                                        if (mounted) {
                                          _refreshChildren();
                                          _selectChild(saved);
                                        }
                                      }
                                    : null,
                                child: isSaving
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFFFFFFF),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(l10n.save),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    childNameController.dispose();
    parentEmailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: _isLoading
            ? const SizedBox.shrink()
            : const AppBackButton(
                fallback: Routes.selectUserType,
                icon: Icons.arrow_back,
                iconSize: 24,
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                l10n.childLogin,
                style: TextStyle(
                  fontSize: AppConstants.largeFontSize * 1.2,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.chooseProfileToContinue,
                style: TextStyle(
                  fontSize: AppConstants.fontSize,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),
              FutureBuilder<List<ChildProfile>>(
                future: _childrenFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(l10n);
                  }

                  final children =
                      _dedupeChildren(snapshot.data ?? const <ChildProfile>[]);
                  return _buildLoginFlow(l10n, children);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginFlow(AppLocalizations l10n, List<ChildProfile> children) {
    if (children.isEmpty) {
      return _buildManualLogin(context, l10n);
    }

    final selectedChild = _resolveSelectedChild(children);
    if (selectedChild == null) {
      if (_selectedChildId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _resetSelection();
        });
      }
      if (children.length == 1) {
        _queueSelectChild(children.first);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      }
      return _buildChildSelection(l10n, children);
    }

    return _buildSelectedChildLogin(
      l10n,
      selectedChild,
      canChangeChild: children.length > 1,
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.child_care_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? l10n.noChildProfilesFound,
            style: TextStyle(
              fontSize: AppConstants.fontSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            height: 48,
            child: ElevatedButton(
              onPressed:
                  _isLoading ? null : () => context.go('/select-user-type'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(l10n.goBack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualLogin(BuildContext context, AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canLogin = !_isLoading &&
        _childNameController.text.trim().isNotEmpty &&
        _childIdController.text.trim().isNotEmpty &&
        _selectedPictures.length == 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.childName,
          style: textTheme.titleMedium?.copyWith(
            fontSize: AppConstants.fontSize,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _childNameController,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: colors.onSurface),
          decoration: _buildLoginDecoration(
            context,
            label: l10n.childName,
            icon: Icons.person,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.childId,
          style: textTheme.titleMedium?.copyWith(
            fontSize: AppConstants.fontSize,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _childIdController,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.none,
          style: TextStyle(color: colors.onSurface),
          decoration: _buildLoginDecoration(
            context,
            label: l10n.childId,
            icon: Icons.badge,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
          ],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        _buildPicturePasswordPicker(l10n),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canLogin
                ? () => _loginWithChildId(
                      childId: _childIdController.text,
                      childName: _childNameController.text,
                    )
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.surface)
                : Text(
                    l10n.login,
                    style: TextStyle(
                      fontSize: AppConstants.fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed:
                _isLoading ? null : () => context.go('/child/forgot-password'),
            child: Text(l10n.forgotPassword),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _showCreateProfileDialog(l10n),
            icon: const Icon(Icons.add),
            label: Text(l10n.createChildProfile),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChildSelection(
      AppLocalizations l10n, List<ChildProfile> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.chooseYourProfile,
          style: TextStyle(
            fontSize: AppConstants.fontSize,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            ...children.map((child) => _buildChildCard(child, l10n)),
            _buildCreateProfileCard(l10n),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedChildLogin(
    AppLocalizations l10n,
    ChildProfile child, {
    required bool canChangeChild,
  }) {
    final canLogin = !_isLoading && _selectedPictures.length == 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              _buildAvatarCircle(
                avatarId: child.avatar,
                avatarPath: child.avatarPath,
                size: 50,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name.isNotEmpty ? child.name : child.id,
                      style: TextStyle(
                        fontSize: AppConstants.fontSize,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (child.age > 0)
                      Text(
                        l10n.yearsOld(child.age),
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (canChangeChild)
                IconButton(
                  icon: Icon(Icons.close,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onPressed: _isLoading ? null : _resetSelection,
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildPicturePasswordPicker(l10n),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canLogin
                ? () => _loginWithChildId(
                      childId: child.id,
                      childName: child.name,
                      childProfile: child,
                    )
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.childTheme.kindness,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.surface)
                : Text(
                    l10n.login,
                    style: TextStyle(
                      fontSize: AppConstants.fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed:
                _isLoading ? null : () => context.go('/child/forgot-password'),
            child: Text(l10n.forgotPassword),
          ),
        ),
      ],
    );
  }

  Widget _buildPicturePasswordPicker(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectPicturePassword,
          style: TextStyle(
            fontSize: AppConstants.fontSize,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        PicturePasswordRow(
          picturePassword: _selectedPictures,
          size: 20,
          showPlaceholders: true,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _pictureOptions.length,
          itemBuilder: (context, index) {
            final option = _pictureOptions[index];
            final isSelected = _selectedPictures.contains(option.id);
            final optionColor = resolvePicturePasswordColor(context, option);
            return InkWell(
              onTap: () => _togglePicture(option.id),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? optionColor.withValues(alpha: 0.2)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? optionColor
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    width: 2,
                  ),
                ),
                child: Icon(
                  option.icon,
                  size: 28,
                  color: optionColor,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvatarCircle({
    required String? avatarId,
    required String? avatarPath,
    required double size,
    required Color backgroundColor,
  }) {
    final option = _avatarForValue(avatarId ?? avatarPath);
    final resolvedBackground = option?.backgroundColor ?? backgroundColor;
    final resolvedPath =
        option?.assetPath.isNotEmpty == true ? option!.assetPath : avatarPath;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: ClipOval(
        child: AvatarView(
          avatarId: avatarId,
          avatarPath: resolvedPath,
          radius: size / 2,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildChildCard(ChildProfile child, AppLocalizations l10n) {
    final isSelected = _selectedChildId == child.id;

    return InkWell(
      onTap: _isLoading ? null : () => _selectChild(child),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            _buildAvatarCircle(
              avatarId: child.avatar,
              avatarPath: child.avatarPath,
              size: 64,
              backgroundColor: context.childTheme.kindness.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              child.name.isNotEmpty ? child.name : child.id,
              style: TextStyle(
                fontSize: AppConstants.fontSize,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (child.age > 0) ...[
              const SizedBox(height: 4),
              Text(
                l10n.yearsOld(child.age),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                '—',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.childTheme.xp.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${l10n.level} ${child.level}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.childTheme.xp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateProfileCard(AppLocalizations l10n) {
    return InkWell(
      onTap: _isLoading ? null : () => _showCreateProfileDialog(l10n),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context).colorScheme.surfaceContainerHighest),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.createChildProfile,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
