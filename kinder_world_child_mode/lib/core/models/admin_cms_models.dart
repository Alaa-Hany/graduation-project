class AdminCmsCategory {
  const AdminCmsCategory({
    required this.id,
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
    required this.contentType,
    required this.status,
    required this.titleEn,
    required this.titleAr,
    this.descriptionEn,
    this.descriptionAr,
    this.bodyEn,
    this.bodyAr,
    this.thumbnailUrl,
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
  final String contentType;
  final String status;
  final String titleEn;
  final String titleAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final String? bodyEn;
  final String? bodyAr;
  final String? thumbnailUrl;
  final String? ageGroup;
  final Map<String, dynamic> metadataJson;
  final AdminCmsCategory? category;
  final int quizCount;
  final List<AdminCmsQuiz> quizzes;
  final String? createdAt;
  final String? updatedAt;
  final String? publishedAt;

  factory AdminCmsContent.fromJson(Map<String, dynamic> json) {
    final rawQuizzes = (json['quizzes'] as List<dynamic>? ?? const [])
        .map((item) => AdminCmsQuiz.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return AdminCmsContent(
      id: json['id'] as int,
      categoryId: json['category_id'] as int?,
      contentType: json['content_type'] as String? ?? 'lesson',
      status: json['status'] as String? ?? 'draft',
      titleEn: json['title_en'] as String? ?? '',
      titleAr: json['title_ar'] as String? ?? '',
      descriptionEn: json['description_en'] as String?,
      descriptionAr: json['description_ar'] as String?,
      bodyEn: json['body_en'] as String?,
      bodyAr: json['body_ar'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
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
