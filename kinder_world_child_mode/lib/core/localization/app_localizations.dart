import 'package:flutter/material.dart';
import 'l10n/app_localizations_en.dart';
import 'l10n/app_localizations_ar.dart';

abstract class AppLocalizations {
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // Common
  String get appTitle;
  String get welcome;
  String get next;
  String get back;
  String get continueText;
  String get skip;
  String get done;
  String get cancel;
  String get save;
  String get delete;
  String get edit;
  String get loading;
  String get error;
  String get notAvailable;
  String get connectionError;
  String get success;
  String get retry;
  String get noInternet;
  String get offlineMode;
  String get noInternetDescription;
  String get availableOffline;
  String get offlineDownloadedLessons;
  String get offlineSavedGames;
  String get offlineStories;
  String get offlineProgressTracking;
  String get checkingConnection;
  String get stillNoConnection;
  String get tryAgain;
  String get continueOffline;
  String get dataSyncTitle;
  String get syncReady;
  String get syncStarting;
  String get syncingChildProfiles;
  String get syncingProgressData;
  String get syncingActivities;
  String get syncFinalizing;
  String get syncCompleted;
  String get syncNow;
  String get syncChildProfilesLabel;
  String get syncProgressDataLabel;
  String get syncSettingsLabel;
  String get syncLastSyncLabel;
  String get syncedLabel;
  String syncedCount(int count);
  String activitiesCount(int count);
  String get errorTitle;
  String get errorDetailsLabel;
  String get goBack;
  String get reportIssue;
  String get errorReported;
  String get legalTitle;
  String get legalTermsTitle;
  String get legalPrivacyTitle;
  String get legalCoppaTitle;
  String get legalNoContent;
  String get legalTermsPlaceholder;
  String get legalPrivacyPlaceholder;
  String get legalCoppaPlaceholder;
  String get legalPlaceholder;
  String get legalTermsHeroTitle;
  String get legalTermsHeroSubtitle;
  String get legalTermsSectionTitle;
  String get legalTermsFooterText;
  String get legalPrivacyHeroTitle;
  String get legalPrivacyHeroSubtitle;
  String get legalPrivacySectionTitle;
  String get legalPrivacyFooterText;
  String get legalCoppaHeroTitle;
  String get legalCoppaHeroSubtitle;
  String get legalCoppaSectionTitle;
  String get legalCoppaFooterText;
  String get maintenanceTitle;
  String get maintenanceDescription;
  String get maintenanceEtaTitle;
  String get maintenanceEtaDuration;
  String get maintenanceEtaWindow;
  String get maintenanceWhatsComing;
  String get maintenanceFeatureAi;
  String get maintenanceFeatureGames;
  String get maintenanceFeatureSafety;
  String get maintenanceFeaturePerformance;
  String get maintenanceFollowUs;
  String openingLink(String target);
  String get helpSupportTitle;
  String get helpNeedHelpTitle;
  String get helpNeedHelpSubtitle;
  String get helpFaqTitle;
  String get helpFaqQ1;
  String get helpFaqA1;
  String get helpFaqQ2;
  String get helpFaqA2;
  String get helpFaqQ3;
  String get helpFaqA3;
  String get helpFaqQ4;
  String get helpFaqA4;
  String get helpFaqQ5;
  String get helpFaqA5;
  String get helpContactSupportTitle;
  String get helpEmailSupportTitle;
  String get helpLiveChatTitle;
  String get helpLiveChatSubtitle;
  String get helpPhoneSupportTitle;
  String get helpPhoneSupportSubtitle;
  String get helpResourcesTitle;
  String get helpUserGuide;
  String get helpAppUpdates;
  String appVersionLabel(String version);
  String get parentDashboardSubtitle;
  String get noChildrenAddedTitle;
  String get noChildrenAddedSubtitle;
  String get todayOverviewTitle;
  String get totalTimeLabel;
  String get avgXpLabel;
  String get viewDetailedReport;
  String get recentActivitiesTitle;
  String get viewAll;
  String get noRecentActivities;
  String completedActivity(String childName);
  String minutesToday(int minutes);
  String dayStreak(int days);
  String insightsSummary(String names, int totalActivities, int childCount);
  String get weeklyProgressTitle;
  String get timeLabel;
  String get avgScoreLabel;
  String get achievementPerfectScoreTitle;
  String get achievementPerfectScoreSubtitle;
  String get achievementMathMasterReportSubtitle;
  String get achievementFiveDayStreakSubtitle;
  String get minutesAgo;
  String get weekdayMon;
  String get weekdayTue;
  String get weekdayWed;
  String get weekdayThu;
  String get weekdayFri;
  String get weekdaySat;
  String get weekdaySun;
  String get currentPasswordLabel;
  String get currentPasswordHint;
  String get currentPassword;
  String get currentPasswordRequired;
  String get newPasswordLabel;
  String get newPasswordHint;
  String get newPassword;
  String get newPasswordRequired;
  String get confirmNewPassword;
  String get confirmNewPasswordRequired;
  String get confirmPasswordLabel;
  String get confirmPasswordHintAlt;
  String get updatePassword;
  String get passwordUpdatedSuccess;
  String get passwordChanged;
  String get passwordChangeFailed;
  String get privacySettingsError;
  String get retryAction;
  String get analyticsTitle;
  String get analyticsSubtitle;
  String get personalizedRecommendationsTitle;
  String get personalizedRecommendationsSubtitle;
  String get dataCollectionOptOutTitle;
  String get dataCollectionOptOutSubtitle;
  String get privacyInfoTitle;
  String get privacyInfoBody;
  String get searchFaqsHint;
  String get noFaqsYet;
  String get noResultsFound;
  String get helpPreparingArticles;
  String get noFaqFound;
  String get contactUsAction;
  String get contactUsIntro;
  String get contactEmailLabel;
  String get contactEmailValue;
  String get contactPhoneLabel;
  String get contactPhoneValue;
  String get contactHoursLabel;
  String get contactHoursValue;
  String get sendMessageTitle;
  String get supportCategoryLabel;
  String get supportCategoryLoginIssue;
  String get supportCategoryBillingIssue;
  String get supportCategoryChildContentIssue;
  String get supportCategoryTechnicalIssue;
  String get supportCategoryGeneralInquiry;
  String get subjectLabel;
  String get subjectHint;
  String get messageLabel;
  String get messageHint;
  String get subjectRequiredError;
  String get messageRequiredError;
  String get messageSent;
  String get messageSentSuccess;
  String get sendMessage;
  String get supportTicketHistoryTitle;
  String get supportTicketHistorySubtitle;
  String get supportTicketNoHistory;
  String get supportStatusOpen;
  String get supportStatusInProgress;
  String get supportStatusResolved;
  String get supportStatusClosed;
  String get supportReplyLabel;
  String get supportReplyHint;
  String get supportReplyAction;
  String get supportReplySentSuccess;
  String get supportAgentLabel;
  String get youLabel;
  String get subscriptionTitle;
  String get subscriptionActiveLabel;
  String get activeLabel;
  String get inactiveLabel;
  String get alertLabel;
  String get yourPlanIncludes;
  String planChildProfiles(int count);
  String get unlimitedActivities;
  String get advancedReportsLabel;
  String get offlineDownloadsLabel;
  String get prioritySupportLabel;
  String get billingInformation;
  String get nextPayment;
  String get amountLabel;
  String get paymentMethodLabel;
  String get manageBilling;
  String get availablePlans;
  String get recommendedLabel;
  String get currentPlanLabel;
  String get processingLabel;
  String get choosePlanLabel;
  String get basicFeaturesOnly;
  String get bestForFamilies;
  String get limitedActivities;
  String get oneChildProfile;
  String get upToThreeChildren;
  String get paletteDefault;
  String get paletteOceanBlue;
  String get palettePurpleNight;
  String get paletteForestGreen;
  String get paletteSunsetOrange;
  String get playTitle;
  String get playSubtitle;
  String get playEducationalGames;
  String get playEducationalGamesSubtitle;
  String get playInteractiveStories;
  String get playInteractiveStoriesSubtitle;
  String get playMusicSongs;
  String get playMusicSongsSubtitle;
  String get playEducationalVideos;
  String get playEducationalVideosSubtitle;
  String get categoryGames;
  String get categoryStories;
  String get categoryMusic;
  String get categoryVideos;
  String activityCount(int count);
  String get chooseActivity;
  String startingActivity(String title);
  String activityMinutes(int minutes);
  String activityXp(int xp);
  String get activityGame1Title;
  String get activityGame1Desc;
  String get activityGame2Title;
  String get activityGame2Desc;
  String get activityGame3Title;
  String get activityGame3Desc;
  String get activityGame4Title;
  String get activityGame4Desc;
  String get activityStory1Title;
  String get activityStory1Desc;
  String get activityStory2Title;
  String get activityStory2Desc;
  String get activityStory3Title;
  String get activityStory3Desc;
  String get activityStory4Title;
  String get activityStory4Desc;
  String get activityMusic1Title;
  String get activityMusic1Desc;
  String get activityMusic2Title;
  String get activityMusic2Desc;
  String get activityMusic3Title;
  String get activityMusic3Desc;
  String get activityMusic4Title;
  String get activityMusic4Desc;
  String get activityVideo1Title;
  String get activityVideo1Desc;
  String get activityVideo2Title;
  String get activityVideo2Desc;
  String get activityVideo3Title;
  String get activityVideo3Desc;
  String get activityVideo4Title;
  String get activityVideo4Desc;
  String get activityOfDayTreasureHuntTitle;
  String get activityOfDayTreasureHuntSubtitle;
  String get activityOfDayMissionTitle;
  String get activityOfDayFindColorsTitle;
  String get activityOfDayFindColorsSubtitle;
  String get activityOfDaySpotShapesTitle;
  String get activityOfDaySpotShapesSubtitle;
  String get activityOfDayShareSmileTitle;
  String get activityOfDayShareSmileSubtitle;
  String get activityOfDayTimeHint;
  String get activityOfDayCompletedCta;
  String get activityOfDayFinishCta;
  String get activityOfDayStartCta;
  String get splashTagline;

