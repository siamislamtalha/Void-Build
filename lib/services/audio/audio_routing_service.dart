import 'dart:io';
import 'package:flutter/foundation.dart';

class AudioDevice {
  final String id;
  final String name;
  final String type; // 'speaker', 'headphone', 'bluetooth', 'usb', etc.
  final bool isDefault;
  
  AudioDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'isDefault': isDefault,
  };

  factory AudioDevice.fromJson(Map<String, dynamic> json) => AudioDevice(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    isDefault: json['isDefault'] as bool? ?? false,
  );

  @override
  String toString() => name;
}

class AudioRoutingService {
  static AudioRoutingService? _instance;
  static AudioRoutingService get instance => 
      _instance ??= AudioRoutingService._();
  
  AudioRoutingService._();

  final List<AudioDevice> _availableDevices = [];
  AudioDevice? _currentDevice;
  bool _isEnabled = false;

  List<AudioDevice> get availableDevices => List.unmodifiable(_availableDevices);
  AudioDevice? get currentDevice => _currentDevice;
  bool get isEnabled => _isEnabled;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled) {
      _initializeInternal();
    }
    debugPrint('Audio routing ${enabled ? "enabled" : "disabled"}');
  }

  Future<void> initialize() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      debugPrint('Audio routing only supported on desktop platforms');
      return;
    }

    await _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      debugPrint('Audio routing only supported on desktop platforms');
      return;
    }

    try {
      await _enumerateDevices();
      debugPrint('Audio routing service initialized');
    } catch (e) {
      debugPrint('Error initializing audio routing: $e');
    }
  }

  Future<void> _enumerateDevices() async {
    _availableDevices.clear();

    // Platform-specific device enumeration
    if (Platform.isWindows) {
      await _enumerateWindowsDevices();
    } else if (Platform.isLinux) {
      await _enumerateLinuxDevices();
    } else if (Platform.isMacOS) {
      await _enumerateMacOSDevices();
    }

    // Set default device
    if (_availableDevices.isNotEmpty) {
      _currentDevice = _availableDevices.firstWhere(
        (device) => device.isDefault,
        orElse: () => _availableDevices.first,
      );
    }

    debugPrint('Found ${_availableDevices.length} audio devices');
  }

  Future<void> _enumerateWindowsDevices() async {
    try {
      // Use Windows Core Audio APIs through platform channel
      // For now, provide enhanced placeholder with more realistic device detection
      
      _availableDevices.clear();
      
      // Default output device
      _availableDevices.add(AudioDevice(
        id: 'default_output',
        name: 'Default Output Device',
        type: 'speaker',
        isDefault: true,
      ));
      
      // Common Windows audio devices
      _availableDevices.addAll([
        AudioDevice(
          id: 'speakers',
          name: 'Speakers',
          type: 'speaker',
        ),
        AudioDevice(
          id: 'headphones',
          name: 'Headphones',
          type: 'headphone',
        ),
        AudioDevice(
          id: 'digital_output',
          name: 'Digital Output (S/PDIF)',
          type: 'speaker',
        ),
        AudioDevice(
          id: 'bluetooth_audio',
          name: 'Bluetooth Audio',
          type: 'bluetooth',
        ),
      ]);
      
      debugPrint('Enumerated ${_availableDevices.length} Windows audio devices');
    } catch (e) {
      debugPrint('Error enumerating Windows devices: $e');
      // Fallback to default device
      _availableDevices.add(AudioDevice(
        id: 'default_output',
        name: 'Default Output',
        type: 'speaker',
        isDefault: true,
      ));
    }
  }

  Future<void> _enumerateLinuxDevices() async {
    try {
      // Use PulseAudio or ALSA through platform channel
      // For now, provide enhanced placeholder with common Linux audio devices
      
      _availableDevices.clear();
      
      // Default output device
      _availableDevices.add(AudioDevice(
        id: 'default_output',
        name: 'Default Output Device',
        type: 'speaker',
        isDefault: true,
      ));
      
      // Common Linux audio devices
      _availableDevices.addAll([
        AudioDevice(
          id: 'analog_stereo',
          name: 'Analog Stereo Output',
          type: 'speaker',
        ),
        AudioDevice(
          id: 'hdmi_output',
          name: 'HDMI Output',
          type: 'speaker',
        ),
        AudioDevice(
          id: 'usb_audio',
          name: 'USB Audio Device',
          type: 'speaker',
        ),
        AudioDevice(
          id: 'bluetooth_speakers',
          name: 'Bluetooth Speakers',
          type: 'bluetooth',
        ),
      ]);
      
      debugPrint('Enumerated ${_availableDevices.length} Linux audio devices');
    } catch (e) {
      debugPrint('Error enumerating Linux devices: $e');
      // Fallback to default device
      _availableDevices.add(AudioDevice(
        id: 'default_output',
        name: 'Default Output',
        type: 'speaker',
        isDefault: true,
      ));
    }
  }

  Future<void> _enumerateMacOSDevices() async {
    try {
      // Use Core Audio through platform channel
      // For now, provide enhanced placeholder with common macOS audio devices
      
      _availableDevices.clear();
      
      // Default output device
      _availableDevices.add(AudioDevice(
        id: 'built_in_output',
        name: 'Built-in Output',
        type: 'speaker',
        isDefault: true,
      ));
      
      // Common macOS audio devices
      _availableDevices.addAll([
        AudioDevice(
          id: 'built_in_speakers',
          name: 'Built-in Speakers',
          type: 'speaker',
        ),
        AudioDevice(
          id: 'headphones',
          name: 'Headphones',
          type: 'headphone',
        ),
        AudioDevice(
          id: 'airplay_speakers',
          name: 'AirPlay Speakers',
          type: 'speaker',
        ),
        AudioDevice(
          id: 'external_display',
          name: 'External Display Audio',
          type: 'speaker',
        ),
        AudioDevice(
          id: 'usb_audio_interface',
          name: 'USB Audio Interface',
          type: 'speaker',
        ),
      ]);
      
      debugPrint('Enumerated ${_availableDevices.length} macOS audio devices');
    } catch (e) {
      debugPrint('Error enumerating macOS devices: $e');
      // Fallback to default device
      _availableDevices.add(AudioDevice(
        id: 'built_in_output',
        name: 'Built-in Output',
        type: 'speaker',
        isDefault: true,
      ));
    }
  }

  Future<bool> switchToDevice(AudioDevice device) async {
    try {
      // Platform-specific device switching
      if (Platform.isWindows) {
        return await _switchWindowsDevice(device);
      } else if (Platform.isLinux) {
        return await _switchLinuxDevice(device);
      } else if (Platform.isMacOS) {
        return await _switchMacOSDevice(device);
      }
      
      return false;
    } catch (e) {
      debugPrint('Error switching audio device: $e');
      return false;
    }
  }

  Future<bool> _switchWindowsDevice(AudioDevice device) async {
    try {
      // Implement Windows device switching using Core Audio APIs
      // This would require platform channels to communicate with Windows audio subsystem
      
      _currentDevice = device;
      debugPrint('Switched to Windows device: ${device.name}');
      
      // TODO: Add actual Windows API call through platform channel
      // Example: await _windowsAudioChannel.invokeMethod('setDevice', {'id': device.id});
      
      return true;
    } catch (e) {
      debugPrint('Error switching Windows device: $e');
      return false;
    }
  }

  Future<bool> _switchLinuxDevice(AudioDevice device) async {
    try {
      // Implement Linux device switching using PulseAudio/ALSA
      // This would require platform channels to communicate with PulseAudio
      
      _currentDevice = device;
      debugPrint('Switched to Linux device: ${device.name}');
      
      // TODO: Add actual Linux API call through platform channel
      // Example: await _linuxAudioChannel.invokeMethod('setDevice', {'id': device.id});
      
      return true;
    } catch (e) {
      debugPrint('Error switching Linux device: $e');
      return false;
    }
  }

  Future<bool> _switchMacOSDevice(AudioDevice device) async {
    try {
      // Implement macOS device switching using Core Audio
      // This would require platform channels to communicate with Core Audio
      
      _currentDevice = device;
      debugPrint('Switched to macOS device: ${device.name}');
      
      // TODO: Add actual macOS API call through platform channel
      // Example: await _macOSAudioChannel.invokeMethod('setDevice', {'id': device.id});
      
      return true;
    } catch (e) {
      debugPrint('Error switching macOS device: $e');
      return false;
    }
  }

  Future<void> refreshDevices() async {
    await _enumerateDevices();
  }

  Map<String, dynamic> getSettings() {
    return {
      'isEnabled': _isEnabled,
      'currentDevice': _currentDevice?.toJson(),
      'availableDevices': _availableDevices.map((d) => d.toJson()).toList(),
    };
  }
}