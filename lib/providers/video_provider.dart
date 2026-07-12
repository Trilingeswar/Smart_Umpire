import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import '../models/video_clip.dart';
import '../models/buffer_status.dart';
import '../models/match_details.dart';
import '../models/camera_config.dart';
import '../services/local_video_service.dart';
import '../services/camera_service.dart';

class VideoProvider with ChangeNotifier {
  final LocalVideoService _localVideoService = LocalVideoService();
  final CameraService _cameraService = CameraService();

  List<VideoClip> _bufferedClips = [];
  BufferStatus? _bufferStatus;
  MatchDetails? _matchDetails;
  bool _isRecording = false;
  bool _isLoading = false;
  String? _error;
  int _ballCount = 1;

  // Innings tracking
  int _currentInnings = 1;

  // Track dual camera mode
  bool _isDualCameraMode = false;

  // Reball recording state
  bool _isReballRecording = false;
  int _currentReballIndex = 1;
  Map<String, int> _reballCountsPerBall = {};

  // Flag for automatic reball trigger after redirection
  bool _shouldAutoReball = false;
  bool get shouldAutoReball => _shouldAutoReball;

  set shouldAutoReball(bool value) {
    _shouldAutoReball = value;
    notifyListeners();
  }

  void clearAutoReball() {
    _shouldAutoReball = false;
    notifyListeners();
  }

  // ── Live preview players (media_kit) ──────────────────────────────────────
  // Separate Player per camera index — prevents black screen from shared state.
  final Map<int, Player> _previewPlayers = {};

  // For replay browser
  String? _selectedMatchFolder;
  List<String> _allMatchFolders = [];

  // ── Getters ────────────────────────────────────────────────────────────────
  List<VideoClip> get bufferedClips => _bufferedClips;
  BufferStatus? get bufferStatus => _bufferStatus;
  MatchDetails? get matchDetails => _matchDetails;
  bool get isRecording => _isRecording;
  bool get isLoading => _isLoading;
  String? get error => _error;
  CameraService get cameraService => _cameraService;
  bool get isDualCameraMode => _isDualCameraMode;
  String? get selectedMatchFolder => _selectedMatchFolder;
  List<String> get allMatchFolders => _allMatchFolders;
  bool get isReballRecording => _isReballRecording;
  int get currentReballIndex => _currentReballIndex;
  int get currentBallNumber => _ballCount;
  int get currentInnings => _currentInnings;

  /// True only when at least one ball has been recorded and we're not already recording.
  bool get canReball => _ballCount > 1 && !_isRecording;

  /// The current over number (0-based) within the current innings.
  int get currentOver => (_ballCount - 1) ~/ 6;

  /// The ball-in-over (1-based) within the current over.
  int get ballInCurrentOver => ((_ballCount - 1) % 6) + 1;

  /// Formatted string like "2.3" (over.ball) for the NEXT ball to be bowled.
  String get currentOverBall => '$currentOver.$ballInCurrentOver';

  /// True when the configured number of overs for this innings has been completed.
  bool get isInningsOver {
    if (_matchDetails == null) return false;
    return currentOver >= _matchDetails!.numberOfOvers;
  }

  /// True when both innings are completed.
  bool get isMatchOver {
    if (_matchDetails == null) return false;
    return _currentInnings >= 2 && isInningsOver;
  }

  /// Convert ball count to over.ball format (e.g., 1 -> "0.1", 7 -> "1.1")
  String _getBallName(int ballNumber) {
    final over = (ballNumber - 1) ~/ 6;
    final ballInOver = ((ballNumber - 1) % 6) + 1;
    return '$over.$ballInOver';
  }

  /// Returns the preview Player for a given camera index (1 or 2).
  Player? getPreviewPlayer(int cameraIndex) => _previewPlayers[cameraIndex];

