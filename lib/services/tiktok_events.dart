import 'package:flutter/services.dart';

class TtEvents {
  static const MethodChannel _channel = MethodChannel('tiktok_events');

  static Future<void> init() async {
    try {
      await _channel.invokeMethod('init');
    } catch (_) {}
  }

  static Future<void> trackTrialStart() async {
    try {
      await _channel.invokeMethod('trackTrialStart');
    } catch (_) {}
  }
}
