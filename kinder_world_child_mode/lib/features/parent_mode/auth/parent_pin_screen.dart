import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/providers/parent_pin_provider.dart';
import 'package:kinder_world/core/theme/app_colors.dart';
import 'package:kinder_world/router.dart';

class ParentPinScreen extends ConsumerStatefulWidget {
  const ParentPinScreen({
    super.key,
    this.redirectPath,
    this.mode = ParentPinFlowMode.auto,
  });

  final String? redirectPath;
  final ParentPinFlowMode mode;

  @override
  ConsumerState<ParentPinScreen> createState() => _ParentPinScreenState();
}

class _ParentPinScreenState extends ConsumerState<ParentPinScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _enteredDigits = <String>[];
  String? _firstPin;
  String? _currentPin;
  late final AnimationController _controller;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(parentPinProvider.notifier).refreshStatus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ParentPinFlowMode get _effectiveMode {
    return ref.read(parentPinProvider.notifier).resolveMode(widget.mode);
  }

  String get _resolvedRedirectPath {
    final raw = widget.redirectPath;
    if (raw == null || raw.isEmpty) {
      return Routes.parentDashboard;
    }
    return Uri.decodeComponent(raw);
  }

  String get _backFallbackPath {
    if (widget.mode == ParentPinFlowMode.change) {
      return _resolvedRedirectPath;
    }
    return Routes.selectUserType;
  }

  void _onNumberPressed(String number) {
    final pinState = ref.read(parentPinProvider);
    if (pinState.isLocked || pinState.isLoading || _enteredDigits.length >= 4) {
      return;
    }

    setState(() {
      _enteredDigits.add(number);
    });

    if (_enteredDigits.length == 4) {
      _submitCurrentStep();
    }
  }

  void _onBackspacePressed() {
    if (_enteredDigits.isEmpty) return;
    setState(() {
      _enteredDigits.removeLast();
    });
  }

  Future<void> _submitCurrentStep() async {
    final pin = _enteredDigits.join();
    final notifier = ref.read(parentPinProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    switch (_effectiveMode) {
      case ParentPinFlowMode.verify:
      case ParentPinFlowMode.auto:
        final success = await notifier.verifyPin(pin);
        if (success && mounted) {
          context.go(_resolvedRedirectPath);
        } else {
          _resetDigitsWithShake();
        }
        break;
      case ParentPinFlowMode.setup:
        if (_firstPin == null) {
          setState(() {
            _firstPin = pin;
            _enteredDigits.clear();
          });
          notifier.clearMessages();
          return;
        }

        final success = await notifier.setPin(
          pin: _firstPin!,
          confirmPin: pin,
        );
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.parentPinCreatedSuccess)),
          );
          context.go(_resolvedRedirectPath);
        } else {
          setState(() {
            _firstPin = null;
          });
          _resetDigitsWithShake();
        }
        break;
      case ParentPinFlowMode.change:
        if (_currentPin == null) {
          setState(() {
            _currentPin = pin;
            _enteredDigits.clear();
          });
          notifier.clearMessages();
          return;
        }
        if (_firstPin == null) {
          setState(() {
            _firstPin = pin;
            _enteredDigits.clear();
          });
          notifier.clearMessages();
          return;
        }

        final success = await notifier.changePin(
          currentPin: _currentPin!,
          newPin: _firstPin!,
          confirmPin: pin,
        );
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.parentPinChangedSuccess)),
          );
          context.go(_resolvedRedirectPath);
        } else {
          setState(() {
            _currentPin = null;
            _firstPin = null;
          });
          _resetDigitsWithShake();
        }
        break;
    }
  }

  void _resetDigitsWithShake() {
    _controller.forward(from: 0);
    setState(() {
      _enteredDigits.clear();
    });
  }

  Future<void> _requestReset() async {
    final l10n = AppLocalizations.of(context)!;
    final success = await ref.read(parentPinProvider.notifier).requestReset();
    if (!mounted) return;
    final text = success
        ? l10n.parentPinResetRequested
        : ref.read(parentPinProvider).error ?? l10n.contactSupportToResetPin;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String _titleFor(AppLocalizations l10n) {
    switch (_effectiveMode) {
      case ParentPinFlowMode.setup:
        return l10n.parentPinCreateTitle;
      case ParentPinFlowMode.change:
        return l10n.parentPinChangeTitle;
      case ParentPinFlowMode.verify:
      case ParentPinFlowMode.auto:
        return l10n.parentPinTitle;
    }
  }

  String _subtitleFor(AppLocalizations l10n) {
    switch (_effectiveMode) {
      case ParentPinFlowMode.setup:
        return _firstPin == null
            ? l10n.parentPinCreateSubtitle
            : l10n.parentPinConfirmSubtitle;
      case ParentPinFlowMode.change:
        if (_currentPin == null) return l10n.parentPinEnterCurrent;
        if (_firstPin == null) return l10n.parentPinEnterNew;
        return l10n.parentPinConfirmNew;
      case ParentPinFlowMode.verify:
      case ParentPinFlowMode.auto:
        return l10n.parentPinSubtitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pinState = ref.watch(parentPinProvider);
    final colors = Theme.of(context).colorScheme;
    final isLocked = pinState.isLocked &&
        pinState.lockedUntil != null &&
        pinState.lockedUntil!.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
          onPressed: () => context.appBack(fallback: _backFallbackPath),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Icon(
                Icons.lock_person_rounded,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _titleFor(l10n),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitleFor(l10n),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _shakeAnimation.value * 12 * (1 - _shakeAnimation.value),
                      0,
                    ),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _enteredDigits.length > index
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              if (pinState.error != null)
                Text(
                  pinState.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (isLocked)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l10n.parentPinLockedUntil(
                      _formatLockedUntil(pinState.lockedUntil!),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.18,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index == 9) return const SizedBox();
                    if (index == 10) {
                      return _NumberButton(
                        number: '0',
                        onPressed: () => _onNumberPressed('0'),
                      );
                    }
                    if (index == 11) {
                      return _NumberButton(
                        icon: Icons.backspace_outlined,
                        onPressed: _onBackspacePressed,
                      );
                    }
                    final number = (index + 1).toString();
                    return _NumberButton(
                      number: number,
                      onPressed: () => _onNumberPressed(number),
                    );
                  },
                ),
              ),
              if (_effectiveMode != ParentPinFlowMode.setup)
                TextButton(
                  onPressed: pinState.isLoading ? null : _requestReset,
                  child: Text(
                    l10n.forgotPin,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              if (pinState.isLoading) ...[
                const SizedBox(height: 8),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatLockedUntil(DateTime lockedUntil) {
    final local = lockedUntil.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _NumberButton extends StatelessWidget {
  const _NumberButton({
    this.number,
    this.icon,
    required this.onPressed,
  });

  final String? number;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 28, color: colors.onSurface)
              : Text(
                  number!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
        ),
      ),
    );
  }
}
