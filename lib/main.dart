import 'package:flutter/material.dart';

import 'app.dart';
import 'supabase/supabase_client.dart';
import 'config/revenuecat_config.dart';
import 'services/revenuecat.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  // Configure RevenueCat if keys are provided (via dart-define or hardcoded)
  if (RevenueCatConfig.androidApiKey.isNotEmpty ||
      RevenueCatConfig.iosApiKey.isNotEmpty) {
    await RevenueCatService.configure(
      apiKeyAndroid: RevenueCatConfig.androidApiKey,
      apiKeyIOS: RevenueCatConfig.iosApiKey,
    );
  }

  runApp(const AppRoot());
}