  // ── Camera initialisation ──────────────────────────────────────────────────
  Future<void> initializeCamera() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _cameraService.initializeCamera();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Live preview ───────────────────────────────────────────────────────────
  /// Initialises isolated media_kit Players for each configured camera.
  /// Called from LivePreviewScreen when match details are available.
  Future<void> initializePreviewPlayers() async {
    if (_matchDetails == null) return;

    // Dispose any existing players first
    await disposePreviewPlayers();

    final details = _matchDetails!;

    // Start both camera preview players IN PARALLEL to halve init time
    final futures = <Future>[];

    if (details.cameraIp.isNotEmpty) {
      futures.add(_startPreviewPlayer(1, details.cameraIp,
          details.cameraUsername, details.cameraPassword, details.cameraPort));
    }

    if (details.hasDualCameras) {
      futures.add(_startPreviewPlayer(2, details.camera2Ip,
          details.camera2Username, details.camera2Password,
          details.camera2Port));
    }

    if (futures.isNotEmpty) await Future.wait(futures);

    notifyListeners();
  }

  Future<void> _startPreviewPlayer(
    int cameraIndex,
    String ip,
    String username,
    String password,
    int port,
  ) async {
    final config = CameraConfig(
        ip: ip, username: username, password: password, port: port);
    final rtspUrl = config.rtspUrl;

    final player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
      ),
    );
    _previewPlayers[cameraIndex] = player;

    // ── Ultra-low-latency mpv properties ─────────────────────────────────────
    // These target the 4-second glass-to-glass delay on RTSP live preview.
    // All properties are set BEFORE opening the stream so mpv picks them up
    // during demuxer/decoder initialisation.
    //
    // Why each property matters:
    //  aid=no                  → Disable audio track entirely — skips the whole
    //                            audio demux + decode pipeline. Audio was the
    //                            biggest hidden contributor to A/V sync buffering.
    //  cache=no                → No demuxer packet cache. mpv normally pre-buffers
    //                            several seconds; this disables it completely.
    //  cache-pause=no          → Don't pause playback when cache runs dry.
    //  demuxer-readahead-secs=0→ Zero look-ahead. mpv won't collect future
    //                            packets before handing them to the decoder.
    //  demuxer-max-bytes=128KB → Hard ceiling on the demuxer packet queue size.
    //  demuxer-max-back-bytes=0→ Zero backward buffer. Removes the cost of
    //                            keeping past frames in memory for seeking.
    //  framedrop=vo            → Drop frames at the video output stage when
    //                            the decoder falls behind — stays live instead
    //                            of playing out a growing backlog.
    //  video-latency-hacks=yes → mpv's own live-stream mode: relaxes PTS checks
    //                            and skips buffering heuristics designed for VOD.
    //  vd-lavc-fast=yes        → Skip non-spec-compliant but safe decode shortcuts
    //                            in libavcodec — fastest H.264 decode path.
    //  vd-lavc-threads=1       → Single decode thread removes pipeline latency
    //                            (multi-thread adds 1–2 frame delay per thread).
    //  network-timeout=5       → Fail fast on stall rather than blocking UI.
    //  rtsp-transport=tcp      → Mirrors the FFmpeg TCP flag; avoids UDP reorder.
    try {
      final mpv = player.platform as dynamic;
      await mpv.setProperty('aid', 'no');                    // no audio
      await mpv.setProperty('cache', 'no');
      await mpv.setProperty('cache-pause', 'no');
      await mpv.setProperty('demuxer-readahead-secs', '0');
      await mpv.setProperty('demuxer-max-bytes', '131072');  // 128 KB
      await mpv.setProperty('demuxer-max-back-bytes', '0');
      await mpv.setProperty('framedrop', 'vo');
      await mpv.setProperty('video-latency-hacks', 'yes');
      await mpv.setProperty('vd-lavc-fast', 'yes');
      await mpv.setProperty('vd-lavc-threads', '1');
      await mpv.setProperty('network-timeout', '5');
      await mpv.setProperty('rtsp-transport', 'tcp');
    } catch (e) {
      print('[Preview Cam$cameraIndex] mpv setProperty warning: $e');
    }

    try {
      await player.open(
        Media(rtspUrl),
        play: true,
      );
      print('[Preview Cam$cameraIndex] Started (ultra-low-latency, no audio): $rtspUrl');
    } catch (e) {
      print('[Preview Cam$cameraIndex] Error: $e');
    }
  }


  Future<void> disposePreviewPlayers() async {
    for (final entry in _previewPlayers.entries) {
      try {
        await entry.value.stop();
        await entry.value.dispose();
        print('[Preview Cam${entry.key}] Disposed');
      } catch (_) {}
    }
    _previewPlayers.clear();
  }

  // ── Recording ──────────────────────────────────────────────────────────────
  Future<void> startRecording({bool isReball = false}) async {
    if (_matchDetails == null) {
      _error = 'Please set match details first';
      notifyListeners();
      return;
    }

    // Prevent recording if the innings is over (but allow reballs)
    if (!isReball && isInningsOver) {
      _error = 'Innings $currentInnings is over. Switch to the next innings.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _isDualCameraMode = _matchDetails!.hasDualCameras;
      _isReballRecording = isReball;
      
      final matchFolder = _matchDetails!.folderName;
      _localVideoService.setMatchFolder(matchFolder);
      
      // For reball, use the LAST recorded ball (ballCount - 1) because
      // _ballCount was already incremented after the previous normal recording.
      // For normal recording, use _ballCount as-is.
      final effectiveBallNumber = isReball ? _ballCount - 1 : _ballCount;

      // Get the reball index for this ball if reballing
      int reballIndex = 0;
      if (isReball) {
        final currentBallKey = _getBallName(effectiveBallNumber);
        reballIndex = (_reballCountsPerBall[currentBallKey] ?? 0) + 1;
      }

      if (_isDualCameraMode) {
        await _localVideoService.startDualCapture(
          config1: CameraConfig(
            ip: _matchDetails!.cameraIp,
            username: _matchDetails!.cameraUsername,
            password: _matchDetails!.cameraPassword,
            port: _matchDetails!.cameraPort,
          ),
          config2: CameraConfig(
            ip: _matchDetails!.camera2Ip,
            username: _matchDetails!.camera2Username,
            password: _matchDetails!.camera2Password,
            port: _matchDetails!.camera2Port,
          ),
          ballNumber: effectiveBallNumber,
          matchFolder: matchFolder,
          isReball: isReball,
          reballIndex: reballIndex,
        );
      } else {
        await _localVideoService.startCapture(
          ip: _matchDetails!.cameraIp,
          username: _matchDetails!.cameraUsername,
          password: _matchDetails!.cameraPassword,
          ballNumber: effectiveBallNumber,
          port: _matchDetails!.cameraPort,
          matchFolder: matchFolder,
          isReball: isReball,
          reballIndex: reballIndex,
        );
      }

      _isRecording = true;
      await refreshBufferStatus();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> stopRecording() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      List<VideoClip> newClips;

      if (_isDualCameraMode) {
        newClips = await _localVideoService.stopDualCapture();
      } else {
        final clip = await _localVideoService.stopCapture();
        newClips = clip != null ? [clip] : [];
      }

      _isRecording = false;
      _isDualCameraMode = false;

      if (newClips.isNotEmpty) {
        // Only increment ball count if NOT a reball
        if (!_isReballRecording) {
          _ballCount++;
        } else {
          // For reball: track reball count for the PREVIOUS ball, DON'T increment ball number
          final reballBallKey = _getBallName(_ballCount - 1);
          _reballCountsPerBall[reballBallKey] = (_reballCountsPerBall[reballBallKey] ?? 0) + 1;
          _currentReballIndex = _reballCountsPerBall[reballBallKey] ?? 1;
        }
        _bufferedClips.insertAll(0, newClips);
        _bufferedClips = _limitClipsByBallCount(_bufferedClips, maxBalls: 6);
      }

      _isReballRecording = false;
      await refreshBufferStatus();
      await refreshBufferedClips();

      // Persist match state after every ball recording
      await _persistMatchState();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Limits clips to a maximum number of unique balls.
  /// Keeps ALL clips (original + rebals) for each ball.
  List<VideoClip> _limitClipsByBallCount(List<VideoClip> clips,
      {required int maxBalls}) {
    if (clips.isEmpty) return clips;

    // Group clips by ball number
    final Map<String, List<VideoClip>> clipsByBall = {};
    for (final clip in clips) {
      if (!clipsByBall.containsKey(clip.ballNumber)) {
        clipsByBall[clip.ballNumber] = [];
      }
      clipsByBall[clip.ballNumber]!.add(clip);
    }

    // Take only maxBalls unique balls (with all their rebals)
    final uniqueBalls = clipsByBall.keys.toList();
    final result = <VideoClip>[];
    
    // Sort balls in reverse order (newest first)
    uniqueBalls.sort((a, b) => b.compareTo(a));
    
    for (int i = 0; i < uniqueBalls.length && i < maxBalls; i++) {
      final ballKey = uniqueBalls[i];
      result.addAll(clipsByBall[ballKey]!);
    }

    return result;
  }

  // ── Buffer / clip helpers ──────────────────────────────────────────────────
  Future<void> refreshBufferStatus() async {
    try {
      _bufferStatus = await _localVideoService.getBufferStatus();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshBufferedClips() async {
    _isLoading = true;
    notifyListeners();

    try {
      _bufferedClips = await _localVideoService.getClips();
      
      // Rebuild reball counts from loaded clips
      _reballCountsPerBall.clear();
      for (final clip in _bufferedClips) {
        if (clip.isReball) {
          final ballKey = clip.ballNumber;
          final currentMax = _reballCountsPerBall[ballKey] ?? 0;
          if (clip.reballIndex > currentMax) {
            _reballCountsPerBall[ballKey] = clip.reballIndex;
          }
        }
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<VideoClip?> selectClipForReview(String clipId) async {
    _error = null;
    try {
      return _bufferedClips.firstWhere((c) => c.id == clipId);
    } catch (e) {
      return null;
    }
  }

  String getVideoUrl(String clipId) {
    try {
      final clip = _bufferedClips.firstWhere((c) => c.id == clipId);
      return clip.localPath;
    } catch (e) {
      return '';
    }
  }

  void saveMatchDetails(MatchDetails details) {
    _matchDetails = details;
    _currentInnings = 1;
    _ballCount = 1;
    _reballCountsPerBall.clear();
    notifyListeners();
    // Persist state immediately when a new match is created
    _persistMatchState();
  }

  /// Moves to the next innings, resetting ball count.
  void switchToNextInnings() {
    if (_currentInnings < 2) {
      _currentInnings = 2;
      _ballCount = 1;
      _reballCountsPerBall.clear();
      _bufferedClips = [];
      notifyListeners();
      // Persist state when switching innings
      _persistMatchState();
    }
  }

  /// Ends the current match entirely and resets all state.
  /// For incomplete matches: saves the state so it can be resumed.
  /// For completed matches (both innings done): deletes the state file.
  Future<void> endMatch() async {
    if (_matchDetails != null) {
      final folderName = _matchDetails!.folderName;
      if (isMatchOver) {
        // Match is fully completed — delete state file so it's not resumable
        await _localVideoService.deleteMatchState(folderName);
      } else {
        // Match is not finished — save state for resuming later
        await _localVideoService.saveMatchState(
          matchFolder: folderName,
          matchDetailsJson: _matchDetails!.toJson(),
          ballCount: _ballCount,
          currentInnings: _currentInnings,
          reballCountsPerBall: Map<String, int>.from(_reballCountsPerBall),
        );
      }
    }

    await disposePreviewPlayers();
    _matchDetails = null;
    _isRecording = false;
    _ballCount = 1;
    _currentInnings = 1;
    _bufferedClips = [];
    _bufferStatus = null;
    _reballCountsPerBall.clear();
    _isReballRecording = false;
    _currentReballIndex = 1;
    _shouldAutoReball = false;
    _error = null;
    notifyListeners();
  }

  // ── Match State Persistence ────────────────────────────────────────────────

  /// Persists the current match state to disk.
  /// Called automatically after every ball recording, innings switch, etc.
  Future<void> _persistMatchState() async {
    if (_matchDetails == null) return;
    await _localVideoService.saveMatchState(
      matchFolder: _matchDetails!.folderName,
      matchDetailsJson: _matchDetails!.toJson(),
      ballCount: _ballCount,
      currentInnings: _currentInnings,
      reballCountsPerBall: Map<String, int>.from(_reballCountsPerBall),
    );
  }

  /// Checks if a match folder has a saved state that can be resumed.
  Future<bool> canResumeMatch(String matchFolder) async {
    return await _localVideoService.hasMatchState(matchFolder);
  }

  /// Resumes a previously ended match by restoring its saved state.
  /// This loads the match details, ball count, innings, and reball counts
  /// from the match folder's state file and restores the provider to that state.
  Future<bool> resumeMatch(String matchFolder) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final stateData = await _localVideoService.loadMatchState(matchFolder);
      if (stateData == null) {
        _error = 'No saved match state found for this match.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Restore match details
      final matchDetailsJson = stateData['matchDetails'] as Map<String, dynamic>;
      _matchDetails = MatchDetails.fromJson(matchDetailsJson);

      // Restore match progress
      _ballCount = stateData['ballCount'] as int? ?? 1;
      _currentInnings = stateData['currentInnings'] as int? ?? 1;

      // Restore reball counts
      _reballCountsPerBall.clear();
      final savedReballCounts = stateData['reballCountsPerBall'] as Map<String, dynamic>?;
      if (savedReballCounts != null) {
        savedReballCounts.forEach((key, value) {
          _reballCountsPerBall[key] = value as int;
        });
      }

      // Reset transient state
      _isRecording = false;
      _isReballRecording = false;
      _currentReballIndex = 1;
      _shouldAutoReball = false;
      _bufferedClips = [];
      _bufferStatus = null;

      // Set the match folder on the local video service
      _localVideoService.setMatchFolder(_matchDetails!.folderName);

      // Refresh clips from the existing folder
      await refreshBufferedClips();
      await refreshBufferStatus();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to resume match: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Returns a list of all match folder names that can be resumed.
  Future<List<String>> getResumableMatches() async {
    return await _localVideoService.getAllResumableMatches();
  }

  Future<void> loadMatchFolders() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allMatchFolders = await _localVideoService.getAllMatchFolders();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectMatchFolder(String folderName) async {
    _selectedMatchFolder = folderName;
    _isLoading = true;
    notifyListeners();

    try {
      _bufferedClips = await _localVideoService.getClipsFromFolder(folderName);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearSelectedMatchFolder() {
    _selectedMatchFolder = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Save & Export Wrappers ────────────────────────────────────────────────
  
  Future<bool> saveClip(VideoClip clip) async {
    _isLoading = true;
    notifyListeners();
    try {
      final savedPath = await _localVideoService.saveBallReplay(clip);
      _isLoading = false;
      notifyListeners();
      return savedPath != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> exportClip(VideoClip clip) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _localVideoService.exportToGallery(clip);
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMatchFolder(String matchFolder) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _localVideoService.deleteMatchFolder(matchFolder);
      if (success) {
        if (_selectedMatchFolder == matchFolder) {
          _selectedMatchFolder = null;
          _bufferedClips = [];
        }
        _allMatchFolders = await _localVideoService.getAllMatchFolders();
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    disposePreviewPlayers();
    _cameraService.dispose();
    _localVideoService.stopCapture();
    super.dispose();
  }
}