  // Authentication
  String get login;
  String get register;
  String get email;
  String get emailHint;
  String get emailRequired;
  String get parentEmail;
  String get password;
  String get passwordHint;
  String get passwordRequired;
  String get confirmPassword;
  String get forgotPassword;
  String get parentLogin;
  String get parentLoginSubtitle;
  String get orLabel;
  String get createAccount;
  String get childLogin;
  String get childId;
  String get picturePassword;
  String get selectPicturePassword;
  String get confirmPicturePassword;
  String get picturePasswordError;
  String get loginError;
  String get registerError;
  String get agreeToTermsError;
  String get registrationSuccess;
  String get registerSubtitle;
  String get fullNameLabel;
  String get fullNameHint;
  String get nameRequired;
  String get phoneNumberOptional;
  String get phoneNumberHint;
  String get passwordCreateHint;
  String get passwordCreateRequired;
  String get passwordUppercaseRequired;
  String get passwordNumberRequired;
  String get passwordSpecialRequired;
  String get confirmPasswordHint;
  String get confirmPasswordRequired;
  String get passwordsDoNotMatch;
  String get agreeToTermsPrefix;
  String get termsOfService;
  String get andLabel;
  String get privacyPolicy;
  String get alreadyHaveAccount;

  // ✅ Child Login Screen (NEW)
  String get chooseProfileToContinue;
  String get chooseYourProfile;
  String get clearSelection;
  String get noChildProfilesFound;
  String get childProfileNotFound;
  String get failedToStartSession;
  String get incorrectPicturePassword;
  String get childLoginNotFound;
  String get childLoginIncorrectPictures;
  String get childLoginMissingData;
  String get createChildProfile;
  String get childProfileBasicInfoTitle;
  String get childProfileBasicInfoSubtitle;
  String get childProfileAvatarTitle;
  String get childProfileAvatarSubtitle;
  String get childProfileInterestsTitle;
  String get childProfileInterestsSubtitle;
  String get childProfilePicturePasswordTitle;
  String get childProfilePicturePasswordSubtitle;
  String get childRegisterParentNotFound;
  String get childRegisterLimitReached;
  String get childRegisterForbidden;
  String get paywallTitle;
  String get paywallPrice;
  String get paywallSubscribe;
  String get paywallManagePaymentMethods;
  String get paymentMethodsTitle;
  String get paymentMethodsEmpty;
  String get noNotifications;
  String get addPaymentMethod;
  String get removePaymentMethod;
  String get openPaymentPortal;

  // ✅ parameterized strings (NEW)
  String yearsOld(int age);
  String levelXp(int level, int xp);

  // User Types
  String get selectUserType;
  String get selectUserTypeSubtitle;
  String get childMode;
  String get parentMode;
  String get teacherMode;
  String get parentModeDescription;
  String get childModeDescription;

  // Child Mode
  String get home;
  String get learn;
  String get play;
  String get aiBuddy;
  String get profile;
  String get hello;
  String get dailyGoal;
  String get continueLearning;
  String get recommendedForYou;
  String get activityOfTheDay;
  String get moodIndicator;
  String get happy;
  String get sad;
  String get excited;
  String get tired;
  String get angry;
  String get calm;

  // Learning
  String get educationalContent;
  String get behavioralSkills;
  String get skillfulActivities;
  String get subjects;
  String get mathematics;
  String get science;
  String get reading;
  String get history;
  String get geography;
  String get languages;
  String get socialStories;
  String get emotionCards;
  String get problemSolving;
  String get drawing;
  String get music;
  String get crafts;
  String get cooking;
  String get quiz;
  String get lesson;
  String get game;
  String get story;
  String get video;
  String get complete;
  String get start;

