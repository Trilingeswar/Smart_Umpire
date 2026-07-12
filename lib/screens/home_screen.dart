import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match_details.dart';
import '../providers/video_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_bottom_nav.dart';
import '../widgets/match_setup_dialog.dart';
import 'live_preview_screen.dart';
import 'replay_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _navController;
  late Animation<double> _navAnimation;

  // Track resumable matches for the home screen
  List<String> _resumableMatches = [];
  bool _loadingResumable = true;
  bool _resumeExpanded = true; // Start expanded so user sees it immediately

  final List<Widget> _screens = [
    const LivePreviewScreen(),
    const ReplayScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _navAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _navController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VideoProvider>().initializeCamera();
      _navController.forward();
      _loadResumableMatches();
    });
  }

  /// Loads the list of matches that can be resumed (have saved state).
  Future<void> _loadResumableMatches() async {
    final provider = context.read<VideoProvider>();
    final matches = await provider.getResumableMatches();
    if (mounted) {
      setState(() {
        _resumableMatches = matches;
        _loadingResumable = false;
      });
    }
  }

  /// Resumes a match from its saved state.
  Future<void> _resumeMatch(String folderName) async {
    final provider = context.read<VideoProvider>();
    final success = await provider.resumeMatch(folderName);
    if (success && mounted) {
      setState(() {
        _selectedIndex = 0; // Switch to Live tab
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.play_arrow, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Match resumed: ${folderName.replaceAll('_', ' ')}',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'Failed to resume match',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _navController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _showEditMatchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const MatchSetupDialog(),
    );
  }

  Widget _buildMatchDetailsSection() {
    return Consumer<VideoProvider>(
      builder: (context, provider, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.background,
                Theme.of(context).colorScheme.surface.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Spacer pushes icon + title to center and buttons to bottom
                  const Spacer(),

                  // Cricket Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.8),
                          AppTheme.primaryColor,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_cricket,
                      color: Colors.white,
                      size: 50,
                    ),
                  )
                      .animate()
                      .scale(delay: 200.ms, duration: 600.ms)
                      .then()
                      .shimmer(delay: 800.ms, duration: 1000.ms),

                  const SizedBox(height: AppTheme.spacingMD),

                  // Welcome Text
                  Text(
                    'Welcome to Smart Cricket',
                    style: GoogleFonts.montserrat(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                  const SizedBox(height: AppTheme.spacingSM),

                  // Subtitle
                  Text(
                    'Professional Umpiring System',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

                  const Spacer(),

                  // Setup Match Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showEditMatchDialog(context),
                      icon: const Icon(Icons.add, size: 22),
                      label: const Text(
                        'Setup New Match',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingXL,
                          vertical: AppTheme.spacingMD,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLG),
                        ),
                        elevation: 8,
                        shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                    ),
                  ).animate().fadeIn(delay: 800.ms, duration: 600.ms).scaleXY(
                      begin: 0.95, end: 1.0, delay: 800.ms, duration: 600.ms),

                  const SizedBox(height: AppTheme.spacingMD),

                  // Review Clips Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await context.read<VideoProvider>().loadMatchFolders();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReplayScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.video_library, size: 22),
                      label: const Text(
                        'Review Clips',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingXL,
                          vertical: AppTheme.spacingMD,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLG),
                        ),
                        elevation: 8,
                        shadowColor: AppTheme.secondaryColor.withOpacity(0.3),
                      ),
                    ),
                  ).animate().fadeIn(delay: 900.ms, duration: 600.ms).scaleXY(
                      begin: 0.95, end: 1.0, delay: 900.ms, duration: 600.ms),

                  const SizedBox(height: AppTheme.spacingLG),

                  // ── Resume Match Dropdown (Now at bottom) ────────
                  if (!_loadingResumable && _resumableMatches.isNotEmpty)
                    _buildResumeDropdown(),

                  const SizedBox(height: AppTheme.spacingLG),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Collapsible dropdown card showing all resumable matches.
  Widget _buildResumeDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.12),
            Colors.green.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: Colors.green.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Theme(
        // Remove ExpansionTile default dividers
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _resumeExpanded,
          onExpansionChanged: (v) => setState(() => _resumeExpanded = v),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMD,
            vertical: 4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMD,
            0,
            AppTheme.spacingMD,
            AppTheme.spacingMD,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.green,
              size: 22,
            ),
          ),
          title: Row(
            children: [
              Text(
                'Resume Match',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_resumableMatches.length}',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          trailing: Icon(
            _resumeExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: Colors.green,
          ),
          children: _resumableMatches.map((matchFolder) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: Colors.green.withOpacity(0.2),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _resumeMatch(matchFolder),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMD,
                      vertical: AppTheme.spacingSM,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sports_cricket,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: AppTheme.spacingSM),
                        Expanded(
                          child: Text(
                            matchFolder.replaceAll('_', ' '),
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMD,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: Text(
                            'Resume',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(
        begin: -0.15, end: 0.0, delay: 300.ms, duration: 500.ms);
  }

  Widget _buildMatchDetailsBanner(MatchDetails matchDetails) {
    final provider = context.read<VideoProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLG,
        vertical: AppTheme.spacingMD,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Cricket Icon
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
            ),
            child: const Icon(
              Icons.sports_cricket,
              color: Colors.white,
              size: 20,
            ),
          ),

          const SizedBox(width: AppTheme.spacingMD),

          // Match Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  matchDetails.matchName,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${matchDetails.team1Name} vs ${matchDetails.team2Name} • Innings ${provider.currentInnings} • ${matchDetails.numberOfOvers} overs',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.2, end: 0.0, duration: 400.ms);
  }

  Widget _buildMatchStatsSection() {
    return Consumer<VideoProvider>(
      builder: (context, provider, _) {
        final bufferStatus = provider.bufferStatus;
        final isRecording = provider.isRecording;
        final bufferedClipsCount = provider.bufferedClips.length;

        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMD, vertical: AppTheme.spacingSM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Title
              Padding(
                padding: const EdgeInsets.only(
                    left: AppTheme.spacingSM, bottom: AppTheme.spacingSM),
                child: Text(
                  'Match Overview',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.8),
                  ),
                ),
              ),

              // Stats Cards Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Recording Status Card
                    _buildStatCard(
                      context: context,
                      icon: isRecording ? Icons.videocam : Icons.videocam_off,
                      title: isRecording ? 'Recording' : 'Ready',
                      value: isRecording ? 'Active' : 'Standby',
                      color: isRecording
                          ? AppTheme.accentColor
                          : AppTheme.secondaryColor,
                      subtitle: isRecording
                          ? 'Live capture in progress'
                          : 'Tap to start recording',
                    ),

                    const SizedBox(width: AppTheme.spacingMD),

                    // Buffer Status Card
                    if (bufferStatus != null)
                      _buildStatCard(
                        context: context,
                        icon: Icons.storage,
                        title: 'Buffer',
                        value: '${bufferStatus.percentageUsed}%',
                        color: bufferStatus.percentageUsed > 80
                            ? AppTheme.accentColor
                            : bufferStatus.percentageUsed > 50
                                ? AppTheme.warningColor
                                : AppTheme.secondaryColor,
                        subtitle: '${bufferStatus.currentBall} balls stored',
                      ),

                    const SizedBox(width: AppTheme.spacingMD),

                    // Clips Count Card
                    _buildStatCard(
                      context: context,
                      icon: Icons.video_library,
                      title: 'Clips',
                      value: '$bufferedClipsCount',
                      color: AppTheme.primaryColor,
                      subtitle: 'Available for review',
                    ),

                    const SizedBox(width: AppTheme.spacingMD),

                    // Match Progress Card (if match details available)
                    if (provider.matchDetails != null)
                      _buildStatCard(
                        context: context,
                        icon: Icons.timeline,
                        title: 'Innings ${provider.currentInnings}',
                        value: '${provider.currentOver}/${provider.matchDetails!.numberOfOvers}',
                        color: provider.isInningsOver ? Colors.orange : AppTheme.primaryColor,
                        subtitle: provider.isMatchOver ? 'Match Over' : (provider.isInningsOver ? 'Innings complete' : 'Overs completed'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms, delay: 200.ms)
            .slideY(begin: 0.1, end: 0.0, duration: 500.ms, delay: 200.ms);
      },
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon and Title Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingSM),

          // Value
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 2),

          // Subtitle
          Text(
            subtitle,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Consumer<VideoProvider>(
        builder: (context, provider, _) {
          // If reball requested from review, switch to Live tab
          if (provider.shouldAutoReball && _selectedIndex != 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedIndex = 0;
                });
              }
            });
          }

          final matchDetails = provider.matchDetails;
          if (matchDetails == null) {
            return _buildMatchDetailsSection();
          }

          return Column(
            children: [
              // Match Details Banner - Only show on Live tab (index 0)
              if (_selectedIndex == 0) _buildMatchDetailsBanner(matchDetails),

              // Main Content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.1, 0.0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _screens[_selectedIndex],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Consumer<VideoProvider>(
        builder: (context, provider, _) {
          if (provider.matchDetails == null) {
            return const SizedBox();
          }

          return AnimatedBottomNav(
            currentIndex: _selectedIndex,
            onTap: _onNavItemTapped,
            animation: _navAnimation,
            items: const [
              BottomNavItem(
                icon: Icons.videocam,
                label: 'Live',
                activeColor: AppTheme.primaryColor,
              ),
              BottomNavItem(
                icon: Icons.replay,
                label: 'Replay',
                activeColor: AppTheme.primaryColor,
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.95),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
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
            child: const Icon(
              Icons.sports_cricket,
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
            child: Text(
              'Smart Cricket',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideX(begin: -0.2, end: 0.0, delay: 300.ms, duration: 500.ms),
          ),
        ],
      ),
      actions: [
        // Edit Match Details Button - Only show on Live tab (index 0)
        Consumer<VideoProvider>(
          builder: (context, provider, _) {
            if (provider.matchDetails == null || _selectedIndex != 0)
              return const SizedBox();

            return IconButton(
              onPressed: () => _showEditMatchDialog(context),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Match Details',
            ).animate().scale(delay: 600.ms, duration: 400.ms);
          },
        ),

        // Buffer Status
        Consumer<VideoProvider>(
          builder: (context, provider, _) {
            final status = provider.bufferStatus;
            if (status == null) return const SizedBox();

            return Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: AppTheme.spacingSM,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    status.percentageUsed > 80
                        ? AppTheme.accentColor
                        : status.percentageUsed > 50
                            ? AppTheme.warningColor
                            : AppTheme.secondaryColor,
                    (status.percentageUsed > 80
                            ? AppTheme.accentColor
                            : status.percentageUsed > 50
                                ? AppTheme.warningColor
                                : AppTheme.secondaryColor)
                        .withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                boxShadow: [
                  BoxShadow(
                    color: (status.percentageUsed > 80
                            ? AppTheme.accentColor
                            : status.percentageUsed > 50
                                ? AppTheme.warningColor
                                : AppTheme.secondaryColor)
                        .withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sports_cricket,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Text(
                    status.currentBall,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .scale(delay: 600.ms, duration: 400.ms)
                .then()
                .shimmer(delay: 1000.ms, duration: 600.ms);
          },
        ),
      ],
    );
  }
}
