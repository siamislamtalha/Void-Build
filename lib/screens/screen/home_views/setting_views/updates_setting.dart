import 'package:voidmusic/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/check_update_view.dart';
import 'package:voidmusic/screens/screen/home_views/setting_views/setting_shared_widgets.dart';
import 'package:voidmusic/screens/widgets/bottom_safe_area_spacer.dart';
import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voidmusic/l10n/app_localizations.dart';
import 'package:icons_plus/icons_plus.dart';

class UpdatesSettings extends StatelessWidget {
  const UpdatesSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          l10n.updateSettingTitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ).merge(Default_Theme.secondoryTextStyleMedium),
        ),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (prev, curr) =>
            prev.autoUpdateNotify != curr.autoUpdateNotify,
        builder: (context, state) {
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              SettingSectionHeader(label: l10n.updateSettingTitle),
              SettingCard(
                children: [
                  SettingNavTile(
                    icon: MingCute.download_3_fill,
                    title: l10n.updateCheckForUpdates,
                    subtitle: l10n.updateCheckSubtitle,
                    roundBottom: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CheckUpdateView(),
                        ),
                      );
                    },
                  ),
                  const SettingDivider(),
                  SettingToggleTile(
                    icon: MingCute.notification_fill,
                    title: l10n.updateAutoNotify,
                    subtitle: l10n.updateAutoNotifySubtitle,
                    value: state.autoUpdateNotify,
                    onChanged: (value) {
                      context.read<SettingsCubit>().setAutoUpdateNotify(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const BottomSafeAreaSpacer(),
            ],
          );
        },
      ),
    );
  }
}
