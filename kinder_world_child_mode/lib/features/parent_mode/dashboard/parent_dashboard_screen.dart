import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/services/child_profiles_view_service.dart';
import 'package:kinder_world/core/widgets/app_skeleton_widgets.dart';
import 'package:kinder_world/core/widgets/app_state_widgets.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/features/parent_mode/dashboard/widgets/parent_dashboard_app_bar.dart';
import 'package:kinder_world/features/parent_mode/dashboard/widgets/parent_dashboard_sections.dart';

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Future<List<ChildProfile>>? _childrenFuture;
  Future<List<ProgressRecord>>? _recentActivitiesFuture;
  String? _cachedParentId;
  String? _recentActivitiesKey;
  bool _isResolvingParent = true;
  int _childrenRequestId = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _resolveParentContext();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resolveParentContext() {
    final secureStorage = ref.read(secureStorageProvider);
    final cachedParentId =
        secureStorage.hasCachedUserId ? secureStorage.cachedUserId : null;
    if (cachedParentId != null && cachedParentId.isNotEmpty) {
      _cachedParentId = cachedParentId;
      _childrenFuture = _loadChildrenForParent(cachedParentId);
      _isResolvingParent = false;
      return;
    }

    Future<void>(() async {
      final parentId = await secureStorage.getParentId();
      if (!mounted) return;
      setState(() {
        _cachedParentId = parentId;
        _childrenFuture =
            parentId == null ? null : _loadChildrenForParent(parentId);
        _isResolvingParent = false;
      });
    });
  }

  Future<List<ChildProfile>> _loadChildrenForParent(String parentId) async {
    final secureStorage = ref.read(secureStorageProvider);
    final requestId = ++_childrenRequestId;
    final parentEmail = secureStorage.hasCachedUserEmail
        ? secureStorage.cachedUserEmail
        : await secureStorage.getParentEmail();
    return ref.read(childProfilesViewServiceProvider).loadParentChildren(
          parentId: parentId,
          parentEmail: parentEmail,
          onRemoteSynced: (children) {
            if (!mounted ||
                requestId != _childrenRequestId ||
                _cachedParentId != parentId) {
              return;
            }
            setState(() {
              _childrenFuture = Future<List<ChildProfile>>.value(children);
              _recentActivitiesFuture = null;
              _recentActivitiesKey = null;
            });
          },
        );
  }

  void _retryLoadChildren() {
    final parentId = _cachedParentId;
    if (parentId == null || parentId.isEmpty) {
      // No resolved parent id yet — re-run the resolution flow from scratch.
      _resolveParentContext();
      return;
    }
    setState(() {
      _childrenFuture = _loadChildrenForParent(parentId);
      _recentActivitiesFuture = null;
      _recentActivitiesKey = null;
    });
  }

  Future<List<ProgressRecord>> _recentActivitiesForChildren(
    List<ChildProfile> children,
  ) {
    final sortedIds = children.map((child) => child.id).toList()..sort();
    final key = sortedIds.join('|');
    if (_recentActivitiesFuture == null || _recentActivitiesKey != key) {
      _recentActivitiesKey = key;
      _recentActivitiesFuture = _getRecentActivitiesForAllChildren(children);
    }
    return _recentActivitiesFuture!;
  }

  String _dashboardGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorningOverview;
    if (hour < 17) return l10n.goodAfternoonOverview;
    return l10n.goodEveningOverview;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: _isResolvingParent
              ? const ParentDashboardSkeleton()
              : _childrenFuture == null
                  ? ParentEmptyState(
                      icon: Icons.child_care_outlined,
                      title: l10n.error,
                      subtitle: l10n.tryAgain,
                    )
                  : FutureBuilder<List<ChildProfile>>(
                      future: _childrenFuture,
                      builder: (context, childrenSnapshot) {
                        if (childrenSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            childrenSnapshot.data == null) {
                          return const ParentDashboardSkeleton();
                        }

                        // Surface load failures explicitly so a connection
                        // problem doesn't masquerade as "no children yet".
                        // Guarded on data == null to preserve the local-first
                        // behavior: if we still have cached children, keep
                        // showing them even when a background refresh fails.
                        if (childrenSnapshot.hasError &&
                            childrenSnapshot.data == null) {
                          return AppErrorState.parent(
                            message: l10n.connectionError,
                            buttonLabel: l10n.tryAgain,
                            onRetry: _retryLoadChildren,
                          );
                        }

                        final children = childrenSnapshot.data ?? [];
                        final recentActivitiesFuture = children.isEmpty
                            ? Future<List<ProgressRecord>>.value(
                                const <ProgressRecord>[],
                              )
                            : _recentActivitiesForChildren(children);

                        return CustomScrollView(
                          slivers: [
                            ParentDashboardSliverAppBar(
                              greeting: _dashboardGreeting(l10n),
                            ),
                            SliverToBoxAdapter(
                              child: ParentDashboardContent(
                                children: children,
                                recentActivitiesFuture: recentActivitiesFuture,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
        ),
        floatingActionButton: _childrenFuture == null
            ? null
            : FutureBuilder<List<ChildProfile>>(
                future: _childrenFuture,
                builder: (context, snapshot) {
                  final hasChildren =
                      (snapshot.data ?? const <ChildProfile>[]).isNotEmpty;
                  if (!hasChildren) {
                    return const SizedBox.shrink();
                  }

                  return FloatingActionButton.extended(
                    onPressed: () {
                      context.go('/parent/child-management');
                    },
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addChild),
                  );
                },
              ),
      ),
    );
  }

  Future<List<ProgressRecord>> _getRecentActivitiesForAllChildren(
    List<ChildProfile> children,
  ) async {
    final progressRepository = ref.read(progressRepositoryProvider);
    final allRecords = await progressRepository.getProgressForChildren(
      children.map((child) => child.id),
    );

    allRecords.sort((a, b) => b.date.compareTo(a.date));
    return allRecords;
  }
}
