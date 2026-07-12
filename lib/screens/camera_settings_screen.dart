import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/camera_config.dart';
import '../providers/video_provider.dart';
import '../services/camera_config_service.dart';
import '../theme/app_theme.dart';

/// Screen for configuring camera connection settings.
///
/// Allows users to input camera IP address, username, and password
/// which are then used to construct the RTSP URL for video streaming.
class CameraSettingsScreen extends StatefulWidget {
  const CameraSettingsScreen({Key? key}) : super(key: key);

  @override
  State<CameraSettingsScreen> createState() => _CameraSettingsScreenState();
}

class _CameraSettingsScreenState extends State<CameraSettingsScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Camera 1 controllers
  final _ipController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _portController = TextEditingController(text: '5554');

  // Camera 2 controllers
  final _ip2Controller = TextEditingController();
  final _username2Controller = TextEditingController();
  final _password2Controller = TextEditingController();
  final _port2Controller = TextEditingController(text: '5554');

  bool _obscurePassword = true;
  bool _obscurePassword2 = true;
  bool _isSaving = false;
  bool _showCamera2Section = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    _loadSavedConfig();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    _ip2Controller.dispose();
    _username2Controller.dispose();
    _password2Controller.dispose();
    _port2Controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Loads previously saved camera configuration.
  Future<void> _loadSavedConfig() async {
    final (config1, config2) = await CameraConfigService().loadDualConfig();
    if (mounted) {
      setState(() {
        _ipController.text = config1.ip;
        _usernameController.text = config1.username;
        _passwordController.text = config1.password;
        _portController.text = config1.port.toString();

        _ip2Controller.text = config2.ip;
        _username2Controller.text = config2.username;
        _password2Controller.text = config2.password;
        _port2Controller.text = config2.port.toString();

        _showCamera2Section = config2.isValid;
      });
    }
  }

  /// Validates and saves the camera configuration.
  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final config1 = CameraConfig(
        ip: _ipController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        port: int.parse(_portController.text.trim()),
      );

      // Save camera 1 config
      await CameraConfigService().saveConfig(config1);

      // Save camera 2 config if section is shown and valid
      if (_showCamera2Section) {
        final config2 = CameraConfig(
          ip: _ip2Controller.text.trim(),
          username: _username2Controller.text.trim(),
          password: _password2Controller.text.trim(),
          port: int.parse(_port2Controller.text.trim()),
        );
        await CameraConfigService().saveCamera2Config(config2);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _showCamera2Section
                  ? 'Dual camera configuration saved!'
                  : 'Camera configuration saved!',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving configuration: $e',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Camera Settings',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingLG),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.1),
                        AppTheme.primaryColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.videocam,
                          color: AppTheme.primaryColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RTSP Camera Setup',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter your camera credentials to connect',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),

                const SizedBox(height: AppTheme.spacingXL),

                // Camera 1 Section Header
                Row(
                  children: [
                    Icon(Icons.videocam, color: AppTheme.primaryColor),
                    const SizedBox(width: AppTheme.spacingSM),
                    Text(
                      'Camera 1 (Primary)',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: AppTheme.spacingMD),

                // IP Address Field
                TextFormField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: 'Camera 1 IP Address',
                    hintText: 'e.g., 192.168.1.100',
                    prefixIcon: const Icon(Icons.dns),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter camera IP address';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                const SizedBox(height: AppTheme.spacingLG),

                // Port Field
                TextFormField(
                  controller: _portController,
                  decoration: InputDecoration(
                    labelText: 'RTSP Port',
                    hintText: 'e.g., 5554',
                    prefixIcon: const Icon(Icons.settings_input_antenna),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter RTSP port';
                    }
                    final port = int.tryParse(value);
                    if (port == null || port <= 0 || port > 65535) {
                      return 'Invalid port number';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

                const SizedBox(height: AppTheme.spacingLG),

                // Username Field
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Camera 1 Username',
                    hintText: 'Enter authentication username',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter camera username';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                const SizedBox(height: AppTheme.spacingLG),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Camera 1 Password',
                    hintText: 'Enter authentication password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter camera password';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _saveConfig(),
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

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
                    Text(
                      'Add Second Camera',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 400.ms),

                // Camera 2 Section
                if (_showCamera2Section) ...[
                  const SizedBox(height: AppTheme.spacingLG),

                  // Camera 2 Section Header
                  Row(
                    children: [
                      Icon(Icons.videocam, color: Colors.orange),
                      const SizedBox(width: AppTheme.spacingSM),
                      Text(
                        'Camera 2 (Secondary)',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 420.ms),

                  const SizedBox(height: AppTheme.spacingMD),

                  // Camera 2 IP Address Field
                  TextFormField(
                    controller: _ip2Controller,
                    decoration: InputDecoration(
                      labelText: 'Camera 2 IP Address',
                      hintText: 'e.g., 192.168.1.101',
                      prefixIcon: const Icon(Icons.dns),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
                  ).animate().fadeIn(delay: 440.ms).slideY(begin: 0.1),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Camera 2 Port Field
                  TextFormField(
                    controller: _port2Controller,
                    decoration: InputDecoration(
                      labelText: 'Camera 2 RTSP Port',
                      hintText: 'e.g., 5554',
                      prefixIcon: const Icon(Icons.settings_input_antenna),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (_showCamera2Section &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Please enter RTSP port';
                      }
                      final port = int.tryParse(value ?? '');
                      if (port != null && (port <= 0 || port > 65535)) {
                        return 'Invalid port number';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ).animate().fadeIn(delay: 460.ms).slideY(begin: 0.1),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Camera 2 Username Field
                  TextFormField(
                    controller: _username2Controller,
                    decoration: InputDecoration(
                      labelText: 'Camera 2 Username',
                      hintText: 'Enter camera 2 username',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
                  ).animate().fadeIn(delay: 480.ms).slideY(begin: 0.1),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Camera 2 Password Field
                  TextFormField(
                    controller: _password2Controller,
                    decoration: InputDecoration(
                      labelText: 'Camera 2 Password',
                      hintText: 'Enter camera 2 password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword2
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(
                              () => _obscurePassword2 = !_obscurePassword2);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                    ),
                    obscureText: _obscurePassword2,
                    validator: (value) {
                      if (_showCamera2Section &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Please enter camera 2 password';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveConfig(),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                ],

                const SizedBox(height: AppTheme.spacingXL),

                // Preview Section - Camera 1
                if (_ipController.text.isNotEmpty &&
                    _usernameController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.link,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: AppTheme.spacingSM),
                            Text(
                              'Camera 1 RTSP URL Preview',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingSM),
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingSM),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .background
                                .withOpacity(0.5),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: SelectableText(
                            'rtsp://${_usernameController.text}:*******@${_ipController.text}:${_portController.text}/',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 550.ms),

                // Preview Section - Camera 2
                if (_showCamera2Section &&
                    _ip2Controller.text.isNotEmpty &&
                    _username2Controller.text.isNotEmpty &&
                    _password2Controller.text.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: AppTheme.spacingMD),
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.link,
                              size: 20,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: AppTheme.spacingSM),
                            Text(
                              'Camera 2 RTSP URL Preview',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingSM),
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingSM),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .background
                                .withOpacity(0.5),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: SelectableText(
                            'rtsp://${_username2Controller.text}:*******@${_ip2Controller.text}:${_port2Controller.text}/',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 580.ms),

                const SizedBox(height: AppTheme.spacingXL),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveConfig,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Configuration',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingXL,
                        vertical: AppTheme.spacingMD,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),

                const SizedBox(height: AppTheme.spacingLG),

                // Test Connection Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            final config1 = CameraConfig(
                              ip: _ipController.text.trim(),
                              username: _usernameController.text.trim(),
                              password: _passwordController.text.trim(),
                              port: int.parse(_portController.text.trim()),
                            );

                            final configs = <String>[];
                            if (config1.isValid) {
                              configs.add('Camera 1: ${config1.rtspUrl}');
                            }

                            if (_showCamera2Section) {
                              final config2 = CameraConfig(
                                ip: _ip2Controller.text.trim(),
                                username: _username2Controller.text.trim(),
                                password: _password2Controller.text.trim(),
                                port: int.parse(_port2Controller.text.trim()),
                              );
                              if (config2.isValid) {
                                configs.add('Camera 2: ${config2.rtspUrl}');
                              }
                            }

                            if (configs.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: configs
                                        .map((url) => Text(url))
                                        .toList(),
                                  ),
                                  backgroundColor: AppTheme.primaryColor,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.link_off),
                    label: Text(
                      'Test URLs',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingXL,
                        vertical: AppTheme.spacingMD,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
