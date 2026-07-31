import 'dart:math';
import 'package:flutter/foundation.dart';

// ISO 31-band equalizer frequencies (20Hz to 20kHz)
const List<double> _iso31BandFrequencies = [
  20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160,
  200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600,
  2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000, 20000
];

enum EqualizerMode {
  basic10,    // Current 10-band
  advanced31, // ISO 31-band
}

class EqualizerBand {
  final double frequency;
  double gain;       // -15dB to +15dB
  double bandwidth; // Q factor related (0.1 to 5.0 octaves)
  
  EqualizerBand({
    required this.frequency,
    this.gain = 0.0,
    this.bandwidth = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'frequency': frequency,
    'gain': gain,
    'bandwidth': bandwidth,
  };

  factory EqualizerBand.fromJson(Map<String, dynamic> json) => EqualizerBand(
    frequency: json['frequency'] as double,
    gain: json['gain'] as double,
    bandwidth: json['bandwidth'] as double,
  );
}

class EqualizerPreset {
  final String name;
  final List<double> gains;
  final String? description;
  
  EqualizerPreset({
    required this.name,
    required this.gains,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'gains': gains,
    'description': description,
  };

  factory EqualizerPreset.fromJson(Map<String, dynamic> json) => EqualizerPreset(
    name: json['name'] as String,
    gains: (json['gains'] as List).cast<double>(),
    description: json['description'] as String?,
  );
}

class AdvancedEqualizerService {
  static AdvancedEqualizerService? _instance;
  static AdvancedEqualizerService get instance => 
      _instance ??= AdvancedEqualizerService._();
  
  AdvancedEqualizerService._();

  EqualizerMode _currentMode = EqualizerMode.basic10;
  final List<EqualizerBand> _bands = [];
  final List<EqualizerPreset> _presets = [];
  EqualizerPreset? _currentPreset;
  bool _isEnabled = false;

  EqualizerMode get currentMode => _currentMode;
  List<EqualizerBand> get bands => List.unmodifiable(_bands);
  List<EqualizerPreset> get presets => List.unmodifiable(_presets);
  EqualizerPreset? get currentPreset => _currentPreset;
  bool get isEnabled => _isEnabled;

  void initialize() {
    _initializeBands();
    _initializePresets();
    debugPrint('Advanced equalizer service initialized');
  }

  void _initializeBands() {
    _bands.clear();
    
    switch (_currentMode) {
      case EqualizerMode.basic10:
        // Current 10-band frequencies
        final basicFreqs = [32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0];
        for (final freq in basicFreqs) {
          _bands.add(EqualizerBand(frequency: freq));
        }
        break;
        
      case EqualizerMode.advanced31:
        // ISO 31-band frequencies
        for (final freq in _iso31BandFrequencies) {
          _bands.add(EqualizerBand(frequency: freq));
        }
        break;
    }
  }

  void _initializePresets() {
    _presets.clear();
    
    final int bandCount = _currentMode == EqualizerMode.basic10 ? 10 : 31;
    
    // Basic presets (10-band compatible)
    _presets.addAll([
      EqualizerPreset(
        name: 'Flat',
        gains: List.filled(bandCount, 0.0),
        description: 'No frequency adjustment',
      ),
      EqualizerPreset(
        name: 'Bass Boost',
        gains: _generatePresetGains(bandCount, 'bass_boost'),
        description: 'Enhanced low frequencies',
      ),
      EqualizerPreset(
        name: 'Treble Boost',
        gains: _generatePresetGains(bandCount, 'treble_boost'),
        description: 'Enhanced high frequencies',
      ),
      EqualizerPreset(
        name: 'Vocal',
        gains: _generatePresetGains(bandCount, 'vocal'),
        description: 'Enhanced vocal frequencies',
      ),
      EqualizerPreset(
        name: 'Rock',
        gains: _generatePresetGains(bandCount, 'rock'),
        description: 'Rock music optimization',
      ),
      EqualizerPreset(
        name: 'Electronic',
        gains: _generatePresetGains(bandCount, 'electronic'),
        description: 'Electronic music optimization',
      ),
      EqualizerPreset(
        name: 'Classical',
        gains: _generatePresetGains(bandCount, 'classical'),
        description: 'Classical music optimization',
      ),
      EqualizerPreset(
        name: 'Jazz',
        gains: _generatePresetGains(bandCount, 'jazz'),
        description: 'Jazz music optimization',
      ),
    ]);

    // Advanced presets for 31-band mode
    if (_currentMode == EqualizerMode.advanced31) {
      _presets.addAll([
        EqualizerPreset(
          name: 'Audiophile',
          gains: _generateAudiophilePreset(),
          description: 'Flat response with subtle enhancements',
        ),
        EqualizerPreset(
          name: 'Club',
          gains: _generateClubPreset(),
          description: 'Club/venue sound profile',
        ),
        EqualizerPreset(
          name: 'Live',
          gains: _generateLivePreset(),
          description: 'Live concert atmosphere',
        ),
      ]);
    }
  }

