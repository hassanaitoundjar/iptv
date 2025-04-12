class XtreamUser {
  final String username;
  final String password;
  final String status;
  final String expDate;
  final bool isActive;
  final String message;
  final int maxConnections;
  final String createdAt;
  final String timezone;
  final String serverUrl;

  XtreamUser({
    required this.username,
    required this.password,
    required this.status,
    required this.expDate,
    required this.isActive,
    required this.message,
    required this.maxConnections,
    required this.createdAt,
    required this.timezone,
    required this.serverUrl,
  });

  factory XtreamUser.fromJson(Map<String, dynamic> json, String serverUrl) {
    final userInfo = json['user_info'] as Map<String, dynamic>;
    return XtreamUser(
      username: userInfo['username'] ?? '',
      password: userInfo['password'] ?? '',
      status: userInfo['status'] ?? '',
      expDate: userInfo['exp_date'] ?? '',
      isActive: userInfo['is_active'] == '1',
      message: userInfo['message'] ?? '',
      maxConnections: int.tryParse(userInfo['max_connections'] ?? '0') ?? 0,
      createdAt: userInfo['created_at'] ?? '',
      timezone: userInfo['timezone'] ?? '',
      serverUrl: serverUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'status': status,
      'exp_date': expDate,
      'is_active': isActive ? '1' : '0',
      'message': message,
      'max_connections': maxConnections.toString(),
      'created_at': createdAt,
      'timezone': timezone,
      'server_url': serverUrl,
    };
  }
} 