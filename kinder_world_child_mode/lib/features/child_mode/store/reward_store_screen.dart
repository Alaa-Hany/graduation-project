// lib/features/child_mode/store/reward_store_screen.dart
// Reward Store — cosmetic items purchasable with virtual coins (seeded from XP).
// Persistence: existing Hive 'gamification_data' box. No real money.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/providers/gamification_provider.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';

// ── MODEL ────────────────────────────────────────────────────────────────────

enum RewardType { avatar, frame, badge, sticker, theme }

extension RewardTypeLabel on RewardType {
  String get label {
    switch (this) {
      case RewardType.avatar:  return 'Avatar';
      case RewardType.frame:   return 'Frame';
      case RewardType.badge:   return 'Badge';
      case RewardType.sticker: return 'Sticker';
      case RewardType.theme:   return 'Theme';
    }
  }
  String get typeEmoji {
    switch (this) {
      case RewardType.avatar:  return '🧑';
      case RewardType.frame:   return '🖼️';
      case RewardType.badge:   return '🏅';
      case RewardType.sticker: return '🎨';
      case RewardType.theme:   return '🎭';
    }
  }
}

class RewardItem {
  final String id;
  final String name;
  final RewardType type;
  final int price;
  final String emoji;
  final Color color;
  const RewardItem({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.emoji,
    required this.color,
  });
}

// ── CATALOG (public — also read by child_profile_screen) ─────────────────────

const List<RewardItem> rewardCatalog = [
  RewardItem(id: 'av_robot',     name: 'Robot',     type: RewardType.avatar,  price: 50,  emoji: '🤖', color: Color(0xFF42A5F5)),
  RewardItem(id: 'av_unicorn',   name: 'Unicorn',   type: RewardType.avatar,  price: 80,  emoji: '🦄', color: Color(0xFFEC407A)),
  RewardItem(id: 'av_astronaut', name: 'Astronaut', type: RewardType.avatar,  price: 100, emoji: '🧑‍🚀', color: Color(0xFF7E57C2)),
  RewardItem(id: 'av_dragon',    name: 'Dragon',    type: RewardType.avatar,  price: 120, emoji: '🐉', color: Color(0xFFEF5350)),
  RewardItem(id: 'fr_rainbow',   name: 'Rainbow',   type: RewardType.frame,   price: 60,  emoji: '🌈', color: Color(0xFFFF7043)),
  RewardItem(id: 'fr_stars',     name: 'Stars',     type: RewardType.frame,   price: 70,  emoji: '⭐', color: Color(0xFFFFD700)),
  RewardItem(id: 'fr_flowers',   name: 'Flowers',   type: RewardType.frame,   price: 55,  emoji: '🌸', color: Color(0xFFE91E63)),
  RewardItem(id: 'bd_champion',  name: 'Champion',  type: RewardType.badge,   price: 90,  emoji: '🏆', color: Color(0xFFFFB300)),
  RewardItem(id: 'bd_star',      name: 'Star',      type: RewardType.badge,   price: 40,  emoji: '🌟', color: Color(0xFFFDD835)),
  RewardItem(id: 'bd_rocket',    name: 'Rocket',    type: RewardType.badge,   price: 75,  emoji: '🚀', color: Color(0xFF26C6DA)),
  RewardItem(id: 'st_heart',     name: 'Heart',     type: RewardType.sticker, price: 30,  emoji: '❤️', color: Color(0xFFE53935)),
  RewardItem(id: 'st_fire',      name: 'Fire',      type: RewardType.sticker, price: 35,  emoji: '🔥', color: Color(0xFFFF6D00)),
  RewardItem(id: 'st_lightning', name: 'Lightning', type: RewardType.sticker, price: 35,  emoji: '⚡', color: Color(0xFFFFEA00)),
  RewardItem(id: 'st_diamond',   name: 'Diamond',   type: RewardType.sticker, price: 45,  emoji: '💎', color: Color(0xFF00BCD4)),
  RewardItem(id: 'th_ocean',     name: 'Ocean',     type: RewardType.theme,   price: 150, emoji: '🌊', color: Color(0xFF1565C0)),
  RewardItem(id: 'th_forest',    name: 'Forest',    type: RewardType.theme,   price: 150, emoji: '🌲', color: Color(0xFF2E7D32)),
  RewardItem(id: 'th_galaxy',    name: 'Galaxy',    type: RewardType.theme,   price: 200, emoji: '🌌', color: Color(0xFF4A148C)),
];

