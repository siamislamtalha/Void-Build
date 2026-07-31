import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum AudioEffectType {
  reverb,
  bassBoost,
  trebleBoost,
  vocalEnhancer,
  spatial3D,
  compressor,
  limiter,
  stereoWidth,
  surround,
}

enum ReverbPreset {
  smallRoom,
  mediumRoom,
  largeHall,
  cathedral,
  plate,
  spring,
}

enum SpatialMode {
  stereo,
  binaural,
  surround5_1,
  surround7_1,
  ambisonics,
}

class AudioEffect {
  final AudioEffectType type;
  double intensity; // 0.0 to 1.0
  bool isEnabled;
  
  // Advanced parameters
  Map<String, double> customParameters;
  int order; // Effect processing order
  String? customPresetName;

  AudioEffect({
    required this.type,
    this.intensity = 0.5,
    this.isEnabled = false,
    Map<String, double>? customParameters,
    this.order = 0,
    this.customPresetName,
  }) : customParameters = customParameters ?? _getDefaultParameters(type);

  static Map<String, double> _getDefaultParameters(AudioEffectType type) {
    switch (type) {
      case AudioEffectType.reverb:
        return {
          'room_size': 0.5,
          'decay_time': 1.5,
          'damping': 0.5,
          'wet_dry_mix': 0.3,
          'pre_delay': 0.0,
        };
      case AudioEffectType.bassBoost:
        return {
          'gain': 6.0,
          'frequency': 100.0,
          'bandwidth': 1.0,
          'q_factor': 1.0,
        };
      case AudioEffectType.trebleBoost:
        return {
          'gain': 5.0,
          'frequency': 8000.0,
          'bandwidth': 1.0,
          'q_factor': 1.0,
        };
      case AudioEffectType.vocalEnhancer:
        return {
          'gain': 3.0,
          'frequency': 2000.0,
          'bandwidth': 2.0,
          'presence': 0.5,
        };
      case AudioEffectType.spatial3D:
        return {
          'width': 1.0,
          'depth': 0.5,
          'elevation': 0.0,
          'room_size': 0.5,
        };
      case AudioEffectType.compressor:
        return {
          'threshold': -20.0,
          'ratio': 4.0,
          'attack': 0.01,
          'release': 0.1,
          'makeup_gain': 0.0,
        };
      case AudioEffectType.limiter:
        return {
          'threshold': -0.1,
          'release': 0.05,
          'lookahead': 0.005,
        };
      case AudioEffectType.stereoWidth:
        return {
          'width': 1.0,
          'mid_gain': 0.0,
          'side_gain': 0.0,
        };
      case AudioEffectType.surround:
        return {
          'rear_level': 0.5,
          'center_level': 0.7,
          'lfe_level': 0.8,
        };
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'intensity': intensity,
    'isEnabled': isEnabled,
    'customParameters': customParameters,
    'order': order,
    'customPresetName': customPresetName,
  };

  factory AudioEffect.fromJson(Map<String, dynamic> json) => AudioEffect(
    type: AudioEffectType.values.firstWhere(
      (e) => e.toString() == json['type'],
    ),
    intensity: json['intensity'] as double? ?? 0.5,
    isEnabled: json['isEnabled'] as bool? ?? false,
    customParameters: (json['customParameters'] as Map<String, dynamic>?)
        ?.map((key, value) => MapEntry(key, (value as num).toDouble())) ??
        _getDefaultParameters(AudioEffectType.reverb),
    order: json['order'] as int? ?? 0,
    customPresetName: json['customPresetName'] as String?,
  );
}

class AudioEffectsService {
  static AudioEffectsService? _instance;
  static AudioEffectsService get instance =>
      _instance ??= AudioEffectsService._();

  AudioEffectsService._() {
    initialize();
    _loadCustomPresets();
  }

  final Map<AudioEffectType, AudioEffect> _effects = {};
  bool _globalEnabled = false;
  ReverbPreset _currentReverbPreset = ReverbPreset.mediumRoom;
  SpatialMode _spatialMode = SpatialMode.stereo;
  
  // Custom presets
  final Map<String, Map<AudioEffectType, AudioEffect>> _customPresets = {};
  String? _currentPresetName;
  
  // Effect processing chain
  final List<AudioEffectType> _effectChain = [];
  
