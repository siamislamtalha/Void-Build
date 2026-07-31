import 'package:voidmusic/screens/widgets/sign_board_widget.dart';
import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:icons_plus/icons_plus.dart';

class DownloadsView extends StatelessWidget {
  const DownloadsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Downloads',
          style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)
              .merge(Default_Theme.secondoryTextStyle),
        ),
      ),
      body: const Center(
        child: SignBoardWidget(
            message: "No Downloads Yet", icon: MingCute.download_2_fill),
      ),
    );
  }
}
