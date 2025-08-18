import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:math';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

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

    await _notifications.initialize(initSettings);
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
      'You have $pendingTasksCount tasks left from your last session',
      'Time to check in on your progress and see what you can accomplish today.',
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
      'Anything on your mind today?',
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
      'How are you feeling about your goals today?',
      'What\'s the biggest challenge you\'re facing right now?',
      'Is there something you\'ve been meaning to think through?',
      'How can you make today a little better?',
      'What\'s on your mind that could use some clarity?',
      'Ready to explore your thoughts?',
      'What would you like to work through today?',
      'Time for some mindful reflection?',
    ];

    final randomMessage = messages[random.nextInt(messages.length)];
    final id = _generateNotificationId('daily_prompt');

    await _notifications.zonedSchedule(
      id,
      'Time to think',
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
      'Test Notification',
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