  // Real-time parameter adjustment
  final StreamController<Map<String, double>> _parameterController =
      StreamController<Map<String, double>>.broadcast();

  bool get globalEnabled => _globalEnabled;
  Map<AudioEffectType, AudioEffect> get effects => Map.unmodifiable(_effects);
  ReverbPreset get currentReverbPreset => _currentReverbPreset;
  SpatialMode get spatialMode => _spatialMode;
  String? get currentPresetName => _currentPresetName;
  Stream<Map<String, double>> get parameterStream => _parameterController.stream;

  void initialize() {
    // Initialize all available effects
    for (final type in AudioEffectType.values) {
      _effects[type] = AudioEffect(type: type, order: _effects.length);
      _effectChain.add(type);
    }
    debugPrint('Audio effects service initialized with ${_effects.length} effects');
  }

  void setGlobalEnabled(bool enabled) {
    _globalEnabled = enabled;
    debugPrint('Audio effects globally ${enabled ? "enabled" : "disabled"}');
  }

  void setEffectEnabled(AudioEffectType type, bool enabled) {
    if (_effects.containsKey(type)) {
      _effects[type]!.isEnabled = enabled;
      _notifyParameterChange();
      debugPrint('$type effect ${enabled ? "enabled" : "disabled"}');
    }
  }

  void setEffectIntensity(AudioEffectType type, double intensity) {
    if (_effects.containsKey(type)) {
      _effects[type]!.intensity = intensity.clamp(0.0, 1.0);
      _notifyParameterChange();
      debugPrint('$type intensity set to: $intensity');
    }
  }

  void setEffectParameter(AudioEffectType type, String parameter, double value) {
    if (_effects.containsKey(type)) {
      _effects[type]!.customParameters[parameter] = value;
      _notifyParameterChange();
      debugPrint('$type parameter $parameter set to: $value');
    }
  }

  void setReverbPreset(ReverbPreset preset) {
    _currentReverbPreset = preset;
    _applyReverbPreset(preset);
    debugPrint('Reverb preset set to: $preset');
  }

  void setSpatialMode(SpatialMode mode) {
    _spatialMode = mode;
    _applySpatialMode(mode);
    debugPrint('Spatial mode set to: $mode');
  }

  void _applyReverbPreset(ReverbPreset preset) {
    final reverbEffect = _effects[AudioEffectType.reverb];
    if (reverbEffect == null) return;

    switch (preset) {
      case ReverbPreset.smallRoom:
        reverbEffect.customParameters['room_size'] = 0.3;
        reverbEffect.customParameters['decay_time'] = 0.8;
        reverbEffect.customParameters['damping'] = 0.7;
        break;
      case ReverbPreset.mediumRoom:
        reverbEffect.customParameters['room_size'] = 0.5;
        reverbEffect.customParameters['decay_time'] = 1.5;
        reverbEffect.customParameters['damping'] = 0.5;
        break;
      case ReverbPreset.largeHall:
        reverbEffect.customParameters['room_size'] = 0.8;
        reverbEffect.customParameters['decay_time'] = 3.0;
        reverbEffect.customParameters['damping'] = 0.3;
        break;
      case ReverbPreset.cathedral:
        reverbEffect.customParameters['room_size'] = 1.0;
        reverbEffect.customParameters['decay_time'] = 5.0;
        reverbEffect.customParameters['damping'] = 0.2;
        break;
      case ReverbPreset.plate:
        reverbEffect.customParameters['room_size'] = 0.6;
        reverbEffect.customParameters['decay_time'] = 2.0;
        reverbEffect.customParameters['damping'] = 0.4;
        break;
      case ReverbPreset.spring:
        reverbEffect.customParameters['room_size'] = 0.4;
        reverbEffect.customParameters['decay_time'] = 1.2;
        reverbEffect.customParameters['damping'] = 0.6;
        break;
    }
    _notifyParameterChange();
  }

