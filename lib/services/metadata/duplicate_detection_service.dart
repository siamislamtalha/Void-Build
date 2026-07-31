import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:voidmusic/src/rust/api/plugin/models.dart';

class DuplicateTrack {
  final Track track;
  final double similarity;
  final String reason;
  
  DuplicateTrack({
    required this.track,
    required this.similarity,
    required this.reason,
  });
}

class DuplicateDetectionService {
  static DuplicateDetectionService? _instance;
  static DuplicateDetectionService get instance => 
      _instance ??= DuplicateDetectionService._();
  
  DuplicateDetectionService._();

  final List<List<DuplicateTrack>> _duplicateGroups = [];
  double _similarityThreshold = 0.85;
  bool _checkDuration = true;
  bool _checkArtist = true;
  bool _checkAlbum = true;

  List<List<DuplicateTrack>> get duplicateGroups => 
      List.unmodifiable(_duplicateGroups);
  double get similarityThreshold => _similarityThreshold;

  void setSimilarityThreshold(double threshold) {
    _similarityThreshold = threshold.clamp(0.5, 1.0);
    debugPrint('Similarity threshold set to: $_similarityThreshold');
  }

  void setCheckDuration(bool check) {
    _checkDuration = check;
  }

  void setCheckArtist(bool check) {
    _checkArtist = check;
  }

  void setCheckAlbum(bool check) {
    _checkAlbum = check;
  }

  Future<void> detectDuplicates(List<Track> tracks) async {
    _duplicateGroups.clear();
    
    final List<DuplicateTrack> allTracks = tracks.map((t) => 
      DuplicateTrack(track: t, similarity: 1.0, reason: 'original')
    ).toList();

    for (int i = 0; i < allTracks.length; i++) {
      final current = allTracks[i];
      final duplicates = <DuplicateTrack>[current];

      for (int j = i + 1; j < allTracks.length; j++) {
        final other = allTracks[j];
        final similarity = _calculateSimilarity(current.track, other.track);

        if (similarity >= _similarityThreshold) {
          duplicates.add(DuplicateTrack(
            track: other.track,
            similarity: similarity,
            reason: _getReason(current.track, other.track),
          ));
        }
      }

      if (duplicates.length > 1) {
        _duplicateGroups.add(duplicates);
      }
    }

    debugPrint('Found ${_duplicateGroups.length} duplicate groups');
  }

  double _calculateSimilarity(Track track1, Track track2) {
    double score = 0.0;
    int factors = 0;

    // Title similarity
    final titleSimilarity = _stringSimilarity(
      track1.title.toLowerCase(),
      track2.title.toLowerCase(),
    );
    score += titleSimilarity * 0.4;
    factors++;

    // Artist similarity
    if (_checkArtist) {
      final artistSimilarity = _artistSimilarity(track1, track2);
      score += artistSimilarity * 0.3;
      factors++;
    }

    // Duration similarity
    if (_checkDuration && track1.durationMs != null && track2.durationMs != null) {
      final durationDiff = (track1.durationMs! - track2.durationMs!).abs();
      final maxDuration = max(track1.durationMs!.toInt(), track2.durationMs!.toInt());
      final durationSimilarity = 1.0 - (durationDiff.toDouble() / maxDuration);
      score += durationSimilarity * 0.2;
      factors++;
    }

    // Album similarity
    if (_checkAlbum && track1.album != null && track2.album != null) {
      final albumSimilarity = _stringSimilarity(
        track1.album!.title.toLowerCase(),
        track2.album!.title.toLowerCase(),
      );
      score += albumSimilarity * 0.1;
      factors++;
    }

    return factors > 0 ? score / factors : 0.0;
  }

  double _stringSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    
    // Levenshtein distance
    final distance = _levenshteinDistance(s1, s2);
    final maxLen = max(s1.length, s2.length);
    
    return 1.0 - (distance / maxLen);
  }

  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    
    if (len1 == 0) return len2;
    if (len2 == 0) return len1;

    final matrix = List.generate(
      len1 + 1,
      (i) => List.generate(len2 + 1, (j) => 0),
    );

    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = min(
          min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    return matrix[len1][len2];
  }

  double _artistSimilarity(Track track1, Track track2) {
    final artists1 = track1.artists.map((a) => a.name.toLowerCase()).toSet();
    final artists2 = track2.artists.map((a) => a.name.toLowerCase()).toSet();

    if (artists1.isEmpty || artists2.isEmpty) return 0.0;

    final intersection = artists1.intersection(artists2);
    final union = artists1.union(artists2);

    return union.isEmpty ? 0.0 : intersection.length / union.length;
  }

  String _getReason(Track track1, Track track2) {
    final reasons = <String>[];

    if (track1.title.toLowerCase() == track2.title.toLowerCase()) {
      reasons.add('Same title');
    }

    if (_checkArtist) {
      final artists1 = track1.artists.map((a) => a.name.toLowerCase()).toSet();
      final artists2 = track2.artists.map((a) => a.name.toLowerCase()).toSet();
      if (artists1.intersection(artists2).isNotEmpty) {
        reasons.add('Same artist');
      }
    }

    if (_checkDuration && track1.durationMs != null && track2.durationMs != null) {
      final diff = (track1.durationMs! - track2.durationMs!).abs();
      if (diff < BigInt.from(1000)) { // Less than 1 second difference
        reasons.add('Same duration');
      }
    }

    if (_checkAlbum && track1.album != null && track2.album != null) {
      if (track1.album!.id == track2.album!.id) {
        reasons.add('Same album');
      }
    }

    return reasons.isEmpty ? 'Similar content' : reasons.join(', ');
  }

  Future<Track> mergeDuplicates(List<DuplicateTrack> duplicates) async {
    // Select the best track based on quality metrics
    // For now, we'll use simple heuristics
    
    Track bestTrack = duplicates.first.track;
    int bestScore = 0;

    for (final dup in duplicates) {
      int score = 0;
      
      // Prefer tracks with artwork
      if (dup.track.thumbnail.url.isNotEmpty) score += 2;
      
      // Prefer tracks with longer duration (usually higher quality)
      if (dup.track.durationMs != null) {
        score += (dup.track.durationMs!.toInt() ~/ 1000);
      }
      
      // Prefer tracks with album info
      if (dup.track.album != null) score += 1;

      if (score > bestScore) {
        bestScore = score;
        bestTrack = dup.track;
      }
    }

    debugPrint('Merged ${duplicates.length} duplicates into: ${bestTrack.title}');
    return bestTrack;
  }

  void clearResults() {
    _duplicateGroups.clear();
    debugPrint('Duplicate detection results cleared');
  }

  Map<String, dynamic> getSettings() {
    return {
      'similarityThreshold': _similarityThreshold,
      'checkDuration': _checkDuration,
      'checkArtist': _checkArtist,
      'checkAlbum': _checkAlbum,
      'duplicateGroups': _duplicateGroups.length,
    };
  }
}