# -*- coding: utf-8 -*-
import re

import os
base = os.path.dirname(os.path.abspath(__file__))
path = os.path.join(base, 'lib', 'features', 'child_mode', 'learn', 'learn_screen.dart')

with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

# 1. Add import
old = "import 'package:kinder_world/core/widgets/child_header.dart';"
new = ("import 'package:kinder_world/core/widgets/child_header.dart';\n"
       "import 'package:kinder_world/core/localization/app_localizations.dart';")
src = src.replace(old, new, 1)

# 2. LearnScreen.build – inject l10n
old = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    return AnimatedBuilder(")
new = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    return AnimatedBuilder(")
src = src.replace(old, new, 1)

# 3. Search hint text
src = src.replace("hintText: 'Search pages...',", "hintText: l10n.searchPages,", 1)

# 4. Explore text
old = '                            "Let\'s explore and learn something fun!",'
new = '                            l10n.letsExploreAndLearn,'
src = src.replace(old, new, 1)

# 5. _buildSearchResults – inject l10n + replace "No pages found"
old = ("  Widget _buildSearchResults(BuildContext context) {\n"
       "    final query = _searchQuery.trim().toLowerCase();")
new = ("  Widget _buildSearchResults(BuildContext context) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    final query = _searchQuery.trim().toLowerCase();")
src = src.replace(old, new, 1)

src = src.replace("          'No pages found',", "          l10n.noPagesFound,", 1)

# 6. _buildSearchResults – localize category title in grid
old = ("            child: Center(\n"
       "              child: Text(\n"
       "                category['title'],\n"
       "                textAlign: TextAlign.center,")
new = ("            child: Center(\n"
       "              child: Text(\n"
       "                _localizedSearchTitle(context, category['title'] as String),\n"
       "                textAlign: TextAlign.center,")
src = src.replace(old, new, 1)

# 7. _buildCategoryCard call – use localized title
old = ("          return _buildCategoryCard(\n"
       "            context,\n"
       "            category['title'],\n"
       "            category['image'],\n"
       "            category['color'],\n"
       "            category['route'],\n"
       "          );")
new = ("          return _buildCategoryCard(\n"
       "            context,\n"
       "            _localizedSearchTitle(context, category['title'] as String),\n"
       "            category['image'],\n"
       "            category['color'],\n"
       "            category['route'],\n"
       "          );")
src = src.replace(old, new, 1)

# 8. Add helper methods before _buildCategoryCard definition
old = "  Widget _buildCategoryCard(\n    BuildContext context,"
new = (
    "  String _localizedSearchTitle(BuildContext context, String title) {\n"
    "    final l10n = AppLocalizations.of(context)!;\n"
    "    switch (title) {\n"
    "      case 'Behavioral': return l10n.categoryBehavioral;\n"
    "      case 'Educational': return l10n.categoryEducational;\n"
    "      case 'Skillful': return l10n.categorySkillful;\n"
    "      case 'Entertaining': return l10n.categoryEntertaining;\n"
    "      default: return title;\n"
    "    }\n"
    "  }\n\n"
    "  Widget _buildCategoryCard(\n    BuildContext context,"
)
src = src.replace(old, new, 1)

# ── EntertainingScreen ──────────────────────────────────────────────────────

# 9. EntertainingScreen.build – inject l10n
old = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFF3E5F5),\n"
       "      appBar: AppBar(")
new = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFF3E5F5),\n"
       "      appBar: AppBar(")
src = src.replace(old, new, 1)

# 10. "I found something fun for you!"
old = ("                  child: Text(\n"
       "                      'I found something fun for you!',\n"
       "                      style: TextStyle(")
new = ("                  child: Text(\n"
       "                      l10n.foundSomethingFun,\n"
       "                      style: TextStyle(")
src = src.replace(old, new, 1)

# ── BehavioralScreen ────────────────────────────────────────────────────────

