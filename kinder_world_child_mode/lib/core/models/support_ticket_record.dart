class SupportTicketThreadEntry {
  const SupportTicketThreadEntry({
    required this.id,
    required this.message,
    required this.authorType,
    this.createdAt,
    this.author,
  });

  final String id;
  final String message;
  final String authorType;
  final String? createdAt;
  final Map<String, dynamic>? author;

  factory SupportTicketThreadEntry.fromJson(Map<String, dynamic> json) {
    return SupportTicketThreadEntry(
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

class SupportTicketRecord {
  const SupportTicketRecord({
    required this.id,
    required this.subject,
    required this.message,
    required this.category,
    required this.status,
    required this.replyCount,
    this.email,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.preview,
    this.thread = const [],
  });

  final int id;
  final String subject;
  final String message;
  final String category;
  final String status;
  final int replyCount;
  final String? email;
  final String? createdAt;
  final String? updatedAt;
  final String? closedAt;
  final String? preview;
  final List<SupportTicketThreadEntry> thread;

  bool get hasThread => thread.isNotEmpty;
  bool get isClosed => status == 'closed';

  factory SupportTicketRecord.fromJson(Map<String, dynamic> json) {
    return SupportTicketRecord(
      id: json['id'] as int? ?? 0,
      subject: json['subject'] as String? ?? '',
      message: json['message'] as String? ?? '',
      category: json['category'] as String? ?? 'general_inquiry',
      status: json['status'] as String? ?? 'open',
      replyCount: json['reply_count'] as int? ?? 0,
      email: json['email'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      closedAt: json['closed_at'] as String?,
      preview: json['preview'] as String?,
      thread: (json['thread'] as List<dynamic>? ?? const [])
          .map((item) => SupportTicketThreadEntry.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }
}
