import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/core/widgets/picture_password_row.dart';
import 'package:kinder_world/router.dart';

class ParentChildProfileScreen extends ConsumerStatefulWidget {
  const ParentChildProfileScreen({
    super.key,
    required this.childId,
    this.initialChild,
  });

  final String childId;
  final ChildProfile? initialChild;

  @override
  ConsumerState<ParentChildProfileScreen> createState() =>
      _ParentChildProfileScreenState();
}

class _ParentChildProfileScreenState
    extends ConsumerState<ParentChildProfileScreen> {
  static const Map<String, String> _avatarAssets = {
    'avatar_1': 'assets/images/avatars/boy1.png',
    'avatar_2': 'assets/images/avatars/boy2.png',
    'avatar_3': 'assets/images/avatars/boy3.png',
    'avatar_4': 'assets/images/avatars/boy4.png',
    'avatar_5': 'assets/images/avatars/girl1.png',
    'avatar_6': 'assets/images/avatars/girl2.png',
    'avatar_7': 'assets/images/avatars/girl3.png',
    'avatar_8': 'assets/images/avatars/girl4.png',
    'avatar_9': 'assets/images/avatars/av1.png',
    'avatar_10': 'assets/images/avatars/av2.png',
    'avatar_11': 'assets/images/avatars/av3.png',
    'avatar_12': 'assets/images/avatars/av4.png',
    'avatar_13': 'assets/images/avatars/av5.png',
    'avatar_14': 'assets/images/avatars/av6.png',
  };

  ChildProfile? _child;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _child = widget.initialChild;
    if (_child == null) {
      _loadChild();
    }
  }

  @override
  void didUpdateWidget(covariant ParentChildProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initialChildChanged =
        oldWidget.initialChild?.id != widget.initialChild?.id ||
            oldWidget.initialChild?.updatedAt != widget.initialChild?.updatedAt;
    if (oldWidget.childId != widget.childId || initialChildChanged) {
      _child = widget.initialChild;
      _error = null;
      if (_child == null) {
        _loadChild();
      }
    }
  }

  Future<void> _loadChild() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final child = await ref
          .read(childRepositoryProvider)
          .getChildProfile(widget.childId);
      if (!mounted) return;
      setState(() {
        _child = child;
        _loading = false;
        _error = child == null
            ? AppLocalizations.of(context)!.childProfileNotFound
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!.childProfileNotFound;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final child = _child;

    if (child == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: AppBackButton(
            fallback: Routes.parentChildManagement,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          title: Text(l10n.childProfiles),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.child_care_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error ?? l10n.childProfileNotFound,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadChild,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(l10n.retry),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final parent = context.parentTheme;
    final childTheme = context.childTheme;
    final avatarAccent = Color.lerp(parent.primary, parent.info, 0.35)!;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: AppBackButton(
          fallback: Routes.parentChildManagement,
          color: colors.onSurface,
        ),
        title: Text(
          child.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ParentCard(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                parent.primary,
                                avatarAccent,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: AvatarView(
                                avatarId: child.avatar,
                                avatarPath: _avatarAssets[child.avatar] ??
                                    child.avatarPath,
                                radius: 46,
                                backgroundColor:
                                    parent.primary.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                parent.primary,
                                avatarAccent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                          child: Text(
                            l10n.levelBadge(child.level),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: colors.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      child.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      child.age > 0
                          ? '${l10n.yearsOld(child.age)} • ${l10n.level} ${child.level}'
                          : '${l10n.notAvailable} • ${l10n.level} ${child.level}',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PicturePasswordRow(
                      picturePassword: child.picturePassword,
                      size: 18,
                      showPlaceholders: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ParentStatCard(
                      value: '${child.activitiesCompleted}',
                      label: l10n.activities,
                      icon: Icons.check_circle_rounded,
                      color: parent.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ParentStatCard(
                      value: '${child.totalTimeSpent}m',
                      label: l10n.timeSpent,
                      icon: Icons.timer_rounded,
                      color: parent.info,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ParentStatCard(
                      value: '${child.streak}',
                      label: l10n.dailyStreak,
                      icon: Icons.local_fire_department_rounded,
                      color: parent.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ParentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ParentSectionHeader(title: l10n.xpProgress),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.xpValue(child.xp % 1000),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: childTheme.xp,
                          ),
                        ),
                        Text(
                          l10n.xpToNextLevel(1000 - (child.xp % 1000)),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: child.xpProgress.clamp(0.0, 1.0),
                        backgroundColor: colors.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          childTheme.xp,
                        ),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (child.interests.isNotEmpty) ...[
                const SizedBox(height: 16),
                ParentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ParentSectionHeader(title: l10n.childInterests),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: child.interests
                            .map(
                              (interest) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: parent.primary
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  interest,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: parent.primary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push('/parent/reports', extra: child.id),
                  icon: const Icon(Icons.bar_chart_rounded, size: 20),
                  label: Text(l10n.activityReports),
                  style: FilledButton.styleFrom(
                    backgroundColor: parent.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