# 11. BehavioralScreen.build – inject l10n
old = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFE8F5E9),\n"
       "      appBar: AppBar(")
new = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFE8F5E9),\n"
       "      appBar: AppBar(")
src = src.replace(old, new, 1)

# 12. "Let's practice kindness today!"
old = ('            Text(\n'
       '              "Let\'s practice kindness today!",\n'
       '              style: TextStyle(\n'
       '                fontSize: 22,')
new = ('            Text(\n'
       '              l10n.letsPracticeKindness,\n'
       '              style: TextStyle(\n'
       '                fontSize: 22,')
src = src.replace(old, new, 1)

# ── MethodContentScreen ─────────────────────────────────────────────────────

# 13. MethodContentScreen.build – inject l10n (ConsumerWidget)
old = ("  Widget build(BuildContext context, WidgetRef ref) {\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFE8F5E9),")
new = ("  Widget build(BuildContext context, WidgetRef ref) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFE8F5E9),")
src = src.replace(old, new, 1)

# 14. "Let's try a new skill today!"
old = ("                        child: Text(\n"
       "                          'Let\\'s try a new skill today!',\n"
       "                          style: TextStyle(")
new = ("                        child: Text(\n"
       "                          l10n.letsTryNewSkill,\n"
       "                          style: TextStyle(")
src = src.replace(old, new, 1)

# ── SkillfulScreen ──────────────────────────────────────────────────────────

# 15. SkillfulScreen.build – inject l10n
old = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFFFF3E0),\n"
       "      appBar: AppBar(")
new = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFFFF3E0),\n"
       "      appBar: AppBar(")
src = src.replace(old, new, 1)

# 16. "Let's create something fun!"
old = ("            Text(\n"
       "              'Let\\'s create something fun!',\n"
       "              style: TextStyle(\n"
       "                fontSize: 24,")
new = ("            Text(\n"
       "              l10n.letsCreateSomethingFun,\n"
       "              style: TextStyle(\n"
       "                fontSize: 24,")
src = src.replace(old, new, 1)

# ── SkillDetailScreen ───────────────────────────────────────────────────────

# 17. SkillDetailScreen.build – inject l10n
old = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFFFF3E0).withOpacity(0.5),")
new = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFFFF3E0).withOpacity(0.5),")
src = src.replace(old, new, 1)

# 18. Search hint "Search activities..."
src = src.replace("                    hintText: 'Search activities...',",
                  "                    hintText: l10n.searchActivities,", 1)

# 19. "No activities found."
old = ('                      child: Text(\n'
       '                      "No activities found.",\n'
       '                      style: TextStyle(color: Colors.grey[500]),\n'
       '                    ))')
new = ('                      child: Text(\n'
       '                      l10n.noActivitiesFound,\n'
       '                      style: TextStyle(color: Colors.grey[500]),\n'
       '                    ))')
src = src.replace(old, new, 1)

# 20. Level chip display – localize in SkillDetailScreen
old = ("                        child: Text(\n"
       "                          level,\n"
       "                          style: TextStyle(\n"
       "                            color: isSelected ? Colors.white : Colors.grey[700],\n"
       "                            fontWeight: FontWeight.w600,\n"
       "                          ),\n"
       "                        ),\n"
       "                      ),\n"
       "                    );\n"
       "                  },\n"
       "                ),\n"
       "              ),\n"
       "            ),\n"
       "            const SizedBox(height: 20),\n"
       "            Expanded(\n"
       "              child: _filteredVideos.isEmpty")
