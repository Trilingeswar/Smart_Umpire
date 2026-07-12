import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class VideoControls extends StatefulWidget {
  final VideoPlayerController controller;

  const VideoControls({Key? key, required this.controller}) : super(key: key);

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls>
    with TickerProviderStateMixin {
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  
  // Playback speed options
  final List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  double _currentSpeed = 1.0;
  
  // For slider seeking - preview position while dragging
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _wasPlayingBeforeDrag = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateState);

    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _controlsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controlsAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Set optimal playback settings for smoothness
    widget.controller.setVolume(1.0);
    widget.controller.setLooping(false);

    // Start animation
    _controlsAnimationController.forward();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    _controlsAnimationController.dispose();
    super.dispose();
  }

  void _updateState() {
    if (mounted && !_isDragging) {
      setState(() {});
    }
  }

  /// Step backward by specified milliseconds with forced frame update
  Future<void> _stepBackward(int milliseconds) async {
    final currentPosition = widget.controller.value.position;
    final newPosition = currentPosition - Duration(milliseconds: milliseconds);
    final clampedPosition = newPosition < Duration.zero ? Duration.zero : newPosition;
    
    await _seekAndForceRender(clampedPosition);
  }

  /// Step forward by specified milliseconds with forced frame update
  Future<void> _stepForward(int milliseconds) async {
    final currentPosition = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final newPosition = currentPosition + Duration(milliseconds: milliseconds);
    final clampedPosition = newPosition > duration ? duration : newPosition;
    
    await _seekAndForceRender(clampedPosition);
  }

  /// Seek to position and force the video player to render the frame
  /// by briefly playing then pausing
  Future<void> _seekAndForceRender(Duration position) async {
    // Store current playing state
    final wasPlaying = widget.controller.value.isPlaying;
    
    // Seek to position
    await widget.controller.seekTo(position);
    
    // Force frame render: briefly play then pause
    if (!wasPlaying) {
      await widget.controller.play();
      await Future.delayed(const Duration(milliseconds: 20));
      await widget.controller.pause();
    }
    
    if (mounted) setState(() {});
  }

  /// Set playback speed
  void _setPlaybackSpeed(double speed) {
    setState(() {
      _currentSpeed = speed;
    });
    widget.controller.setPlaybackSpeed(speed);
  }

  /// Show speed selection popup
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
                    _setPlaybackSpeed(speed);
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

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    
    // Calculate slider value
    double sliderValue;
    if (_isDragging) {
      sliderValue = _dragValue;
    } else if (duration.inMilliseconds > 0) {
      sliderValue = position.inMilliseconds / duration.inMilliseconds;
    } else {
      sliderValue = 0.0;
    }
    sliderValue = sliderValue.clamp(0.0, 1.0);
    
    // Calculate preview time when dragging
    final previewPosition = _isDragging
        ? Duration(milliseconds: (_dragValue * duration.inMilliseconds).round())
        : position;

    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _controlsAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _controlsAnimation.value)),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLG,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seek Slider - only seeks on release for reliability
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
                        _wasPlayingBeforeDrag = widget.controller.value.isPlaying;
                        if (_wasPlayingBeforeDrag) {
                          widget.controller.pause();
                        }
                        setState(() {
                          _isDragging = true;
                          _dragValue = value;
                        });
                      },
                      onChanged: (value) {
                        // Only update UI preview, don't seek yet
                        setState(() {
                          _dragValue = value;
                        });
                      },
                      onChangeEnd: (value) async {
                        // Seek only on release
                        final newPosition = Duration(
                          milliseconds: (value * duration.inMilliseconds).round(),
                        );
                        
                        await widget.controller.seekTo(newPosition);
                        
                        // Resume if was playing before
                        if (_wasPlayingBeforeDrag) {
                          await widget.controller.play();
                        }
                        
                        if (mounted) {
                          setState(() {
                            _isDragging = false;
                          });
                        }
                      },
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms).scaleX(
                      begin: 0.0, end: 1.0, duration: 400.ms, delay: 200.ms),

                  const SizedBox(height: AppTheme.spacingSM),

                  // Control Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Previous Frame (100ms step for visible change)
                      _buildControlButton(
                        icon: Icons.skip_previous,
                        tooltip: 'Step Back',
                        onPressed: () => _stepBackward(100),
                        size: 32,
                      ),
                      
                      // Rewind 5s
                      _buildControlButton(
                        icon: Icons.replay_5,
                        tooltip: 'Rewind 5s',
                        onPressed: () async {
                          final newPos = position - const Duration(seconds: 5);
                          await _seekAndForceRender(
                            newPos < Duration.zero ? Duration.zero : newPos,
                          );
                        },
                        size: 32,
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
                            widget.controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          ),
                          onPressed: () {
                            if (widget.controller.value.isPlaying) {
                              widget.controller.pause();
                            } else {
                              widget.controller.play();
                            }
                          },
                          tooltip: widget.controller.value.isPlaying
                              ? 'Pause'
                              : 'Play',
                          iconSize: 40,
                        ),
                      )
                          .animate()
                          .scale(
                              delay: 400.ms,
                              duration: 500.ms,
                              curve: Curves.elasticOut)
                          .then()
                          .shimmer(delay: 900.ms, duration: 800.ms),

                      // Forward 5s
                      _buildControlButton(
                        icon: Icons.forward_5,
                        tooltip: 'Forward 5s',
                        onPressed: () async {
                          final newPos = position + const Duration(seconds: 5);
                          await _seekAndForceRender(
                            newPos > duration ? duration : newPos,
                          );
                        },
                        size: 32,
                      ),

                      // Next Frame (100ms step for visible change)
                      _buildControlButton(
                        icon: Icons.skip_next,
                        tooltip: 'Step Forward',
                        onPressed: () => _stepForward(100),
                        size: 32,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacingSM),

                  // Bottom Row: Time Display + Speed Control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Time Display (shows preview time when dragging)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMD,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: _isDragging 
                              ? AppTheme.primaryColor.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        ),
                        child: Text(
                          '${_formatDuration(previewPosition)} / ${_formatDuration(duration)}',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ).animate().fadeIn(duration: 300.ms, delay: 600.ms).slideY(
                          begin: 0.5, end: 0.0, duration: 300.ms, delay: 600.ms),

                      // Playback Speed Button
                      GestureDetector(
                        onTap: _showSpeedSelector,
                        child: Container(
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
                              Icon(
                                Icons.speed,
                                color: Colors.white,
                                size: 16,
                              ),
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
                      ).animate().fadeIn(duration: 300.ms, delay: 700.ms).slideY(
                          begin: 0.5, end: 0.0, duration: 300.ms, delay: 700.ms),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    double size = 28,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: size,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
