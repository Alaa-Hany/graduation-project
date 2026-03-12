class ParentNotificationEntry {
  const ParentNotificationEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.isRemote,
    this.remoteId,
    this.childId,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final bool isRemote;
  final String? remoteId;
  final String? childId;

  ParentNotificationEntry copyWith({
    bool? isRead,
  }) {
    return ParentNotificationEntry(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isRemote: isRemote,
      remoteId: remoteId,
      childId: childId,
    );
  }

  factory ParentNotificationEntry.fromBackend(
    Map<String, dynamic> json,
  ) {
    return ParentNotificationEntry(
      id: 'server-${json['id']}',
      remoteId: json['id']?.toString(),
      type: json['type']?.toString() ?? 'SYSTEM',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isRead: json['is_read'] == true,
      isRemote: true,
      childId: json['child_id']?.toString(),
    );
  }
}