  List<double> _generatePresetGains(int bandCount, String presetType) {
    final gains = List<double>.filled(bandCount, 0.0);
    
    switch (presetType) {
      case 'bass_boost':
        for (int i = 0; i < min(3, bandCount); i++) {
          gains[i] = 6.0 - (i * 2.0);
        }
        break;
      case 'treble_boost':
        for (int i = max(0, bandCount - 3); i < bandCount; i++) {
          gains[i] = 4.0 + ((i - (bandCount - 3)) * 2.0);
        }
        break;
      case 'vocal':
        final midStart = (bandCount * 0.4).floor();
        final midEnd = (bandCount * 0.7).floor();
        for (int i = midStart; i <= midEnd && i < bandCount; i++) {
          gains[i] = 3.0;
        }
        break;
      case 'rock':
        gains[0] = 5.0;
        gains[1] = 4.0;
        gains[bandCount - 2] = 3.0;
        gains[bandCount - 1] = 4.0;
        break;
      case 'electronic':
        gains[0] = 6.0;
        gains[1] = 5.0;
        gains[bandCount - 3] = 2.0;
        gains[bandCount - 2] = 4.0;
        gains[bandCount - 1] = 5.0;
        break;
      case 'classical':
        for (int i = 2; i < min(5, bandCount); i++) {
          gains[i] = 2.0;
        }
        break;
      case 'jazz':
        gains[0] = 3.0;
        gains[1] = 2.0;
        final midStart = (bandCount * 0.4).floor();
        final midEnd = (bandCount * 0.6).floor();
        for (int i = midStart; i <= midEnd && i < bandCount; i++) {
          gains[i] = 2.0;
        }
        break;
    }
    
    return gains;
  }

  List<double> _generateAudiophilePreset() {
    // Subtle enhancement for critical frequencies
    return [
      0, 0, 1, 1, 0, 0, 0, 0, 0, 0,  // 20-200Hz
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 250-2kHz
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 2.5-8kHz
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 10-20kHz
      0,  // 20kHz
    ];
  }

  List<double> _generateClubPreset() {
    return [
      6, 5, 4, 3, 2, 1, 0, 0, 0, 0,  // Bass heavy
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
    ];
  }

  List<double> _generateLivePreset() {
    return [
      3, 2, 1, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
    ];
  }

  void setMode(EqualizerMode mode) {
    if (_currentMode == mode) return;
    
    _currentMode = mode;
    _initializeBands();
    _initializePresets();
    _currentPreset = null;
    debugPrint('Equalizer mode set to: $mode');
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('Equalizer ${enabled ? "enabled" : "disabled"}');
  }

  void setBandGain(int index, double gain) {
    if (index >= 0 && index < _bands.length) {
      _bands[index].gain = gain.clamp(-15.0, 15.0);
      _currentPreset = null; // Clear preset when manually adjusting
    }
  }

  void setBandBandwidth(int index, double bandwidth) {
    if (index >= 0 && index < _bands.length) {
      _bands[index].bandwidth = bandwidth.clamp(0.1, 5.0);
    }
  }

  void applyPreset(EqualizerPreset preset) {
    if (preset.gains.length != _bands.length) {
      debugPrint('Preset gain count mismatch');
      return;
    }

    for (int i = 0; i < _bands.length; i++) {
      _bands[i].gain = preset.gains[i].clamp(-15.0, 15.0);
    }
    
    _currentPreset = preset;
    debugPrint('Applied preset: ${preset.name}');
  }

  void reset() {
    for (final band in _bands) {
      band.gain = 0.0;
      band.bandwidth = 1.0;
    }
    _currentPreset = null;
    debugPrint('Equalizer reset to flat');
  }

  EqualizerPreset createCustomPreset(String name) {
    final gains = _bands.map((band) => band.gain).toList();
    final preset = EqualizerPreset(
      name: name,
      gains: gains,
      description: 'Custom preset',
    );
    
    _presets.add(preset);
    _currentPreset = preset;
    
    return preset;
  }

  void deletePreset(EqualizerPreset preset) {
    _presets.remove(preset);
    if (_currentPreset == preset) {
      _currentPreset = null;
    }
  }

  List<double> getCurrentGains() {
    return _bands.map((band) => band.gain).toList();
  }

  Map<String, dynamic> getSettings() {
    return {
      'mode': _currentMode.toString(),
      'isEnabled': _isEnabled,
      'currentPreset': _currentPreset?.name,
      'bands': _bands.map((band) => band.toJson()).toList(),
    };
  }

  void applySettings(Map<String, dynamic> settings) {
    final modeStr = settings['mode'] as String?;
    if (modeStr != null) {
      _currentMode = EqualizerMode.values.firstWhere(
        (e) => e.toString() == modeStr,
        orElse: () => EqualizerMode.basic10,
      );
      _initializeBands();
    }

    _isEnabled = settings['isEnabled'] as bool? ?? false;

    final bandsData = settings['bands'] as List?;
    if (bandsData != null) {
      for (int i = 0; i < min(bandsData.length, _bands.length); i++) {
        final bandData = bandsData[i] as Map<String, dynamic>;
        _bands[i].gain = bandData['gain'] as double? ?? 0.0;
        _bands[i].bandwidth = bandData['bandwidth'] as double? ?? 1.0;
      }
    }
  }
}