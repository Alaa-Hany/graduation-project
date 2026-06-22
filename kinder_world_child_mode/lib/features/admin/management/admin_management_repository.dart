import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/models/admin_analytics_overview.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/models/admin_audit_log.dart';
import 'package:kinder_world/core/models/admin_child_record.dart';
import 'package:kinder_world/core/models/admin_cms_models.dart';
import 'package:kinder_world/core/models/admin_management_activity.dart';
import 'package:kinder_world/core/models/admin_parent_user.dart';
import 'package:kinder_world/core/models/admin_rbac_models.dart';
import 'package:kinder_world/core/models/admin_support_ticket.dart';
import 'package:kinder_world/core/models/admin_subscription_models.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';

class AdminPagedResponse<T> {
  const AdminPagedResponse({
    required this.items,
    required this.pagination,
  });

  final List<T> items;
  final Map<String, dynamic> pagination;
}

class AdminCmsCatalogResponse {
  const AdminCmsCatalogResponse({
    required this.categories,
    required this.axes,
  });

  final List<AdminCmsCategory> categories;
  final List<AdminCmsAxisSummary> axes;
}

class AdminYouTubeVideo {
  const AdminYouTubeVideo({
    required this.videoId,
    required this.title,
    required this.description,
    this.thumbnailUrl,
    this.publishedAt,
    required this.url,
  });

  final String videoId;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final String? publishedAt;
  final String url;

  factory AdminYouTubeVideo.fromJson(Map<String, dynamic> json) {
    return AdminYouTubeVideo(
      videoId: json['video_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString(),
      publishedAt: json['published_at']?.toString(),
      url: json['url']?.toString() ?? '',
    );
  }
}

class AdminYouTubeChannelPreview {
  const AdminYouTubeChannelPreview({
    required this.items,
    this.nextPageToken,
  });

  final List<AdminYouTubeVideo> items;
  final String? nextPageToken;
}

class AdminManagementRepository {
  AdminManagementRepository({
    required NetworkService network,
    required SecureStorage storage,
  })  : _network = network,
        _storage = storage;

  final NetworkService _network;
  final SecureStorage _storage;

  Future<Options> _confirmedAdminOptions(String action) async {
    final options = await _adminOptions();
    final headers = <String, dynamic>{
      ...?options.headers,
      'X-Admin-Confirm': 'CONFIRM',
      'X-Admin-Confirm-Action': action,
    };
    return options.copyWith(headers: headers);
  }

  Future<Options> _adminOptions() async {
    final token = await _storage.getAdminToken();
    return Options(headers: {
      'Authorization': token == null ? null : 'Bearer $token',
    });
  }

  Future<String?> _refreshAdminToken() async {
    final refreshToken = await _storage.getAdminRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    final response = await _network.post<Map<String, dynamic>>(
      '/admin/auth/refresh',
      data: {'refresh_token': refreshToken},
      options: Options(headers: {'Authorization': null}),
    );
    final body = Map<String, dynamic>.from(response.data ?? const {});
    final accessToken = body['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    await _storage.saveAdminToken(accessToken);
    return accessToken;
  }

  Future<Response<dynamic>> _sendWithFreshAdminToken(
    Future<Response<dynamic>> Function(Options options) send,
  ) async {
    try {
      return await send(await _adminOptions());
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        rethrow;
      }
      final refreshedToken = await _refreshAdminToken();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        await _storage.clearAdminSession();
        rethrow;
      }
      return send(await _adminOptions());
    }
  }

  Map<String, dynamic> _body(Response<dynamic> response) {
    return _jsonMap(response.data);
  }

  Map<String, dynamic> _item(Response<dynamic> response) {
    return _jsonMap(_body(response)['item']);
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> body) {
    return _jsonList(body['items']);
  }

  Future<AdminPagedResponse<AdminParentUser>> fetchUsers({
    String search = '',
    String status = 'all',
    int page = 1,
  }) async {
    final response = await _network.get(
      '/admin/users',
      queryParameters: {
        'search': search,
        'status': status,
        'page': page,
      },
      options: await _adminOptions(),
    );
    final body = _body(response);
    final items = _items(body).map(AdminParentUser.fromJson).toList();
    return AdminPagedResponse(
      items: items,
      pagination: _jsonMap(body['pagination']),
    );
  }

