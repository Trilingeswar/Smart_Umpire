class BufferStatus {
  final int totalBufferSize; // in balls (max 5)
  final int usedBufferSize; // in balls (current count)
  final int percentageUsed; // percentage based on balls
  final int numberOfClips;
  final bool isRecording;
  final String currentBall;
  final bool isBufferFull;
  final String lastUpdated;

  BufferStatus({
    required this.totalBufferSize,
    required this.usedBufferSize,
    required this.percentageUsed,
    required this.numberOfClips,
    required this.isRecording,
    required this.currentBall,
    required this.isBufferFull,
    required this.lastUpdated,
  });

  factory BufferStatus.fromJson(Map<String, dynamic> json) {
    return BufferStatus(
      totalBufferSize: json['totalBufferSize'] ?? 5,
      usedBufferSize: json['usedBufferSize'] ?? 0,
      percentageUsed: json['percentageUsed'] ?? 0,
      numberOfClips: json['numberOfClips'] ?? 0,
      isRecording: json['isRecording'] ?? false,
      currentBall: json['currentBall'] ?? 'Ball 0',
      isBufferFull: json['isBufferFull'] ?? false,
      lastUpdated: json['lastUpdated'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalBufferSize': totalBufferSize,
      'usedBufferSize': usedBufferSize,
      'percentageUsed': percentageUsed,
      'numberOfClips': numberOfClips,
      'isRecording': isRecording,
      'currentBall': currentBall,
      'isBufferFull': isBufferFull,
      'lastUpdated': lastUpdated,
    };
  }
}
