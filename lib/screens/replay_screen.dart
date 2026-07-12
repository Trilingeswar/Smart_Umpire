import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/video_provider.dart';
import '../models/video_clip.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_fab.dart';
import 'ball_review_screen.dart';

class ReplayScreen extends StatefulWidget {
  const ReplayScreen({Key? key}) : super(key: key);

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  VideoPlayerController? _videoController;
  VideoClip? _selectedClip;

  // Group clips by ball number and track selected variant per ball
  final Map<String, VideoClip> _selectedClipPerBall = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VideoProvider>().loadMatchFolders();
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<VideoProvider>(
        builder: (context, provider, _) {
          final selectedFolder = provider.selectedMatchFolder;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  Theme.of(context).colorScheme.background,
                  Theme.of(context).colorScheme.surface.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              children: [
                _buildHeader(context, provider, selectedFolder),
                Expanded(
                  child: selectedFolder == null
                      ? _buildMatchFoldersList(provider)
                      : _buildClipsList(provider.bufferedClips, provider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, VideoProvider provider, String? selectedFolder) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusLG),
          bottomRight: Radius.circular(AppTheme.radiusLG),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (selectedFolder != null)
            Container(
              margin: const EdgeInsets.only(right: AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: IconButton(
                onPressed: () {
                  provider.clearSelectedMatchFolder();
                  provider.loadMatchFolders();
                },
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
            ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.2, end: 0.0),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              selectedFolder != null ? Icons.folder : Icons.sports_cricket,
              color: Colors.white,
              size: 24,
            ),
          )
              .animate()
              .scale(delay: 200.ms, duration: 500.ms)
              .then()
              .shimmer(delay: 700.ms, duration: 800.ms),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedFolder ?? 'Ball Replays',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideX(
                    begin: -0.2, end: 0.0, delay: 300.ms, duration: 500.ms),
                Text(
                  selectedFolder != null
                      ? 'Review and analyze ball deliveries'
                      : 'Select a match to view recordings',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 500.ms).slideX(
                    begin: -0.2, end: 0.0, delay: 500.ms, duration: 500.ms),
              ],
            ),
          ),
          // Delete folder button — visible only when inside a specific match folder
          if (selectedFolder != null)
            Container(
              margin: const EdgeInsets.only(left: AppTheme.spacingSM),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: IconButton(
                onPressed: () => _confirmAndDeleteFolder(context, provider, selectedFolder!),
                icon: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                  size: 20,
                ),
                tooltip: 'Delete Match Folder',
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms).scaleXY(begin: 0.8, end: 1.0, duration: 300.ms, delay: 200.ms),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: -0.2, end: 0.0, duration: 600.ms);
  }

  Widget _buildMatchFoldersList(VideoProvider provider) {
    if (provider.isLoading) {
      return _buildLoadingState();
    }

    final folders = provider.allMatchFolders;

    if (folders.isEmpty) {
      return _buildNoMatchesState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadMatchFolders();
      },
      color: AppTheme.primaryColor,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.04,
              vertical: AppTheme.spacingSM,
            ),
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: AppTheme.getCardDecoration(context),
            child: Row(
              children: [
                const Icon(Icons.folder, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.spacingMD),
                Text(
                  'Match Recordings',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 600.ms)
              .slideY(begin: 0.2, end: 0.0, duration: 600.ms, delay: 600.ms),
          Expanded(
            child: AnimationLimiter(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.04,
                  vertical: AppTheme.spacingSM,
                ),
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 500),
                    child: SlideAnimation(
                      verticalOffset: 30.0,
                      child: FadeInAnimation(
                        child:
                            _buildFolderCard(folders[index], provider, index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard(
      String folderName, VideoProvider provider, int index) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Card(
        elevation: 2,
        shadowColor: AppTheme.primaryColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        child: InkWell(
          onTap: () async {
            await provider.selectMatchFolder(folderName);
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: Padding(
            padding: EdgeInsets.all(
                screenWidth > 400 ? AppTheme.spacingMD : AppTheme.spacingSM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingSM),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withOpacity(0.8)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.folder,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(
                        width: screenWidth > 400
                            ? AppTheme.spacingMD
                            : AppTheme.spacingSM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folderName.replaceAll('_', ' '),
                            style: GoogleFonts.montserrat(
                              fontSize: screenWidth > 400 ? 18 : 16,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXS),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: AppTheme.spacingXS),
                              Text(
                                'Tap to view recordings',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Delete button for this folder
                    IconButton(
                      onPressed: () => _confirmAndDeleteFolder(context, provider, folderName),
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                      tooltip: 'Delete Match Folder',
                      splashRadius: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMatchesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_off,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            ),
          )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(delay: 800.ms, duration: 800.ms),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            'No match recordings found',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 500.ms)
              .slideY(begin: 0.3, end: 0.0, delay: 400.ms, duration: 500.ms),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            'Start a match recording to see it here',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          )
              .animate()
              .fadeIn(delay: 600.ms, duration: 500.ms)
              .slideY(begin: 0.3, end: 0.0, delay: 600.ms, duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildClipsList(
    List<VideoClip> clips,
    VideoProvider provider,
  ) {
    if (provider.isLoading) {
      return _buildLoadingState();
    }

    if (clips.isEmpty) {
      return _buildEmptyState();
    }

    // Group clips by ball number
    final Map<String, List<VideoClip>> clipsByBall = {};
    for (final clip in clips) {
      final ballKey = clip.ballNumber;
      if (!clipsByBall.containsKey(ballKey)) {
        clipsByBall[ballKey] = [];
      }
      clipsByBall[ballKey]!.add(clip);
    }

    // Sort balls in descending order
    final sortedBalls = clipsByBall.keys.toList()
      ..sort((a, b) => _compareBallNumbers(b, a));

    return RefreshIndicator(
      onRefresh: () async {
        if (provider.selectedMatchFolder != null) {
          await provider.selectMatchFolder(provider.selectedMatchFolder!);
        }
      },
      color: AppTheme.primaryColor,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: AnimationLimiter(
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.04,
            vertical: AppTheme.spacingSM,
          ),
          itemCount: sortedBalls.length,
          itemBuilder: (context, index) {
            final ballKey = sortedBalls[index];
            final ballClips = clipsByBall[ballKey]!;
            
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 500),
              child: SlideAnimation(
                verticalOffset: 30.0,
                child: FadeInAnimation(
                  child: _buildBallClipGroup(
                    ballKey, 
                    ballClips, 
                    provider, 
                    index,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Compare ball numbers like "0.1", "0.2" etc for sorting
  int _compareBallNumbers(String a, String b) {
    final partsA = a.split('.');
    final partsB = b.split('.');
    if (partsA.length != 2 || partsB.length != 2) return a.compareTo(b);
    
    final overA = int.tryParse(partsA[0]) ?? 0;
    final overB = int.tryParse(partsB[0]) ?? 0;
    if (overA != overB) return overA.compareTo(overB);
    
    final ballA = int.tryParse(partsA[1]) ?? 0;
    final ballB = int.tryParse(partsB[1]) ?? 0;
    return ballA.compareTo(ballB);
  }

  Widget _buildBallClipGroup(
    String ballKey,
    List<VideoClip> clips,
    VideoProvider provider,
    int index,
  ) {
    // Sort clips: original first, then by reball index
    clips.sort((a, b) {
      if (a.isReball && !b.isReball) return 1;
      if (!a.isReball && b.isReball) return -1;
      return a.reballIndex.compareTo(b.reballIndex);
    });

    // Get the currently selected clip for this ball, matching by ID to handle object instance changes
    final VideoClip? savedClip = _selectedClipPerBall[ballKey];
    final VideoClip currentClip = clips.firstWhere(
      (c) => c.id == savedClip?.id,
      orElse: () => clips.first,
    );

    // Update the selection to the current instance to prevent DropdownButton assertion errors
    _selectedClipPerBall[ballKey] = currentClip;

    final hasMultipleClips = clips.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ball header
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacingXS, 
              bottom: AppTheme.spacingXS
            ),
            child: Text(
              'Ball $ballKey',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          
          // Clip card with dropdown inside
          _buildClipCard(
            _selectedClipPerBall[ballKey]!, 
            provider, 
            index,
            ballKey,
            clips,
          ),
        ],
      ),
    );
  }

  Widget _buildBallDropdown(String ballKey, List<VideoClip> clips) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<VideoClip>(
          isExpanded: true,
          value: _selectedClipPerBall[ballKey],
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppTheme.primaryColor,
          ),
          dropdownColor: Theme.of(context).colorScheme.surface,
          items: clips.map((clip) {
            String label = clip.isReball ? 'Reball ${clip.reballIndex}' : 'Original';
            if (clip.isPermanent) {
              label += ' (Saved)';
            }
            return DropdownMenuItem<VideoClip>(
              value: clip,
              child: Row(
                children: [
                    Icon(
                      clip.isReball ? Icons.replay : Icons.videocam,
                      size: 16,
                      color: clip.isPermanent 
                        ? Colors.green 
                        : (clip.isReball ? AppTheme.secondaryColor : AppTheme.primaryColor),
                    ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Text(
                    label,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (clip) {
            if (clip != null) {
              setState(() {
                _selectedClipPerBall[ballKey] = clip;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Shimmer.fromColors(
            baseColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            highlightColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.6),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Icon(
                Icons.videocam,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            'Loading clips...',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: AppTheme.spacingMD),
          const CircularProgressIndicator()
              .animate()
              .fadeIn(duration: 400.ms, delay: 400.ms)
              .scaleXY(begin: 0.5, end: 1.0, duration: 400.ms, delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.videocam_off,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            ),
          )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(delay: 800.ms, duration: 800.ms),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            'No clips in this match',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 500.ms)
              .slideY(begin: 0.3, end: 0.0, delay: 400.ms, duration: 500.ms),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            'Record balls to see them here',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          )
              .animate()
              .fadeIn(delay: 600.ms, duration: 500.ms)
              .slideY(begin: 0.3, end: 0.0, delay: 600.ms, duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildClipCard(
    VideoClip clip, 
    VideoProvider provider, 
    int index, 
    String ballKey,
    List<VideoClip> allClips,
  ) {
    final isSelected = _selectedClip?.id == clip.id;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.08),
                  AppTheme.primaryColor.withOpacity(0.03),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: isSelected
            ? Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
                width: 1.5,
              )
            : null,
      ),
      child: Card(
        elevation: isSelected ? 6 : 1,
        shadowColor: isSelected
            ? AppTheme.primaryColor.withOpacity(0.2)
            : Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        child: InkWell(
          onTap: () => _navigateToReview(clip),
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: Padding(
            padding: EdgeInsets.all(
                screenWidth > 400 ? AppTheme.spacingMD : AppTheme.spacingSM),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (allClips.length > 1) ...[
                  _buildBallDropdown(ballKey, allClips),
                  const SizedBox(height: AppTheme.spacingMD),
                ],
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingSM),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: clip.isPermanent
                              ? [Colors.green, Colors.green.withOpacity(0.8)]
                              : (clip.isReball
                                  ? [
                                      AppTheme.secondaryColor,
                                      AppTheme.secondaryColor.withOpacity(0.8)
                                    ]
                                  : [
                                      AppTheme.primaryColor,
                                      AppTheme.primaryColor.withOpacity(0.8)
                                    ]),
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        boxShadow: [
                          BoxShadow(
                            color: (clip.isReball 
                                ? AppTheme.secondaryColor 
                                : AppTheme.primaryColor).withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        clip.isReball ? Icons.replay : Icons.videocam,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    SizedBox(
                        width: screenWidth > 400
                            ? AppTheme.spacingMD
                            : AppTheme.spacingSM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                clip.ballNumber,
                                style: GoogleFonts.montserrat(
                                  fontSize: screenWidth > 400 ? 18 : 16,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (clip.isReball) ...[
                                const SizedBox(width: AppTheme.spacingSM),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingSM,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Reball ${clip.reballIndex}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.secondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                              if (clip.isPermanent) ...[
                                const SizedBox(width: AppTheme.spacingSM),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingSM,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Saved Replay',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingXS),
                          Wrap(
                            spacing: AppTheme.spacingMD,
                            runSpacing: AppTheme.spacingXS,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                  const SizedBox(width: AppTheme.spacingXS),
                                  Text(
                                    '${clip.duration}s',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                  const SizedBox(width: AppTheme.spacingXS),
                                  Text(
                                    _formatTimestamp(clip.timestamp),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.videocam,
                                    size: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                  const SizedBox(width: AppTheme.spacingXS),
                                  Text(
                                    clip.camera2Path != null
                                        ? 'Camera ${clip.cameraIndex} & Camera 2'
                                        : 'Camera ${clip.cameraIndex}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AnimatedFAB(
                      onPressed: () => _navigateToReview(clip),
                      icon: Icons.play_arrow,
                      label: 'Review',
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      size: FABSize.small,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToReview(VideoClip clip) async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => BallReviewScreen(clip: clip),
      ),
    );
  }

  /// Shows a confirmation dialog then deletes [folderName] via the provider.
  Future<void> _confirmAndDeleteFolder(
    BuildContext context,
    VideoProvider provider,
    String folderName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Match Folder',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete the entire match folder:',
              style: GoogleFonts.montserrat(
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                folderName,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All clips and saved replays will be lost. This action cannot be undone.',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text(
              'DELETE',
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

    if (confirmed != true || !mounted) return;

    // Show progress snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Deleting match folder...'),
          ],
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
      ),
    );

    final success = await provider.deleteMatchFolder(folderName);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Match folder "$folderName" deleted.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
        ),
      );
      // If we were viewing this folder's clips, go back to the folder list
      if (provider.selectedMatchFolder == null) {
        // Provider already cleared it; UI rebuilds automatically via Consumer.
        // Nothing else needed.
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete match folder.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
        ),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
