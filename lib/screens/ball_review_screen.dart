import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../models/video_clip.dart';
import '../providers/video_provider.dart';
import '../theme/app_theme.dart';

class BallReviewScreen extends StatefulWidget {
  final VideoClip clip;

  const BallReviewScreen({Key? key, required this.clip}) : super(key: key);

  @override
  State<BallReviewScreen> createState() => _BallReviewScreenState();
}

class _BallReviewScreenState extends State<BallReviewScreen> {
  // Action state
  bool _isSaving = false;
  bool _isExporting = false;

  // Camera 1 player
  late final Player _player1;
  late final VideoController _videoController1;

  // Camera 2 player (for split-screen)
  Player? _player2;
  VideoController? _videoController2;

  bool _isLoading = true;
  int _selectedCameraIndex = 1;

  // Split-screen mode
  bool _isSplitScreen = false;
  bool get _hasDualCameras => widget.clip.camera2Path != null;

  // Playback controls
  double _currentSpeed = 1.0;
  final List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // Seeking state
  bool _isDragging = false;
  double _dragValue = 0.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Sync lock for dual players
  bool _isSeeking = false;

  // Full-screen mode
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _selectedCameraIndex = widget.clip.cameraIndex;
    _initializePlayer();
  }

  @override
  void dispose() {
    // Restore system UI if disposed while full-screen
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    _player1.dispose();
    _player2?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      // Create player 1 with optimized settings for smooth playback
      _player1 = Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.warn,
          // Hardware acceleration for smoother playback
          // Force hardware decoding if available
        ),
      );
      _videoController1 = VideoController(_player1);

      // Apply optimized playback properties for smooth, high-quality local clip playback
      final mpv1 = _player1.platform as dynamic;
      await mpv1.setProperty('hwdec', 'auto-safe');          // Hardware decoding (safe mode for Android)
      await mpv1.setProperty('vd-lavc-dr', 'yes');           // Direct rendering: skip a GPU copy per frame
      await mpv1.setProperty('framedrop', 'no');             // Never drop frames during review
      await mpv1.setProperty('video-sync', 'display-resample'); // Tear-free, display-synced playback
      await mpv1.setProperty('interpolation', 'yes');        // Smooth motion between frames
      await mpv1.setProperty('audio', 'no');                 // No audio track
      await mpv1.setProperty('cache', 'yes');                // Enable packet cache for local file
      await mpv1.setProperty('demuxer-readahead-secs', '8'); // Pre-buffer 8s for smooth seeking
      await mpv1.setProperty('demuxer-max-bytes', '52428800'); // 50 MB packet cache
      await mpv1.setProperty('demuxer-max-back-bytes', '10485760'); // 10 MB back-buffer for rewind

      // Listen to position updates from player 1 (master)
      _player1.stream.position.listen((pos) {
        if (mounted && !_isDragging && !_isSeeking) {
          setState(() => _position = pos);
        }
      });

      // Listen to duration updates
      _player1.stream.duration.listen((dur) {
        if (mounted) {
          setState(() => _duration = dur);
        }
      });

      // Listen for playing state
      _player1.stream.playing.listen((playing) {
        if (mounted) setState(() {});
      });

      // Use 'file://' prefix so media_kit skips network-path heuristics
      // and goes directly to the local file reader — saves ~150 ms per open.
      final localUri1 = _toFileUri(widget.clip.localPath);

      // Open both players IN PARALLEL when dual cameras are available
      if (_hasDualCameras) {
        await Future.wait([
          _player1.open(Media(localUri1)),
          _initializePlayer2(),
        ]);
      } else {
        await _player1.open(Media(localUri1));
      }
      await _player1.pause();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading video: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  /// Converts an absolute file path to a 'file://' URI string.
  /// media_kit resolves local paths much faster with an explicit scheme.
  String _toFileUri(String path) {
    // Standardize to forward slashes for URI compatibility
    final normalized = path.replaceAll('\\', '/');
    // On Android the path begins with '/'
    if (normalized.startsWith('/')) return 'file://$normalized';
    // Windows-style paths 'C:/...' — use three slashes
    return 'file:///$normalized';
  }

  Future<void> _initializePlayer2() async {
    if (widget.clip.camera2Path == null) return;

    _player2 = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
      ),
    );
    _videoController2 = VideoController(_player2!);

    // Apply same optimized settings to player 2
    final mpv2 = _player2!.platform as dynamic;
    await mpv2.setProperty('hwdec', 'auto-safe');          // Hardware decoding (safe mode)
    await mpv2.setProperty('vd-lavc-dr', 'yes');           // Direct rendering
    await mpv2.setProperty('framedrop', 'no');             // Never drop frames
    await mpv2.setProperty('video-sync', 'display-resample'); // Tear-free sync
    await mpv2.setProperty('interpolation', 'yes');        // Smooth motion
    await mpv2.setProperty('audio', 'no');                 // No audio
    await mpv2.setProperty('cache', 'yes');                // Enable packet cache
    await mpv2.setProperty('demuxer-readahead-secs', '8'); // 8s pre-buffer
    await mpv2.setProperty('demuxer-max-bytes', '52428800'); // 50 MB cache
    await mpv2.setProperty('demuxer-max-back-bytes', '10485760'); // 10 MB back-buffer

    final localUri2 = _toFileUri(widget.clip.camera2Path!);

    // Open camera 2 video using file:// URI for fast local resolution
    await _player2!.open(Media(localUri2));
    await _player2!.pause();

    // Sync speed with player 1
    await _player2!.setRate(_currentSpeed);
  }

  Future<void> _switchToCamera(int cameraIndex) async {
    if (cameraIndex == _selectedCameraIndex) return;
    if (_isSplitScreen) return; // No switching in split-screen mode

    setState(() {
      _isLoading = true;
      _selectedCameraIndex = cameraIndex;
    });

    // Determine new video path and convert to file:// URI for fast open
    String videoPath;
    if (cameraIndex == 2 && widget.clip.camera2Path != null) {
      videoPath = _toFileUri(widget.clip.camera2Path!);
    } else {
      videoPath = _toFileUri(widget.clip.localPath);
    }

    await _player1.open(Media(videoPath));
    await _player1.pause();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Toggle split-screen mode
  Future<void> _toggleSplitScreen() async {
    if (!_hasDualCameras) return;

    setState(() {
      _isSplitScreen = !_isSplitScreen;
    });

    if (_isSplitScreen) {
      // Entering split-screen: open both players in parallel using file:// URIs
      final open1 = _player1.open(Media(_toFileUri(widget.clip.localPath)));

      Future<void> open2Future;
      if (_player2 == null) {
        open2Future = _initializePlayer2();
      } else {
        open2Future = _player2!
            .open(Media(_toFileUri(widget.clip.camera2Path!)))
            .then((_) => _player2!.pause());
      }

      await Future.wait([open1, open2Future]);
      await _player1.pause();

      // Sync both to start
      await _syncSeek(Duration.zero);
    } else {
      // Exiting split-screen: switch back to selected camera
      await _switchToCamera(_selectedCameraIndex);
    }
  }

  /// Synchronized seek for both players
  Future<void> _syncSeek(Duration position) async {
    _isSeeking = true;
    await _player1.seek(position);
    if (_isSplitScreen && _player2 != null) {
      await _player2!.seek(position);
    }
    _isSeeking = false;
  }

  /// Synchronized play/pause
  Future<void> _syncPlayOrPause() async {
    if (_player1.state.playing) {
      await _player1.pause();
      if (_isSplitScreen && _player2 != null) {
        await _player2!.pause();
      }
    } else {
      await _player1.play();
      if (_isSplitScreen && _player2 != null) {
        await _player2!.play();
      }
    }
  }

  /// Step forward by milliseconds (frame-by-frame)
  Future<void> _stepForward(int milliseconds) async {
    // Pause first for precise stepping
    if (_player1.state.playing) {
      await _player1.pause();
      if (_isSplitScreen && _player2 != null) {
        await _player2!.pause();
      }
    }
    final newPos = _position + Duration(milliseconds: milliseconds);
    final clampedPos = newPos > _duration ? _duration : newPos;
    await _syncSeek(clampedPos);
  }

  /// Step backward by milliseconds (frame-by-frame)
  Future<void> _stepBackward(int milliseconds) async {
    // Pause first for precise stepping
    if (_player1.state.playing) {
      await _player1.pause();
      if (_isSplitScreen && _player2 != null) {
        await _player2!.pause();
      }
    }
    final newPos = _position - Duration(milliseconds: milliseconds);
    final clampedPos = newPos < Duration.zero ? Duration.zero : newPos;
    await _syncSeek(clampedPos);
  }

  /// Set playback speed (synced)
  Future<void> _setSpeed(double speed) async {
    await _player1.setRate(speed);
    if (_isSplitScreen && _player2 != null) {
      await _player2!.setRate(speed);
    }
    setState(() => _currentSpeed = speed);
  }

  /// Enter / exit full-screen mode
  Future<void> _toggleFullScreen() async {
    if (_isFullScreen) {
      // Exit full-screen
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      setState(() => _isFullScreen = false);
    } else {
      // Enter full-screen: immersive landscape
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      setState(() => _isFullScreen = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Full-screen mode: bare black screen with only the video + close button
    if (_isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video fills entire screen
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                panEnabled: true,
                scaleEnabled: true,
                child: Video(
                  controller: _videoController1,
                  controls: NoVideoControls,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Thin seek slider at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildFullScreenControls(),
            ),

            // Exit full-screen button (top-right)
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: _toggleFullScreen,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 26),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Normal mode
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.black.withOpacity(0.95),
              Theme.of(context).colorScheme.surface,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? _buildLoadingView()
                  : _buildVideoPlayerView(),
            ),
            _buildAnalysisPanel(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.of(context).pop(),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .scaleXY(begin: 0.8, end: 1.0, duration: 300.ms),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isSplitScreen ? 'Split-Screen Review' : 'Ball Review',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.clip.ballNumber,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              if (widget.clip.isPermanent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'SAVED',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 400.ms, delay: 100.ms)
          .slideX(begin: -0.2, end: 0.0, duration: 400.ms, delay: 100.ms),
      actions: [
        // Split-screen toggle button
        if (_hasDualCameras)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isSplitScreen
                    ? AppTheme.primaryColor.withOpacity(0.8)
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: _isSplitScreen
                    ? Border.all(color: AppTheme.primaryColor, width: 2)
                    : null,
              ),
              child: Icon(
                Icons.view_column,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: _toggleSplitScreen,
            tooltip: _isSplitScreen ? 'Exit Split-Screen' : 'Split-Screen View',
          )
              .animate()
              .fadeIn(duration: 300.ms, delay: 150.ms)
              .scaleXY(begin: 0.8, end: 1.0, duration: 300.ms, delay: 150.ms),
        // Full-screen button
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
          ),
          onPressed: _isLoading ? null : _toggleFullScreen,
          tooltip: 'Full-Screen',
        )
            .animate()
            .fadeIn(duration: 300.ms, delay: 175.ms)
            .scaleXY(begin: 0.8, end: 1.0, duration: 300.ms, delay: 175.ms),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: const Icon(Icons.ios_share, color: Colors.white),
          ),
          onPressed: _isExporting ? null : _exportToGallery,
          tooltip: 'Export to Gallery',
        )
            .animate()
            .fadeIn(duration: 300.ms, delay: 200.ms)
            .scaleXY(begin: 0.8, end: 1.0, duration: 300.ms, delay: 200.ms),
      ],
    );
  }

  /// Compact controls shown at the bottom of the full-screen view
  Widget _buildFullScreenControls() {
    double sliderValue;
    if (_isDragging) {
      sliderValue = _dragValue;
    } else if (_duration.inMilliseconds > 0) {
      sliderValue = _position.inMilliseconds / _duration.inMilliseconds;
    } else {
      sliderValue = 0.0;
    }
    sliderValue = sliderValue.clamp(0.0, 1.0);

    String _fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time labels
          Row(
            children: [
              Text(
                _fmt(_position),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const Spacer(),
              Text(
                _fmt(_duration),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          // Seek slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: Colors.white24,
              thumbColor: AppTheme.primaryColor,
              overlayColor: AppTheme.primaryColor.withOpacity(0.3),
            ),
            child: Slider(
              value: sliderValue,
              onChangeStart: (v) => setState(() { _isDragging = true; _dragValue = v; }),
              onChanged: (v) {
                setState(() => _dragValue = v);
                _syncSeek(Duration(milliseconds: (v * _duration.inMilliseconds).round()));
              },
              onChangeEnd: (v) {
                _syncSeek(Duration(milliseconds: (v * _duration.inMilliseconds).round()));
                setState(() => _isDragging = false);
              },
            ),
          ),
          // Play/Pause + step row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_5, color: Colors.white, size: 28),
                onPressed: () => _stepBackward(5000),
                tooltip: 'Rewind 5s',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28),
                onPressed: () => _stepBackward(33),
                tooltip: 'Previous Frame',
              ),
              const SizedBox(width: 8),
              // Play / Pause
              GestureDetector(
                onTap: _syncPlayOrPause,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: StreamBuilder<bool>(
                    stream: _player1.stream.playing,
                    initialData: _player1.state.playing,
                    builder: (_, snap) => Icon(
                      (snap.data ?? false) ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                onPressed: () => _stepForward(33),
                tooltip: 'Next Frame',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.forward_5, color: Colors.white, size: 28),
                onPressed: () => _stepForward(5000),
                tooltip: 'Forward 5s',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveBallReplay() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    
    // Show saving toast/snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
            ),
            SizedBox(width: 12),
            Text('Saving replay to match folder...'),
          ],
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 1),
      ),
    );

    final success = await context.read<VideoProvider>().saveClip(widget.clip);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save replay.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
          ),
        );
      }
    }
  }

  Future<void> _exportToGallery() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);
    
    // Show exporting toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
            ),
            SizedBox(width: 12),
            Text('Exporting to Gallery (Movies/SmartUmpire)...'),
          ],
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
      ),
    );

    final success = await context.read<VideoProvider>().exportClip(widget.clip);

    if (mounted) {
      setState(() => _isExporting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Exported to Gallery successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to export. Check permissions.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
          ),
        );
      }
    }
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.3),
                  AppTheme.primaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(
              Icons.videocam,
              color: AppTheme.primaryColor,
              size: 40,
            ),
          )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(delay: 800.ms, duration: 800.ms),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            'Loading video...',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
          const SizedBox(height: AppTheme.spacingMD),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 600.ms)
              .scaleXY(begin: 0.5, end: 1.0, duration: 400.ms, delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerView() {
    return Column(
      children: [
        // Video Display - Single or Split-Screen
        Expanded(
          child: _isSplitScreen ? _buildSplitScreenView() : _buildSingleVideoView(),
        ),

        // Enhanced Video Controls
        _buildVideoControls(),
      ],
    );
  }

  /// Single video view with pinch-to-zoom
  Widget _buildSingleVideoView() {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              panEnabled: true,
              scaleEnabled: true,
              child: Video(
                controller: _videoController1,
                controls: NoVideoControls,
              ),
            ),
            // Camera indicator overlay
            Positioned(
              top: AppTheme.spacingSM,
              right: AppTheme.spacingSM,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSM,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  'Camera $_selectedCameraIndex',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Full-screen expand button (bottom-right of video)
            Positioned(
              bottom: AppTheme.spacingSM,
              right: AppTheme.spacingSM,
              child: GestureDetector(
                onTap: _toggleFullScreen,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 300.ms).scaleXY(
        begin: 0.9,
        end: 1.0,
        duration: 600.ms,
        delay: 300.ms,
        curve: Curves.easeOutCubic);
  }

  /// Split-screen view showing both cameras side-by-side
  Widget _buildSplitScreenView() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingSM),
      child: isLandscape
          ? Row(
              children: [
                Expanded(child: _buildCameraPanel(1, _videoController1)),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(child: _buildCameraPanel(2, _videoController2)),
              ],
            )
          : Column(
              children: [
                Expanded(child: _buildCameraPanel(1, _videoController1)),
                const SizedBox(height: AppTheme.spacingSM),
                Expanded(child: _buildCameraPanel(2, _videoController2)),
              ],
            ),
    ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.95, end: 1.0, duration: 500.ms);
  }

  /// Individual camera panel for split-screen
  Widget _buildCameraPanel(int cameraIndex, VideoController? controller) {
    if (controller == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: Center(
          child: Text(
            'Camera $cameraIndex\nNot Available',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Stack(
          children: [
            // Video with pinch-to-zoom
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              panEnabled: true,
              scaleEnabled: true,
              child: Video(
                controller: controller,
                controls: NoVideoControls,
              ),
            ),
            // Camera label
            Positioned(
              top: AppTheme.spacingXS,
              left: AppTheme.spacingXS,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSM,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.9),
                      AppTheme.primaryColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'CAM $cameraIndex',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    // Calculate slider value
    double sliderValue;
    if (_isDragging) {
      sliderValue = _dragValue;
    } else if (_duration.inMilliseconds > 0) {
      sliderValue = _position.inMilliseconds / _duration.inMilliseconds;
    } else {
      sliderValue = 0.0;
    }
    sliderValue = sliderValue.clamp(0.0, 1.0);

    final previewPosition = _isDragging
        ? Duration(milliseconds: (_dragValue * _duration.inMilliseconds).round())
        : _position;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD, // Reduced from LG (24) to MD (16)
        vertical: AppTheme.spacingMD,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.95),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusLG),
          topRight: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Split-screen indicator
          if (_isSplitScreen)
            Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.3),
                    AppTheme.primaryColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sync, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Synced Playback',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // Seek Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8,
                elevation: 4,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: Colors.white.withOpacity(0.2),
              thumbColor: AppTheme.primaryColor,
              overlayColor: AppTheme.primaryColor.withOpacity(0.3),
            ),
            child: Slider(
              value: sliderValue,
              onChangeStart: (value) {
                setState(() {
                  _isDragging = true;
                  _dragValue = value;
                });
              },
              onChanged: (value) {
                setState(() {
                  _dragValue = value;
                });
                // Seek while dragging for smooth preview
                final newPos = Duration(
                  milliseconds: (value * _duration.inMilliseconds).round(),
                );
                _syncSeek(newPos);
              },
              onChangeEnd: (value) {
                final newPos = Duration(
                  milliseconds: (value * _duration.inMilliseconds).round(),
                );
                _syncSeek(newPos);
                setState(() {
                  _isDragging = false;
                });
              },
            ),
          ),

          const SizedBox(height: AppTheme.spacingSM),

          // Control Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous Frame (33ms step for ~30fps precision)
              _buildControlButton(
                icon: Icons.skip_previous,
                tooltip: 'Previous Frame',
                onPressed: () => _stepBackward(33),
              ),

              // Rewind 5s
              _buildControlButton(
                icon: Icons.replay_5,
                tooltip: 'Rewind 5s',
                onPressed: () => _stepBackward(5000),
              ),

              // Play/Pause Button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _player1.state.playing ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _syncPlayOrPause,
                  tooltip: _player1.state.playing ? 'Pause' : 'Play',
                  iconSize: 40,
                ),
              ),

              // Forward 5s
              _buildControlButton(
                icon: Icons.forward_5,
                tooltip: 'Forward 5s',
                onPressed: () => _stepForward(5000),
              ),

              // Next Frame (33ms step for ~30fps precision)
              _buildControlButton(
                icon: Icons.skip_next,
                tooltip: 'Next Frame',
                onPressed: () => _stepForward(33),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingSM),

          // Time Display + Speed Control
          // Time Display + Speed Control + Reball
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Time Display
              Flexible(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSM, // Reduced from MD
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? AppTheme.primaryColor.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_formatDuration(previewPosition)} / ${_formatDuration(_duration)}',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: AppTheme.spacingXS),

              // Speed Control Button
              Flexible(
                flex: 2,
                child: GestureDetector(
                  onTap: _showSpeedSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM, // Reduced from MD
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.3),
                          AppTheme.primaryColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.speed, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${_currentSpeed}x',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: AppTheme.spacingXS),

              // Reball Button
              Flexible(
                flex: 3,
                child: GestureDetector(
                  onTap: () async {
                    // Show confirmation dialog (kept dialog as requested)
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                        ),
                        title: Text(
                          'Confirm Reball',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        content: Text(
                          'Are you sure want to reball?',
                          style: GoogleFonts.montserrat(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(
                              'NO',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              ),
                            ),
                            child: Text(
                              'YES',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && mounted) {
                      final provider = context.read<VideoProvider>();
                      provider.shouldAutoReball = true;
                      Navigator.of(context).pop('reball');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM, // Reduced from MD
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.withOpacity(0.3),
                          Colors.amber.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.replay, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Reball',
                            style: GoogleFonts.montserrat(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 500.ms)
        .slideY(begin: 0.3, end: 0.0, duration: 500.ms, delay: 500.ms);
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 28,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }

  void _showSpeedSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusXL),
            topRight: Radius.circular(AppTheme.radiusXL),
          ),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              'Playback Speed',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Wrap(
              spacing: AppTheme.spacingSM,
              runSpacing: AppTheme.spacingSM,
              children: _speedOptions.map((speed) {
                final isSelected = speed == _currentSpeed;
                return GestureDetector(
                  onTap: () {
                    _setSpeed(speed);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMD,
                      vertical: AppTheme.spacingSM,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.primaryColor.withOpacity(0.8),
                              ],
                            )
                          : null,
                      color: isSelected ? null : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.white.withOpacity(0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '${speed}x',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spacingLG),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisPanel() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusXL),
          topRight: Radius.circular(AppTheme.radiusXL),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ball Info
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLG,
                    vertical: AppTheme.spacingSM,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.8)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                  ),
                  child: Text(
                    widget.clip.ballNumber,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.clip.duration}s duration',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _isSplitScreen
                            ? 'Split-Screen Mode'
                            : 'Camera $_selectedCameraIndex',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Save Button
                IconButton(
                  onPressed: (_isSaving || widget.clip.isPermanent) ? null : _saveBallReplay,
                  icon: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(widget.clip.isPermanent ? Icons.check_circle : Icons.save_alt),
                  tooltip: widget.clip.isPermanent ? 'Permanently Saved' : 'Save to Match',
                  color: widget.clip.isPermanent ? Colors.green : AppTheme.primaryColor,
                ),
                // Export Button
                IconButton(
                  onPressed: _isExporting ? null : _exportToGallery,
                  icon: _isExporting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ios_share),
                  tooltip: 'Export to Gallery',
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingLG),

          // Camera Selection (only show when not in split-screen)
          if (!_isSplitScreen) _buildCameraSelectionPanel(),
        ],
      ),
    );
  }

  Widget _buildCameraSelectionPanel() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.videocam,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Expanded(
                child: Text(
                  'Select Camera Source',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hasDualCameras)
                Flexible(
                  child: TextButton.icon(
                    onPressed: _toggleSplitScreen,
                    icon: const Icon(Icons.view_column, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Split View',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSM,
                        vertical: AppTheme.spacingXS,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _hasDualCameras
              ? _buildCameraDropdown()
              : Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.videocam,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Text(
                        'Recorded from Camera ${widget.clip.cameraIndex}',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCameraDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedCameraIndex,
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          borderSide: BorderSide(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMD,
          vertical: AppTheme.spacingSM,
        ),
      ),
      icon: Icon(Icons.camera_alt, color: AppTheme.primaryColor),
      style: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      items: const [
        DropdownMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.videocam, size: 18),
              SizedBox(width: 8),
              Text('Camera 1'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: 2,
          child: Row(
            children: [
              Icon(Icons.videocam, size: 18),
              SizedBox(width: 8),
              Text('Camera 2'),
            ],
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null && value != _selectedCameraIndex) {
          _switchToCamera(value);
        }
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final millis = (duration.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$millis';
  }

}
