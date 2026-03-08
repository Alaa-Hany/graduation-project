import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';

class DataSyncScreen extends ConsumerStatefulWidget {
  const DataSyncScreen({super.key});

  @override
  ConsumerState<DataSyncScreen> createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends ConsumerState<DataSyncScreen> 
    with SingleTickerProviderStateMixin {
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String? _syncStatusKey = 'syncReady';
  
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getSyncStatus(AppLocalizations l10n) {
    switch (_syncStatusKey) {
      case 'syncReady':
        return l10n.syncReady;
      case 'syncStarting':
        return l10n.syncStarting;
      case 'syncingChildProfiles':
        return l10n.syncingChildProfiles;
      case 'syncingProgressData':
        return l10n.syncingProgressData;
      case 'syncingActivities':
        return l10n.syncingActivities;
      case 'syncFinalizing':
        return l10n.syncFinalizing;
      case 'syncCompleted':
        return l10n.syncCompleted;
      default:
        return l10n.syncReady;
    }
  }

  Future<void> _startSync() async {
    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
      _syncStatusKey = 'syncStarting';
    });
    
    _controller.repeat();
    
    // Simulate sync process
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        setState(() {
          _syncProgress = i / 100;
          
          if (i < 30) {
            _syncStatusKey = 'syncingChildProfiles';
          } else if (i < 60) {
            _syncStatusKey = 'syncingProgressData';
          } else if (i < 90) {
            _syncStatusKey = 'syncingActivities';
          } else {
            _syncStatusKey = 'syncFinalizing';
          }
        });
      }
    }
    
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _isSyncing = false;
        _syncStatusKey = 'syncCompleted';
      });
      
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final successColor = context.successColor;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.onSurface),
          onPressed: () => context.go('/parent/settings'),
        ),
        title: Text(
          AppLocalizations.of(context)!.dataSyncTitle,
          style: textTheme.titleMedium?.copyWith(
            fontSize: AppConstants.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Sync icon
              AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value * 2 * 3.14159,
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _isSyncing 
                        ? colors.primary.withValues(alpha: 0.12)
                        : successColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: Icon(
                    _isSyncing ? Icons.sync : Icons.check_circle,
                    size: 60,
                    color: _isSyncing ? colors.primary : successColor,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Sync status
              Text(
                _getSyncStatus(AppLocalizations.of(context)!),
                style: textTheme.titleLarge?.copyWith(
                  fontSize: AppConstants.largeFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Progress bar
              if (_isSyncing) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _syncProgress,
                    backgroundColor: colors.surfaceContainerHighest,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_syncProgress * 100).toInt()}%',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              
              const SizedBox(height: 48),
              
              // Sync details
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _SyncDetailItem(
                      icon: Icons.person,
                      label: AppLocalizations.of(context)!.syncChildProfilesLabel,
                      value: AppLocalizations.of(context)!.syncedCount(2),
                      isSynced: true,
                    ),
                    const SizedBox(height: 16),
                    _SyncDetailItem(
                      icon: Icons.analytics,
                      label: AppLocalizations.of(context)!.syncProgressDataLabel,
                      value: AppLocalizations.of(context)!.activitiesCount(15),
                      isSynced: true,
                    ),
                    const SizedBox(height: 16),
                    _SyncDetailItem(
                      icon: Icons.settings,
                      label: AppLocalizations.of(context)!.syncSettingsLabel,
                      value: AppLocalizations.of(context)!.syncedLabel,
                      isSynced: true,
                    ),
                    const SizedBox(height: 16),
                    _SyncDetailItem(
                      icon: Icons.cloud,
                      label: AppLocalizations.of(context)!.syncLastSyncLabel,
                      value: AppLocalizations.of(context)!.hoursAgoSync,
                      isSynced: null,
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Sync button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSyncing ? null : _startSync,
                  child: _isSyncing
                    ? CircularProgressIndicator(color: colors.onPrimary)
                    : Text(
                        AppLocalizations.of(context)!.syncNow,
                        style: textTheme.titleSmall?.copyWith(
                          fontSize: AppConstants.fontSize,
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimary,
                        ),
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

class _SyncDetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool? isSynced;
  
  const _SyncDetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.isSynced,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 16),
        
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 16,
            ),
          ),
        ),
        
        if (isSynced == true)
          Icon(
            Icons.check_circle,
            size: 20,
            color: context.successColor,
          )
        else if (isSynced == false)
          Icon(
            Icons.error,
            size: 20,
            color: colors.error,
          )
        else
          const SizedBox(width: 20),
        
        const SizedBox(width: 8),
        
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            fontSize: 14,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