// ── STATE ────────────────────────────────────────────────────────────────────

class RewardStoreState {
  final int coins;
  final Set<String> ownedIds;
  final Map<RewardType, String> equippedByType;

  const RewardStoreState({
    required this.coins,
    required this.ownedIds,
    required this.equippedByType,
  });

  RewardStoreState copyWith({
    int? coins,
    Set<String>? ownedIds,
    Map<RewardType, String>? equippedByType,
  }) =>
      RewardStoreState(
        coins: coins ?? this.coins,
        ownedIds: ownedIds ?? this.ownedIds,
        equippedByType: equippedByType ?? this.equippedByType,
      );
}

// ── NOTIFIER ─────────────────────────────────────────────────────────────────

class RewardStoreNotifier extends StateNotifier<RewardStoreState> {
  final Box _box;
  final String _childId;
  final int _seedXp;

  RewardStoreNotifier(this._box, this._childId, this._seedXp)
      : super(const RewardStoreState(coins: 0, ownedIds: {}, equippedByType: {})) {
    _load();
  }

  String get _coinsKey    => 'store_coins_$_childId';
  String get _ownedKey    => 'store_owned_$_childId';
  String get _equippedKey => 'store_equipped_$_childId';
  // One-time seeding flag — prevents re-seeding on every app launch
  String get _seededKey   => 'store_seeded_$_childId';

  void _load() {
    // Seed coins from XP only once per child (first launch)
    final bool alreadySeeded = _box.get(_seededKey, defaultValue: false) as bool;
    final int coins;
    if (!alreadySeeded) {
      coins = _seedXp;
      _box.put(_coinsKey, coins);
      _box.put(_seededKey, true);
    } else {
      coins = _box.get(_coinsKey, defaultValue: 0) as int;
    }

    final String ownedRaw = _box.get(_ownedKey, defaultValue: '[]') as String;
    final Set<String> owned =
        (jsonDecode(ownedRaw) as List<dynamic>).cast<String>().toSet();

    final String equippedRaw = _box.get(_equippedKey, defaultValue: '{}') as String;
    final Map<String, dynamic> equippedMap =
        jsonDecode(equippedRaw) as Map<String, dynamic>;
    final Map<RewardType, String> equipped = {};
    equippedMap.forEach((k, v) {
      final type = RewardType.values.firstWhere(
        (t) => t.name == k,
        orElse: () => RewardType.avatar,
      );
      equipped[type] = v as String;
    });

    state = RewardStoreState(coins: coins, ownedIds: owned, equippedByType: equipped);
  }

  void _persist() {
    _box.put(_coinsKey, state.coins);
    _box.put(_ownedKey, jsonEncode(state.ownedIds.toList()));
    final Map<String, String> eq = {};
    state.equippedByType.forEach((k, v) => eq[k.name] = v);
    _box.put(_equippedKey, jsonEncode(eq));
  }

  /// Returns null on success, or an error message.
  String? purchase(RewardItem item) {
    if (state.ownedIds.contains(item.id)) return 'Already owned';
    if (state.coins < item.price) {
      return 'Need ${item.price} 🪙 — you have ${state.coins} 🪙';
    }
    state = state.copyWith(
      coins: state.coins - item.price,
      ownedIds: {...state.ownedIds, item.id},
    );
    _persist();
    return null;
  }

  void equip(RewardItem item) {
    if (!state.ownedIds.contains(item.id)) return;
    final eq = Map<RewardType, String>.from(state.equippedByType);
    eq[item.type] = item.id;
    state = state.copyWith(equippedByType: eq);
    _persist();
  }

