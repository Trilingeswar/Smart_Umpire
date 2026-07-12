class MatchDetails {
  final String matchName;
  final String team1Name;
  final String team2Name;
  final int numberOfOvers;

  // Camera 1 (Primary)
  final String cameraIp;
  final String cameraUsername;
  final String cameraPassword;
  final int cameraPort;

  // Camera 2 (Secondary)
  final String camera2Ip;
  final String camera2Username;
  final String camera2Password;
  final int camera2Port;

  MatchDetails({
    required this.matchName,
    required this.team1Name,
    required this.team2Name,
    required this.numberOfOvers,
    required this.cameraIp,
    required this.cameraUsername,
    required this.cameraPassword,
    this.cameraPort = 5554,
    // Camera 2 fields
    this.camera2Ip = '',
    this.camera2Username = '',
    this.camera2Password = '',
    this.camera2Port = 5554,
  });

  /// Constructs the RTSP URL from the camera 1 configuration.
  String get cameraRtspUrl {
    return 'rtsp://$cameraUsername:$cameraPassword@$cameraIp:$cameraPort/';
  }

  /// Constructs the RTSP URL from the camera 2 configuration.
  String get camera2RtspUrl {
    return 'rtsp://$camera2Username:$camera2Password@$camera2Ip:$camera2Port/';
  }

  /// Checks if camera 1 configuration is valid.
  bool get isCamera1Valid {
    return cameraIp.isNotEmpty &&
        cameraUsername.isNotEmpty &&
        cameraPassword.isNotEmpty;
  }

  /// Checks if camera 2 configuration is valid.
  bool get isCamera2Valid {
    return camera2Ip.isNotEmpty &&
        camera2Username.isNotEmpty &&
        camera2Password.isNotEmpty;
  }

  /// Checks if at least one camera is configured.
  bool get hasAnyCamera => isCamera1Valid || isCamera2Valid;

  /// Checks if both cameras are configured.
  bool get hasDualCameras => isCamera1Valid && isCamera2Valid;

  /// Creates a safe folder name from the match name for storage.
  /// Replaces invalid characters with underscores.
  String get folderName {
    final sanitized = matchName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s-_]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.length > 50 ? sanitized.substring(0, 50) : sanitized;
  }

  MatchDetails copyWith({
    String? matchName,
    String? team1Name,
    String? team2Name,
    int? numberOfOvers,
    String? cameraIp,
    String? cameraUsername,
    String? cameraPassword,
    int? cameraPort,
    String? camera2Ip,
    String? camera2Username,
    String? camera2Password,
    int? camera2Port,
  }) {
    return MatchDetails(
      matchName: matchName ?? this.matchName,
      team1Name: team1Name ?? this.team1Name,
      team2Name: team2Name ?? this.team2Name,
      numberOfOvers: numberOfOvers ?? this.numberOfOvers,
      cameraIp: cameraIp ?? this.cameraIp,
      cameraUsername: cameraUsername ?? this.cameraUsername,
      cameraPassword: cameraPassword ?? this.cameraPassword,
      cameraPort: cameraPort ?? this.cameraPort,
      camera2Ip: camera2Ip ?? this.camera2Ip,
      camera2Username: camera2Username ?? this.camera2Username,
      camera2Password: camera2Password ?? this.camera2Password,
      camera2Port: camera2Port ?? this.camera2Port,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchName': matchName,
      'team1Name': team1Name,
      'team2Name': team2Name,
      'numberOfOvers': numberOfOvers,
      'cameraIp': cameraIp,
      'cameraUsername': cameraUsername,
      'cameraPassword': cameraPassword,
      'cameraPort': cameraPort,
      'camera2Ip': camera2Ip,
      'camera2Username': camera2Username,
      'camera2Password': camera2Password,
      'camera2Port': camera2Port,
    };
  }

  factory MatchDetails.fromJson(Map<String, dynamic> json) {
    return MatchDetails(
      matchName: json['matchName'] ?? '',
      team1Name: json['team1Name'] ?? '',
      team2Name: json['team2Name'] ?? '',
      numberOfOvers: json['numberOfOvers'] ?? 0,
      cameraIp: json['cameraIp'] ?? '',
      cameraUsername: json['cameraUsername'] ?? '',
      cameraPassword: json['cameraPassword'] ?? '',
      cameraPort: json['cameraPort'] ?? 5554,
      camera2Ip: json['camera2Ip'] ?? '',
      camera2Username: json['camera2Username'] ?? '',
      camera2Password: json['camera2Password'] ?? '',
      camera2Port: json['camera2Port'] ?? 5554,
    );
  }
}