  // Entertainment
  String get entertainment;
  String get educationalGames;
  String get puppetShows;
  String get interactiveStories;
  String get miniChallenges;
  String get natureVideos;
  String get brainTeasers;
  String get cartoonMovies;
  String get songs;
  String get funnyClips;

  // AI Buddy
  String get askMeAnything;
  String get quickActions;
  String get recommendLesson;
  String get suggestGame;
  String get tellStory;
  String get funFact;
  String get motivation;
  String typeMessage(String name);
  String get voiceChat;
  String get textChat;
  String get aiThinking;
  String get aiError;

  // Progress & Rewards
  String get progress;
  String get xp;
  String get level;
  String get streak;
  String get achievements;
  String get badges;
  String get dailyStreak;
  String get weeklyProgress;
  String get monthlyProgress;

  // Parent Dashboard
  String get parentDashboard;
  String get overview;
  String get childProfiles;
  String get addChild;
  String get editChild;
  String get childName;
  String get childAge;
  String get childInterests;
  String get avatar;
  String get saveChanges;

  // Reports
  String get reports;
  String get activityReports;
  String get learningProgress;
  String get skillDevelopment;
  String get behavioralProgress;
  String get screenTimeReport;
  String get aiInsights;
  String get recentActivities;
  String get timeSpent;
  String get completedActivities;
  String get averageScore;
  String get strengths;
  String get areasForImprovement;

  // Parental Controls
  String get parentalControls;
  String get contentRestrictions;
  String get screenTime;
  String get dailyLimit;
  String get allowedHours;
  String get sleepMode;
  String get emergencyLock;
  String get contentFiltering;
  String get ageAppropriate;
  String get blockContent;
  String get allowContent;
  String get timeLimits;
  String get breakReminders;
  String get smartControl;
  String get aiRecommendations;

  // Settings
  String get settings;
  String get accountSection;
  String get familySection;
  String get preferencesSection;
  String get supportSection;
  String get legalSection;
  String get profileLabel;
  String get changePassword;
  String get helpFaq;
  String get about;
  String get coppaCompliance;
  String get logout;
  String comingSoon(String title);
  String get notifications;
  String get privacySettings;
  String get dataSharing;
  String get parentalConsent;
  String get accessibility;
  String get fontSize;
  String get contrast;
  String get language;
  String get english;
  String get arabic;
  String get theme;
  String get mode;
  String get systemMode;
  String get themePalette;
  String get themePaletteHint;
  String get lightMode;
  String get darkMode;
  String get eyeFriendlyMode;
  String get auto;
  String get sound;
  String get soundEffects;
  String get backgroundMusic;
  String get voiceGuidance;
  String get appSettings;
  String get editProfile;
  String get changeAvatar;
  String get resetProgress;
  String get resetProgressTitle;
  String get resetProgressMessage;
  String get reset;
  String get progressReset;

  // General Labels
  String get week;
  String get month;
  String get year;
  String get yearlyProgress;
  String get recentAchievements;
  String get activityBreakdown;
  String get learningProgressReports;
  String get trackChildDevelopment;
  String get reportsAndAnalytics;
  String get noChildSelected;
  String get addChildToViewReports;
  String get lessonsCompletedLabel;
  String get mostUsedContentLabel;
  String get completionRateLabel;
  String get dailyTrendLabel;
  String get moodTrendLabel;
  String get currentMoodLabel;
  String get recordedSessionsNotice;
  String get profileFallbackNotice;
  String get noRecordedActivityYet;

  // Parental Controls (extended)
  String get contentRestrictionsAndScreenTime;
  String get manageChildAccess;
  String get screenTimeLimits;
  String get timeRestrictions;
  String get emergencyControls;
  String get lockAppNow;
  String get hoursPerDay;
  String get requireApproval;
  String get bedtime;
  String get wakeTime;

  // Child Management (extended)
  String get childManagement;
  String get manageChildProfiles;
  String get addEditManageChildren;
  String get yourChildren;
  String get noChildProfilesYet;
  String get tapToAddChild;
  String get addChildProfiles;
  String get editProfiles;
  String get picturePasswords;
  String get configurePreferences;
  String get deactivateProfiles;
  String get childProfileAdded;
  String get childProfileAddFailed;

  // Notifications (extended)
  String get markAllRead;
  String notificationDailyGoal(String name, int activities);
  String notificationScreenTime(String name, int hours);
  String notificationAchievement(String name, String badge);
  String get notificationWeeklyReport;
  String notificationMilestone(String name, int count);
  String notificationRecommendation(String name);
  String notificationLessonCompleted(String name, String lessonTitle);
  String notificationStreakReached(String name, int streakDays);
  String notificationInactive(String name, int days);
  String get hoursAgo;
  String get daysAgo;
  String get justNow;

  // Welcome & Onboarding
  String get welcomeTitle;
  String get welcomeSubtitle;
  String get chooseLanguageTitle;
  String get chooseLanguageSubtitle;
  String get languageEnglishShort;
  String get languageArabicShort;
  String get educational;
  String get funGames;
  String get aiPowered;
  String get safe;
  String get getStarted;
  String get coppaGdprNote;
  String get onboardingLearn;
  String get onboardingPlay;
  String get onboardingGrow;
  String get onboardingLearnSubtitle;
  String get onboardingLearnDescription;
  String get onboardingPlaySubtitle;
  String get onboardingPlayDescription;
  String get onboardingGrowSubtitle;
  String get onboardingGrowDescription;

  // Child Profile
  String get yourProgress;
  String get yourInterests;
  String get weeklyChallenge;
  String get activities;
  String levelExplorer(int level);
  String xpToLevel(int level);
  String helloName(String name);
  String get levelsTitle;
  String get levelJourneySubtitle;
  String get achievementFirstQuizTitle;
  String get achievementFirstQuizDescription;
  String get achievementFiveDayStreakTitle;
  String get achievementFiveDayStreakDescription;
  String get achievementMathMasterTitle;
  String get achievementMathMasterDescription;
  String get levelLockedMessage;
  String levelStartMessage(int level);

