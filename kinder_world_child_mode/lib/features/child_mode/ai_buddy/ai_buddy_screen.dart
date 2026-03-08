import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/core/widgets/child_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isTyping;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isTyping = false,
    required this.timestamp,
  });
}

class _QuickAction {
  final String title;
  final String emoji;
  final Color color;
  final String action;

  const _QuickAction({
    required this.title,
    required this.emoji,
    required this.color,
    required this.action,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AiBuddyScreen extends ConsumerStatefulWidget {
  const AiBuddyScreen({super.key});

  @override
  ConsumerState<AiBuddyScreen> createState() => _AiBuddyScreenState();
}

class _AiBuddyScreenState extends ConsumerState<AiBuddyScreen>
    with SingleTickerProviderStateMixin {
  // Kinder avatar pulse animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseGlow;

  late List<ChatMessage> _messages;
  bool _messagesInitialized = false;

  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isVoiceMode = false;

  List<_QuickAction> _getQuickActions(AppLocalizations l10n) => [
    _QuickAction(
      title: l10n.recommendLesson,
      emoji: '📚',
      color: ChildColors.learningBlue,
      action: 'recommend_lesson',
    ),
    _QuickAction(
      title: l10n.suggestGame,
      emoji: '🎮',
      color: ChildColors.skillPurple,
      action: 'suggest_game',
    ),
    _QuickAction(
      title: l10n.tellStory,
      emoji: '📖',
      color: ChildColors.kindnessPink,
      action: 'tell_story',
    ),
    _QuickAction(
      title: l10n.funFact,
      emoji: '🔬',
      color: ChildColors.funCyan,
      action: 'fun_fact',
    ),
    _QuickAction(
      title: l10n.motivation,
      emoji: '🚀',
      color: ChildColors.streakFire,
      action: 'motivation',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_messagesInitialized) {
      final l10n = AppLocalizations.of(context)!;
      _messages = [
        ChatMessage(
          text: l10n.aiInitialGreeting,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ];
      _messagesInitialized = true;
    }
  }

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
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _textCtrl.clear();
    });
    _scrollToBottom();
    _simulateResponse(text);
  }

  void _simulateResponse(String userMessage) {
    setState(() {
      _messages.add(ChatMessage(
        text: '...',
        isUser: false,
        isTyping: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.isTyping);
        _messages.add(ChatMessage(
          text: _generateResponse(userMessage),
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  String _generateResponse(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('math')) {
      return 'I love math too! 🔢  Try this: 3 + 5 = ?  How about we play a quick numbers game?';
    } else if (lower.contains('story')) {
      return 'Once upon a time in the land of Kinder World, a brave little explorer discovered that learning was the greatest adventure of all... ✨';
    } else if (lower.contains('game')) {
      return 'Ooh, games! 🎮  Try the Puzzle Builder in the Skills section — it\'s super fun and helps your brain grow!';
    } else if (lower.contains('sad') || lower.contains('upset')) {
      return 'I\'m sorry you\'re feeling that way 💙  It\'s okay to have big feelings. Want to hear something that might cheer you up?';
    } else if (lower.contains('tired')) {
      return 'Rest is important! 😴  Maybe do a short, calm activity today. The Coloring page is a great choice!';
    }
    return 'That\'s interesting! 🌟  Tell me more — I\'m here to help you learn and have fun every single day!';
  }

  void _handleQuickAction(String action) {
    final responses = {
      'recommend_lesson': '📚  I recommend "Numbers Adventure" — it\'s perfect for your level and super fun! Want me to open it?',
      'suggest_game': '🎮  Try "Puzzle Challenge" right now! It sharpens your problem-solving skills while keeping things exciting.',
      'tell_story': '📖  Here\'s a quick tale: Sammy the Science Explorer once found a magic potion... but it turned out to just be orange juice! 😄',
      'fun_fact': '🔬  Did you know octopuses have THREE hearts and BLUE blood? Nature is incredibly amazing!',
      'motivation': '🚀  You\'re doing GREAT! Every time you learn something new, your brain gets stronger. Keep going — I believe in you! ⭐',
    };

    setState(() {
      _messages.add(ChatMessage(
        text: responses[action] ?? 'Here\'s something cool for you! 🌟',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
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
            _buildQuickActions(colors, l10n),
            const Divider(height: 1),
            Expanded(child: _buildChatList(colors)),
            _buildInputBar(colors),
          ],
        ),
      ),
    );
  }

  // ── HEADER (Kinder avatar + identity) ─────────────────────────────────────

  Widget _buildHeader(ColorScheme colors, AppLocalizations l10n) {
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
          // Nav row
          const Row(
            children: [
              ChildHeader(compact: true, padding: EdgeInsets.zero),
            ],
          ),
          const SizedBox(height: 16),

          // Kinder identity row
          Row(
            children: [
              // Kinder avatar with pulse glow
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, child) => Transform.scale(
                  scale: _pulseScale.value,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ChildColors.buddyStart,
                          ChildColors.buddyEnd,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ChildColors.buddyStart
                              .withValues(alpha: _pulseGlow.value),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('⭐', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Kinder',
                          style: TextStyle(
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
                            color: ChildColors.successGreen
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 7,
                                color: ChildColors.successGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.aiBuddyOnline,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: ChildColors.successGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.aiCompanionSubtitle,
                      style: TextStyle(
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

          // Quick action label
          Text(
            l10n.quickActions,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ── QUICK ACTIONS ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(ColorScheme colors, AppLocalizations l10n) {
    final actions = _getQuickActions(l10n);
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: actions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _buildQuickActionCard(actions[i]),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(_QuickAction action) {
    return InkWell(
      onTap: () => _handleQuickAction(action.action),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: action.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: action.color.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(action.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 5),
            Text(
              action.title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: action.color,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // ── CHAT LIST ─────────────────────────────────────────────────────────────

  Widget _buildChatList(ColorScheme colors) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildMessageRow(_messages[i], colors),
    );
  }

  Widget _buildMessageRow(ChatMessage msg, ColorScheme colors) {
    if (msg.isUser) {
      return _buildUserBubble(msg, colors);
    }
    return _buildKinderBubble(msg, colors);
  }

  Widget _buildKinderBubble(ChatMessage msg, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Mini Kinder avatar
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsetsDirectional.only(end: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ChildColors.buddyStart, ChildColors.buddyEnd],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('⭐', style: TextStyle(fontSize: 14)),
            ),
          ),
          // Bubble
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
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: msg.isTyping
                  ? const TypingDotsIndicator()
                  : Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: AppConstants.fontSize,
                        color: colors.onSurface,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(ChatMessage msg, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: AppConstants.fontSize,
                  color: colors.onPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── INPUT BAR ─────────────────────────────────────────────────────────────

  Widget _buildInputBar(ColorScheme colors) {
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
            // Voice / text toggle
            InkWell(
              onTap: () => setState(() => _isVoiceMode = !_isVoiceMode),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isVoiceMode
                      ? ChildColors.buddyStart.withValues(alpha: 0.15)
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _isVoiceMode ? Icons.mic_rounded : Icons.mic_none_rounded,
                  size: 22,
                  color: _isVoiceMode
                      ? ChildColors.buddyStart
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Text field
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
                  hintText: _isVoiceMode
                      ? AppLocalizations.of(context)!.tapMicToSpeak
                      : AppLocalizations.of(context)!.askKinderAnything,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 11),
                  ),
                  style: TextStyle(
                    fontSize: AppConstants.fontSize,
                    color: colors.onSurface,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isVoiceMode,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            InkWell(
              onTap: _sendMessage,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ChildColors.buddyStart, ChildColors.buddyEnd],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: ChildColors.buddyStart.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
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
