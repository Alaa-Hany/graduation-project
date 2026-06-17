import 'package:kinder_world/core/utils/video_url_utils.dart';

class PublicContentCategory {
  const PublicContentCategory({
    required this.id,
    required this.axisKey,
    required this.slug,
    required this.titleEn,
    required this.titleAr,
    this.descriptionEn,
    this.descriptionAr,
    this.contentCount = 0,
    this.quizCount = 0,
  });

  final int id;
  final String axisKey;
  final String slug;
  final String titleEn;
  final String titleAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final int contentCount;
  final int quizCount;

  factory PublicContentCategory.fromJson(Map<String, dynamic> json) {
    return PublicContentCategory(
      id: json['id'] as int? ?? 0,
      axisKey: json['axis_key']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      titleEn: json['title_en']?.toString() ?? '',
      titleAr: json['title_ar']?.toString() ?? '',
      descriptionEn: json['description_en']?.toString(),
      descriptionAr: json['description_ar']?.toString(),
      contentCount: json['content_count'] as int? ?? 0,
      quizCount: json['quiz_count'] as int? ?? 0,
    );
  }
}

class PublicQuiz {
  const PublicQuiz({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    this.descriptionEn,
    this.descriptionAr,
    this.questionCount = 0,
    this.questions = const [],
  });

  final int id;
  final String titleEn;
  final String titleAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final int questionCount;
  final List<Map<String, dynamic>> questions;

  factory PublicQuiz.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions_json'];
    return PublicQuiz(
      id: json['id'] as int? ?? 0,
      titleEn: json['title_en']?.toString() ?? '',
      titleAr: json['title_ar']?.toString() ?? '',
      descriptionEn: json['description_en']?.toString(),
      descriptionAr: json['description_ar']?.toString(),
      questionCount: json['question_count'] as int? ?? 0,
      questions: rawQuestions is List
          ? rawQuestions
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const [],
    );
  }
}

class PublicContentItem {
  const PublicContentItem({
    required this.id,
    required this.slug,
    this.axisKey,
    required this.contentType,
    required this.titleEn,
    required this.titleAr,
    this.descriptionEn,
    this.descriptionAr,
    this.bodyEn,
    this.bodyAr,
    this.thumbnailUrl,
    this.videoUrl,
    this.videoProvider,
    this.videoPublicId,
    this.videoDurationSeconds,
    this.ageGroup,
    this.metadata = const {},
    this.category,
    this.quizzes = const [],
  });

  final int id;
  final String slug;
  final String? axisKey;
  final String contentType;
  final String titleEn;
  final String titleAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final String? bodyEn;
  final String? bodyAr;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? videoProvider;
  final String? videoPublicId;
  final int? videoDurationSeconds;
  final String? ageGroup;
  final Map<String, dynamic> metadata;
  final PublicContentCategory? category;
  final List<PublicQuiz> quizzes;

  String? get videoPreviewUrl => _metadataString('video_preview_url');
  String? get preferredVideoUrl =>
      videoPreviewUrl ?? videoUrl ?? _metadataString('video_url');
  String? get effectiveVideoProvider =>
      videoProvider ?? _metadataString('video_provider');
  String? get effectiveThumbnailUrl =>
      thumbnailUrl ?? youtubeThumbnailUrl(preferredVideoUrl);
  String? get videoHostTier => _metadataString('video_host_tier');
  bool get hasVideo => (preferredVideoUrl ?? '').trim().isNotEmpty;

  String? _metadataString(String key) {
    final value = metadata[key];
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  factory PublicContentItem.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata_json'];
    final rawQuizzes = json['quizzes'];
    final rawCategory = json['category'];
    return PublicContentItem(
      id: json['id'] as int? ?? 0,
      slug: json['slug']?.toString() ?? '',
      axisKey: json['axis_key']?.toString(),
      contentType: json['content_type']?.toString() ?? '',
      titleEn: json['title_en']?.toString() ?? '',
      titleAr: json['title_ar']?.toString() ?? '',
      descriptionEn: json['description_en']?.toString(),
      descriptionAr: json['description_ar']?.toString(),
      bodyEn: json['body_en']?.toString(),
      bodyAr: json['body_ar']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      videoUrl: json['video_url']?.toString(),
      videoProvider: json['video_provider']?.toString(),
      videoPublicId: json['video_public_id']?.toString(),
      videoDurationSeconds: json['video_duration_seconds'] as int?,
      ageGroup: json['age_group']?.toString(),
      metadata: rawMetadata is Map<String, dynamic>
          ? rawMetadata
          : rawMetadata is Map
              ? Map<String, dynamic>.from(rawMetadata)
              : const {},
      category: rawCategory is Map<String, dynamic>
          ? PublicContentCategory.fromJson(rawCategory)
          : rawCategory is Map
              ? PublicContentCategory.fromJson(
                  Map<String, dynamic>.from(rawCategory))
              : null,
      quizzes: rawQuizzes is List
          ? rawQuizzes
              .whereType<Map>()
              .map((item) =>
                  PublicQuiz.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
    );
  }
}
