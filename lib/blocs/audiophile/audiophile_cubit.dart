import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:voidmusic/services/audiophile/audiophile_download_service.dart';
import 'package:voidmusic/services/audiophile/audiophile_plugin_registry.dart';
import 'package:voidmusic/services/audiophile/audiophile_service.dart';

class AudiophileState extends Equatable {
  final bool isEnabled;
  final String activePluginId;
  final AudiophileQualityTier qualityTier;
  final List<String> availableAudiophilePlugins;
  final List<AudiophileDownloadTask> downloadQueue;
  final Map<String, bool> pluginHealth;

  const AudiophileState({
    required this.isEnabled,
    required this.activePluginId,
    required this.qualityTier,
    required this.availableAudiophilePlugins,
    this.downloadQueue = const [],
    this.pluginHealth = const {},
  });

  AudiophileState copyWith({
    bool? isEnabled,
    String? activePluginId,
    AudiophileQualityTier? qualityTier,
    List<String>? availableAudiophilePlugins,
    List<AudiophileDownloadTask>? downloadQueue,
    Map<String, bool>? pluginHealth,
  }) {
    return AudiophileState(
      isEnabled: isEnabled ?? this.isEnabled,
      activePluginId: activePluginId ?? this.activePluginId,
      qualityTier: qualityTier ?? this.qualityTier,
      availableAudiophilePlugins:
          availableAudiophilePlugins ?? this.availableAudiophilePlugins,
      downloadQueue: downloadQueue ?? this.downloadQueue,
      pluginHealth: pluginHealth ?? this.pluginHealth,
    );
  }

  @override
  List<Object?> get props => [
        isEnabled,
        activePluginId,
        qualityTier,
        availableAudiophilePlugins,
        downloadQueue,
        pluginHealth,
      ];
}

class AudiophileCubit extends Cubit<AudiophileState> {
  final AudiophileService _service;
  final AudiophilePluginRegistry _registry = AudiophilePluginRegistry();
  final AudiophileDownloadService _downloadService = AudiophileDownloadService();

  StreamSubscription? _downloadSub;

  AudiophileCubit({AudiophileService? service})
      : _service = service ?? AudiophileService(),
        super(const AudiophileState(
          isEnabled: false,
          activePluginId: 'audiophile.deezer',
          qualityTier: AudiophileQualityTier.hiResFlac24,
          availableAudiophilePlugins: [
            'audiophile.deezer',
            'audiophile.qobuz-web',
            'audiophile.tidal-web',
            'audiophile.ytmusic-spotiflac',
            'audiophile.apple-music',
            'audiophile.amazon',
            'audiophile.pandora',
            'audiophile.soundcloud',
          ],
        )) {
    _service.addListener(_onServiceChanged);
    _init();
  }

  Future<void> _init() async {
    final manifests = await _registry.discoverPlugins();
    final setIds = <String>{
      'audiophile.deezer',
      'audiophile.qobuz-web',
      'audiophile.tidal-web',
      'audiophile.ytmusic-spotiflac',
      'audiophile.apple-music',
      'audiophile.amazon',
      'audiophile.pandora',
      'audiophile.soundcloud',
    };
    if (manifests.isNotEmpty) {
      for (final m in manifests) {
        setIds.add(m.id);
      }
    }
    final ids = setIds.toList();
    emit(state.copyWith(
      availableAudiophilePlugins: ids,
      activePluginId: ids.firstWhere(
        (id) => id.contains('deezer') || id.contains('qobuz'),
        orElse: () => ids.first,
      ),
    ));

    _downloadSub = _downloadService.tasksStream.listen((tasks) {
      emit(state.copyWith(downloadQueue: tasks));
    });
  }

  void _onServiceChanged() {
    emit(state.copyWith(
      isEnabled: _service.isAudiophileModeEnabled,
      activePluginId:
          _service.preferredAudiophilePluginId ?? state.activePluginId,
      qualityTier: _service.targetQuality,
    ));
  }

  void toggleAudiophileMode() {
    final next = !_service.isAudiophileModeEnabled;
    _service.setAudiophileMode(next);
  }

  void setAudiophilePlugin(String pluginId) {
    _service.setPreferredPlugin(pluginId);
    emit(state.copyWith(activePluginId: pluginId));
  }

  void setQualityTier(AudiophileQualityTier tier) {
    _service.setTargetQuality(tier);
    emit(state.copyWith(qualityTier: tier));
  }

  void cancelDownload(String taskId) {
    _downloadService.cancelTask(taskId);
  }

  void clearCompletedDownloads() {
    _downloadService.clearCompleted();
  }

  @override
  Future<void> close() {
    _service.removeListener(_onServiceChanged);
    _downloadSub?.cancel();
    return super.close();
  }
}
