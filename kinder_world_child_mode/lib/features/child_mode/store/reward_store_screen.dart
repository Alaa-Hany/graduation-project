import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/gamification_provider.dart';
import 'package:kinder_world/core/providers/parent_pin_provider.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';

enum RewardType { avatar, frame, badge, sticker, theme }

extension RewardTypeLabel on RewardType {
  String label(AppLocalizations l10n) {
    switch (this) {
      case RewardType.avatar:
        return l10n.rewardTypeAvatar;
      case RewardType.frame:
        return l10n.rewardTypeFrame;
      case RewardType.badge:
        return l10n.rewardTypeBadge;
      case RewardType.sticker:
        return l10n.rewardTypeSticker;
      case RewardType.theme:
        return l10n.rewardTypeTheme;
    }
  }

  String get typeEmoji {
    switch (this) {
      case RewardType.avatar:
        return '\u{1F464}';
      case RewardType.frame:
        return '\u{1F5BC}\u{FE0F}';
      case RewardType.badge:
        return '\u{1F3C5}';
      case RewardType.sticker:
        return '\u{1F3A8}';
      case RewardType.theme:
        return '\u{1F3A8}';
    }
  }
}

class RewardItem {
  const RewardItem({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.emoji,
    required this.color,
  });

  final String id;
  final String name;
  final RewardType type;
  final int price;
  final String emoji;
  final Color color;
}

const List<RewardItem> rewardCatalog = [
  RewardItem(
      id: 'av_robot',
      name: 'Robot',
      type: RewardType.avatar,
      price: 50,
      emoji: '\u{1F916}',
      color: Color(0xFF42A5F5)),
  RewardItem(
      id: 'av_unicorn',
      name: 'Unicorn',
      type: RewardType.avatar,
      price: 80,
      emoji: '\u{1F984}',
      color: Color(0xFFEC407A)),
  RewardItem(
      id: 'av_astronaut',
      name: 'Astronaut',
      type: RewardType.avatar,
      price: 100,
      emoji: '\u{1F9D1}\u{200D}\u{1F680}',
      color: Color(0xFF7E57C2)),
  RewardItem(
      id: 'av_dragon',
      name: 'Dragon',
      type: RewardType.avatar,
      price: 120,
      emoji: '\u{1F409}',
      color: Color(0xFFEF5350)),
  RewardItem(
      id: 'fr_rainbow',
      name: 'Rainbow',
      type: RewardType.frame,
      price: 60,
      emoji: '\u{1F308}',
      color: Color(0xFFFF7043)),
  RewardItem(
      id: 'fr_stars',
      name: 'Stars',
      type: RewardType.frame,
      price: 70,
      emoji: '\u{2B50}',
      color: Color(0xFFFFD700)),
  RewardItem(
      id: 'fr_flowers',
      name: 'Flowers',
      type: RewardType.frame,
      price: 55,
      emoji: '\u{1F338}',
      color: Color(0xFFE91E63)),
  RewardItem(
      id: 'bd_champion',
      name: 'Champion',
      type: RewardType.badge,
      price: 90,
      emoji: '\u{1F3C6}',
      color: Color(0xFFFFB300)),
  RewardItem(
      id: 'bd_star',
      name: 'Star',
      type: RewardType.badge,
      price: 40,
      emoji: '\u{1F31F}',
      color: Color(0xFFFDD835)),
  RewardItem(
      id: 'bd_rocket',
      name: 'Rocket',
      type: RewardType.badge,
      price: 75,
      emoji: '\u{1F680}',
      color: Color(0xFF26C6DA)),
  RewardItem(
      id: 'st_heart',
      name: 'Heart',
      type: RewardType.sticker,
      price: 30,
      emoji: '\u{2764}\u{FE0F}',
      color: Color(0xFFE53935)),
  RewardItem(
      id: 'st_fire',
      name: 'Fire',
      type: RewardType.sticker,
      price: 35,
      emoji: '\u{1F525}',
      color: Color(0xFFFF6D00)),
  RewardItem(
      id: 'st_lightning',
      name: 'Lightning',
      type: RewardType.sticker,
      price: 35,
      emoji: '\u{26A1}',
      color: Color(0xFFFFEA00)),
  RewardItem(
      id: 'st_diamond',
      name: 'Diamond',
      type: RewardType.sticker,
      price: 45,
      emoji: '\u{1F48E}',
      color: Color(0xFF00BCD4)),
  RewardItem(
      id: 'th_ocean',
      name: 'Ocean',
      type: RewardType.theme,
      price: 150,
      emoji: '\u{1F30A}',
      color: Color(0xFF1565C0)),
  RewardItem(
      id: 'th_forest',
      name: 'Forest',
      type: RewardType.theme,
      price: 150,
      emoji: '\u{1F332}',
      color: Color(0xFF2E7D32)),
  RewardItem(
      id: 'th_galaxy',
      name: 'Galaxy',
      type: RewardType.theme,
      price: 200,
      emoji: '\u{1F30C}',
      color: Color(0xFF4A148C)),
];

