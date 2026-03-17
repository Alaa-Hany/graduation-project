import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/faq_item.dart';
import 'package:kinder_world/core/services/content_service.dart';
import 'package:kinder_world/router.dart';

class ParentHelpScreen extends ConsumerStatefulWidget {
  const ParentHelpScreen({super.key});

  @override
  ConsumerState<ParentHelpScreen> createState() => _ParentHelpScreenState();
}

class _ParentHelpScreenState extends ConsumerState<ParentHelpScreen> {
  late final TextEditingController _searchController;
  late Future<List<FaqItem>> _faqFuture;

  List<FaqItem> _localizedFaqItems(AppLocalizations l10n) {
    return [
      FaqItem(id: '1', question: l10n.helpFaqQ1, answer: l10n.helpFaqA1),
      FaqItem(id: '2', question: l10n.helpFaqQ2, answer: l10n.helpFaqA2),
      FaqItem(id: '3', question: l10n.helpFaqQ3, answer: l10n.helpFaqA3),
      FaqItem(id: '4', question: l10n.helpFaqQ4, answer: l10n.helpFaqA4),
      FaqItem(id: '5', question: l10n.helpFaqQ5, answer: l10n.helpFaqA5),
    ];
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _faqFuture = _fetchFaqs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<FaqItem>> _fetchFaqs() {
    return ref.read(contentServiceProvider).getFaq();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _searchController.text.trim();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.parentHelp),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchFaqsHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: FutureBuilder<List<FaqItem>>(
                future: _faqFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _searchController.text.trim().isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data?.isNotEmpty == true
                      ? snapshot.data!
                      : _localizedFaqItems(l10n);
                  final filtered = query.isEmpty
                      ? items
                      : items
                          .where((item) {
                            final q = query.toLowerCase();
                            final question = item.question.toLowerCase();
                            final answer = item.answer.toLowerCase();
                            return question.contains(q) || answer.contains(q);
                          })
                          .toList();

                  if (filtered.isEmpty) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 72,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          query.isEmpty ? l10n.noFaqsYet : l10n.noResultsFound,
                          style: TextStyle(
                            fontSize: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.helpPreparingArticles,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return ExpansionTile(
                        title: Text(item.question),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(item.answer),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(Routes.parentContactUs),
                child: Text(l10n.contactUsAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
