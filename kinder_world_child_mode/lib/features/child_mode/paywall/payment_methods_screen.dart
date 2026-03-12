import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/theme/app_colors.dart';
import 'package:kinder_world/app.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  late Future<List<Map<String, dynamic>>> _methodsFuture;

  @override
  void initState() {
    super.initState();
    _methodsFuture = _loadMethods();
  }

  Future<List<Map<String, dynamic>>> _loadMethods() async {
    try {
      final response =
          await ref.read(networkServiceProvider).get<Map<String, dynamic>>(
                '/billing/methods',
              );
      final data = response.data;
      if (data == null) return [];
      final methods = data['methods'];
      if (methods is List) {
        return methods
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _addPaymentMethod(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final method = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.addPaymentMethod),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.paymentMethod,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (method == null || method.isEmpty) return;
    await ref.read(networkServiceProvider).post<Map<String, dynamic>>(
      '/billing/methods',
      data: {
        'label': method,
      },
    );
    if (!mounted) return;
    setState(() {
      _methodsFuture = _loadMethods();
    });
  }

  Future<void> _openPaymentPortal(AppLocalizations l10n) async {
    try {
      await ref.read(networkServiceProvider).post<Map<String, dynamic>>(
        '/billing/portal',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.openPaymentPortal)),
      );
    } catch (_) {
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
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _methodsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
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
                        final label = method['label']?.toString() ?? '';
                        final id = method['id']?.toString() ?? '';
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
                              const Icon(Icons.credit_card,
                                  color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  label,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontSize: AppConstants.fontSize,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  if (id.isEmpty) return;
                                  await ref
                                      .read(networkServiceProvider)
                                      .delete<Map<String, dynamic>>(
                                        '/billing/methods/$id',
                                      );
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