enum RewardRequestStatus { pending, approved, rejected }

class RewardRedemptionRequest {
  const RewardRedemptionRequest({
    required this.id,
    required this.childId,
    required this.itemId,
    required this.status,
    required this.requiresParentApproval,
    required this.requestedAt,
    this.resolvedAt,
  });

  final String id;
  final String childId;
  final String itemId;
  final RewardRequestStatus status;
  final bool requiresParentApproval;
  final DateTime requestedAt;
  final DateTime? resolvedAt;

  RewardRedemptionRequest copyWith({
    RewardRequestStatus? status,
    DateTime? resolvedAt,
  }) {
    return RewardRedemptionRequest(
      id: id,
      childId: childId,
      itemId: itemId,
      status: status ?? this.status,
      requiresParentApproval: requiresParentApproval,
      requestedAt: requestedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'child_id': childId,
        'item_id': itemId,
        'status': status.name,
        'requires_parent_approval': requiresParentApproval,
        'requested_at': requestedAt.toIso8601String(),
        'resolved_at': resolvedAt?.toIso8601String(),
      };

  factory RewardRedemptionRequest.fromJson(Map<String, dynamic> json) {
    return RewardRedemptionRequest(
      id: json['id']?.toString() ?? '',
      childId: json['child_id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      status: RewardRequestStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => RewardRequestStatus.pending,
      ),
      requiresParentApproval: json['requires_parent_approval'] == true,
      requestedAt: DateTime.tryParse(json['requested_at']?.toString() ?? '') ??
          DateTime.now(),
      resolvedAt: DateTime.tryParse(json['resolved_at']?.toString() ?? ''),
    );
  }
}

class RewardStoreState {
  const RewardStoreState({
    required this.coins,
    required this.ownedIds,
    required this.equippedByType,
    required this.pendingRequests,
    required this.redemptionHistory,
  });

  final int coins;
  final Set<String> ownedIds;
  final Map<RewardType, String> equippedByType;
  final List<RewardRedemptionRequest> pendingRequests;
  final List<RewardRedemptionRequest> redemptionHistory;

  RewardStoreState copyWith({
    int? coins,
    Set<String>? ownedIds,
    Map<RewardType, String>? equippedByType,
    List<RewardRedemptionRequest>? pendingRequests,
    List<RewardRedemptionRequest>? redemptionHistory,
  }) {
    return RewardStoreState(
      coins: coins ?? this.coins,
      ownedIds: ownedIds ?? this.ownedIds,
      equippedByType: equippedByType ?? this.equippedByType,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      redemptionHistory: redemptionHistory ?? this.redemptionHistory,
    );
  }
}

enum RewardRedeemOutcome { purchased, pendingApproval, failed }

enum RewardRedeemMessage {
  alreadyOwned,
  alreadyPending,
  requestSent,
  needMoreCoins,
  rewardRedeemed,
  requestNotFound,
  itemMissing,
  notEnoughCoinsApproval,
  itemApproved,
  requestRejected,
}

class RewardRedeemResult {
  const RewardRedeemResult({
    required this.outcome,
    required this.message,
    this.itemId,
    this.price,
    this.currentCoins,
  });

