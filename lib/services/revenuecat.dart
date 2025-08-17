import 'dart:io';

import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static bool _configured = false;

  static Future<void> configure({
    required String apiKeyAndroid,
    required String apiKeyIOS,
    String? userId,
  }) async {
    if (_configured) return;

    final configuration = PurchasesConfiguration(
      Platform.isAndroid ? apiKeyAndroid : apiKeyIOS,
    );
    if (userId != null && userId.isNotEmpty) {
      configuration.appUserID = userId;
    }
    await Purchases.configure(configuration);
    _configured = true;
  }

  static Future<CustomerInfo> getCustomerInfo() async {
    return Purchases.getCustomerInfo();
  }

  static Future<Offerings> getOfferings() async {
    return Purchases.getOfferings();
  }

  static Future<PurchaseResult> purchasePackage(Package package) async {
    return Purchases.purchasePackage(package);
  }

  static Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }
}