  void unequip(RewardType type) {
    final eq = Map<RewardType, String>.from(state.equippedByType);
    eq.remove(type);
    state = state.copyWith(equippedByType: eq);
    _persist();
  }
}

// ── PROVIDER ─────────────────────────────────────────────────────────────────

final rewardStoreProvider =
    StateNotifierProvider.autoDispose<RewardStoreNotifier, RewardStoreState>(
  (ref) {
    final box = ref.watch(gamificationBoxProvider);
    final child = ref.watch(currentChildProvider);
    return RewardStoreNotifier(box, child?.id ?? 'guest', child?.xp ?? 100);
  },
);

// ── SCREEN ───────────────────────────────────────────────────────────────────

class RewardStoreScreen extends ConsumerStatefulWidget {
  const RewardStoreScreen({super.key});

  @override
  ConsumerState<RewardStoreScreen> createState() => _RewardStoreScreenState();
}

class _RewardStoreScreenState extends ConsumerState<RewardStoreScreen> {
  RewardType? _filter;

  @override
  Widget build(BuildContext context) {
    final storeState = ref.watch(rewardStoreProvider);
    final childTheme = context.childTheme;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // Use app's child accent color for consistency
    final storeColor = childTheme.streak;
    final onStoreColor = storeColor.onColor;

    final items = _filter == null
        ? rewardCatalog
        : rewardCatalog.where((i) => i.type == _filter).toList();

    final equippedItems = rewardCatalog
        .where((i) => storeState.equippedByType[i.type] == i.id)
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: storeColor,
        foregroundColor: onStoreColor,
        elevation: 0,
        title: Text(
          '🛍️ Reward Store',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: onStoreColor,
          ),
        ),
        actions: [
          // Coin balance — AnimatedSwitcher gives visual pop when coins change
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: onStoreColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: onStoreColor.withValues(alpha: 0.24)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🪙',
                    style: TextStyle(
                      fontSize: 16,
                      color: childTheme.xp,
                    )),
                const SizedBox(width: 5),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Text(
                    '${storeState.coins}',
                    key: ValueKey(storeState.coins),
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: onStoreColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Equipped strip
          if (equippedItems.isNotEmpty)
            _EquippedStrip(equippedItems: equippedItems, xpColor: childTheme.xp),

          // Filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _FilterChip(
                  label: 'All',
                  emoji: '✨',
                  selected: _filter == null,
                  selectedColor: storeColor,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final t in RewardType.values)
                  _FilterChip(
                    label: t.label,
                    emoji: t.typeEmoji,
                    selected: _filter == t,
                    selectedColor: storeColor,
                    onTap: () => setState(() => _filter = t),
                  ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.80,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final owned = storeState.ownedIds.contains(item.id);
                final equipped = storeState.equippedByType[item.type] == item.id;
                return _StoreItemCard(
                  item: item,
                  owned: owned,
                  equipped: equipped,
                  coins: storeState.coins,
                  onAction: () =>
                      _handleAction(item, owned, equipped, storeState.coins),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(RewardItem item, bool owned, bool equipped, int coins) {
    if (owned && equipped) {
      ref.read(rewardStoreProvider.notifier).unequip(item.type);
      _snack('${item.emoji} ${item.name} unequipped', success: false);
    } else if (owned) {
      ref.read(rewardStoreProvider.notifier).equip(item);
      _snack('${item.emoji} ${item.name} equipped! ✨');
    } else {
      showDialog(
        context: context,
        builder: (_) => _PurchaseDialog(
          item: item,
          coins: coins,
          onConfirm: () {
            Navigator.pop(context);
            final err = ref.read(rewardStoreProvider.notifier).purchase(item);
            if (err == null) {
              _snack('🎉 You got ${item.name}!');
            } else {
              _snack(err, success: false, isError: true);
            }
          },
        ),
      );
    }
  }

  void _snack(String msg, {bool success = true, bool isError = false}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final childTheme = context.childTheme;
    final bg = isError
        ? theme.colorScheme.error
        : success
            ? childTheme.success
            : theme.colorScheme.inverseSurface;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: bg.onColor,
          ),
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 2200),
      ),
    );
  }
}