  final RewardRedeemOutcome outcome;
  final RewardRedeemMessage message;
  final String? itemId;
  final int? price;
  final int? currentCoins;
}

class RewardStoreNotifier extends StateNotifier<RewardStoreState> {
  RewardStoreNotifier(this._box, this._childId, this._coinFloor)
      : super(const RewardStoreState(
          coins: 0,
          ownedIds: {},
          equippedByType: {},
          pendingRequests: [],
          redemptionHistory: [],
        )) {
    _load();
  }

  final Box _box;
  final String _childId;
  final int _coinFloor;

  String get _coinsKey => 'store_coins_$_childId';
  String get _ownedKey => 'store_owned_$_childId';
  String get _equippedKey => 'store_equipped_$_childId';
  String get _seededKey => 'store_seeded_$_childId';
  String get _pendingRequestsKey => 'store_pending_requests_$_childId';
  String get _historyRequestsKey => 'store_history_requests_$_childId';

  void _load() {
    final alreadySeeded = _box.get(_seededKey, defaultValue: false) == true;
    int coins;
    if (!alreadySeeded) {
      coins = _coinFloor;
      _box.put(_coinsKey, coins);
      _box.put(_seededKey, true);
    } else {
      coins = _box.get(_coinsKey, defaultValue: _coinFloor) as int;
      if (coins < _coinFloor) {
        coins = _coinFloor;
        _box.put(_coinsKey, coins);
      }
    }

    final ownedRaw = _box.get(_ownedKey, defaultValue: '[]') as String;
    final owned = (jsonDecode(ownedRaw) as List<dynamic>)
        .map((value) => value.toString())
        .toSet();

    final equippedRaw = _box.get(_equippedKey, defaultValue: '{}') as String;
    final equippedMap = jsonDecode(equippedRaw) as Map<String, dynamic>;
    final equipped = <RewardType, String>{};
    equippedMap.forEach((key, value) {
      final type = RewardType.values.firstWhere(
        (item) => item.name == key,
        orElse: () => RewardType.avatar,
      );
      equipped[type] = value.toString();
    });

    final pendingRaw =
        _box.get(_pendingRequestsKey, defaultValue: '[]') as String;
    final pending = (jsonDecode(pendingRaw) as List<dynamic>)
        .map((value) => RewardRedemptionRequest.fromJson(
            Map<String, dynamic>.from(value as Map)))
        .where((request) => request.status == RewardRequestStatus.pending)
        .toList();

    final historyRaw =
        _box.get(_historyRequestsKey, defaultValue: '[]') as String;
    final history = (jsonDecode(historyRaw) as List<dynamic>)
        .map((value) => RewardRedemptionRequest.fromJson(
            Map<String, dynamic>.from(value as Map)))
        .toList();

    state = RewardStoreState(
      coins: coins,
      ownedIds: owned,
      equippedByType: equipped,
      pendingRequests: pending,
      redemptionHistory: history,
    );
  }

  void _persist() {
    _box.put(_coinsKey, state.coins);
    _box.put(_ownedKey, jsonEncode(state.ownedIds.toList()));

    final equipped = <String, String>{};
    state.equippedByType.forEach((key, value) {
      equipped[key.name] = value;
    });
    _box.put(_equippedKey, jsonEncode(equipped));

    _box.put(
      _pendingRequestsKey,
      jsonEncode(
          state.pendingRequests.map((request) => request.toJson()).toList()),
    );
    _box.put(
      _historyRequestsKey,
      jsonEncode(
          state.redemptionHistory.map((request) => request.toJson()).toList()),
    );
  }

  void syncCoinFloor(int floor) {
    if (floor > state.coins) {
      state = state.copyWith(coins: floor);
      _persist();
    }
  }

