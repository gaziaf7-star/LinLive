import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Performance levels for battery optimization
enum PerformanceLevel { high, medium, low, critical }

/// ✅ BATTERY OPTIMIZATION: Utility class to monitor and optimize battery usage during live streaming
class BatteryOptimizer {
  static final BatteryOptimizer _instance = BatteryOptimizer._internal();
  factory BatteryOptimizer() => _instance;
  BatteryOptimizer._internal();

  final Battery _battery = Battery();
  Timer? _batteryMonitorTimer;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  // Current performance level
  PerformanceLevel _currentLevel = PerformanceLevel.high;

  // Battery thresholds
  static const int lowBatteryThreshold = 30;
  static const int criticalBatteryThreshold = 15;

  // Callbacks
  Function(PerformanceLevel)? onPerformanceLevelChanged;
  Function(String)? onBatteryWarning;

  /// Initialize battery monitoring
  Future<void> initialize({
    Function(PerformanceLevel)? onPerformanceLevelChanged,
    Function(String)? onBatteryWarning,
  }) async {
    this.onPerformanceLevelChanged = onPerformanceLevelChanged;
    this.onBatteryWarning = onBatteryWarning;

    // ✅ STEP 3A: do not create duplicate monitor timers when live room opens
    // again/minimized/restored. Battery level changes slowly, so 60s is enough.
    _batteryMonitorTimer ??= Timer.periodic(
      const Duration(seconds: 60),
          (_) => _checkBatteryLevel(),
    );

    _batteryStateSubscription ??= _battery.onBatteryStateChanged.listen(
          (BatteryState state) => _handleBatteryStateChange(state),
    );

    // Initial check
    await _checkBatteryLevel();
  }

  /// Check current battery level and adjust performance
  Future<void> _checkBatteryLevel() async {
    try {
      final batteryLevel = await _battery.batteryLevel;
      final batteryState = await _battery.batteryState;

      PerformanceLevel newLevel;

      if (batteryLevel <= criticalBatteryThreshold) {
        newLevel = PerformanceLevel.critical;
        // onBatteryWarning?.call('Critical battery level: ${batteryLevel}%. Switching to power saving mode.');
      } else if (batteryLevel <= lowBatteryThreshold) {
        newLevel = PerformanceLevel.low;
        // onBatteryWarning?.call('Low battery: ${batteryLevel}%. Reducing video quality to save power.');
      } else if (batteryLevel <= 50 && batteryState != BatteryState.charging) {
        newLevel = PerformanceLevel.medium;
      } else {
        newLevel = PerformanceLevel.high;
      }

      if (newLevel != _currentLevel) {
        _currentLevel = newLevel;
        onPerformanceLevelChanged?.call(newLevel);
      }
    } catch (e) {
      print('Error checking battery level: $e');
    }
  }

  /// Handle battery state changes (charging/discharging)
  void _handleBatteryStateChange(BatteryState state) {
    switch (state) {
      case BatteryState.charging:
      // When charging, we can use higher performance
        if (_currentLevel == PerformanceLevel.low ||
            _currentLevel == PerformanceLevel.critical) {
          _checkBatteryLevel(); // Re-evaluate performance level
        }
        break;
      case BatteryState.discharging:
      // When discharging, be more conservative
        _checkBatteryLevel();
        break;
      default:
        break;
    }
  }

