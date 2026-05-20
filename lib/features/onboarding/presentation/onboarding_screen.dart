import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cinematic_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../data/onboarding_store.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: ref.read(onboardingStoreProvider).isCompleted(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go(AppRoutes.projects);
            }
          });
        }

        return CinematicScaffold(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    flex: 5,
                    child: _MediaPrelude()
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.onboardingTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                  ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1, curve: Curves.easeOut),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.onboardingBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                  ).animate().fadeIn(delay: 220.ms),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        await ref.read(onboardingStoreProvider).complete();
                        await AnalyticsService.instance.capture(
                          AnalyticsEvent.onboardingCompleted,
                        );
                        if (context.mounted) {
                          context.go(AppRoutes.projects);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(AppStrings.onboardingCta),
                      ),
                    ),
                  ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.2, curve: Curves.easeOut),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MediaPrelude extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.9,
      child: Stack(
        children: [
          // Background Placeholder/Image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  image: const DecorationImage(
                    image: AssetImage('assets/images/onboarding_hero.png'),
                    fit: BoxFit.cover,
                    opacity: 0.8,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Floating Badge
          Positioned(
            top: 20,
            right: 20,
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.amber, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Time-lapse AI',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 800.ms).scale(),

          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NOVO',
                    style: TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Capture hoje.\nCompare amanhã.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
