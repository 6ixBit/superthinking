import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:math';
import 'dart:async';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Stream controllers for notification events
  static final StreamController<String?> _notificationTappedController =
      StreamController<String?>.broadcast();
  static final StreamController<String?>
  _appLaunchedFromNotificationController =
      StreamController<String?>.broadcast();

  // Streams for listening to notification events
  static Stream<String?> get onNotificationTapped =>
      _notificationTappedController.stream;
  static Stream<String?> get onAppLaunchedFromNotification =>
      _appLaunchedFromNotificationController.stream;

  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Initialize notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null) {
          _notificationTappedController.add(payload);
          _appLaunchedFromNotificationController.add(payload);
        }
      },
    );

    _initialized = true;
  }

  static Future<void> scheduleTaskReminder({
    required int pendingTasksCount,
    required DateTime sessionDate,
  }) async {
    if (!_initialized) await initialize();

    // Schedule for the next day at 9 AM
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final scheduledTime = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      9,
      0,
    );

    final id = _generateNotificationId('task_reminder');

    await _notifications.zonedSchedule(
      id,
      'SuperThinking',
      'You have $pendingTasksCount tasks left from your last session.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription:
              'Reminders about pending tasks from your thinking sessions',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'task_reminders'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> schedulePersonalizedPrompt({
    required String preferredTime,
    required Map<String, dynamic> onboardingResponses,
  }) async {
    if (!_initialized) await initialize();

    // Determine time based on preference
    final scheduledTime = _getTimeForPreference(preferredTime);
    if (scheduledTime == null) return;

    // Generate personalized message based on onboarding responses
    final message = _generatePersonalizedMessage(onboardingResponses);

    final id = _generateNotificationId('personalized_prompt');

    await _notifications.zonedSchedule(
      id,
      'SuperThinking',
      message,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'personalized_prompts',
          'Personalized Prompts',
          channelDescription:
              'Personalized prompts to encourage reflection and thinking',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'personalized_prompts',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleRandomDailyPrompt() async {
    if (!_initialized) await initialize();

    // Random time between 9 AM and 8 PM
    final now = DateTime.now();
    final random = Random();
    final hour = 9 + random.nextInt(11); // 9 AM to 8 PM
    final minute = random.nextInt(60);

    final scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

    // If the time has passed today, schedule for tomorrow
    final finalTime = scheduledTime.isBefore(now)
        ? scheduledTime.add(const Duration(days: 1))
        : scheduledTime;

    final messages = [
      'How are you feeling about your goals?',
      'What\'s your biggest challenge right now?',
      'Something you\'ve been meaning to think through?',
      'How can you make today better?',
      'What needs clarity today?',
      'Ready to explore your thoughts?',
      'What would you like to work through?',
      'Time for reflection?',
    ];

    final randomMessage = messages[random.nextInt(messages.length)];
    final id = _generateNotificationId('daily_prompt');

    await _notifications.zonedSchedule(
      id,
      'SuperThinking',
      randomMessage,
      tz.TZDateTime.from(finalTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_prompts',
          'Daily Prompts',
          channelDescription:
              'Daily prompts to encourage thinking and reflection',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'daily_prompts'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAllNotifications() async {
    if (!_initialized) await initialize();
    await _notifications.cancelAll();
  }

  static Future<void> cancelNotification(int id) async {
    if (!_initialized) await initialize();
    await _notifications.cancel(id);
  }

  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    if (!_initialized) await initialize();
    return await _notifications.pendingNotificationRequests();
  }

  static Future<void> scheduleTestNotification() async {
    if (!_initialized) await initialize();

    // Schedule for 5 seconds from now
    final scheduledTime = DateTime.now().add(const Duration(seconds: 5));
    final id = _generateNotificationId('test');

    await _notifications.zonedSchedule(
      id,
      'SuperThinking',
      'This is a test notification from SuperThinking!',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_notifications',
          'Test Notifications',
          channelDescription: 'Test notifications for debugging',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'test_notifications',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleSessionAnalysisNotification(
    String sessionId,
  ) async {
    if (!_initialized) await initialize();

    // Schedule for immediate delivery (when user is away from app)
    final scheduledTime = DateTime.now().add(const Duration(seconds: 1));
    final id = _generateNotificationId('session_analysis_$sessionId');

    await _notifications.zonedSchedule(
      id,
      'SuperThinking',
      'Your session analysis is ready! Tap to see your insights and next steps.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'session_analysis',
          'Session Analysis',
          channelDescription:
              'Notifications when your session analysis is complete',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'session_analysis',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: sessionId, // Pass session ID as payload for navigation
    );
  }

  // Helper methods
  static int _generateNotificationId(String type) {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(1000);
    return int.parse('${timestamp % 100000}$randomNum');
  }

  static tz.TZDateTime? _getTimeForPreference(String preferredTime) {
    final now = DateTime.now();

    switch (preferredTime.toLowerCase()) {
      case 'morning':
        var scheduledTime = DateTime(now.year, now.month, now.day, 8, 0);
        // If time has passed today, schedule for tomorrow
        if (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }
        return tz.TZDateTime.from(scheduledTime, tz.local);
      case 'day':
        var scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          14,
          0,
        ); // 2 PM
        // If time has passed today, schedule for tomorrow
        if (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }
        return tz.TZDateTime.from(scheduledTime, tz.local);
      case 'evening':
        var scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          19,
          0,
        ); // 7 PM
        // If time has passed today, schedule for tomorrow
        if (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }
        return tz.TZDateTime.from(scheduledTime, tz.local);
      default:
        return null;
    }
  }

  static String _generatePersonalizedMessage(
    Map<String, dynamic> onboardingResponses,
  ) {
    final frequency = onboardingResponses['overthinking_frequency'] as String?;
    final focus = onboardingResponses['overthinking_focus'] as String?;

    if (frequency == 'Often' && focus == 'Problems') {
      return 'Let\'s work through what\'s on your mind and find some clarity.';
    } else if (frequency == 'Sometimes' && focus == 'Possibilities') {
      return 'Ready to explore some new ideas and possibilities?';
    } else if (focus == 'Both') {
      return 'Time to reflect on both challenges and opportunities.';
    } else {
      return 'How can we make your thinking more productive today?';
    }
  }
}
