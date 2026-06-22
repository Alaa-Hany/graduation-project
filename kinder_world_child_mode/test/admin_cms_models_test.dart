// Unit tests for the admin CMS models (admin_cms_models.dart): fromJson parsing
// with full and minimal payloads, nested category/quiz parsing, and the
// metadata-derived getters on AdminCmsContent.

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/admin_cms_models.dart';

void main() {
  group('AdminCmsAxisSummary', () {
    test('parses full payload', () {
      final a = AdminCmsAxisSummary.fromJson({
        'key': 'educational',
        'title_en': 'Educational',
        'title_ar': 'تعليمي',
        'category_count': 4,
        'content_count': 10,
        'quiz_count': 3,
      });
      expect(a.key, 'educational');
      expect(a.titleAr, 'تعليمي');
      expect(a.categoryCount, 4);
      expect(a.quizCount, 3);
    });

    test('falls back to defaults for empty payload', () {
      final a = AdminCmsAxisSummary.fromJson(const {});
      expect(a.key, '');
      expect(a.categoryCount, 0);
      expect(a.contentCount, 0);
    });
  });

  group('AdminUploadedVideoAsset', () {
    test('parses url and optional fields', () {
      final v = AdminUploadedVideoAsset.fromJson({
        'video_url': 'https://x/v.mp4',
        'thumbnail_url': 'https://x/t.png',
        'video_provider': 'cloudinary',
        'video_public_id': 'abc',
        'video_duration_seconds': 90,
        'metadata_json': {'k': 'v'},
      });
      expect(v.videoUrl, 'https://x/v.mp4');
      expect(v.videoProvider, 'cloudinary');
      expect(v.videoDurationSeconds, 90);
      expect(v.metadataJson['k'], 'v');
    });

    test('handles missing metadata as empty map', () {
      final v = AdminUploadedVideoAsset.fromJson({'video_url': 'u'});
      expect(v.metadataJson, isEmpty);
      expect(v.thumbnailUrl, isNull);
    });
  });

  group('AdminCmsCategory', () {
    test('parses required id and titles', () {
      final c = AdminCmsCategory.fromJson({
        'id': 7,
        'axis_key': 'skillful',
        'slug': 'cooking',
        'title_en': 'Cooking',
        'title_ar': 'طبخ',
        'content_count': 2,
        'quiz_count': 1,
      });
      expect(c.id, 7);
      expect(c.slug, 'cooking');
      expect(c.contentCount, 2);
    });
  });

  group('AdminCmsQuiz', () {
    test('parses questions and nested category', () {
      final q = AdminCmsQuiz.fromJson({
        'id': 1,
        'status': 'published',
        'title_en': 'Quiz',
        'title_ar': 'اختبار',
        'questions_json': [
          {'q': 'a'},
          {'q': 'b'},
        ],
        'category': {
          'id': 3,
          'axis_key': 'educational',
          'slug': 's',
          'title_en': 'Cat',
          'title_ar': 'فئة',
        },
      });
      expect(q.id, 1);
      expect(q.status, 'published');
      expect(q.questionsJson.length, 2);
      expect(q.questionCount, 2); // derived from list length
      expect(q.category!.id, 3);
    });

    test('defaults status to draft and category to null', () {
      final q = AdminCmsQuiz.fromJson({
        'id': 2,
        'title_en': 'Q',
        'title_ar': 'س',
      });
      expect(q.status, 'draft');
      expect(q.category, isNull);
      expect(q.questionsJson, isEmpty);
    });
  });

  group('AdminCmsContent', () {
    test('parses content with nested quizzes', () {
      final c = AdminCmsContent.fromJson({
        'id': 5,
        'content_type': 'video',
        'status': 'published',
        'title_en': 'Lesson',
        'title_ar': 'درس',
        'quizzes': [
          {'id': 1, 'title_en': 'Q', 'title_ar': 'س'},
        ],
      });
      expect(c.id, 5);
      expect(c.contentType, 'video');
      expect(c.quizzes.length, 1);
      expect(c.quizCount, 1);
    });

    test('defaults contentType/status for minimal payload', () {
      final c = AdminCmsContent.fromJson({'id': 9});
      expect(c.contentType, 'lesson');
      expect(c.status, 'draft');
      expect(c.quizzes, isEmpty);
    });

    test('metadata getters resolve fallback values', () {
      final c = AdminCmsContent.fromJson({
        'id': 1,
        'metadata_json': {
          'video_preview_url': 'https://x/preview.mp4',
          'video_host_tier': 'premium',
          'video_url': 'https://x/fallback.mp4',
          'video_provider': 'youtube',
        },
      });
      expect(c.videoPreviewUrl, 'https://x/preview.mp4');
      expect(c.videoHostTier, 'premium');
      // videoUrl is null, so it falls back to metadata
      expect(c.effectiveVideoUrl, 'https://x/fallback.mp4');
      expect(c.effectiveVideoProvider, 'youtube');
    });

    test('effectiveVideoUrl prefers explicit videoUrl over metadata', () {
      final c = AdminCmsContent.fromJson({
        'id': 1,
        'video_url': 'https://x/direct.mp4',
        'metadata_json': {'video_url': 'https://x/meta.mp4'},
      });
      expect(c.effectiveVideoUrl, 'https://x/direct.mp4');
    });

    test('blank metadata strings resolve to null', () {
      final c = AdminCmsContent.fromJson({
        'id': 1,
        'metadata_json': {'video_preview_url': '   '},
      });
      expect(c.videoPreviewUrl, isNull);
    });
  });
}
