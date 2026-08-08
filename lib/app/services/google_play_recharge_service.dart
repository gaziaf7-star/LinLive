import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class GoogleRechargePackage {
  const GoogleRechargePackage({
    required this.id,
    required this.name,
    required this.coins,
    required this.productId,
    required this.fallbackPrice,
  });

  final int id;
  final String name;
  final int coins;
  final String productId;
  final String fallbackPrice;

  factory GoogleRechargePackage.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return GoogleRechargePackage(
      id: toInt(json['id']),
      name: (json['name'] ?? json['title'] ?? '').toString().trim(),
      coins: toInt(json['coins'] ?? json['amount']),
      productId: (json['product_id'] ??
          json['google_play_product_id'] ??
          json['play_product_id'] ??
          '')
          .toString()
          .trim(),
      fallbackPrice:
      (json['display_price_fallback'] ?? json['price'] ?? '').toString(),
    );
  }
}

class GoogleRechargeResult {
  const GoogleRechargeResult({
    required this.success,
    required this.message,
    this.coins,
    this.coinsAdded,
    this.pending = false,
  });

  final bool success;
  final String message;
  final int? coins;
  final int? coinsAdded;
  final bool pending;
}

class GooglePlayRechargeService {
  GooglePlayRechargeService({
    required Dio dio,
    required this.productsUrl,
    required this.verifyUrl,
    required this.accessTokenProvider,
    required this.onResult,
  }) : _dio = dio;

  final Dio _dio;
  final String productsUrl;
  final String verifyUrl;
  final Future<String> Function() accessTokenProvider;
  final Future<void> Function(GoogleRechargeResult result) onResult;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  List<GoogleRechargePackage> packages = const <GoogleRechargePackage>[];
  Map<String, ProductDetails> storeProducts =
  const <String, ProductDetails>{};

  String _obfuscatedAccountId = '';
  final Set<String> _processingTokens = <String>{};
  bool _initialized = false;
  bool _disposed = false;

  Iterable<GoogleRechargePackage> get availablePackages sync* {
    for (final GoogleRechargePackage package in packages) {
      if (storeProducts.containsKey(package.productId)) {
        yield package;
      }
    }
  }

  ProductDetails? productFor(String productId) => storeProducts[productId];

  Future<void> initialize() async {
    if (_disposed) {
      throw StateError('Google Play recharge service is already disposed.');
    }

    _listenToPurchases();

    final bool available = await _iap.isAvailable();
    if (!available) {
      throw StateError(
        'Google Play Billing is unavailable. Install the app from the Play '
            'Console testing track and sign in to Google Play.',
      );
    }

    await loadProducts();
    _initialized = true;
  }

  void _listenToPurchases() {
    _purchaseSubscription ??= _iap.purchaseStream.listen(
          (List<PurchaseDetails> purchases) {
        unawaited(_handlePurchaseUpdates(purchases));
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Google Play purchase stream error: $error');
        if (_disposed) return;
        unawaited(
          onResult(
            GoogleRechargeResult(
              success: false,
              message: 'Google Play purchase update failed: $error',
            ),
          ),
        );
      },
      onDone: () {
        _purchaseSubscription = null;
      },
    );
  }

  Future<void> loadProducts() async {
    if (_disposed) return;

    final String token = (await accessTokenProvider()).trim();
    if (token.isEmpty) {
      throw StateError('Login token is unavailable. Please sign in again.');
    }

    final Response<dynamic> response = await _dio.get<dynamic>(
      productsUrl,
      options: Options(
        headers: <String, dynamic>{
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        validateStatus: (int? status) => status != null && status < 500,
      ),
    );

    final Map<String, dynamic> body = _map(response.data);

    if (response.statusCode != 200 || body['success'] != true) {
      throw StateError(
        _serverMessage(body, 'Unable to load Google Play recharge products.'),
      );
    }

    if (body['billing_enabled'] != true) {
      throw StateError('Google Play recharge is disabled by the server.');
    }

    _obfuscatedAccountId =
        (body['obfuscated_account_id'] ?? '').toString().trim();

    final List<dynamic> rawProducts =
    body['products'] is List<dynamic>
        ? body['products'] as List<dynamic>
        : body['data'] is List<dynamic>
        ? body['data'] as List<dynamic>
        : const <dynamic>[];

    packages = rawProducts
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> item) => GoogleRechargePackage.fromJson(
        Map<String, dynamic>.from(item),
      ),
    )
        .where(
          (GoogleRechargePackage item) =>
      item.productId.isNotEmpty && item.coins > 0,
    )
        .toList(growable: false);

    final Set<String> productIds = packages
        .map((GoogleRechargePackage item) => item.productId)
        .toSet();

    if (productIds.isEmpty) {
      storeProducts = const <String, ProductDetails>{};
      throw StateError(
        'No active Google Play Product ID was returned by the server.',
      );
    }

    final ProductDetailsResponse playResponse =
    await _iap.queryProductDetails(productIds);

    if (playResponse.error != null) {
      throw StateError(playResponse.error!.message);
    }

