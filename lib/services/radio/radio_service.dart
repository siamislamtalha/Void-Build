import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:voidmusic/src/rust/api/plugin/models.dart';

enum RadioType {
  songBased,
  artistBased,
  genreBased,
  moodBased,
}

class RadioStation {
  final String id;
  final String name;
  final RadioType type;
  final String? seedTrackId;
  final String? seedArtistId;
  final String? seedGenre;
  final List<Track> tracks;
  final DateTime createdAt;
  
  RadioStation({
    required this.id,
    required this.name,
    required this.type,
    this.seedTrackId,
    this.seedArtistId,
    this.seedGenre,
    required this.tracks,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.toString(),
    'seedTrackId': seedTrackId,
    'seedArtistId': seedArtistId,
    'seedGenre': seedGenre,
    'tracks': [],
    'createdAt': createdAt.toIso8601String(),
  };

  factory RadioStation.fromJson(Map<String, dynamic> json) => RadioStation(
    id: json['id'] as String,
    name: json['name'] as String,
    type: RadioType.values.firstWhere(
      (e) => e.toString() == json['type'],
      orElse: () => RadioType.songBased,
    ),
    seedTrackId: json['seedTrackId'] as String?,
    seedArtistId: json['seedArtistId'] as String?,
    seedGenre: json['seedGenre'] as String?,
    tracks: [],
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class RadioService {
  static RadioService? _instance;
  static RadioService get instance => 
      _instance ??= RadioService._();
  
  RadioService._();

  final List<RadioStation> _stations = [];
  RadioStation? _currentStation;
  int _currentTrackIndex = 0;
  bool _isEnabled = true;

  List<RadioStation> get stations => List.unmodifiable(_stations);
  RadioStation? get currentStation => _currentStation;
  int get currentTrackIndex => _currentTrackIndex;
  bool get isEnabled => _isEnabled;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('Radio service ${enabled ? "enabled" : "disabled"}');
  }

  Future<RadioStation> createStation({
    required String name,
    required RadioType type,
    String? seedTrackId,
    String? seedArtistId,
    String? seedGenre,
  }) async {
    final station = RadioStation(
      id: _generateStationId(),
      name: name,
      type: type,
      seedTrackId: seedTrackId,
      seedArtistId: seedArtistId,
      seedGenre: seedGenre,
      tracks: await _generateInitialTracks(type, seedTrackId, seedArtistId, seedGenre),
      createdAt: DateTime.now(),
    );

    _stations.add(station);
    debugPrint('Created radio station: $name');
    
    return station;
  }

  String _generateStationId() {
    return 'radio_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  Future<List<Track>> _generateInitialTracks(
    RadioType type,
    String? seedTrackId,
    String? seedArtistId,
    String? seedGenre,
  ) async {
    // TODO: Implement track generation based on type
    // This would use the plugin system to fetch relevant tracks
    
    switch (type) {
      case RadioType.songBased:
        return await _generateSongBasedTracks(seedTrackId);
      case RadioType.artistBased:
        return await _generateArtistBasedTracks(seedArtistId);
      case RadioType.genreBased:
        return await _generateGenreBasedTracks(seedGenre);
      case RadioType.moodBased:
        return await _generateMoodBasedTracks();
    }
  }

  Future<List<Track>> _generateSongBasedTracks(String? seedTrackId) async {
    // TODO: Implement song-based radio generation
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<List<Track>> _generateArtistBasedTracks(String? seedArtistId) async {
    // TODO: Implement artist-based radio generation
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<List<Track>> _generateGenreBasedTracks(String? seedGenre) async {
    // TODO: Implement genre-based radio generation
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<List<Track>> _generateMoodBasedTracks() async {
    // TODO: Implement mood-based radio generation
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<void> playStation(RadioStation station) async {
    _currentStation = station;
    _currentTrackIndex = 0;
    
    // Add more tracks if needed
    if (station.tracks.length < 10) {
      await _extendStation(station);
    }
    
    debugPrint('Playing radio station: ${station.name}');
  }

  Future<void> _extendStation(RadioStation station) async {
    // TODO: Implement station extension with more tracks
    // This should fetch additional tracks based on the station's seed
    
    final newTracks = await _generateInitialTracks(
      station.type,
      station.seedTrackId,
      station.seedArtistId,
      station.seedGenre,
    );
    
    station.tracks.addAll(newTracks);
    debugPrint('Extended station with ${newTracks.length} tracks');
  }

  Track? getCurrentTrack() {
    if (_currentStation == null || 
        _currentTrackIndex >= _currentStation!.tracks.length) {
      return null;
    }
    
    return _currentStation!.tracks[_currentTrackIndex];
  }

  Track? getNextTrack() {
    if (_currentStation == null) return null;
    
    _currentTrackIndex++;
    
    // Extend station if we're running low on tracks
    if (_currentTrackIndex >= _currentStation!.tracks.length - 3) {
      _extendStation(_currentStation!);
    }
    
    return getCurrentTrack();
  }

  Track? getPreviousTrack() {
    if (_currentStation == null || _currentTrackIndex <= 0) return null;
    
    _currentTrackIndex--;
    return getCurrentTrack();
  }

  void skipToNext() {
    getNextTrack();
  }

  void skipToPrevious() {
    getPreviousTrack();
  }

  void deleteStation(RadioStation station) {
    _stations.remove(station);
    
    if (_currentStation == station) {
      _currentStation = null;
      _currentTrackIndex = 0;
    }
    
    debugPrint('Deleted radio station: ${station.name}');
  }

  Map<String, dynamic> getSettings() {
    return {
      'isEnabled': _isEnabled,
      'stationsCount': _stations.length,
      'currentStation': _currentStation?.name,
      'currentTrackIndex': _currentTrackIndex,
    };
  }
}