  // Child Settings & Profile Helpers
  String get searchSettingsHint;
  String get appSettingsSection;
  String get themes;
  String get lightAndCalm;
  String get aboutUs;
  String get noSettingsFound;
  String get selectLanguage;
  String languageChanged(String languageName);
  String get englishUs;
  String get chooseAvatar;
  String get customizeProfile;
  String get customizeProfileSubtitle;
  String get frameColors;
  String get frameStyles;
  String get profileStyle;
  String get frameStyleClassic;
  String get frameStyleGlow;
  String get frameStyleStars;
  String get frameStyleShield;
  String get customizationSaved;
  String get lockedLabel;
  String get unlockedLabel;
  String unlockAtLevel(int level);
  String unlockWithStreak(int streak);
  String unlockWithActivities(int count);
  String get avatarSaved;
  String get pleaseSelectThreePictures;
  String get failedToUpdatePicturePassword;
  String get profileUpdated;
  String get changeAvatarFromProfile;
  String get nameLabel;
  String get enterYourName;
  String get pleaseEnterName;
  String get chooseExactlyThreePictures;
  String get darkLight;
  String get chooseCalmColor;
  String get kinderWorldAppTitle;
  String get aboutAppName;
  String versionLabel(String version);
  String get aboutAppDescription;
  String get aboutDescription;
  String lastUpdated(String date);
  String privacyLastUpdated(String date);
  String get privacyIntroTitle;
  String get privacyIntroBody;
  String get privacyDataCollectionTitle;
  String get privacyDataCollectionBody;
  String get privacySecurityTitle;
  String get privacySecurityBody;
  String get levels;
  String get levelsSubtitle;
  String get open;
  String get currentLabel;
  String get newLabel;
  String get finishPreviousLevel;
  String levelNumber(int level);
  String startLevel(int level);
  String playLevel(int level);
  String levelKeepGoing(int level);
  String get achievementFirstQuizSubtitle;
  String get achievementStreakTitle;
  String get achievementStreakSubtitle;
  String get achievementMathMasterSubtitle;

  // Subscription
  String get subscription;
  String get freeTrial;
  String get familyPlan;
  String get premiumFeatures;
  String get upgradeNow;
  String get choosePlan;
  String get currentPlan;
  String get planFree;
  String get planPremium;
  String get planFamilyPlus;
  String get planFeatureInPremium;
  String planChildLimit(int count);
  String get planUnlimitedChildren;
  String get planBasicReports;
  String get planAdvancedReports;
  String get planAiInsightsPro;
  String get planOfflineDownloads;
  String get planSmartControls;
  String get planExclusiveContent;
  String get planFamilyDashboard;
  String get freePlanChildLimit;
  String get manageSubscription;
  String get paymentMethod;
  String get billingInfo;
  String get trialEnds;
  String get subscriptionActive;
  String get subscriptionExpired;

  // Safety & Privacy
  String get safety;
  String get safetyDashboard;
  String get safetyDashboardSubtitle;
  String get privacy;
  String get childProtection;
  String get dataSecurity;
  String get parentalConsentRequired;
  String get minimalDataCollection;
  String get encryptedStorage;

  // Help & Support
  String get help;
  String get support;
  String get faq;
  String get contactUs;
  String get tutorial;
  String get walkthrough;
  String get feedback;

  // System Messages
  String get maintenanceMode;
  String get updateRequired;
  String get syncData;
  String get dataSyncComplete;
  String get sessionExpired;
  String get logoutConfirm;
  String get exitConfirm;
  String get deleteConfirm;
  String get deleteChildTitle;
  String get deleteChildDescription;
  String get deleteChildSuccess;
  String get deleteChildFailed;

  // Validation
  String get fieldRequired;
  String get invalidEmail;
  String get parentEmailNotFound;
  String get passwordTooShort;
  String get passwordsDontMatch;
  String get invalidAge;
  String get selectAvatar;

  // Accessibility
  String get increaseFontSize;
  String get decreaseFontSize;
  String get highContrast;
  String get screenReader;
  String get voiceCommands;
  String get switchAccess;

  // Parent Settings
  String get parentProfile;
  String get parentChangePassword;
  String get parentTheme;
  String get parentPrivacySettings;
  String get parentHelp;
  String get parentContactUs;
  String get parentAbout;
  String buildLabel(String buildNumber);
  String get subscriptionActivationFailed;
  String planActivated(String planName);
  String get nextPaymentSampleDate;
  String get sampleAmountPerMonth;
  String get samplePaymentMethod;
  String get billingTitle;
  String get billingComingSoon;

  // ── Parent Forgot Password Screen ──
  String get resetPassword;
  String get parentAccount;
  String get forgotYourPassword;
  String get forgotPasswordDescription;
  String get forgotPasswordTitle;
  String get forgotPasswordSubtitle;
  String get emailAddress;
  String get emailPlaceholder;
  String get emailValidationEmpty;
  String get emailValidationInvalid;
  String get spamFolderNote;
  String get sendResetLink;
  String get resetLinkSent;
  String get backToLogin;
  String get checkYourInbox;
  String resetLinkSentTo(String email);
  String get step1OpenEmail;
  String get step2ClickLink;
  String get step3CreatePassword;
  String get didntReceiveIt;

  // ── Child Forgot Password Screen ──
  String get needHelp;
  String get wellAskYourParent;
  String get forgotYourPictures;
  String get forgotPicturesDescription;
  String get childForgotPasswordTitle;
  String get childForgotPasswordSubtitle;
  String get yourChildId;
  String get childIdHint;
  String get childIdRequired;
  String get parentsEmail;
  String get parentEmailHint;
  String get parentEmailRequired;
  String get parentEmailInvalid;
  String get parentWillGetEmail;
  String get askParentForHelp;
  String get backToChildLogin;
  String get messageSentTitle;
  String messageSentToParent(String email);
  String get whatHappensNext;
  String get childStep1;
  String get childStep2;
  String get childStep3;
  String get tryAgainDifferentInfo;
  String get childNameLabel;
  String get pleaseEnterChildName;
  String get childNameHint;
  String get childNameRequired;
  String get childAgeLabel;
  String get childAgeHint;
  String get childAgeRequired;
  String get selectAvatarLabel;
  String get setPicturePassword;
  String get createProfile;

  // ── Parent Register Screen ──
  String get personalInformation;
  String get securitySection;
  String get noActiveAlerts;
  String get accountCreatedWelcome;

  // ── UI Redesign — Role Selection / Login / Register / Widgets ──
  String get signIn;
  String get whoIsUsingKinderWorld;
  String get secureAndStructured;
  String get funAndPlayful;
  String get loginFailed;
  String get parentPortal;
  String get useGmailOrMicrosoftEmail;
  String get registrationFailed;
  String get nameTooShort;
  String get useAllowedEmail;
  String get passwordTooShortRegister;
  String get joinKinderWorld;
  String get passwordWeak;
  String get passwordFair;
  String get passwordStrong;
  String get passwordVeryStrong;

  // ── Parent PIN Screen ──
  String get parentAccess;
  String get parentPinTitle;
  String get parentPinSubtitle;
  String get parentPinHint;
  String get parentPinError;
  String get parentPinSuccess;
  String get parentPinVerify;
  String get parentPinForgot;
  String get enterPinToContinue;
  String get forgotPin;
  String get contactSupportToResetPin;
  String get parentPinCreateTitle;
  String get parentPinCreateSubtitle;
  String get parentPinConfirmSubtitle;
  String get parentPinChangeTitle;
  String get parentPinEnterCurrent;
  String get parentPinEnterNew;
  String get parentPinConfirmNew;
  String get parentPinCreatedSuccess;
  String get parentPinChangedSuccess;
  String get parentPinResetRequested;
  String parentPinLockedUntil(String time);
  String get manageParentPin;
  String get manageParentPinSubtitle;

