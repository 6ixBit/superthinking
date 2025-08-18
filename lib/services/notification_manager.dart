import 'dart:math';
import '../supabase/user_profile_api.dart';
import '../supabase/session_api.dart';
import 'notification_service.dart';

class NotificationManager {
  static final Random _random = Random();

  /// Schedule task reminder for the next day if user has pending tasks
  static Future<void> scheduleTaskReminderIfNeeded() async {
    try {
      // Get yesterday's date
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStart = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
      );
      final yesterdayEnd = yesterdayStart.add(const Duration(days: 1));

      // Get pending tasks count from yesterday's sessions only
      final pendingTasks = await SessionApi.countPendingTasksFromDateRange(
        startDate: yesterdayStart,
        endDate: yesterdayEnd,
      );

      if (pendingTasks > 0) {
        await NotificationService.scheduleTaskReminder(
          pendingTasksCount: pendingTasks,
          sessionDate: yesterday,
        );
        print(
          '[NotificationManager] Scheduled task reminder for $pendingTasks pending tasks from yesterday',
        );
      }
    } catch (e) {
      print('[NotificationManager] Error scheduling task reminder: $e');
    }
  }

  /// Schedule personalized prompt based on user's preferred time
  static Future<void> schedulePersonalizedPrompt() async {
    try {
      final profile = await UserProfileApi.getProfile();
      if (profile == null) return;

      final preferredTime = profile['preferred_prompt_time'] as String?;
      final onboardingResponses =
          profile['onboarding_responses'] as Map<String, dynamic>? ?? {};

      if (preferredTime != null && preferredTime.isNotEmpty) {
        await NotificationService.schedulePersonalizedPrompt(
          preferredTime: preferredTime,
          onboardingResponses: onboardingResponses,
        );
        print(
          '[NotificationManager] Scheduled personalized prompt for $preferredTime',
        );
      }
    } catch (e) {
      print('[NotificationManager] Error scheduling personalized prompt: $e');
    }
  }

  /// Schedule a random daily prompt (50% chance)
  static Future<void> scheduleRandomDailyPrompt() async {
    try {
      // 50% chance to schedule a random prompt
      if (_random.nextBool()) {
        await NotificationService.scheduleRandomDailyPrompt();
        print('[NotificationManager] Scheduled random daily prompt');
      }
    } catch (e) {
      print('[NotificationManager] Error scheduling random daily prompt: $e');
    }
  }

  /// Schedule all notifications for the day
  static Future<void> scheduleDailyNotifications() async {
    try {
      // Cancel existing notifications
      await NotificationService.cancelAllNotifications();

      // Schedule task reminder if needed
      await scheduleTaskReminderIfNeeded();

      // Schedule personalized prompt
      await schedulePersonalizedPrompt();

      // Schedule random daily prompt (50% chance)
      await scheduleRandomDailyPrompt();

      print('[NotificationManager] Daily notifications scheduled successfully');
    } catch (e) {
      print('[NotificationManager] Error scheduling daily notifications: $e');
    }
  }

  /// Called when user completes a session to schedule appropriate notifications
  static Future<void> onSessionCompleted() async {
    try {
      // Schedule task reminder for tomorrow
      await scheduleTaskReminderIfNeeded();

      // Schedule personalized prompt for their preferred time
      await schedulePersonalizedPrompt();

      print(
        '[NotificationManager] Notifications scheduled after session completion',
      );
    } catch (e) {
      print(
        '[NotificationManager] Error scheduling notifications after session: $e',
      );
    }
  }

  /// Called when user completes a task to potentially adjust notifications
  static Future<void> onTaskCompleted() async {
    try {
      // Check if there are still pending tasks
      final totalTasks = await SessionApi.countTotalActionItemsForCurrentUser();
      final completedTasks =
          await SessionApi.countCompletedActionItemsForCurrentUser();
      final pendingTasks = totalTasks - completedTasks;

      if (pendingTasks == 0) {
        // Cancel task reminder if all tasks are completed
        // Note: We'd need to track notification IDs to cancel specific ones
        // For now, we'll let the notification show but with 0 tasks
        print(
          '[NotificationManager] All tasks completed - task reminder will show 0 tasks',
        );
      }
    } catch (e) {
      print('[NotificationManager] Error handling task completion: $e');
    }
  }

  /// Called when session analysis is complete to notify user
  static Future<void> onSessionAnalysisComplete(String sessionId) async {
    try {
      await NotificationService.scheduleSessionAnalysisNotification(sessionId);
      print(
        '[NotificationManager] Session analysis completion notification scheduled for session $sessionId',
      );
    } catch (e) {
      print(
        '[NotificationManager] Error scheduling session analysis notification: $e',
      );
    }
  }

  /// Initialize notification service and schedule daily notifications
  static Future<void> initialize() async {
    try {
      await NotificationService.initialize();
      await scheduleDailyNotifications();
      print('[NotificationManager] Initialized successfully');
    } catch (e) {
      print('[NotificationManager] Error initializing: $e');
    }
  }

  /// Get pending notifications for debugging
  static Future<void> debugPendingNotifications() async {
    try {
      final pending = await NotificationService.getPendingNotifications();
      print('[NotificationManager] Pending notifications: ${pending.length}');
      for (final notification in pending) {
        print('  - ID: ${notification.id}, Title: ${notification.title}');
      }
    } catch (e) {
      print('[NotificationManager] Error getting pending notifications: $e');
    }
  }

  /// Schedule a test notification for debugging
  static Future<void> scheduleTestNotification() async {
    try {
      await NotificationService.scheduleTestNotification();
      print('[NotificationManager] Test notification scheduled');
    } catch (e) {
      print('[NotificationManager] Error scheduling test notification: $e');
    }
  }

  /// Test session analysis notification
  static Future<void> testSessionAnalysisNotification() async {
    try {
      await NotificationService.scheduleSessionAnalysisNotification(
        'test-session-id',
      );
      print(
        '[NotificationManager] Test session analysis notification scheduled',
      );
    } catch (e) {
      print(
        '[NotificationManager] Error scheduling test session analysis notification: $e',
      );
    }
  }
}
