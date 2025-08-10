import 'package:flutter/material.dart';

import 'app.dart';
import 'supabase/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const AppRoot());
}
