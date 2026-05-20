import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CinematicScaffold extends StatelessWidget {
  const CinematicScaffold({
    required this.child,
    this.appBar,
    this.extendBodyBehindAppBar = false,
    super.key,
  });

  final PreferredSizeWidget? appBar;
  final Widget child;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      backgroundColor: AppColors.black,
      appBar: appBar,
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
