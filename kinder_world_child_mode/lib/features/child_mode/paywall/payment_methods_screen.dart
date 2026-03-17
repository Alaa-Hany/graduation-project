import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/payment_method_record.dart';
import 'package:kinder_world/core/providers/subscription_provider.dart';
import 'package:kinder_world/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen>
    with WidgetsBindingObserver {
  late Future<List<PaymentMethodRecord>> _methodsFuture;
  bool _refreshOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _methodsFuture = _loadMethods();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _refreshOnResume) {
      setState(() {
        _methodsFuture = _loadMethods(forceRefresh: true);
        _refreshOnResume = false;
      });
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<List<PaymentMethodRecord>> _loadMethods({bool forceRefresh = false}) async {
    final service = ref.read(subscriptionServiceProvider);
    return await service.listPaymentMethods(forceRefresh: forceRefresh);
  }

  Future<void> _addPaymentMethod(AppLocalizations l10n) async {
    final labelController = TextEditingController();
    final providerIdController = TextEditingController();
    bool setDefault = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.addPaymentMethod),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: l10n.paymentMethod,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: providerIdController,
                decoration: InputDecoration(
                  labelText: l10n.paymentProviderMethodIdOptional,
                ),
              ),
              StatefulBuilder(
                builder: (context, setState) {
                  return CheckboxListTile(
                    value: setDefault,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.setAsDefault),
                    onChanged: (value) =>
                        setState(() => setDefault = value ?? false),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    final label = labelController.text.trim();
    final providerId = providerIdController.text.trim();
    labelController.dispose();
    providerIdController.dispose();
    if (confirmed != true) return;
    try {
      final service = ref.read(subscriptionServiceProvider);
      await service.addPaymentMethod(
        label: label.isEmpty ? null : label,
        providerMethodId: providerId.isEmpty ? null : providerId,
        setDefault: setDefault,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.billingComingSoon)),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _methodsFuture = _loadMethods();
    });
  }

  Future<void> _openPaymentPortal(AppLocalizations l10n) async {
    try {
      final url = await ref.read(subscriptionServiceProvider).manageCurrentSubscription();
      final uri = Uri.tryParse(url);
      if (uri == null) throw StateError('Invalid portal URL');
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw StateError('Unable to open portal');
      setState(() {
        _refreshOnResume = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.billingComingSoon)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.paymentMethodsTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: FutureBuilder<List<PaymentMethodRecord>>(
                  future: _methodsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.billingComingSoon,
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: AppConstants.fontSize,
                                color: colors.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _methodsFuture = _loadMethods(forceRefresh: true);
                                });
                              },
                              child: Text(l10n.retry),
                            ),
                          ],
                        ),
                      );
                    }
                    final methods = snapshot.data ?? [];
                    if (methods.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.paymentMethodsEmpty,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: AppConstants.fontSize,
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: methods.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final method = methods[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
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
                          child: Row(
                            children: [
                              Icon(
                                Icons.credit_card,
                                color: method.isDefault
                                    ? AppColors.primary
                                    : colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      method.displayTitle,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontSize: AppConstants.fontSize,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        if (method.expiryLabel.isNotEmpty)
                                          method.expiryLabel,
                                        method.provider.toUpperCase(),
                                        if (method.methodType != null)
                                          method.methodType!,
                                      ].where((e) => e.isNotEmpty).join(' • '),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                    if (method.isDefault)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            l10n.paymentMethodDefaultLabel,
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await ref
                                      .read(subscriptionServiceProvider)
                                      .deletePaymentMethod(method.id);
                                  if (!mounted) return;
                                  setState(() {
                                    _methodsFuture = _loadMethods();
                                  });
                                },
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.error,
                                ),
                                tooltip: l10n.removePaymentMethod,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _addPaymentMethod(l10n),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addPaymentMethod),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () => _openPaymentPortal(l10n),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(l10n.openPaymentPortal),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