  void _applySpatialMode(SpatialMode mode) {
    final spatialEffect = _effects[AudioEffectType.spatial3D];
    if (spatialEffect == null) return;

    switch (mode) {
      case SpatialMode.stereo:
        spatialEffect.customParameters['width'] = 1.0;
        spatialEffect.customParameters['depth'] = 0.5;
        spatialEffect.customParameters['elevation'] = 0.0;
        break;
      case SpatialMode.binaural:
        spatialEffect.customParameters['width'] = 1.5;
        spatialEffect.customParameters['depth'] = 0.8;
        spatialEffect.customParameters['elevation'] = 0.3;
        break;
      case SpatialMode.surround5_1:
        spatialEffect.customParameters['width'] = 2.0;
        spatialEffect.customParameters['depth'] = 1.0;
        spatialEffect.customParameters['elevation'] = 0.2;
        break;
      case SpatialMode.surround7_1:
        spatialEffect.customParameters['width'] = 2.5;
        spatialEffect.customParameters['depth'] = 1.2;
        spatialEffect.customParameters['elevation'] = 0.4;
        break;
      case SpatialMode.ambisonics:
        spatialEffect.customParameters['width'] = 3.0;
        spatialEffect.customParameters['depth'] = 1.5;
        spatialEffect.customParameters['elevation'] = 0.5;
        break;
    }
    _notifyParameterChange();
  }

  void setEffectOrder(AudioEffectType type, int newOrder) {
    if (_effects.containsKey(type)) {
      _effects[type]!.order = newOrder;
      _reorderEffectChain();
      debugPrint('$type order set to: $newOrder');
    }
  }

  void _reorderEffectChain() {
    _effectChain.sort((a, b) {
      final orderA = _effects[a]?.order ?? 0;
      final orderB = _effects[b]?.order ?? 0;
      return orderA.compareTo(orderB);
    });
  }

  AudioEffect? getEffect(AudioEffectType type) {
    return _effects[type];
  }

  bool isEffectEnabled(AudioEffectType type) {
    return _globalEnabled &&
           _effects.containsKey(type) &&
           _effects[type]!.isEnabled;
  }

  void resetAllEffects() {
    for (final effect in _effects.values) {
      effect.isEnabled = false;
      effect.intensity = 0.5;
      effect.customParameters = AudioEffect._getDefaultParameters(effect.type);
    }
    _currentPresetName = null;
    debugPrint('All audio effects reset');
  }

  void _notifyParameterChange() {
    _parameterController.add(getProcessingParameters());
  }

  // Get audio processing parameters for the current effects
  Map<String, double> getProcessingParameters() {
    if (!_globalEnabled) return {};

    final params = <String, double>{};

    // Process effects in order
    for (final type in _effectChain) {
      final effect = _effects[type];
      if (effect == null || !effect.isEnabled) continue;

      switch (effect.type) {
        case AudioEffectType.reverb:
          params['reverb_mix'] = effect.customParameters['wet_dry_mix'] ?? (effect.intensity * 0.4);
          params['reverb_decay'] = effect.customParameters['decay_time'] ?? (1.5 + effect.intensity * 2.0);
          params['reverb_room_size'] = effect.customParameters['room_size'] ?? 0.5;
          params['reverb_damping'] = effect.customParameters['damping'] ?? 0.5;
          params['reverb_pre_delay'] = effect.customParameters['pre_delay'] ?? 0.0;
          break;

        case AudioEffectType.bassBoost:
          params['bass_gain'] = effect.customParameters['gain'] ?? (effect.intensity * 12.0);
          params['bass_frequency'] = effect.customParameters['frequency'] ?? 100.0;
          params['bass_bandwidth'] = effect.customParameters['bandwidth'] ?? 1.0;
          params['bass_q_factor'] = effect.customParameters['q_factor'] ?? 1.0;
          break;

        case AudioEffectType.trebleBoost:
          params['treble_gain'] = effect.customParameters['gain'] ?? (effect.intensity * 10.0);
          params['treble_frequency'] = effect.customParameters['frequency'] ?? 8000.0;
          params['treble_bandwidth'] = effect.customParameters['bandwidth'] ?? 1.0;
          params['treble_q_factor'] = effect.customParameters['q_factor'] ?? 1.0;
          break;

        case AudioEffectType.vocalEnhancer:
          params['vocal_gain'] = effect.customParameters['gain'] ?? (effect.intensity * 6.0);
          params['vocal_frequency'] = effect.customParameters['frequency'] ?? 2000.0;
          params['vocal_bandwidth'] = effect.customParameters['bandwidth'] ?? 2.0;
          params['vocal_presence'] = effect.customParameters['presence'] ?? 0.5;
          break;

        case AudioEffectType.spatial3D:
          params['spatial_width'] = effect.customParameters['width'] ?? (effect.intensity * 2.0);
          params['spatial_depth'] = effect.customParameters['depth'] ?? (effect.intensity * 1.5);
          params['spatial_elevation'] = effect.customParameters['elevation'] ?? 0.0;
          params['spatial_room_size'] = effect.customParameters['room_size'] ?? 0.5;
          break;

        case AudioEffectType.compressor:
          params['comp_threshold'] = effect.customParameters['threshold'] ?? -20.0;
          params['comp_ratio'] = effect.customParameters['ratio'] ?? 4.0;
          params['comp_attack'] = effect.customParameters['attack'] ?? 0.01;
          params['comp_release'] = effect.customParameters['release'] ?? 0.1;
          params['comp_makeup_gain'] = effect.customParameters['makeup_gain'] ?? 0.0;
          break;

        case AudioEffectType.limiter:
          params['lim_threshold'] = effect.customParameters['threshold'] ?? -0.1;
          params['lim_release'] = effect.customParameters['release'] ?? 0.05;
          params['lim_lookahead'] = effect.customParameters['lookahead'] ?? 0.005;
          break;

        case AudioEffectType.stereoWidth:
          params['stereo_width'] = effect.customParameters['width'] ?? 1.0;
          params['stereo_mid_gain'] = effect.customParameters['mid_gain'] ?? 0.0;
          params['stereo_side_gain'] = effect.customParameters['side_gain'] ?? 0.0;
          break;

        case AudioEffectType.surround:
          params['surround_rear_level'] = effect.customParameters['rear_level'] ?? 0.5;
          params['surround_center_level'] = effect.customParameters['center_level'] ?? 0.7;
          params['surround_lfe_level'] = effect.customParameters['lfe_level'] ?? 0.8;
          break;
      }
    }

    return params;
  }

