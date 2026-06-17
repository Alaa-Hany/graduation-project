class AdminCmsAxisSummary {
  const AdminCmsAxisSummary({
    required this.key,
    required this.titleEn,
    required this.titleAr,
    this.categoryCount = 0,
    this.contentCount = 0,
    this.quizCount = 0,
  });

  final String key;
  final String titleEn;
  final String titleAr;
  final int categoryCount;
  final int contentCount;
  final int quizCount;

  factory AdminCmsAxisSummary.fromJson(Map<String, dynamic> json) {
    return AdminCmsAxisSummary(
      key: json['key'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      titleAr: json['title_ar'] as String? ?? '',
      categoryCount: json['category_count'] as int? ?? 0,
      contentCount: json['content_count'] as int? ?? 0,
      quizCount: json['quiz_count'] as int? ?? 0,
    );
  }
}

class AdminUploadedVideoAsset {
  const AdminUploadedVideoAsset({
    required this.videoUrl,
    this.thumbnailUrl,
    this.videoProvider,
    this.videoPublicId,
    this.videoDurationSeconds,
    this.metadataJson = const {},
  });

  final String videoUrl;
  final String? thumbnailUrl;
  final String? videoProvider;
  final String? videoPublicId;
  final int? videoDurationSeconds;
  final Map<String, dynamic> metadataJson;

  factory AdminUploadedVideoAsset.fromJson(Map<String, dynamic> json) {
    return AdminUploadedVideoAsset(
      videoUrl: json['video_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      videoProvider: json['video_provider'] as String?,
      videoPublicId: json['video_public_id'] as String?,
      videoDurationSeconds: json['video_duration_seconds'] as int?,
      metadataJson: json['metadata_json'] is Map
          ? Map<String, dynamic>.from(json['metadata_json'] as Map)
          : const {},
    );
  }
}

class AdminCmsCategory {
  const AdminCmsCategory({
    required this.id,
    required this.axisKey,
    required this.slug,
    required this.titleEn,
    required this.titleAr,
    this.descriptionEn,
    this.descriptionAr,
    this.contentCount = 0,
    this.quizCount = 0,
    this.createdAt,
    this.updatedAt,
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
  final String? createdAt;
  final String? updatedAt;

  factory AdminCmsCategory.fromJson(Map<String, dynamic> json) {
    return AdminCmsCategory(
      id: json['id'] as int,
      axisKey: json['axis_key'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      titleAr: json['title_ar'] as String? ?? '',
      descriptionEn: json['description_en'] as String?,
      descriptionAr: json['description_ar'] as String?,
      contentCount: json['content_count'] as int? ?? 0,
      quizCount: json['quiz_count'] as int? ?? 0,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class AdminCmsQuiz {
  const AdminCmsQuiz({
    required this.id,
    this.contentId,
    this.categoryId,
    this.axisKey,
    required this.status,
    required this.titleEn,
    required this.titleAr,
    this.descriptionEn,
    this.descriptionAr,
    this.questionsJson = const [],
    this.questionCount = 0,
    this.contentTitleEn,
    this.contentTitleAr,
    this.category,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
  });

  final int id;
  final int? contentId;
  final int? categoryId;
  final String? axisKey;
  final String status;
  final String titleEn;
  final String titleAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final List<Map<String, dynamic>> questionsJson;
  final int questionCount;
  final String? contentTitleEn;
  final String? contentTitleAr;
  final AdminCmsCategory? category;
  final String? createdAt;
  final String? updatedAt;
  final String? publishedAt;

  factory AdminCmsQuiz.fromJson(Map<String, dynamic> json) {
    final rawQuestions = (json['questions_json'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return AdminCmsQuiz(
      id: json['id'] as int,
      contentId: json['content_id'] as int?,
      categoryId: json['category_id'] as int?,
      axisKey: json['axis_key'] as String?,
      status: json['status'] as String? ?? 'draft',
      titleEn: json['title_en'] as String? ?? '',
      titleAr: json['title_ar'] as String? ?? '',
      descriptionEn: json['description_en'] as String?,
      descriptionAr: json['description_ar'] as String?,
      questionsJson: rawQuestions,
      questionCount: json['question_count'] as int? ?? rawQuestions.length,
      contentTitleEn: json['content_title_en'] as String?,
      contentTitleAr: json['content_title_ar'] as String?,
      category: json['category'] is Map
          ? AdminCmsCategory.fromJson(
              Map<String, dynamic>.from(json['category'] as Map),
            )
          : null,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      publishedAt: json['published_at'] as String?,
    );
  }
}

class AdminCmsContent {
  const AdminCmsContent({
    required this.id,
    this.categoryId,
    this.axisKey,
    required this.contentType,
    required this.status,
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
    this.metadataJson = const {},
    this.category,
    this.quizCount = 0,
    this.quizzes = const [],
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
  });

  final int id;
  final int? categoryId;
  final String? axisKey;
  final String contentType;
  final String status;
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
  final Map<String, dynamic> metadataJson;
  final AdminCmsCategory? category;
  final int quizCount;
  final List<AdminCmsQuiz> quizzes;
  final String? createdAt;
  final String? updatedAt;
  final String? publishedAt;

  String? get videoPreviewUrl => _metadataString('video_preview_url');
  String? get videoHostTier => _metadataString('video_host_tier');
  String? get effectiveVideoUrl => videoUrl ?? _metadataString('video_url');
  String? get effectiveVideoProvider =>
      videoProvider ?? _metadataString('video_provider');

  String? _metadataString(String key) {
    final value = metadataJson[key];
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  factory AdminCmsContent.fromJson(Map<String, dynamic> json) {
    final rawQuizzes = (json['quizzes'] as List<dynamic>? ?? const [])
        .map((item) =>
            AdminCmsQuiz.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return AdminCmsContent(
      id: json['id'] as int,
      categoryId: json['category_id'] as int?,
      axisKey: json['axis_key'] as String?,
      contentType: json['content_type'] as String? ?? 'lesson',
      status: json['status'] as String? ?? 'draft',
      titleEn: json['title_en'] as String? ?? '',
      titleAr: json['title_ar'] as String? ?? '',
      descriptionEn: json['description_en'] as String?,
      descriptionAr: json['description_ar'] as String?,
      bodyEn: json['body_en'] as String?,
      bodyAr: json['body_ar'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      videoUrl: json['video_url'] as String?,
      videoProvider: json['video_provider'] as String?,
      videoPublicId: json['video_public_id'] as String?,
      videoDurationSeconds: json['video_duration_seconds'] as int?,
      ageGroup: json['age_group'] as String?,
      metadataJson: json['metadata_json'] is Map
          ? Map<String, dynamic>.from(json['metadata_json'] as Map)
          : const {},
      category: json['category'] is Map
          ? AdminCmsCategory.fromJson(
              Map<String, dynamic>.from(json['category'] as Map),
            )
          : null,
      quizCount: json['quiz_count'] as int? ?? rawQuizzes.length,
      quizzes: rawQuizzes,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      publishedAt: json['published_at'] as String?,
    );
  }
}
