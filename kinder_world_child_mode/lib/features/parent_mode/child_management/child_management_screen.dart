// ignore_for_file: prefer_const_constructors
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/router.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/widgets/picture_password_row.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/plan_status_banner.dart';

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

class ChildManagementScreen extends ConsumerStatefulWidget {
  const ChildManagementScreen({super.key});

  @override
  ConsumerState<ChildManagementScreen> createState() =>
      _ChildManagementScreenState();
}

class _ChildManagementScreenState extends ConsumerState<ChildManagementScreen> {
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
  Future<List<ChildProfile>>? _childrenFuture;
  String? _cachedParentId;
  OverlayEntry? _topMessageEntry;

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
        'Child age resolve: apiAge=$apiAge, birthDate=$birthDate, computedAge=$computedAge, existing=${existing?.age}',
      );
    }

    if (apiAge > 0) return apiAge;
    if (computedAge > 0) return computedAge;
    return existing?.age ?? 0;
  }

  ChildProfile? _mergeChildProfileFromApi(
    Map<String, dynamic> data, {
    required String parentId,
    String? parentEmail,
    ChildProfile? existing,
  }) {
    final childId = _parseChildId(data);
    if (childId == null || childId.isEmpty) return null;

    final now = DateTime.now();
    final apiName = data['name']?.toString().trim();
    final resolvedName = (apiName != null && apiName.isNotEmpty)
        ? apiName
        : (existing?.name ?? childId);
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
      parentId: parentId,
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

  String? _extractChildIdFromResponse(dynamic data) {
    if (data is Map) {
      final child = data['child'];
      if (child is Map) {
        return _parseChildId(Map<String, dynamic>.from(child)) ??
            _parseChildId(Map<String, dynamic>.from(data));
      }
      return _parseChildId(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<List<ChildProfile>> _loadChildrenForParent(String parentId) async {
    final repo = ref.read(childRepositoryProvider);
    final parentEmail = await ref.read(secureStorageProvider).getParentEmail();
    if (parentEmail != null && parentEmail.isNotEmpty) {
      await repo.linkChildrenToParent(
        parentId: parentId,
        parentEmail: parentEmail,
      );
    }
    final localChildren = await repo.getChildProfilesForParent(parentId);
    final childrenById = {
      for (final child in localChildren) child.id: child,
    };

    final token = await ref.read(secureStorageProvider).getAuthToken();
    if (token == null || token.startsWith('child_session_')) {
      return childrenById.values.toList();
    }

    final resolvedParentEmail = parentEmail;
    try {
      final response = await ref.read(networkServiceProvider).get<dynamic>(
            '/children',
          );
      final apiChildren = _extractChildrenList(response.data);
      for (final childData in apiChildren) {
        final childId = _parseChildId(childData);
        if (childId == null || childId.isEmpty) continue;
        final existing =
            await repo.getChildProfile(childId) ?? childrenById[childId];
        final merged = _mergeChildProfileFromApi(
          childData,
          parentId: parentId,
          parentEmail: resolvedParentEmail,
          existing: existing,
        );
        if (merged == null) continue;
        childrenById[childId] = merged;
        if (existing == null) {
          await repo.createChildProfile(merged);
        } else {
          await repo.updateChildProfile(merged);
        }
      }
    } catch (_) {
      return childrenById.values.toList();
    }

    return childrenById.values.toList();
  }

  Future<void> _refreshChildren() async {
    final parentId = await ref.read(secureStorageProvider).getParentId();
    if (!mounted) return;
    final resolvedParentId = parentId ?? '';
    setState(() {
      _cachedParentId = resolvedParentId;
      _childrenFuture = _loadChildrenForParent(resolvedParentId);
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
                  color: isError
                      ? ParentColors.alertRed
                      : ParentColors.parentGreenLight,
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

  Future<void> _showChildLimitDialog(AppLocalizations l10n) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.freePlanChildLimit),
          content: Text(l10n.planFeatureInPremium),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push('/parent/subscription');
              },
              child: Text(l10n.upgradeNow),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteChild(ChildProfile child) async {
    final l10n = AppLocalizations.of(context)!;
    bool isDeleting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.deleteChildTitle),
              content: Text(l10n.deleteChildDescription),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                          });
                          try {
                            await ref
                                .read(networkServiceProvider)
                                .delete('/children/${child.id}');
                            final repo = ref.read(childRepositoryProvider);
                            final deleted =
                                await repo.deleteChildProfile(child.id);
                            if (!mounted) return;
                            if (mounted) {
                              // ignore: use_build_context_synchronously
                              Navigator.of(dialogContext).pop();
                            }
                            if (deleted) {
                              _showTopMessage(
                                l10n.deleteChildSuccess,
                                isError: false,
                              );
                            } else {
                              _showTopMessage(l10n.deleteChildFailed);
                            }
                            if (_cachedParentId != null) {
                              setState(() {
                                _childrenFuture =
                                    _loadChildrenForParent(_cachedParentId!);
                              });
                            } else {
                              _refreshChildren();
                            }
                          } on DioException catch (e) {
                            final statusCode = e.response?.statusCode;
                            if (statusCode == 403 ||
                                statusCode == 409 ||
                                statusCode == 500) {
                              _showTopMessage(l10n.deleteChildFailed);
                            } else {
                              _showTopMessage(l10n.deleteChildFailed);
                            }
                            setDialogState(() {
                              isDeleting = false;
                            });
                          } catch (_) {
                            _showTopMessage(l10n.deleteChildFailed);
                            setDialogState(() {
                              isDeleting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParentColors.alertRed,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: isDeleting
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.surface,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(l10n.delete),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _topMessageEntry?.remove();
    _topMessageEntry = null;
    super.dispose();
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

  Widget _buildAvatarCircle({
    required String? avatarId,
    required String? avatarPath,
    required double size,
  }) {
    final option = _avatarForValue(avatarId ?? avatarPath);
    final resolvedBackground = option?.backgroundColor ??
        ParentColors.parentGreen.withValues(alpha: 0.1);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(Routes.parentSettings);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => context.go(Routes.parentSettings),
          ),
          title: Text(
            l10n.childManagement,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(
                height: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.4)),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: FutureBuilder<String?>(
                    future: ref.read(secureStorageProvider).getParentId(),
                    builder: (context, parentIdSnapshot) {
                      final parentId = parentIdSnapshot.data ?? '';
                      if (_childrenFuture == null ||
                          _cachedParentId != parentId) {
                        _cachedParentId = parentId;
                        _childrenFuture = _loadChildrenForParent(parentId);
                      }
                      return FutureBuilder<List<ChildProfile>>(
                        future: _childrenFuture,
                        builder: (context, childrenSnapshot) {
                          final repoChildren = childrenSnapshot.data ?? [];
                          final children = repoChildren;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              Text(
                                l10n.manageChildProfiles,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.addEditManageChildren,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const PlanStatusBanner(),
                              Text(
                                l10n.yourChildren,
                                style: TextStyle(
                                  fontSize: AppConstants.fontSize,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (children.isEmpty)
                                ParentEmptyState(
                                  icon: Icons.child_care_rounded,
                                  title: l10n.noChildProfilesYet,
                                  subtitle: l10n.tapToAddChild,
                                )
                              else
                                Column(
                                  children:
                                      children.map(_buildChildCard).toList(),
                                ),
                              const SizedBox(height: 24),
                              Text(
                                l10n.childProfiles,
                                style: TextStyle(
                                  fontSize: AppConstants.fontSize,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureItem(
                                  Icons.person_add, l10n.addChildProfiles),
                              _buildFeatureItem(Icons.edit, l10n.editProfiles),
                              _buildFeatureItem(
                                  Icons.lock, l10n.picturePasswords),
                              _buildFeatureItem(
                                  Icons.settings, l10n.configurePreferences),
                              _buildFeatureItem(
                                  Icons.delete, l10n.deactivateProfiles),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final l10n = AppLocalizations.of(context)!;
            try {
              final plan = await ref.read(planInfoProvider.future);
              final parentId =
                  await ref.read(secureStorageProvider).getParentId();
              final repo = ref.read(childRepositoryProvider);
              final currentChildren = parentId != null && parentId.isNotEmpty
                  ? await repo.getChildProfilesForParent(parentId)
                  : await repo.getAllChildProfiles();
              if (!plan.canAddChild(currentChildren.length)) {
                await _showChildLimitDialog(l10n);
                return;
              }
            } catch (_) {
              // If plan lookup fails, continue without blocking.
            }

            if (!mounted) return;
            final parentContext = context;
            // ignore: use_build_context_synchronously
            final messenger = ScaffoldMessenger.of(parentContext);
            String name = '';
            int? age;
            String selectedAvatar = _avatarOptions.first.id;
            final List<String> picturePassword = [];
            bool passwordTouched = false;
            bool isSaving = false;

            await showDialog<void>(
              // ignore: use_build_context_synchronously
              context: parentContext,
              builder: (dialogContext) {
                return StatefulBuilder(
                  builder: (context, setDialogState) {
                    final trimmedName = name.trim();
                    final isValidName = trimmedName.isNotEmpty &&
                        trimmedName.toLowerCase() != 'child' &&
                        trimmedName.length >= 2;
                    final canSave =
                        isValidName && picturePassword.length == 3 && !isSaving;
                    final showPasswordError =
                        passwordTouched && picturePassword.length != 3;
                    void togglePicture(String pictureId) {
                      setDialogState(() {
                        passwordTouched = true;
                        if (picturePassword.contains(pictureId)) {
                          picturePassword.remove(pictureId);
                        } else if (picturePassword.length < 3) {
                          picturePassword.add(pictureId);
                        }
                      });
                    }

                    return AlertDialog(
                      title: Text(l10n.addChild),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              decoration: InputDecoration(
                                labelText: l10n.childName,
                                errorText: name.trim().isEmpty
                                    ? null
                                    : (name.trim().toLowerCase() == 'child'
                                        ? l10n.pleaseEnterRealName
                                        : (name.trim().length < 2
                                            ? l10n.nameTooShort
                                            : null)),
                              ),
                              textCapitalization: TextCapitalization.words,
                              keyboardType: TextInputType.name,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r"[a-zA-Z\u0600-\u06FF\s'-]"),
                                ),
                              ],
                              onChanged: (v) => setDialogState(() {
                                name = v;
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
                                      .map((v) => DropdownMenuItem(
                                            value: v,
                                            child: Text('$v'),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setDialogState(() {
                                    age = v;
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(l10n.avatar),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 320,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _avatarOptions.map((option) {
                                  final isSelected =
                                      selectedAvatar == option.id;
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
                                            ? ParentColors.parentGreen
                                                .withValues(alpha: 0.2)
                                            : Theme.of(context)
                                                .colorScheme
                                                .surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? ParentColors.parentGreen
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: _buildAvatarOption(option),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(l10n.selectPicturePassword),
                            ),
                            const SizedBox(height: 8),
                            PicturePasswordRow(
                              picturePassword: picturePassword,
                              size: 20,
                              showPlaceholders: true,
                            ),
                            if (showPasswordError) ...[
                              const SizedBox(height: 6),
                              Text(
                                l10n.picturePasswordError,
                                style: TextStyle(
                                  color: ParentColors.alertRed,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 320,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: picturePasswordOptions.map((option) {
                                  final isSelected =
                                      picturePassword.contains(option.id);
                                  return InkWell(
                                    onTap: () => togglePicture(option.id),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? option.color
                                                .withValues(alpha: 0.2)
                                            : Theme.of(context)
                                                .colorScheme
                                                .surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? option.color
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        option.icon,
                                        size: 24,
                                        color: option.color,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.cancel),
                        ),
                        ElevatedButton(
                          onPressed: canSave
                              ? () async {
                                  setDialogState(() {
                                    isSaving = true;
                                    passwordTouched = true;
                                  });

                                  final trimmedName = name.trim();
                                  if (trimmedName.isEmpty ||
                                      trimmedName.toLowerCase() == 'child' ||
                                      trimmedName.length < 2 ||
                                      age == null ||
                                      age! < 5 ||
                                      age! > 12 ||
                                      picturePassword.length != 3) {
                                    setDialogState(() {
                                      isSaving = false;
                                    });
                                    _showTopMessage(l10n.childLoginMissingData);
                                    return;
                                  }

                                  Map<String, dynamic>? responseData;
                                  try {
                                    final response = await ref
                                        .read(networkServiceProvider)
                                        .post<Map<String, dynamic>>(
                                      '/children',
                                      data: {
                                        'name': trimmedName,
                                        'picture_password':
                                            List<String>.from(picturePassword),
                                        'age': age,
                                        'avatar': selectedAvatar,
                                      },
                                    );
                                    responseData = response.data;
                                  } catch (_) {
                                    setDialogState(() {
                                      isSaving = false;
                                    });
                                    _showTopMessage(l10n.childProfileAddFailed);
                                    return;
                                  }

                                  final childId =
                                      _extractChildIdFromResponse(responseData);
                                  if (childId == null || childId.isEmpty) {
                                    setDialogState(() {
                                      isSaving = false;
                                    });
                                    _showTopMessage(l10n.childProfileAddFailed);
                                    return;
                                  }

                                  final parentId = await ref
                                      .read(secureStorageProvider)
                                      .getParentId();
                                  final parentEmail = await ref
                                      .read(secureStorageProvider)
                                      .getParentEmail();
                                  final now = DateTime.now();
                                  final repo =
                                      ref.read(childRepositoryProvider);
                                  final existing =
                                      await repo.getChildProfile(childId);
                                  final newProfile = ChildProfile(
                                    id: childId,
                                    name: trimmedName,
                                    age: age ?? 0,
                                    avatar: selectedAvatar,
                                    avatarPath: selectedAvatar,
                                    interests: existing?.interests ?? const [],
                                    level: existing?.level ?? 1,
                                    xp: existing?.xp ?? 0,
                                    streak: existing?.streak ?? 0,
                                    favorites: existing?.favorites ?? const [],
                                    parentId: parentId ?? 'local',
                                    parentEmail:
                                        existing?.parentEmail ?? parentEmail,
                                    picturePassword:
                                        List<String>.from(picturePassword),
                                    createdAt: existing?.createdAt ?? now,
                                    updatedAt: now,
                                    totalTimeSpent:
                                        existing?.totalTimeSpent ?? 0,
                                    activitiesCompleted:
                                        existing?.activitiesCompleted ?? 0,
                                    currentMood: existing?.currentMood,
                                    learningStyle: existing?.learningStyle,
                                    specialNeeds: existing?.specialNeeds,
                                    accessibilityNeeds:
                                        existing?.accessibilityNeeds,
                                  );

                                  final saved = existing == null
                                      ? await repo
                                          .createChildProfile(newProfile)
                                      : await repo
                                          .updateChildProfile(newProfile);

                                  if (!mounted) return;

                                  if (saved != null) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.childProfileAdded),
                                      ),
                                    );
                                  } else {
                                    _showTopMessage(l10n.childProfileAddFailed);
                                  }

                                  if (!mounted) return;
                                  if (mounted) {
                                    // ignore: use_build_context_synchronously
                                    Navigator.of(dialogContext).pop();
                                  }
                                  if (_cachedParentId != null) {
                                    setState(() {
                                      _childrenFuture = _loadChildrenForParent(
                                          _cachedParentId!);
                                    });
                                  }
                                }
                              : null,
                          child: isSaving
                              ? SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.addChild),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
          backgroundColor: ParentColors.parentGreen,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildChildCard(ChildProfile child) {
    final l10n = AppLocalizations.of(context)!;
    final hasAge = child.age > 0;
    final hasLevel = child.level > 0;
    final details = <String>[];
    if (hasAge) {
      details.add(l10n.yearsOld(child.age));
    }
    if (hasLevel) {
      details.add('${l10n.level} ${child.level}');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ParentCard(
        onTap: () => context.push('/parent/child-profile', extra: child),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatarCircle(
                  avatarId: child.avatar,
                  avatarPath: child.avatarPath,
                  size: 60,
                ),
                const SizedBox(height: 6),
                PicturePasswordRow(
                  picturePassword: child.picturePassword,
                  size: 14,
                  showPlaceholders: true,
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: TextStyle(
                      fontSize: AppConstants.fontSize,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l10n.childId}: ${child.id}',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: child.id),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.success),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' - '),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        '${child.activitiesCompleted} ${l10n.activities}',
                        ParentColors.parentGreenLight,
                      ),
                      _buildInfoChip(
                        '${child.totalTimeSpent} ${l10n.timeSpent}',
                        ParentColors.infoBlue,
                      ),
                      _buildInfoChip(
                        '${child.streak} ${l10n.dailyStreak}',
                        ParentColors.streakOrange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    MoodTypes.getEmoji(child.currentMood ?? MoodTypes.happy),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(height: 8),
                Tooltip(
                  message: l10n.activityReports,
                  child: IconButton(
                    onPressed: () =>
                        context.push('/parent/reports', extra: child.id),
                    icon: const Icon(Icons.pie_chart),
                    color: ParentColors.parentGreen,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 8),
                Tooltip(
                  message: l10n.delete,
                  child: IconButton(
                    onPressed: () => _confirmDeleteChild(child),
                    icon: const Icon(Icons.delete_outline),
                    color: ParentColors.alertRed,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: ParentColors.parentGreen, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarOption(_AvatarOption option) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: option.backgroundColor,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: option.assetPath.isNotEmpty
            ? Image.asset(
                option.assetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(
                    option.icon,
                    color: option.iconColor,
                    size: 24,
                  ),
                ),
              )
            : Center(
                child: Icon(
                  option.icon,
                  color: option.iconColor,
                  size: 24,
                ),
              ),
      ),
    );
  }
}
