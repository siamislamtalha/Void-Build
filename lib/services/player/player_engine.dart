import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:media_kit/media_kit.dart';
import 'package:rxdart/rxdart.dart';
import 'package:voidmusic/services/audio/volume_normalization_service.dart';
import 'package:voidmusic/services/audio/skip_silence_service.dart';
import 'package:voidmusic/services/audio/advanced_equalizer_service.dart';
import 'package:voidmusic/services/audio/audio_effects_service.dart';
import 'package:voidmusic/services/audio/gapless_playback_service.dart';
import 'package:voidmusic/services/player/playback_speed_service.dart';
import 'package:voidmusic/services/cast/google_cast_service.dart' as cast_service;

enum EngineState { idle, loading, buffering, ready, completed, error }

enum LoopMode { off, one, all }

sealed class EngineResult {}

class EngineSuccess extends EngineResult {}

class EngineFailure extends EngineResult {
  final Object error;
  EngineFailure(this.error);
}

class EngineCanceled extends EngineResult {}

class EqualizerBand {
  final double centerFrequency;
  double gain;
  EqualizerBand(this.centerFrequency, {this.gain = 0.0});
}

/// FIX M-07: Replaced the 20-step await loop with a Timer.periodic that fires
/// at ~30fps and calls setVolume fire-and-forget. This eliminates 20 sequential
/// platform-channel round-trips and removes jitter from event-loop pressure.
class VolumeFader {
  bool _cancelled = false;
  Timer? _timer;