  // ── Child Header ──
  String get friendFallback;
  String get childHeaderGreeting;
  String get childHeaderSubtitle;
  String levelLabel(int level);

  // ── Router fallback messages ──
  String get unexpectedError;
  String get pageNotFound;

  // ── No Internet Screen (specific) ──
  String get noInternetConnection;
  String get pleaseTryAgain;
  String get checkYourConnection;
  String get checkWifiConnection;
  String get checkMobileData;
  String get restartRouter;

  // ── Error Screen ──
  String get oopsSomethingWentWrong;

  // ── Maintenance Screen ──
  String get estimatedCompletion;
  String get followUsForUpdates;

  // ── Help & Support Screen (extra) ──
  String get weAreHereToSupportYou;
  String get emailSupport;
  String get liveChat;
  String get available247;
  String get phoneSupport;
  String get phoneNumber;
  String get additionalResources;
  String get privacyPolicyResource;
  String get termsOfServiceResource;

  // ── Data Sync Screen (extra) ──
  String get hoursAgoSync;

  // ── AI Buddy Screen ──
  String get aiBuddyName;
  String get aiBuddyOnline;
  String get aiCompanionSubtitle;
  String get tapMicToSpeak;
  String get askKinderAnything;
  String get aiInitialGreeting;
  String get aiWelcomeGreeting;
  String get aiMathResponse;
  String get aiStoryResponse;
  String get aiGameResponse;
  String get aiSadResponse;
  String get aiTiredResponse;
  String get aiDefaultResponse;
  String get aiQuickActionLessonResponse;
  String get aiQuickActionGameResponse;
  String get aiQuickActionStoryResponse;
  String get aiQuickActionFactResponse;
  String get aiQuickActionMotivationResponse;
  String get aiQuickActionFallbackResponse;

  // ── Lesson Flow Screen ──
  String get lessonFinish;
  String get startLearning;
  String get learningContent;
  String get todayWeWillLearn;
  String get lessonContentFallback;
  String get lessonContentPlaceholder;
  String get letsPractice;
  String get interactiveActivity;
  String get tapCorrectAnswer;
  String get quickQuiz;
  String questionOf(int current, int total);
  String get whatDidYouLearn;
  String get lessonAnswerOptionA;
  String get lessonAnswerOptionB;
  String get lessonAnswerOptionC;
  String get greatJob;
  String get youCompletedLesson;
  String get correct;
  String get xpEarned;
  String get daysLabel;
  String get xpReward;
  String get difficulty;
  String get beginner;
  String get intermediate;
  String get advanced;
  String get countingNumbers;
  String get countingNumbersDesc;
  String get lessonTime;

  // ── Coloring Gallery Screen ──
  String get coloringTitle;
  String get all;
  String get noColoringPages;
  String get tapToColor;
  String coloringPageN(int n);

  // ── Subject Screen ──
  String get availableLessons;
  String lessonDurationMin(int minutes);

  // ── Subscription Screen (extra) ──
  String get freePlan;
  String get freePlanPrice;
  String get familyPlanLabel;
  String get familyPlanPrice;

  // ── Theme Mode Toggle ──
  String get darkLabel;
  String get lightLabel;

  // ── Child Login Screen (extra) ──
  String get pleaseEnterRealName;

  // ── Learn Screen ──
  String get searchPages;
  String get letsExploreAndLearn;
  String get noPagesFound;
  String get categoryBehavioral;
  String get categoryEducational;
  String get categorySkillful;
  String get categoryEntertaining;

  // ── Entertaining Screen ──
  String get foundSomethingFun;

  // ── Behavioral Screen ──
  String get letsPracticeKindness;

  // ── Method Content Screen ──
  String get letsTryNewSkill;

  // ── Skillful Screen ──
  String get letsCreateSomethingFun;
  String get searchActivities;
  String get noActivitiesFound;
  String get watchNow;
  String get letsCreate;
  String followStepsInVideo(String title);
  String get imDone;

  // ── Educational Screen ──
  String get letsLearnSomethingNew;
  String get searchLessons;
  String get noLessonsFound;

  // ── Lesson Detail / Quiz Screen ──
  String get readyForFunQuiz;
  String get playQuizToEarnStars;
  String get startQuiz;
  String get quizTime;
  String get youCompletedQuiz;
  String get awesome;
  String get nextQuestion;

  // ── Welcome Screen features ──
  String get interactiveLessons;
  String get interactiveLessonsDesc;
  String get learnThroughPlay;
  String get learnThroughPlayDesc;
  String get personalizedForChild;
  String get personalizedForChildDesc;
  String get coppaGdprCompliant;
  String get coppaGdprCompliantDesc;

  // ── Coloring Page Screen ──
  String get tapShapeToFill;
  String get undo;
  String get redo;
  String get eraser;
  String get awesomeColoring;
  String couldNotLoadColoringPage(String error);
  String interactiveFillDisabled(String error);

  // ── Parent Settings Screen ──
  String get parentFallback;
  String get changePasswordSubtitle;
  String get notificationsSubtitle;
  String get childProfilesSubtitle;
  String get parentalControlsSubtitle;
  String get premiumActive;
  String get upgradePlan;
  String get languageSubtitle;
  String get themeSubtitle;
  String get privacySettingsSubtitle;
  String get helpFaqSubtitle;
  String get contactUsSubtitle;
  String get aboutSubtitle;
  String get logoutTitle;
  String get logoutMessage;

  // ── Child Home Screen ──
  String get noActiveChildSession;
  String get signInToContinue;
  String get goToLogin;
  String get exploreLessons;
  String get newTopicsAwait;
  String get goLabel;
  String get goalComplete;
  String completeActivitiesToday(int n);
  String get xpBonusEarned;
  String get myActivities;
  String get exploreNewActivities;
  String get discoverSomethingAmazing;
  String get xpBonusLabel;
  String xpDisplay(int xp);
  String levelBubble(int level);

  // ── Play Screen ──
  String get nothingFound;
  String get tryDifferentSearch;
  String get featured;
  String get allVideos;
  String get playTime;
  String get safeAndFunVideos;
  String get safeMode;
  String get searchVideos;
  String get fanFavourite;
  String get todaysPick;
  String get topRated;
  String get kindnessTab;
  String get learningTab;
  String get skillsTab;

  // ── Parent Dashboard Screen ──
  String get goodMorningOverview;
  String get goodAfternoonOverview;
  String get goodEveningOverview;
  String get noChildrenAddedSubtitleDashboard;
  String childrenLinkedCount(int n);
  String get manage;
  String xpProgressDisplay(int current, int max);
  String get aggregatedAcrossChildren;
  String get minutesLabel;
  String get premiumAnalysis;
  String get viewFullReport;
  String completedAnActivity(String name);
  String get weeklyActivity;
  String get activitiesCompletedPerDay;

  // ── Subscription Screen (extra) ──
  String get foreverLabel;
  String get perMonthLabel;

  // ── Notifications Screen ──
  String get allCaughtUp;
  String get notificationFallback;