  bool requiresParentApproval(RewardItem item) {
    return item.type == RewardType.theme ||
        item.type == RewardType.avatar ||
        item.price >= 100;
  }

  bool hasPendingRequestForItem(String itemId) {
    return state.pendingRequests.any((request) => request.itemId == itemId);
  }

  RewardRedeemResult redeem(RewardItem item) {
    if (state.ownedIds.contains(item.id)) {
      return const RewardRedeemResult(
        outcome: RewardRedeemOutcome.failed,
        message: RewardRedeemMessage.alreadyOwned,
      );
    }
    if (hasPendingRequestForItem(item.id)) {
      return const RewardRedeemResult(
        outcome: RewardRedeemOutcome.failed,
        message: RewardRedeemMessage.alreadyPending,
      );
    }

    if (requiresParentApproval(item)) {
      final request = RewardRedemptionRequest(
        id: '${DateTime.now().microsecondsSinceEpoch}_${item.id}',
        childId: _childId,
        itemId: item.id,
        status: RewardRequestStatus.pending,
        requiresParentApproval: true,
        requestedAt: DateTime.now(),
      );
      state =
          state.copyWith(pendingRequests: [...state.pendingRequests, request]);
      _persist();
      return const RewardRedeemResult(
        outcome: RewardRedeemOutcome.pendingApproval,
        message: RewardRedeemMessage.requestSent,
      );
    }

    if (state.coins < item.price) {
      return RewardRedeemResult(
        outcome: RewardRedeemOutcome.failed,
        message: RewardRedeemMessage.needMoreCoins,
        price: item.price,
        currentCoins: state.coins,
      );
    }

    final completedRequest = RewardRedemptionRequest(
      id: '${DateTime.now().microsecondsSinceEpoch}_${item.id}',
      childId: _childId,
      itemId: item.id,
      status: RewardRequestStatus.approved,
      requiresParentApproval: false,
      requestedAt: DateTime.now(),
      resolvedAt: DateTime.now(),
    );

    state = state.copyWith(
      coins: state.coins - item.price,
      ownedIds: {...state.ownedIds, item.id},
      redemptionHistory: [...state.redemptionHistory, completedRequest],
    );
    _persist();
    return const RewardRedeemResult(
      outcome: RewardRedeemOutcome.purchased,
      message: RewardRedeemMessage.rewardRedeemed,
    );
  }

  RewardRedeemResult approveRequest(String requestId) {
    final request =
        state.pendingRequests.where((row) => row.id == requestId).firstOrNull;
    if (request == null) {
      return const RewardRedeemResult(
        outcome: RewardRedeemOutcome.failed,
        message: RewardRedeemMessage.requestNotFound,
      );
    }

    final item =
        rewardCatalog.where((row) => row.id == request.itemId).firstOrNull;
    if (item == null) {
      return const RewardRedeemResult(
        outcome: RewardRedeemOutcome.failed,
        message: RewardRedeemMessage.itemMissing,
      );
    }

    if (state.coins < item.price) {
      return const RewardRedeemResult(
        outcome: RewardRedeemOutcome.failed,
        message: RewardRedeemMessage.notEnoughCoinsApproval,
      );
    }

    final pending = [...state.pendingRequests]
      ..removeWhere((row) => row.id == requestId);
    final approved = request.copyWith(
      status: RewardRequestStatus.approved,
      resolvedAt: DateTime.now(),
    );

    state = state.copyWith(
      coins: state.coins - item.price,
      ownedIds: {...state.ownedIds, item.id},
      pendingRequests: pending,
      redemptionHistory: [...state.redemptionHistory, approved],
    );
    _persist();
    return RewardRedeemResult(
      outcome: RewardRedeemOutcome.purchased,
      message: RewardRedeemMessage.itemApproved,
      itemId: item.id,
    );
  }

