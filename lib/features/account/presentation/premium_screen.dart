import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/error_tracking_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cinematic_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../application/auth_providers.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _loginWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await SupabaseService.instance.signInWithGoogle();
    } catch (e, stack) {
      await ErrorTrackingService.captureException(e, stackTrace: stack);
      if (mounted) {
        setState(() => _error = 'Falha ao autenticar com o Google. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await SupabaseService.instance.signOut();
    } catch (e, stack) {
      await ErrorTrackingService.captureException(e, stackTrace: stack);
      if (mounted) {
        setState(() => _error = 'Erro ao sair da conta. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isPremium = ref.watch(isPremiumUserProvider);
    final isConfigured = SupabaseService.instance.isConfigured;

    return CinematicScaffold(
      appBar: AppBar(
        title: Text(isPremium ? AppStrings.premiumActive : AppStrings.premiumTitle),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.projects);
            }
          },
        ),
      ),
      bottomNavigationBar: isPremium
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () => context.go(AppRoutes.projects),
                  child: const Text('Voltar para Projetos'),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
            )
          : null,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          children: [
            if (!isPremium) ...[
              // Upgrade Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.amber,
                            AppColors.amber.withValues(alpha: 0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.amber.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 42,
                        color: AppColors.black,
                      ),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .scale(duration: 2.seconds, begin: const Offset(1.0, 1.0), end: const Offset(1.06, 1.06))
                     .then()
                     .shimmer(duration: 1.5.seconds, color: AppColors.warmWhite.withValues(alpha: 0.4)),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      AppStrings.premiumTitle,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.premiumSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ).animate().fadeIn(delay: 150.ms),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Feature Cards List
              _buildFeatureDetail(
                context,
                icon: Icons.all_inclusive_rounded,
                title: AppStrings.unlimitedProjects,
                description: AppStrings.unlimitedProjectsDesc,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
              const SizedBox(height: AppSpacing.md),
              _buildFeatureDetail(
                context,
                icon: Icons.photo_library_outlined,
                title: AppStrings.unlimitedCaptures,
                description: AppStrings.unlimitedCapturesDesc,
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05),
              const SizedBox(height: AppSpacing.md),
              _buildFeatureDetail(
                context,
                icon: Icons.movie_filter_outlined,
                title: AppStrings.premiumCreativeTools,
                description: AppStrings.premiumCreativeToolsDesc,
              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05),
              
              const SizedBox(height: AppSpacing.xl),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(),
                const SizedBox(height: AppSpacing.md),
              ],

              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: (_loading || !isConfigured) ? null : _loginWithGoogle,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                        )
                      : const Icon(Icons.g_mobiledata, size: 32),
                  label: const Text(
                    AppStrings.googleSignIn,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms),
              
              const SizedBox(height: AppSpacing.md),
              Text(
                'A assinatura do Evolo Pro é vinculada à sua Conta Google. Ao se autenticar, você sincroniza seus dados e libera todas as barreiras.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
              ).animate().fadeIn(delay: 450.ms),
              
              if (!isConfigured) ...[
                const SizedBox(height: AppSpacing.lg),
                GlassPanel(
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.amber),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Google Sign-In desativado: Configuração ausente (SUPABASE_URL e SUPABASE_ANON_KEY).',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // Logged In / Premium Active State
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 52,
                        color: AppColors.black,
                      ),
                    ).animate()
                     .scale(duration: 500.ms, curve: Curves.bounceOut)
                     .then()
                     .shimmer(duration: 2.seconds, color: AppColors.warmWhite.withValues(alpha: 0.6)),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      AppStrings.premiumActive,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.premiumActiveSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ).animate().fadeIn(delay: 150.ms),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Account summary card
              Text(
                'Detalhes da Assinatura',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: AppSpacing.md),
              
              GlassPanel(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 36, color: AppColors.amber),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.email ?? 'Assinante Evolo Pro',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const Text(
                                'Login ativo via Google',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.lg, color: AppColors.outline),
                    _buildStatusRow(Icons.check_circle_outline, 'Status da licença: Ativa'),
                    const SizedBox(height: AppSpacing.xs),
                    _buildStatusRow(Icons.all_inclusive, 'Projetos permitidos: Ilimitados'),
                  ],
                ),
              ).animate().fadeIn(delay: 250.ms),
              
              const SizedBox(height: AppSpacing.xxl),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(),
                const SizedBox(height: AppSpacing.md),
              ],

              // Log Out Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warmWhite,
                    side: const BorderSide(color: AppColors.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warmWhite),
                        )
                      : const Icon(Icons.logout),
                  label: const Text(AppStrings.logOut),
                ),
              ).animate().fadeIn(delay: 300.ms),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureDetail(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return GlassPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.amber, size: 26),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

  Widget _buildStatusRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.success),
        const SizedBox(width: AppSpacing.sm),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
