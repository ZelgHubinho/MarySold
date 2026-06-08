class User {
  final int id;
  final String username;
  final String role; // 'admin' or 'seller'

  User({
    required this.id,
    required this.username,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isSeller => role == 'seller';

  @override
  String toString() => 'User(id: $id, username: $username, role: $role)';
}
