// ─────────────────────────────────────────────────────────────────────────────
// DEAD CODE — faqProvider / legalContentProvider / contentServiceProvider are
// not imported anywhere in the app (LegalScreen uses networkServiceProvider
// directly). Safe to delete or wire up when a dedicated content service is needed.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/models/faq_item.dart';
import 'package:kinder_world/core/services/content_service.dart';
import 'package:kinder_world/app.dart';

/// Provider to get FAQ items
final faqProvider = FutureProvider.autoDispose<List<FaqItem>>((ref) async {
  final service = ref.watch(contentServiceProvider);
  return service.getFaq();
});

/// Provider to get legal content
final legalContentProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, type) async {
    final service = ref.watch(contentServiceProvider);
    return service.getLegal(type);
  },
);

/// Content service provider
final contentServiceProvider = Provider<ContentService>((ref) {
  final networkService = ref.watch(networkServiceProvider);
  final logger = ref.watch(loggerProvider);
  return ContentService(
    networkService: networkService,
    logger: logger,
  );
});
