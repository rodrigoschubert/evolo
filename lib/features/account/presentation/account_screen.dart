import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/services/error_tracking_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cinematic_scaffold.dart';
import '../../../core/widgets/glass_panel.dart';
import '../application/auth_providers.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
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
    final isAuthenticated = user != null;
    final isConfigured = SupabaseService.instance.isConfigured;

    return CinematicScaffold(
      appBar: AppBar(title: const Text('Conta & Backup')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Status Card
            GlassPanel(
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !isConfigured
                          ? AppColors.amber
                          : (isAuthenticated ? AppColors.success : AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          !isConfigured
                              ? 'Modo Local-Only (Sem chaves da nuvem)'
                              : (isAuthenticated ? 'Backup ativo' : 'Backup desativado'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          !isConfigured
                              ? 'O backup está indisponível porque o app foi compilado sem as chaves do Supabase. Defina SUPABASE_URL e SUPABASE_ANON_KEY.'
                              : (isAuthenticated
                                  ? 'Seus projetos estão salvos em segurança na nuvem.'
                                  : 'Conecte-se com sua conta Google para salvar seus dados na nuvem.'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.05),

            const SizedBox(height: AppSpacing.xl),

            if (!isAuthenticated) ...[
              Text(
                'Acesse de qualquer lugar',
                style: Theme.of(context).textTheme.headlineSmall,
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Faça backup dos seus projetos na nuvem para nunca perder o progresso.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: AppSpacing.xl),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ).animate().fadeIn(),
                const SizedBox(height: AppSpacing.md),
              ],
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: (_loading || !isConfigured) ? null : _loginWithGoogle,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata, size: 32),
                  label: const Text('Continuar com Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warmWhite,
                    side: const BorderSide(color: AppColors.outline),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms),
            ] else ...[
              Text(
                'Sua Conta',
                style: Theme.of(context).textTheme.headlineSmall,
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Você está conectado como:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: AppSpacing.md),
              GlassPanel(
                child: Row(
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 40, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.email ?? 'Usuário Google',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Text(
                            'Conta Google vinculada',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: AppSpacing.xl),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ).animate().fadeIn(),
                const SizedBox(height: AppSpacing.md),
              ],
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _logout,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                  label: const Text('Sair da Conta'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surfaceHigh,
                    foregroundColor: AppColors.warmWhite,
                  ),
                ),
              ).animate().fadeIn(delay: 250.ms),
            ],
          ],
        ),
      ),
    );
  }
}
