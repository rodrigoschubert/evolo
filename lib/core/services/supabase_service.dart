import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_service.dart';
import 'error_tracking_service.dart';
import '../../../features/projects/domain/capture_entry.dart';
import '../../../features/projects/domain/evolo_project.dart';
import '../../../features/account/domain/user_profile.dart';

/// Handles all remote Supabase sync operations.
class SupabaseService {
  SupabaseService._();

  static final instance = SupabaseService._();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isConfigured => _client != null;

  // ── Auth ────────────────────────────────────────────────────────────────────

  User? get currentUser => _client?.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges =>
      _client != null ? _client!.auth.onAuthStateChange : const Stream.empty();

  /// Initiates Google Sign-In via OAuth.
  Future<void> signInWithGoogle() async {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase não foi inicializado. Verifique se passou as chaves de ambiente.',
      );
    }
    try {
      await AnalyticsService.instance.capture(AnalyticsEvent.authGoogleStarted);
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'evolo://login-callback',
      );
    } catch (e, stack) {
      await AnalyticsService.instance.capture(AnalyticsEvent.authGoogleFailed);
      await ErrorTrackingService.captureException(e, stackTrace: stack);
      rethrow;
    }
  }

  /// Signs out of the authenticated session.
  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    try {
      await AnalyticsService.instance.capture(AnalyticsEvent.logoutCompleted);
      await client.auth.signOut();
      await AnalyticsService.instance.resetUser();
    } catch (e, stack) {
      await ErrorTrackingService.captureException(e, stackTrace: stack);
      rethrow;
    }
  }

  // ── User Profiles ─────────────────────────────────────────────────────────

  /// Obtém o perfil de um usuário no Supabase.
  Future<EvoloProfile?> getProfile(String userId) async {
    final client = _client;
    if (client == null) return null;
    try {
      final data = await client.from('profiles').select().eq('id', userId).maybeSingle();
      if (data == null) return null;
      return EvoloProfile.fromJson(data);
    } catch (e, stack) {
      await ErrorTrackingService.captureException(e, stackTrace: stack);
      rethrow;
    }
  }

  /// Atualiza o status premium de um usuário no Supabase.
  Future<void> updatePremiumStatus({
    required String userId,
    required bool isPremium,
    required String source,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('profiles').update({
        'is_premium': isPremium,
        'premium_source': source,
        'premium_since': isPremium ? DateTime.now().toUtc().toIso8601String() : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e, stack) {
      await ErrorTrackingService.captureException(e, stackTrace: stack);
      rethrow;
    }
  }

  // ── Projects ─────────────────────────────────────────────────────────────

  Future<void> upsertProject(EvoloProject project) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    await _client!.from('projects').upsert({
      'id': project.id,
      'user_id': userId,
      'name': project.name,
      'cover_image_path': project.coverImagePath,
      'created_at': project.createdAt.toUtc().toIso8601String(),
      'updated_at': project.updatedAt.toUtc().toIso8601String(),
    });
  }

  Future<void> deleteProject(String projectId) async {
    if (!isAuthenticated) return;
    await _client!.from('projects').delete().eq('id', projectId);
  }

  // ── Captures ──────────────────────────────────────────────────────────────

  Future<void> upsertCapture(CaptureEntry capture) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    await _client!.from('captures').upsert({
      'id': capture.id,
      'project_id': capture.projectId,
      'user_id': userId,
      'image_path': capture.imagePath,
      'note': capture.note,
      'source': capture.source,
      'sort_order': capture.sortOrder,
      'created_at': capture.createdAt.toUtc().toIso8601String(),
    });
  }

  Future<void> deleteCapture(String captureId) async {
    if (!isAuthenticated) return;
    await _client!.from('captures').delete().eq('id', captureId);
  }

  /// Synchronizes all local projects and their captures to the cloud.
  Future<void> syncLocalData(List<EvoloProject> projects) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    for (final project in projects) {
      await upsertProject(project);
      for (final capture in project.captures) {
        await upsertCapture(capture);
      }
    }
  }
}
