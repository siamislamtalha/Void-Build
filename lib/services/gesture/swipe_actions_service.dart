import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:icons_plus/icons_plus.dart';

enum SwipeAction {
  none,
  like,
  addToPlaylist,
  download,
  delete,
  share,
  addToQueue,
  playNext,
}

class SwipeActionConfig {
  final SwipeAction leftAction;
  final SwipeAction rightAction;
  final double swipeThreshold;
  final double animationDuration;

  const SwipeActionConfig({
    this.leftAction = SwipeAction.like,
    this.rightAction = SwipeAction.addToPlaylist,
    this.swipeThreshold = 0.5,
    this.animationDuration = 300,
  });

  Map<String, dynamic> toJson() => {
    'leftAction': leftAction.toString(),
    'rightAction': rightAction.toString(),
    'swipeThreshold': swipeThreshold,
    'animationDuration': animationDuration,
  };

  factory SwipeActionConfig.fromJson(Map<String, dynamic> json) => SwipeActionConfig(
    leftAction: SwipeAction.values.firstWhere(
      (e) => e.toString() == json['leftAction'],
      orElse: () => SwipeAction.like,
    ),
    rightAction: SwipeAction.values.firstWhere(
      (e) => e.toString() == json['rightAction'],
      orElse: () => SwipeAction.addToPlaylist,
    ),
    swipeThreshold: json['swipeThreshold'] ?? 0.5,
    animationDuration: json['animationDuration'] ?? 300,
  );
}

class SwipeActionsService {
  static SwipeActionsService? _instance;
  static SwipeActionsService get instance => 
      _instance ??= SwipeActionsService._();
  
  SwipeActionsService._();

  SwipeActionConfig _songListConfig = const SwipeActionConfig(
    leftAction: SwipeAction.like,
    rightAction: SwipeAction.addToPlaylist,
  );

  SwipeActionConfig _playlistConfig = const SwipeActionConfig(
    leftAction: SwipeAction.playNext,
    rightAction: SwipeAction.addToQueue,
  );

  bool _isEnabled = true;
  bool _hapticFeedback = true;

  SwipeActionConfig get songListConfig => _songListConfig;
  SwipeActionConfig get playlistConfig => _playlistConfig;
  bool get isEnabled => _isEnabled;
  bool get hapticFeedback => _hapticFeedback;

  void setSongListConfig(SwipeActionConfig config) {
    _songListConfig = config;
    debugPrint('Song list swipe config updated');
  }

  void setPlaylistConfig(SwipeActionConfig config) {
    _playlistConfig = config;
    debugPrint('Playlist swipe config updated');
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('Swipe actions ${enabled ? "enabled" : "disabled"}');
  }

  void setHapticFeedback(bool enabled) {
    _hapticFeedback = enabled;
    debugPrint('Swipe haptic feedback: $enabled');
  }

  ActionPane? buildActionPane({
    required SwipeAction action,
    required Function() onPressed,
  }) {
    if (!_isEnabled) return null;

    switch (action) {
      case SwipeAction.like:
        return ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onPressed(),
              backgroundColor: _getActionColor(action),
              foregroundColor: Colors.white,
              icon: _getActionIcon(action),
              label: _getActionLabel(action),
            ),
          ],
        );
      case SwipeAction.addToPlaylist:
        return ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onPressed(),
              backgroundColor: _getActionColor(action),
              foregroundColor: Colors.white,
              icon: _getActionIcon(action),
              label: _getActionLabel(action),
            ),
          ],
        );
      case SwipeAction.download:
        return ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onPressed(),
              backgroundColor: _getActionColor(action),
              foregroundColor: Colors.white,
              icon: _getActionIcon(action),
              label: _getActionLabel(action),
            ),
          ],
        );
      case SwipeAction.delete:
        return ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onPressed(),
              backgroundColor: _getActionColor(action),
              foregroundColor: Colors.white,
              icon: _getActionIcon(action),
              label: _getActionLabel(action),
            ),
          ],
        );
      case SwipeAction.share:
        return ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onPressed(),
              backgroundColor: _getActionColor(action),
              foregroundColor: Colors.white,
              icon: _getActionIcon(action),
              label: _getActionLabel(action),
            ),
          ],
        );
      case SwipeAction.addToQueue:
        return ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onPressed(),
              backgroundColor: _getActionColor(action),
              foregroundColor: Colors.white,
              icon: _getActionIcon(action),
              label: _getActionLabel(action),
            ),
          ],
        );
      case SwipeAction.playNext:
        return ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onPressed(),
              backgroundColor: _getActionColor(action),
              foregroundColor: Colors.white,
              icon: _getActionIcon(action),
              label: _getActionLabel(action),
            ),
          ],
        );
      case SwipeAction.none:
        return null;
    }
  }

  Color _getActionColor(SwipeAction action) {
    switch (action) {
      case SwipeAction.like:
        return Colors.pink;
      case SwipeAction.addToPlaylist:
        return Colors.blue;
      case SwipeAction.download:
        return Colors.green;
      case SwipeAction.delete:
        return Colors.red;
      case SwipeAction.share:
        return Colors.orange;
      case SwipeAction.addToQueue:
        return Colors.purple;
      case SwipeAction.playNext:
        return Colors.teal;
      case SwipeAction.none:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(SwipeAction action) {
    switch (action) {
      case SwipeAction.like:
        return MingCute.heart_line;
      case SwipeAction.addToPlaylist:
        return MingCute.add_circle_line;
      case SwipeAction.download:
        return MingCute.download_line;
      case SwipeAction.delete:
        return MingCute.delete_line;
      case SwipeAction.share:
        return MingCute.send_line;
      case SwipeAction.addToQueue:
        return MingCute.add_line;
      case SwipeAction.playNext:
        return MingCute.skip_forward_line;
      case SwipeAction.none:
        return MingCute.close_line;
    }
  }

  String _getActionLabel(SwipeAction action) {
    switch (action) {
      case SwipeAction.like:
        return 'Like';
      case SwipeAction.addToPlaylist:
        return 'Add to Playlist';
      case SwipeAction.download:
        return 'Download';
      case SwipeAction.delete:
        return 'Delete';
      case SwipeAction.share:
        return 'Share';
      case SwipeAction.addToQueue:
        return 'Add to Queue';
      case SwipeAction.playNext:
        return 'Play Next';
      case SwipeAction.none:
        return 'None';
    }
  }

  Map<String, dynamic> getSettings() {
    return {
      'isEnabled': _isEnabled,
      'hapticFeedback': _hapticFeedback,
      'songListConfig': _songListConfig.toJson(),
      'playlistConfig': _playlistConfig.toJson(),
    };
  }

  void loadSettings(Map<String, dynamic> settings) {
    _isEnabled = settings['isEnabled'] ?? true;
    _hapticFeedback = settings['hapticFeedback'] ?? true;
    
    if (settings['songListConfig'] != null) {
      _songListConfig = SwipeActionConfig.fromJson(
        settings['songListConfig'] as Map<String, dynamic>,
      );
    }
    
    if (settings['playlistConfig'] != null) {
      _playlistConfig = SwipeActionConfig.fromJson(
        settings['playlistConfig'] as Map<String, dynamic>,
      );
    }
    
    debugPrint('Loaded swipe actions settings');
  }
}