// ── PRIVATE WIDGETS ───────────────────────────────────────────────────────────

class _EquippedStrip extends StatelessWidget {
  const _EquippedStrip({required this.equippedItems, required this.xpColor});
  final List<RewardItem> equippedItems;
  final Color xpColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      color: xpColor.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('✨ Equipped:',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: colors.onSurface,
              )),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: equippedItems
                    .map((i) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: i.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: i.color, width: 1.5),
                            ),
                            child: Text(
                              '${i.emoji} ${i.name}',
                              style: textTheme.labelMedium?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: i.color,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });
  final String label;
  final String emoji;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? selectedColor : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: 0.4)
                : colors.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          '$emoji $label',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? selectedColor.onColor : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _StoreItemCard extends StatelessWidget {
  const _StoreItemCard({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.coins,
    required this.onAction,
  });
  final RewardItem item;
  final bool owned;
  final bool equipped;
  final int coins;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final successColor = context.successColor;
    final canAfford = coins >= item.price;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: equipped
            ? item.color.withValues(alpha: 0.15)
            : owned
                ? successColor.withValues(alpha: 0.10)
                : colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: equipped
              ? item.color
              : owned
                  ? successColor.withValues(alpha: 0.45)
                  : colors.outlineVariant.withValues(alpha: 0.45),
          width: equipped ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.type.label,
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: item.color,
                  ),
                ),
              ),
            ),
            Text(item.emoji, style: const TextStyle(fontSize: 48)),
            Text(
              item.name,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (!owned)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 3),
                  Text(
                    '${item.price}',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color:
                          canAfford ? context.childTheme.success : colors.error,
                    ),
                  ),
                ],
              )
            else
              Text(
                equipped ? '✨ Equipped' : '✅ Owned',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: equipped ? item.color : successColor,
                ),
              ),
            _ActionBtn(
              owned: owned,
              equipped: equipped,
              canAfford: canAfford,
              color: item.color,
              onTap: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.owned,
    required this.equipped,
    required this.canAfford,
    required this.color,
    required this.onTap,
  });
  final bool owned;
  final bool equipped;
  final bool canAfford;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;
    final Color fg;
    final colors = Theme.of(context).colorScheme;
    if (owned && equipped) {
      label = 'Unequip';
      bg = colors.outlineVariant;
      fg = colors.onSurface;
    } else if (owned) {
      label = 'Equip ✨';
      bg = color;
      fg = color.onColor;
    } else if (canAfford) {
      label = 'Buy 🛒';
      bg = color;
      fg = color.onColor;
    } else {
      label = 'Need more 🪙';
      bg = colors.surfaceContainerHighest;
      fg = colors.onSurfaceVariant;
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (owned || canAfford) ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
        ),
        child: Text(label),
      ),
    );
  }
}

// ── PURCHASE DIALOG ───────────────────────────────────────────────────────────

class _PurchaseDialog extends StatelessWidget {
  const _PurchaseDialog({
    required this.item,
    required this.coins,
    required this.onConfirm,
  });
  final RewardItem item;
  final int coins;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canAfford = coins >= item.price;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        canAfford ? 'Buy ${item.name}?' : 'Not Enough Coins 😢',
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          if (canAfford) ...[
            Text('Cost: 🪙 ${item.price}',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                )),
            const SizedBox(height: 4),
            Text('You have: 🪙 $coins',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                )),
            const SizedBox(height: 4),
            Text('After purchase: 🪙 ${coins - item.price}',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                )),
          ] else ...[
            Text(
              'You need 🪙 ${item.price} but only have 🪙 $coins.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Keep learning to earn more coins! 🌟',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (canAfford)
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: item.color,
              foregroundColor: item.color.onColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Buy! 🎉',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }
}
