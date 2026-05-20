import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_strings.dart';
import '../navigation/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'glass_panel.dart';

class PremiumPaywallSheet extends StatelessWidget {
  const PremiumPaywallSheet({
    required this.title,
    required this.description,
    super.key,
  });

  final String title;
  final String description;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumPaywallSheet(
        title: title,
        description: description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AppColors.warmWhite.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xl,
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.warmWhite.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Header with Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.amber, Color(0xFFFF8F00)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 14, color: AppColors.black),
                      const SizedBox(width: 4),
                      Text(
                        'PRO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.black,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                      ),
                    ],
                  ),
                ).animate().scale(delay: 100.ms),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.05),
            const SizedBox(height: AppSpacing.sm),

            // Description
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: AppSpacing.xl),

            // Key features preview
            Text(
              'Com o Evolo Pro você tem:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.warmWhite,
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: AppSpacing.md),

            Column(
              children: [
                _buildFeatureRow(
                  context,
                  icon: Icons.all_inclusive_rounded,
                  title: AppStrings.unlimitedProjects,
                  subtitle: AppStrings.unlimitedProjectsDesc,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildFeatureRow(
                  context,
                  icon: Icons.photo_library_outlined,
                  title: AppStrings.unlimitedCaptures,
                  subtitle: AppStrings.unlimitedCapturesDesc,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildFeatureRow(
                  context,
                  icon: Icons.movie_filter_outlined,
                  title: AppStrings.premiumCreativeTools,
                  subtitle: AppStrings.premiumCreativeToolsDesc,
                ),
              ],
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),
            const SizedBox(height: AppSpacing.xl),

            // Actions
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.premium);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  AppStrings.upgradeNow,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ).animate().fadeIn(delay: 350.ms),
            const SizedBox(height: AppSpacing.sm),
            
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Voltar',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.amber, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        height: 1.3,
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
