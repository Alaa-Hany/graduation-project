import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/theme/app_colors.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/providers/parent_pin_provider.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';

class ParentPinScreen extends ConsumerStatefulWidget {
  final String? redirectPath;
  
  const ParentPinScreen({
    super.key,
    this.redirectPath,
  });

  @override
  ConsumerState<ParentPinScreen> createState() => _ParentPinScreenState();
}

class _ParentPinScreenState extends ConsumerState<ParentPinScreen> 
    with SingleTickerProviderStateMixin {
  final List<String> _enteredPin = [];
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticIn,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin.add(number);
      });
      
      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin.removeLast();
      });
    }
  }

  Future<void> _verifyPin() async {
    final pin = _enteredPin.join();
    final isValid = await ref.read(parentPinProvider.notifier).verifyPin(pin);
    
    if (isValid) {
      if (mounted) {
        if (widget.redirectPath != null) {
          context.go(widget.redirectPath!);
        } else {
          context.go('/parent/dashboard');
        }
      }
    } else {
      _controller.forward().then((_) {
        _controller.reverse();
      });
      
      setState(() {
        _enteredPin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinState = ref.watch(parentPinProvider);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.onSurface),
          onPressed: () => context.go('/welcome'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              const Icon(
                Icons.lock_outline,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              
              Text(
                AppLocalizations.of(context)!.parentAccess,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: AppConstants.largeFontSize * 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                AppLocalizations.of(context)!.enterPinToContinue,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: AppConstants.fontSize,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              
              // PIN Display
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value * 10 * (1 - _shakeAnimation.value), 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final colors = Theme.of(context).colorScheme;
                    return Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _enteredPin.length > index
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      ),
                    );
                  }),
                ),
              ),
              
              if (pinState.error != null) ...[
                const SizedBox(height: 24),
                Text(
                  pinState.error!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.error,
                  ),
                ),
              ],
              
              const SizedBox(height: 48),
              
              // Number Pad
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index == 9) {
                      // Empty space
                      return const SizedBox();
                    } else if (index == 10) {
                      // 0 button
                      return _NumberButton(
                        number: '0',
                        onPressed: () => _onNumberPressed('0'),
                      );
                    } else if (index == 11) {
                      // Backspace button
                      return _NumberButton(
                        icon: Icons.backspace,
                        onPressed: _onBackspacePressed,
                      );
                    } else {
                      // Number buttons 1-9
                      final number = (index + 1).toString();
                      if (index >= 10) {
                        final adjustedIndex = index - 1;
                        final adjustedNumber = (adjustedIndex + 1).toString();
                        return _NumberButton(
                          number: adjustedNumber,
                          onPressed: () => _onNumberPressed(adjustedNumber),
                        );
                      }
                      return _NumberButton(
                        number: number,
                        onPressed: () => _onNumberPressed(number),
                      );
                    }
                  },
                ),
              ),
              
              // Forgot PIN button
              TextButton(
                onPressed: () {
                  // In a real app, this would trigger a reset flow
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.contactSupportToResetPin),
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)!.forgotPin,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final String? number;
  final IconData? icon;
  final VoidCallback onPressed;
  
  const _NumberButton({
    this.number,
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  size: 32,
                  color: colors.onSurface,
                )
              : Text(
                  number!,
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: AppConstants.largeFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}