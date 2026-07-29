import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Manages the visibility state of the full-screen player overlay.
class PlayerOverlayCubit extends Cubit<bool> {
  PlayerOverlayCubit() : super(false);

  /// Callback to collapse the UpNext panel, returns true if panel was expanded
  bool Function()? _collapseUpNextPanel;

  /// Callback to navigate the shell to a given branch index.
  void Function(int)? _navigateToBranch;

  /// Callback to notify when dismiss animation completes
  VoidCallback? _onDismissComplete;

  /// The navigation branch index that was active when the player was last
  /// opened. Used by the down-arrow button to restore the previous page.
  int? lastPageIndex;

  /// Register a callback to collapse the UpNext panel
  void registerUpNextPanelCollapse(bool Function() collapse) {
    _collapseUpNextPanel = collapse;
  }

  /// Unregister the UpNext panel collapse callback
  void unregisterUpNextPanelCollapse() {
    _collapseUpNextPanel = null;
  }

  /// Register a callback that navigates the shell to a branch index.
  void registerNavigateToBranch(void Function(int) navigate) {
    _navigateToBranch = navigate;
  }

  /// Unregister the navigation callback.
  void unregisterNavigateToBranch() {
    _navigateToBranch = null;
  }

  /// Register a callback to notify when dismiss animation completes
  void registerDismissComplete(VoidCallback onDismissComplete) {
    _onDismissComplete = onDismissComplete;
  }

  /// Unregister the dismiss complete callback
  void unregisterDismissComplete() {
    _onDismissComplete = null;
  }

  /// Try to collapse the UpNext panel if it's expanded
  /// Returns true if the panel was collapsed, false otherwise
  bool collapseUpNextPanel() {
    return _collapseUpNextPanel?.call() ?? false;
  }

  /// Navigate the shell back to the last page and hide the player.
  void minimizePlayer() {
    hidePlayer();
  }

  /// Called by the wrapper when dismiss animation completes
  void onDismissAnimationComplete() {
    final idx = lastPageIndex;
    if (idx != null) {
      _navigateToBranch?.call(idx);
    }
    _onDismissComplete?.call();
  }

  /// Show the player and optionally record which page the user came from.
  void showPlayer({int? fromPageIndex}) {
    if (fromPageIndex != null) lastPageIndex = fromPageIndex;
    emit(true);
  }

  void hidePlayer() => emit(false);

  void togglePlayer() => emit(!state);

  bool get isPlayerVisible => state;
}
