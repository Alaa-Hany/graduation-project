class AdminSupportThreadEntry {
  const AdminSupportThreadEntry({
    required this.id,
    required this.message,
    required this.authorType,
    required this.createdAt,
    this.author,
  });

  final String id;
  final String message;
  final String authorType;
  final String? createdAt;
  final Map<String, dynamic>? author;

  factory AdminSupportThreadEntry.fromJson(Map<String, dynamic> json) {
    return AdminSupportThreadEntry(
      id: json['id']?.toString() ?? '',
      message: json['message'] as String? ?? '',
      authorType: json['author_type'] as String? ?? 'system',
      createdAt: json['created_at'] as String?,
      author: json['author'] is Map
          ? Map<String, dynamic>.from(json['author'] as Map)
          : null,
    );
  }
}

class AdminSupportTicket {
  const AdminSupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.replyCount,
    this.userId,
    this.email,
    this.assignedAdminId,
    this.assignedAdmin,
    this.requester,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.lastMessageAt,
    this.preview,
    this.thread = const [],
  });

  final int id;
  final int? userId;
  final String subject;
  final String message;
  final String? email;
  final String status;
  final int? assignedAdminId;
  final Map<String, dynamic>? assignedAdmin;
  final Map<String, dynamic>? requester;
  final String? createdAt;
  final String? updatedAt;
  final String? closedAt;
  final int replyCount;
  final String? lastMessageAt;
  final String? preview;
  final List<AdminSupportThreadEntry> thread;

  factory AdminSupportTicket.fromJson(Map<String, dynamic> json) {
    return AdminSupportTicket(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      subject: json['subject'] as String? ?? '',
      message: json['message'] as String? ?? '',
      email: json['email'] as String?,
      status: json['status'] as String? ?? 'open',
      assignedAdminId: json['assigned_admin_id'] as int?,
      assignedAdmin: json['assigned_admin'] is Map
          ? Map<String, dynamic>.from(json['assigned_admin'] as Map)
          : null,
      requester: json['requester'] is Map
          ? Map<String, dynamic>.from(json['requester'] as Map)
          : null,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      closedAt: json['closed_at'] as String?,
      replyCount: json['reply_count'] as int? ?? 0,
      lastMessageAt: json['last_message_at'] as String?,
      preview: json['preview'] as String?,
      thread: (json['thread'] as List<dynamic>? ?? const [])
          .map((item) => AdminSupportThreadEntry.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }
}
