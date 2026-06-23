import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/api/api_providers.dart';
import 'package:kinder_world/core/providers/app_services.dart';
import 'package:kinder_world/core/utils/color_compat.dart';
import 'package:kinder_world/core/utils/session_token_utils.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/features/parent_mode/reports/development_report.dart';

/// Parent-facing card that shows the child's four development domains
/// (cognitive, language, creative, social) with an AI-written summary.
class DevelopmentReportCard extends ConsumerStatefulWidget {
  const DevelopmentReportCard({
    super.key,
    required this.childId,
    required this.days,
  });

  final String childId;
  final int days;

  @override
  ConsumerState<DevelopmentReportCard> createState() =>
      _DevelopmentReportCardState();
}

class _DevelopmentReportCardState extends ConsumerState<DevelopmentReportCard> {
  static const Map<String, Color> _domainColors = {
    'cognitive': Color(0xFF7C4DFF),
    'language': Color(0xFF2196F3),
    'creative': Color(0xFFFF7043),
    'social': Color(0xFF26A69A),
  };

  Future<DevelopmentReport?>? _future;
  String? _key;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureFuture();
  }

  @override
  void didUpdateWidget(covariant DevelopmentReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childId != widget.childId || oldWidget.days != widget.days) {
      _ensureFuture();
    }
  }

  bool _isArabic() =>
      Localizations.localeOf(context).languageCode == 'ar';

  void _ensureFuture() {
    final language = _isArabic() ? 'ar' : 'en';
    final key = '${widget.childId}:${widget.days}:$language';
    if (_key == key && _future != null) return;
    _key = key;
    _future = _load(language);
    if (mounted) setState(() {});
  }

  Future<DevelopmentReport?> _load(String language) async {
    final childId = int.tryParse(widget.childId);
    if (childId == null) return null;
    final token = await _resolveParentToken();
    if (token == null || token.isEmpty) return null;
    final payload = await ref.read(reportsApiProvider).getDevelopmentReport(
          childId: childId,
          days: widget.days,
          language: language,
          parentAccessToken: token,
        );
    if (payload.isEmpty) return null;
    return DevelopmentReport.fromJson(payload);
  }

  Future<String?> _resolveParentToken() async {
    final secureStorage = ref.read(secureStorageProvider);
    final parentToken = await secureStorage.getParentAccessToken();
    if (parentToken != null && parentToken.isNotEmpty) return parentToken;
    final authToken = await secureStorage.getAuthToken();
    if (authToken != null &&
        authToken.isNotEmpty &&
        !isChildSessionToken(authToken)) {
      return authToken;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DevelopmentReport?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return _loadingCard(context);
        }
        final report = snapshot.data;
        if (report == null) {
          // Degrade quietly when the report can't be loaded.
          return const SizedBox.shrink();
        }
        return _reportCard(context, report);
      },
    );
  }

  Widget _loadingCard(BuildContext context) {
    final isArabic = _isArabic();
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: isArabic ? 'مجالات القوة والنمو' : 'Strengths & Growth',
            subtitle: isArabic
                ? 'تقييم بالذكاء الاصطناعي لأربعة محاور'
                : 'AI assessment across four areas',
          ),
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _reportCard(BuildContext context, DevelopmentReport report) {
    final colors = Theme.of(context).colorScheme;
    final isArabic = _isArabic();

    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ParentSectionHeader(
                  title: isArabic
                      ? 'مجالات القوة والنمو'
                      : 'Strengths & Growth',
                  subtitle: isArabic
                      ? 'تقييم بالذكاء الاصطناعي لأربعة محاور'
                      : 'AI assessment across four areas',
                ),
              ),
              if (report.overallAverageScore != null)
                _OverallBadge(
                  score: report.overallAverageScore!,
                  color: colors.primary,
                  label: isArabic ? 'المتوسط' : 'Overall',
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!report.hasAnyData)
            ParentEmptyState(
              icon: Icons.insights_rounded,
              title: isArabic ? 'لا توجد بيانات كافية بعد' : 'Not enough data yet',
              subtitle: isArabic
                  ? 'شجّع طفلك على تجربة أنشطة متنوعة وسيظهر التقييم هنا.'
                  : 'Encourage a few varied activities and the report will fill in.',
            )
          else
            ...report.domains.map(
              (domain) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _DomainBar(
                  domain: domain,
                  isArabic: isArabic,
                  color: _domainColors[domain.key] ?? colors.primary,
                ),
              ),
            ),
          if (report.narrative.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            _NarrativeBox(
              text: report.narrative.summary.trim(),
              isAi: report.narrative.isAiGenerated,
              isArabic: isArabic,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  report.disclaimer(isArabic),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    fontStyle: FontStyle.italic,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DomainBar extends StatelessWidget {
  const _DomainBar({
    required this.domain,
    required this.isArabic,
    required this.color,
  });

  final DevelopmentDomain domain;
  final bool isArabic;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasData = domain.hasData;
    final score = domain.score ?? 0;
    final levelLabel = domain.levelLabel(isArabic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: hasData ? color : colors.outline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                domain.title(isArabic),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (hasData && levelLabel != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValuesCompat(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  levelLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$score',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ] else
              Text(
                isArabic ? 'بيانات غير كافية' : 'Not enough data',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: hasData ? (score / 100).clamp(0.0, 1.0) : 0.0,
            minHeight: 8,
            backgroundColor: colors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (hasData && domain.confidence == 'medium') ...[
          const SizedBox(height: 4),
          Text(
            isArabic ? 'بيانات محدودة' : 'limited data',
            style: TextStyle(
              fontSize: 10,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _NarrativeBox extends StatelessWidget {
  const _NarrativeBox({
    required this.text,
    required this.isAi,
    required this.isArabic,
  });

  final String text;
  final bool isAi;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValuesCompat(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.primary.withValuesCompat(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                isAi
                    ? (isArabic ? 'ملخص الذكاء الاصطناعي' : 'AI summary')
                    : (isArabic ? 'ملخص' : 'Summary'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(color: colors.onSurface, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _OverallBadge extends StatelessWidget {
  const _OverallBadge({
    required this.score,
    required this.color,
    required this.label,
  });

  final int score;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValuesCompat(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
