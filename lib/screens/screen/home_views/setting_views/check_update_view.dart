import 'package:flutter/material.dart';
import 'package:voidmusic/core/theme/app_theme.dart';
import 'package:voidmusic/l10n/app_localizations.dart';

class CheckUpdateView extends StatelessWidget {
  const CheckUpdateView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          l10n.updateCheckTitle,
          style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)
              .merge(Default_Theme.secondoryTextStyle),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text(
              "🎧 Update Check Temporarily Disabled 🎧",
              style: TextStyle(
                      color: AppTheme.accentColor(context), fontSize: 20)
                  .merge(Default_Theme.secondoryTextStyleMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "We're cooking up something amazing in the void! 🚀 Please be patient while we prepare the next update. Good things take time, and we promise it'll be worth the wait! ⏳✨",
                style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.8),
                        fontSize: 16)
                    .merge(Default_Theme.tertiaryTextStyle),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Stay tuned, music lover! 🎵",
              style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      fontSize: 14)
                  .merge(Default_Theme.tertiaryTextStyle),
            ),
            const Spacer(),
          ],
        ),
        // Commented out to disable update checking
        // child: FutureBuilder(
        //   future: getLatestVersion(),
        //   builder: (context, snapshot) {
        //     if (snapshot.hasData) {
        //       if (!snapshot.data?["results"]) {
        //         return Column(
        //           mainAxisAlignment: MainAxisAlignment.center,
        //           children: [
        //             const Spacer(),
        //             Text(
        //               l10n.updateUpToDate,
        //               style: const TextStyle(
        //                       color: AppTheme.accentColor(context), fontSize: 20)
        //                   .merge(Default_Theme.secondoryTextStyleMedium),
        //             ),
        //             Padding(
        //               padding: const EdgeInsets.all(5.0),
        //               child: FilledButton(
        //                 onPressed: () {
        //                   launch_Url(Uri.parse(
        //                       "https://github.com/HemantKArya/BloomeeTunes/releases"));
        //                 },
        //                 child: SizedBox(
        //                   // width: 150,
        //                   child: Row(
        //                     mainAxisSize: MainAxisSize.min,
        //                     mainAxisAlignment: MainAxisAlignment.center,
        //                     children: [
        //                       const Icon(
        //                         FontAwesome.github_alt_brand,
        //                         size: 25,
        //                       ),
        //                       Padding(
        //                         padding: const EdgeInsets.only(left: 5),
        //                         child: Text(
        //                           l10n.updateViewPreRelease,
        //                           style: const TextStyle(fontSize: 17).merge(
        //                               Default_Theme.secondoryTextStyleMedium),
        //                         ),
        //                       ),
        //                     ],
        //                   ),
        //                 ),
        //               ),
        //             ),
        //             const Spacer(),
        //             Padding(
        //               padding: const EdgeInsets.only(top: 20),
        //               child: Text(
        //                 l10n.updateCurrentVersion(
        //                     snapshot.data?["currVer"] ?? '',
        //                     snapshot.data?["currBuild"] ?? ''),
        //                 style: TextStyle(
        //                         color: Default_Theme.primaryColor2
        //                             .withValues(alpha: 0.5),
        //                         fontSize: 12)
        //                     .merge(Default_Theme.tertiaryTextStyle),
        //               ),
        //             ),
        //           ],
        //         );
        //       } else {
        //         return Column(
        //           mainAxisAlignment: MainAxisAlignment.center,
        //           children: [
        //             const Spacer(),
        //             Text(
        //               l10n.updateNewVersionAvailable,
        //               style: const TextStyle(
        //                       color: AppTheme.accentColor(context), fontSize: 20)
        //                   .merge(Default_Theme.tertiaryTextStyle),
        //               textAlign: TextAlign.center,
        //             ),
        //             Padding(
        //               padding: const EdgeInsets.all(8.0),
        //               child: Text(
        //                 l10n.updateVersion(snapshot.data?["newVer"] ?? '',
        //                     snapshot.data?["newBuild"] ?? ''),
        //                 style: TextStyle(
        //                         color: Default_Theme.primaryColor1
        //                             .withValues(alpha: 0.8),
        //                         fontSize: 16)
        //                     .merge(Default_Theme.tertiaryTextStyle),
        //                 textAlign: TextAlign.center,
        //               ),
        //             ),
        //             Padding(
        //               padding: const EdgeInsets.all(8.0),
        //               child: FilledButton(
        //                 onPressed: () {
        //                   launch_Url(
        //                       Uri.parse("https://bloomee.sourceforge.io/"));
        //                 },
        //                 child: SizedBox(
        //                   width: 150,
        //                   child: Row(
        //                     mainAxisAlignment: MainAxisAlignment.center,
        //                     children: [
        //                       const Icon(Icons.open_in_browser_rounded,
        //                           size: 25),
        //                       Text(
        //                         l10n.updateDownloadNow,
        //                         style: const TextStyle(fontSize: 17).merge(
        //                             Default_Theme.secondoryTextStyleMedium),
        //                       ),
        //                     ],
        //                   ),
        //                 ),
        //               ),
        //             ),
        //             const Spacer(),
        //             Padding(
        //               padding: const EdgeInsets.only(top: 20),
        //               child: Text(
        //                 l10n.updateCurrentVersion(
        //                     snapshot.data?["currVer"] ?? '',
        //                     snapshot.data?["currBuild"] ?? ''),
        //                 style: TextStyle(
        //                         color: Default_Theme.primaryColor2
        //                             .withValues(alpha: 0.5),
        //                         fontSize: 12)
        //                     .merge(Default_Theme.tertiaryTextStyle),
        //               ),
        //             ),
        //           ],
        //         );
        //       }
        //     } else {
        //       return Column(
        //         mainAxisAlignment: MainAxisAlignment.center,
        //         children: [
        //           const Padding(
        //             padding: EdgeInsets.all(15.0),
        //             child: SizedBox(
        //                 height: 50,
        //                 width: 50,
        //                 child: CircularProgressIndicator(
        //                   color: AppTheme.accentColor(context),
        //                 )),
        //           ),
        //           LayoutBuilder(
        //             builder: (context, constraints) {
        //               return SizedBox(
        //                 width: constraints.maxWidth * 0.6,
        //                 child: Text(l10n.updateChecking,
        //                     style: const TextStyle(
        //                             color: AppTheme.accentColor(context),
        //                             fontSize: 20)
        //                         .merge(Default_Theme.tertiaryTextStyle),
        //                     textAlign: TextAlign.center),
        //               );
        //             },
        //           )
        //         ],
        //       );
        //     }
        //   },
        // ),
      ),
    );
  }
}