  // Enhanced preset combinations
  void applyPreset(String presetName) {
    resetAllEffects();
    _currentPresetName = presetName;

    switch (presetName.toLowerCase()) {
      case 'concert':
        _effects[AudioEffectType.reverb]!.isEnabled = true;
        _effects[AudioEffectType.reverb]!.intensity = 0.7;
        _effects[AudioEffectType.reverb]!.customParameters['room_size'] = 0.8;
        _effects[AudioEffectType.reverb]!.customParameters['decay_time'] = 2.5;
        _effects[AudioEffectType.spatial3D]!.isEnabled = true;
        _effects[AudioEffectType.spatial3D]!.intensity = 0.5;
        _effects[AudioEffectType.spatial3D]!.customParameters['width'] = 1.5;
        _effects[AudioEffectType.compressor]!.isEnabled = true;
        _effects[AudioEffectType.compressor]!.intensity = 0.3;
        break;

      case 'club':
        _effects[AudioEffectType.bassBoost]!.isEnabled = true;
        _effects[AudioEffectType.bassBoost]!.intensity = 0.8;
        _effects[AudioEffectType.bassBoost]!.customParameters['gain'] = 10.0;
        _effects[AudioEffectType.reverb]!.isEnabled = true;
        _effects[AudioEffectType.reverb]!.intensity = 0.4;
        _effects[AudioEffectType.reverb]!.customParameters['room_size'] = 0.6;
        _effects[AudioEffectType.compressor]!.isEnabled = true;
        _effects[AudioEffectType.compressor]!.intensity = 0.5;
        _effects[AudioEffectType.compressor]!.customParameters['ratio'] = 6.0;
        break;

      case 'vocal':
        _effects[AudioEffectType.vocalEnhancer]!.isEnabled = true;
        _effects[AudioEffectType.vocalEnhancer]!.intensity = 0.6;
        _effects[AudioEffectType.vocalEnhancer]!.customParameters['presence'] = 0.7;
        _effects[AudioEffectType.reverb]!.isEnabled = true;
        _effects[AudioEffectType.reverb]!.intensity = 0.2;
        _effects[AudioEffectType.reverb]!.customParameters['room_size'] = 0.3;
        _effects[AudioEffectType.compressor]!.isEnabled = true;
        _effects[AudioEffectType.compressor]!.intensity = 0.4;
        break;

      case 'bass':
        _effects[AudioEffectType.bassBoost]!.isEnabled = true;
        _effects[AudioEffectType.bassBoost]!.intensity = 0.9;
        _effects[AudioEffectType.bassBoost]!.customParameters['gain'] = 12.0;
        _effects[AudioEffectType.bassBoost]!.customParameters['frequency'] = 80.0;
        _effects[AudioEffectType.limiter]!.isEnabled = true;
        _effects[AudioEffectType.limiter]!.intensity = 0.3;
        break;

      case 'immersive':
        _effects[AudioEffectType.spatial3D]!.isEnabled = true;
        _effects[AudioEffectType.spatial3D]!.intensity = 0.8;
        _effects[AudioEffectType.spatial3D]!.customParameters['width'] = 2.0;
        _effects[AudioEffectType.spatial3D]!.customParameters['depth'] = 1.0;
        _effects[AudioEffectType.reverb]!.isEnabled = true;
        _effects[AudioEffectType.reverb]!.intensity = 0.3;
        _effects[AudioEffectType.reverb]!.customParameters['room_size'] = 0.7;
        _effects[AudioEffectType.surround]!.isEnabled = true;
        _effects[AudioEffectType.surround]!.intensity = 0.4;
        break;

      case 'studio':
        _effects[AudioEffectType.compressor]!.isEnabled = true;
        _effects[AudioEffectType.compressor]!.intensity = 0.5;
        _effects[AudioEffectType.compressor]!.customParameters['ratio'] = 3.0;
        _effects[AudioEffectType.limiter]!.isEnabled = true;
        _effects[AudioEffectType.limiter]!.intensity = 0.4;
        _effects[AudioEffectType.stereoWidth]!.isEnabled = true;
        _effects[AudioEffectType.stereoWidth]!.intensity = 0.3;
        break;

      case 'cinema':
        _effects[AudioEffectType.spatial3D]!.isEnabled = true;
        _effects[AudioEffectType.spatial3D]!.intensity = 0.9;
        _effects[AudioEffectType.spatial3D]!.customParameters['width'] = 2.5;
        _effects[AudioEffectType.spatial3D]!.customParameters['depth'] = 1.2;
        _effects[AudioEffectType.reverb]!.isEnabled = true;
        _effects[AudioEffectType.reverb]!.intensity = 0.5;
        _effects[AudioEffectType.reverb]!.customParameters['room_size'] = 0.9;
        _effects[AudioEffectType.surround]!.isEnabled = true;
        _effects[AudioEffectType.surround]!.intensity = 0.7;
        break;
    }

    _notifyParameterChange();
    debugPrint('Applied audio effects preset: $presetName');
  }