new = ("                        child: Text(\n"
       "                          level == 'All' ? l10n.all\n"
       "                            : level == 'Beginner' ? l10n.beginner\n"
       "                            : level == 'Intermediate' ? l10n.intermediate\n"
       "                            : level == 'Advanced' ? l10n.advanced\n"
       "                            : level,\n"
       "                          style: TextStyle(\n"
       "                            color: isSelected ? Colors.white : Colors.grey[700],\n"
       "                            fontWeight: FontWeight.w600,\n"
       "                          ),\n"
       "                        ),\n"
       "                      ),\n"
       "                    );\n"
       "                  },\n"
       "                ),\n"
       "              ),\n"
       "            ),\n"
       "            const SizedBox(height: 20),\n"
       "            Expanded(\n"
       "              child: _filteredVideos.isEmpty")
src = src.replace(old, new, 1)

# 21. "Watch Now" in _buildVideoCard
old = ("                      child: Text(\n"
       "                        'Watch Now',\n"
       "                        style: const TextStyle(\n"
       "                          color: AppColors.skillful,")
new = ("                      child: Text(\n"
       "                        l10n.watchNow,\n"
       "                        style: const TextStyle(\n"
       "                          color: AppColors.skillful,")
src = src.replace(old, new, 1)

# ── SkillVideoScreen ────────────────────────────────────────────────────────

# 22. SkillVideoScreen.build – inject l10n
old = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFFFF8E1),")
new = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFFFF8E1),")
src = src.replace(old, new, 1)

# 23. "Let's Create!"
old = ('                                const Text(\n'
       '                                  "Let\'s Create!",\n'
       '                                  style: TextStyle(')
new = ('                                Text(\n'
       '                                  l10n.letsCreate,\n'
       '                                  style: TextStyle(')
src = src.replace(old, new, 1)

# 24. Follow steps text
old = ('                            Text(\n'
       '                              "Follow the steps in this video to learn how to create $videoTitle. Have fun and be creative!",\n'
       '                              style: TextStyle(')
new = ('                            Text(\n'
       '                              l10n.followStepsInVideo(videoTitle),\n'
       '                              style: TextStyle(')
src = src.replace(old, new, 1)

# 25. "I'm Done!"
old = ('                                child: const Text(\n'
       '                                  "I\'m Done!",\n'
       '                                  style: TextStyle(')
new = ('                                child: Text(\n'
       '                                  l10n.imDone,\n'
       '                                  style: TextStyle(')
src = src.replace(old, new, 1)

# ── EducationalScreen ───────────────────────────────────────────────────────

# 26. EducationalScreen.build – inject l10n
old = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFE3F2FD),\n"
       "      appBar: AppBar(")
new = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFE3F2FD),\n"
       "      appBar: AppBar(")
src = src.replace(old, new, 1)

# 27. "Let's learn something new!"
old = ('                  child: Text(\n'
       '                    "Let\'s learn something new!",\n'
       '                    style: TextStyle(')
new = ('                  child: Text(\n'
       '                    l10n.letsLearnSomethingNew,\n'
       '                    style: TextStyle(')
src = src.replace(old, new, 1)

# ── EducationalSubjectScreen ────────────────────────────────────────────────

# 28. EducationalSubjectScreen.build – inject l10n
old = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFE3F2FD),\n"
       "      body: SafeArea(")
new = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFE3F2FD),\n"
       "      body: SafeArea(")
src = src.replace(old, new, 1)

# 29. Search hint "Search lessons..."
src = src.replace("                    hintText: 'Search lessons...',",
                  "                    hintText: l10n.searchLessons,", 1)

# 30. "No lessons found."
old = ('                      child: Text(\n'
       '                      "No lessons found.",\n'
       '                      style: TextStyle(color: Colors.grey[500]),\n'
       '                    ))')
new = ('                      child: Text(\n'
       '                      l10n.noLessonsFound,\n'
       '                      style: TextStyle(color: Colors.grey[500]),\n'
       '                    ))')
src = src.replace(old, new, 1)