  // ── Reports Screen ──
  String ageLabel(int age);

  // ── Parent Child Profile Screen ──
  String get xpProgress;
  String xpValue(int xp);
  String xpToNextLevel(int xp);
  String levelBadge(int level);

  // ── About Screen ──
  String versionBuildLabel(String version, String build);
  String get loadingVersion;
  String get aboutFallbackText;

  // ── Child Home Screen (motivational / axis) ──
  String get funTab;
  String streakOnFire(int streak);
  String streakDaysStrong(int streak);
  String activitiesCompletedAmazing(int count);
  String get readyForAdventure;
  String get todayLabel;
  String get yesterdayLabel;
  String daysAgoCount(int count);
  String minutesShort(int minutes);
  String get historySharingStars;
  String get historyKindWords;
  String get historyHelpingHands;
  String get historyNumbersAdventure;
  String get historyColorQuest;
  String get historyStoryTime;
  String get historyPuzzleBuilder;
  String get historyShapeMatch;
  String get historyMemoryGame;
  String get historyDanceParty;
  String get historySingAlong;
  String get historyMagicShow;
  String get songsAndMusic;
  String get entertainmentBrainTeasers;
  String get entertainmentGames;
  String get entertainmentCartoons;
  String get contentPuzzleGame;
  String get contentRacingCars;
  String get contentAdventureTime;
  String get contentFunnyAnimals;
  String get contentSpaceHeroes;
  String get contentMagicWorld;
  String get contentAbcSong;
  String get contentBabyShark;
  String get contentTwinkleStar;
  String get videoTomAndJerryKeepCalm;
  String get videoMomoAndMimiArabic;
  String get videoKindnessChallenge;
  String get videoBuildAndCreate;
  String get videoMathBasicsFun;
  String get videoScienceWonders;
  String get videoColoringFun;
  String get videoAlphabetSong;
  String get videoAnimalFriends;
  String get videoSharingTime;
  String get videoPuzzlePlay;
  String get activityRespectSharing;
  String get skillCooking;
  String get skillCookingDesc;
  String get skillDrawing;
  String get skillDrawingDesc;
  String get skillColoringDesc;
  String get skillMusicDesc;
  String get skillSinging;
  String get skillSingingDesc;
  String get skillHandcrafts;
  String get skillHandcraftsDesc;
  String get skillSports;
  String get skillSportsDesc;
  String skillVideoBasics(String skill);
  String skillVideoFun(String skill);
  String skillVideoAdvanced(String skill);
  String skillVideoMastering(String skill);
  String get lessonIntroductionToBasics;
  String get lessonAdvancedConcepts;
  String get lessonIntermediatePractice;
  String get lessonFunWithMath;
  String get lessonDeepDive;

  // ── Admin Portal ──────────────────────────────────────────────────────────
  // Login screen
  String get adminWelcome;
  String get adminLoginSubtitle;
  String get adminEmail;
  String get adminEmailRequired;
  String get adminEmailInvalid;
  String get adminPassword;
  String get adminPasswordRequired;
  String get adminSignIn;
  String get adminLoginFooter;

  // Dashboard / shell
  String get adminDashboard;
  String get adminDashboardWelcome;
  String get adminDashboardSubtitle;
  String get adminDashboardPermissionsTitle;

  // Sidebar labels
  String get adminSidebarOverview;
  String get adminSidebarUsers;
  String get adminSidebarChildren;
  String get adminSidebarContent;
  String get adminSidebarReports;
  String get adminSidebarSupport;
  String get adminSidebarSubscriptions;
  String get adminSidebarSettings;
  String get adminSidebarAudit;
  String get adminSidebarAdmins;

  // Auth / session
  String get adminLogout;
  String get adminLogoutConfirm;
  String get adminSessionExpired;

  // Access control
  String get adminAccessDenied;
  String get adminPermissionDenied;
  String get adminPermissionDeniedMessage;
  String get adminDisabledAccount;

  // UI Tooltips
  String get adminMenuTooltip;
  String get adminRefreshTooltip;

  // Roles
  String get adminRoleSuperAdmin;
  String get adminRoleContentAdmin;
  String get adminRoleSupportAdmin;
  String get adminRoleAnalyticsAdmin;
  String get adminRoleFinanceAdmin;

  // Admin Management
  String get adminAdminsTitle;
  String get adminAdminsSubtitle;
  String get adminAdminsIdLabel;
  String get adminAdminsUsersTab;
  String get adminAdminsRolesTab;
  String get adminAdminsSearchLabel;
  String get adminAdminsStatusFilter;
  String get adminAdminsCreateAction;
  String get adminAdminsCreateTitle;
  String get adminAdminsNameField;
  String get adminAdminsEmailField;
  String get adminAdminsPasswordField;
  String get adminAdminsInitialRolesLabel;
  String get adminAdminsCreatedMessage;
  String get adminAdminsEditTitle;
  String get adminAdminsPasswordHelper;
  String get adminAdminsUpdatedMessage;
  String get adminAdminsEnableTitle;
  String get adminAdminsDisableTitle;
  String get adminAdminsEnableConfirm;
  String get adminAdminsDisableConfirm;
  String get adminAdminsEnableAction;
  String get adminAdminsDisableAction;
  String get adminAdminsEnabledMessage;
  String get adminAdminsDisabledMessage;
  String get adminAdminsAssignRoleTitle;
  String get adminAdminsAssignRoleAction;
  String get adminAdminsRoleAssignedMessage;
  String get adminAdminsRemoveRoleTitle;
  String adminAdminsRemoveRoleConfirm(String roleName);
  String get adminAdminsRemoveRoleAction;
  String get adminAdminsRoleRemovedMessage;
  String get adminAdminsCreateRoleTitle;
  String get adminAdminsCreateRoleAction;
  String get adminAdminsRoleNameField;
  String get adminAdminsRoleDescriptionField;
  String adminRoleStats(int permissionCount, int adminCount);
  String get adminAdminsRoleCreatedMessage;
  String get adminAdminsEditRoleTitle;
  String get adminAdminsEditRoleAction;
  String get adminAdminsRoleUpdatedMessage;
  String get adminAdminsPermissionsUpdatedMessage;
  String get adminAdminsRolesSection;
  String get adminAdminsPermissionsSection;
  String get adminAdminsSavePermissionsAction;
  String get adminAdminsNoSelection;
  String get adminAdminsNoRoleSelection;
  String get adminAdminsCurrentAdminHint;
  String get adminAdminsEditAction;

  // User Status
  String get adminUsersStatusAll;
  String get adminUsersStatusActive;
  String get adminUsersStatusDisabled;