  Future<void> fade(
      Player player, double startVol, double endVol, Duration duration) async {
    cancel();
    _cancelled = false;
    if (duration <= Duration.zero) {
      await player.setVolume(endVol.clamp(0.0, 100.0));
      return;
    }

    final startMs = DateTime.now().millisecondsSinceEpoch;
    final endMs = startMs + duration.inMilliseconds;

    _timer = Timer.periodic(const Duration(milliseconds: 33), (t) {
      if (_cancelled) {
        t.cancel();
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final frac = ((now - startMs) / (endMs - startMs)).clamp(0.0, 1.0);
      final vol = startVol + (endVol - startVol) * frac;
      // Fire and forget — do NOT await. Awaiting here would back-pressure the timer.
      player.setVolume(vol.clamp(0.0, 100.0));
      if (frac >= 1.0) t.cancel();
    });
  }

  void cancel() {
    _cancelled = true;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}

class PlayerEngine {
  static const double _eqMinGainDb = -15.0;
  static const double _eqMaxGainDb = 15.0;

  late final Player _playerA;
  late final Player _playerB;
  bool _aIsActive = true;
  bool _disposed = false;

  Player get _active => _aIsActive ? _playerA : _playerB;
  Player get _standby => _aIsActive ? _playerB : _playerA;

  late final BehaviorSubject<Player> _activePlayerSubject;

  Duration crossfadeDuration = Duration.zero;

  final VolumeFader _oldPlayerFader = VolumeFader();
  final VolumeFader _newPlayerFader = VolumeFader();
  Timer? _fadeCleanupTimer;
  Timer? _fadeOutCleanupTimer;

  int _generation = 0;
  bool _isTransitioning = false;
  bool _crossfadeTriggered = false;
  bool _suppressIdleUntilMediaLoads = false;

  Uri? _pendingPreloadUri;
  Map<String, String>? _pendingPreloadHeaders;
  Uri? _preloadedNextUri;
  Map<String, String>? _preloadedNextHeaders;
  bool _standbyPreloaded = false;

  LoopMode _loopMode = LoopMode.off;
  double _userVolume = 1.0;
  double _playerAVolume = 100.0;
  double _playerBVolume = 100.0;
  bool _hasMedia = false;

  final BehaviorSubject<EngineState> _stateSubject =
      BehaviorSubject.seeded(EngineState.idle);
  final BehaviorSubject<bool> _playingSubject = BehaviorSubject.seeded(false);
  final BehaviorSubject<Duration> _positionSubject =
      BehaviorSubject.seeded(Duration.zero);
  final BehaviorSubject<Duration> _durationSubject =
      BehaviorSubject.seeded(Duration.zero);
  final BehaviorSubject<Duration> _bufferedSubject =
      BehaviorSubject.seeded(Duration.zero);
  final BehaviorSubject<double> _volumeSubject = BehaviorSubject.seeded(1.0);
  final BehaviorSubject<double> _speedSubject = BehaviorSubject.seeded(1.0);

  final StreamController<void> _completionController =
      StreamController<void>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  late final List<StreamSubscription> _subs;

  bool _eqEnabled = false;
  final List<EqualizerBand> _eqBands = [
    EqualizerBand(32),
    EqualizerBand(64),
    EqualizerBand(125),
    EqualizerBand(250),
    EqualizerBand(500),
    EqualizerBand(1000),
    EqualizerBand(2000),
    EqualizerBand(4000),
    EqualizerBand(8000),
    EqualizerBand(16000),
  ];
  static const Duration _eqApplyDebounce = Duration(milliseconds: 180);
  Timer? _eqApplyDebounceTimer;

  // FIX L-01: Reactive EQ streams so EqualizerView can subscribe and stay
  // in sync even if EQ state changes from outside the view (settings restore,
  // revive, eqSource toggle).
  final BehaviorSubject<bool> _eqEnabledSubject = BehaviorSubject.seeded(false);
  final BehaviorSubject<List<double>> _eqBandGainsSubject =
      BehaviorSubject.seeded(List.filled(10, 0.0));

  Stream<bool> get equalizerEnabledStream => _eqEnabledSubject.stream;
  Stream<List<double>> get equalizerBandGainsStream =>
      _eqBandGainsSubject.stream;

  PlayerEngine() {
    _playerA = Player(
        configuration: const PlayerConfiguration(
            title: 'Void Music', bufferSize: 16 * 1024 * 1024));
    _playerB = Player(
        configuration: const PlayerConfiguration(
            title: 'Void Music', bufferSize: 16 * 1024 * 1024));

    _configureNativePlayer(_playerA);
    _configureNativePlayer(_playerB);

    _activePlayerSubject = BehaviorSubject.seeded(_playerA);
    _subs = _buildSubscriptions();
    
    // Initialize audio services
    _initializeAudioServices();
  }

  void _initializeAudioServices() {
    // Set player instances for audio services
    SkipSilenceService.instance.setPlayer(_active);
    GaplessPlaybackService.instance.setPlayer(_active);

    // Register callbacks so when any audio service setting changes,
    // we immediately re-apply the combined MPV audio filter chain.
    VolumeNormalizationService.instance.onSettingsChanged = () {
      _scheduleAudioFilterApply();
    };
    AudioEffectsService.instance.onSettingsChanged = () {
      _scheduleAudioFilterApply();
    };
    AdvancedEqualizerService.instance.onSettingsChanged = () {
      _scheduleAudioFilterApply();
    };
    GaplessPlaybackService.instance.onCrossfadeDurationChanged = (duration) {
      crossfadeDuration = duration;
    };
    PlaybackSpeedService.instance.onSpeedChanged = (spd) {
      setSpeed(spd);
    };

    // Initialize Google Cast service
    cast_service.GoogleCastService.instance.initialize();
  }

  /// Public entry point so audio settings UI can trigger filter re-application
  /// after toggling any feature (EQ mode, audio effects, normalization, etc.).
  Future<void> applyAudioFilters() => _applyAudioFilters();

  void _scheduleAudioFilterApply() {
    if (_disposed) return;
    _eqApplyDebounceTimer?.cancel();
    _eqApplyDebounceTimer = Timer(_eqApplyDebounce, () {
      if (_disposed) return;
      _applyAudioFilters();
    });
  }
  
  // ── Google Cast Integration ───────────────────────────────────────────────
  
  Future<void> castToDevice(cast_service.CastDevice device) async {
    final castService = cast_service.GoogleCastService.instance;
    final success = await castService.connectToDevice(device);
    if (success) {
      // Load current media to cast device
      await castService.loadMedia(
        mediaUrl: _getCurrentMediaUrl(),
        title: _getCurrentMediaTitle(),
        artist: _getCurrentMediaArtist(),
        album: _getCurrentMediaAlbum(),
        duration: _durationSubject.value,
      );
      
      if (_playingSubject.value) {
        await castService.play();
      }
    }
  }
  
  Future<void> disconnectCast() async {
    await cast_service.GoogleCastService.instance.disconnect();
  }
  
  bool get isCasting => cast_service.GoogleCastService.instance.isCasting;
  
  String currentMediaUrl = '';
  String currentMediaTitle = '';
  String currentMediaArtist = '';
  String currentMediaAlbum = '';
  String currentArtworkUrl = '';

  String _getCurrentMediaUrl() => currentMediaUrl;
  String _getCurrentMediaTitle() => currentMediaTitle;
  String _getCurrentMediaArtist() => currentMediaArtist;
  String _getCurrentMediaAlbum() => currentMediaAlbum;

  void _configureNativePlayer(Player player) {
    if (player.platform is NativePlayer) {
      final native = player.platform as NativePlayer;
      native.setProperty('stream-lavf-o',
          'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5');
      native.setProperty('cache', 'yes');
      native.setProperty('demuxer-max-bytes', '134217728'); // 128 MB
      native.setProperty('network-timeout', '15');
    }
  }

  List<StreamSubscription> _buildSubscriptions() {
    return [
      _activePlayerSubject.switchMap((p) => p.stream.playing).listen((playing) {
        _playingSubject.add(playing);
        _deriveState();
      }),
      _activePlayerSubject.switchMap((p) => p.stream.position).listen((pos) {
        _positionSubject.add(pos);
        _checkCrossfadeTrigger(pos);
      }),
      _activePlayerSubject.switchMap((p) => p.stream.duration).listen((d) {
        _durationSubject.add(d);
        _deriveState();
      }),
      _activePlayerSubject
          .switchMap((p) => p.stream.buffer)
          .listen(_bufferedSubject.add),
      _activePlayerSubject
          .switchMap((p) => p.stream.buffering)
          .listen((_) => _deriveState()),
      _activePlayerSubject
          .switchMap((p) => p.stream.completed)
          .listen((completed) {
        if (completed && _hasMedia && !_disposed && !_crossfadeTriggered) {
          final pos = _positionSubject.value;
          final dur = _durationSubject.value;
          if (dur > Duration.zero && (dur - pos) > const Duration(seconds: 2)) {
            dev.log('Abnormal EOF detected (pos: $pos, dur: $dur). Routing to error handler.',
                name: 'PlayerEngine');
            _triggerEngineFailure(
                'Abnormal EOF: Connection dropped prematurely');
          } else {
            _handleCompletion();
          }
        }
      }),
      _activePlayerSubject.switchMap((p) => p.stream.volume).listen((v) {
        if (!_isTransitioning) _volumeSubject.add((v / 100.0).clamp(0.0, 1.0));
      }),
      _activePlayerSubject.switchMap((p) => p.stream.error).listen((error) {
        dev.log('Engine error: $error', name: 'PlayerEngine');
        _triggerEngineFailure(error);
      }),
      _playerA.stream.volume.listen((v) => _playerAVolume = v),
      _playerB.stream.volume.listen((v) => _playerBVolume = v),
    ];
  }

  void _checkCrossfadeTrigger(Duration pos) {
    if (_disposed || !_hasMedia || crossfadeDuration <= Duration.zero) return;
    if (_crossfadeTriggered || _isTransitioning || _loopMode == LoopMode.one) {
      return;
    }
    final dur = _durationSubject.value;
    if (dur <= Duration.zero) return;
    final remaining = dur - pos;
    if (remaining <= crossfadeDuration && remaining.inMilliseconds > 50) {
      _crossfadeTriggered = true;
      _handleCompletion();
    }
  }

  void _triggerEngineFailure(String error) {
    _hasMedia = false;
    _suppressIdleUntilMediaLoads = false;
    _playingSubject.add(false);
    _stateSubject.add(EngineState.error);
    _errorController.add(error);
  }

  void _swapActivePlayer() {
    _aIsActive = !_aIsActive;
    final p = _active;
    _playingSubject.add(p.state.playing);
    _positionSubject.add(p.state.position);
    _durationSubject.add(p.state.duration);
    _bufferedSubject.add(p.state.buffer);
    _activePlayerSubject.add(p);
    _deriveState();
  }

  void _handleCompletion() {
    if (_disposed || !_hasMedia || _loopMode == LoopMode.one) return;
    _stateSubject.add(EngineState.completed);
    _completionController.add(null);
  }

  void _deriveState() {
    if (_disposed) return;
    if (!_hasMedia) {
      if (!_suppressIdleUntilMediaLoads) _stateSubject.add(EngineState.idle);
      return;
    }
    _suppressIdleUntilMediaLoads = false;
    final player = _active;
    if (player.state.buffering) {
      _stateSubject.add(EngineState.buffering);
    } else if (_isTransitioning) {
      _stateSubject.add(EngineState.ready);
    } else if (player.state.duration > Duration.zero ||
        player.state.position > Duration.zero ||
        player.state.playing) {
      _stateSubject.add(EngineState.ready);
    } else {
      _stateSubject.add(EngineState.loading);
    }
  }

  EngineState get state => _stateSubject.value;
  bool get playing => _playingSubject.value;
  Duration get position => _positionSubject.value;
  Duration get duration => _durationSubject.value;
  Duration get buffered => _bufferedSubject.value;
  double get volume => _volumeSubject.value;
  double get speed => _speedSubject.value;
  LoopMode get loopMode => _loopMode;
  Stream<EngineState> get stateStream => _stateSubject.stream;
  Stream<bool> get playingStream => _playingSubject.stream;
  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<Duration> get durationStream => _durationSubject.stream;
  Stream<Duration> get bufferedStream => _bufferedSubject.stream;
  Stream<double> get volumeStream => _volumeSubject.stream;
  Stream<double> get speedStream => _speedSubject.stream;
  Stream<void> get completionStream => _completionController.stream;
  Stream<String> get errorStream => _errorController.stream;

  void setLoadingState() {
    if (_disposed) return;
    _suppressIdleUntilMediaLoads = true;
    _stateSubject.add(EngineState.loading);
  }

  Future<EngineResult> openDirect(Uri uri,
      {Map<String, String>? httpHeaders, bool autoPlay = true}) async {
    if (_disposed) return EngineFailure('Engine disposed');
    final gen = ++_generation;

    _oldPlayerFader.cancel();
    _newPlayerFader.cancel();
    _fadeCleanupTimer?.cancel();
    _fadeOutCleanupTimer?.cancel();

    _isTransitioning = false;
    _crossfadeTriggered = false;
    _hasMedia = false;

    setLoadingState();

    try {
      currentMediaUrl = uri.toString();
      await _active.setVolume(_userVolume * 100.0);
      await _active.open(Media(uri.toString(), httpHeaders: httpHeaders),
          play: autoPlay);
      if (_disposed || _generation != gen) return EngineCanceled();

      _hasMedia = true;
      // FIX M-09: Apply EQ only to active player after open; standby gets it
      // when it becomes active (after _swapActivePlayer in crossfade paths).
      if (_eqEnabled) await _applyEqualizerToPlayer(_active);
      _deriveState();
      return EngineSuccess();
    } catch (e) {
      if (_generation != gen) return EngineCanceled();
      _triggerEngineFailure(e.toString());
      return EngineFailure(e);
    }
  }

  Future<EngineResult> activatePreloaded({bool autoPlay = true}) async {
    if (_disposed || !_standbyPreloaded || _preloadedNextUri == null) {
      if (_pendingPreloadUri != null) {
        final uri = _pendingPreloadUri!;
        final headers = _pendingPreloadHeaders;
        _pendingPreloadUri = null;
        _pendingPreloadHeaders = null;
        return openDirect(uri, httpHeaders: headers, autoPlay: autoPlay);
      }
      return EngineFailure('Not preloaded');
    }

    final gen = ++_generation;
    _oldPlayerFader.cancel();
    _newPlayerFader.cancel();
    _fadeCleanupTimer?.cancel();
    _fadeOutCleanupTimer?.cancel();
    _isTransitioning = false;
    _crossfadeTriggered = false;

    setLoadingState();
    final oldPlayer = _active;
    final newPlayer = _standby;
    final nextUri = _preloadedNextUri!;
    final nextHeaders = _preloadedNextHeaders;

    try {
      oldPlayer.stop().catchError((_) {});
      if (_generation != gen || _disposed) return EngineCanceled();

      await newPlayer.setVolume(_userVolume * 100.0);
      if (_generation != gen || _disposed) return EngineCanceled();

      if (autoPlay) {
        try {
          await newPlayer.play();
        } catch (e) {
          dev.log('Socket dropped while idle on standby. Executing fallback re-open.',
              name: 'PlayerEngine');
          await newPlayer.open(
              Media(nextUri.toString(), httpHeaders: nextHeaders),
              play: true);
        }
      }

      if (_generation != gen || _disposed) return EngineCanceled();

      _standbyPreloaded = false;
      _preloadedNextUri = null;
      _hasMedia = true;

      _swapActivePlayer();
      // FIX M-09: Apply EQ to the newly active player after swap.
      if (_eqEnabled) await _applyEqualizerToPlayer(_active);
      
      // Apply volume normalization
      if (VolumeNormalizationService.instance.isEnabled) {
        await _applyVolumeNormalization();
      }
      
      // Start skip silence detection
      if (SkipSilenceService.instance.isEnabled) {
        SkipSilenceService.instance.setPlayer(_active);
      }
      
      // Update gapless playback
      GaplessPlaybackService.instance.setPlayer(_active);
      
      // Notify gapless service of track change
      GaplessPlaybackService.instance.onTrackEnded();

      return EngineSuccess();
    } catch (e) {
      if (_generation != gen) return EngineCanceled();
      newPlayer.stop().catchError((_) {});
      _standbyPreloaded = false;
      _triggerEngineFailure(e.toString());
      return EngineFailure(e);
    }
  }

  Future<EngineResult> crossfadeToPreloaded(Duration duration) async {
    if (_disposed) return EngineFailure('Engine disposed');

    if (!_standbyPreloaded) {
      if (_pendingPreloadUri != null) {
        final uri = _pendingPreloadUri!;
        final headers = _pendingPreloadHeaders;
        _pendingPreloadUri = null;
        _pendingPreloadHeaders = null;
        return openDirect(uri, httpHeaders: headers, autoPlay: true);
      }
      return EngineFailure('Not preloaded');
    }

    _oldPlayerFader.cancel();
    _newPlayerFader.cancel();
    _fadeCleanupTimer?.cancel();
    _fadeOutCleanupTimer?.cancel();

    final gen = ++_generation;
    _isTransitioning = true;
    _crossfadeTriggered = false;

    setLoadingState();

    final oldPlayer = _active;
    final newPlayer = _standby;
    final oldStartVol = _aIsActive ? _playerAVolume : _playerBVolume;
    final nextUri = _preloadedNextUri!;
    final nextHeaders = _preloadedNextHeaders;

    try {
      await newPlayer.setVolume(0.0);
      try {
        await newPlayer.play();
      } catch (e) {
        dev.log('Socket dropped while idle on standby. Executing fallback re-open.',
            name: 'PlayerEngine');
        await newPlayer.open(
            Media(nextUri.toString(), httpHeaders: nextHeaders),
            play: true);
      }

      if (_generation != gen || _disposed) {
        newPlayer.stop().catchError((_) {});
        return EngineCanceled();
      }

      _standbyPreloaded = false;
      _preloadedNextUri = null;
      _hasMedia = true;

      _swapActivePlayer();
      // FIX M-09: Apply EQ to the new active player immediately after swap.
      if (_eqEnabled) await _applyEqualizerToPlayer(_active);

      _oldPlayerFader.fade(oldPlayer, oldStartVol, 0.0, duration);
      _newPlayerFader.fade(newPlayer, 0.0, _userVolume * 100.0, duration);

      _fadeCleanupTimer = Timer(duration, () async {
        if (!_disposed) {
          _oldPlayerFader.cancel();
          _newPlayerFader.cancel();
          await oldPlayer.stop().catchError((_) {});
          await oldPlayer.setVolume(_userVolume * 100.0).catchError((_) {});
          await newPlayer.setVolume(_userVolume * 100.0).catchError((_) {});
          _isTransitioning = false;

          if (_pendingPreloadUri != null) {
            final uri = _pendingPreloadUri!;
            final headers = _pendingPreloadHeaders;
            _pendingPreloadUri = null;
            _pendingPreloadHeaders = null;
            preloadNext(uri, httpHeaders: headers);
          }
        }
      });

      return EngineSuccess();
    } catch (e) {
      if (_generation != gen) return EngineCanceled();
      _oldPlayerFader.cancel();
      _newPlayerFader.cancel();
      _fadeCleanupTimer?.cancel();
      _isTransitioning = false;
      _active.setVolume(_userVolume * 100.0).catchError((_) {});
      _triggerEngineFailure(e.toString());
      return EngineFailure(e);
    }
  }

  void fadeOutActive(Duration duration) {
    if (_disposed) return;
    final player = _active;
    if (!player.state.playing) {
      player.stop().catchError((_) {});
      return;
    }
    _isTransitioning = true;
    final startVol = (_aIsActive ? _playerAVolume : _playerBVolume)
        .clamp(0.0, _userVolume * 100.0);
    _oldPlayerFader.cancel();
    _oldPlayerFader.fade(player, startVol, 0.0, duration);
    _fadeOutCleanupTimer?.cancel();
    _fadeOutCleanupTimer = Timer(duration, () {
      if (!_disposed) {
        _oldPlayerFader.cancel();
        player.stop().catchError((_) {});
        player.setVolume(_userVolume * 100.0).catchError((_) {});
        _isTransitioning = false;
      }
    });
  }

  Future<void> stop({bool keepLoadingState = false}) async {
    if (_disposed) return;
    ++_generation;

    _oldPlayerFader.cancel();
    _newPlayerFader.cancel();
    _fadeCleanupTimer?.cancel();
    _fadeOutCleanupTimer?.cancel();

    _isTransitioning = false;
    _crossfadeTriggered = false;
    _hasMedia = false;
    _standbyPreloaded = false;
    _preloadedNextUri = null;
    _preloadedNextHeaders = null;
    _pendingPreloadUri = null;
    _pendingPreloadHeaders = null;

    if (!keepLoadingState) _suppressIdleUntilMediaLoads = false;

    _positionSubject.add(Duration.zero);
    _durationSubject.add(Duration.zero);
    _bufferedSubject.add(Duration.zero);
    _playingSubject.add(false);

    try {
      await Future.wait([_playerA.stop(), _playerB.stop()]);
      final vol = _userVolume * 100.0;
      await Future.wait([_playerA.setVolume(vol), _playerB.setVolume(vol)]);
    } catch (e) {
      dev.log('Stop error: $e', name: 'PlayerEngine');
    }

    if (!keepLoadingState) _stateSubject.add(EngineState.idle);
  }

  Future<void> play() async {
    if (_disposed) return;
    if (isCasting) {
      await cast_service.GoogleCastService.instance.play();
    }
    await _active.play();
  }

  Future<void> pause() async {
    if (_disposed) return;
    if (isCasting) {
      await cast_service.GoogleCastService.instance.pause();
    }
    await _active.pause();
  }

  Future<void> seek(Duration position) async {
    if (_disposed) return;
    if (isCasting) {
      await cast_service.GoogleCastService.instance.seek(position);
    }
    final actualDuration = _active.state.duration;
    if (actualDuration <= Duration.zero) return;
    final clamped = Duration(
        milliseconds:
            position.inMilliseconds.clamp(0, actualDuration.inMilliseconds));
    await _active.seek(clamped);
  }

  Future<void> setVolume(double value) async {
    if (_disposed) return;
    _userVolume = value.clamp(0.0, 1.0);
    if (isCasting) {
      await cast_service.GoogleCastService.instance.setVolume(_userVolume);
    }
    if (!_isTransitioning) {
      final vol = _userVolume * 100.0;
      await Future.wait([_playerA.setVolume(vol), _playerB.setVolume(vol)]);
    }
    _volumeSubject.add(_userVolume);
    
    // Apply volume normalization if enabled
    if (VolumeNormalizationService.instance.isEnabled) {
      final normalizedVolume = _userVolume * _getNormalizationGain();
      if (!_isTransitioning) {
        final vol = normalizedVolume.clamp(0.0, 1.0) * 100.0;
        await Future.wait([_playerA.setVolume(vol), _playerB.setVolume(vol)]);
      }
    }
  }
  
  double _getNormalizationGain() {
    // Convert the normalization service's pre-gain from dB to linear scale.
    // Formula: linear = 10^(dB / 20)
    final preGainDb = VolumeNormalizationService.instance.preGain;
    if (preGainDb == 0.0) return 1.0;
    return pow(10.0, preGainDb / 20.0).toDouble().clamp(0.1, 4.0);
  }

  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    final clamped = speed.clamp(0.25, 4.0);
    // Update the speed service record (fire-and-forget, no player ref needed)
    PlaybackSpeedService.instance.recordSpeed(clamped);
    await Future.wait([
      _playerA.setRate(clamped),
      _playerB.setRate(clamped),
    ]);
    _speedSubject.add(clamped);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    if (_disposed) return;
    _loopMode = mode;
    final mpvMode =
        mode == LoopMode.one ? PlaylistMode.single : PlaylistMode.none;
    await Future.wait(
        [_playerA.setPlaylistMode(mpvMode), _playerB.setPlaylistMode(mpvMode)]);
  }

  Future<bool> preloadNext(Uri uri, {Map<String, String>? httpHeaders}) async {
    if (_disposed) return false;
    if (_standbyPreloaded &&
        _preloadedNextUri == uri &&
        _preloadedNextHeaders == httpHeaders) {
      return true;
    }

    if (_isTransitioning) {
      _pendingPreloadUri = uri;
      _pendingPreloadHeaders = httpHeaders;
      _preloadedNextUri = uri;
      _preloadedNextHeaders = httpHeaders;
      return true;
    }

    try {
      await _standby.setVolume(0);
      await _standby.open(Media(uri.toString(), httpHeaders: httpHeaders),
          play: false);
      _preloadedNextUri = uri;
      _preloadedNextHeaders = httpHeaders;
      _standbyPreloaded = true;
      _pendingPreloadUri = null;
      _pendingPreloadHeaders = null;
      dev.log('Preloaded next track: $uri', name: 'PlayerEngine');
      return true;
    } catch (e) {
      dev.log('Preload failed: $e', name: 'PlayerEngine');
      _preloadedNextUri = null;
      _preloadedNextHeaders = null;
      _standbyPreloaded = false;
      return false;
    }
  }

  Future<void> clearPreload() async {
    _preloadedNextUri = null;
    _preloadedNextHeaders = null;
    _standbyPreloaded = false;
    _pendingPreloadUri = null;
    _pendingPreloadHeaders = null;
    if (!_isTransitioning) {
      try {
        await _standby.stop();
      } catch (_) {}
    }
  }

  bool get isPreloaded => _standbyPreloaded || _pendingPreloadUri != null;

  // ── Equalizer ──────────────────────────────────────────────────────────────

  List<EqualizerBand> get equalizerBands => List.unmodifiable(_eqBands);
  bool get equalizerEnabled => _eqEnabled;

  Future<void> setEqualizerEnabled(bool enabled) async {
    _eqEnabled = enabled;
    _eqEnabledSubject.add(enabled);
    _eqApplyDebounceTimer?.cancel();
    await _applyEqualizer();
  }

  Future<void> setEqualizerBandGain(int bandIndex, double gain,
      {bool immediate = false}) async {
    if (bandIndex < 0 || bandIndex >= _eqBands.length) return;
    _eqBands[bandIndex].gain = gain.clamp(_eqMinGainDb, _eqMaxGainDb);
    _eqBandGainsSubject
        .add(_eqBands.map((b) => b.gain).toList(growable: false));
    if (!_eqEnabled) return;
    if (immediate) {
      _eqApplyDebounceTimer?.cancel();
      await _applyEqualizer();
      return;
    }
    _scheduleEqualizerApply();
  }

  Future<void> setEqualizerBandGains(List<double> gains,
      {bool immediate = false}) async {
    final count =
        gains.length < _eqBands.length ? gains.length : _eqBands.length;
    for (var i = 0; i < count; i++) {
      _eqBands[i].gain = gains[i].clamp(_eqMinGainDb, _eqMaxGainDb);
    }
    _eqBandGainsSubject
        .add(_eqBands.map((b) => b.gain).toList(growable: false));
    if (!_eqEnabled) return;
    if (immediate) {
      _eqApplyDebounceTimer?.cancel();
      await _applyEqualizer();
      return;
    }
    _scheduleEqualizerApply();
  }

  Future<void> resetEqualizer() async {
    for (final band in _eqBands) {
      band.gain = 0.0;
    }
    _eqBandGainsSubject
        .add(_eqBands.map((b) => b.gain).toList(growable: false));
    _eqApplyDebounceTimer?.cancel();
    await _applyEqualizer();
  }

  void _scheduleEqualizerApply() {
    _scheduleAudioFilterApply();
  }

  /// Applies combined audio filters (Equalizer, Effects, Volume Normalization)
  Future<void> _applyAudioFilters() async {
    if (_disposed) return;
    try {
      final filter = _buildCombinedAudioFilter();
      dev.log('Applying combined audio filter: ${filter.isEmpty ? '<off>' : filter}',
          name: 'PlayerEngine');

      if (_isTransitioning) {
        await _applyFilterToPlayer(_active, filter);
      } else {
        await Future.wait([
          _applyFilterToPlayer(_playerA, filter),
          _applyFilterToPlayer(_playerB, filter),
        ]);
      }
    } catch (e) {
      dev.log('Audio filter apply error: $e', name: 'PlayerEngine');
    }
  }

  Future<void> _applyEqualizer() async {
    await _applyAudioFilters();
  }

  Future<void> _applyFilterToPlayer(Player player, String filter) async {
    if (_disposed) return;
    try {
      final platform = player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('af', filter);
      }
    } catch (e) {
      dev.log('Audio filter apply to player error: $e', name: 'PlayerEngine');
    }
  }