# 31. Level chip display – localize in EducationalSubjectScreen
old = ("                        child: Text(\n"
       "                          level,\n"
       "                          style: TextStyle(\n"
       "                            color: isSelected ? Colors.white : Colors.grey[700],\n"
       "                            fontWeight: FontWeight.w600,\n"
       "                          ),\n"
       "                        ),\n"
       "                      ),\n"
       "                    );\n"
       "                  },\n"
       "                ),\n"
       "              ),\n"
       "            ),\n"
       "            const SizedBox(height: 20),\n"
       "            Expanded(\n"
       "              child: _filteredLessons.isEmpty")
new = ("                        child: Text(\n"
       "                          level == 'All' ? l10n.all\n"
       "                            : level == 'Beginner' ? l10n.beginner\n"
       "                            : level == 'Intermediate' ? l10n.intermediate\n"
       "                            : level == 'Advanced' ? l10n.advanced\n"
       "                            : level,\n"
       "                          style: TextStyle(\n"
       "                            color: isSelected ? Colors.white : Colors.grey[700],\n"
       "                            fontWeight: FontWeight.w600,\n"
       "                          ),\n"
       "                        ),\n"
       "                      ),\n"
       "                    );\n"
       "                  },\n"
       "                ),\n"
       "              ),\n"
       "            ),\n"
       "            const SizedBox(height: 20),\n"
       "            Expanded(\n"
       "              child: _filteredLessons.isEmpty")
src = src.replace(old, new, 1)

# ── LessonDetailScreen ──────────────────────────────────────────────────────

# 32. LessonDetailScreen.build – inject l10n
old = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFE1F5FE),")
new = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    return Scaffold(\n"
       "      backgroundColor: Color(0xFFE1F5FE),")
src = src.replace(old, new, 1)

# 33. "Ready for a fun quiz?"
old = ('                                const Text(\n'
       '                                  "Ready for a fun quiz?",\n'
       '                                  style: TextStyle(')
new = ('                                Text(\n'
       '                                  l10n.readyForFunQuiz,\n'
       '                                  style: TextStyle(')
src = src.replace(old, new, 1)

# 34. "Play a quick quiz to earn stars..."
old = ('                            Text(\n'
       '                              "Play a quick quiz to earn stars and show what you learned!",\n'
       '                              textAlign: TextAlign.center,')
new = ('                            Text(\n'
       '                              l10n.playQuizToEarnStars,\n'
       '                              textAlign: TextAlign.center,')
src = src.replace(old, new, 1)

# 35. "Start Quiz"
old = ('                                label: const Text(\n'
       '                                  "Start Quiz",\n'
       '                                  style: TextStyle(')
new = ('                                label: Text(\n'
       '                                  l10n.startQuiz,\n'
       '                                  style: TextStyle(')
src = src.replace(old, new, 1)

# ── LessonQuizScreen ────────────────────────────────────────────────────────

# 36. LessonQuizScreen._nextQuestion – inject l10n for dialog
old = ("  void _nextQuestion() {\n"
       "    if (_currentQuestionIndex < _quizData.length - 1) {\n"
       "      setState(() {\n"
       "        _currentQuestionIndex++;\n"
       "        _selectedAnswerIndex = null;\n"
       "        _showResult = false;\n"
       "      });\n"
       "    } else {\n"
       "      showDialog(\n"
       "        context: context,\n"
       "        builder: (ctx) => AlertDialog(\n"
       "          shape:\n"
       "              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),\n"
       "          title: const Row(\n"
       "            children: [\n"
       "              Icon(Icons.celebration, color: Colors.orange, size: 28),\n"
       "              SizedBox(width: 10),\n"
       "              Text('Great Job!'),\n"
       "            ],\n"
       "          ),\n"
       "          content: const Text('You completed the quiz!'),\n"
       "          actions: [\n"
       "            TextButton(\n"
       "              onPressed: () => Navigator.of(ctx).pop(),\n"
       "              child: const Text(\n"
       "                'Awesome!',\n"
       "                style: TextStyle(\n"
       "                  color: Colors.orange,\n"
       "                  fontWeight: FontWeight.bold,\n"
       "                ),\n"
       "              ),\n"
       "            ),\n"
       "          ],\n"
       "        ),\n"
       "      );\n"
       "    }\n"
       "  }")
