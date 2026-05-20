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
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        _MediaPrelude()
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .slideY(begin: 0.04),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          AppStrings.onboardingTitle,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.05),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          AppStrings.onboardingBody,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ).animate().fadeIn(delay: 220.ms),
                        const SizedBox(height: AppSpacing.xl),
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
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Text(AppStrings.onboardingCta),
                            ),
                          ),
                        ).animate().fadeIn(delay: 320.ms),
                      ],
                    ),
                  ),
                ),
              ],
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
      aspectRatio: 1.2,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surfaceHigh,
                      AppColors.steelBlue.withValues(alpha: 0.55),
                      AppColors.black,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: GlassPanel(
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Capture hoje. Compare amanhã. Reveja sempre.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
