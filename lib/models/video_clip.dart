class VideoClip {
  final String id;
  final String filename;
  final String localPath;
  final String? s3Url;
  final DateTime timestamp;
  final int duration; // in seconds
  final bool isUploaded;
  final String ballNumber;
  final int size; // in bytes
  final int cameraIndex; // 1 for camera 1, 2 for camera 2
  final String matchName; // Name of the match this clip belongs to
  final String? camera2Path; // Path to camera 2 video if dual recording
  final bool isReball;
  final int reballIndex;
  final bool isPermanent;

  VideoClip({
    required this.id,
    required this.filename,
    required this.localPath,
    this.s3Url,
    required this.timestamp,
    required this.duration,
    this.isUploaded = false,
    required this.ballNumber,
    required this.size,
    this.cameraIndex = 1,
    this.matchName = '',
    this.camera2Path,
    this.isReball = false,
    this.reballIndex = 0,
    this.isPermanent = false,
  });

  factory VideoClip.fromJson(Map<String, dynamic> json) {
    return VideoClip(
      id: json['id'] ?? '',
      filename: json['filename'] ?? '',
      localPath: json['localPath'] ?? '',
      s3Url: json['s3Url'],
      timestamp: DateTime.parse(json['timestamp']),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      isUploaded: json['isUploaded'] ?? false,
      ballNumber: json['ballNumber'] ?? '',
      size: json['size'] ?? 0,
      cameraIndex: json['cameraIndex'] ?? 1,
      matchName: json['matchName'] ?? '',
      camera2Path: json['camera2Path'],
      isReball: json['isReball'] ?? false,
      reballIndex: json['reballIndex'] ?? 0,
      isPermanent: json['isPermanent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'localPath': localPath,
      's3Url': s3Url,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration,
      'isUploaded': isUploaded,
      'ballNumber': ballNumber,
      'size': size,
      'cameraIndex': cameraIndex,
      'matchName': matchName,
      'camera2Path': camera2Path,
      'isReball': isReball,
      'reballIndex': reballIndex,
      'isPermanent': isPermanent,
    };
  }

  VideoClip copyWith({
    String? id,
    String? filename,
    String? localPath,
    String? s3Url,
    DateTime? timestamp,
    int? duration,
    bool? isUploaded,
    String? ballNumber,
    int? size,
    int? cameraIndex,
    String? matchName,
    String? camera2Path,
    bool? isReball,
    int? reballIndex,
    bool? isPermanent,
  }) {
    return VideoClip(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      localPath: localPath ?? this.localPath,
      s3Url: s3Url ?? this.s3Url,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      isUploaded: isUploaded ?? this.isUploaded,
      ballNumber: ballNumber ?? this.ballNumber,
      size: size ?? this.size,
      cameraIndex: cameraIndex ?? this.cameraIndex,
      matchName: matchName ?? this.matchName,
      camera2Path: camera2Path ?? this.camera2Path,
      isReball: isReball ?? this.isReball,
      reballIndex: reballIndex ?? this.reballIndex,
      isPermanent: isPermanent ?? this.isPermanent,
    );
  }
}