new = ("  void _nextQuestion() {\n"
       "    if (_currentQuestionIndex < _quizData.length - 1) {\n"
       "      setState(() {\n"
       "        _currentQuestionIndex++;\n"
       "        _selectedAnswerIndex = null;\n"
       "        _showResult = false;\n"
       "      });\n"
       "    } else {\n"
       "      final l10n = AppLocalizations.of(context)!;\n"
       "      showDialog(\n"
       "        context: context,\n"
       "        builder: (ctx) => AlertDialog(\n"
       "          shape:\n"
       "              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),\n"
       "          title: Row(\n"
       "            children: [\n"
       "              const Icon(Icons.celebration, color: Colors.orange, size: 28),\n"
       "              const SizedBox(width: 10),\n"
       "              Text(l10n.greatJob),\n"
       "            ],\n"
       "          ),\n"
       "          content: Text(l10n.youCompletedQuiz),\n"
       "          actions: [\n"
       "            TextButton(\n"
       "              onPressed: () => Navigator.of(ctx).pop(),\n"
       "              child: Text(\n"
       "                l10n.awesome,\n"
       "                style: const TextStyle(\n"
       "                  color: Colors.orange,\n"
       "                  fontWeight: FontWeight.bold,\n"
       "                ),\n"
       "              ),\n"
       "            ),\n"
       "          ],\n"
       "        ),\n"
       "      );\n"
       "    }\n"
       "  }")
src = src.replace(old, new, 1)

# 37. LessonQuizScreen.build – inject l10n
old = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final currentQ = _quizData[_currentQuestionIndex];")
new = ("  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final l10n = AppLocalizations.of(context)!;\n"
       "    final currentQ = _quizData[_currentQuestionIndex];")
src = src.replace(old, new, 1)

# 38. "Quiz Time!"
old = ("                          const Text(\n"
       "                            'Quiz Time!',\n"
       "                            style: TextStyle(\n"
       "                              fontWeight: FontWeight.bold,\n"
       "                              fontSize: 16,\n"
       "                            ),\n"
       "                          ),")
new = ("                          Text(\n"
       "                            l10n.quizTime,\n"
       "                            style: const TextStyle(\n"
       "                              fontWeight: FontWeight.bold,\n"
       "                              fontSize: 16,\n"
       "                            ),\n"
       "                          ),")
src = src.replace(old, new, 1)

# 39. Question counter
old = ("                          Text(\n"
       "                            'Question ${_currentQuestionIndex + 1} of ${_quizData.length}',\n"
       "                            style: TextStyle(color: Colors.grey[600]),\n"
       "                          ),")
new = ("                          Text(\n"
       "                            l10n.questionOf(_currentQuestionIndex + 1, _quizData.length),\n"
       "                            style: TextStyle(color: Colors.grey[600]),\n"
       "                          ),")
src = src.replace(old, new, 1)

# 40. "Next Question" / "Finish"
old = ("                  child: Text(\n"
       "                    _currentQuestionIndex < _quizData.length - 1\n"
       "                        ? 'Next Question'\n"
       "                        : 'Finish',\n"
       "                    style: const TextStyle(\n"
       "                        fontSize: 18, fontWeight: FontWeight.bold),\n"
       "                  ),")
new = ("                  child: Text(\n"
       "                    _currentQuestionIndex < _quizData.length - 1\n"
       "                        ? l10n.nextQuestion\n"
       "                        : l10n.lessonFinish,\n"
       "                    style: const TextStyle(\n"
       "                        fontSize: 18, fontWeight: FontWeight.bold),\n"
       "                  ),")
src = src.replace(old, new, 1)

with open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Done: learn_screen.dart localized successfully.")
