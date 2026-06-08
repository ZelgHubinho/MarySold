class AuditLog {
  final int id;
  final int? userId;
  final String username;
  final String action;
  final String details;
  final DateTime createdAt;

  AuditLog({
    required this.id,
    this.userId,
    required this.username,
    required this.action,
    required this.details,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      username: json['username'] as String,
      action: json['action'] as String,
      details: json['details'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
