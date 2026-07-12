import 'dart:io';
import 'dart:convert';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_clip.dart';
import '../models/buffer_status.dart';
import '../models/camera_config.dart';
import 'camera_config_service.dart';

class LocalVideoService {
  static final LocalVideoService _instance = LocalVideoService._internal();
  factory LocalVideoService() => _instance;
  LocalVideoService._internal();

  // ── Map-based session management ──────────────────────────────────────────
  // Key = camera index (1, 2, …). Prevents any overwrite between sessions.
  final Map<int, FFmpegSession> _captureSessions = {};
  final Map<int, String> _currentBallPaths = {};
  final Map<int, String> _currentClipIds = {};

  DateTime? _recordingStartTime;
  String? _currentBallName;
  String _currentMatchFolder = '';
  bool _isCurrentRecordingReball = false;
  int _currentReballIndex = 0;

  // ── Paths ──────────────────────────────────────────────────────────────────
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<String> get _recordingsPath async {
    final path = await _localPath;
    final dir = Directory('$path/recordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> _getMatchClipsPath() async {
    final recordingsDir = await _recordingsPath;
    final matchFolder =
        _currentMatchFolder.isNotEmpty ? _currentMatchFolder : 'default';
    final dir = Directory('$recordingsDir/$matchFolder/clips');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> getMatchFolderPath(String matchFolder) async {
    final recordingsDir = await _recordingsPath;
    return '$recordingsDir/$matchFolder';
  }

  void setMatchFolder(String matchFolder) {
    _currentMatchFolder = matchFolder;
  }

  // ── Match State Persistence (Resume Feature) ──────────────────────────────

  /// Saves the current match state to a JSON file inside the match folder.
  /// This is called when ending a match so it can be resumed later.
  Future<void> saveMatchState({
    required String matchFolder,
    required Map<String, dynamic> matchDetailsJson,
    required int ballCount,
    required int currentInnings,
    required Map<String, int> reballCountsPerBall,
  }) async {
    try {
      final matchPath = await getMatchFolderPath(matchFolder);
      final stateFile = File('$matchPath/match_state.json');

      final stateData = {
        'matchDetails': matchDetailsJson,
        'ballCount': ballCount,
        'currentInnings': currentInnings,
        'reballCountsPerBall': reballCountsPerBall,
        'savedAt': DateTime.now().toIso8601String(),
      };

      // Ensure match directory exists
      final dir = Directory(matchPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await stateFile.writeAsString(jsonEncode(stateData));
      print('[MatchState] Saved match state to $matchPath/match_state.json');
    } catch (e) {
      print('[MatchState] Error saving match state: $e');
    }
  }

  /// Loads a previously saved match state from a match folder.
  /// Returns null if no state file exists or it cannot be parsed.
  Future<Map<String, dynamic>?> loadMatchState(String matchFolder) async {
    try {
      final matchPath = await getMatchFolderPath(matchFolder);
      final stateFile = File('$matchPath/match_state.json');

      if (!await stateFile.exists()) {
        return null;
      }

      final contents = await stateFile.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;
      print('[MatchState] Loaded match state from $matchPath/match_state.json');
      return data;
    } catch (e) {
      print('[MatchState] Error loading match state: $e');
      return null;
    }
  }

  /// Checks if a match folder has a saved match state that can be resumed.
  Future<bool> hasMatchState(String matchFolder) async {
    try {
      final matchPath = await getMatchFolderPath(matchFolder);
      final stateFile = File('$matchPath/match_state.json');
      return await stateFile.exists();
    } catch (_) {
      return false;
    }
  }

  /// Deletes the saved match state for a completed match.
  Future<void> deleteMatchState(String matchFolder) async {
    try {
      final matchPath = await getMatchFolderPath(matchFolder);
      final stateFile = File('$matchPath/match_state.json');
      if (await stateFile.exists()) {
        await stateFile.delete();
        print('[MatchState] Deleted match state for $matchFolder');
      }
    } catch (e) {
      print('[MatchState] Error deleting match state: $e');
    }
  }

  /// Returns a list of all match folders that have a saved resumable state.
  Future<List<String>> getAllResumableMatches() async {
    final resumable = <String>[];
    try {
      final recordingsDir = await _recordingsPath;
      final dir = Directory(recordingsDir);
      if (!await dir.exists()) return resumable;

      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final folderName = entity.path.split('/').last.split('\\').last;
          final stateFile = File('${entity.path}/match_state.json');
          if (await stateFile.exists()) {
            resumable.add(folderName);
          }
        }
      }
    } catch (e) {
      print('[MatchState] Error scanning for resumable matches: $e');
    }
    return resumable;
  }

  // ── Save & Export Features ────────────────────────────────────────────────
  
  /// Gets the path for permanent saved replays for a specific match.
  /// Structure: /SmartUmpire/Matches/<Match_Id>/Saved_Replays/
  Future<String> _getMatchSavedReplaysPath(String matchFolder) async {
    final recordingsDir = await _recordingsPath;
    final dir = Directory('$recordingsDir/$matchFolder/Saved_Replays');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Saves a clip permanently to the match's Saved_Replays folder.
  /// Handles duplicate filenames by appending _SavedX suffixes.
  /// Returns the path to the saved file (or camera 1 file if two exist).
  Future<String?> saveBallReplay(VideoClip clip) async {
    try {
      final matchFolder = clip.matchName.isNotEmpty ? clip.matchName : _currentMatchFolder;
      if (matchFolder.isEmpty) {
        print('[Save] No match folder available');
        return null;
      }

      final savedDir = await _getMatchSavedReplaysPath(matchFolder);
      
      // Determine base filename without extension
      // Format: <ball>_<uuid>_cam1.mp4
      // We want to preserve the ball number and UUID but handle duplicates.
      String baseName = clip.filename.replaceAll('.mp4', '');
      
      // Check for existing "Saved" suffix to avoid _Saved1_Saved1
      // If saving from buffer, it won't have Saved suffix usually.
      // If saving from Saved_Replays (unlikely but possible), strip existing suffix?
      // Let's just append for safety and simplicity as per request.

      // Generate unique filename for Camera 1
      String newFilename = '${baseName}_Saved.mp4';
      int counter = 1;
      while (await File('$savedDir/$newFilename').exists()) {
        newFilename = '${baseName}_Saved$counter.mp4';
        counter++;
      }
      
      final newPath1 = '$savedDir/$newFilename';
      
      // Copy Camera 1 file
      final file1 = File(clip.localPath);
      if (await file1.exists()) {
        await file1.copy(newPath1);
        print('[Save] Saved clip to $newPath1');
      } else {
        print('[Save] Source file not found: ${clip.localPath}');
        return null;
      }

      // Handle Camera 2 if exists
      if (clip.camera2Path != null) {
        final file2 = File(clip.camera2Path!);
        if (await file2.exists()) {
          // Use same suffix logic for cam2 to keep them in sync?
          // Filename: ..._cam2.mp4
          // If we used counter=2 for cam1, we should use counter=2 for cam2 ideally.
          // But strict file existence check is safer.
          // Let's derive cam2 name from cam1's new name to keep them paired.
          // cam1: ball_uuid_cam1_Saved1.mp4
          // cam2: ball_uuid_cam2_Saved1.mp4
          
          String newFilename2 = newFilename.replaceFirst('cam1', 'cam2');
          
          // If the original didn't have cam1 (legacy?), falls back to standard check
          if (newFilename2 == newFilename) {
             String baseName2 = clip.camera2Path!.split('/').last.replaceAll('.mp4', '');
             newFilename2 = '${baseName2}_Saved${counter > 1 ? (counter - 1) : ""}.mp4';
          }
          
          final newPath2 = '$savedDir/$newFilename2';
          await file2.copy(newPath2);
          print('[Save] Saved camera 2 clip to $newPath2');
        }
      }

      return newPath1;
    } catch (e) {
      print('[Save] Error saving clip: $e');
      return null;
    }
  }

  /// Exports the clip to the device Gallery/Movies folder.
  /// Uses 'gal' package to handle Android 10+ scoped storage.
  /// Saves to album "SmartUmpire".
  Future<bool> exportToGallery(VideoClip clip) async {
    try {
      // Check permissions first
      if (!await _requestStoragePermission()) {
        print('[Export] Permission denied');
        return false;
      }

      // Export Camera 1
      await Gal.putVideo(clip.localPath, album: 'SmartUmpire');
      print('[Export] Camera 1 exported to Gallery');

      // Export Camera 2 if exists
      if (clip.camera2Path != null) {
        await Gal.putVideo(clip.camera2Path!, album: 'SmartUmpire');
        print('[Export] Camera 2 exported to Gallery');
      }

      return true;
    } catch (e) {
      print('[Export] Error exporting to gallery: $e');
      return false;
    }
  }

  Future<bool> _requestStoragePermission() async {
    // For Android 10+, Gal handles it, but good to check generally.
    // Gal.requestAccess() handles platform specific logic.
    try {
      return await Gal.requestAccess(); 
    } catch (e) {
      // Fallback for older devices or if Gal.requestAccess throws
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
  }

  // ── FFmpeg command ──────────────────────────────────────────────────────
  /// Stream-copy recording command: ZERO re-encode latency, original quality.
  ///
  /// Why stream-copy (-c:v copy) instead of libx264:
  ///  • No encoder init (~500–1000 ms saved at recording start).
  ///  • Original H.264 frames written directly — no double-compression artifacts.
  ///  • CPU is completely free during recording (no encode work).
  ///  • Bitrate = camera's native bitrate — no quality ceiling.
  ///
  /// Input flags (applied BEFORE -i) control RTSP demux behaviour.
  /// Output flags (after -i) control container muxing only.
  String _generateFFmpegCommand({
    required String rtspUrl,
    required String outputPath,
  }) {
    return
        // ── Input / demux options ───────────────────────────────────────
        '-rtsp_transport tcp '          // Force TCP — reliable, no UDP drops
        '-rtsp_flags prefer_tcp '       // Prefer TCP even if server offers UDP
        '-reorder_queue_size 8 '        // Tiny jitter buffer (we use TCP, low jitter)
        '-analyzeduration 300000 '      // 300 ms stream analysis (fast open)
        '-probesize 300000 '            // 300 KB probe size (fast open)
        '-fflags nobuffer+discardcorrupt+genpts ' // No demux buffer; regen bad PTS
        '-flags low_delay '             // Decoder: minimal pipeline latency
        '-i $rtspUrl '
        // ── Output / codec ───────────────────────────────────────────
        '-c:v copy '                    // STREAM COPY — zero encode latency
        '-an '                          // No audio
        '-avoid_negative_ts make_zero ' // Clean timestamps — smooth seeking
        '-movflags frag_keyframe+empty_moov+default_base_moof ' // Robust frag MP4
        '$outputPath';
  }

  // ── File-flush poller ──────────────────────────────────────────────────────
  /// Waits until [filePath] stops growing in size (i.e. FFmpeg has flushed all
  /// data) or [maxWaitMs] elapses. Uses 50 ms poll intervals.
  /// This replaces the old blind Future.delayed(500–600 ms) with a smart wait
  /// that exits as soon as the file is stable — often in < 100 ms.
  Future<void> _waitForFileFlush(String filePath,
      {int maxWaitMs = 2000}) async {
    final file = File(filePath);
    int lastSize = -1;
    int stableCount = 0;
    int elapsed = 0;
    const pollMs = 50;

    while (elapsed < maxWaitMs) {
      await Future.delayed(const Duration(milliseconds: pollMs));
      elapsed += pollMs;
      if (!await file.exists()) continue;
      final current = (await file.stat()).size;
      
      if (current > 0 && current == lastSize) {
        stableCount++;
        if (stableCount >= 2) return; // Confirmed stable for ~100ms
      } else {
        stableCount = 0;
      }
      lastSize = current;
    }
  }

  // ── Single-camera capture ──────────────────────────────────────────────────
  Future<void> startCapture({
    required String ip,
    required String username,
    required String password,
    int ballNumber = 1,
    int port = 5554,
    String? matchFolder,
    bool isReball = false,
    int reballIndex = 0,
  }) async {
    final config = CameraConfig(
      ip: ip,
      username: username,
      password: password,
      port: port,
    );
    await startCaptureWithConfig(config, ballNumber, matchFolder: matchFolder, isReball: isReball, reballIndex: reballIndex);
  }

  Future<void> startCaptureWithConfig(
    CameraConfig config,
    int ballNumber, {
    String? matchFolder,
    int cameraIndex = 1,
    bool isReball = false,
    int reballIndex = 0,
  }) async {
    if (matchFolder != null) _currentMatchFolder = matchFolder;

    final clipsDir = await _getMatchClipsPath();
    await _manageBuffer(clipsDir);

    final clipId = const Uuid().v4();
    _currentBallName = _getBallName(ballNumber);
    _isCurrentRecordingReball = isReball;
    _currentReballIndex = reballIndex;

    String filename;
    if (isReball) {
      filename = '${_currentBallName}_Reball_${reballIndex}_${clipId}_cam$cameraIndex.mp4';
    } else {
      filename = '${_currentBallName}_${clipId}_cam$cameraIndex.mp4';
    }
    final ballPath = '$clipsDir/$filename';

    // Store per-camera state
    _currentClipIds[cameraIndex] = clipId;
    _currentBallPaths[cameraIndex] = ballPath;

    final command = _generateFFmpegCommand(
      rtspUrl: config.rtspUrl,
      outputPath: ballPath,
    );

    _recordingStartTime = DateTime.now();
    print('[Cam$cameraIndex] Starting Recording Ball $_currentBallName: $command');

    final session = await FFmpegKit.executeAsync(command, (s) async {
      final rc = await s.getReturnCode();
      print('[Cam$cameraIndex] FFmpeg session finished with code: $rc');
    });

    _captureSessions[cameraIndex] = session;
  }

  // ── Dual-camera capture ────────────────────────────────────────────────────
  /// Both cameras start in parallel with completely isolated sessions.
  Future<void> startDualCapture({
    required CameraConfig config1,
    required CameraConfig config2,
    int ballNumber = 1,
    String? matchFolder,
    bool isReball = false,
    int reballIndex = 0,
  }) async {
    if (matchFolder != null) _currentMatchFolder = matchFolder;

    final clipsDir = await _getMatchClipsPath();
    await _manageBuffer(clipsDir);

    // Use the SAME clipId for both cameras so they can be paired on playback
    final clipId = const Uuid().v4();
    _currentBallName = _getBallName(ballNumber);
    _isCurrentRecordingReball = isReball;
    _currentReballIndex = reballIndex;

    String filename1;
    String filename2;
    if (isReball) {
      filename1 = '${_currentBallName}_Reball_${reballIndex}_${clipId}_cam1.mp4';
      filename2 = '${_currentBallName}_Reball_${reballIndex}_${clipId}_cam2.mp4';
    } else {
      filename1 = '${_currentBallName}_${clipId}_cam1.mp4';
      filename2 = '${_currentBallName}_${clipId}_cam2.mp4';
    }

    _currentClipIds[1] = clipId;
    _currentClipIds[2] = clipId;
    _currentBallPaths[1] = '$clipsDir/$filename1';
    _currentBallPaths[2] = '$clipsDir/$filename2';

    final command1 = _generateFFmpegCommand(
      rtspUrl: config1.rtspUrl,
      outputPath: _currentBallPaths[1]!,
    );
    final command2 = _generateFFmpegCommand(
      rtspUrl: config2.rtspUrl,
      outputPath: _currentBallPaths[2]!,
    );

    _recordingStartTime = DateTime.now();
    print('[DualCam] Starting Ball $_currentBallName — both cameras in parallel');
    print('[Cam1] $command1');
    print('[Cam2] $command2');

    // Launch both sessions in parallel — each is completely independent
    final results = await Future.wait([
      FFmpegKit.executeAsync(command1, (s) async {
        final rc = await s.getReturnCode();
        print('[Cam1] Session finished with code: $rc');
      }),
      FFmpegKit.executeAsync(command2, (s) async {
        final rc = await s.getReturnCode();
        print('[Cam2] Session finished with code: $rc');
      }),
    ]);

    _captureSessions[1] = results[0];
    _captureSessions[2] = results[1];
  }

  // ── Saved-config helpers ───────────────────────────────────────────────────
  Future<bool> startCaptureWithSavedConfig(
    int ballNumber, {
    String? matchFolder,
    bool isReball = false,
    int reballIndex = 0,
  }) async {
    final config = await CameraConfigService().loadConfig();
    if (!config.isValid) {
      print('No valid camera configuration saved');
      return false;
    }
    await startCaptureWithConfig(config, ballNumber, matchFolder: matchFolder, isReball: isReball, reballIndex: reballIndex);
    return true;
  }

  Future<bool> startDualCaptureWithSavedConfig(
    int ballNumber, {
    String? matchFolder,
    bool isReball = false,
    int reballIndex = 0,
  }) async {
    final (config1, config2) = await CameraConfigService().loadDualConfig();
    if (!config1.isValid || !config2.isValid) {
      print('Invalid camera configurations');
      return false;
    }
    await startDualCapture(
      config1: config1,
      config2: config2,
      ballNumber: ballNumber,
      matchFolder: matchFolder,
      isReball: isReball,
      reballIndex: reballIndex,
    );
    return true;
  }

  // ── Stop capture ───────────────────────────────────────────────────────────
  /// Stops a single-camera session and returns its VideoClip.
  Future<VideoClip?> stopCapture({int cameraIndex = 1}) async {
    final session = _captureSessions.remove(cameraIndex);
    if (session != null) {
      await FFmpegKit.cancel(session.getSessionId());
    }

    final ballPath = _currentBallPaths.remove(cameraIndex);
    final clipId = _currentClipIds.remove(cameraIndex);

    if (ballPath == null || _recordingStartTime == null || clipId == null) {
      return null;
    }

    final duration =
        DateTime.now().difference(_recordingStartTime!).inSeconds;
    final file = File(ballPath);

    // Smart flush wait: exit as soon as the file stops growing (max 2 s)
    if (ballPath != null) await _waitForFileFlush(ballPath);

    if (await file.exists()) {
      final stats = await file.stat();
      
      // Validate clip: check minimum file size (50KB) to avoid grey clips
      const minimumClipSize = 50 * 1024; // 50KB - adjusted for short clips
      if (stats.size < minimumClipSize) {
        print('[Cam$cameraIndex] Discarding clip: file size (${stats.size} bytes) < minimum threshold ($minimumClipSize bytes)');
        await file.delete(); // Clean up invalid file
        if (_captureSessions.isEmpty) {
          _recordingStartTime = null;
          _currentBallName = null;
        }
        return null;
      }

      final clip = VideoClip(
        id: clipId,
        filename: ballPath.split('/').last,
        localPath: ballPath,
        s3Url: '',
        timestamp: DateTime.now(),
        duration: duration,
        isUploaded: false,
        ballNumber: _currentBallName ?? '0.0',
        size: stats.size,
        cameraIndex: cameraIndex,
        matchName: _currentMatchFolder,
        isReball: _isCurrentRecordingReball,
        reballIndex: _currentReballIndex,
      );

      if (_captureSessions.isEmpty) {
        _recordingStartTime = null;
        _currentBallName = null;
      }

      print('[Cam$cameraIndex] Successfully created clip: ${clip.filename}, size: ${(stats.size / 1024).toStringAsFixed(1)}KB');
      return clip;
    } else {
      print('[Cam$cameraIndex] File not found: $ballPath');
    }

    return null;
  }

  /// Stops all active sessions and returns a list of VideoClips (one per camera).
  Future<List<VideoClip>> stopDualCapture() async {
    final List<VideoClip> clips = [];

    // Cancel all active sessions in parallel
    final cancelFutures = _captureSessions.entries.map((entry) async {
      await FFmpegKit.cancel(entry.value.getSessionId());
    });
    await Future.wait(cancelFutures);
    _captureSessions.clear();

    if (_recordingStartTime == null) return clips;

    final duration =
        DateTime.now().difference(_recordingStartTime!).inSeconds;

    // Smart flush wait for both cameras in parallel (max 2 s each)
    final flushFutures = <Future>[];
    if (_currentBallPaths[1] != null) flushFutures.add(_waitForFileFlush(_currentBallPaths[1]!));
    if (_currentBallPaths[2] != null) flushFutures.add(_waitForFileFlush(_currentBallPaths[2]!));
    if (flushFutures.isNotEmpty) await Future.wait(flushFutures);

    // Collect camera 1 path and camera 2 path
    final path1 = _currentBallPaths[1];
    final path2 = _currentBallPaths[2];
    final clipId = _currentClipIds[1] ?? _currentClipIds[2] ?? const Uuid().v4();

    String? camera2Path;
    if (path2 != null) {
      final file2 = File(path2);
      if (await file2.exists()) {
        final stats2 = await file2.stat();
        const minimumClipSize = 50 * 1024; // 50KB - adjusted for short clips
        if (stats2.size < minimumClipSize) {
          print('[Cam2] Discarding clip: file size (${stats2.size} bytes) < minimum threshold ($minimumClipSize bytes)');
          await file2.delete(); // Clean up invalid file
        } else {
          camera2Path = path2;
        }
      }
    }

    if (path1 != null) {
      final file1 = File(path1);
      if (await file1.exists()) {
        final stats1 = await file1.stat();
        const minimumClipSize = 50 * 1024; // 50KB - adjusted for short clips
        if (stats1.size < minimumClipSize) {
          print('[Cam1] Discarding clip: file size (${stats1.size} bytes) < minimum threshold ($minimumClipSize bytes)');
          await file1.delete(); // Clean up invalid file
        } else {
          clips.add(VideoClip(
            id: clipId,
            filename: path1.split('/').last,
            localPath: path1,
            s3Url: '',
            timestamp: DateTime.now(),
            duration: duration,
            isUploaded: false,
            ballNumber: _currentBallName ?? '0.0',
            size: stats1.size,
            cameraIndex: 1,
            matchName: _currentMatchFolder,
            camera2Path: camera2Path,
            isReball: _isCurrentRecordingReball,
            reballIndex: _currentReballIndex,
          ));
          print('[DualCam] Successfully created clip: ${path1.split('/').last}, size: ${(stats1.size / 1024).toStringAsFixed(1)}KB');
          if (camera2Path != null) {
            final stats2 = await File(camera2Path!).stat();
            print('[DualCam] Camera 2 clip: ${camera2Path!.split('/').last}, size: ${(stats2.size / 1024).toStringAsFixed(1)}KB');
          }
        }
      } else {
        print('[Cam1] File not found: $path1');
      }
    }

    // Reset all state
    _currentBallPaths.clear();
    _currentClipIds.clear();
    _recordingStartTime = null;
    _currentBallName = null;

    return clips;
  }

  // ── Clip management ────────────────────────────────────────────────────────
  Future<List<String>> getAllMatchFolders() async {
    final recordingsDir = await _recordingsPath;
    final dir = Directory(recordingsDir);
    if (!await dir.exists()) return [];

    final folders = <String>[];
    final entities = dir.listSync();
    for (final entity in entities) {
      if (entity is Directory) {
        folders.add(entity.path.split('/').last);
      }
    }
    return folders;
  }

  Future<List<VideoClip>> getClipsFromFolder(String matchFolder) async {
    final matchPath = await getMatchFolderPath(matchFolder);
    final clipsDir = Directory('$matchPath/clips');
    final savedDir = Directory('$matchPath/Saved_Replays');
    
    final List<VideoClip> allClips = [];
    
    // Load from buffer (clips)
    if (await clipsDir.exists()) {
      allClips.addAll(await _loadClipsFromDirectory(clipsDir, matchFolder, isPermanent: false));
    }
    
    // Load from permanent storage
    if (await savedDir.exists()) {
      allClips.addAll(await _loadClipsFromDirectory(savedDir, matchFolder, isPermanent: true));
    }

    // Pair cam1 + cam2 clips that share the same UUID
    final Map<String, VideoClip> clipMap = {};
    for (final clip in allClips) {
      if (clipMap.containsKey(clip.id)) {
        final existing = clipMap[clip.id]!;
        if (clip.cameraIndex == 2) {
          clipMap[clip.id] = existing.copyWith(camera2Path: clip.localPath);
        } else if (existing.cameraIndex == 2) {
          clipMap[clip.id] = clip.copyWith(camera2Path: existing.localPath);
        }
      } else {
        clipMap[clip.id] = clip;
      }
    }

    final result = clipMap.values.toList();
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  Future<List<VideoClip>> _loadClipsFromDirectory(Directory directory, String matchFolder, {required bool isPermanent}) async {
    final List<VideoClip> clips = [];
    final files = directory.listSync();

    for (var file in files) {
      if (file is File && file.path.endsWith('.mp4')) {
        final stats = await file.stat();
        final name = file.path.split('/').last;

        // Filename format: 0.1_{uuid}_cam1.mp4 or 0.1_Reball_{index}_{uuid}_cam1.mp4
        // or 0.1_{uuid}_cam1_Saved1.mp4
        final parts = name.split('_');
        
        // Check if this is a reball clip
        bool isReball = false;
        int reballIndex = 0;
        int ballNameIndex = 0;
        int idIndex = 1;
        
        if (parts.length > 2 && parts[1] == 'Reball') {
          isReball = true;
          reballIndex = int.tryParse(parts[2]) ?? 0;
          ballNameIndex = 0;
          idIndex = 3;
        }
        
        final ballName = parts[ballNameIndex];
        final hasCamIndex = name.contains('_cam');

        int cameraIndex = 1;
        if (hasCamIndex) {
          // Extract cam number: find part starting with 'cam'
          for (var part in parts) {
            if (part.startsWith('cam')) {
              final camNumberStr = part.replaceAll('.mp4', '').replaceAll('cam', '');
              cameraIndex = int.tryParse(camNumberStr) ?? 1;
              break;
            }
          }
        }

        // Generate a stable ID based on the filename parts (excluding extension and camera index and "Saved" suffix)
        // This helps pairing cam1 and cam2 even if they are in different folders (though they shouldn't be)
        // parts format: [ball, uuid, camIndex, SavedX]
        String stableId;
        if (isReball) {
            stableId = parts.length > 3 ? parts[3] : const Uuid().v4();
        } else {
            stableId = parts.length > 1 ? parts[1] : const Uuid().v4();
        }
        
        // If it's a UUID, we are good.

        clips.add(VideoClip(
          id: stableId,
          filename: name,
          localPath: file.path,
          s3Url: '',
          timestamp: stats.modified,
          duration: 0,
          isUploaded: false,
          ballNumber: ballName,
          size: stats.size,
          cameraIndex: cameraIndex,
          matchName: matchFolder,
          isReball: isReball,
          reballIndex: reballIndex,
          isPermanent: isPermanent,
        ));
      }
    }
    return clips;
  }

  // ── Buffer management ──────────────────────────────────────────────────────
  String _extractBallName(String filename) => filename.split('_')[0];

  Set<String> _getUniqueBallNames(List<File> files) =>
      files.map((f) => _extractBallName(f.path.split('/').last)).toSet();

  List<File> _getFilesForBall(List<File> files, String ballName) => files
      .where((f) => _extractBallName(f.path.split('/').last) == ballName)
      .toList();

  Future<void> _manageBuffer(String clipsDir) async {
    final dir = Directory(clipsDir);
    if (!await dir.exists()) return;

    final clips = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.mp4'))
        .toList();

    final uniqueBalls = _getUniqueBallNames(clips);
    if (uniqueBalls.length < 6) return;

    final List<Map<String, dynamic>> ballInfo = [];
    for (final ballName in uniqueBalls) {
      final ballFiles = _getFilesForBall(clips, ballName);
      if (ballFiles.isNotEmpty) {
        final oldestTime = ballFiles
            .map((f) => f.statSync().modified)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        ballInfo.add({
          'ballName': ballName,
          'files': ballFiles,
          'oldestTime': oldestTime,
        });
      }
    }

    ballInfo.sort((a, b) => a['oldestTime'].compareTo(b['oldestTime']));

    final itemsToDelete = ballInfo.length - 5;
    for (int i = 0; i < itemsToDelete; i++) {
      final ballData = ballInfo[i];
      final ballName = ballData['ballName'] as String;
      final ballFiles = ballData['files'] as List<File>;
      for (final file in ballFiles) {
        print('[Buffer] Deleting oldest ball $ballName clip: ${file.path}');
        await file.delete();
      }
    }
  }

  String _getBallName(int ballNumber) {
    final over = (ballNumber - 1) ~/ 6;
    final ballInOver = ((ballNumber - 1) % 6) + 1;
    return '$over.$ballInOver';
  }

  // ── Status ─────────────────────────────────────────────────────────────────
  Future<BufferStatus> getBufferStatus() async {
    final clipsDir = await _getMatchClipsPath();
    final dir = Directory(clipsDir);

    int ballCount = 0;
    Set<String> uniqueBalls = {};

    if (await dir.exists()) {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp4'));
      uniqueBalls = _getUniqueBallNames(files.toList());
      ballCount = uniqueBalls.length;
    }

    return BufferStatus(
      totalBufferSize: 6,
      usedBufferSize: ballCount,
      percentageUsed: (ballCount / 6 * 100).toInt(),
      numberOfClips: ballCount,
      isRecording: _captureSessions.isNotEmpty,
      currentBall: _currentBallName ?? '0.0',
      isBufferFull: ballCount >= 6,
      lastUpdated: DateTime.now().toIso8601String(),
    );
  }

  Future<List<VideoClip>> getClips() async {
    if (_currentMatchFolder.isNotEmpty) {
      return getClipsFromFolder(_currentMatchFolder);
    }
    final clips = <VideoClip>[];
    final folders = await getAllMatchFolders();
    for (final folder in folders) {
      clips.addAll(await getClipsFromFolder(folder));
    }
    return clips;
  }

  Future<void> deleteClip(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Deletes the entire match folder (clips + Saved_Replays + any other contents).
  /// Returns true if the folder was found and deleted, false otherwise.
  Future<bool> deleteMatchFolder(String matchFolder) async {
    try {
      final recordingsDir = await _recordingsPath;
      final dir = Directory('$recordingsDir/$matchFolder');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        print('[Delete] Match folder deleted: $matchFolder');
        return true;
      }
      print('[Delete] Match folder not found: $matchFolder');
      return false;
    } catch (e) {
      print('[Delete] Error deleting match folder: $e');
      return false;
    }
  }

  /// True only when ALL configured cameras are actively recording.
  bool get isDualRecording =>
      _captureSessions.containsKey(1) && _captureSessions.containsKey(2);

  /// True when at least one camera is recording.
  bool get isRecording => _captureSessions.isNotEmpty;
}
