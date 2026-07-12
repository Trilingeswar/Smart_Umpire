import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/video_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/buffer_indicator.dart';
import '../widgets/animated_fab.dart';

class LivePreviewScreen extends StatefulWidget {
  const LivePreviewScreen({Key? key}) : super(key: key);

  @override
  State<LivePreviewScreen> createState() => _LivePreviewScreenState();
}

class _LivePreviewScreenState extends State<LivePreviewScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  int _refreshKey = 0;       // Incremented to force Video widget teardown
  bool _isRefreshing = false; // Shows loading overlay during reconnect

  // Separate VideoControllers per camera — prevents shared-surface black screens
  final Map<int, VideoController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Initialise preview players after the first frame so the provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPreviews();
    });
  }

  Future<void> _initPreviews() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);

    try {
      final provider = context.read<VideoProvider>();

      // Dispose old controllers before reinitialising players
      await provider.initializePreviewPlayers();

      // Increment key — forces every Video widget to be fully recreated
      // (new rendering surface, new texture) rather than reusing the stale one.
      _videoControllers.clear();
      for (int camIdx in [1, 2]) {
        final player = provider.getPreviewPlayer(camIdx);
        if (player != null) {
          _videoControllers[camIdx] = VideoController(player);
        }
      }

      if (mounted) {
        setState(() {
          _refreshKey++; // Key change forces Video widget rebuild
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // VideoControllers don't need explicit disposal — Players are owned by provider
    super.dispose();
  }

  List<Widget> _buildActionButtons(VideoProvider provider) {
    // If the match is completely over
    if (provider.isMatchOver) {
      return [
        Expanded(
          child: AnimatedFAB(
            onPressed: () => _showEndMatchConfirmation(context, provider),
            icon: Icons.flag,
            label: 'MATCH OVER',
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            size: FABSize.large,
          ),
        ),
      ];
    }

    // If the current innings is over but match is not
    if (provider.isInningsOver) {
      return [
        Expanded(
          child: AnimatedFAB(
            onPressed: () => provider.switchToNextInnings(),
            icon: Icons.swap_horiz,
            label: 'NEXT INNINGS',
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            size: FABSize.large,
          ),
        ),
      ];
    }

    return [
      Expanded(
        flex: 3,
        child: AnimatedFAB(
          onPressed: provider.isRecording
              ? () => provider.stopRecording()
              : () => provider.startRecording(),
          icon: provider.isRecording ? Icons.stop : Icons.fiber_manual_record,
          label: provider.isRecording ? 'STOP' : 'REC',
          backgroundColor: provider.isRecording
              ? AppTheme.accentColor
              : AppTheme.primaryColor,
          foregroundColor: Colors.white,
          size: FABSize.large,
        ),
      ),
      const SizedBox(width: AppTheme.spacingSM),
      Expanded(
        flex: 2,
        child: AnimatedFAB(
          onPressed: provider.canReball
              ? () => _showReballConfirmation(context, provider)
              : null,
          icon: Icons.replay,
          label: provider.isRecording ? '...' : 'REBALL',
          backgroundColor: provider.canReball
              ? Colors.amber
              : Colors.grey,
          foregroundColor: Colors.black,
          size: FABSize.large,
        ),
      ),
    ];
  }

  void _showReballConfirmation(BuildContext context, VideoProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Confirm Reball',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to reball?',
          style: GoogleFonts.montserrat(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'NO',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: AppTheme.neutralColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.startRecording(isReball: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
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
  }

  void _showEndMatchConfirmation(BuildContext context, VideoProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            const Icon(Icons.flag, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'End Match',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end this match? You will be taken back to the setup screen.',
          style: GoogleFonts.montserrat(
            color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'CANCEL',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.endMatch();
            },
            icon: const Icon(Icons.flag, size: 18),
            label: Text(
              'END MATCH',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInningsOverlay(VideoProvider provider) {
    final matchDetails = provider.matchDetails;
    if (matchDetails == null) return const SizedBox.shrink();

    final innings = provider.currentInnings;
    final overBall = provider.currentOverBall;
    final totalOvers = matchDetails.numberOfOvers;
    final isInningsOver = provider.isInningsOver;
    final isMatchOver = provider.isMatchOver;

    String statusText;
    Color statusColor;
    if (isMatchOver) {
      statusText = 'Match Over';
      statusColor = Colors.green;
    } else if (isInningsOver) {
      statusText = 'Innings $innings Complete';
      statusColor = Colors.orange;
    } else {
      statusText = 'Innings $innings  •  $overBall / $totalOvers overs';
      statusColor = AppTheme.primaryColor;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.85),
            statusColor.withOpacity(0.65),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMatchOver
                  ? Icons.flag
                  : isInningsOver
                      ? Icons.swap_horiz
                      : Icons.sports_cricket,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            if (!isMatchOver && !isInningsOver) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  '${matchDetails.team1Name} vs ${matchDetails.team2Name}',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, end: 0.0, duration: 400.ms);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, provider, _) {
        final hasDual = provider.matchDetails?.hasDualCameras ?? false;
        final hasIpCamera =
            provider.matchDetails?.cameraIp.isNotEmpty ?? false;

        // Auto-trigger reball if requested from review screen
        if (provider.shouldAutoReball) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (provider.shouldAutoReball) { // Double check
              provider.clearAutoReball();
              provider.startRecording(isReball: true);
            }
          });
        }

        return Stack(
          children: [
            // ── Preview Area ─────────────────────────────────────────────
            Positioned.fill(
              child: hasIpCamera
                  ? _buildPreviewArea(provider, hasDual)
                  : _buildDeviceCameraPreview(provider),
            ),

            // ── Overlays ─────────────────────────────────────────────────
            Column(
              children: [
                // Innings & Over status banner
                _buildInningsOverlay(provider),

                // Buffer Status
                const BufferIndicator()
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 200.ms)
                    .slideY(
                        begin: -0.2, end: 0.0, duration: 600.ms, delay: 200.ms),

                const Spacer(),

                // Controls
                SafeArea(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMD,
                        vertical: AppTheme.spacingSM),
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: AppTheme.getCardDecoration(context).copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Main Action Buttons - Record + Reball
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _buildActionButtons(provider),
                        ),

                        const SizedBox(height: AppTheme.spacingMD),

                        // Secondary Actions Row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isRefreshing ? null : () => _initPreviews(),
                                icon: _isRefreshing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primaryColor,
                                        ),
                                      )
                                    : const Icon(Icons.refresh, size: 18),
                                label: Text(
                                  _isRefreshing ? 'Connecting...' : 'Refresh Preview',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingMD,
                                    vertical: AppTheme.spacingSM,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusMD),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingSM),
                            // End Match button
                            OutlinedButton.icon(
                              onPressed: () => _showEndMatchConfirmation(context, provider),
                              icon: const Icon(Icons.flag, size: 18, color: Colors.red),
                              label: Text('End Match',
                                  style: TextStyle(fontSize: 14, color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingMD,
                                  vertical: AppTheme.spacingSM,
                                ),
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMD),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 600.ms).slideY(
                    begin: 0.3, end: 0.0, duration: 600.ms, delay: 600.ms),
              ],
            ),
          ],
        );
      },
    );
  }

  // ── Preview builders ───────────────────────────────────────────────────────

  /// Builds the preview area: single or dual depending on configuration.
  Widget _buildPreviewArea(VideoProvider provider, bool hasDual) {
    if (!hasDual) {
      // Single camera — full screen
      return _buildCameraView(1);
    }

    // Dual camera — split screen (vertical on portrait, horizontal on landscape)
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return isLandscape
        ? Row(
            children: [
              Expanded(child: _buildCameraView(1)),
              const SizedBox(width: 2),
              Expanded(child: _buildCameraView(2)),
            ],
          )
        : Column(
            children: [
              Expanded(child: _buildCameraView(1)),
              const SizedBox(height: 2),
              Expanded(child: _buildCameraView(2)),
            ],
          );
  }

  /// Renders a single camera's live preview using its isolated VideoController.
  Widget _buildCameraView(int cameraIndex) {
    final controller = _videoControllers[cameraIndex];

    if (controller == null) {
      return _buildLoadingState('Connecting to Camera $cameraIndex…');
    }

    return Stack(
      // Key change forces Flutter to fully destroy and recreate the
      // Video widget (new GPU texture) instead of reusing the stale surface.
      key: ValueKey('cam_${cameraIndex}_$_refreshKey'),
      fit: StackFit.expand,
      children: [
        Video(
          controller: controller,
          controls: NoVideoControls,
          fit: BoxFit.cover,
        ),
        // Camera label badge
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  'CAM $cameraIndex',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCameraPreview(VideoProvider provider) {
    if (!provider.cameraService.isInitialized) {
      return _buildLoadingState('Initializing Camera…');
    }
    final controller = provider.cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoadingState('Initializing Camera…');
    }

    // Device camera uses the camera package — unchanged
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: controller.buildPreview(),
    );
  }

  Widget _buildLoadingState(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