  // Custom preset management
  void saveCustomPreset(String name) {
    final presetEffects = <AudioEffectType, AudioEffect>{};
    for (final entry in _effects.entries) {
      presetEffects[entry.key] = AudioEffect(
        type: entry.value.type,
        intensity: entry.value.intensity,
        isEnabled: entry.value.isEnabled,
        customParameters: Map.from(entry.value.customParameters),
        order: entry.value.order,
        customPresetName: name,
      );
    }
    _customPresets[name] = presetEffects;
    _persistCustomPresets();
    debugPrint('Saved custom preset: $name');
  }

  void loadCustomPreset(String name) {
    if (!_customPresets.containsKey(name)) {
      debugPrint('Custom preset not found: $name');
      return;
    }

    resetAllEffects();
    final presetEffects = _customPresets[name]!;
    
    for (final entry in presetEffects.entries) {
      if (_effects.containsKey(entry.key)) {
        _effects[entry.key]!.isEnabled = entry.value.isEnabled;
        _effects[entry.key]!.intensity = entry.value.intensity;
        _effects[entry.key]!.customParameters = Map.from(entry.value.customParameters);
        _effects[entry.key]!.order = entry.value.order;
      }
    }

    _currentPresetName = name;
    _notifyParameterChange();
    debugPrint('Loaded custom preset: $name');
  }

  void deleteCustomPreset(String name) {
    _customPresets.remove(name);
    _persistCustomPresets();
    debugPrint('Deleted custom preset: $name');
  }

