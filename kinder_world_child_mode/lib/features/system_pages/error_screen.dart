import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/theme/app_colors.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';

class ErrorScreen extends ConsumerStatefulWidget {
  final String error;
  
  const ErrorScreen({
    super.key,
    required this.error,
  });

  @override
  ConsumerState<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends ConsumerState<ErrorScreen> 
    with SingleTickerProviderStateMixin {
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
      curve: Curves.easeInOut,
    ));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/welcome');
            }
          },
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                _shakeAnimation.value * 10 * (1 - _shakeAnimation.value),
                0,
              ),
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Title
                Text(
                  AppLocalizations.of(context)!.oopsSomethingWentWrong,
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: AppConstants.largeFontSize * 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Error Message
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.errorDetailsLabel,
                        style: textTheme.titleSmall?.copyWith(
                          fontSize: AppConstants.fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.error,
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Action Buttons
                ElevatedButton.icon(
                  onPressed: () {
                    // Try to navigate back
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/child/home');
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: Text(AppLocalizations.of(context)!.goBack),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: colors.onPrimary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                OutlinedButton.icon(
                  onPressed: () {
                    // Refresh current route
                    context.go(context.namedLocation(
                      (GoRouter.of(context).routerDelegate.currentConfiguration.routes.first as GoRoute).path,
                    ));
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.tryAgain),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextButton.icon(
                  onPressed: () {
                    // Report error (placeholder)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.errorReported),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  icon: const Icon(Icons.bug_report),
                  label: Text(AppLocalizations.of(context)!.reportIssue),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
