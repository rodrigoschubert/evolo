import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_service.dart';
import 'analytics_service.dart';
import 'error_tracking_service.dart';
import '../../features/account/application/auth_providers.dart';
import '../../features/account/domain/user_profile.dart';

class BillingState {
  final ProductDetails? premiumProduct;
  final bool isAvailable;
  final bool isPurchasing;
  final String? purchaseError;

  BillingState({
    this.premiumProduct,
    this.isAvailable = false,
    this.isPurchasing = false,
    this.purchaseError,
  });

  BillingState copyWith({
    ProductDetails? premiumProduct,
    bool? isAvailable,
    bool? isPurchasing,
    String? purchaseError,
  }) {
    return BillingState(
      premiumProduct: premiumProduct ?? this.premiumProduct,
      isAvailable: isAvailable ?? this.isAvailable,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      purchaseError: purchaseError,
    );
  }
}

final billingServiceProvider = AsyncNotifierProvider<BillingController, BillingState>(
  BillingController.new,
);

class BillingController extends AsyncNotifier<BillingState> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  static const String premiumProductId = 'evolo_premium_unlock';

  @override
  FutureOr<BillingState> build() async {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onError: _onPurchaseError,
    );
    ref.onDispose(() {
      _subscription?.cancel();
    });

    final isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      return BillingState(isAvailable: false);
    }

    ProductDetails? product;
    try {
      final response = await _iap.queryProductDetails({premiumProductId});
      if (response.productDetails.isNotEmpty) {
        product = response.productDetails.firstWhere(
          (element) => element.id == premiumProductId,
        );
      }
    } catch (e, stack) {
      await ErrorTrackingService.captureException(e, stackTrace: stack);
    }

    return BillingState(
      isAvailable: true,
      premiumProduct: product,
    );
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    final current = state.value ?? BillingState();
    
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        state = AsyncValue.data(current.copyWith(isPurchasing: true, purchaseError: null));
      } else {
        state = AsyncValue.data(current.copyWith(isPurchasing: false));
        
        if (purchaseDetails.status == PurchaseStatus.purchased || 
            purchaseDetails.status == PurchaseStatus.restored) {
          
          final valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            await _grantPremiumEntitlement(purchaseDetails);
          }
        }
        
        if (purchaseDetails.status == PurchaseStatus.error) {
          state = AsyncValue.data(current.copyWith(
            isPurchasing: false,
            purchaseError: purchaseDetails.error?.message ?? 'Erro desconhecido na compra.',
          ));
          await AnalyticsService.instance.capture(
            AnalyticsEvent.purchaseFailed,
            properties: {'error': purchaseDetails.error?.message ?? 'Unknown error'},
          );
          await ErrorTrackingService.captureException(
            Exception('Google Play Billing error: ${purchaseDetails.error?.message}'),
            context: {'purchase_id': purchaseDetails.purchaseID ?? ''},
          );
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void _onPurchaseError(Object error) {
    final current = state.value ?? BillingState();
    state = AsyncValue.data(current.copyWith(
      isPurchasing: false,
      purchaseError: 'Erro ao conectar com o serviço de faturamento.',
    ));
    ErrorTrackingService.captureException(error, context: {'billing': 'purchaseStreamError'});
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    return purchase.productID == premiumProductId;
  }

  Future<void> _grantPremiumEntitlement(PurchaseDetails purchase) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final isRestore = purchase.status == PurchaseStatus.restored;
      
      if (isRestore) {
        final profileState = ref.read(userProfileProvider).value;
        if (profileState != null && profileState.isPremium) {
          final currentSource = profileState.premiumSource;
          if (currentSource == 'manual' || currentSource == 'admin' || currentSource == 'promo') {
            debugPrint('Evolo [BillingService]: Compra restaurada ignorada para evitar sobrescrever entitlement manual/admin/promo.');
            await AnalyticsService.instance.capture(AnalyticsEvent.restoreSuccess, properties: {'skipped_override': true});
            return;
          }
        }
      }

      final source = 'google_play';
      await SupabaseService.instance.updatePremiumStatus(
        userId: user.id,
        isPremium: true,
        source: source,
      );

      final now = DateTime.now();
      final updatedProfile = EvoloProfile(
        id: user.id,
        isPremium: true,
        premiumSource: source,
        premiumSince: now,
        createdAt: now,
        updatedAt: now,
      );
      await ref.read(userProfileProvider.notifier).updateLocalProfile(updatedProfile);

      await AnalyticsService.instance.capture(
        isRestore ? AnalyticsEvent.restoreSuccess : AnalyticsEvent.purchaseSuccess,
        properties: {
          'product_id': purchase.productID,
          'purchase_id': purchase.purchaseID ?? '',
        },
      );
      await AnalyticsService.instance.capture(AnalyticsEvent.premiumEnabled);
      
      await AnalyticsService.instance.identifyUser(
        userId: user.id,
        authProvider: user.appMetadata['provider']?.toString(),
        isPremium: true,
        createdAt: user.createdAt,
      );
    } catch (e, stack) {
      await ErrorTrackingService.captureException(
        e,
        stackTrace: stack,
        context: {'action': 'grantPremiumEntitlement', 'purchase_id': purchase.purchaseID ?? ''},
      );
    }
  }

  Future<void> purchasePremium() async {
    final current = state.value;
    final premiumProduct = current?.premiumProduct;
    if (current == null || !current.isAvailable || premiumProduct == null) {
      throw StateError('Serviço de faturamento não disponível ou produto não carregado.');
    }

    await AnalyticsService.instance.capture(AnalyticsEvent.purchaseStarted, properties: {
      'product_id': premiumProductId,
    });

    final purchaseParam = PurchaseParam(productDetails: premiumProduct);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    final current = state.value;
    if (current == null || !current.isAvailable) {
      throw StateError('Serviço de faturamento não disponível.');
    }

    await AnalyticsService.instance.capture(AnalyticsEvent.restoreStarted);
    
    try {
      await _iap.restorePurchases();
    } catch (e, stack) {
      await ErrorTrackingService.captureException(e, stackTrace: stack);
      rethrow;
    }
  }
}
