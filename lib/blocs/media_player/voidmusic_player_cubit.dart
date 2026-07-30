import 'package:voidmusic/services/voidmusic_player.dart';
import 'package:bloc/bloc.dart';
import 'package:rxdart/rxdart.dart';
part 'voidmusic_player_state.dart';

class VoidMusicPlayerCubit extends Cubit<VoidMusicPlayerState> {
  final VoidMusicPlayer voidMusicPlayer;
  late ValueStream<ProgressBarStreams> progressStreams;

  VoidMusicPlayerCubit(this.voidMusicPlayer)
      : super(VoidMusicPlayerState(isReady: true)) {
    voidMusicPlayer.syncPublicState();
    _setupProgressStreams();
  }

  void switchShowLyrics({bool? value}) {
    emit(VoidMusicPlayerState(
        isReady: true, showLyrics: value ?? !state.showLyrics));
  }

  void _setupProgressStreams() {
    progressStreams = Rx.combineLatest4<Duration, Duration, Duration, bool, ProgressBarStreams>(
      Rx.defer(() => voidMusicPlayer.engine.positionStream, reusable: true),
      Rx.defer(() => voidMusicPlayer.engine.durationStream, reusable: true),
      Rx.defer(() => voidMusicPlayer.engine.bufferedStream, reusable: true),
      Rx.defer(() => voidMusicPlayer.engine.playingStream, reusable: true),
      (Duration position, Duration duration, Duration buffered, bool playing) =>
          ProgressBarStreams(
        position: position,
        duration: duration,
        buffered: buffered,
        isPlaying: playing,
      ),
    ).shareValueSeeded(
      ProgressBarStreams(
        position: Duration.zero,
        duration: Duration.zero,
        buffered: Duration.zero,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> close() {
    // Intentionally does NOT stop the player.
    // The AudioService foreground service manages its own lifecycle via
    // onTaskRemoved() / onNotificationDeleted().
    return super.close();
  }
}
