import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/ai_buddy_models.dart';
import 'package:kinder_world/core/providers/ai_buddy_provider.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/services/ai_buddy_service.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/core/widgets/child_header.dart';

class _QuickAction {
  const _QuickAction({
    required this.title,
    required this.color,
    required this.icon,
    required this.action,
  });

  final String title;
  final Color color;
  final IconData icon;
  final String action;
}

class AiBuddyScreen extends ConsumerStatefulWidget {
  const AiBuddyScreen({super.key});

  @override
  ConsumerState<AiBuddyScreen> createState() => _AiBuddyScreenState();
}

class _AiBuddyScreenState extends ConsumerState<AiBuddyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseGlow;

  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  AiBuddyConversation? _conversation;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  String? _unavailable;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseGlow = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversation();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<_QuickAction> _getQuickActions(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = context.childTheme;
    return [
      _QuickAction(
        title: l10n.recommendLesson,
        color: theme.learning,
        icon: Icons.menu_book_rounded,
        action: 'recommend_lesson',
      ),
      _QuickAction(
        title: l10n.suggestGame,
        color: theme.skill,
        icon: Icons.games_rounded,
        action: 'suggest_game',
      ),
      _QuickAction(
        title: l10n.tellStory,
        color: theme.kindness,
        icon: Icons.auto_stories_rounded,
        action: 'tell_story',
      ),
      _QuickAction(
        title: l10n.funFact,
        color: theme.fun,
        icon: Icons.lightbulb_rounded,
        action: 'fun_fact',
      ),
      _QuickAction(
        title: l10n.motivation,
        color: theme.streak,
        icon: Icons.favorite_rounded,
        action: 'motivation',
      ),
    ];
  }

  Future<void> _loadConversation({bool forceNew = false}) async {
    final childId = int.tryParse(ref.read(currentChildIdProvider) ?? '');
    if (childId == null) {
      setState(() {
        _isLoading = false;
        _error = null;
        _unavailable = AppLocalizations.of(context)!.aiBuddyNoActiveChildSession;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _unavailable = null;
    });

    try {
      final service = ref.read(aiBuddyServiceProvider);
      final conversation = forceNew
          ? await service.startSession(childId: childId, forceNew: true)
          : await service.getOrStartCurrentSession(childId: childId);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _isLoading = false;
      });
      _scrollToBottom();
    } on AiBuddyUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _conversation = null;
        _isLoading = false;
        _unavailable = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conversation = null;
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _sendMessage({
    String? contentOverride,
    String? quickAction,
  }) async {
    if (_isSending) return;
    final childId = int.tryParse(ref.read(currentChildIdProvider) ?? '');
    if (childId == null) {
      setState(() {
        _unavailable = AppLocalizations.of(context)!.aiBuddyNoActiveChildSession;
      });
      return;
    }

    final content = (contentOverride ?? _textCtrl.text).trim();
    if (content.isEmpty) return;

    var session = _conversation?.session;
    if (session == null) {
      await _loadConversation();
      session = _conversation?.session;
      if (session == null) {
        return;
      }
    }

    if (contentOverride == null) {
      _textCtrl.clear();
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final result = await ref.read(aiBuddyServiceProvider).sendMessage(
            sessionId: session.id,
            childId: childId,
            content: content,
            quickAction: quickAction,
            clientMessageId:
                '${childId}_${DateTime.now().millisecondsSinceEpoch}',
          );
      if (!mounted) return;
      final existingMessages = List<AiBuddyMessage>.from(
        _conversation?.messages ?? const [],
      );
      existingMessages
        ..add(result.userMessage)
        ..add(result.assistantMessage);
      setState(() {
        _conversation = AiBuddyConversation(
          session: result.session,
          messages: existingMessages,
          provider: result.provider,
        );
        _isSending = false;
      });
      _scrollToBottom();
    } on AiBuddyUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _unavailable = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error = e.toString();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    return DateFormat('h:mm a').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colors, l10n),
            _buildQuickActions(context, colors, l10n),
            if (_conversation?.provider != null &&
                (!_conversation!.provider.configured ||
                    _conversation!.provider.status != 'ready'))
              _buildProviderBanner(colors, _conversation!.provider, l10n),
            const Divider(height: 1),
            Expanded(child: _buildBody(colors, l10n)),
            _buildInputBar(colors, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colors, AppLocalizations l10n) {
    final childTheme = context.childTheme;
    final textTheme = Theme.of(context).textTheme;
    final child = ref.watch(currentChildProvider);
    final provider = _conversation?.provider;
    final isFallback =
        provider != null && (!provider.configured || provider.status == 'fallback');
    final isUnavailable = provider != null && provider.status == 'unavailable';
    final statusText = provider == null
        ? l10n.aiBuddyOnline
        : isUnavailable
            ? l10n.aiBuddyStatusUnavailable
            : isFallback
                ? l10n.aiBuddyStatusFallbackOnly
                : l10n.aiBuddyOnline;
    final statusColor = isUnavailable
        ? colors.error
        : isFallback
            ? colors.tertiary
            : childTheme.success;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              ChildHeader(compact: true, padding: EdgeInsets.zero),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, childWidget) => Transform.scale(
                  scale: _pulseScale.value,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          childTheme.buddyStart,
                          childTheme.buddyEnd,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              childTheme.buddyStart.withValues(alpha: _pulseGlow.value),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.smart_toy_rounded, size: 30, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.aiBuddyName,
                          style: textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 7, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      child == null
                          ? (isFallback
                              ? l10n.aiBuddyFallbackSubtitle
                              : l10n.aiCompanionSubtitle)
                          : (isFallback
                              ? l10n.aiBuddyFallbackSubtitleFor(child.name)
                              : l10n.aiCompanionSubtitleWithName(child.name)),
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.quickActions,
            style: textTheme.labelLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    final actions = _getQuickActions(context, l10n);
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: actions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => InkWell(
            onTap: _isLoading || _isSending || _unavailable != null
                ? null
                : () => _sendMessage(
                      contentOverride: actions[i].title,
                      quickAction: actions[i].action,
                    ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 90,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: actions[i].color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: actions[i].color.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(actions[i].icon, color: actions[i].color, size: 24),
                  const SizedBox(height: 5),
                  Text(
                    actions[i].title,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: actions[i].color,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderBanner(
    ColorScheme colors,
    AiBuddyProviderStatus provider,
    AppLocalizations l10n,
  ) {
    final isFallback = !provider.configured || provider.status == 'fallback';
    final isUnavailable = provider.status == 'unavailable';
    final title = isUnavailable
        ? l10n.aiBuddyBannerUnavailableTitle
        : isFallback
            ? l10n.aiBuddyBannerFallbackTitle
            : l10n.aiBuddyBannerOnlineTitle;
    final description = provider.reason ??
        (isFallback
            ? l10n.aiBuddyBannerFallbackDescription
            : l10n.aiBuddyBannerOnlineDescription);
    final bannerColor = isUnavailable
        ? colors.errorContainer
        : colors.tertiaryContainer.withValues(alpha: 0.6);
    final bannerIconColor = isUnavailable ? colors.error : colors.tertiary;
    final bannerTextColor =
        isUnavailable ? colors.onErrorContainer : colors.onTertiaryContainer;

    return Container(
      width: double.infinity,
      color: bannerColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: bannerIconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title. $description',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: bannerTextColor,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colors, AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_unavailable != null) {
      return _StateCard(
        icon: Icons.cloud_off_rounded,
        title: l10n.aiBuddyUnavailableTitle,
        subtitle: _unavailable!,
        buttonLabel: l10n.retry,
        onPressed: _loadConversation,
      );
    }
    if (_error != null) {
      return _StateCard(
        icon: Icons.error_outline_rounded,
        title: l10n.error,
        subtitle: _error!,
        buttonLabel: l10n.retry,
        onPressed: _loadConversation,
      );
    }

    final conversation = _conversation;
    if (conversation == null || !conversation.hasSession) {
      return _StateCard(
        icon: Icons.chat_bubble_outline_rounded,
        title: l10n.aiBuddyNoConversationTitle,
        subtitle: l10n.aiBuddyNoConversationSubtitle,
        buttonLabel: l10n.aiBuddyStartSessionAction,
        onPressed: () => _loadConversation(forceNew: true),
      );
    }

    if (conversation.messages.isEmpty) {
      return _StateCard(
        icon: Icons.mark_chat_read_outlined,
        title: l10n.aiBuddyNoMessagesTitle,
        subtitle: l10n.aiBuddyNoMessagesSubtitle,
        buttonLabel: l10n.aiBuddyRefreshAction,
        onPressed: _loadConversation,
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: conversation.messages.length + (_isSending ? 1 : 0),
      itemBuilder: (_, i) {
        if (_isSending && i == conversation.messages.length) {
          return _TypingBubble(colors: colors);
        }
        final message = conversation.messages[i];
        return message.isUser
            ? _UserBubble(
                colors: colors,
                text: message.content,
                timeLabel: _formatTime(message.createdAt),
              )
            : _BuddyBubble(
                colors: colors,
                text: message.content,
                timeLabel: _formatTime(message.createdAt),
              );
      },
    );
  }

  Widget _buildInputBar(ColorScheme colors, AppLocalizations l10n) {
    final childTheme = context.childTheme;
    final disabled = _isLoading || _isSending || _unavailable != null;
    final provider = _conversation?.provider;
    final isFallback =
        provider != null && (!provider.configured || provider.status == 'fallback');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _textCtrl,
                  decoration: InputDecoration(
                    hintText: disabled
                        ? l10n.aiBuddyUnavailableHint
                        : isFallback
                            ? l10n.aiBuddySafeModeHint
                            : l10n.askKinderAnything,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  style: TextStyle(
                    fontSize: AppConstants.fontSize,
                    color: colors.onSurface,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !disabled,
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: disabled ? null : _sendMessage,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: disabled
                        ? [
                            colors.surfaceContainerHighest,
                            colors.surfaceContainerHighest,
                          ]
                        : [childTheme.buddyStart, childTheme.buddyEnd],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: disabled
                      ? const []
                      : [
                          BoxShadow(
                            color: childTheme.buddyStart.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: disabled
                      ? colors.onSurfaceVariant
                      : childTheme.buddyStart.onColor,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuddyBubble extends StatelessWidget {
  const _BuddyBubble({
    required this.colors,
    required this.text,
    required this.timeLabel,
  });

  final ColorScheme colors;
  final String text;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final childTheme = context.childTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsetsDirectional.only(end: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [childTheme.buddyStart, childTheme.buddyEnd],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: AppConstants.fontSize,
                      color: colors.onSurface,
                      height: 1.4,
                    ),
                  ),
                  if (timeLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final childTheme = context.childTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsetsDirectional.only(end: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [childTheme.buddyStart, childTheme.buddyEnd],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: const TypingDotsIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.colors,
    required this.text,
    required this.timeLabel,
  });

  final ColorScheme colors;
  final String text;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary,
                    colors.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: AppConstants.fontSize,
                      color: colors.onPrimary,
                      height: 1.4,
                    ),
                  ),
                  if (timeLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.onPrimary.withValues(alpha: 0.8),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => onPressed(),
                child: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
