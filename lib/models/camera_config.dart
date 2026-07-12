/// Model class for storing camera configuration including IP, username, and password.
class CameraConfig {
  /// The IP address of the camera (without protocol)
  final String ip;

  /// The username for camera authentication
  final String username;

  /// The password for camera authentication
  final String password;

  /// Optional port number (default: 5554)
  final int port;

  /// Creates a new CameraConfig instance.
  CameraConfig({
    required this.ip,
    required this.username,
    required this.password,
    this.port = 5554,
  });

  /// Constructs the RTSP URL with authentication credentials.
  ///
  /// Format: rtsp://username:password@ip:port/
  String get rtspUrl {
    return 'rtsp://$username:$password@$ip:$port/';
  }

  /// Creates a copy of this CameraConfig with updated values.
  CameraConfig copyWith({
    String? ip,
    String? username,
    String? password,
    int? port,
  }) {
    return CameraConfig(
      ip: ip ?? this.ip,
      username: username ?? this.username,
      password: password ?? this.password,
      port: port ?? this.port,
    );
  }

  /// Converts this config to a JSON-compatible Map.
  Map<String, dynamic> toMap() {
    return {
      'ip': ip,
      'username': username,
      'password': password,
      'port': port,
    };
  }

  /// Creates a CameraConfig from a Map (e.g., from shared_preferences).
  factory CameraConfig.fromMap(Map<String, dynamic> map) {
    return CameraConfig(
      ip: map['ip'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      port: map['port'] ?? 5554,
    );
  }

  /// Returns an empty CameraConfig with default values.
  factory CameraConfig.empty() {
    return CameraConfig(
      ip: '',
      username: '',
      password: '',
      port: 5554,
    );
  }

  /// Checks if this config has valid non-empty values.
  bool get isValid {
    return ip.isNotEmpty && username.isNotEmpty && password.isNotEmpty;
  }

  @override
  String toString() {
    return 'CameraConfig(ip: $ip, port: $port)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraConfig &&
        other.ip == ip &&
        other.username == username &&
        other.password == password &&
        other.port == port;
  }

  @override
  int get hashCode {
    return Object.hash(ip, username, password, port);
  }
}
