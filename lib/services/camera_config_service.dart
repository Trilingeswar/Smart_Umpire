import 'package:shared_preferences/shared_preferences.dart';
import '../models/camera_config.dart';

/// Service for managing camera configuration persistence using shared_preferences.
class CameraConfigService {
  // Camera 1 keys
  static const String _kCameraIp = 'camera_ip';
  static const String _kCameraUsername = 'camera_username';
  static const String _kCameraPassword = 'camera_password';
  static const String _kCameraPort = 'camera_port';

  // Camera 2 keys
  static const String _kCamera2Ip = 'camera2_ip';
  static const String _kCamera2Username = 'camera2_username';
  static const String _kCamera2Password = 'camera2_password';
  static const String _kCamera2Port = 'camera2_port';

  static final CameraConfigService _instance = CameraConfigService._internal();
  factory CameraConfigService() => _instance;
  CameraConfigService._internal();

  SharedPreferences? _prefs;

  /// Initializes the shared_preferences instance.
  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Saves the camera 1 configuration to persistent storage.
  Future<void> saveConfig(CameraConfig config) async {
    await _init();
    await _prefs!.setString(_kCameraIp, config.ip);
    await _prefs!.setString(_kCameraUsername, config.username);
    await _prefs!.setString(_kCameraPassword, config.password);
    await _prefs!.setInt(_kCameraPort, config.port);
  }

  /// Saves the camera 2 configuration to persistent storage.
  Future<void> saveCamera2Config(CameraConfig config) async {
    await _init();
    await _prefs!.setString(_kCamera2Ip, config.ip);
    await _prefs!.setString(_kCamera2Username, config.username);
    await _prefs!.setString(_kCamera2Password, config.password);
    await _prefs!.setInt(_kCamera2Port, config.port);
  }

  /// Saves both camera configurations at once.
  Future<void> saveDualCameraConfig(
      CameraConfig config1, CameraConfig config2) async {
    await saveConfig(config1);
    await saveCamera2Config(config2);
  }

  /// Loads the camera 1 configuration from persistent storage.
  Future<CameraConfig> loadConfig() async {
    await _init();
    return CameraConfig(
      ip: _prefs!.getString(_kCameraIp) ?? '',
      username: _prefs!.getString(_kCameraUsername) ?? '',
      password: _prefs!.getString(_kCameraPassword) ?? '',
      port: _prefs!.getInt(_kCameraPort) ?? 5554,
    );
  }

  /// Loads the camera 2 configuration from persistent storage.
  Future<CameraConfig> loadCamera2Config() async {
    await _init();
    return CameraConfig(
      ip: _prefs!.getString(_kCamera2Ip) ?? '',
      username: _prefs!.getString(_kCamera2Username) ?? '',
      password: _prefs!.getString(_kCamera2Password) ?? '',
      port: _prefs!.getInt(_kCamera2Port) ?? 5554,
    );
  }

  /// Loads both camera configurations.
  Future<(CameraConfig, CameraConfig)> loadDualConfig() async {
    final config1 = await loadConfig();
    final config2 = await loadCamera2Config();
    return (config1, config2);
  }

  /// Returns whether a camera 1 configuration exists.
  Future<bool> hasConfig() async {
    await _init();
    return _prefs!.containsKey(_kCameraIp);
  }

  /// Returns whether a camera 2 configuration exists.
  Future<bool> hasCamera2Config() async {
    await _init();
    return _prefs!.containsKey(_kCamera2Ip);
  }

  /// Returns whether both cameras are configured.
  Future<bool> hasDualCameraConfig() async {
    await _init();
    return _prefs!.containsKey(_kCameraIp) && _prefs!.containsKey(_kCamera2Ip);
  }

  /// Clears the saved camera 1 configuration.
  Future<void> clearConfig() async {
    await _init();
    await _prefs!.remove(_kCameraIp);
    await _prefs!.remove(_kCameraUsername);
    await _prefs!.remove(_kCameraPassword);
    await _prefs!.remove(_kCameraPort);
  }

  /// Clears the saved camera 2 configuration.
  Future<void> clearCamera2Config() async {
    await _init();
    await _prefs!.remove(_kCamera2Ip);
    await _prefs!.remove(_kCamera2Username);
    await _prefs!.remove(_kCamera2Password);
    await _prefs!.remove(_kCamera2Port);
  }

  /// Clears all camera configurations.
  Future<void> clearAllConfigs() async {
    await clearConfig();
    await clearCamera2Config();
  }

  /// Gets the RTSP URL directly from saved camera 1 configuration.
  Future<String?> getRtspUrl() async {
    final config = await loadConfig();
    if (config.isValid) {
      return config.rtspUrl;
    }
    return null;
  }

  /// Gets the RTSP URL directly from saved camera 2 configuration.
  Future<String?> getCamera2RtspUrl() async {
    final config = await loadCamera2Config();
    if (config.isValid) {
      return config.rtspUrl;
    }
    return null;
  }
}
