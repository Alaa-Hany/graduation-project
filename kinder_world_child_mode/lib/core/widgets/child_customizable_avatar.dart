import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/models/child_avatar_customization.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/child_avatar_customization_provider.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';

class ChildCustomizableAvatar extends ConsumerWidget {
  const ChildCustomizableAvatar({
    super.key,
    required this.child,
    this.radius = 24,
    this.backgroundColor,
  });

  final ChildProfile child;
  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customization = ref.watch(
      childAvatarCustomizationResolvedProvider(child.id),
    );
    return ChildAvatarFrame(
      child: child,
      customization: customization,
      radius: radius,
      backgroundColor: backgroundColor,
    );
  }
}

class ChildAvatarFrame extends StatelessWidget {
  const ChildAvatarFrame({
    super.key,
    required this.child,
    required this.customization,
    this.radius = 24,
    this.backgroundColor,
  });

  final ChildProfile child;
  final ChildAvatarCustomization customization;
  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final frameColor = ChildAvatarFrameCatalog.colorForId(
      customization.frameColorId,
    );
    final style =
        ChildAvatarFrameCatalog.styleForId(customization.frameStyleId);
    final outerSize = (radius * 2) + 20;
    final avatarPath = customization.avatarPath ?? child.avatarPath;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          _FrameBase(
            size: outerSize,
            frameColor: frameColor,
            styleId: style.id,
          ),
          if (style.id == ChildAvatarFrameCatalog.starsStyleId) ...[
            _AccentStar(top: -2, left: 10, color: frameColor),
            _AccentStar(top: 10, right: -2, color: frameColor),
            _AccentStar(bottom: 2, left: -2, color: frameColor),
          ],
          Padding(
            padding: const EdgeInsets.all(6),
            child: AvatarView(
              avatarId: child.avatar,
              avatarPath: avatarPath,
              radius: radius,
              backgroundColor: backgroundColor ?? Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameBase extends StatelessWidget {
  const _FrameBase({
    required this.size,
    required this.frameColor,
    required this.styleId,
  });

  final double size;
  final Color frameColor;
  final String styleId;

  @override
  Widget build(BuildContext context) {
    final glow = styleId == ChildAvatarFrameCatalog.glowStyleId;
    final shield = styleId == ChildAvatarFrameCatalog.shieldStyleId;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            frameColor.withValues(alpha: 0.95),
            frameColor.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: frameColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
        border: shield
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 3,
              )
            : null,
      ),
      child: shield
          ? Padding(
              padding: const EdgeInsets.all(5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: frameColor.withValues(alpha: 0.9),
                    width: 3,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _AccentStar extends StatelessWidget {
  const _AccentStar({
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.color,
  });

  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Icon(
        Icons.auto_awesome_rounded,
        size: 16,
        color: color,
      ),
    );
  }
}