  Future<void> _applyEqualizerToPlayer(Player player) async {
    final filter = _buildCombinedAudioFilter();
    await _applyFilterToPlayer(player, filter);
  }

  String _buildCombinedAudioFilter() {
    final parts = <String>[];

    // 1. Equalizer Filter
    final advancedEq = AdvancedEqualizerService.instance;
    final isEqOn = _eqEnabled || advancedEq.isEnabled;
    if (isEqOn) {
      if (advancedEq.isEnabled && advancedEq.currentMode == EqualizerMode.advanced31) {
        for (final band in advancedEq.bands) {
          if (band.gain.abs() < 0.05) continue;
          parts.add('equalizer=f=${band.frequency}:t=o:w=${band.bandwidth}:g=${band.gain.toStringAsFixed(2)}');
        }
      } else {
        for (var i = 0; i < _eqBands.length; i++) {
          final band = _eqBands[i];
          if (band.gain.abs() < 0.05) continue;
          final width = switch (i) {
            0 || 1 => 1.8,
            8 || 9 => 1.6,
            _ => 1.25,
          };
          parts.add('equalizer=f=${band.centerFrequency}:t=o:w=$width:g=${band.gain.toStringAsFixed(2)}');
        }
      }
    }

    // 2. Audio Effects Filters
    final fx = AudioEffectsService.instance;
    if (fx.globalEnabled) {
      final params = fx.getProcessingParameters();
      if (params.containsKey('bass_gain') && (params['bass_gain'] ?? 0.0) > 0.05) {
        final bassGain = params['bass_gain']!;
        final bassFreq = params['bass_frequency'] ?? 100.0;
        final bassBandwidth = params['bass_bandwidth'] ?? 1.0;
        parts.add('equalizer=f=$bassFreq:t=q:w=$bassBandwidth:g=${bassGain.toStringAsFixed(2)}');
      }
      if (params.containsKey('treble_gain') && (params['treble_gain'] ?? 0.0) > 0.05) {
        final trebleGain = params['treble_gain']!;
        final trebleFreq = params['treble_frequency'] ?? 8000.0;
        final trebleBandwidth = params['treble_bandwidth'] ?? 1.0;
        parts.add('equalizer=f=$trebleFreq:t=q:w=$trebleBandwidth:g=${trebleGain.toStringAsFixed(2)}');
      }
      if (params.containsKey('reverb_mix') && (params['reverb_mix'] ?? 0.0) > 0.05) {
        final mix = (params['reverb_mix']! * 0.8).toStringAsFixed(2);
        parts.add('aecho=0.8:$mix:60:0.4');
      }
      if (params.containsKey('stereo_width') && (params['stereo_width'] ?? 1.0) != 1.0) {
        final width = params['stereo_width']!.toStringAsFixed(2);
        parts.add('extrastereo=m=$width');
      }
    }

    // 3. Volume Normalization Filter
    final norm = VolumeNormalizationService.instance;
    if (norm.isEnabled) {
      final gain = norm.preGain;
      if (gain.abs() > 0.05) {
        parts.add('volume=${gain.toStringAsFixed(2)}dB');
      }
    }

    if (parts.isEmpty) return '';
    return 'lavfi=[${parts.join(',')}]';
  }

  Future<void> _applyVolumeNormalization() async {
    await _applyAudioFilters();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;

    _oldPlayerFader.dispose();
    _newPlayerFader.dispose();
    _fadeCleanupTimer?.cancel();
    _fadeOutCleanupTimer?.cancel();
    _eqApplyDebounceTimer?.cancel();
    _isTransitioning = false;

    for (final sub in _subs) {
      await sub.cancel();
    }

    await _activePlayerSubject.close();
    await Future.wait([_playerA.dispose(), _playerB.dispose()]);
    await _stateSubject.close();
    await _playingSubject.close();
    await _positionSubject.close();
    await _durationSubject.close();
    await _bufferedSubject.close();
    await _volumeSubject.close();
    await _speedSubject.close();
    await _completionController.close();
    await _errorController.close();
    await _eqEnabledSubject.close();
    await _eqBandGainsSubject.close();
  }
}
