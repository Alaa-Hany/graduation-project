import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/theme/app_colors.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/features/child_mode/paywall/child_paywall_screen.dart';

class CreateChildProfileScreen extends ConsumerStatefulWidget {
  const CreateChildProfileScreen({super.key});

  @override
  ConsumerState<CreateChildProfileScreen> createState() => _CreateChildProfileScreenState();
}

class _CreateChildProfileScreenState extends ConsumerState<CreateChildProfileScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  
  // Step 1: Basic Info
  final _nameController = TextEditingController();
  final _parentEmailController = TextEditingController();
  int _selectedAge = 6;
  
  // Step 2: Avatar
  String _selectedAvatar = 'assets/images/avatars/boy1.png';
  
  // Step 3: Interests
  final List<String> _selectedInterests = [];
  
  // Step 4: Picture Password
  final List<String> _picturePassword = [];
  OverlayEntry? _topMessageEntry;
  
  // Available avatars
  final List<String> _avatarOptions = [
    'assets/images/avatars/boy1.png',
    'assets/images/avatars/boy2.png',
    'assets/images/avatars/boy3.png',
    'assets/images/avatars/boy4.png',
    'assets/images/avatars/girl1.png',
    'assets/images/avatars/girl2.png',
    'assets/images/avatars/girl3.png',
    'assets/images/avatars/girl4.png',
    'assets/images/avatars/av1.png',
    'assets/images/avatars/av2.png',
    'assets/images/avatars/av3.png',
    'assets/images/avatars/av4.png',
    'assets/images/avatars/av5.png',
    'assets/images/avatars/av6.png',
  ];
  
  // Available interests
  final Map<String, String> _interestOptions = {
    'math': '🔢 Mathematics',
    'science': '🔬 Science',
    'reading': '📚 Reading',
    'art': '🎨 Art & Drawing',
    'music': '🎵 Music',
    'sports': '⚽ Sports',
    'animals': '🐾 Animals',
    'nature': '🌿 Nature',
  };
  
  // Available pictures for password
  final List<Map<String, dynamic>> _pictureOptions = [
    {'id': 'apple', 'icon': '🍎', 'name': 'Apple'},
    {'id': 'ball', 'icon': '⚽', 'name': 'Ball'},
    {'id': 'cat', 'icon': '🐱', 'name': 'Cat'},
    {'id': 'dog', 'icon': '🐶', 'name': 'Dog'},
    {'id': 'elephant', 'icon': '🐘', 'name': 'Elephant'},
    {'id': 'fish', 'icon': '🐠', 'name': 'Fish'},
    {'id': 'guitar', 'icon': '🎸', 'name': 'Guitar'},
    {'id': 'house', 'icon': '🏠', 'name': 'House'},
    {'id': 'icecream', 'icon': '🍦', 'name': 'Ice Cream'},
    {'id': 'jelly', 'icon': '🍇', 'name': 'Jelly'},
    {'id': 'kite', 'icon': '🪁', 'name': 'Kite'},
    {'id': 'lion', 'icon': '🦁', 'name': 'Lion'},
  ];

  @override
  void dispose() {
    _topMessageEntry?.remove();
    _topMessageEntry = null;
    _nameController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadParentEmail();
  }

  Future<void> _loadParentEmail() async {
    final storedEmail = await ref.read(secureStorageProvider).getParentEmail();
    if (!mounted) return;
    if (storedEmail != null &&
        storedEmail.isNotEmpty &&
        _parentEmailController.text.isEmpty) {
      _parentEmailController.text = storedEmail;
    }
  }

  void _showTopMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    _topMessageEntry?.remove();
    final textDirection = Directionality.of(context);
    _topMessageEntry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: MediaQuery.of(overlayContext).padding.top + 12,
          left: 16,
          right: 16,
          child: Directionality(
            textDirection: textDirection,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isError ? AppColors.error : AppColors.success,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.surface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = _topMessageEntry!;
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (_topMessageEntry == entry) {
        entry.remove();
        _topMessageEntry = null;
      }
    });
  }

  void _onPictureSelected(String pictureId) {
    setState(() {
      if (_picturePassword.length < 3 && !_picturePassword.contains(pictureId)) {
        _picturePassword.add(pictureId);
      } else if (_picturePassword.contains(pictureId)) {
        _picturePassword.remove(pictureId);
      }
    });
  }

  void _onInterestSelected(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else if (_selectedInterests.length < 5) {
        _selectedInterests.add(interest);
      }
    });
  }

  String _mapChildRegisterError(AppLocalizations l10n, String? error) {
    switch (error) {
      case 'child_register_404':
        return l10n.childRegisterParentNotFound;
      case 'child_register_401':
        return l10n.childRegisterForbidden;
      case 'child_register_422':
        return l10n.childLoginMissingData;
      case 'child_register_limit':
        return l10n.childRegisterLimitReached;
      default:
        return l10n.registerError;
    }
  }

  String _mapChildLoginError(AppLocalizations l10n, String? error) {
    switch (error) {
      case 'child_login_404':
        return l10n.childLoginNotFound;
      case 'child_login_401':
        return l10n.childLoginIncorrectPictures;
      case 'child_login_422':
        return l10n.childLoginMissingData;
      default:
        return l10n.loginError;
    }
  }

  Future<bool> _openPaywall() async {
    if (!mounted) return false;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const ChildPaywallScreen(),
      ),
    );
    return result == true;
  }

  Future<void> _createProfile() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedInterests.isEmpty || _picturePassword.length != 3) {
      _showTopMessage(l10n.childLoginMissingData);
      return;
    }

    final trimmedName = _nameController.text.trim();
    final trimmedEmail = _parentEmailController.text.trim();
    if (trimmedName.isEmpty || trimmedEmail.isEmpty) {
      _showTopMessage(l10n.childLoginMissingData);
      return;
    }

    final authController = ref.read(authControllerProvider.notifier);
    var response = await authController.registerChild(
      name: trimmedName,
      picturePassword: List<String>.from(_picturePassword),
      parentEmail: trimmedEmail,
      age: _selectedAge,
      avatar: _selectedAvatar,
    );

    if (response == null &&
        ref.read(authControllerProvider).error == 'child_register_limit') {
      _showTopMessage(l10n.childRegisterLimitReached);
      final upgraded = await _openPaywall();
      if (!upgraded) return;
      response = await authController.registerChild(
        name: trimmedName,
        picturePassword: List<String>.from(_picturePassword),
        parentEmail: trimmedEmail,
        age: _selectedAge,
        avatar: _selectedAvatar,
      );
    }

    if (response == null) {
      final error = ref.read(authControllerProvider).error;
      _showTopMessage(_mapChildRegisterError(l10n, error));
      return;
    }

    await ref.read(secureStorageProvider).saveUserEmail(trimmedEmail);

    final resolvedName = response.name?.trim().isNotEmpty == true
        ? response.name!.trim()
        : trimmedName;
    final now = DateTime.now();
    final repo = ref.read(childRepositoryProvider);
    final existing = await repo.getChildProfile(response.childId);
    final newProfile = ChildProfile(
      id: response.childId,
      name: resolvedName,
      age: _selectedAge,
      avatar: _selectedAvatar,
      avatarPath: _selectedAvatar,
      interests: _selectedInterests,
      level: existing?.level ?? 1,
      xp: existing?.xp ?? 0,
      streak: existing?.streak ?? 0,
      favorites: existing?.favorites ?? [],
      parentId: existing?.parentId ?? trimmedEmail,
      parentEmail: existing?.parentEmail ?? trimmedEmail,
      picturePassword: List<String>.from(_picturePassword),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      totalTimeSpent: existing?.totalTimeSpent ?? 0,
      activitiesCompleted: existing?.activitiesCompleted ?? 0,
      currentMood: existing?.currentMood ?? 'happy',
      learningStyle: existing?.learningStyle,
      specialNeeds: existing?.specialNeeds,
      accessibilityNeeds: existing?.accessibilityNeeds,
    );

    final saved = existing == null
        ? await repo.createChildProfile(newProfile)
        : await repo.updateChildProfile(newProfile);

    if (saved == null) {
      _showTopMessage(l10n.childProfileAddFailed);
      return;
    }

    final authSuccess = await authController.loginChild(
      childId: response.childId,
      childName: newProfile.name,
      picturePassword: List<String>.from(_picturePassword),
    );

    if (!authSuccess) {
      final error = ref.read(authControllerProvider).error;
      _showTopMessage(_mapChildLoginError(l10n, error));
      return;
    }

    await ref.read(childSessionControllerProvider.notifier).startChildSession(
      childId: response.childId,
      childProfile: saved,
    );

    if (mounted) {
      context.go('/child/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
              });
            } else {
              context.go('/select-user-type');
            }
          },
        ),
        title: Text(
          'Create Child Profile',
          style: TextStyle(
            fontSize: AppConstants.fontSize,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index <= _currentStep 
                            ? AppColors.primary 
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            // Step content
            Expanded(
              child: Form(
                key: _formKey,
                child: _buildCurrentStep(),
              ),
            ),
            
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _currentStep--;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(
                            fontSize: AppConstants.fontSize,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentStep == 3 ? _createProfile : () {
                        setState(() {
                          _currentStep++;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _currentStep == 3 ? 'Create Profile' : 'Next',
                        style: TextStyle(
                          fontSize: AppConstants.fontSize,
                          color: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildAvatarStep();
      case 2:
        return _buildInterestsStep();
      case 3:
        return _buildPicturePasswordStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBasicInfoStep() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us about your child',
            style: TextStyle(
              fontSize: AppConstants.largeFontSize,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us personalize their learning experience',
            style: TextStyle(
              fontSize: AppConstants.fontSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          
          // Name input
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Child\'s Name',
              labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your child\'s name';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _parentEmailController,
            decoration: InputDecoration(
              labelText: l10n.parentEmail,
              labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            enableSuggestions: false,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return l10n.fieldRequired;
              }
              final isValid =
                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
              if (!isValid) {
                return l10n.invalidEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // Age selector
          Text(
            'Age',
            style: TextStyle(
              fontSize: AppConstants.fontSize,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(7, (index) {
              final age = index + 5; // Ages 5-12
              return ChoiceChip(
                label: Text('$age years'),
                selected: _selectedAge == age,
                onSelected: (selected) {
                  setState(() {
                    _selectedAge = age;
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose an avatar',
            style: TextStyle(
              fontSize: AppConstants.largeFontSize,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a fun character to represent your child',
            style: TextStyle(
              fontSize: AppConstants.fontSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _avatarOptions.length,
            itemBuilder: (context, index) {
              final avatar = _avatarOptions[index];
              final isSelected = _selectedAvatar == avatar;
              
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedAvatar = avatar;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are your child\'s interests?',
            style: TextStyle(
              fontSize: AppConstants.largeFontSize,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select up to 5 interests (optional)',
            style: TextStyle(
              fontSize: AppConstants.fontSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
            ),
            itemCount: _interestOptions.length,
            itemBuilder: (context, index) {
              final entry = _interestOptions.entries.elementAt(index);
              final isSelected = _selectedInterests.contains(entry.key);
              
              return InkWell(
                onTap: () => _onInterestSelected(entry.key),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPicturePasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create a picture password',
            style: TextStyle(
              fontSize: AppConstants.largeFontSize,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select 3 pictures your child will remember',
            style: TextStyle(
              fontSize: AppConstants.fontSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          
          // Selected pictures
          Container(
            height: 80,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  child: _picturePassword.length > index
                      ? Center(
                        child: Text(
                          _pictureOptions.firstWhere(
                            (p) => p['id'] == _picturePassword[index]
                          )['icon'],
                          style: const TextStyle(fontSize: 24),
                        ),
                        )
                      : null,
                );
              }),
            ),
          ),
          const SizedBox(height: 32),
          
          // Picture options
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _pictureOptions.length,
            itemBuilder: (context, index) {
              final picture = _pictureOptions[index];
              final isSelected = _picturePassword.contains(picture['id']);
              
              return InkWell(
                onTap: () => _onPictureSelected(picture['id']),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        picture['icon'],
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        picture['name'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

