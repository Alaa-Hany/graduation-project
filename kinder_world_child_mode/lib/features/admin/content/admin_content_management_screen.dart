import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_cms_models.dart';
import 'package:kinder_world/core/widgets/cloudinary_video_player_view.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_confirm_dialog.dart';
import 'package:kinder_world/features/admin/shared/admin_filter_bar.dart';
import 'package:kinder_world/features/admin/shared/admin_form_dialog.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';
import 'package:kinder_world/features/admin/shared/admin_table_widgets.dart';
import 'package:kinder_world/core/widgets/material_compat.dart';
import 'package:kinder_world/features/child_mode/learn/data/learn_catalog.dart';

/// IMPORTANT:
/// All UI text must use AppLocalizations.
/// Hardcoded strings are NOT allowed.

class AdminContentManagementScreen extends ConsumerStatefulWidget {
  const AdminContentManagementScreen({super.key});

  @override
  ConsumerState<AdminContentManagementScreen> createState() =>
      _AdminContentManagementScreenState();
}

class _AdminContentManagementScreenState
    extends ConsumerState<AdminContentManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;

  List<AdminCmsAxisSummary> _axes = const [];
  List<AdminCmsCategory> _categories = const [];
  List<AdminCmsContent> _contents = const [];
  List<AdminCmsQuiz> _quizzes = const [];
  Map<String, dynamic> _contentPagination = const {};
  Map<String, dynamic> _quizPagination = const {};

  String _contentSearch = '';
  String _contentStatus = '';
  String _contentType = '';
  String _selectedAxisKey = '';
  int? _contentCategoryId;
  int _contentPage = 1;

  String _quizStatus = '';
  int? _quizCategoryId;
  int _quizPage = 1;

  List<DropdownMenuItem<String>> _contentTypeItems(AppLocalizations l10n) => [
        DropdownMenuItem(
          value: 'lesson',
          child: Text(l10n.adminCmsTypeLesson),
        ),
        DropdownMenuItem(
          value: 'story',
          child: Text(l10n.adminCmsTypeStory),
        ),
        DropdownMenuItem(
          value: 'video',
          child: Text(l10n.adminCmsTypeVideo),
        ),
        DropdownMenuItem(
          value: 'activity',
          child: Text(l10n.adminCmsTypeActivity),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminManagementRepositoryProvider);
      final catalog = await repo.fetchCmsCatalog();
      final effectiveAxisKey = _selectedAxisKey.isNotEmpty
          ? _selectedAxisKey
          : (catalog.axes.isNotEmpty ? catalog.axes.first.key : '');
      final contents = await repo.fetchContents(
        search: _contentSearch,
        status: _contentStatus,
        categoryId: _contentCategoryId,
        axisKey: effectiveAxisKey,
        contentType: _contentType,
        page: _contentPage,
      );
      final quizzes = await repo.fetchQuizzes(
        status: _quizStatus,
        categoryId: _quizCategoryId,
        axisKey: effectiveAxisKey,
        page: _quizPage,
      );
      if (!mounted) return;
      setState(() {
        _axes = catalog.axes;
        _selectedAxisKey = effectiveAxisKey;
        _categories = catalog.categories;
        _contents = contents.items;
        _quizzes = quizzes.items;
        _contentPagination = contents.pagination;
        _quizPagination = quizzes.pagination;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  AdminCmsAxisSummary? get _selectedAxisSummary {
    for (final axis in _axes) {
      if (axis.key == _selectedAxisKey) {
        return axis;
      }
    }
    return _axes.isNotEmpty ? _axes.first : null;
  }

  List<AdminCmsCategory> get _categoriesForSelectedAxis {
    if (_selectedAxisKey.isEmpty) {
      return _categories;
    }
    return _categories
        .where((category) => category.axisKey == _selectedAxisKey)
        .toList();
  }

  String _axisTitle(BuildContext context, String? axisKey) {
    if ((axisKey ?? '').isEmpty) {
      return '';
    }
    final localeCode = Localizations.localeOf(context).languageCode;
    for (final axis in _axes) {
      if (axis.key == axisKey) {
        return localeCode == 'ar' ? axis.titleAr : axis.titleEn;
      }
    }
    return axisKey ?? '';
  }

  String _extractErrorMessage(AppLocalizations l10n, Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
      if (data is String && data.trim().isNotEmpty) {
        return data;
      }
      if ((error.message ?? '').trim().isNotEmpty) {
        return error.message!;
      }
    }
    final raw = error.toString().trim();
    return raw.isEmpty ? l10n.errorTitle : raw;
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
          content: Text(message),
        ),
      );
  }

  List<_StatusOption> _contentStatusOptions(AppLocalizations l10n) => [
        _StatusOption('draft', l10n.adminCmsStatusDraft),
        _StatusOption('ready', l10n.adminCmsStatusReady),
        _StatusOption('published', l10n.adminCmsStatusPublished),
        _StatusOption('archived', l10n.adminCmsStatusArchived),
      ];

  List<_StatusOption> _quizStatusOptions(AppLocalizations l10n) => [
        _StatusOption('draft', l10n.adminCmsStatusDraft),
        _StatusOption('review', l10n.adminCmsStatusReview),
        _StatusOption('published', l10n.adminCmsStatusPublished),
      ];

  String _statusLabel(String status, AppLocalizations l10n) {
    final allOptions = [
      ..._contentStatusOptions(l10n),
      _StatusOption('archived', l10n.adminCmsStatusArchived),
      ..._quizStatusOptions(l10n),
    ];
    for (final option in allOptions) {
      if (option.value == status) return option.label;
    }
    return status;
  }

  String _contentTypeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'lesson':
        return l10n.adminCmsTypeLesson;
      case 'story':
        return l10n.adminCmsTypeStory;
      case 'video':
        return l10n.adminCmsTypeVideo;
      case 'activity':
        return l10n.adminCmsTypeActivity;
      default:
        return type;
    }
  }

  void _selectAxis(AdminCmsAxisSummary axis) {
    if (_selectedAxisKey == axis.key) {
      return;
    }
    setState(() {
      _selectedAxisKey = axis.key;
      _contentCategoryId = null;
      _quizCategoryId = null;
      _contentSearch = '';
      _contentStatus = '';
      _contentType = '';
      _quizStatus = '';
      _contentPage = 1;
      _quizPage = 1;
    });
    _loadAll();
  }

  void _openTab(int tabIndex) {
    if (_tabs.index != tabIndex) {
      _tabs.animateTo(tabIndex);
    }
  }

  Future<void> _createContentForType(String type) async {
    _openTab(1);
    await _saveContent(initialType: type);
  }

  void _filterByContentType(String type) {
    _openTab(1);
    setState(() {
      _contentType = type;
      _contentCategoryId = null;
      _contentPage = 1;
    });
    _loadAll();
  }

  Future<AdminCmsCategory?> _saveCategory({
    AdminCmsCategory? category,
    String? initialAxisKey,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final slug = TextEditingController(text: category?.slug ?? '');
    final titleEn = TextEditingController(text: category?.titleEn ?? '');
    final titleAr = TextEditingController(text: category?.titleAr ?? '');
    final descEn = TextEditingController(text: category?.descriptionEn ?? '');
    final descAr = TextEditingController(text: category?.descriptionAr ?? '');
    String selectedAxisKey = category?.axisKey ??
        initialAxisKey ??
        _selectedAxisSummary?.key ??
        _selectedAxisKey;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
                vertical: 24,
              ),
              title: Text(category == null
                  ? (l10n.adminCmsCategoryCreateTitle)
                  : (l10n.adminCmsCategoryEditTitle)),
              content: SizedBox(
                width: adminResponsiveDialogWidth(
                  context,
                  preferredWidth: 520,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormFieldCompat<String>(
                      initialValue:
                          selectedAxisKey.isEmpty ? null : selectedAxisKey,
                      decoration: InputDecoration(
                          labelText: l10n.adminCmsCategoryLabel),
                      items: _axes
                          .map(
                            (axis) => DropdownMenuItem<String>(
                              value: axis.key,
                              child: Text(axis.titleEn),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setStateDialog(
                        () => selectedAxisKey = value ?? selectedAxisKey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: slug,
                        decoration: InputDecoration(
                            labelText: l10n.adminCmsCategorySlug)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: titleEn,
                        decoration: InputDecoration(
                            labelText: l10n.adminCmsTitleEnLabel)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: titleAr,
                        decoration: InputDecoration(
                            labelText: l10n.adminCmsTitleArLabel)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: descEn,
                        decoration: InputDecoration(
                            labelText: l10n.adminCmsDescriptionEnLabel)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: descAr,
                        decoration: InputDecoration(
                            labelText: l10n.adminCmsDescriptionArLabel)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel)),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.save)),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) return null;
    if (selectedAxisKey.trim().isEmpty) {
      _showFeedback(l10n.errorTitle, isError: true);
      return null;
    }
    if (titleEn.text.trim().isEmpty) {
      _showFeedback(l10n.adminCmsValidationTitleEnRequired, isError: true);
      return null;
    }
    if (titleAr.text.trim().isEmpty) {
      _showFeedback(l10n.adminCmsValidationTitleArRequired, isError: true);
      return null;
    }
    if (slug.text.trim().isEmpty) {
      slug.text = titleEn.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
    }
    final repo = ref.read(adminManagementRepositoryProvider);
    try {
      late final AdminCmsCategory savedCategory;
      if (category == null) {
        savedCategory = await repo.createCategory(
          axisKey: selectedAxisKey,
          slug: slug.text.trim(),
          titleEn: titleEn.text.trim(),
          titleAr: titleAr.text.trim(),
          descriptionEn: descEn.text.trim(),
          descriptionAr: descAr.text.trim(),
        );
      } else {
        savedCategory = await repo.updateCategory(
          category.id,
          axisKey: selectedAxisKey,
          slug: slug.text.trim(),
          titleEn: titleEn.text.trim(),
          titleAr: titleAr.text.trim(),
          descriptionEn: descEn.text.trim(),
          descriptionAr: descAr.text.trim(),
        );
      }
      _showFeedback(l10n.adminCmsCategorySaved);
      await _loadAll();
      return savedCategory;
    } catch (error) {
      _showFeedback(_extractErrorMessage(l10n, error), isError: true);
      return null;
    }
  }

  Future<void> _deleteCategory(AdminCmsCategory category) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: l10n.adminCmsDeleteCategoryTitle,
      message: l10n.adminCmsDeleteCategoryConfirm,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(adminManagementRepositoryProvider)
          .deleteCategory(category.id);
      if (!mounted) return;
      await _loadAll();
    } catch (error) {
      _showFeedback(_extractErrorMessage(l10n, error), isError: true);
    }
  }

  Future<void> _saveContent({
    AdminCmsContent? content,
    String? initialType,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final metadataMap =
        Map<String, dynamic>.from(content?.metadataJson ?? const {});
    final advancedMetadata = Map<String, dynamic>.from(metadataMap)
      ..remove('duration_minutes')
      ..remove('difficulty')
      ..remove('tags')
      ..remove('featured')
      ..remove('video_url')
      ..remove('video_preview_url')
      ..remove('video_provider')
      ..remove('video_public_id')
      ..remove('duration_seconds')
      ..remove('video_host_tier')
      ..remove('resource_type')
      ..remove('folder')
      ..remove('format')
      ..remove('bytes')
      ..remove('behavioral_value')
      ..remove('behavioral_method');
    final titleEn = TextEditingController(text: content?.titleEn ?? '');
    final titleAr = TextEditingController(text: content?.titleAr ?? '');
    final descEn = TextEditingController(text: content?.descriptionEn ?? '');
    final descAr = TextEditingController(text: content?.descriptionAr ?? '');
    final bodyEn = TextEditingController(text: content?.bodyEn ?? '');
    final bodyAr = TextEditingController(text: content?.bodyAr ?? '');
    final thumb = TextEditingController(text: content?.thumbnailUrl ?? '');
    final videoUrl =
        TextEditingController(text: content?.effectiveVideoUrl ?? '');
    final videoPreviewUrl =
        TextEditingController(text: content?.videoPreviewUrl ?? '');
    final videoProvider =
        TextEditingController(text: content?.effectiveVideoProvider ?? '');
    final videoHostTier =
        TextEditingController(text: content?.videoHostTier ?? '');
    final age = TextEditingController(text: content?.ageGroup ?? '');
    final duration = TextEditingController(
      text: metadataMap['duration_minutes']?.toString() ?? '',
    );
    final difficulty = TextEditingController(
      text: metadataMap['difficulty']?.toString() ?? '',
    );
    final tags = TextEditingController(
      text: metadataMap['tags'] is List
          ? (metadataMap['tags'] as List<dynamic>).join(', ')
          : '',
    );
    final metadata = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(advancedMetadata),
    );
    String selectedAxisKey =
        content?.axisKey ?? content?.category?.axisKey ?? _selectedAxisKey;
    int? selectedCategoryId = content?.categoryId;
    String selectedType = content?.contentType ?? initialType ?? 'lesson';
    String selectedStatus =
        content?.status ?? (selectedType == 'video' ? 'published' : 'draft');
    String selectedBehavioralValue =
        metadataMap['behavioral_value']?.toString() ?? '';
    String selectedBehavioralMethod =
        metadataMap['behavioral_method']?.toString() ?? '';
    bool featured = metadataMap['featured'] == true;
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    List<AdminCmsCategory> categoriesForAxis() {
      if (selectedAxisKey.isEmpty) {
        return _categories;
      }
      return _categories
          .where((category) => category.axisKey == selectedAxisKey)
          .toList();
    }

    AdminCmsCategory? selectedCategoryForAxis() {
      if (selectedCategoryId == null) {
        return null;
      }
      for (final category in categoriesForAxis()) {
        if (category.id == selectedCategoryId) {
          return category;
        }
      }
      return null;
    }

    String categoryTitle(AdminCmsCategory category) =>
        isArabic ? category.titleAr : category.titleEn;

    List<String> behavioralValueTitles() => behavioralValues
        .map((item) => item['title']?.toString() ?? '')
        .where((title) => title.isNotEmpty)
        .toList();

    List<String> behavioralMethodTitles() => behavioralMethods
        .map((item) => item['title']?.toString() ?? '')
        .where((title) => title.isNotEmpty)
        .toList();

    String normalizeBehavioralTitle(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

    AdminCmsCategory? categoryForBehavioralValue(String value) {
      final normalizedValue = normalizeBehavioralTitle(value);
      if (normalizedValue.isEmpty) {
        return null;
      }
      for (final category in categoriesForAxis()) {
        if (category.axisKey != 'behavioral') {
          continue;
        }
        final terms = [
          category.slug,
          category.titleEn,
          category.titleAr,
        ].map(normalizeBehavioralTitle);
        if (terms.contains(normalizedValue)) {
          return category;
        }
      }
      return null;
    }

    if (selectedAxisKey == 'behavioral' &&
        selectedBehavioralValue.isEmpty &&
        selectedCategoryId != null) {
      final category = selectedCategoryForAxis();
      if (category != null) {
        final normalizedCategory = normalizeBehavioralTitle(category.titleEn);
        for (final value in behavioralValueTitles()) {
          if (normalizeBehavioralTitle(value) == normalizedCategory) {
            selectedBehavioralValue = value;
            break;
          }
        }
      }
    }
    if (!behavioralValueTitles().contains(selectedBehavioralValue)) {
      selectedBehavioralValue = '';
    }
    if (!behavioralMethodTitles().contains(selectedBehavioralMethod)) {
      selectedBehavioralMethod = '';
    }

    String videoPlacementLabel() {
      final axisTitle = _axisTitle(context, selectedAxisKey);
      final category = selectedCategoryForAxis();
      if (category != null) {
        return '$axisTitle / ${categoryTitle(category)}';
      }
      return '$axisTitle / ${l10n.adminCmsNoCategory}';
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
                vertical: 24,
              ),
              title: Text(content == null
                  ? (l10n.adminCmsCreateContentTitle)
                  : (l10n.adminCmsEditContentTitle)),
              content: SizedBox(
                width: adminResponsiveDialogWidth(
                  context,
                  preferredWidth: 700,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_axes.isNotEmpty) ...[
                        DropdownButtonFormFieldCompat<String>(
                          initialValue:
                              selectedAxisKey.isEmpty ? null : selectedAxisKey,
                          decoration: InputDecoration(
                            hintText: _axisTitle(context, selectedAxisKey),
                            prefixIcon: const Icon(Icons.account_tree_outlined),
                          ),
                          items: _axes
                              .map(
                                (axis) => DropdownMenuItem<String>(
                                  value: axis.key,
                                  child: Text(_axisTitle(context, axis.key)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setStateDialog(() {
                            selectedAxisKey = value ?? '';
                            if (selectedAxisKey != 'behavioral') {
                              selectedBehavioralValue = '';
                              selectedBehavioralMethod = '';
                            }
                            final availableCategoryIds = categoriesForAxis()
                                .map((category) => category.id)
                                .toSet();
                            if (!availableCategoryIds.contains(
                              selectedCategoryId,
                            )) {
                              selectedCategoryId = null;
                            }
                          }),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormFieldCompat<int?>(
                              initialValue: selectedCategoryId,
                              decoration: InputDecoration(
                                  labelText: l10n.adminCmsCategoryLabel),
                              items: [
                                DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text(l10n.adminCmsNoCategory)),
                                ...categoriesForAxis().map((category) =>
                                    DropdownMenuItem<int?>(
                                        value: category.id,
                                        child: Text(categoryTitle(category)))),
                              ],
                              onChanged: (value) => setStateDialog(() {
                                selectedCategoryId = value;
                                if (selectedAxisKey == 'behavioral' &&
                                    value != null) {
                                  final category = selectedCategoryForAxis();
                                  if (category != null) {
                                    for (final behavioralValue
                                        in behavioralValueTitles()) {
                                      if (normalizeBehavioralTitle(
                                            behavioralValue,
                                          ) ==
                                          normalizeBehavioralTitle(
                                            category.titleEn,
                                          )) {
                                        selectedBehavioralValue =
                                            behavioralValue;
                                        break;
                                      }
                                    }
                                  }
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: l10n.adminCmsCategoryCreateTitle,
                            onPressed: () async {
                              final createdCategory = await _saveCategory(
                                initialAxisKey: selectedAxisKey,
                              );
                              if (!mounted || createdCategory == null) {
                                return;
                              }
                              setStateDialog(() {
                                selectedAxisKey = createdCategory.axisKey;
                                selectedCategoryId = createdCategory.id;
                              });
                            },
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextField(
                              controller: titleEn,
                              decoration: InputDecoration(
                                  labelText: l10n.adminCmsTitleEnLabel)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                              controller: titleAr,
                              decoration: InputDecoration(
                                  labelText: l10n.adminCmsTitleArLabel)),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormFieldCompat<String>(
                            initialValue: selectedType,
                            decoration: InputDecoration(
                                labelText: l10n.adminCmsTypeLabel),
                            items: _contentTypeItems(l10n),
                            onChanged: (value) => setStateDialog(() {
                              selectedType = value ?? 'lesson';
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormFieldCompat<String>(
                            initialValue: selectedStatus,
                            decoration: InputDecoration(
                                labelText: l10n.adminCmsStatusLabel),
                            items: _contentStatusOptions(l10n)
                                .map((item) => DropdownMenuItem(
                                    value: item.value, child: Text(item.label)))
                                .toList(),
                            onChanged: (value) => setStateDialog(
                                () => selectedStatus = value ?? 'draft'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      if (selectedAxisKey == 'behavioral') ...[
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            l10n.adminCmsBehavioralPlacementTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: DropdownButtonFormFieldCompat<String>(
                              initialValue: selectedBehavioralValue.isEmpty
                                  ? null
                                  : selectedBehavioralValue,
                              decoration: InputDecoration(
                                labelText: l10n.adminCmsBehavioralValueLabel,
                              ),
                              items: behavioralValueTitles()
                                  .map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setStateDialog(() {
                                selectedBehavioralValue = value ?? '';
                                final matchingCategory =
                                    categoryForBehavioralValue(
                                  selectedBehavioralValue,
                                );
                                if (matchingCategory != null) {
                                  selectedCategoryId = matchingCategory.id;
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormFieldCompat<String>(
                              initialValue: selectedBehavioralMethod.isEmpty
                                  ? null
                                  : selectedBehavioralMethod,
                              decoration: InputDecoration(
                                labelText: l10n.adminCmsBehavioralMethodLabel,
                              ),
                              items: behavioralMethodTitles()
                                  .map(
                                    (method) => DropdownMenuItem<String>(
                                      value: method,
                                      child: Text(method),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setStateDialog(
                                () => selectedBehavioralMethod = value ?? '',
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                          controller: descEn,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsDescriptionEnLabel)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: descAr,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsDescriptionArLabel)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: bodyEn,
                          minLines: 4,
                          maxLines: 6,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsBodyEnLabel)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: bodyAr,
                          minLines: 4,
                          maxLines: 6,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsBodyArLabel)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: thumb,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsThumbnailLabel)),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.adminCmsVideoSectionTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                videoPlacementLabel(),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: videoUrl,
                        decoration: InputDecoration(
                          labelText: l10n.adminCmsVideoUrlLabel,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: videoPreviewUrl,
                        decoration: InputDecoration(
                          labelText: l10n.adminCmsVideoPreviewUrlLabel,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selectedType != 'video')
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: videoProvider,
                              decoration: InputDecoration(
                                labelText: l10n.adminCmsVideoProviderLabel,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: videoHostTier,
                              decoration: InputDecoration(
                                labelText: l10n.adminCmsVideoHostTierLabel,
                              ),
                            ),
                          ),
                        ])
                      else
                        TextField(
                          controller: videoHostTier,
                          decoration: InputDecoration(
                            labelText: l10n.adminCmsVideoHostTierLabel,
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                          controller: age,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsAgeGroupLabel)),
                      const SizedBox(height: 16),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.adminCmsStructuredMetadataTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: duration,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.adminCmsMetadataDurationLabel,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: difficulty,
                            decoration: InputDecoration(
                              labelText: l10n.adminCmsMetadataDifficultyLabel,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tags,
                        decoration: InputDecoration(
                          labelText: l10n.adminCmsMetadataTagsLabel,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: featured,
                        title: Text(l10n.adminCmsMetadataFeaturedLabel),
                        onChanged: (value) =>
                            setStateDialog(() => featured = value),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.adminCmsAdvancedJsonTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.adminCmsAdvancedJsonHelp,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                          controller: metadata,
                          minLines: 4,
                          maxLines: 8,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsMetadataLabel)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel)),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.save)),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) return;
    if (titleEn.text.trim().isEmpty) {
      _showFeedback(l10n.adminCmsValidationTitleEnRequired, isError: true);
      return;
    }
    if (titleAr.text.trim().isEmpty) {
      _showFeedback(l10n.adminCmsValidationTitleArRequired, isError: true);
      return;
    }
    if (selectedStatus == 'published' &&
        selectedType != 'video' &&
        bodyEn.text.trim().isEmpty) {
      _showFeedback(l10n.adminCmsValidationBodyEnRequired, isError: true);
      return;
    }
    if (selectedStatus == 'published' &&
        selectedType != 'video' &&
        bodyAr.text.trim().isEmpty) {
      _showFeedback(l10n.adminCmsValidationBodyArRequired, isError: true);
      return;
    }
    if (selectedType == 'video' && selectedCategoryId == null) {
      _showFeedback(
        '${l10n.adminCmsCategoryLabel}: ${l10n.fieldRequired}',
        isError: true,
      );
      return;
    }
    if (selectedAxisKey == 'behavioral' &&
        (selectedBehavioralValue.trim().isEmpty ||
            selectedBehavioralMethod.trim().isEmpty)) {
      _showFeedback(
        l10n.adminCmsValidationBehavioralPlacementRequired,
        isError: true,
      );
      return;
    }
    final thumbValue = thumb.text.trim();
    final videoUrlValue = videoUrl.text.trim();
    final videoPreviewUrlValue = videoPreviewUrl.text.trim();
    final normalizedVideoProvider = videoProvider.text.trim();
    final derivedThumbnailUrl = thumbValue.isNotEmpty ? thumbValue : null;
    if (selectedType == 'video' &&
        selectedStatus == 'published' &&
        videoUrlValue.isEmpty) {
      _showFeedback(l10n.adminCmsValidationVideoRequired, isError: true);
      return;
    }
    final urlValues = [thumbValue, videoUrlValue, videoPreviewUrlValue];
    for (final value in urlValues) {
      if (value.isEmpty) {
        continue;
      }
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !uri.hasAuthority ||
          !['http', 'https'].contains(uri.scheme)) {
        _showFeedback(l10n.adminCmsValidationInvalidUrl, isError: true);
        return;
      }
    }
    final ageValue = age.text.trim();
    if (ageValue.isNotEmpty &&
        !RegExp(r'^\s*(\d{1,2}\s*-\s*\d{1,2}|\d{1,2}\+)\s*$')
            .hasMatch(ageValue)) {
      _showFeedback(l10n.adminCmsValidationInvalidAgeGroup, isError: true);
      return;
    }
    Map<String, dynamic> advancedJson;
    try {
      if (metadata.text.trim().isEmpty || metadata.text.trim() == '{}') {
        advancedJson = <String, dynamic>{};
      } else {
        final parsed = jsonDecode(metadata.text.trim());
        if (parsed is! Map) {
          _showFeedback(l10n.adminCmsValidationInvalidJsonObject,
              isError: true);
          return;
        }
        advancedJson = Map<String, dynamic>.from(parsed);
      }
    } on FormatException {
      _showFeedback(l10n.adminCmsValidationInvalidJsonSyntax, isError: true);
      return;
    }
    final tagsList = tags.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final videoProviderValue = normalizedVideoProvider;
    final payload = {
      'category_id': selectedCategoryId,
      'content_type': selectedType,
      'status': selectedStatus,
      'title_en': titleEn.text.trim(),
      'title_ar': titleAr.text.trim(),
      'description_en': descEn.text.trim(),
      'description_ar': descAr.text.trim(),
      'body_en': bodyEn.text.trim(),
      'body_ar': bodyAr.text.trim(),
      'thumbnail_url': derivedThumbnailUrl,
      'video_url': videoUrlValue.isEmpty ? null : videoUrlValue,
      'video_provider': videoProviderValue.isEmpty ? null : videoProviderValue,
      'video_public_id': null,
      'video_duration_seconds': null,
      'age_group': ageValue,
      'metadata_json': {
        ...advancedJson,
        if (duration.text.trim().isNotEmpty)
          'duration_minutes':
              int.tryParse(duration.text.trim()) ?? duration.text.trim(),
        if (difficulty.text.trim().isNotEmpty)
          'difficulty': difficulty.text.trim(),
        if (tagsList.isNotEmpty) 'tags': tagsList,
        if (selectedAxisKey == 'behavioral') ...{
          'behavioral_value': selectedBehavioralValue.trim(),
          'behavioral_method': selectedBehavioralMethod.trim(),
        },
        if (videoPreviewUrlValue.isNotEmpty)
          'video_preview_url': videoPreviewUrlValue,
        if (videoProviderValue.isNotEmpty) 'video_provider': videoProviderValue,
        if (videoHostTier.text.trim().isNotEmpty)
          'video_host_tier': videoHostTier.text.trim(),
        'featured': featured,
      },
    };
    final repo = ref.read(adminManagementRepositoryProvider);
    try {
      if (content == null) {
        await repo.createContent(payload);
      } else {
        await repo.updateContent(content.id, payload);
      }
      _showFeedback(l10n.adminCmsContentSaved);
      await _loadAll();
    } catch (error) {
      _showFeedback(_extractErrorMessage(l10n, error), isError: true);
    }
  }

  Future<void> _previewContent(AdminCmsContent content) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final detail = await ref
          .read(adminManagementRepositoryProvider)
          .fetchContentDetail(content.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
            vertical: 24,
          ),
          title: Text(l10n.adminCmsPreviewTitle),
          content: SizedBox(
            width: adminResponsiveDialogWidth(
              context,
              preferredWidth: 720,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.adminCmsPreviewEnglishSection,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detail.titleEn.trim().isEmpty
                        ? l10n.adminCmsPreviewEmpty
                        : detail.titleEn,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text((detail.descriptionEn ?? '').trim().isEmpty
                      ? l10n.notAvailable
                      : detail.descriptionEn!),
                  const SizedBox(height: 8),
                  Text((detail.bodyEn ?? '').trim().isEmpty
                      ? l10n.notAvailable
                      : detail.bodyEn!),
                  const SizedBox(height: 16),
                  Text(
                    l10n.adminCmsPreviewArabicSection,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detail.titleAr.trim().isEmpty
                        ? l10n.adminCmsPreviewEmpty
                        : detail.titleAr,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text((detail.descriptionAr ?? '').trim().isEmpty
                      ? l10n.notAvailable
                      : detail.descriptionAr!),
                  const SizedBox(height: 8),
                  Text((detail.bodyAr ?? '').trim().isEmpty
                      ? l10n.notAvailable
                      : detail.bodyAr!),
                  const SizedBox(height: 16),
                  Text(
                    l10n.adminCmsPreviewMetadataSection,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.adminCmsCategoryLabel}: ${detail.category?.titleEn ?? l10n.notAvailable}',
                  ),
                  Text(
                    '${l10n.adminCmsTypeLabel}: ${_contentTypeLabel(detail.contentType, l10n)}',
                  ),
                  Text(
                    '${l10n.adminCmsStatusLabel}: ${_statusLabel(detail.status, l10n)}',
                  ),
                  Text(
                    '${l10n.adminCmsAgeGroupLabel}: ${detail.ageGroup ?? l10n.notAvailable}',
                  ),
                  Text(
                    '${l10n.adminCmsLinkedQuizzes}: ${detail.quizCount}',
                  ),
                  if ((detail.effectiveVideoUrl ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.adminCmsVideoSectionTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _AdminVideoPreviewCard(
                      videoUrl: detail.effectiveVideoUrl!,
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (detail.metadataJson.isEmpty)
                    Text(l10n.adminCmsPreviewEmpty)
                  else
                    ...detail.metadataJson.entries.map(
                      (entry) => Text('${entry.key}: ${entry.value}'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      );
    } catch (error) {
      _showFeedback(_extractErrorMessage(l10n, error), isError: true);
    }
  }

  Future<void> _togglePublish(AdminCmsContent content) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(adminManagementRepositoryProvider);
    try {
      if (content.status == 'published') {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.adminCmsUnpublishConfirmTitle),
                content: Text(l10n.adminCmsUnpublishConfirmMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.adminCmsUnpublishAction),
                  ),
                ],
              ),
            ) ??
            false;
        if (!confirmed) return;
        await repo.unpublishContent(content.id);
        _showFeedback(l10n.adminCmsUnpublishSuccess);
      } else {
        final detail = await repo.fetchContentDetail(content.id);
        if (detail.titleEn.trim().isEmpty) {
          _showFeedback(l10n.adminCmsValidationTitleEnRequired, isError: true);
          return;
        }
        if (detail.titleAr.trim().isEmpty) {
          _showFeedback(l10n.adminCmsValidationTitleArRequired, isError: true);
          return;
        }
        if ((detail.bodyEn ?? '').trim().isEmpty) {
          _showFeedback(l10n.adminCmsValidationBodyEnRequired, isError: true);
          return;
        }
        if ((detail.bodyAr ?? '').trim().isEmpty) {
          _showFeedback(l10n.adminCmsValidationBodyArRequired, isError: true);
          return;
        }
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(l10n.adminCmsPublishConfirmTitle),
                content: Text(l10n.adminCmsPublishConfirmMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(l10n.adminCmsPublishAction),
                  ),
                ],
              ),
            ) ??
            false;
        if (!confirmed) return;
        await repo.publishContent(content.id);
        _showFeedback(l10n.adminCmsPublishSuccess);
      }
      if (!mounted) return;
      await _loadAll();
    } catch (error) {
      _showFeedback(_extractErrorMessage(l10n, error), isError: true);
    }
  }

  Future<void> _deleteContent(AdminCmsContent content) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: l10n.adminCmsDeleteContentTitle,
      message: l10n.adminCmsDeleteContentConfirm,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(adminManagementRepositoryProvider)
          .deleteContent(content.id);
      if (!mounted) return;
      await _loadAll();
    } catch (error) {
      _showFeedback(_extractErrorMessage(l10n, error), isError: true);
    }
  }

  Future<void> _saveQuiz({AdminCmsQuiz? quiz}) async {
    final l10n = AppLocalizations.of(context)!;
    final titleEn = TextEditingController(text: quiz?.titleEn ?? '');
    final titleAr = TextEditingController(text: quiz?.titleAr ?? '');
    final descEn = TextEditingController(text: quiz?.descriptionEn ?? '');
    final descAr = TextEditingController(text: quiz?.descriptionAr ?? '');
    final questions = TextEditingController(
      text: const JsonEncoder.withIndent('  ')
          .convert(quiz?.questionsJson ?? const []),
    );
    int? selectedCategoryId = quiz?.categoryId;
    int? selectedContentId = quiz?.contentId;
    String selectedStatus = quiz?.status ?? 'draft';
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
                vertical: 24,
              ),
              title: Text(quiz == null
                  ? (l10n.adminCmsCreateQuizTitle)
                  : (l10n.adminCmsEditQuizTitle)),
              content: SizedBox(
                width: adminResponsiveDialogWidth(
                  context,
                  preferredWidth: 680,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormFieldCompat<int?>(
                        initialValue: selectedCategoryId,
                        decoration: InputDecoration(
                            labelText: l10n.adminCmsCategoryLabel),
                        items: [
                          DropdownMenuItem<int?>(
                              value: null,
                              child: Text(l10n.adminCmsNoCategory)),
                          ..._categoriesForSelectedAxis.map((category) =>
                              DropdownMenuItem<int?>(
                                  value: category.id,
                                  child: Text(category.titleEn))),
                        ],
                        onChanged: (value) =>
                            setStateDialog(() => selectedCategoryId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormFieldCompat<int?>(
                        initialValue: selectedContentId,
                        decoration: InputDecoration(
                            labelText: l10n.adminCmsLinkedContentLabel),
                        items: [
                          DropdownMenuItem<int?>(
                              value: null,
                              child: Text(l10n.adminCmsNoLinkedContent)),
                          ..._contents.map((content) => DropdownMenuItem<int?>(
                              value: content.id, child: Text(content.titleEn))),
                        ],
                        onChanged: (value) =>
                            setStateDialog(() => selectedContentId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormFieldCompat<String>(
                        initialValue: selectedStatus,
                        decoration: InputDecoration(
                            labelText: l10n.adminCmsStatusLabel),
                        items: _quizStatusOptions(l10n)
                            .map((item) => DropdownMenuItem(
                                value: item.value, child: Text(item.label)))
                            .toList(),
                        onChanged: (value) => setStateDialog(
                            () => selectedStatus = value ?? 'draft'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                          controller: titleEn,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsTitleEnLabel)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: titleAr,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsTitleArLabel)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: descEn,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsDescriptionEnLabel)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: descAr,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsDescriptionArLabel)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: questions,
                          minLines: 6,
                          maxLines: 12,
                          decoration: InputDecoration(
                              labelText: l10n.adminCmsQuestionsJsonLabel)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel)),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.save)),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) return;
    if (titleEn.text.trim().isEmpty) {
      _showFeedback(l10n.adminCmsValidationTitleEnRequired, isError: true);
      return;
    }
    if (titleAr.text.trim().isEmpty) {
      _showFeedback(l10n.adminCmsValidationTitleArRequired, isError: true);
      return;
    }
    List<Map<String, dynamic>> questionsJson;
    try {
      final parsed = jsonDecode(
          questions.text.trim().isEmpty ? '[]' : questions.text.trim());
      if (parsed is! List) {
        _showFeedback(l10n.adminCmsValidationInvalidJsonList, isError: true);
        return;
      }
      questionsJson = List<Map<String, dynamic>>.from(
        parsed.map((item) => Map<String, dynamic>.from(item as Map)),
      );
    } on FormatException {
      _showFeedback(l10n.adminCmsValidationInvalidJsonSyntax, isError: true);
      return;
    }
    if (selectedStatus == 'published' && questionsJson.isEmpty) {
      _showFeedback(l10n.adminCmsValidationQuestionRequired, isError: true);
      return;
    }
    for (final question in questionsJson) {
      final promptEn = (question['prompt_en'] ?? '').toString().trim();
      final promptAr = (question['prompt_ar'] ?? '').toString().trim();
      if (promptEn.isEmpty && promptAr.isEmpty) {
        _showFeedback(l10n.adminCmsValidationQuestionPromptRequired,
            isError: true);
        return;
      }
      final options = (question['options'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .toList();
      if (options.length < 2) {
        _showFeedback(l10n.adminCmsValidationQuestionOptionsRequired,
            isError: true);
        return;
      }
      if (options.any((option) => option.isEmpty)) {
        _showFeedback(l10n.adminCmsValidationQuestionOptionTextRequired,
            isError: true);
        return;
      }
      final correctIndex = question['correct_index'];
      if (correctIndex is! int ||
          correctIndex < 0 ||
          correctIndex >= options.length) {
        _showFeedback(l10n.adminCmsValidationQuestionCorrectAnswerRequired,
            isError: true);
        return;
      }
    }
    final payload = {
      'content_id': selectedContentId,
      'category_id': selectedCategoryId,
      'status': selectedStatus,
      'title_en': titleEn.text.trim(),
      'title_ar': titleAr.text.trim(),
      'description_en': descEn.text.trim(),
      'description_ar': descAr.text.trim(),
      'questions_json': questionsJson,
    };
    final repo = ref.read(adminManagementRepositoryProvider);
    try {
      if (quiz == null) {
        await repo.createQuiz(payload);
      } else {
        await repo.updateQuiz(quiz.id, payload);
      }
      _showFeedback(l10n.adminCmsQuizSaved);
      if (!mounted) return;
      await _loadAll();
    } catch (error) {
      _showFeedback(_extractErrorMessage(l10n, error), isError: true);
    }
  }

  Future<void> _deleteQuiz(AdminCmsQuiz quiz) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: l10n.adminCmsDeleteQuizTitle,
      message: l10n.adminCmsDeleteQuizConfirm,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(adminManagementRepositoryProvider).deleteQuiz(quiz.id);
      if (!mounted) return;
      await _loadAll();
    } catch (error) {
      _showFeedback(_extractErrorMessage(l10n, error), isError: true);
    }
  }

  Future<void> _previewQuiz(AdminCmsQuiz quiz) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
          vertical: 24,
        ),
        title: Text(l10n.adminCmsQuizPreviewAction),
        content: SizedBox(
          width: adminResponsiveDialogWidth(
            context,
            preferredWidth: 700,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  quiz.titleEn.trim().isEmpty
                      ? l10n.adminCmsPreviewEmpty
                      : quiz.titleEn,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  quiz.titleAr.trim().isEmpty
                      ? l10n.adminCmsPreviewEmpty
                      : quiz.titleAr,
                ),
                const SizedBox(height: 8),
                Text(
                  (quiz.descriptionEn ?? '').trim().isEmpty
                      ? l10n.notAvailable
                      : quiz.descriptionEn!,
                ),
                const SizedBox(height: 16),
                Text(
                  '${l10n.adminCmsLinkedContentLabel}: ${quiz.contentTitleEn ?? l10n.adminCmsNoLinkedContent}',
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.adminCmsPreviewQuestionsSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (quiz.questionsJson.isEmpty)
                  Text(l10n.adminCmsPreviewEmpty)
                else
                  ...quiz.questionsJson.asMap().entries.map((entry) {
                    final question = entry.value;
                    final options =
                        (question['options'] as List<dynamic>? ?? const [])
                            .map((item) => item.toString())
                            .toList();
                    final correctIndex = question['correct_index'] as int?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.adminCmsQuestionLabel(entry.key + 1),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (question['prompt_en'] ??
                                        question['prompt_ar'] ??
                                        '')
                                    .toString()
                                    .trim()
                                    .isEmpty
                                ? l10n.adminCmsPreviewEmpty
                                : (question['prompt_en'] ??
                                        question['prompt_ar'])
                                    .toString(),
                          ),
                          const SizedBox(height: 6),
                          ...List.generate(options.length, (index) {
                            final marker = correctIndex == index ? '*' : '-';
                            return Text('$marker ${options[index]}');
                          }),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.content.view') ?? false)) {
      return const AdminPermissionPlaceholder();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: l10n.adminCmsTitle,
                subtitle: l10n.adminCmsSubtitle,
                actions: [
                  OutlinedButton.icon(
                    onPressed: _loadAll,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_axes.isNotEmpty) ...[
                _buildAxisWorkspace(context, l10n, admin),
                const SizedBox(height: 20),
              ],
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: [
                  Tab(text: l10n.adminCmsCategoriesTab),
                  Tab(text: l10n.adminCmsContentsTab),
                  Tab(text: l10n.adminCmsQuizzesTab),
                ],
              ),
              const SizedBox(height: 20),
              if (_loading)
                const AdminLoadingState()
              else if (_error != null)
                AdminErrorState(message: _error!, onRetry: _loadAll)
              else
                SizedBox(
                  height: compact ? 980 : 860,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildCategoriesTab(context, l10n, admin),
                      _buildContentsTab(context, l10n, admin),
                      _buildQuizzesTab(context, l10n, admin),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab(
      BuildContext context, AppLocalizations l10n, admin) {
    final canCreate = admin?.hasPermission('admin.content.create') ?? false;
    final canEdit = admin?.hasPermission('admin.content.edit') ?? false;
    final canDelete = admin?.hasPermission('admin.content.delete') ?? false;
    final axis = _selectedAxisSummary;
    final categories = _categoriesForSelectedAxis;
    return Column(
      children: [
        if (axis != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${axis.titleEn} • ${axis.categoryCount}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
                onPressed: canCreate ? () => _saveCategory() : null,
                icon: const Icon(Icons.add),
                label: Text(l10n.adminCmsAddCategory)),
            OutlinedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                child: ListTile(
                  title: Text(category.titleEn),
                  subtitle: Text(
                      '${category.slug}\n${l10n.adminCmsCategoryUsage}: ${category.contentCount} / ${category.quizCount}'),
                  isThreeLine: true,
                  trailing: Wrap(spacing: 8, children: [
                    IconButton(
                        onPressed: canEdit
                            ? () => _saveCategory(category: category)
                            : null,
                        icon: const Icon(Icons.edit_outlined)),
                    IconButton(
                        onPressed:
                            canDelete ? () => _deleteCategory(category) : null,
                        icon: const Icon(Icons.delete_outline)),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContentsTab(BuildContext context, AppLocalizations l10n, admin) {
    final canCreate = admin?.hasPermission('admin.content.create') ?? false;
    final canEdit = admin?.hasPermission('admin.content.edit') ?? false;
    final canPublish = admin?.hasPermission('admin.content.publish') ?? false;
    final canDelete = admin?.hasPermission('admin.content.delete') ?? false;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 720;
      final fieldWidth = compact ? constraints.maxWidth : 240.0;
      final dropdownWidth = compact ? constraints.maxWidth : 200.0;
      final categoryWidth = compact ? constraints.maxWidth : 220.0;
      return Column(children: [
        AdminFilterBar(children: [
          SizedBox(
            width: fieldWidth,
            child: TextFormField(
              initialValue: _contentSearch,
              decoration: InputDecoration(labelText: l10n.adminCmsSearchLabel),
              onFieldSubmitted: (value) {
                setState(() {
                  _contentSearch = value.trim();
                  _contentPage = 1;
                });
                _loadAll();
              },
            ),
          ),
          SizedBox(
            width: dropdownWidth,
            child: DropdownButtonFormFieldCompat<String>(
              initialValue: _contentType,
              decoration: InputDecoration(labelText: l10n.adminCmsTypeLabel),
              items: [
                DropdownMenuItem(
                    value: '', child: Text(l10n.adminCmsStatusAll)),
                ..._contentTypeItems(l10n),
              ],
              onChanged: (value) {
                setState(() {
                  _contentType = value ?? '';
                  _contentPage = 1;
                });
                _loadAll();
              },
            ),
          ),
          SizedBox(
            width: dropdownWidth,
            child: DropdownButtonFormFieldCompat<String>(
              initialValue: _contentStatus,
              decoration: InputDecoration(labelText: l10n.adminCmsStatusLabel),
              items: [
                DropdownMenuItem(
                    value: '', child: Text(l10n.adminCmsStatusAll)),
                ..._contentStatusOptions(l10n).map((item) => DropdownMenuItem(
                    value: item.value, child: Text(item.label))),
              ],
              onChanged: (value) {
                setState(() {
                  _contentStatus = value ?? '';
                  _contentPage = 1;
                });
                _loadAll();
              },
            ),
          ),
          SizedBox(
            width: categoryWidth,
            child: DropdownButtonFormFieldCompat<int?>(
              initialValue: _contentCategoryId,
              decoration:
                  InputDecoration(labelText: l10n.adminCmsCategoryLabel),
              items: [
                DropdownMenuItem<int?>(
                    value: null, child: Text(l10n.adminCmsAllCategories)),
                ..._categoriesForSelectedAxis.map((item) =>
                    DropdownMenuItem<int?>(
                        value: item.id, child: Text(item.titleEn))),
              ],
              onChanged: (value) {
                setState(() {
                  _contentCategoryId = value;
                  _contentPage = 1;
                });
                _loadAll();
              },
            ),
          ),
          FilledButton.icon(
              onPressed: canCreate ? () => _saveContent() : null,
              icon: const Icon(Icons.add),
              label: Text(l10n.adminCmsAddContent)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _contents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final content = _contents[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(content.titleEn,
                                  style:
                                      Theme.of(context).textTheme.titleMedium)),
                          _CmsStatusChip(
                              label: _statusLabel(content.status, l10n),
                              status: content.status),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                            (content.descriptionEn ?? '').trim().isEmpty
                                ? l10n.notAvailable
                                : content.descriptionEn!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          if ((content.axisKey ?? '').isNotEmpty)
                            Text(_axisTitle(context, content.axisKey)),
                          Text(
                              '${l10n.adminCmsCategoryLabel}: ${content.category?.titleEn ?? l10n.notAvailable}'),
                          Text(
                              '${l10n.adminCmsTypeLabel}: ${_contentTypeLabel(content.contentType, l10n)}'),
                          Text(
                              '${l10n.adminCmsLinkedQuizzes}: ${content.quizCount}'),
                        ]),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          OutlinedButton(
                              onPressed: () => _previewContent(content),
                              child: Text(l10n.adminCmsPreviewAction)),
                          OutlinedButton(
                              onPressed: canEdit
                                  ? () => _saveContent(content: content)
                                  : null,
                              child: Text(l10n.edit)),
                          OutlinedButton(
                              onPressed: canPublish
                                  ? () => _togglePublish(content)
                                  : null,
                              child: Text(content.status == 'published'
                                  ? l10n.adminCmsUnpublishAction
                                  : l10n.adminCmsPublishAction)),
                          OutlinedButton(
                              onPressed: canDelete
                                  ? () => _deleteContent(content)
                                  : null,
                              child: Text(l10n.delete)),
                        ]),
                      ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AdminPaginationBar(
          summary: l10n.adminPaginationSummary(
              (_contentPagination['page'] as int?) ?? _contentPage,
              (_contentPagination['total_pages'] as int?) ?? 1,
              (_contentPagination['total'] as int?) ?? _contents.length),
          hasPrevious: (_contentPagination['has_previous'] as bool?) ?? false,
          hasNext: (_contentPagination['has_next'] as bool?) ?? false,
          previousLabel: l10n.adminPaginationPrevious,
          nextLabel: l10n.adminPaginationNext,
          onPrevious: () {
            setState(() => _contentPage -= 1);
            _loadAll();
          },
          onNext: () {
            setState(() => _contentPage += 1);
            _loadAll();
          },
        ),
      ]);
    });
  }

  Widget _buildQuizzesTab(BuildContext context, AppLocalizations l10n, admin) {
    final canCreate = admin?.hasPermission('admin.content.create') ?? false;
    final canEdit = admin?.hasPermission('admin.content.edit') ?? false;
    final canDelete = admin?.hasPermission('admin.content.delete') ?? false;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 720;
      final dropdownWidth = compact ? constraints.maxWidth : 200.0;
      final categoryWidth = compact ? constraints.maxWidth : 220.0;
      return Column(children: [
        AdminFilterBar(children: [
          SizedBox(
            width: dropdownWidth,
            child: DropdownButtonFormFieldCompat<String>(
              initialValue: _quizStatus,
              decoration: InputDecoration(labelText: l10n.adminCmsStatusLabel),
              items: [
                DropdownMenuItem(
                    value: '', child: Text(l10n.adminCmsStatusAll)),
                ..._quizStatusOptions(l10n).map((item) => DropdownMenuItem(
                    value: item.value, child: Text(item.label))),
              ],
              onChanged: (value) {
                setState(() {
                  _quizStatus = value ?? '';
                  _quizPage = 1;
                });
                _loadAll();
              },
            ),
          ),
          SizedBox(
            width: categoryWidth,
            child: DropdownButtonFormFieldCompat<int?>(
              initialValue: _quizCategoryId,
              decoration:
                  InputDecoration(labelText: l10n.adminCmsCategoryLabel),
              items: [
                DropdownMenuItem<int?>(
                    value: null, child: Text(l10n.adminCmsAllCategories)),
                ..._categoriesForSelectedAxis.map((item) =>
                    DropdownMenuItem<int?>(
                        value: item.id, child: Text(item.titleEn))),
              ],
              onChanged: (value) {
                setState(() {
                  _quizCategoryId = value;
                  _quizPage = 1;
                });
                _loadAll();
              },
            ),
          ),
          FilledButton.icon(
              onPressed: canCreate ? () => _saveQuiz() : null,
              icon: const Icon(Icons.add),
              label: Text(l10n.adminCmsAddQuiz)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _quizzes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final quiz = _quizzes[index];
              return Card(
                child: ListTile(
                  title: Text(quiz.titleEn),
                  subtitle: Text(
                      '${quiz.questionCount} ${l10n.adminCmsQuestionsLabel} * ${quiz.category?.titleEn ?? l10n.notAvailable}'),
                  trailing: Wrap(spacing: 8, children: [
                    _CmsStatusChip(
                        label: _statusLabel(quiz.status, l10n),
                        status: quiz.status),
                    IconButton(
                        onPressed: () => _previewQuiz(quiz),
                        icon: const Icon(Icons.visibility_outlined)),
                    IconButton(
                        onPressed: canEdit ? () => _saveQuiz(quiz: quiz) : null,
                        icon: const Icon(Icons.edit_outlined)),
                    IconButton(
                        onPressed: canDelete ? () => _deleteQuiz(quiz) : null,
                        icon: const Icon(Icons.delete_outline)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AdminPaginationBar(
          summary: l10n.adminPaginationSummary(
              (_quizPagination['page'] as int?) ?? _quizPage,
              (_quizPagination['total_pages'] as int?) ?? 1,
              (_quizPagination['total'] as int?) ?? _quizzes.length),
          hasPrevious: (_quizPagination['has_previous'] as bool?) ?? false,
          hasNext: (_quizPagination['has_next'] as bool?) ?? false,
          previousLabel: l10n.adminPaginationPrevious,
          nextLabel: l10n.adminPaginationNext,
          onPrevious: () {
            setState(() => _quizPage -= 1);
            _loadAll();
          },
          onNext: () {
            setState(() => _quizPage += 1);
            _loadAll();
          },
        ),
      ]);
    });
  }

  Widget _buildAxisWorkspace(
    BuildContext context,
    AppLocalizations l10n,
    dynamic admin,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final axis = _selectedAxisSummary;
    final canCreate = admin?.hasPermission('admin.content.create') ?? false;
    final quickTypeItems = <({String type, IconData icon})>[
      (type: 'lesson', icon: Icons.menu_book_outlined),
      (type: 'story', icon: Icons.auto_stories_outlined),
      (type: 'video', icon: Icons.play_circle_outline_rounded),
      (type: 'activity', icon: Icons.extension_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _axes
              .map(
                (axisItem) => _AxisSummaryCard(
                  axis: axisItem,
                  selected: axisItem.key == _selectedAxisKey,
                  onTap: () => _selectAxis(axisItem),
                ),
              )
              .toList(),
        ),
        if (axis != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          axis.titleEn,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (axis.titleAr.trim().isNotEmpty)
                          Text(
                            axis.titleAr,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: canCreate ? () => _saveCategory() : null,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: Text(l10n.adminCmsAddCategory),
                    ),
                    FilledButton.icon(
                      onPressed: canCreate ? () => _saveContent() : null,
                      icon: const Icon(Icons.note_add_outlined),
                      label: Text(l10n.adminCmsAddContent),
                    ),
                    FilledButton.icon(
                      onPressed: canCreate ? () => _saveQuiz() : null,
                      icon: const Icon(Icons.quiz_outlined),
                      label: Text(l10n.adminCmsAddQuiz),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _AxisMetricCard(
                      icon: Icons.folder_copy_outlined,
                      label: l10n.adminCmsCategoriesTab,
                      value: axis.categoryCount,
                    ),
                    _AxisMetricCard(
                      icon: Icons.library_books_outlined,
                      label: l10n.adminCmsContentsTab,
                      value: axis.contentCount,
                    ),
                    _AxisMetricCard(
                      icon: Icons.quiz_outlined,
                      label: l10n.adminCmsQuizzesTab,
                      value: axis.quizCount,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: quickTypeItems
                      .map(
                        (entry) => OutlinedButton.icon(
                          onPressed: canCreate
                              ? () => _createContentForType(entry.type)
                              : null,
                          icon: Icon(entry.icon, size: 18),
                          label: Text(_contentTypeLabel(entry.type, l10n)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _AxisQuickFilterChip(
                      label: l10n.adminCmsContentsTab,
                      selected: _tabs.index == 1 && _contentType.isEmpty,
                      onTap: () {
                        _openTab(1);
                        setState(() {
                          _contentType = '';
                          _contentPage = 1;
                        });
                        _loadAll();
                      },
                    ),
                    ...quickTypeItems.map(
                      (entry) => _AxisQuickFilterChip(
                        label: _contentTypeLabel(entry.type, l10n),
                        selected:
                            _tabs.index == 1 && _contentType == entry.type,
                        onTap: () => _filterByContentType(entry.type),
                      ),
                    ),
                    _AxisQuickFilterChip(
                      label: l10n.adminCmsQuizzesTab,
                      selected: _tabs.index == 2,
                      onTap: () => _openTab(2),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusOption {
  const _StatusOption(this.value, this.label);
  final String value;
  final String label;
}

class _AdminVideoPreviewCard extends StatelessWidget {
  const _AdminVideoPreviewCard({
    required this.videoUrl,
  });

  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    return CloudinaryVideoPlayerView(
      videoUrl: videoUrl,
    );
  }
}

class _CmsStatusChip extends StatelessWidget {
  const _CmsStatusChip({required this.label, required this.status});
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (status) {
      'published' => scheme.primaryContainer,
      'ready' => scheme.tertiaryContainer,
      'review' => scheme.tertiaryContainer,
      'archived' => scheme.surfaceContainerHighest,
      _ => scheme.secondaryContainer,
    };
    final foreground = switch (status) {
      'published' => scheme.primary,
      'ready' => scheme.tertiary,
      'review' => scheme.tertiary,
      'archived' => scheme.onSurfaceVariant,
      _ => scheme.secondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: foreground, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _AxisSummaryCard extends StatelessWidget {
  const _AxisSummaryCard({
    required this.axis,
    required this.selected,
    required this.onTap,
  });

  final AdminCmsAxisSummary axis;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              axis.titleEn,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (axis.titleAr.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                axis.titleAr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${axis.categoryCount} / ${axis.contentCount} / ${axis.quizCount}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisMetricCard extends StatelessWidget {
  const _AxisMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisQuickFilterChip extends StatelessWidget {
  const _AxisQuickFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? scheme.primary : scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
