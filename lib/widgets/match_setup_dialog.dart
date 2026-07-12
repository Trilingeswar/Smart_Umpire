import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/match_details.dart';
import '../providers/video_provider.dart';
import '../theme/app_theme.dart';

class MatchSetupDialog extends StatefulWidget {
  const MatchSetupDialog({Key? key}) : super(key: key);

  @override
  State<MatchSetupDialog> createState() => _MatchSetupDialogState();
}

class _MatchSetupDialogState extends State<MatchSetupDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _matchNameController = TextEditingController();
  final _team1Controller = TextEditingController();
  final _team2Controller = TextEditingController();
  final _oversController = TextEditingController();
  final _cameraIpController = TextEditingController(text: '192.168.29.44');
  final _cameraUsernameController = TextEditingController();
  final _cameraPasswordController = TextEditingController();

  // Camera 2 controllers
  final _camera2IpController = TextEditingController();
  final _camera2UsernameController = TextEditingController();
  final _camera2PasswordController = TextEditingController();

  bool _showCamera2Section = false;

  late AnimationController _dialogController;
  late Animation<double> _dialogAnimation;

  @override
  void initState() {
    super.initState();
    _dialogController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _dialogAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dialogController, curve: Curves.elasticOut),
    );
    _dialogController.forward();

    // Pre-fill form if editing existing match details
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<VideoProvider>();
      final existingDetails = provider.matchDetails;
      if (existingDetails != null) {
        _matchNameController.text = existingDetails.matchName;
        _team1Controller.text = existingDetails.team1Name;
        _team2Controller.text = existingDetails.team2Name;
        _oversController.text = existingDetails.numberOfOvers.toString();
        _cameraIpController.text = existingDetails.cameraIp;
        _cameraUsernameController.text = existingDetails.cameraUsername;
        _cameraPasswordController.text = existingDetails.cameraPassword;

        // Camera 2 fields
        _camera2IpController.text = existingDetails.camera2Ip;
        _camera2UsernameController.text = existingDetails.camera2Username;
        _camera2PasswordController.text = existingDetails.camera2Password;
        _showCamera2Section = existingDetails.camera2Ip.isNotEmpty;
      }
    });
  }

  @override
  void dispose() {
    _matchNameController.dispose();
    _team1Controller.dispose();
    _team2Controller.dispose();
    _oversController.dispose();
    _cameraIpController.dispose();
    _cameraUsernameController.dispose();
    _cameraPasswordController.dispose();
    _camera2IpController.dispose();
    _camera2UsernameController.dispose();
    _camera2PasswordController.dispose();
    _dialogController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final matchDetails = MatchDetails(
        matchName: _matchNameController.text.trim(),
        team1Name: _team1Controller.text.trim(),
        team2Name: _team2Controller.text.trim(),
        numberOfOvers: int.parse(_oversController.text.trim()),
        cameraIp: _cameraIpController.text.trim(),
        cameraUsername: _cameraUsernameController.text.trim(),
        cameraPassword: _cameraPasswordController.text.trim(),
        // Camera 2 fields (only if user enabled it)
        camera2Ip: _showCamera2Section ? _camera2IpController.text.trim() : '',
        camera2Username:
            _showCamera2Section ? _camera2UsernameController.text.trim() : '',
        camera2Password:
            _showCamera2Section ? _camera2PasswordController.text.trim() : '',
      );

      final provider = context.read<VideoProvider>();
      provider.saveMatchDetails(matchDetails);

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dialogAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _dialogAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Consumer<VideoProvider>(
                        builder: (context, provider, _) {
                          final isEditing = provider.matchDetails != null;
                          return Row(
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.all(AppTheme.spacingSM),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor,
                                      AppTheme.primaryColor.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMD),
                                ),
                                child: Icon(
                                  isEditing ? Icons.edit : Icons.sports_cricket,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingMD),
                              Expanded(
                                child: Text(
                                  isEditing
                                      ? 'Edit Match Details'
                                      : 'Match Setup',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          )
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideX(begin: -0.2, end: 0.0);
                        },
                      ),

                      const SizedBox(height: AppTheme.spacingXL),

                      // Match Name Field
                      TextFormField(
                        controller: _matchNameController,
                        decoration: InputDecoration(
                          labelText: 'Match Name',
                          hintText: 'e.g., India vs Australia - Final',
                          prefixIcon: const Icon(Icons.event),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter match name';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 100.ms)
                          .slideY(begin: 0.2, end: 0.0),

                      const SizedBox(height: AppTheme.spacingLG),

                      // Team 1 Field
                      TextFormField(
                        controller: _team1Controller,
                        decoration: InputDecoration(
                          labelText: 'Team 1 Name',
                          hintText: 'e.g., India',
                          prefixIcon: const Icon(Icons.group),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter team 1 name';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 200.ms)
                          .slideY(begin: 0.2, end: 0.0),

                      const SizedBox(height: AppTheme.spacingLG),

                      // Team 2 Field
                      TextFormField(
                        controller: _team2Controller,
                        decoration: InputDecoration(
                          labelText: 'Team 2 Name',
                          hintText: 'e.g., Australia',
                          prefixIcon: const Icon(Icons.group),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter team 2 name';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 300.ms)
                          .slideY(begin: 0.2, end: 0.0),

                      const SizedBox(height: AppTheme.spacingLG),

                      // Number of Overs Field
                      TextFormField(
                        controller: _oversController,
                        decoration: InputDecoration(
                          labelText: 'Number of Overs',
                          hintText: 'e.g., 50',
                          prefixIcon: const Icon(Icons.timer),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter number of overs';
                          }
                          final overs = int.tryParse(value);
                          if (overs == null || overs <= 0) {
                            return 'Please enter a valid number of overs';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 400.ms)
                          .slideY(begin: 0.2, end: 0.0),

                      const SizedBox(height: AppTheme.spacingXL),

                      // Camera 1 Section Header
                      Row(
                        children: [
                          Icon(Icons.videocam, color: AppTheme.primaryColor),
                          const SizedBox(width: AppTheme.spacingSM),
                          Text(
                            'Camera 1 (Primary)',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms, delay: 450.ms),

                      const SizedBox(height: AppTheme.spacingMD),

                      // Camera IP Field
                      TextFormField(
                        controller: _cameraIpController,
                        decoration: InputDecoration(
                          labelText: 'Camera 1 IP Address',
                          hintText: 'e.g., 192.168.1.100',
                          prefixIcon: const Icon(Icons.videocam),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter camera IP address';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 500.ms)
                          .slideY(begin: 0.2, end: 0.0),

                      const SizedBox(height: AppTheme.spacingLG),

                      // Camera Username Field
                      TextFormField(
                        controller: _cameraUsernameController,
                        decoration: InputDecoration(
                          labelText: 'Camera 1 Username',
                          hintText: 'Enter camera username',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter camera username';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 550.ms)
                          .slideY(begin: 0.2, end: 0.0),

                      const SizedBox(height: AppTheme.spacingLG),

                      // Camera Password Field
                      TextFormField(
                        controller: _cameraPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Camera 1 Password',
                          hintText: 'Enter camera password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter camera password';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitForm(),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 600.ms)
                          .slideY(begin: 0.2, end: 0.0),

                      const SizedBox(height: AppTheme.spacingXL),

                      // Camera 2 Toggle
                      Row(
                        children: [
                          Switch(
                            value: _showCamera2Section,
                            onChanged: (value) {
                              setState(() {
                                _showCamera2Section = value;
                              });
                            },
                            activeColor: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: AppTheme.spacingSM),
                          Expanded(
                            child: Text(
                              'Add Second Camera (Dual Recording)',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms, delay: 650.ms),

                      // Camera 2 Section (collapsible)
                      if (_showCamera2Section) ...[
                        const SizedBox(height: AppTheme.spacingLG),

                        Row(
                          children: [
                            Icon(Icons.videocam, color: Colors.orange),
                            const SizedBox(width: AppTheme.spacingSM),
                            Text(
                              'Camera 2 (Secondary)',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 400.ms),

                        const SizedBox(height: AppTheme.spacingMD),

                        // Camera 2 IP Field
                        TextFormField(
                          controller: _camera2IpController,
                          decoration: InputDecoration(
                            labelText: 'Camera 2 IP Address',
                            hintText: 'e.g., 192.168.1.101',
                            prefixIcon: const Icon(Icons.videocam),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMD),
                            ),
                          ),
                          validator: (value) {
                            if (_showCamera2Section &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Please enter camera 2 IP address';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.2, end: 0.0),

                        const SizedBox(height: AppTheme.spacingLG),

                        // Camera 2 Username Field
                        TextFormField(
                          controller: _camera2UsernameController,
                          decoration: InputDecoration(
                            labelText: 'Camera 2 Username',
                            hintText: 'Enter camera 2 username',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMD),
                            ),
                          ),
                          validator: (value) {
                            if (_showCamera2Section &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Please enter camera 2 username';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.2, end: 0.0),

                        const SizedBox(height: AppTheme.spacingLG),

                        // Camera 2 Password Field
                        TextFormField(
                          controller: _camera2PasswordController,
                          decoration: InputDecoration(
                            labelText: 'Camera 2 Password',
                            hintText: 'Enter camera 2 password',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMD),
                            ),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (_showCamera2Section &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Please enter camera 2 password';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submitForm(),
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.2, end: 0.0),
                      ],

                      const SizedBox(height: AppTheme.spacingXL),

                      // Submit Button
                      Consumer<VideoProvider>(
                        builder: (context, provider, _) {
                          final isEditing = provider.matchDetails != null;
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _submitForm,
                              icon: Icon(
                                  isEditing ? Icons.save : Icons.play_arrow),
                              label: Text(
                                  isEditing ? 'Save Changes' : 'Start Match'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingXL,
                                  vertical: AppTheme.spacingMD,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMD),
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 700.ms)
                              .scaleXY(begin: 0.8, end: 1.0);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