  // Subscriptions
  String get adminSubscriptionsTitle;
  String get adminSubscriptionsSubtitle;
  String get adminSubscriptionsSearchLabel;
  String get adminSubscriptionsStatusFilter;
  String get adminSubscriptionsStatusAll;
  String get adminSubscriptionsStatusActive;
  String get adminSubscriptionsStatusFree;
  String get adminSubscriptionsStatusDisabled;
  String get adminSubscriptionsPlanFilter;
  String get adminSubscriptionsPlanAll;
  String get adminSubscriptionsNoItems;
  String get adminSubscriptionsNoSelection;
  String get adminSubscriptionsUserName;
  String get adminSubscriptionsStatusLabel;
  String get adminSubscriptionsChildrenMetric;
  String get adminSubscriptionsPaymentMethodsMetric;
  String get adminSubscriptionsFeaturesTitle;
  String get adminSubscriptionsOverrideTitle;
  String get adminSubscriptionsOverrideAction;
  String get adminSubscriptionsCancelTitle;
  String get adminSubscriptionsCancelConfirm;
  String get adminSubscriptionsCancelAction;
  String get adminSubscriptionsRefundAction;
  String get adminSubscriptionsRefundNotSupported;

  // Users Details & Management
  String adminUsersDetailTitle(String email);
  String get adminUsersOverviewCard;
  String get adminUsersNameField;
  String get adminUsersEmailField;
  String get adminUsersPlanColumn;
  String get adminUsersStatusColumn;
  String get adminUsersActivityCard;
  String get adminUsersChildrenColumn;
  String get adminUsersNotificationsMetric;
  String get adminUsersSupportMetric;
  String get adminUsersLastUpdatedMetric;
  String get adminUsersChildrenSection;
  String get adminUsersNotificationsSection;
  String get adminUsersSupportSection;
  String get adminPlanFree;
  String get adminPlanPremium;
  String get adminPlanFamilyPlus;
  String get adminUsersEditTitle;
  String get adminUsersPlanField;
  String get adminUsersUpdatedMessage;
  String get adminUsersEnableTitle;
  String get adminUsersDisableTitle;
  String get adminUsersEnableConfirm;
  String get adminUsersDisableConfirm;
  String get adminUsersEnableAction;
  String get adminUsersDisableAction;
  String get adminUsersEnabledMessage;
  String get adminUsersDisabledMessage;
  String get adminUsersTitle;
  String get adminUsersSubtitle;
  String get adminUsersSearchLabel;
  String get adminUsersStatusFilter;
  String get adminUsersNameColumn;
  String get adminUsersEmailColumn;
  String get adminUsersActionsColumn;
  String get adminUsersViewAction;

  // Children Management
  String get adminChildrenTitle;
  String get adminChildrenNoChildren;
  String get adminChildrenSubtitle;
  String get adminChildrenParentFilter;
  String get adminChildrenAgeFilter;
  String get adminChildrenStatusFilter;
  String get adminChildrenNameColumn;
  String get adminChildrenParentColumn;
  String get adminChildrenAgeColumn;
  String get adminChildrenStatusColumn;
  String get adminChildrenActionsColumn;
  String get adminChildrenEditTitle;
  String get adminChildrenNameField;
  String get adminChildrenAgeField;
  String get adminChildrenAvatarField;
  String get adminChildrenUpdatedMessage;
  String get adminChildrenDeactivateTitle;
  String get adminChildrenDeactivateConfirm;
  String get adminChildrenDeactivateAction;
  String get adminChildrenDeactivatedMessage;
  String adminChildrenDetailTitle(String name);
  String get adminChildrenOverviewCard;
  String get adminChildrenProgressCard;
  String get adminChildrenProgressDaysMetric;
  String get adminChildrenProgressEventsMetric;
  String get adminChildrenMilestonesSection;
  String get adminChildrenActivitySection;

  // Audit Logs
  String get adminAuditTitle;
  String get adminAuditSubtitle;
  String get adminAuditAdminFilter;
  String get adminAuditActionFilter;
  String get adminAuditDateFromFilter;
  String get adminAuditDateToFilter;
  String get adminAuditApplyFilters;
  String get adminAuditActionColumn;
  String get adminAuditEntityColumn;
  String get adminAuditAdminColumn;
  String get adminAuditTimeColumn;
  String get adminAuditNetworkColumn;
  String get adminAuditNoLogs;

  // Support Tickets
  String get adminSupportReply;
  String get adminSupportReplyHint;
  String get adminSupportReplySuccess;
  String get adminSupportAssignSuccess;
  String get adminSupportClose;
  String get adminSupportCloseConfirm;
  String get adminSupportCloseSuccess;
  String get adminSupportTicketsTitle;
  String get adminSupportTicketsSubtitle;
  String get adminSupportStatusFilter;
  String get adminSupportStatusAll;
  String get adminSupportStatusOpen;
  String get adminSupportStatusInProgress;
  String get adminSupportStatusResolved;
  String get adminSupportStatusClosed;
  String get adminSupportNoTickets;
  String adminSupportMessagesCount(int count);
  String get adminSupportNoTicketSelected;
  String get adminSupportRequester;
  String get adminSupportAssignee;
  String get adminSupportCategoryFilter;
  String get adminSupportCategoryAll;
  String get adminSupportCategoryLabel;
  String get adminSupportAssignedToMe;
  String get adminSupportThread;
  String get adminSupportAssign;
  String get adminSupportResolve;
  String get adminSupportResolveSuccess;

