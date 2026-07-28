import 'package:voidmusic/blocs/notification/notification_cubit.dart';
import 'package:voidmusic/screens/widgets/sign_board_widget.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:icons_plus/icons_plus.dart';

import 'notification_views/notification_tile.dart';

class NotificationView extends StatelessWidget {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          context.read<NotificationCubit>().clearNotification();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () {
                context.read<NotificationCubit>().clearNotification();
              },
              icon: const Icon(
                MingCute.broom_fill,
                color: Default_Theme.primaryColor1,
              ),
            ),
          ],
          title: Text(
            l10n.notificationsTitle,
            style: const TextStyle(
                    color: Default_Theme.primaryColor1,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)
                .merge(Default_Theme.secondoryTextStyle),
          ),
        ),
        body: BlocBuilder<NotificationCubit, NotificationState>(
          builder: (context, state) {
            if (state is NotificationInitial || state.notifications.isEmpty) {
              return Center(
                child: SignBoardWidget(
                    message: l10n.notificationsEmpty,
                    icon: MingCute.notification_off_line),
              );
            }
            return ListView.builder(
              itemCount: state.notifications.length + 1,
              itemBuilder: (context, index) {
                if (index < state.notifications.length) {
                  return NotificationTile(
                    notification: state.notifications[index],
                  );
                }
                return const BottomSafeAreaSpacer();
              },
            );
          },
        ),
      ),
    );
  }
}
