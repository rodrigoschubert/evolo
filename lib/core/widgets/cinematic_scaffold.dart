import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CinematicScaffold extends StatelessWidget {
  const CinematicScaffold({
    required this.child,
    this.appBar,
    this.extendBodyBehindAppBar = false,
    this.bottomNavigationBar,
    super.key,
  });

  final PreferredSizeWidget? appBar;
  final Widget child;
  final bool extendBodyBehindAppBar;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      backgroundColor: AppColors.black,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar != null
          ? SafeArea(
              top: false,
              child: bottomNavigationBar!,
            )
          : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surface, AppColors.black],
          ),
        ),
        child: child,
      ),
    );
  }
}
