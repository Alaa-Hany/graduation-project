import 'package:flutter/material.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/theme/app_colors.dart';

const learnCategories = <Map<String, dynamic>>[
  {
    'title': 'Behavioral',
    'image': 'assets/images/behavioral_main.png',
    'color': AppColors.behavioral,
    'route': 'behavioral',
  },
  {
    'title': 'Educational',
    'image': 'assets/images/educational_main.png',
    'color': AppColors.educational,
    'route': 'educational',
  },
  {
    'title': 'Skillful',
    'image': 'assets/images/skillful_main.png',
    'color': AppColors.skillful,
    'route': 'skillful',
  },
  {
    'title': 'Entertaining',
    'image': 'assets/images/entertaining_main.png',
    'color': AppColors.entertaining,
    'route': 'entertaining',
  },
];

const learnSearchItems = <Map<String, String>>[
  {'title': 'Behavioral', 'route': 'behavioral'},
  {'title': 'Educational', 'route': 'educational'},
  {'title': 'Skillful', 'route': 'skillful'},
  {'title': 'Entertaining', 'route': 'entertaining'},
  {'title': 'Values', 'route': 'behavioral'},
  {'title': 'Methods', 'route': 'behavioral'},
  {'title': 'Activities', 'route': 'behavioral'},
  {'title': 'Value Details', 'route': 'behavioral'},
  {'title': 'Method Content', 'route': 'behavioral'},
  {'title': 'Stories', 'route': 'entertaining'},
  {'title': 'Games', 'route': 'entertaining'},
  {'title': 'Music', 'route': 'entertaining'},
  {'title': 'Videos', 'route': 'entertaining'},
  {'title': 'Subjects', 'route': 'educational'},
  {'title': 'Lessons', 'route': 'educational'},
  {'title': 'Lesson Detail', 'route': 'educational'},
  {'title': 'Skills', 'route': 'skillful'},
  {'title': 'Skill Details', 'route': 'skillful'},
  {'title': 'Skill Video', 'route': 'skillful'},
  {'title': 'Behavioral Values', 'route': 'behavioral'},
  {'title': 'Behavioral Methods', 'route': 'behavioral'},
];

const entertainingItems = <Map<String, dynamic>>[
  {
    'title': 'Puppet Show',
    'title_ar': 'عروض الدمى',
    'image': 'assets/images/ent_puppet_show.png',
    'color': Colors.orange,
  },
  {
    'title': 'Interactive Stories',
    'title_ar': 'قصص تفاعلية',
    'image': 'assets/images/ent_stories.png',
    'color': Colors.purple,
  },
  {
    'title': 'Songs & Music',
    'title_ar': 'أغاني وموسيقى',
    'image': 'assets/images/ent_music.png',
    'color': Colors.pink,
  },
  {
    'title': 'Funny Clips',
    'title_ar': 'مقاطع مضحكة',
    'image': 'assets/images/ent_clips.png',
    'color': Colors.yellow,
  },
  {
    'title': 'Brain Teasers',
    'title_ar': 'ألغاز ذهنية',
    'image': 'assets/images/ent_teasers.png',
    'color': Colors.teal,
  },
  {
    'title': 'Games',
    'title_ar': 'ألعاب',
    'image': 'assets/images/ent_games.png',
    'color': Colors.blue,
  },
  {
    'title': 'Cartoons',
    'title_ar': 'رسوم متحركة',
    'image': 'assets/images/ent_cartoons.png',
    'color': Colors.indigo,
  },
];

const behavioralValues = <Map<String, dynamic>>[
  {
    'title': 'Giving',
    'title_ar': 'العطاء',
    'image': 'assets/images/behavior_giving.png',
  },
  {
    'title': 'Respect',
    'title_ar': 'الاحترام',
    'image': 'assets/images/behavior_respect.png',
  },
  {
    'title': 'Tolerance',
    'title_ar': 'التسامح',
    'image': 'assets/images/behavior_tolerance.png',
  },
  {
    'title': 'Kindness',
    'title_ar': 'اللطف',
    'image': 'assets/images/behavior_kindness.png',
  },
  {
    'title': 'Cooperation',
    'title_ar': 'التعاون',
    'image': 'assets/images/behavior_cooperation.png',
  },
  {
    'title': 'Responsibility',
    'title_ar': 'المسؤولية',
    'image': 'assets/images/behavior_responsibility.png',
  },
  {
    'title': 'Honesty',
    'title_ar': 'الأمانة',
    'image': 'assets/images/behavior_honesty.png',
  },
  {
    'title': 'Patience',
    'title_ar': 'الصبر',
    'image': 'assets/images/behavior_patience.png',
  },
  {
    'title': 'Courage',
    'title_ar': 'الشجاعة',
    'image': 'assets/images/behavior_courage.png',
  },
  {
    'title': 'Gratitude',
    'title_ar': 'الامتنان',
    'image': 'assets/images/behavior_gratitude.png',
  },
  {
    'title': 'Peace',
    'title_ar': 'السلام',
    'image': 'assets/images/behavior_peace.png',
  },
  {
    'title': 'Love',
    'title_ar': 'الحب',
    'image': 'assets/images/behavior_love.png',
  },
];