  /// Get optimized video configuration based on performance level
  VideoEncoderConfiguration getOptimizedVideoConfig(PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.critical:
        return VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 320, height: 240),
          frameRate: 10,
          bitrate: 200,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainFramerate,
        );
      case PerformanceLevel.low:
        return VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 480, height: 360),
          frameRate: 12,
          bitrate: 300,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainFramerate,
        );
      case PerformanceLevel.medium:
        return VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 480),
          frameRate: 15,
          bitrate: 400,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainFramerate,
        );
      case PerformanceLevel.high:
      default:
        return VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 720, height: 540),
          frameRate: 20,
          bitrate: 600,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainFramerate,
        );
    }
  }

  /// Get optimized ping interval based on performance level
  Duration getOptimizedPingInterval(PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.critical:
        return const Duration(seconds: 120); // 2 minutes
      case PerformanceLevel.low:
        return const Duration(seconds: 90); // 1.5 minutes
      case PerformanceLevel.medium:
        return const Duration(seconds: 60); // 1 minute
      case PerformanceLevel.high:
      default:
        return const Duration(seconds: 60); // 1 minute
    }
  }

  /// Get optimized audio configuration based on performance level
  Map<String, dynamic> getOptimizedAudioConfig(PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.critical:
        return {
          'profile': AudioProfileType.audioProfileDefault,
          'scenario': AudioScenarioType.audioScenarioDefault,
          'sampleRate': 16000, // Lower sample rate for battery saving
          'channels': 1, // Mono audio
        };
      case PerformanceLevel.low:
        return {
          'profile': AudioProfileType.audioProfileSpeechStandard,
          'scenario': AudioScenarioType.audioScenarioDefault,
          'sampleRate': 32000,
          'channels': 1, // Mono audio
        };
      case PerformanceLevel.medium:
        return {
          'profile': AudioProfileType.audioProfileSpeechStandard,
          'scenario': AudioScenarioType.audioScenarioGameStreaming,
          'sampleRate': 44100,
          'channels': 2, // Stereo audio
        };
      case PerformanceLevel.high:
      default:
        return {
          'profile': AudioProfileType.audioProfileMusicHighQuality,
          'scenario': AudioScenarioType.audioScenarioGameStreaming,
          'sampleRate': 48000, // High quality sample rate
          'channels': 2, // Stereo audio
        };
    }
  }

  /// Check if device is overheating (Android only)
  Future<bool> isDeviceOverheating() async {
    if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        // This is a simplified check - in real implementation,
        // you might want to use native platform channels to get actual temperature
        return false; // Placeholder
      } catch (e) {
        print('Error checking device temperature: $e');
        return false;
      }
    }
    return false;
  }

  /// Apply optimizations to Agora engine
  Future<void> applyOptimizations(
      RtcEngine engine, PerformanceLevel level) async {
    try {
      final config = getOptimizedVideoConfig(level);
      await engine.setVideoEncoderConfiguration(config);

      // Additional optimizations based on performance level
      switch (level) {
        case PerformanceLevel.critical:
        // Disable video for audience to save maximum battery
          await engine.enableLocalVideo(false);
          break;
        case PerformanceLevel.low:
        // Reduce audio quality
          await engine.setAudioProfile(
            profile: AudioProfileType.audioProfileDefault,
            scenario: AudioScenarioType.audioScenarioDefault,
          );
          break;
        case PerformanceLevel.medium:
        case PerformanceLevel.high:
        // Normal settings
          break;
      }
    } catch (e) {
      print('Error applying optimizations: $e');
    }
  }

  /// Get current performance level
  PerformanceLevel get currentLevel => _currentLevel;

  /// Get current battery level
  Future<int> getCurrentBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      print('Error getting battery level: $e');
      return 100; // Default to full battery if error
    }
  }

  /// Get performance level based on battery level
  PerformanceLevel getPerformanceLevel(int batteryLevel) {
    if (batteryLevel <= criticalBatteryThreshold) {
      return PerformanceLevel.critical;
    } else if (batteryLevel <= lowBatteryThreshold) {
      return PerformanceLevel.low;
    } else if (batteryLevel <= 50) {
      return PerformanceLevel.medium;
    } else {
      return PerformanceLevel.high;
    }
  }

  /// Dispose resources
  void dispose() {
    _batteryMonitorTimer?.cancel();
    _batteryStateSubscription?.cancel();
    _batteryMonitorTimer = null;
    _batteryStateSubscription = null;
  }
}
