class AdminAnalyticsOverview {
  const AdminAnalyticsOverview({
    required this.kpis,
    required this.subscriptionsByPlan,
    required this.paidSubscriptions,
    required this.freeSubscriptions,
    required this.usageSummary,
    required this.recentTickets,
  });

  final Map<String, int> kpis;
  final Map<String, int> subscriptionsByPlan;
  final int paidSubscriptions;
  final int freeSubscriptions;
  final Map<String, int> usageSummary;
  final List<Map<String, dynamic>> recentTickets;

  factory AdminAnalyticsOverview.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseIntMap(dynamic value) {
      final source = value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
      return source.map((key, raw) => MapEntry(key, (raw as num?)?.toInt() ?? 0));
    }

    final subscriptions = json['subscriptions_summary'] is Map
        ? Map<String, dynamic>.from(json['subscriptions_summary'] as Map)
        : const <String, dynamic>{};

    return AdminAnalyticsOverview(
      kpis: parseIntMap(json['kpis']),
      subscriptionsByPlan: parseIntMap(subscriptions['by_plan']),
      paidSubscriptions: (subscriptions['paid_total'] as num?)?.toInt() ?? 0,
      freeSubscriptions: (subscriptions['free_total'] as num?)?.toInt() ?? 0,
      usageSummary: parseIntMap(json['usage_summary']),
      recentTickets: (json['recent_tickets'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }
}

class AdminAnalyticsUsagePoint {
  const AdminAnalyticsUsagePoint({
    required this.date,
    required this.label,
    required this.users,
    required this.children,
    required this.activities,
    required this.tickets,
  });

  final String date;
  final String label;
  final int users;
  final int children;
  final int activities;
  final int tickets;

  factory AdminAnalyticsUsagePoint.fromJson(Map<String, dynamic> json) {
    return AdminAnalyticsUsagePoint(
      date: json['date'] as String? ?? '',
      label: json['label'] as String? ?? '',
      users: (json['users'] as num?)?.toInt() ?? 0,
      children: (json['children'] as num?)?.toInt() ?? 0,
      activities: (json['activities'] as num?)?.toInt() ?? 0,
      tickets: (json['tickets'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminAnalyticsUsage {
  const AdminAnalyticsUsage({
    required this.range,
    required this.points,
  });

  final String range;
  final List<AdminAnalyticsUsagePoint> points;

  factory AdminAnalyticsUsage.fromJson(Map<String, dynamic> json) {
    return AdminAnalyticsUsage(
      range: json['range'] as String? ?? 'week',
      points: (json['points'] as List<dynamic>? ?? const [])
          .map((item) => AdminAnalyticsUsagePoint.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }
}
