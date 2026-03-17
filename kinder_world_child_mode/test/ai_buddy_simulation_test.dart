import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/ai_buddy_provider.dart';
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/features/child_mode/ai_buddy/ai_buddy_screen.dart';
import 'package:kinder_world/core/models/ai_buddy_models.dart';
import 'package:kinder_world/core/services/ai_buddy_service.dart';
import 'test_shared_preferences.dart';

class FakeAiBuddyService implements AiBuddyService {
  FakeAiBuddyService()
      : _provider = const AiBuddyProviderStatus(
          configured: false,
          mode: 'internal_fallback',
          status: 'fallback',
          reason:
              'AI Buddy is running in safe fallback mode. No external AI provider is configured yet.',
        );

  final AiBuddyProviderStatus _provider;
  AiBuddyConversation? _conversation;
  int _messageId = 1;

  @override
  Future<AiBuddyConversation> getOrStartCurrentSession({
    required int childId,
  }) async {
    _conversation ??= _buildConversation(childId: childId);
    return _conversation!;
  }

  @override
  Future<AiBuddyConversation> startSession({
    required int childId,
    bool forceNew = false,
  }) async {
    _conversation = _buildConversation(childId: childId);
    return _conversation!;
  }

  @override
  Future<AiBuddyConversation> getSession({required int sessionId}) async {
    return _conversation ?? _buildConversation(childId: 1);
  }

  @override
  Future<AiBuddySendResult> sendMessage({
    required int sessionId,
    required int childId,
    required String content,
    String? clientMessageId,
    String? quickAction,
  }) async {
    final session = _conversation?.session ??
        AiBuddySession(
          id: 10,
          childId: childId,
          parentUserId: 1,
          status: 'active',
          title: null,
          providerMode: 'internal_fallback',
          providerStatus: 'fallback',
          unavailableReason: _provider.reason,
          visibilityMode: 'summary_and_metrics',
          parentSummary: null,
          startedAt: DateTime.now(),
          lastMessageAt: DateTime.now(),
          endedAt: null,
          retentionExpiresAt: null,
          metadataJson: const {},
          messagesCount: 2,
        );

    final userMessage = AiBuddyMessage(
      id: _messageId++,
      sessionId: session.id,
      childId: childId,
      role: 'child',
      content: content,
      intent: quickAction,
      responseSource: 'client',
      status: 'completed',
      clientMessageId: clientMessageId,
      safetyStatus: 'allowed',
      metadataJson: const {},
      retentionExpiresAt: null,
      archivedAt: null,
      createdAt: DateTime.now(),
    );
    final assistantMessage = AiBuddyMessage(
      id: _messageId++,
      sessionId: session.id,
      childId: childId,
      role: 'assistant',
      content: 'Safe fallback response.',
      intent: quickAction ?? 'general_help',
      responseSource: 'internal_fallback',
      status: 'completed',
      clientMessageId: null,
      safetyStatus: 'allowed',
      metadataJson: const {},
      retentionExpiresAt: null,
      archivedAt: null,
      createdAt: DateTime.now(),
    );

    _conversation = AiBuddyConversation(
      session: session,
      messages: [
        ..._conversation?.messages ?? const [],
        userMessage,
        assistantMessage,
      ],
      provider: _provider,
    );

    return AiBuddySendResult(
      session: session,
      userMessage: userMessage,
      assistantMessage: assistantMessage,
      provider: _provider,
    );
  }

  @override
  Future<AiBuddyVisibilitySummary> getChildVisibilitySummary({
    required int childId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> deleteChildHistory({
    required int childId,
  }) async {
    throw UnimplementedError();
  }

  AiBuddyConversation _buildConversation({required int childId}) {
    return AiBuddyConversation(
      session: AiBuddySession(
        id: 10,
        childId: childId,
        parentUserId: 1,
        status: 'active',
        title: null,
        providerMode: 'internal_fallback',
        providerStatus: 'fallback',
        unavailableReason: _provider.reason,
        visibilityMode: 'summary_and_metrics',
        parentSummary: null,
        startedAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
        endedAt: null,
        retentionExpiresAt: null,
        metadataJson: const {},
        messagesCount: 1,
      ),
      messages: [
        AiBuddyMessage(
          id: _messageId++,
          sessionId: 10,
          childId: childId,
          role: 'assistant',
          content: 'Hello! I am your learning buddy in safe mode.',
          intent: 'greeting',
          responseSource: 'internal_fallback',
          status: 'completed',
          clientMessageId: null,
          safetyStatus: 'allowed',
          metadataJson: const {},
          retentionExpiresAt: null,
          archivedAt: null,
          createdAt: DateTime.now(),
        ),
      ],
      provider: _provider,
    );
  }
}

Future<void> _pumpAiBuddy(WidgetTester tester) async {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (message.contains('A RenderFlex overflowed')) {
      return;
    }
    previousOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousOnError);

  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final child = ChildProfile(
    id: 'child-1',
    name: 'Lina',
    age: 7,
    avatar: 'assets/images/avatars/av1.png',
    interests: const ['math', 'stories'],
    level: 2,
    xp: 150,
    streak: 2,
    favorites: const [],
    parentId: 'parent-1',
    parentEmail: 'parent@example.com',
    picturePassword: const ['cat', 'dog', 'apple'],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
    totalTimeSpent: 25,
    activitiesCompleted: 4,
    avatarPath: 'assets/images/avatars/av1.png',
  );
  final sharedPreferencesOverrides = await createSharedPreferencesOverrides();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentChildProvider.overrideWithValue(child),
        aiBuddyServiceProvider.overrideWithValue(FakeAiBuddyService()),
        ...sharedPreferencesOverrides,
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.lightTheme(palette: ThemePalettes.defaultPalette),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('ar'),
        ],
        home: const AiBuddyScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('AI Buddy renders fallback banner and quick actions',
      (WidgetTester tester) async {
    await _pumpAiBuddy(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(AiBuddyScreen)),
    )!;

    expect(find.textContaining('Safe fallback mode'), findsOneWidget);
    expect(find.text(l10n.aiBuddyName), findsOneWidget);
    expect(find.text(l10n.quickActions), findsOneWidget);
    expect(find.text(l10n.recommendLesson), findsOneWidget);
    expect(find.text(l10n.suggestGame), findsOneWidget);
  });

  testWidgets('quick action sends a fallback response',
      (WidgetTester tester) async {
    await _pumpAiBuddy(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(AiBuddyScreen)),
    )!;

    await tester.ensureVisible(find.text(l10n.recommendLesson));
    await tester.tap(find.text(l10n.recommendLesson));
    await tester.pump();

    expect(find.text('Safe fallback response.'), findsOneWidget);
  });

  testWidgets('sending a message appends a fallback reply',
      (WidgetTester tester) async {
    await _pumpAiBuddy(tester);

    await tester.enterText(find.byType(TextField), 'math game');
    await tester.ensureVisible(find.byIcon(Icons.send_rounded));
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(find.text('math game'), findsOneWidget);
    expect(find.text('Safe fallback response.'), findsOneWidget);
  });
}
