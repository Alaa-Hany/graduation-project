import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_cms_models.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';

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

  List<AdminCmsCategory> _categories = const [];
  List<AdminCmsContent> _contents = const [];
  List<AdminCmsQuiz> _quizzes = const [];
  Map<String, dynamic> _contentPagination = const {};
  Map<String, dynamic> _quizPagination = const {};

  String _contentSearch = '';
  String _contentStatus = '';
  int? _contentCategoryId;
  int _contentPage = 1;

  String _quizStatus = '';
  int? _quizCategoryId;
  int _quizPage = 1;

  List<DropdownMenuItem<String>> _contentTypeItems(AppLocalizations? l10n) => [
        DropdownMenuItem(
          value: 'lesson',
          child: Text(l10n?.adminCmsTypeLesson ?? 'Lesson'),
        ),
        DropdownMenuItem(
          value: 'story',
          child: Text(l10n?.adminCmsTypeStory ?? 'Story'),
        ),
        DropdownMenuItem(
          value: 'video',
          child: Text(l10n?.adminCmsTypeVideo ?? 'Video'),
        ),
        DropdownMenuItem(
          value: 'activity',
          child: Text(l10n?.adminCmsTypeActivity ?? 'Activity'),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
      final categories = await repo.fetchCategories();
      final contents = await repo.fetchContents(
        search: _contentSearch,
        status: _contentStatus,
        categoryId: _contentCategoryId,
        page: _contentPage,
      );
      final quizzes = await repo.fetchQuizzes(
        status: _quizStatus,
        categoryId: _quizCategoryId,
        page: _quizPage,
      );
      if (!mounted) return;
      setState(() {
        _categories = categories;
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

  List<_StatusOption> _statusOptions(AppLocalizations? l10n) => [
        _StatusOption('draft', l10n?.adminCmsStatusDraft ?? 'Draft'),
        _StatusOption('review', l10n?.adminCmsStatusReview ?? 'Review'),
        _StatusOption(
            'published', l10n?.adminCmsStatusPublished ?? 'Published'),
      ];

  String _statusLabel(String status, AppLocalizations? l10n) {
    for (final option in _statusOptions(l10n)) {
      if (option.value == status) return option.label;
    }
    return status;
  }

  Future<void> _saveCategory({AdminCmsCategory? category}) async {
    final l10n = AppLocalizations.of(context);
    final slug = TextEditingController(text: category?.slug ?? '');
    final titleEn = TextEditingController(text: category?.titleEn ?? '');
    final titleAr = TextEditingController(text: category?.titleAr ?? '');
    final descEn = TextEditingController(text: category?.descriptionEn ?? '');
    final descAr = TextEditingController(text: category?.descriptionAr ?? '');
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(category == null
                ? (l10n?.adminCmsCategoryCreateTitle ?? 'Create category')
                : (l10n?.adminCmsCategoryEditTitle ?? 'Edit category')),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: slug,
                      decoration: InputDecoration(
                          labelText: l10n?.adminCmsCategorySlug ?? 'Slug')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: titleEn,
                      decoration: InputDecoration(
                          labelText:
                              l10n?.adminCmsTitleEnLabel ?? 'English title')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: titleAr,
                      decoration: InputDecoration(
                          labelText:
                              l10n?.adminCmsTitleArLabel ?? 'Arabic title')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: descEn,
                      decoration: InputDecoration(
                          labelText: l10n?.adminCmsDescriptionEnLabel ??
                              'English description')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: descAr,
                      decoration: InputDecoration(
                          labelText: l10n?.adminCmsDescriptionArLabel ??
                              'Arabic description')),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n?.cancel ?? 'Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n?.save ?? 'Save')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final repo = ref.read(adminManagementRepositoryProvider);
    if (category == null) {
      await repo.createCategory(
        slug: slug.text.trim(),
        titleEn: titleEn.text.trim(),
        titleAr: titleAr.text.trim(),
        descriptionEn: descEn.text.trim(),
        descriptionAr: descAr.text.trim(),
      );
    } else {
      await repo.updateCategory(
        category.id,
        slug: slug.text.trim(),
        titleEn: titleEn.text.trim(),
        titleAr: titleAr.text.trim(),
        descriptionEn: descEn.text.trim(),
        descriptionAr: descAr.text.trim(),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n?.adminCmsCategorySaved ?? 'Category saved')),
    );
    await _loadAll();
  }

  Future<void> _deleteCategory(AdminCmsCategory category) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n?.adminCmsDeleteCategoryTitle ?? 'Delete category'),
            content: Text(
                l10n?.adminCmsDeleteCategoryConfirm ?? 'Delete this category?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n?.cancel ?? 'Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n?.delete ?? 'Delete')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref
        .read(adminManagementRepositoryProvider)
        .deleteCategory(category.id);
    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _saveContent({AdminCmsContent? content}) async {
    final l10n = AppLocalizations.of(context);
    final titleEn = TextEditingController(text: content?.titleEn ?? '');
    final titleAr = TextEditingController(text: content?.titleAr ?? '');
    final descEn = TextEditingController(text: content?.descriptionEn ?? '');
    final descAr = TextEditingController(text: content?.descriptionAr ?? '');
    final bodyEn = TextEditingController(text: content?.bodyEn ?? '');
    final bodyAr = TextEditingController(text: content?.bodyAr ?? '');
    final thumb = TextEditingController(text: content?.thumbnailUrl ?? '');
    final age = TextEditingController(text: content?.ageGroup ?? '');
    final metadata = TextEditingController(
      text: const JsonEncoder.withIndent('  ')
          .convert(content?.metadataJson ?? const <String, dynamic>{}),
    );
    int? selectedCategoryId = content?.categoryId;
    String selectedType = content?.contentType ?? 'lesson';
    String selectedStatus = content?.status ?? 'draft';
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              title: Text(content == null
                  ? (l10n?.adminCmsCreateContentTitle ?? 'Create content')
                  : (l10n?.adminCmsEditContentTitle ?? 'Edit content')),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int?>(
                        initialValue: selectedCategoryId,
                        decoration: InputDecoration(
                            labelText:
                                l10n?.adminCmsCategoryLabel ?? 'Category'),
                        items: [
                          DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                  l10n?.adminCmsNoCategory ?? 'No category')),
                          ..._categories.map((category) =>
                              DropdownMenuItem<int?>(
                                  value: category.id,
                                  child: Text(category.titleEn))),
                        ],
                        onChanged: (value) =>
                            setStateDialog(() => selectedCategoryId = value),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextField(
                              controller: titleEn,
                              decoration: InputDecoration(
                                  labelText: l10n?.adminCmsTitleEnLabel ??
                                      'English title')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                              controller: titleAr,
                              decoration: InputDecoration(
                                  labelText: l10n?.adminCmsTitleArLabel ??
                                      'Arabic title')),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedType,
                            decoration: InputDecoration(
                                labelText: l10n?.adminCmsTypeLabel ?? 'Type'),
                            items: _contentTypeItems(l10n),
                            onChanged: (value) => setStateDialog(
                                () => selectedType = value ?? 'lesson'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            decoration: InputDecoration(
                                labelText:
                                    l10n?.adminCmsStatusLabel ?? 'Status'),
                            items: _statusOptions(l10n)
                                .map((item) => DropdownMenuItem(
                                    value: item.value, child: Text(item.label)))
                                .toList(),
                            onChanged: (value) => setStateDialog(
                                () => selectedStatus = value ?? 'draft'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                          controller: descEn,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                              labelText: l10n?.adminCmsDescriptionEnLabel ??
                                  'English description')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: descAr,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                              labelText: l10n?.adminCmsDescriptionArLabel ??
                                  'Arabic description')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: bodyEn,
                          minLines: 4,
                          maxLines: 6,
                          decoration: InputDecoration(
                              labelText:
                                  l10n?.adminCmsBodyEnLabel ?? 'English body')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: bodyAr,
                          minLines: 4,
                          maxLines: 6,
                          decoration: InputDecoration(
                              labelText:
                                  l10n?.adminCmsBodyArLabel ?? 'Arabic body')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: thumb,
                          decoration: InputDecoration(
                              labelText: l10n?.adminCmsThumbnailLabel ??
                                  'Thumbnail URL')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: age,
                          decoration: InputDecoration(
                              labelText:
                                  l10n?.adminCmsAgeGroupLabel ?? 'Age group')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: metadata,
                          minLines: 4,
                          maxLines: 8,
                          decoration: InputDecoration(
                              labelText: l10n?.adminCmsMetadataLabel ??
                                  'Metadata JSON')),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n?.cancel ?? 'Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n?.save ?? 'Save')),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) return;
    final payload = {
      'category_id': selectedCategoryId,
      'content_type': selectedType,
      'status': selectedStatus,
      'title_en': titleEn.text.trim(),
      'title_ar': titleAr.text.trim(),
      'description_en': descEn.text.trim(),
      'description_ar': descAr.text.trim(),
      'body_en': bodyEn.text,
      'body_ar': bodyAr.text,
      'thumbnail_url': thumb.text.trim(),
      'age_group': age.text.trim(),
      'metadata_json': metadata.text.trim().isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(metadata.text.trim()) as Map),
    };
    final repo = ref.read(adminManagementRepositoryProvider);
    if (content == null) {
      await repo.createContent(payload);
    } else {
      await repo.updateContent(content.id, payload);
    }
    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _previewContent(AdminCmsContent content) async {
    final l10n = AppLocalizations.of(context);
    final detail = await ref
        .read(adminManagementRepositoryProvider)
        .fetchContentDetail(content.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.adminCmsPreviewTitle ?? 'Preview'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(detail.titleEn,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(detail.descriptionEn ?? ''),
                const SizedBox(height: 16),
                Text(detail.bodyEn ?? ''),
                const SizedBox(height: 16),
                Text(
                    '${l10n?.adminCmsLinkedQuizzes ?? 'Linked quizzes'}: ${detail.quizCount}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n?.cancel ?? 'Close')),
        ],
      ),
    );
  }

  Future<void> _togglePublish(AdminCmsContent content) async {
    final repo = ref.read(adminManagementRepositoryProvider);
    if (content.status == 'published') {
      await repo.unpublishContent(content.id);
    } else {
      await repo.publishContent(content.id);
    }
    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _deleteContent(AdminCmsContent content) async {
    await ref.read(adminManagementRepositoryProvider).deleteContent(content.id);
    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _saveQuiz({AdminCmsQuiz? quiz}) async {
    final l10n = AppLocalizations.of(context);
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
              title: Text(quiz == null
                  ? (l10n?.adminCmsCreateQuizTitle ?? 'Create quiz')
                  : (l10n?.adminCmsEditQuizTitle ?? 'Edit quiz')),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int?>(
                        initialValue: selectedCategoryId,
                        decoration: InputDecoration(
                            labelText:
                                l10n?.adminCmsCategoryLabel ?? 'Category'),
                        items: [
                          DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                  l10n?.adminCmsNoCategory ?? 'No category')),
                          ..._categories.map((category) =>
                              DropdownMenuItem<int?>(
                                  value: category.id,
                                  child: Text(category.titleEn))),
                        ],
                        onChanged: (value) =>
                            setStateDialog(() => selectedCategoryId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        initialValue: selectedContentId,
                        decoration: InputDecoration(
                            labelText: l10n?.adminCmsLinkedContentLabel ??
                                'Linked content'),
                        items: [
                          DropdownMenuItem<int?>(
                              value: null,
                              child: Text(l10n?.adminCmsNoLinkedContent ??
                                  'No linked content')),
                          ..._contents.map((content) => DropdownMenuItem<int?>(
                              value: content.id, child: Text(content.titleEn))),
                        ],
                        onChanged: (value) =>
                            setStateDialog(() => selectedContentId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: InputDecoration(
                            labelText: l10n?.adminCmsStatusLabel ?? 'Status'),
                        items: _statusOptions(l10n)
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
                              labelText: l10n?.adminCmsTitleEnLabel ??
                                  'English title')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: titleAr,
                          decoration: InputDecoration(
                              labelText: l10n?.adminCmsTitleArLabel ??
                                  'Arabic title')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: descEn,
                          decoration: InputDecoration(
                              labelText: l10n?.adminCmsDescriptionEnLabel ??
                                  'English description')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: descAr,
                          decoration: InputDecoration(
                              labelText: l10n?.adminCmsDescriptionArLabel ??
                                  'Arabic description')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: questions,
                          minLines: 6,
                          maxLines: 12,
                          decoration: InputDecoration(
                              labelText: l10n?.adminCmsQuestionsJsonLabel ??
                                  'Questions JSON')),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n?.cancel ?? 'Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n?.save ?? 'Save')),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) return;
    final payload = {
      'content_id': selectedContentId,
      'category_id': selectedCategoryId,
      'status': selectedStatus,
      'title_en': titleEn.text.trim(),
      'title_ar': titleAr.text.trim(),
      'description_en': descEn.text.trim(),
      'description_ar': descAr.text.trim(),
      'questions_json': List<Map<String, dynamic>>.from(
        (jsonDecode(questions.text.trim()) as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map)),
      ),
    };
    final repo = ref.read(adminManagementRepositoryProvider);
    if (quiz == null) {
      await repo.createQuiz(payload);
    } else {
      await repo.updateQuiz(quiz.id, payload);
    }
    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _deleteQuiz(AdminCmsQuiz quiz) async {
    await ref.read(adminManagementRepositoryProvider).deleteQuiz(quiz.id);
    if (!mounted) return;
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.content.view') ?? false)) {
      return const AdminPermissionPlaceholder();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n?.adminCmsTitle ?? 'Content management',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(l10n?.adminCmsSubtitle ??
              'Manage categories, educational content, and quizzes.'),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: [
              Tab(text: l10n?.adminCmsCategoriesTab ?? 'Categories'),
              Tab(text: l10n?.adminCmsContentsTab ?? 'Contents'),
              Tab(text: l10n?.adminCmsQuizzesTab ?? 'Quizzes'),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16), child: Text(_error!)))
          else
            SizedBox(
              height: 860,
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
  }

  Widget _buildCategoriesTab(
      BuildContext context, AppLocalizations? l10n, admin) {
    final canCreate = admin?.hasPermission('admin.content.create') ?? false;
    final canEdit = admin?.hasPermission('admin.content.edit') ?? false;
    final canDelete = admin?.hasPermission('admin.content.delete') ?? false;
    return Column(
      children: [
        Row(children: [
          FilledButton.icon(
              onPressed: canCreate ? () => _saveCategory() : null,
              icon: const Icon(Icons.add),
              label: Text(l10n?.adminCmsAddCategory ?? 'Add category')),
          const SizedBox(width: 12),
          OutlinedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: Text(l10n?.retry ?? 'Refresh')),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final category = _categories[index];
              return Card(
                child: ListTile(
                  title: Text(category.titleEn),
                  subtitle: Text(
                      '${category.slug}\n${l10n?.adminCmsCategoryUsage ?? 'Content / quizzes'}: ${category.contentCount} / ${category.quizCount}'),
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

  Widget _buildContentsTab(
      BuildContext context, AppLocalizations? l10n, admin) {
    final canCreate = admin?.hasPermission('admin.content.create') ?? false;
    final canEdit = admin?.hasPermission('admin.content.edit') ?? false;
    final canPublish = admin?.hasPermission('admin.content.publish') ?? false;
    final canDelete = admin?.hasPermission('admin.content.delete') ?? false;
    return Column(children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
          width: 240,
          child: TextFormField(
            initialValue: _contentSearch,
            decoration: InputDecoration(
                labelText: l10n?.adminCmsSearchLabel ?? 'Search'),
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
          width: 200,
          child: DropdownButtonFormField<String>(
            initialValue: _contentStatus,
            decoration: InputDecoration(
                labelText: l10n?.adminCmsStatusLabel ?? 'Status'),
            items: [
              DropdownMenuItem(
                  value: '',
                  child: Text(l10n?.adminCmsStatusAll ?? 'All statuses')),
              ..._statusOptions(l10n).map((item) =>
                  DropdownMenuItem(value: item.value, child: Text(item.label))),
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
          width: 220,
          child: DropdownButtonFormField<int?>(
            initialValue: _contentCategoryId,
            decoration: InputDecoration(
                labelText: l10n?.adminCmsCategoryLabel ?? 'Category'),
            items: [
              DropdownMenuItem<int?>(
                  value: null,
                  child: Text(l10n?.adminCmsAllCategories ?? 'All categories')),
              ..._categories.map((item) => DropdownMenuItem<int?>(
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
            label: Text(l10n?.adminCmsAddContent ?? 'Add content')),
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
                      Text(content.descriptionEn ?? '',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 10),
                      Wrap(spacing: 12, children: [
                        Text(
                            '${l10n?.adminCmsCategoryLabel ?? 'Category'}: ${content.category?.titleEn ?? '—'}'),
                        Text(
                            '${l10n?.adminCmsTypeLabel ?? 'Type'}: ${content.contentType}'),
                        Text(
                            '${l10n?.adminCmsLinkedQuizzes ?? 'Linked quizzes'}: ${content.quizCount}'),
                      ]),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton(
                            onPressed: () => _previewContent(content),
                            child:
                                Text(l10n?.adminCmsPreviewAction ?? 'Preview')),
                        OutlinedButton(
                            onPressed: canEdit
                                ? () => _saveContent(content: content)
                                : null,
                            child: Text(l10n?.edit ?? 'Edit')),
                        OutlinedButton(
                            onPressed: canPublish
                                ? () => _togglePublish(content)
                                : null,
                            child: Text(content.status == 'published'
                                ? (l10n?.adminCmsUnpublishAction ?? 'Unpublish')
                                : (l10n?.adminCmsPublishAction ?? 'Publish'))),
                        OutlinedButton(
                            onPressed: canDelete
                                ? () => _deleteContent(content)
                                : null,
                            child: Text(l10n?.delete ?? 'Delete')),
                      ]),
                    ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      _PaginationBar(
        summary: l10n?.adminPaginationSummary(
                (_contentPagination['page'] as int?) ?? _contentPage,
                (_contentPagination['total_pages'] as int?) ?? 1,
                (_contentPagination['total'] as int?) ?? _contents.length) ??
            '',
        hasPrevious: (_contentPagination['has_previous'] as bool?) ?? false,
        hasNext: (_contentPagination['has_next'] as bool?) ?? false,
        previousLabel: l10n?.adminPaginationPrevious ?? 'Previous',
        nextLabel: l10n?.adminPaginationNext ?? 'Next',
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
  }

  Widget _buildQuizzesTab(BuildContext context, AppLocalizations? l10n, admin) {
    final canCreate = admin?.hasPermission('admin.content.create') ?? false;
    final canEdit = admin?.hasPermission('admin.content.edit') ?? false;
    final canDelete = admin?.hasPermission('admin.content.delete') ?? false;
    return Column(children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            initialValue: _quizStatus,
            decoration: InputDecoration(
                labelText: l10n?.adminCmsStatusLabel ?? 'Status'),
            items: [
              DropdownMenuItem(
                  value: '',
                  child: Text(l10n?.adminCmsStatusAll ?? 'All statuses')),
              ..._statusOptions(l10n).map((item) =>
                  DropdownMenuItem(value: item.value, child: Text(item.label))),
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
          width: 220,
          child: DropdownButtonFormField<int?>(
            initialValue: _quizCategoryId,
            decoration: InputDecoration(
                labelText: l10n?.adminCmsCategoryLabel ?? 'Category'),
            items: [
              DropdownMenuItem<int?>(
                  value: null,
                  child: Text(l10n?.adminCmsAllCategories ?? 'All categories')),
              ..._categories.map((item) => DropdownMenuItem<int?>(
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
            label: Text(l10n?.adminCmsAddQuiz ?? 'Add quiz')),
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
                    '${quiz.questionCount} ${l10n?.adminCmsQuestionsLabel ?? 'questions'} • ${quiz.category?.titleEn ?? '—'}'),
                trailing: Wrap(spacing: 8, children: [
                  _CmsStatusChip(
                      label: _statusLabel(quiz.status, l10n),
                      status: quiz.status),
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
      _PaginationBar(
        summary: l10n?.adminPaginationSummary(
                (_quizPagination['page'] as int?) ?? _quizPage,
                (_quizPagination['total_pages'] as int?) ?? 1,
                (_quizPagination['total'] as int?) ?? _quizzes.length) ??
            '',
        hasPrevious: (_quizPagination['has_previous'] as bool?) ?? false,
        hasNext: (_quizPagination['has_next'] as bool?) ?? false,
        previousLabel: l10n?.adminPaginationPrevious ?? 'Previous',
        nextLabel: l10n?.adminPaginationNext ?? 'Next',
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
  }
}

class _StatusOption {
  const _StatusOption(this.value, this.label);
  final String value;
  final String label;
}

class _CmsStatusChip extends StatelessWidget {
  const _CmsStatusChip({required this.label, required this.status});
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = status == 'published'
        ? scheme.primaryContainer
        : status == 'review'
            ? scheme.tertiaryContainer
            : scheme.secondaryContainer;
    final foreground = status == 'published'
        ? scheme.primary
        : status == 'review'
            ? scheme.tertiary
            : scheme.secondary;
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

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.summary,
    required this.hasPrevious,
    required this.hasNext,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final String summary;
  final bool hasPrevious;
  final bool hasNext;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(summary),
        Row(children: [
          OutlinedButton(
              onPressed: hasPrevious ? onPrevious : null,
              child: Text(previousLabel)),
          const SizedBox(width: 8),
          FilledButton(
              onPressed: hasNext ? onNext : null, child: Text(nextLabel)),
        ]),
      ],
    );
  }
}
