import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:voidmusic/blocs/mini_player/mini_player_cubit.dart';

// Logical height values matching global_footer.dart
const double _kMiniPlayerHeight = 72.0; // Card height (64) + vertical padding (8)
const double _kMiniPlayerGap = 6.0;     // Gap between mini player and nav bar
const double _kNavBarFooterHeight = 72.0; // Gap (6) + nav bar (66)
const double _kOuterBottomPadding = 6.0;

/// Calculates the dynamic bottom spacing required so that content at the bottom
/// of a page can scroll fully into view above the floating footer and mini player.
double calculateBottomFooterSpacing(BuildContext context, {required bool isVisible}) {
  final isMobile = ResponsiveBreakpoints.of(context).isMobile;
  final deviceBottomPadding = MediaQuery.of(context).padding.bottom;

  double totalHeight = _kOuterBottomPadding;
  if (isMobile) {
    totalHeight += _kNavBarFooterHeight;
  }
  if (isVisible) {
    totalHeight += _kMiniPlayerHeight + _kMiniPlayerGap;
  }

  return totalHeight + deviceBottomPadding;
}

/// A box spacer that dynamically adjusts its height based on whether the mini player
/// and floating navbar are visible. Use at the bottom of [Column], [ListView],
/// or [SingleChildScrollView].
class BottomSafeAreaSpacer extends StatelessWidget {
  final double extraPadding;

  const BottomSafeAreaSpacer({
    super.key,
    this.extraPadding = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      buildWhen: (prev, curr) => prev.isVisible != curr.isVisible,
      builder: (context, miniState) {
        final height = calculateBottomFooterSpacing(context, isVisible: miniState.isVisible) + extraPadding;
        return SizedBox(height: height);
      },
    );
  }
}

/// A sliver box spacer for [CustomScrollView] that dynamically adjusts its height
/// based on footer and mini player visibility.
class SliverBottomSafeAreaSpacer extends StatelessWidget {
  final double extraPadding;

  const SliverBottomSafeAreaSpacer({
    super.key,
    this.extraPadding = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      buildWhen: (prev, curr) => prev.isVisible != curr.isVisible,
      builder: (context, miniState) {
        final height = calculateBottomFooterSpacing(context, isVisible: miniState.isVisible) + extraPadding;
        return SliverToBoxAdapter(
          child: SizedBox(height: height),
        );
      },
    );
  }
}