  Future<AdminParentUser> fetchUserDetail(int userId) async {
    final response = await _network.get(
      '/admin/users/$userId',
      options: await _adminOptions(),
    );
    return AdminParentUser.fromJson(_item(response));
  }

  Future<AdminUserActivityDetails> fetchUserActivity(int userId) async {
    final response = await _network.get(
      '/admin/users/$userId/activity',
      options: await _adminOptions(),
    );
    return AdminUserActivityDetails.fromJson(_body(response));
  }

  Future<AdminParentUser> updateUser(
    int userId, {
    required String name,
    required String email,
    required String plan,
  }) async {
    final response = await _network.patch(
      '/admin/users/$userId',
      data: {
        'name': name,
        'email': email,
        'plan': plan,
      },
      options: await _confirmedAdminOptions('user.override_plan'),
    );
    return AdminParentUser.fromJson(_item(response));
  }

  Future<AdminParentUser> createUser({
    required String name,
    required String email,
    required String password,
    required String plan,
  }) async {
    final response = await _network.post(
      '/admin/users',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'plan': plan,
      },
      options: await _adminOptions(),
    );
    return AdminParentUser.fromJson(_item(response));
  }

  Future<AdminParentUser> setUserEnabled(int userId, bool enabled) async {
    final response = await _network.post(
      '/admin/users/$userId/${enabled ? 'enable' : 'disable'}',
      options: await _confirmedAdminOptions(
        enabled ? 'user.enable' : 'user.disable',
      ),
    );
    return AdminParentUser.fromJson(_item(response));
  }

  Future<String> resetUserPassword(
    int userId, {
    String? newPassword,
  }) async {
    final response = await _network.post(
      '/admin/users/$userId/reset-password',
      data: {
        if (newPassword != null && newPassword.isNotEmpty)
          'new_password': newPassword,
      },
      options: await _confirmedAdminOptions('user.reset_password'),
    );
    return _body(response)['temporary_password']?.toString() ?? '';
  }

  Future<void> deleteUser(int userId) async {
    await _network.delete(
      '/admin/users/$userId',
      options: await _confirmedAdminOptions('user.delete'),
    );
  }

  Future<AdminPagedResponse<AdminChildRecord>> fetchChildren({
    String parentId = '',
    String age = '',
    bool? active,
    int page = 1,
  }) async {
    final query = <String, dynamic>{'page': page};
    if (parentId.isNotEmpty) query['parent_id'] = int.tryParse(parentId);
    if (age.isNotEmpty) query['age'] = int.tryParse(age);
    if (active != null) query['active'] = active;

    final response = await _network.get(
      '/admin/children',
      queryParameters: query,
      options: await _adminOptions(),
    );
    final body = _body(response);
    final items = _items(body).map(AdminChildRecord.fromJson).toList();
    return AdminPagedResponse(
      items: items,
      pagination: _jsonMap(body['pagination']),
    );
  }

  Future<AdminChildRecord> fetchChildDetail(int childId) async {
    final response = await _network.get(
      '/admin/children/$childId',
      options: await _adminOptions(),
    );
    return AdminChildRecord.fromJson(_item(response));
  }

  Future<AdminChildProgressDetails> fetchChildProgress(int childId) async {
    final response = await _network.get(
      '/admin/children/$childId/progress',
      options: await _adminOptions(),
    );
    return AdminChildProgressDetails.fromJson(_body(response));
  }

  Future<AdminChildActivityLog> fetchChildActivityLog(int childId) async {
    final response = await _network.get(
      '/admin/children/$childId/activity-log',
      options: await _adminOptions(),
    );
    return AdminChildActivityLog.fromJson(_body(response));
  }

  Future<AdminChildAiBuddySummary> fetchChildAiBuddySummary(int childId) async {
    final response = await _network.get(
      '/admin/children/$childId/ai-buddy-summary',
      options: await _adminOptions(),
    );
    return AdminChildAiBuddySummary.fromJson(_item(response));
  }

  Future<AdminChildRecord> updateChild(
    int childId, {
    required String name,
    required String age,
    required String avatar,
  }) async {
    final response = await _network.patch(
      '/admin/children/$childId',
      data: {
        'name': name,
        'age': int.tryParse(age),
        'avatar': avatar.isEmpty ? null : avatar,
      },
      options: await _adminOptions(),
    );
    return AdminChildRecord.fromJson(_item(response));
  }

  Future<AdminChildRecord> deactivateChild(int childId) async {
    final response = await _network.post(
      '/admin/children/$childId/deactivate',
      options: await _confirmedAdminOptions('child.deactivate'),
    );
    return AdminChildRecord.fromJson(_item(response));
  }

  Future<void> deleteChild(int childId) async {
    await _network.delete(
      '/admin/children/$childId',
      options: await _confirmedAdminOptions('child.delete'),
    );
  }

  Future<AdminPagedResponse<AdminAuditLog>> fetchAuditLogs({
    String adminId = '',
    String action = '',
    String dateFrom = '',
    String dateTo = '',
    int page = 1,
  }) async {
    final query = <String, dynamic>{'page': page};
    if (adminId.isNotEmpty) query['admin_id'] = int.tryParse(adminId);
    if (action.isNotEmpty) query['action'] = action;
    if (dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo.isNotEmpty) query['date_to'] = dateTo;

    final response = await _network.get(
      '/admin/audit-logs',
      queryParameters: query,
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    final items = (body['items'] as List<dynamic>? ?? const [])
        .map((item) =>
            AdminAuditLog.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return AdminPagedResponse(
      items: items,
      pagination:
          Map<String, dynamic>.from(body['pagination'] as Map? ?? const {}),
    );
  }

  Future<AdminPagedResponse<AdminSupportTicket>> fetchSupportTickets({
    String status = '',
    String category = '',
    int page = 1,
  }) async {
    final response = await _network.get(
      '/admin/support/tickets',
      queryParameters: {
        'status': status,
        'category': category,
        'page': page,
      },
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    final items = (body['items'] as List<dynamic>? ?? const [])
        .map((item) =>
            AdminSupportTicket.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return AdminPagedResponse(
      items: items,
      pagination:
          Map<String, dynamic>.from(body['pagination'] as Map? ?? const {}),
    );
  }

  Future<AdminSupportTicket> fetchSupportTicketDetail(int ticketId) async {
    final response = await _network.get(
      '/admin/support/tickets/$ticketId',
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminSupportTicket.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminSupportTicket> replySupportTicket(
      int ticketId, String message) async {
    final response = await _network.post(
      '/admin/support/tickets/$ticketId/reply',
      data: {'message': message},
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminSupportTicket.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminSupportTicket> assignSupportTicket(int ticketId,
      {int? adminUserId}) async {
    final response = await _network.post(
      '/admin/support/tickets/$ticketId/assign',
      data: {'admin_user_id': adminUserId},
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminSupportTicket.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminSupportTicket> closeSupportTicket(int ticketId) async {
    final response = await _network.post(
      '/admin/support/tickets/$ticketId/close',
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminSupportTicket.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminSupportTicket> resolveSupportTicket(int ticketId) async {
    final response = await _network.post(
      '/admin/support/tickets/$ticketId/resolve',
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminSupportTicket.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminAnalyticsOverview> fetchAnalyticsOverview() async {
    final response = await _network.get(
      '/admin/analytics/overview',
      options: await _adminOptions(),
    );
    return AdminAnalyticsOverview.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<AdminAnalyticsUsage> fetchAnalyticsUsage(String range) async {
    final response = await _network.get(
      '/admin/analytics/usage',
      queryParameters: {'range': range},
      options: await _adminOptions(),
    );
    return AdminAnalyticsUsage.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<AdminCmsCatalogResponse> fetchCmsCatalog({String axisKey = ''}) async {
    final response = await _network.get(
      '/admin/categories',
      queryParameters: {
        if (axisKey.isNotEmpty) 'axis_key': axisKey,
      },
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    final categories = (body['items'] as List<dynamic>? ?? const [])
        .map((item) =>
            AdminCmsCategory.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final axes = (body['axes'] as List<dynamic>? ?? const [])
        .map((item) => AdminCmsAxisSummary.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList();
    return AdminCmsCatalogResponse(categories: categories, axes: axes);
  }

  Future<List<AdminCmsCategory>> fetchCategories({String axisKey = ''}) async {
    final response = await fetchCmsCatalog(axisKey: axisKey);
    return response.categories;
  }

  Future<AdminCmsCategory> createCategory({
    required String axisKey,
    required String slug,
    required String titleEn,
    required String titleAr,
    String? descriptionEn,
    String? descriptionAr,
  }) async {
    final response = await _network.post(
      '/admin/categories',
      data: {
        'axis_key': axisKey,
        'slug': slug,
        'title_en': titleEn,
        'title_ar': titleAr,
        'description_en': descriptionEn,
        'description_ar': descriptionAr,
      },
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminCmsCategory.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminCmsCategory> updateCategory(
    int categoryId, {
    required String axisKey,
    required String slug,
    required String titleEn,
    required String titleAr,
    String? descriptionEn,
    String? descriptionAr,
  }) async {
    final response = await _network.patch(
      '/admin/categories/$categoryId',
      data: {
        'axis_key': axisKey,
        'slug': slug,
        'title_en': titleEn,
        'title_ar': titleAr,
        'description_en': descriptionEn,
        'description_ar': descriptionAr,
      },
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminCmsCategory.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<void> deleteCategory(int categoryId) async {
    await _network.delete(
      '/admin/categories/$categoryId',
      options: await _adminOptions(),
    );
  }

  Future<AdminPagedResponse<AdminCmsContent>> fetchContents({
    String search = '',
    String status = '',
    int? categoryId,
    String axisKey = '',
    String contentType = '',
    int page = 1,
  }) async {
    final query = <String, dynamic>{'page': page};
    if (search.isNotEmpty) query['search'] = search;
    if (status.isNotEmpty) query['status'] = status;
    if (categoryId != null) query['category_id'] = categoryId;
    if (axisKey.isNotEmpty) query['axis_key'] = axisKey;
    if (contentType.isNotEmpty) query['content_type'] = contentType;

    final response = await _network.get(
      '/admin/contents',
      queryParameters: query,
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    final items = (body['items'] as List<dynamic>? ?? const [])
        .map((item) =>
            AdminCmsContent.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return AdminPagedResponse(
      items: items,
      pagination:
          Map<String, dynamic>.from(body['pagination'] as Map? ?? const {}),
    );
  }

  Future<AdminCmsContent> fetchContentDetail(int contentId) async {
    final response = await _network.get(
      '/admin/contents/$contentId',
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminCmsContent.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminUploadedVideoAsset> uploadContentVideo({
    required List<int> bytes,
    required String filename,
    String? axisKey,
    String? categorySlug,
    String? contentSlug,
    ProgressCallback? onSendProgress,
  }) async {
    Future<Response<dynamic>> sendUpload(
        {bool useRefreshedToken = false}) async {
      final options = useRefreshedToken
          ? Options(headers: {
              'Authorization':
                  'Bearer ${(await _storage.getAdminToken()) ?? ''}',
            })
          : await _adminOptions();
      return _network.post(
        '/admin/media/videos/upload',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename),
          if (axisKey != null && axisKey.isNotEmpty) 'axis_key': axisKey,
          if (categorySlug != null && categorySlug.isNotEmpty)
            'category_slug': categorySlug,
          if (contentSlug != null && contentSlug.isNotEmpty)
            'content_slug': contentSlug,
        }),
        options: options.copyWith(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 15),
          receiveTimeout: const Duration(minutes: 15),
        ),
        onSendProgress: onSendProgress,
      );
    }

    Response<dynamic> response;
    try {
      response = await sendUpload();
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      final refreshedToken = await _refreshAdminToken();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        rethrow;
      }
      response = await sendUpload(useRefreshedToken: true);
    }

    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminUploadedVideoAsset.fromJson(
      Map<String, dynamic>.from(body['item'] as Map),
    );
  }

  Future<AdminYouTubeChannelPreview> fetchYouTubeChannelVideos({
    required String channel,
    String pageToken = '',
  }) async {
    final response = await _sendWithFreshAdminToken(
      (options) => _network.get(
        '/admin/content/youtube/videos',
        queryParameters: {
          'channel': channel,
          if (pageToken.isNotEmpty) 'page_token': pageToken,
        },
        options: options,
      ),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    final items = (body['items'] as List<dynamic>? ?? const [])
        .map((item) =>
            AdminYouTubeVideo.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return AdminYouTubeChannelPreview(
      items: items,
      nextPageToken: body['next_page_token'] as String?,
    );
  }

  Future<List<AdminCmsContent>> importYouTubeVideos(
    List<Map<String, dynamic>> items,
  ) async {
    final response = await _sendWithFreshAdminToken(
      (options) => _network.post(
        '/admin/content/youtube/import',
        data: {'items': items},
        options: options,
      ),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return (body['items'] as List<dynamic>? ?? const [])
        .map((item) =>
            AdminCmsContent.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<AdminCmsContent> createContent(Map<String, dynamic> payload) async {
    final response = await _sendWithFreshAdminToken(
      (options) => _network.post(
        '/admin/contents',
        data: payload,
        options: options,
      ),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminCmsContent.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminCmsContent> updateContent(
      int contentId, Map<String, dynamic> payload) async {
    final response = await _sendWithFreshAdminToken(
      (options) => _network.patch(
        '/admin/contents/$contentId',
        data: payload,
        options: options,
      ),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminCmsContent.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminCmsContent> publishContent(int contentId) async {
    final response = await _sendWithFreshAdminToken(
      (options) => _network.post(
        '/admin/contents/$contentId/publish',
        options: options,
      ),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminCmsContent.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminCmsContent> unpublishContent(int contentId) async {
    final response = await _sendWithFreshAdminToken(
      (options) => _network.post(
        '/admin/contents/$contentId/unpublish',
        options: options,
      ),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminCmsContent.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<void> deleteContent(int contentId) async {
    await _sendWithFreshAdminToken(
      (options) => _network.delete(
        '/admin/contents/$contentId',
        options: options,
      ),
    );
  }

  Future<AdminPagedResponse<AdminCmsQuiz>> fetchQuizzes({
    String status = '',
    int? categoryId,
    String axisKey = '',
    int? contentId,
    int page = 1,
  }) async {
    final query = <String, dynamic>{'page': page};
    if (status.isNotEmpty) query['status'] = status;
    if (categoryId != null) query['category_id'] = categoryId;
    if (axisKey.isNotEmpty) query['axis_key'] = axisKey;
    if (contentId != null) query['content_id'] = contentId;

    final response = await _network.get(
      '/admin/quizzes',
      queryParameters: query,
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    final items = (body['items'] as List<dynamic>? ?? const [])
        .map((item) =>
            AdminCmsQuiz.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return AdminPagedResponse(
      items: items,
      pagination:
          Map<String, dynamic>.from(body['pagination'] as Map? ?? const {}),
    );
  }

  Future<AdminCmsQuiz> createQuiz(Map<String, dynamic> payload) async {
    final response = await _network.post(
      '/admin/quizzes',
      data: payload,
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminCmsQuiz.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminCmsQuiz> updateQuiz(
      int quizId, Map<String, dynamic> payload) async {
    final response = await _network.patch(
      '/admin/quizzes/$quizId',
      data: payload,
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminCmsQuiz.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<void> deleteQuiz(int quizId) async {
    await _network.delete(
      '/admin/quizzes/$quizId',
      options: await _adminOptions(),
    );
  }

  Future<AdminPagedResponse<AdminSubscriptionRecord>> fetchSubscriptions({
    String search = '',
    String status = '',
    String plan = '',
    int page = 1,
  }) async {
    final response = await _network.get(
      '/admin/subscriptions',
      queryParameters: {
        'search': search,
        'status': status,
        'plan': plan,
        'page': page,
      },
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    final items = (body['items'] as List<dynamic>? ?? const [])
        .map((item) => AdminSubscriptionRecord.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList();
    return AdminPagedResponse(
      items: items,
      pagination:
          Map<String, dynamic>.from(body['pagination'] as Map? ?? const {}),
    );
  }

  Future<AdminSubscriptionRecord> fetchSubscriptionDetail(int id) async {
    final response = await _network.get(
      '/admin/subscriptions/$id',
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminSubscriptionRecord.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminSubscriptionRecord> overrideSubscriptionPlan(
      int id, String plan) async {
    final response = await _network.post(
      '/admin/subscriptions/$id/override-plan',
      data: {'plan': plan},
      options: await _confirmedAdminOptions('subscription.override_plan'),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminSubscriptionRecord.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminSubscriptionRecord> cancelSubscription(int id) async {
    final response = await _network.post(
      '/admin/subscriptions/$id/cancel',
      options: await _confirmedAdminOptions('subscription.cancel'),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminSubscriptionRecord.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<String> refundSubscription(int id) async {
    try {
      await _network.post(
        '/admin/subscriptions/$id/refund',
        options: await _confirmedAdminOptions('subscription.refund'),
      );
      return 'ok';
    } on DioException catch (e) {
      final detail = e.response?.data;
      if (detail is Map && detail['detail'] is String) {
        return detail['detail'] as String;
      }
      return e.message ?? 'Refund failed';
    }
  }

  Future<AdminSystemSettingsPayload> fetchAdminSettings() async {
    final response = await _network.get(
      '/admin/settings',
      options: await _adminOptions(),
    );
    return AdminSystemSettingsPayload.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AdminSystemSettingsPayload> updateAdminSettings(
      Map<String, dynamic> payload) async {
    final response = await _network.patch(
      '/admin/settings',
      data: payload,
      options: await _confirmedAdminOptions('settings.update'),
    );
    return AdminSystemSettingsPayload.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AdminPagedResponse<AdminUser>> fetchAdminUsers({
    String search = '',
    String status = 'all',
    int page = 1,
  }) async {
    final response = await _network.get(
      '/admin/admin-users',
      queryParameters: {
        'search': search,
        'status': status,
        'page': page,
      },
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    final items = (body['items'] as List<dynamic>? ?? const [])
        .map((item) =>
            AdminUser.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return AdminPagedResponse(
      items: items,
      pagination:
          Map<String, dynamic>.from(body['pagination'] as Map? ?? const {}),
    );
  }

  Future<AdminUser> fetchAdminUserDetail(int adminUserId) async {
    final response = await _network.get(
      '/admin/admin-users/$adminUserId',
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminUser.fromJson(Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminUser> createAdminUser({
    required String email,
    required String password,
    required String name,
    List<int> roleIds = const [],
  }) async {
    final response = await _network.post(
      '/admin/admin-users',
      data: {
        'email': email,
        'password': password,
        'name': name,
        'role_ids': roleIds,
      },
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminUser.fromJson(Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminUser> updateAdminUser(
    int adminUserId, {
    String? email,
    String? name,
    String? password,
  }) async {
    final response = await _network.patch(
      '/admin/admin-users/$adminUserId',
      data: {
        if (email != null) 'email': email,
        if (name != null) 'name': name,
        if (password != null && password.isNotEmpty) 'password': password,
      },
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminUser.fromJson(Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminUser> setAdminUserEnabled(int adminUserId, bool enabled) async {
    final response = await _network.post(
      '/admin/admin-users/$adminUserId/${enabled ? 'enable' : 'disable'}',
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminUser.fromJson(Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminUser> assignAdminRole(int adminUserId, int roleId) async {
    final response = await _network.post(
      '/admin/admin-users/$adminUserId/assign-role',
      data: {'role_id': roleId},
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminUser.fromJson(Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminUser> removeAdminRole(int adminUserId, int roleId) async {
    final response = await _network.post(
      '/admin/admin-users/$adminUserId/remove-role',
      data: {'role_id': roleId},
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminUser.fromJson(Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<List<AdminRoleRecord>> fetchRoles() async {
    final response = await _network.get(
      '/admin/roles',
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return (body['items'] as List<dynamic>? ?? const [])
        .map((item) =>
            AdminRoleRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<AdminRoleRecord> fetchRoleDetail(int roleId) async {
    final response = await _network.get(
      '/admin/roles/$roleId',
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminRoleRecord.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminRoleRecord> createRole({
    required String name,
    required String description,
  }) async {
    final response = await _network.post(
      '/admin/roles',
      data: {
        'name': name,
        'description': description,
      },
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminRoleRecord.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminRoleRecord> updateRole(
    int roleId, {
    String? name,
    String? description,
  }) async {
    final response = await _network.patch(
      '/admin/roles/$roleId',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      },
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminRoleRecord.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }

  Future<AdminPermissionsPayload> fetchPermissions() async {
    final response = await _network.get(
      '/admin/permissions',
      options: await _adminOptions(),
    );
    return AdminPermissionsPayload.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AdminRoleRecord> updateRolePermissions(
      int roleId, List<int> permissionIds) async {
    final response = await _network.patch(
      '/admin/roles/$roleId/permissions',
      data: {'permission_ids': permissionIds},
      options: await _adminOptions(),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return AdminRoleRecord.fromJson(
        Map<String, dynamic>.from(body['item'] as Map));
  }
}

final adminManagementRepositoryProvider =
    Provider<AdminManagementRepository>((ref) {
  final network = ref.watch(networkServiceProvider);
  final storage = ref.watch(secureStorageProvider);
  return AdminManagementRepository(network: network, storage: storage);
});

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _jsonList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
