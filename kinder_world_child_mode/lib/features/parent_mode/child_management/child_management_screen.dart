import 'dart:async';

// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/router.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/data/child_avatar_catalog.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/providers/deferred_operations_provider.dart';
import 'package:kinder_world/core/services/children_cache_service.dart';
import 'package:kinder_world/core/utils/children_api_parsing.dart';
import 'package:kinder_world/core/widgets/picture_password_row.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/plan_status_banner.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

class ChildManagementScreen extends ConsumerStatefulWidget {
  const ChildManagementScreen({super.key});

  @override
  ConsumerState<ChildManagementScreen> createState() =>
      _ChildManagementScreenState();
}

class _ChildManagementScreenState extends ConsumerState<ChildManagementScreen> {
  Future<List<ChildProfile>>? _childrenFuture;
  String? _cachedParentId;
  OverlayEntry? _topMessageEntry;

  @override
  void initState() {
    super.initState();
    // The plan snapshot (Free/Premium, child limit) is a non-autodispose
    // FutureProvider, so Riverpod caches its first result for the whole
    // session. An admin-side upgrade therefore wouldn't show here until a
    // manual refresh. Invalidate it on entry so the plan banner and the
    // child-limit check always reflect the latest plan straight away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(subscriptionSnapshotProvider);
    });
  }

  bool _isOfflineDioError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
  }

  String? _extractChildIdFromResponse(dynamic data) {
    if (data is Map) {
      final child = data['child'];
      if (child is Map) {
        return parseChildId(Map<String, dynamic>.from(child)) ??
            parseChildId(Map<String, dynamic>.from(data));
      }
      return parseChildId(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<List<ChildProfile>> _loadChildrenForParent(String parentId) async {
    final parentEmail = await ref.read(secureStorageProvider).getParentEmail();
    final result =
        await ref.read(childrenCacheServiceProvider).loadChildrenForParent(
              parentId,
              parentEmail: parentEmail,
            );
    return result.children;
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
                      ? context.parentTheme.danger
                      : context.parentTheme.success,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .shadow
                          .withValuesCompat(alpha: 0.2),
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
                unawaited(context.push('/parent/subscription'));
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
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            if (deleted) {
                              await ref
                                  .read(childrenCacheServiceProvider)
                                  .markChildrenMutated(_cachedParentId ?? '');
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
                              await _refreshChildren();
                            }
                          } on DioException catch (e) {
                            if (_isOfflineDioError(e)) {
                              final queue =
                                  ref.read(deferredOperationsQueueProvider);
                              await queue.enqueueHttpOperation(
                                method: 'DELETE',
                                path: '/children/${child.id}',
                              );
                              final repo = ref.read(childRepositoryProvider);
                              final deleted =
                                  await repo.deleteChildProfile(child.id);
                              if (!mounted) return;
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              if (deleted) {
                                await ref
                                    .read(childrenCacheServiceProvider)
                                    .markChildrenMutated(_cachedParentId ?? '');
                                _showTopMessage(
                                  l10n.deletedOfflineWillSync,
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
                                await _refreshChildren();
                              }
                              return;
                            }
                            _showTopMessage(l10n.deleteChildFailed);
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
                    backgroundColor: context.parentTheme.danger,
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

  Widget _buildAvatarCircle({
    required String? avatarId,
    required String? avatarPath,
    required double size,
  }) {
    final option = childAvatarOptionForValue(avatarId ?? avatarPath);
    final resolvedBackground = option?.backgroundColor ??
        context.parentTheme.primary.withValuesCompat(alpha: 0.1);
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
          context.appBack(fallback: Routes.parentDashboard);
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
            onPressed: () => context.appBack(fallback: Routes.parentDashboard),
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
                    .withValuesCompat(alpha: 0.4)),
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
            final messenger = ScaffoldMessenger.of(context);
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
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.tryAgain)),
              );
              return;
            }

            if (!mounted) return;
            // ignore: use_build_context_synchronously
            final parentContext = context;
            String name = '';
            int? age;
            String selectedAvatar = defaultChildAvatarId;
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
                                  hint: Text(l10n.placeholderDash),
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
                                children: childAvatarOptions.map((option) {
                                  // New children start at level 1, so avatars
                                  // are gated the same way the child sees them
                                  // in the profile customization screen.
                                  final isUnlocked =
                                      option.isUnlockedForLevel(1);
                                  final isSelected =
                                      selectedAvatar == option.id;
                                  return InkWell(
                                    onTap: isUnlocked
                                        ? () {
                                            setDialogState(() {
                                              selectedAvatar = option.id;
                                            });
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? context.parentTheme.primary
                                                .withValuesCompat(alpha: 0.2)
                                            : Theme.of(context)
                                                .colorScheme
                                                .surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? context.parentTheme.primary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: isUnlocked
                                            ? _buildAvatarOption(option)
                                            : Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Opacity(
                                                    opacity: 0.35,
                                                    child: _buildAvatarOption(
                                                        option),
                                                  ),
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.lock_rounded,
                                                        size: 18,
                                                      ),
                                                      if (option.unlockLevel !=
                                                          null)
                                                        Text(
                                                          'LV${option.unlockLevel}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
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
                                  color: context.parentTheme.danger,
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
                                  final optionColor =
                                      resolvePicturePasswordColor(
                                          context, option);
                                  return InkWell(
                                    onTap: () => togglePicture(option.id),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? optionColor.withValuesCompat(
                                                alpha: 0.2)
                                            : Theme.of(context)
                                                .colorScheme
                                                .surface,
                                        borderRadius: BorderRadius.circular(12),
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
                                        size: 24,
                                        color: optionColor,
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
                                  final resolvedParentId =
                                      parentId ?? existing?.parentId;
                                  if (resolvedParentId == null ||
                                      resolvedParentId.isEmpty) {
                                    setDialogState(() {
                                      isSaving = false;
                                    });
                                    _showTopMessage(
                                      l10n.parentSessionMissing,
                                    );
                                    return;
                                  }
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
                                    parentId: resolvedParentId,
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
                                    await ref
                                        .read(childrenCacheServiceProvider)
                                        .markChildrenMutated(resolvedParentId);
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
          backgroundColor: context.parentTheme.primary,
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
        onTap: () => unawaited(
          context.push(
            Routes.parentChildProfileById(child.id),
            extra: child,
          ),
        ),
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
                        context.parentTheme.success,
                      ),
                      _buildInfoChip(
                        '${child.totalTimeSpent} ${l10n.timeSpent}',
                        context.parentTheme.info,
                      ),
                      _buildInfoChip(
                        '${child.streak} ${l10n.dailyStreak}',
                        context.parentTheme.warning,
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
                    onPressed: () => unawaited(
                      context.push('/parent/reports', extra: child.id),
                    ),
                    icon: const Icon(Icons.pie_chart),
                    color: context.parentTheme.primary,
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
                    color: context.parentTheme.danger,
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
        color: color.withValuesCompat(alpha: 0.1),
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
          Icon(icon, color: context.parentTheme.primary, size: 20),
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

  Widget _buildAvatarOption(ChildAvatarOption option) {
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
