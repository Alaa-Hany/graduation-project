// lib/core/services/mood_recommendation_service.dart
//
// Pure rule-based recommendation engine.
// Maps a child's current mood to a curated list of content suggestions.
// No external AI — deterministic, offline-capable logic.

import 'package:flutter/material.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RECOMMENDATION MODEL
// ─────────────────────────────────────────────────────────────────────────────

/// A single content recommendation card shown to the child.
class MoodRecommendation {
  final String id;
  final String emoji;
  final String titleKey;   // localization key
  final String subtitleKey; // localization key
  final Color color;
  final String route;      // GoRouter route to navigate to
  final IconData icon;

  const MoodRecommendation({
    required this.id,
    required this.emoji,
    required this.titleKey,
    required this.subtitleKey,
    required this.color,
    required this.route,
    required this.icon,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// RECOMMENDATION SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class MoodRecommendationService {
  const MoodRecommendationService._();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns 2–3 content recommendations for the given [mood].
  static List<MoodRecommendation> getRecommendations(String mood) {
    switch (mood) {
      case ChildMoods.happy:
        return _happyRecs;
      case ChildMoods.excited:
        return _excitedRecs;
      case ChildMoods.calm:
        return _calmRecs;
      case ChildMoods.tired:
        return _tiredRecs;
      case ChildMoods.sad:
        return _sadRecs;
      case ChildMoods.angry:
        return _angryRecs;
      default:
        return _defaultRecs;
    }
  }

  /// Returns a short encouragement message for the given [mood].
  static String getEncouragementKey(String mood) {
    switch (mood) {
      case ChildMoods.happy:
        return 'moodEncouragementHappy';
      case ChildMoods.excited:
        return 'moodEncouragementExcited';
      case ChildMoods.calm:
        return 'moodEncouragementCalm';
      case ChildMoods.tired:
        return 'moodEncouragementTired';
      case ChildMoods.sad:
        return 'moodEncouragementSad';
      case ChildMoods.angry:
        return 'moodEncouragementAngry';
      default:
        return 'moodEncouragementHappy';
    }
  }

  // ── Recommendation Catalogs ────────────────────────────────────────────────

  // HAPPY 😊 — child is in a great mood → reward with engaging content
  static const List<MoodRecommendation> _happyRecs = [
    MoodRecommendation(
      id: 'happy_learn',
      emoji: '📚',
      titleKey: 'moodRecHappyLearnTitle',
      subtitleKey: 'moodRecHappyLearnSubtitle',
      color: Color(0xFFFFD700),
      route: Routes.childLearn,
      icon: Icons.school_rounded,
    ),
    MoodRecommendation(
      id: 'happy_play',
      emoji: '🎮',
      titleKey: 'moodRecHappyPlayTitle',
      subtitleKey: 'moodRecHappyPlaySubtitle',
      color: Color(0xFFFF6B35),
      route: Routes.childPlay,
      icon: Icons.sports_esports_rounded,
    ),
    MoodRecommendation(
      id: 'happy_ai',
      emoji: '🤖',
      titleKey: 'moodRecHappyAiTitle',
      subtitleKey: 'moodRecHappyAiSubtitle',
      color: Color(0xFF7C4DFF),
      route: Routes.childAiBuddy,
      icon: Icons.smart_toy_rounded,
    ),
  ];

  // EXCITED 🤩 — high energy → channel into active learning
  static const List<MoodRecommendation> _excitedRecs = [
    MoodRecommendation(
      id: 'excited_play',
      emoji: '🎯',
      titleKey: 'moodRecExcitedPlayTitle',
      subtitleKey: 'moodRecExcitedPlaySubtitle',
      color: Color(0xFFFF6B35),
      route: Routes.childPlay,
      icon: Icons.sports_esports_rounded,
    ),
    MoodRecommendation(
      id: 'excited_learn',
      emoji: '🧩',
      titleKey: 'moodRecExcitedLearnTitle',
      subtitleKey: 'moodRecExcitedLearnSubtitle',
      color: Color(0xFF3F51B5),
      route: Routes.childLearn,
      icon: Icons.extension_rounded,
    ),
    MoodRecommendation(
      id: 'excited_ai',
      emoji: '💬',
      titleKey: 'moodRecExcitedAiTitle',
      subtitleKey: 'moodRecExcitedAiSubtitle',
      color: Color(0xFF7C4DFF),
      route: Routes.childAiBuddy,
      icon: Icons.chat_bubble_rounded,
    ),
  ];

  // CALM 😌 — focused state → ideal for deep learning
  static const List<MoodRecommendation> _calmRecs = [
    MoodRecommendation(
      id: 'calm_learn',
      emoji: '📖',
      titleKey: 'moodRecCalmLearnTitle',
      subtitleKey: 'moodRecCalmLearnSubtitle',
      color: Color(0xFF4CAF50),
      route: Routes.childLearn,
      icon: Icons.menu_book_rounded,
    ),
    MoodRecommendation(
      id: 'calm_coloring',
      emoji: '🎨',
      titleKey: 'moodRecCalmColoringTitle',
      subtitleKey: 'moodRecCalmColoringSubtitle',
      color: Color(0xFF9C27B0),
      route: Routes.childLearn,
      icon: Icons.palette_rounded,
    ),
    MoodRecommendation(
      id: 'calm_ai',
      emoji: '🌟',
      titleKey: 'moodRecCalmAiTitle',
      subtitleKey: 'moodRecCalmAiSubtitle',
      color: Color(0xFF00BCD4),
      route: Routes.childAiBuddy,
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  // TIRED 😴 — low energy → light, gentle activities
  static const List<MoodRecommendation> _tiredRecs = [
    MoodRecommendation(
      id: 'tired_coloring',
      emoji: '🖍️',
      titleKey: 'moodRecTiredColoringTitle',
      subtitleKey: 'moodRecTiredColoringSubtitle',
      color: Color(0xFF9C27B0),
      route: Routes.childLearn,
      icon: Icons.palette_rounded,
    ),
    MoodRecommendation(
      id: 'tired_story',
      emoji: '📕',
      titleKey: 'moodRecTiredStoryTitle',
      subtitleKey: 'moodRecTiredStorySubtitle',
      color: Color(0xFF4CAF50),
      route: Routes.childPlay,
      icon: Icons.auto_stories_rounded,
    ),
  ];

  // SAD 😢 — needs comfort → calming, kind content
  static const List<MoodRecommendation> _sadRecs = [
    MoodRecommendation(
      id: 'sad_story',
      emoji: '💛',
      titleKey: 'moodRecSadStoryTitle',
      subtitleKey: 'moodRecSadStorySubtitle',
      color: Color(0xFFFFD700),
      route: Routes.childPlay,
      icon: Icons.favorite_rounded,
    ),
    MoodRecommendation(
      id: 'sad_ai',
      emoji: '🤗',
      titleKey: 'moodRecSadAiTitle',
      subtitleKey: 'moodRecSadAiSubtitle',
      color: Color(0xFF7C4DFF),
      route: Routes.childAiBuddy,
      icon: Icons.smart_toy_rounded,
    ),
    MoodRecommendation(
      id: 'sad_coloring',
      emoji: '🌈',
      titleKey: 'moodRecSadColoringTitle',
      subtitleKey: 'moodRecSadColoringSubtitle',
      color: Color(0xFF9C27B0),
      route: Routes.childLearn,
      icon: Icons.palette_rounded,
    ),
  ];

  // ANGRY 😠 — needs de-escalation → breathing, relaxation
  static const List<MoodRecommendation> _angryRecs = [
    MoodRecommendation(
      id: 'angry_ai',
      emoji: '🧘',
      titleKey: 'moodRecAngryAiTitle',
      subtitleKey: 'moodRecAngryAiSubtitle',
      color: Color(0xFF4CAF50),
      route: Routes.childAiBuddy,
      icon: Icons.self_improvement_rounded,
    ),
    MoodRecommendation(
      id: 'angry_coloring',
      emoji: '🎨',
      titleKey: 'moodRecAngryColoringTitle',
      subtitleKey: 'moodRecAngryColoringSubtitle',
      color: Color(0xFF9C27B0),
      route: Routes.childLearn,
      icon: Icons.palette_rounded,
    ),
    MoodRecommendation(
      id: 'angry_story',
      emoji: '📖',
      titleKey: 'moodRecAngryStoryTitle',
      subtitleKey: 'moodRecAngryStorySubtitle',
      color: Color(0xFF3F51B5),
      route: Routes.childPlay,
      icon: Icons.auto_stories_rounded,
    ),
  ];

  // DEFAULT — fallback
  static const List<MoodRecommendation> _defaultRecs = [
    MoodRecommendation(
      id: 'default_learn',
      emoji: '📚',
      titleKey: 'moodRecHappyLearnTitle',
      subtitleKey: 'moodRecHappyLearnSubtitle',
      color: Color(0xFFFFD700),
      route: Routes.childLearn,
      icon: Icons.school_rounded,
    ),
    MoodRecommendation(
      id: 'default_play',
      emoji: '🎮',
      titleKey: 'moodRecHappyPlayTitle',
      subtitleKey: 'moodRecHappyPlaySubtitle',
      color: Color(0xFFFF6B35),
      route: Routes.childPlay,
      icon: Icons.sports_esports_rounded,
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCALIZATION FALLBACKS (used when l10n context is unavailable)
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a hardcoded EN fallback for a recommendation title key.
String moodRecTitleFallback(String key) {
  const map = <String, String>{
    'moodRecHappyLearnTitle': 'Start Learning',
    'moodRecHappyPlayTitle': 'Play a Game',
    'moodRecHappyAiTitle': 'Chat with Buddy',
    'moodRecExcitedPlayTitle': 'Play Now!',
    'moodRecExcitedLearnTitle': 'Try a Puzzle',
    'moodRecExcitedAiTitle': 'Talk to Buddy',
    'moodRecCalmLearnTitle': 'Read & Learn',
    'moodRecCalmColoringTitle': 'Draw & Color',
    'moodRecCalmAiTitle': 'Explore with Buddy',
    'moodRecTiredColoringTitle': 'Light Coloring',
    'moodRecTiredStoryTitle': 'Listen to a Story',
    'moodRecSadStoryTitle': 'A Kind Story',
    'moodRecSadAiTitle': 'Talk to Buddy',
    'moodRecSadColoringTitle': 'Color a Rainbow',
    'moodRecAngryAiTitle': 'Calm Down',
    'moodRecAngryColoringTitle': 'Express Yourself',
    'moodRecAngryStoryTitle': 'A Peaceful Story',
  };
  return map[key] ?? key;
}

/// Returns a hardcoded EN fallback for a recommendation subtitle key.
String moodRecSubtitleFallback(String key) {
  const map = <String, String>{
    'moodRecHappyLearnSubtitle': 'Earn XP while you\'re happy!',
    'moodRecHappyPlaySubtitle': 'Have fun and earn rewards',
    'moodRecHappyAiSubtitle': 'Share your happiness!',
    'moodRecExcitedPlaySubtitle': 'Channel your energy!',
    'moodRecExcitedLearnSubtitle': 'Challenge your brain',
    'moodRecExcitedAiSubtitle': 'Buddy loves your energy!',
    'moodRecCalmLearnSubtitle': 'Perfect time to focus',
    'moodRecCalmColoringSubtitle': 'Create something beautiful',
    'moodRecCalmAiSubtitle': 'Discover new things',
    'moodRecTiredColoringSubtitle': 'Easy and relaxing',
    'moodRecTiredStorySubtitle': 'Sit back and enjoy',
    'moodRecSadStorySubtitle': 'Feel better with a story',
    'moodRecSadAiSubtitle': 'Buddy is here for you',
    'moodRecSadColoringSubtitle': 'Colors make you smile',
    'moodRecAngryAiSubtitle': 'Breathe and relax',
    'moodRecAngryColoringSubtitle': 'Draw your feelings',
    'moodRecAngryStorySubtitle': 'A calming adventure',
  };
  return map[key] ?? key;
}