  List<String> getCustomPresetNames() {
    return _customPresets.keys.toList();
  }

  Future<void> _loadCustomPresets() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final presetFile = File('${directory.path}/audio_effects_presets.json');
      
      if (await presetFile.exists()) {
        final jsonString = await presetFile.readAsString();
        final presetData = json.decode(jsonString) as Map<String, dynamic>;
        
        presetData.forEach((name, effectsData) {
          final presetEffects = <AudioEffectType, AudioEffect>{};
          
          effectsData.forEach((key, value) {
            final type = AudioEffectType.values.firstWhere(
              (e) => e.toString() == key,
              orElse: () => AudioEffectType.reverb,
            );
            
            final effectData = value as Map<String, dynamic>;
            presetEffects[type] = AudioEffect(
              type: type,
              intensity: effectData['intensity'] as double? ?? 0.5,
              isEnabled: effectData['isEnabled'] as bool? ?? false,
              customParameters: (effectData['customParameters'] as Map<String, dynamic>?)
                  ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
                  AudioEffect._getDefaultParameters(type),
              order: effectData['order'] as int? ?? 0,
              customPresetName: name,
            );
          });
          
          _customPresets[name] = presetEffects;
        });
        
        debugPrint('Loaded ${_customPresets.length} custom presets');
      }
    } catch (e) {
      debugPrint('Error loading custom presets: $e');
    }
  }

  Future<void> _persistCustomPresets() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final presetFile = File('${directory.path}/audio_effects_presets.json');
      
      final presetData = <String, dynamic>{};
      _customPresets.forEach((name, effects) {
        presetData[name] = effects.map((key, value) => MapEntry(
          key.toString(),
          value.toJson(),
        ));
      });
      
      await presetFile.writeAsString(json.encode(presetData));
      debugPrint('Persisted ${_customPresets.length} custom presets');
    } catch (e) {
      debugPrint('Error persisting custom presets: $e');
    }
  }

  List<String> getAvailablePresets() {
    final presets = [
      'Concert',
      'Club',
      'Vocal',
      'Bass',
      'Immersive',
      'Studio',
      'Cinema',
    ];
    presets.addAll(_customPresets.keys);
    return presets;
  }

  Map<String, dynamic> getSettings() {
    return {
      'globalEnabled': _globalEnabled,
      'currentPresetName': _currentPresetName,
      'reverbPreset': _currentReverbPreset.toString(),
      'spatialMode': _spatialMode.toString(),
      'effects': _effects.map((key, value) => MapEntry(
        key.toString(),
        value.toJson(),
      )),
    };
  }

  void applySettings(Map<String, dynamic> settings) {
    _globalEnabled = settings['globalEnabled'] as bool? ?? false;
    _currentPresetName = settings['currentPresetName'] as String?;

    final reverbPresetStr = settings['reverbPreset'] as String?;
    if (reverbPresetStr != null) {
      _currentReverbPreset = ReverbPreset.values.firstWhere(
        (e) => e.toString() == reverbPresetStr,
        orElse: () => ReverbPreset.mediumRoom,
      );
    }

    final spatialModeStr = settings['spatialMode'] as String?;
    if (spatialModeStr != null) {
      _spatialMode = SpatialMode.values.firstWhere(
        (e) => e.toString() == spatialModeStr,
        orElse: () => SpatialMode.stereo,
      );
    }

    final effectsData = settings['effects'] as Map<String, dynamic>?;
    if (effectsData != null) {
      effectsData.forEach((key, value) {
        final type = AudioEffectType.values.firstWhere(
          (e) => e.toString() == key,
          orElse: () => AudioEffectType.reverb,
        );

        if (_effects.containsKey(type)) {
          final effectData = value as Map<String, dynamic>;
          _effects[type]!.isEnabled = effectData['isEnabled'] as bool? ?? false;
          _effects[type]!.intensity = effectData['intensity'] as double? ?? 0.5;
          _effects[type]!.order = effectData['order'] as int? ?? 0;
          
          final customParams = effectData['customParameters'] as Map<String, dynamic>?;
          if (customParams != null) {
            _effects[type]!.customParameters = customParams.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            );
          }
        }
      });
    }

    _reorderEffectChain();
  }

  void dispose() {
    _parameterController.close();
  }
}