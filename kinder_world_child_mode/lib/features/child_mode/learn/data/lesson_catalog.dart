class LearnLessonBlueprint {
  const LearnLessonBlueprint({
    required this.id,
    required this.subject,
    required this.title,
    required this.description,
    required this.content,
    required this.durationMinutes,
    required this.difficulty,
    required this.xpReward,
    required this.prerequisites,
    this.category = 'educational',
  });

  final String id;
  final String subject;
  final String title;
  final String description;
  final String content;
  final int durationMinutes;
  final String difficulty;
  final int xpReward;
  final List<String> prerequisites;
  final String category;
}

const _mathLessons = <LearnLessonBlueprint>[
  LearnLessonBlueprint(
    id: 'math_01',
    subject: 'math',
    title: 'Counting Numbers 1-10',
    description: 'Learn to count from 1 to 10',
    content:
        'Count each object carefully and say the number out loud. Start slowly, then try again with confidence.',
    durationMinutes: 15,
    difficulty: 'beginner',
    xpReward: 50,
    prerequisites: [],
  ),
  LearnLessonBlueprint(
    id: 'math_02',
    subject: 'math',
    title: 'Addition Basics',
    description: 'Simple addition with small numbers',
    content:
        'Combine two small groups and discover how numbers grow when we add them together.',
    durationMinutes: 20,
    difficulty: 'beginner',
    xpReward: 70,
    prerequisites: ['math_01'],
  ),
  LearnLessonBlueprint(
    id: 'math_03',
    subject: 'math',
    title: 'Shapes and Patterns',
    description: 'Recognize different shapes and patterns',
    content:
        'Look for circles, squares, and repeating patterns in everyday objects around you.',
    durationMinutes: 18,
    difficulty: 'intermediate',
    xpReward: 85,
    prerequisites: ['math_02'],
  ),
];

const _scienceLessons = <LearnLessonBlueprint>[
  LearnLessonBlueprint(
    id: 'sci_01',
    subject: 'science',
    title: 'Parts of a Plant',
    description: 'Learn about roots, stem, leaves, and flowers',
    content:
        'Plants need roots to drink water, stems to stand tall, and leaves to make food from sunlight.',
    durationMinutes: 12,
    difficulty: 'beginner',
    xpReward: 50,
    prerequisites: [],
  ),
  LearnLessonBlueprint(
    id: 'sci_02',
    subject: 'science',
    title: 'Weather and Seasons',
    description: 'Understand daily weather and seasons',
    content:
        'Sunny, rainy, windy, and cloudy days help us understand weather. Seasons change what we wear and do.',
    durationMinutes: 22,
    difficulty: 'intermediate',
    xpReward: 75,
    prerequisites: ['sci_01'],
  ),
  LearnLessonBlueprint(
    id: 'sci_03',
    subject: 'science',
    title: 'Animal Habitats',
    description: 'Where do different animals live?',
    content:
        'Animals live in places that keep them safe and help them find food, from forests to oceans.',
    durationMinutes: 25,
    difficulty: 'advanced',
    xpReward: 95,
    prerequisites: ['sci_02'],
  ),
];

const _readingLessons = <LearnLessonBlueprint>[
  LearnLessonBlueprint(
    id: 'read_01',
    subject: 'reading',
    title: 'Alphabet Fun',
    description: 'Learn all the letters A-Z',
    content:
        'Meet each letter, say its sound, and match uppercase with lowercase forms.',
    durationMinutes: 30,
    difficulty: 'beginner',
    xpReward: 50,
    prerequisites: [],
  ),
  LearnLessonBlueprint(
    id: 'read_02',
    subject: 'reading',
    title: 'Short Vowel Sounds',
    description: 'Practice a, e, i, o, u sounds',
    content:
        'Short vowels help us sound out simple words like cat, bed, pig, dog, and sun.',
    durationMinutes: 20,
    difficulty: 'beginner',
    xpReward: 70,
    prerequisites: ['read_01'],
  ),
  LearnLessonBlueprint(
    id: 'read_03',
    subject: 'reading',
    title: 'Simple Words',
    description: 'Form simple three-letter words',
    content:
        'Blend sounds together to read and build short words with confidence.',
    durationMinutes: 25,
    difficulty: 'intermediate',
    xpReward: 90,
    prerequisites: ['read_02'],
  ),
];

const _historyLessons = <LearnLessonBlueprint>[
  LearnLessonBlueprint(
    id: 'history_01',
    subject: 'history',
    title: 'Yesterday and Today',
    description: 'Understand how life changes over time',
    content:
        'History helps us compare how people lived before with how we live now.',
    durationMinutes: 16,
    difficulty: 'beginner',
    xpReward: 45,
    prerequisites: [],
  ),
  LearnLessonBlueprint(
    id: 'history_02',
    subject: 'history',
    title: 'Helpers from the Past',
    description: 'Learn about important people and roles',
    content:
        'People in the past built, taught, healed, and protected their communities in many ways.',
    durationMinutes: 19,
    difficulty: 'intermediate',
    xpReward: 65,
    prerequisites: ['history_01'],
  ),
];

const _geographyLessons = <LearnLessonBlueprint>[
  LearnLessonBlueprint(
    id: 'geography_01',
    subject: 'geography',
    title: 'Maps Around Us',
    description: 'Learn how maps help us find places',
    content:
        'Maps show roads, rivers, homes, and landmarks so we can understand where things are.',
    durationMinutes: 14,
    difficulty: 'beginner',
    xpReward: 45,
    prerequisites: [],
  ),
  LearnLessonBlueprint(
    id: 'geography_02',
    subject: 'geography',
    title: 'Land and Water',
    description: 'Discover mountains, rivers, and seas',
    content:
        'Earth has many landforms and water bodies, and each place feels different to explore.',
    durationMinutes: 21,
    difficulty: 'intermediate',
    xpReward: 70,
    prerequisites: ['geography_01'],
  ),
];

const _genericLessons = <LearnLessonBlueprint>[
  LearnLessonBlueprint(
    id: 'generic_01',
    subject: 'general',
    title: 'Starter Lesson',
    description: 'A simple first lesson to get started',
    content:
        'Start with a short activity, follow the examples, and build confidence one step at a time.',
    durationMinutes: 15,
    difficulty: 'beginner',
    xpReward: 40,
    prerequisites: [],
  ),
  LearnLessonBlueprint(
    id: 'generic_02',
    subject: 'general',
    title: 'Practice Lesson',
    description: 'Build your confidence with practice',
    content:
        'Practice helps your brain grow stronger. Repeat the steps and try again with more focus.',
    durationMinutes: 18,
    difficulty: 'intermediate',
    xpReward: 60,
    prerequisites: ['generic_01'],
  ),
];

List<LearnLessonBlueprint> lessonsForSubject(String subject) {
  return const [];
}

LearnLessonBlueprint? lessonBlueprintById(String lessonId) {
  for (final lesson in <LearnLessonBlueprint>[
    ..._mathLessons,
    ..._scienceLessons,
    ..._readingLessons,
    ..._historyLessons,
    ..._geographyLessons,
    ..._genericLessons,
  ]) {
    if (lesson.id == lessonId) {
      return lesson;
    }
  }
  return null;
}
