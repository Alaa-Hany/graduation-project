import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/ai_buddy_models.dart';

void main() {
  test('AiBuddyConversation parses session, messages, and provider', () {
    final conversation = AiBuddyConversation.fromJson({
      'session': {
        'id': 4,
        'child_id': 7,
        'parent_user_id': 1,
        'status': 'active',
        'title': 'AI Buddy Session',
        'provider_mode': 'internal_fallback',
        'provider_status': 'fallback',
        'visibility_mode': 'summary_and_metrics',
        'parent_summary': 'Safe usage summary',
        'messages_count': 2,
      },
      'messages': [
        {
          'id': 1,
          'session_id': 4,
          'child_id': 7,
          'role': 'assistant',
          'content': 'Hello!',
          'response_source': 'internal_fallback',
          'status': 'completed',
          'safety_status': 'allowed',
        },
      ],
      'provider': {
        'configured': false,
        'mode': 'internal_fallback',
        'status': 'fallback',
        'reason': 'Provider is not configured.',
      },
    });

    expect(conversation.session?.id, 4);
    expect(conversation.messages.single.role, 'assistant');
    expect(conversation.provider.configured, isFalse);
    expect(conversation.provider.mode, 'internal_fallback');
    expect(conversation.session?.visibilityMode, 'summary_and_metrics');
  });

  test('AiBuddySendResult parses response pair', () {
    final result = AiBuddySendResult.fromJson({
      'session': {
        'id': 4,
        'child_id': 7,
        'parent_user_id': 1,
        'status': 'active',
        'provider_mode': 'internal_fallback',
        'provider_status': 'fallback',
        'visibility_mode': 'summary_and_metrics',
        'messages_count': 4,
      },
      'user_message': {
        'id': 2,
        'session_id': 4,
        'child_id': 7,
        'role': 'child',
        'content': 'Tell me a story',
        'response_source': 'client',
        'status': 'completed',
        'safety_status': 'allowed',
      },
      'assistant_message': {
        'id': 3,
        'session_id': 4,
        'child_id': 7,
        'role': 'assistant',
        'content': 'Here is a story',
        'response_source': 'internal_fallback',
        'status': 'completed',
        'safety_status': 'allowed',
      },
      'provider': {
        'configured': false,
        'mode': 'internal_fallback',
        'status': 'fallback',
      },
    });

    expect(result.userMessage.isUser, isTrue);
    expect(result.assistantMessage.isUser, isFalse);
    expect(result.provider.status, 'fallback');
  });

  test('AiBuddyVisibilitySummary parses policy and safety metrics', () {
    final summary = AiBuddyVisibilitySummary.fromJson({
      'child_id': 7,
      'child_name': 'Lina',
      'visibility_mode': 'summary_and_metrics',
      'transcript_access': false,
      'parent_summary': 'Summary only',
      'provider': {
        'configured': false,
        'mode': 'internal_fallback',
        'status': 'fallback',
        'reason': 'Fallback only',
      },
      'retention_policy': {
        'messages_retained_days': 30,
        'auto_archive': true,
        'delete_supported': true,
      },
      'usage_metrics': {
        'sessions_count': 2,
        'messages_count': 6,
        'child_messages_count': 3,
        'assistant_messages_count': 3,
        'allowed_count': 2,
        'refusal_count': 1,
        'safe_redirect_count': 0,
      },
      'recent_flags': [
        {
          'message_id': 11,
          'classification': 'needs_refusal',
          'topic': 'violence',
          'reason': 'Unsafe topic',
        },
      ],
    });

    expect(summary.transcriptAccess, isFalse);
    expect(summary.provider.status, 'fallback');
    expect(summary.retentionPolicy.messagesRetainedDays, 30);
    expect(summary.usageMetrics.refusalCount, 1);
    expect(summary.recentFlags.single.topic, 'violence');
  });
}
