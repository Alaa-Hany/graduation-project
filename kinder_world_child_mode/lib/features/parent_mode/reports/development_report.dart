// Parsed model for the parent-facing child development report
// (`GET /reports/development`). Framed as strengths & growth areas — not a
// formal intelligence test.

class DevelopmentDomainStats {
  const DevelopmentDomainStats({
    required this.activitiesCount,
    required this.averageScore,
    required this.completionRate,
    required this.dataPoints,
  });

  final int activitiesCount;
  final double? averageScore;
  final double completionRate;
  final int dataPoints;

  factory DevelopmentDomainStats.fromJson(Map<String, dynamic> json) {
    return DevelopmentDomainStats(
      activitiesCount: _asInt(json['activities_count']),
      averageScore: _asDoubleOrNull(json['average_score']),
      completionRate: _asDoubleOrNull(json['completion_rate']) ?? 0.0,
      dataPoints: _asInt(json['data_points']),
    );
  }
}

class DevelopmentDomain {
  const DevelopmentDomain({
    required this.key,
    required this.titleEn,
    required this.titleAr,
    required this.score,
    required this.level,
    required this.levelLabelEn,
    required this.levelLabelAr,
    required this.confidence,
    required this.stats,
  });

  final String key;
  final String titleEn;
  final String titleAr;
  final int? score;
  final String? level;
  final String? levelLabelEn;
  final String? levelLabelAr;
  final String confidence;
  final DevelopmentDomainStats stats;

  bool get hasData => score != null && confidence != 'insufficient';

  String title(bool isArabic) => isArabic ? titleAr : titleEn;
  String? levelLabel(bool isArabic) => isArabic ? levelLabelAr : levelLabelEn;

  factory DevelopmentDomain.fromJson(Map<String, dynamic> json) {
    return DevelopmentDomain(
      key: json['key']?.toString() ?? '',
      titleEn: json['title_en']?.toString() ?? '',
      titleAr: json['title_ar']?.toString() ?? '',
      score: _asIntOrNull(json['score']),
      level: json['level']?.toString(),
      levelLabelEn: json['level_label_en']?.toString(),
      levelLabelAr: json['level_label_ar']?.toString(),
      confidence: json['confidence']?.toString() ?? 'insufficient',
      stats: DevelopmentDomainStats.fromJson(
        Map<String, dynamic>.from(json['stats'] as Map? ?? const {}),
      ),
    );
  }
}

class DevelopmentNarrative {
  const DevelopmentNarrative({
    required this.language,
    required this.source,
    required this.summary,
  });

  final String language;
  final String source;
  final String summary;

  bool get isAiGenerated => source == 'ai';

  factory DevelopmentNarrative.fromJson(Map<String, dynamic> json) {
    return DevelopmentNarrative(
      language: json['language']?.toString() ?? 'ar',
      source: json['source']?.toString() ?? 'fallback',
      summary: json['summary']?.toString() ?? '',
    );
  }
}

class DevelopmentReport {
  const DevelopmentReport({
    required this.childName,
    required this.windowDays,
    required this.domains,
    required this.overallAverageScore,
    required this.topDomain,
    required this.focusDomain,
    required this.narrative,
    required this.disclaimerAr,
    required this.disclaimerEn,
  });

  final String childName;
  final int windowDays;
  final List<DevelopmentDomain> domains;
  final int? overallAverageScore;
  final String? topDomain;
  final String? focusDomain;
  final DevelopmentNarrative narrative;
  final String disclaimerAr;
  final String disclaimerEn;

  bool get hasAnyData => domains.any((domain) => domain.hasData);

  String disclaimer(bool isArabic) => isArabic ? disclaimerAr : disclaimerEn;

  factory DevelopmentReport.fromJson(Map<String, dynamic> json) {
    final child = Map<String, dynamic>.from(json['child'] as Map? ?? const {});
    final overall =
        Map<String, dynamic>.from(json['overall'] as Map? ?? const {});
    final disclaimer =
        Map<String, dynamic>.from(json['disclaimer'] as Map? ?? const {});
    final domains = (json['domains'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => DevelopmentDomain.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);

    return DevelopmentReport(
      childName: child['name']?.toString() ?? '',
      windowDays: _asInt(json['window_days']),
      domains: domains,
      overallAverageScore: _asIntOrNull(overall['average_score']),
      topDomain: overall['top_domain']?.toString(),
      focusDomain: overall['focus_domain']?.toString(),
      narrative: DevelopmentNarrative.fromJson(
        Map<String, dynamic>.from(json['narrative'] as Map? ?? const {}),
      ),
      disclaimerAr: disclaimer['ar']?.toString() ?? '',
      disclaimerEn: disclaimer['en']?.toString() ?? '',
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