    if (playResponse.notFoundIDs.isNotEmpty) {
      debugPrint(
        'Google Play products not found: ${playResponse.notFoundIDs.join(', ')}',
      );
    }

    storeProducts = <String, ProductDetails>{
      for (final ProductDetails product in playResponse.productDetails)
        product.id: product,
    };

    if (storeProducts.isEmpty) {
      throw StateError(
        'Google Play returned no products. Confirm that the product IDs are '
            'active and exactly match the Laravel Coin Store Product IDs.',
      );
    }
  }

  Future<void> reloadProducts() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    await loadProducts();
  }

  Future<void> buy(String productId) async {
    if (_disposed) {
      throw StateError('Google Play recharge service is already disposed.');
    }
    if (!_initialized) {
      throw StateError('Google Play Billing is not ready yet.');
    }

    final ProductDetails? product = storeProducts[productId];
    if (product == null) {
      throw StateError(
        'This Google Play coin package is not available right now.',
      );
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName:
      _obfuscatedAccountId.isEmpty ? null : _obfuscatedAccountId,
    );

    // The Laravel backend verifies and consumes the product. Keeping
    // autoConsume disabled prevents the client from consuming before the
    // backend has securely credited the coins.
    final bool started = await _iap.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: false,
    );

    if (!started) {
      throw StateError('Google Play did not start the purchase screen.');
    }
  }

  Future<void> _handlePurchaseUpdates(
      List<PurchaseDetails> purchases,
      ) async {
    for (final PurchaseDetails purchase in purchases) {
      if (_disposed) return;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          await onResult(
            const GoogleRechargeResult(
              success: false,
              pending: true,
              message:
              'Payment is pending. Coins will be added only after Google '
                  'confirms the payment.',
            ),
          );
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyWithBackend(purchase);
          break;

        case PurchaseStatus.error:
          await onResult(
            GoogleRechargeResult(
              success: false,
              message:
              purchase.error?.message ?? 'Google Play purchase failed.',
            ),
          );
          break;

        case PurchaseStatus.canceled:
          await onResult(
            const GoogleRechargeResult(
              success: false,
              message: 'Purchase canceled.',
            ),
          );
          break;
      }
    }
  }

  Future<void> _verifyWithBackend(PurchaseDetails purchase) async {
    final String purchaseToken =
    purchase.verificationData.serverVerificationData.trim();

    if (purchaseToken.isEmpty) {
      await onResult(
        const GoogleRechargeResult(
          success: false,
          message: 'Google Play purchase token is missing.',
        ),
      );
      return;
    }

    if (_processingTokens.contains(purchaseToken)) return;
    _processingTokens.add(purchaseToken);

    try {
      final String accessToken = (await accessTokenProvider()).trim();
      if (accessToken.isEmpty) {
        throw StateError('Login token is unavailable. Please sign in again.');
      }

      final Response<dynamic> response = await _dio.post<dynamic>(
        verifyUrl,
        data: <String, dynamic>{
          'product_id': purchase.productID,
          'purchase_token': purchaseToken,
          'order_id': purchase.purchaseID,
        },
        options: Options(
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );

      final Map<String, dynamic> body = _map(response.data);

      if (response.statusCode == 200 && body['success'] == true) {
        // Backend already verified, credited and consumed the token.
        // completePurchase clears the Flutter purchase queue. A server-side
        // consume may complete first, so a harmless platform error is ignored.
        if (purchase.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchase);
          } catch (error) {
            debugPrint(
              'completePurchase after backend confirmation skipped: $error',
            );
          }
        }

        await onResult(
          GoogleRechargeResult(
            success: true,
            message: _serverMessage(body, 'Recharge successful.'),
            coins: _toNullableInt(
              body['coins'] ?? body['new_coins'] ?? body['balance'],
            ),
            coinsAdded: _toNullableInt(
              body['coins_added'] ?? body['added_coins'],
            ),
          ),
        );
        return;
      }

      await onResult(
        GoogleRechargeResult(
          success: false,
          pending: body['pending'] == true,
          message: _serverMessage(body, 'Purchase verification failed.'),
        ),
      );
    } on DioException catch (error) {
      await onResult(
        GoogleRechargeResult(
          success: false,
          message: _serverMessage(
            _map(error.response?.data),
            'Unable to verify the purchase with the server.',
          ),
        ),
      );
    } catch (error) {
      await onResult(
        GoogleRechargeResult(
          success: false,
          message: 'Unable to verify the purchase with the server: $error',
        ),
      );
    } finally {
      _processingTokens.remove(purchaseToken);
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _serverMessage(
      Map<String, dynamic> body,
      String fallback,
      ) {
    final dynamic message =
        body['message'] ?? body['error'] ?? body['errors'];

    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    if (message is List && message.isNotEmpty) {
      return message.first.toString();
    }

    if (message is Map && message.isNotEmpty) {
      final dynamic first = message.values.first;
      if (first is List && first.isNotEmpty) {
        return first.first.toString();
      }
      return first.toString();
    }

    return fallback;
  }

  int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().replaceAll(',', '').trim());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }
}
