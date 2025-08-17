class RevenueCatConfig {
  // Set your keys here for local development, or pass them via --dart-define
  // at build/run time to avoid committing secrets into source control.
  // Example:
  // flutter run \
  //   --dart-define=RC_ANDROID_KEY=pub_android_xxx \
  //   --dart-define=RC_IOS_KEY=pub_ios_xxx

  static const String androidApiKey = String.fromEnvironment(
    'RC_ANDROID_KEY',
    defaultValue: '',
  );

  static const String iosApiKey = String.fromEnvironment(
    'RC_IOS_KEY',
    defaultValue: 'appl_UNIOzHqYMXuMyXHXQFVfKgZpJwP',
  );
}
