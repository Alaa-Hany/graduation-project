# -*- coding: utf-8 -*-
import os

ar_file = os.path.join(os.path.dirname(__file__),
    'lib', 'core', 'localization', 'l10n', 'app_localizations_ar.dart')

new_keys = """
  // ── Learn Screen ──
  @override String get searchPages => 'ابحث عن الصفحات...';
  @override String get letsExploreAndLearn => 'هيا نستكشف ونتعلم شيئاً ممتعاً!';
  @override String get noPagesFound => 'لا توجد صفحات';
  @override String get categoryBehavioral => 'السلوكي';
  @override String get categoryEducational => 'التعليمي';
  @override String get categorySkillful => 'المهاري';
  @override String get categoryEntertaining => 'الترفيهي';

  // ── Entertaining Screen ──
  @override String get foundSomethingFun => 'وجدت شيئاً ممتعاً لك!';

  // ── Behavioral Screen ──
  @override String get letsPracticeKindness => 'هيا نتدرب على اللطف اليوم!';

  // ── Method Content Screen ──
  @override String get letsTryNewSkill => 'هيا نجرب مهارة جديدة اليوم!';

  // ── Skillful Screen ──
  @override String get letsCreateSomethingFun => 'هيا نصنع شيئاً ممتعاً!';
  @override String get searchActivities => 'ابحث عن الأنشطة...';
  @override String get noActivitiesFound => 'لا توجد أنشطة.';
  @override String get watchNow => 'شاهد الآن';
  @override String get letsCreate => 'هيا نبدع!';
  @override String followStepsInVideo(String title) =>
      'اتبع الخطوات في هذا الفيديو لتتعلم كيفية إنشاء $title. استمتع وكن مبدعاً!';
  @override String get imDone => 'انتهيت!';

  // ── Educational Screen ──
  @override String get letsLearnSomethingNew => 'هيا نتعلم شيئاً جديداً!';
  @override String get searchLessons => 'ابحث عن الدروس...';
  @override String get noLessonsFound => 'لا توجد دروس.';

  // ── Lesson Detail / Quiz Screen ──
  @override String get readyForFunQuiz => 'هل أنت مستعد لاختبار ممتع؟';
  @override String get playQuizToEarnStars =>
      'العب اختباراً سريعاً لتكسب النجوم وتُظهر ما تعلمته!';
  @override String get startQuiz => 'ابدأ الاختبار';
  @override String get quizTime => 'وقت الاختبار!';
  @override String get youCompletedQuiz => 'أكملت الاختبار!';
  @override String get awesome => 'رائع!';
  @override String get nextQuestion => 'السؤال التالي';
"""

with open(ar_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Check if already added
if 'searchPages' in content:
    print('Keys already present, skipping.')
else:
    # Insert before the last closing brace
    last_brace = content.rfind('}')
    if last_brace == -1:
        print('ERROR: Could not find closing brace')
    else:
        content = content[:last_brace] + new_keys + '\n}\n'
        with open(ar_file, 'w', encoding='utf-8') as f:
            f.write(content)
        print('Done: Arabic keys appended successfully.')