const behavioralMethods = <Map<String, dynamic>>[
  {
    'title': 'Relaxation',
    'title_ar': 'الاسترخاء',
    'image': 'assets/images/method_relaxation.png',
  },
  {
    'title': 'Imagination',
    'title_ar': 'الخيال',
    'image': 'assets/images/method_imagination.png',
  },
  {
    'title': 'Meditation',
    'title_ar': 'التأمل',
    'image': 'assets/images/method_meditation.png',
  },
  {
    'title': 'Art Expression',
    'title_ar': 'التعبير الفني',
    'image': 'assets/images/method_art.png',
  },
  {
    'title': 'Social Bonding',
    'title_ar': 'الترابط الاجتماعي',
    'image': 'assets/images/method_social.png',
  },
  {
    'title': 'Self Development',
    'title_ar': 'تطوير الذات',
    'image': 'assets/images/method_self_dev.png',
  },
  {
    'title': 'Social Justice Focus',
    'title_ar': 'التركيز على العدالة الاجتماعية',
    'image': 'assets/images/method_justice.png',
  },
];

const skillCatalog = <Map<String, dynamic>>[
  {
    'title': 'Cooking',
    'title_ar': 'الطبخ',
    'image': 'assets/images/skill_cooking.png',
    'desc': 'Yummy food',
  },
  {
    'title': 'Drawing',
    'title_ar': 'الرسم',
    'image': 'assets/images/skill_drawing.png',
    'desc': 'Express art',
  },
  {
    'title': 'Coloring',
    'title_ar': 'التلوين',
    'image': 'assets/images/skill_coloring.png',
    'desc': 'Use colors',
  },
  {
    'title': 'Music',
    'title_ar': 'الموسيقى',
    'image': 'assets/images/skill_music.png',
    'desc': 'Play instruments',
  },
  {
    'title': 'Singing',
    'title_ar': 'الغناء',
    'image': 'assets/images/skill_singing.png',
    'desc': 'Learn songs',
  },
  {
    'title': 'Handcrafts',
    'title_ar': 'الأشغال اليدوية',
    'image': 'assets/images/skill_handcrafts.png',
    'desc': 'Cut & Paste',
  },
  {
    'title': 'Sports',
    'title_ar': 'الرياضة',
    'image': 'assets/images/skill_sports.png',
    'desc': 'Stay fit',
  },
];

const educationalSubjects = <Map<String, dynamic>>[
  {
    'title': 'English',
    'title_ar': 'الإنجليزية',
    'image': 'assets/images/edu_english.png',
    'color': Colors.blueAccent,
  },
  {
    'title': 'Arabic',
    'title_ar': 'العربية',
    'image': 'assets/images/edu_arabic.png',
    'color': Colors.green,
  },
  {
    'title': 'Geography',
    'title_ar': 'الجغرافيا',
    'image': 'assets/images/edu_geography.png',
    'color': Colors.orange,
  },
  {
    'title': 'History',
    'title_ar': 'التاريخ',
    'image': 'assets/images/edu_history.png',
    'color': Colors.brown,
  },
  {
    'title': 'Science',
    'title_ar': 'العلوم',
    'image': 'assets/images/edu_science.png',
    'color': Colors.purple,
  },
  {
    'title': 'Math',
    'title_ar': 'الرياضيات',
    'image': 'assets/images/edu_math.png',
    'color': Colors.red,
  },
  {
    'title': 'Animals',
    'title_ar': 'الحيوانات',
    'image': 'assets/images/edu_animals.png',
    'color': Colors.teal,
  },
  {
    'title': 'Plants',
    'title_ar': 'النباتات',
    'image': 'assets/images/edu_plants.png',
    'color': Colors.lightGreen,
  },
];

List<Map<String, String>> buildLegacyEducationalLessons(
  AppLocalizations l10n,
) {
  return const [];
}

const lessonQuizQuestions = <Map<String, dynamic>>[
  {
    'question': 'What color is the sky?',
    'options': ['Blue', 'Green', 'Red', 'Yellow'],
    'correct': 0,
  },
  {
    'question': 'How many legs does a dog have?',
    'options': ['Two', 'Four', 'Six', 'Eight'],
    'correct': 1,
  },
  {
    'question': 'Which one is a fruit?',
    'options': ['Carrot', 'Apple', 'Potato', 'Onion'],
    'correct': 1,
  },
];
