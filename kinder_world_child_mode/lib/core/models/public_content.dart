class PublicContentCategory {
  const PublicContentCategory({
    required this.id,
    required this.slug,
    required this.titleEn,
    required this.titleAr,
    this.descriptionEn,
    this.descriptionAr,
    this.contentCount = 0,
    this.quizCount = 0,
  });

  final int id;
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
    required this.contentType,
    required this.titleEn,
    required this.titleAr,
    this.descriptionEn,
    this.descriptionAr,
    this.bodyEn,
    this.bodyAr,
    this.thumbnailUrl,
    this.ageGroup,
    this.metadata = const {},
    this.category,
    this.quizzes = const [],
  });

  final int id;
  final String slug;
  final String contentType;
  final String titleEn;
  final String titleAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final String? bodyEn;
  final String? bodyAr;
  final String? thumbnailUrl;
  final String? ageGroup;
  final Map<String, dynamic> metadata;
  final PublicContentCategory? category;
  final List<PublicQuiz> quizzes;

  factory PublicContentItem.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata_json'];
    final rawQuizzes = json['quizzes'];
    final rawCategory = json['category'];
    return PublicContentItem(
      id: json['id'] as int? ?? 0,
      slug: json['slug']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? '',
      titleEn: json['title_en']?.toString() ?? '',
      titleAr: json['title_ar']?.toString() ?? '',
      descriptionEn: json['description_en']?.toString(),
      descriptionAr: json['description_ar']?.toString(),
      bodyEn: json['body_en']?.toString(),
      bodyAr: json['body_ar']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      ageGroup: json['age_group']?.toString(),
      metadata: rawMetadata is Map<String, dynamic>
          ? rawMetadata
          : rawMetadata is Map
              ? Map<String, dynamic>.from(rawMetadata)
              : const {},
      category: rawCategory is Map<String, dynamic>
          ? PublicContentCategory.fromJson(rawCategory)
          : rawCategory is Map
              ? PublicContentCategory.fromJson(Map<String, dynamic>.from(rawCategory))
              : null,
      quizzes: rawQuizzes is List
          ? rawQuizzes
              .whereType<Map>()
              .map((item) => PublicQuiz.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
    );
  }
}