  RewardRedeemResult rejectRequest(String requestId) {
    final request =
        state.pendingRequests.where((row) => row.id == requestId).firstOrNull;
    if (request == null) {
      return const RewardRedeemResult(
        outcome: RewardRedeemOutcome.failed,
        message: RewardRedeemMessage.requestNotFound,
      );
    }

    final pending = [...state.pendingRequests]
      ..removeWhere((row) => row.id == requestId);
    final rejected = request.copyWith(
      status: RewardRequestStatus.rejected,
      resolvedAt: DateTime.now(),
    );

    state = state.copyWith(
      pendingRequests: pending,
      redemptionHistory: [...state.redemptionHistory, rejected],
    );
    _persist();
    return const RewardRedeemResult(
      outcome: RewardRedeemOutcome.purchased,
      message: RewardRedeemMessage.requestRejected,
    );
  }

  void equip(RewardItem item) {
    if (!state.ownedIds.contains(item.id)) return;
    final equipped = Map<RewardType, String>.from(state.equippedByType);
    equipped[item.type] = item.id;
    state = state.copyWith(equippedByType: equipped);
    _persist();
  }

  void unequip(RewardType type) {
    final equipped = Map<RewardType, String>.from(state.equippedByType);
    equipped.remove(type);
    state = state.copyWith(equippedByType: equipped);
    _persist();
  }
}

final rewardStoreProvider =
    StateNotifierProvider.autoDispose<RewardStoreNotifier, RewardStoreState>(
        (ref) {
  final box = ref.watch(gamificationBoxProvider);
  final child = ref.watch(currentChildProvider);
  final gamification = ref.watch(currentGamificationStateProvider);

  final baselineCoins = (() {
    if (gamification != null) {
      return (gamification.totalXP / 2).floor() +
          (gamification.earnedBadges.length * 25) +
          (gamification.streak * 2);
    }
    return ((child?.xp ?? 100) / 2).floor();
  })();

  return RewardStoreNotifier(
    box,
    child?.id ?? 'guest',
    baselineCoins,
  );
});

class RewardStoreScreen extends ConsumerStatefulWidget {
  const RewardStoreScreen({super.key});

  @override
  ConsumerState<RewardStoreScreen> createState() => _RewardStoreScreenState();
}

class _RewardStoreScreenState extends ConsumerState<RewardStoreScreen> {
  RewardType? _filter;
  bool _approvalUnlocked = false;

