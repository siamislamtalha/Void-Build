import 'package:voidmusic/services/db/dao/settings_dao.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'global_events_state.dart';

class GlobalEventsCubit extends Cubit<GlobalEventsState> {
  GlobalEventsCubit({required SettingsDAO settingsDao})
      : super(GlobalEventsInitial()) {
    // checkForUpdates(); // Commented out to disable automatic update checking
  }

  // Commented out to disable update checking
  // void checkForUpdates() async {
  //   final Map<String, dynamic> updates = await getAppUpdates();
  //   log("Checking for updates...", name: 'GlobalEventsCubit');

  //   // Commented out to disable update notifications
  //   // if (updates['changelogs'] != null) {
  //   //   emit(WhatIsNewState(changeLogs: updates['changelogs']));
  //   }

  //   // if (await _settingsDao.getSettingBool(SettingKeys.autoUpdateNotify) ??
  //   //     true) {
  //   //   if (updates["results"]) {
  //   //     emit(UpdateAvailable(
  //   //       newVersion: updates["newVer"],
  //   //       newBuild: updates["newBuild"],
  //   //       downloadUrl: "https://voidmusic.sourceforge.io/",
  //   //     ));
  //   //   }
  //   // }
  // }

  void showAlertDialog(String title, String content) {
    emit(AlertDialogState(title: title, content: content));
  }
}