  // Content Management System (CMS)
  String get adminCmsTypeLesson;
  String get adminCmsTypeStory;
  String get adminCmsTypeVideo;
  String get adminCmsTypeActivity;
  String get adminCmsStatusDraft;
  String get adminCmsStatusReview;
  String get adminCmsStatusPublished;
  String get adminCmsCategoryCreateTitle;
  String get adminCmsCategoryEditTitle;
  String get adminCmsCategorySlug;
  String get adminCmsTitleEnLabel;
  String get adminCmsTitleArLabel;
  String get adminCmsDescriptionEnLabel;
  String get adminCmsDescriptionArLabel;
  String get adminCmsCategorySaved;
  String get adminCmsDeleteCategoryTitle;
  String get adminCmsDeleteCategoryConfirm;
  String get adminCmsCreateContentTitle;
  String get adminCmsEditContentTitle;
  String get adminCmsCategoryLabel;
  String get adminCmsNoCategory;
  String get adminCmsTypeLabel;
  String get adminCmsStatusLabel;
  String get adminCmsBodyEnLabel;
  String get adminCmsBodyArLabel;
  String get adminCmsThumbnailLabel;
  String get adminCmsAgeGroupLabel;
  String get adminCmsMetadataLabel;
  String get adminCmsPreviewTitle;
  String get adminCmsLinkedQuizzes;
  String get adminCmsCreateQuizTitle;
  String get adminCmsEditQuizTitle;
  String get adminCmsLinkedContentLabel;
  String get adminCmsNoLinkedContent;
  String get adminCmsQuestionsJsonLabel;
  String get adminCmsTitle;
  String get adminCmsSubtitle;
  String get adminCmsCategoriesTab;
  String get adminCmsContentsTab;
  String get adminCmsQuizzesTab;
  String get adminCmsAddCategory;
  String get adminCmsCategoryUsage;
  String get adminCmsSearchLabel;
  String get adminCmsStatusAll;
  String get adminCmsAllCategories;
  String get adminCmsAddContent;
  String get adminCmsPreviewAction;
  String get adminCmsUnpublishAction;
  String get adminCmsPublishAction;
  String get adminCmsAddQuiz;
  String get adminCmsQuestionsLabel;
  String get adminCmsDeleteContentTitle;
  String get adminCmsDeleteContentConfirm;
  String get adminCmsDeleteQuizTitle;
  String get adminCmsDeleteQuizConfirm;
  String get adminCmsQuizSaved;
  String get adminCmsContentSaved;
  String get adminCmsStructuredMetadataTitle;
  String get adminCmsAdvancedJsonTitle;
  String get adminCmsAdvancedJsonHelp;
  String get adminCmsMetadataDurationLabel;
  String get adminCmsMetadataDifficultyLabel;
  String get adminCmsMetadataFeaturedLabel;
  String get adminCmsMetadataTagsLabel;
  String get adminCmsPreviewEnglishSection;
  String get adminCmsPreviewArabicSection;
  String get adminCmsPreviewMetadataSection;
  String get adminCmsPreviewQuestionsSection;
  String get adminCmsPreviewEmpty;
  String get adminCmsQuizPreviewAction;
  String get adminCmsPublishConfirmTitle;
  String get adminCmsPublishConfirmMessage;
  String get adminCmsUnpublishConfirmTitle;
  String get adminCmsUnpublishConfirmMessage;
  String get adminCmsPublishSuccess;
  String get adminCmsUnpublishSuccess;
  String get adminCmsQuestionAdd;
  String adminCmsQuestionLabel(int number);
  String get adminCmsQuestionPromptEnLabel;
  String get adminCmsQuestionPromptArLabel;
  String get adminCmsQuestionOptionsLabel;
  String adminCmsQuestionOptionLabel(int number);
  String get adminCmsQuestionCorrectAnswerLabel;
  String get adminCmsQuestionExplanationEnLabel;
  String get adminCmsQuestionExplanationArLabel;
  String get adminCmsQuestionRemove;
  String get adminCmsOptionAdd;
  String get adminCmsOptionRemove;
  String get adminCmsValidationTitleEnRequired;
  String get adminCmsValidationTitleArRequired;
  String get adminCmsValidationBodyEnRequired;
  String get adminCmsValidationBodyArRequired;
  String get adminCmsValidationInvalidUrl;
  String get adminCmsValidationInvalidAgeGroup;
  String get adminCmsValidationInvalidJsonObject;
  String get adminCmsValidationInvalidJsonList;
  String get adminCmsValidationInvalidJsonSyntax;
  String get adminCmsValidationQuestionRequired;
  String get adminCmsValidationQuestionPromptRequired;
  String get adminCmsValidationQuestionOptionsRequired;
  String get adminCmsValidationQuestionCorrectAnswerRequired;
  String get adminCmsValidationQuestionOptionTextRequired;

  // Pagination
  String adminPaginationSummary(int page, int totalPages, int total);
  String get adminPaginationPrevious;
  String get adminPaginationNext;

  // Analytics
  String get adminAnalyticsTitle;
  String get adminAnalyticsSubtitle;
  String get adminAnalyticsRangeWeek;
  String get adminAnalyticsRangeMonth;
  String get adminAnalyticsTotalUsers;
  String get adminAnalyticsActiveChildren;
  String get adminAnalyticsActivitiesToday;
  String get adminAnalyticsOpenTickets;
  String get adminAnalyticsUsageTitle;
  String get adminAnalyticsNewUsers;
  String get adminAnalyticsNewChildren;
  String get adminAnalyticsActivities;
  String get adminAnalyticsTickets;
  String get adminAnalyticsSubscriptionsTitle;
  String get adminAnalyticsPaidSubscriptions;
  String get adminAnalyticsFreeSubscriptions;
  String get adminAnalyticsRecentTickets;
  String get adminAnalyticsNoData;

  // System Settings
  String get adminSystemSettingsTitle;
  String get adminSystemSettingsSubtitle;
  String get adminSettingsMaintenanceMode;
  String get adminSettingsMaintenanceModeHint;
  String get adminSettingsRegistrationEnabled;
  String get adminSettingsRegistrationEnabledHint;
  String get adminSettingsAiBuddyEnabled;
  String get adminSettingsAiBuddyEnabledHint;
  String get adminSettingsFeatureFlagsTitle;
  String get adminSettingsDefaultsTitle;
  String get adminSettingsDefaultPlanLabel;
  String get adminSettingsDefaultChildLimitLabel;

  // Generic labels
  String get labelId;

  // ── Gamification ──────────────────────────────────────────────────────────
  String get gamificationTitle;
  String get gamificationSubtitle;
  String get gamificationXpLabel;
  String get gamificationLevelLabel;
  String get gamificationStreakLabel;
  String get gamificationBadgesEarned;
  String get gamificationAchievementsUnlocked;
  String get gamificationViewAll;
  String get gamificationParentSnapshot;
  String get gamificationParentSnapshotSubtitle;
  String get gamificationNoAchievementsYet;
  String get gamificationNoBadgesYet;
  String get gamificationLevelUp;
  String get gamificationAchievementUnlocked;
  String gamificationXpToNext(int xp);
  String gamificationLevelTitle(int level);
  String get gamificationActivitiesCompleted;
  String get gamificationCurrentStreak;
  String get gamificationTotalXp;
  String get gamificationSeeAllAchievements;
  String get gamificationRecentBadges;
  String get gamificationProgressSection;

  // ── Accessibility ─────────────────────────────────────────────────────────
  String get accessibilitySettings;
  String get accessibilitySettingsSubtitle;
  String get accessibilityMode;
  String get accessibilityModeSubtitle;
  String get largeFontMode;
  String get largeFontModeSubtitle;
  String get highContrastMode;
  String get highContrastModeSubtitle;
  String get accessibilityActiveLabel;
  String get accessibilityInactiveLabel;
  String get accessibilityParentNote;
  String get accessibilityResetAll;
  String get accessibilityResetConfirm;

  // ── Mood Tracking ─────────────────────────────────────────────────────────
  String get moodPickerTitle;
  String get moodPickerSubtitle;
  String get moodSaved;
  String get moodTodayLabel;
  String get moodWeekLabel;
  String get moodNoHistory;
  String get moodRecommendationsTitle;
  String get moodRecommendationsSubtitle;
  String get moodReportTitle;
  String get moodReportSubtitle;
  String get moodMostFrequent;
  String moodEntriesCount(int n);
  String get moodEncouragementHappy;
  String get moodEncouragementExcited;
  String get moodEncouragementCalm;
  String get moodEncouragementTired;
  String get moodEncouragementSad;
  String get moodEncouragementAngry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'ar':
        return AppLocalizationsAr();
      case 'en':
      default:
        return AppLocalizationsEn();
    }
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