  @override
  Widget build(BuildContext context) {
    final storeState = ref.watch(rewardStoreProvider);
    final l10n = AppLocalizations.of(context)!;
    final childTheme = context.childTheme;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final storeColor = childTheme.streak;
    final onStoreColor = storeColor.onColor;

    final items = _filter == null
        ? rewardCatalog
        : rewardCatalog.where((item) => item.type == _filter).toList();

    final equippedItems = rewardCatalog
        .where((item) => storeState.equippedByType[item.type] == item.id)
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: storeColor,
        foregroundColor: onStoreColor,
        elevation: 0,
        title: Text(
          l10n.rewardStoreTitle,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: onStoreColor,
          ),
        ),
        actions: [
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
                Text(l10n.rewardStoreCoinsLabel,
                    style: TextStyle(fontSize: 16, color: childTheme.xp)),
                const SizedBox(width: 5),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
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
          if (equippedItems.isNotEmpty)
            _EquippedStrip(
                equippedItems: equippedItems, xpColor: childTheme.xp),
          if (storeState.pendingRequests.isNotEmpty)
            _PendingApprovalsCard(
              requests: storeState.pendingRequests,
              unlocked: _approvalUnlocked,
              onUnlock: _unlockParentApproval,
              onApprove: (request) {
                final result = ref
                    .read(rewardStoreProvider.notifier)
                    .approveRequest(request.id);
                _snack(_resolveResultMessage(result),
                    success: result.outcome != RewardRedeemOutcome.failed);
              },
              onReject: (request) {
                final result = ref
                    .read(rewardStoreProvider.notifier)
                    .rejectRequest(request.id);
                _snack(_resolveResultMessage(result), success: true);
              },
            ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _FilterChip(
                  label: l10n.rewardStoreFilterAll,
                  emoji: '?',
                  selected: _filter == null,
                  selectedColor: storeColor,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final type in RewardType.values)
                  _FilterChip(
                    label: type.label(l10n),
                    emoji: type.typeEmoji,
                    selected: _filter == type,
                    selectedColor: storeColor,
                    onTap: () => setState(() => _filter = type),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final owned = storeState.ownedIds.contains(item.id);
                final equipped =
                    storeState.equippedByType[item.type] == item.id;
                final pending = storeState.pendingRequests
                    .any((row) => row.itemId == item.id);
                final needsApproval = ref
                    .read(rewardStoreProvider.notifier)
                    .requiresParentApproval(item);
                return _StoreItemCard(
                  item: item,
                  owned: owned,
                  equipped: equipped,
                  pendingApproval: pending,
                  needsApproval: needsApproval,
                  coins: storeState.coins,
                  onAction: () => _handleAction(item, owned, equipped, pending),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockParentApproval() async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(parentPinProvider.notifier).refreshStatus();
    if (!mounted) {
      return;
    }
    final pinState = ref.read(parentPinProvider);
    if (!pinState.hasPin) {
      _snack(l10n.rewardStoreParentPinMissing, success: false);
      return;
    }

    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.rewardStoreParentApprovalTitle),
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: l10n.rewardStoreParentPinLabel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.rewardStoreVerifyAction),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    final verified = await ref
        .read(parentPinProvider.notifier)
        .verifyPin(controller.text.trim());
    if (!mounted) return;
    if (verified) {
      setState(() => _approvalUnlocked = true);
      _snack(l10n.rewardStoreParentVerificationSuccess);
    } else {
      _snack(l10n.rewardStoreInvalidPin, success: false);
    }
  }

  void _handleAction(RewardItem item, bool owned, bool equipped, bool pending) {
    final l10n = AppLocalizations.of(context)!;
    if (pending) {
      _snack(l10n.rewardStoreWaitingForParentApproval, success: false);
      return;
    }
    if (owned && equipped) {
      ref.read(rewardStoreProvider.notifier).unequip(item.type);
      _snack(
        l10n.rewardStoreItemUnequipped(l10n.rewardItemName(item.id)),
        success: false,
      );
      return;
    }
    if (owned) {
      ref.read(rewardStoreProvider.notifier).equip(item);
      _snack(l10n.rewardStoreItemEquipped(l10n.rewardItemName(item.id)));
      return;
    }

    final result = ref.read(rewardStoreProvider.notifier).redeem(item);
    switch (result.outcome) {
      case RewardRedeemOutcome.purchased:
        _snack(_resolveResultMessage(result));
        break;
      case RewardRedeemOutcome.pendingApproval:
        _snack(_resolveResultMessage(result));
        break;
      case RewardRedeemOutcome.failed:
        _snack(_resolveResultMessage(result), success: false);
        break;
    }
  }

  String _resolveResultMessage(RewardRedeemResult result) {
    final l10n = AppLocalizations.of(context)!;
    switch (result.message) {
      case RewardRedeemMessage.alreadyOwned:
        return l10n.rewardStoreAlreadyOwned;
      case RewardRedeemMessage.alreadyPending:
        return l10n.rewardStoreAlreadyPending;
      case RewardRedeemMessage.requestSent:
        return l10n.rewardStoreRequestSent;
      case RewardRedeemMessage.needMoreCoins:
        return l10n.rewardStoreNeedMoreCoinsMessage(
          result.price ?? 0,
          result.currentCoins ?? 0,
        );
      case RewardRedeemMessage.rewardRedeemed:
        return l10n.rewardStoreRewardRedeemed;
      case RewardRedeemMessage.requestNotFound:
        return l10n.rewardStoreRequestNotFound;
      case RewardRedeemMessage.itemMissing:
        return l10n.rewardStoreItemMissing;
      case RewardRedeemMessage.notEnoughCoinsApproval:
        return l10n.rewardStoreNotEnoughCoinsApproval;
      case RewardRedeemMessage.itemApproved:
        return l10n.rewardStoreItemApproved(
          l10n.rewardItemName(result.itemId ?? ''),
        );
      case RewardRedeemMessage.requestRejected:
        return l10n.rewardStoreRequestRejected;
    }
  }

  void _snack(String message, {bool success = true}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final background =
        success ? context.childTheme.success : theme.colorScheme.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: background.onColor,
          ),
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _PendingApprovalsCard extends StatelessWidget {
  const _PendingApprovalsCard({
    required this.requests,
    required this.unlocked,
    required this.onUnlock,
    required this.onApprove,
    required this.onReject,
  });

  final List<RewardRedemptionRequest> requests;
  final bool unlocked;
  final VoidCallback onUnlock;
  final ValueChanged<RewardRedemptionRequest> onApprove;
  final ValueChanged<RewardRedemptionRequest> onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.rewardStorePendingApprovals(requests.length),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                if (!unlocked)
                  OutlinedButton(
                    onPressed: onUnlock,
                    child: Text(l10n.rewardStoreParentUnlock),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...requests.take(3).map((request) {
              final item = rewardCatalog
                  .where((reward) => reward.id == request.itemId)
                  .firstOrNull;
              if (item == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.rewardItemName(item.id),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(
                              l10n.rewardStoreRequestedAt(
                                DateFormat(
                                  'MMM d, h:mm a',
                                  Localizations.localeOf(context).toLanguageTag(),
                                ).format(request.requestedAt),
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (unlocked) ...[
                        TextButton(
                          onPressed: () => onReject(request),
                          child: Text(l10n.rewardStoreRejectAction),
                        ),
                        FilledButton(
                          onPressed: () => onApprove(request),
                          child: Text(l10n.rewardStoreApproveAction),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _EquippedStrip extends StatelessWidget {
  const _EquippedStrip({required this.equippedItems, required this.xpColor});

  final List<RewardItem> equippedItems;
  final Color xpColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: xpColor.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('${l10n.rewardStoreEquippedLabel}:',
              style: TextStyle(
                  color: colors.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: equippedItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${item.emoji} ${l10n.rewardItemName(item.id)}',
                          style: TextStyle(
                              color: item.color, fontWeight: FontWeight.w700)),
                    ),
                  );
                }).toList(),
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
        ),
        child: Text(
          '$emoji $label',
          style: TextStyle(
            color: selected ? selectedColor.onColor : colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 13,
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
    required this.pendingApproval,
    required this.needsApproval,
    required this.coins,
    required this.onAction,
  });

  final RewardItem item;
  final bool owned;
  final bool equipped;
  final bool pendingApproval;
  final bool needsApproval;
  final int coins;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final canAfford = coins >= item.price;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: equipped
              ? item.color
              : colors.outlineVariant.withValues(alpha: 0.5),
          width: equipped ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Text(item.type.typeEmoji),
          ),
          Text(item.emoji, style: const TextStyle(fontSize: 46)),
          Text(
            l10n.rewardItemName(item.id),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(l10n.rewardStorePriceCoins(item.price),
              style: TextStyle(
                  color:
                      canAfford ? context.childTheme.success : colors.error)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: pendingApproval ? null : onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: item.color,
                foregroundColor: item.color.onColor,
              ),
              child: Text(_actionLabel(context, canAfford)),
            ),
          ),
        ],
      ),
    );
  }

  String _actionLabel(BuildContext context, bool canAfford) {
    final l10n = AppLocalizations.of(context)!;
    if (pendingApproval) return l10n.rewardStorePendingAction;
    if (owned && equipped) return l10n.rewardStoreUnequipAction;
    if (owned) return l10n.rewardStoreEquipAction;
    if (needsApproval) return l10n.rewardStoreRequestParentAction;
    if (!canAfford) return l10n.rewardStoreNeedMoreCoinsAction;
    return l10n.rewardStoreRedeemAction;
  }
}
