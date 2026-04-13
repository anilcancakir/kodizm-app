import 'package:magic/magic.dart';

/// Notification Configuration.
///
/// ## Push
///
/// - `driver` — Push driver name (`onesignal`)
/// - `app_id` — OneSignal App ID (from env)
/// - `safari_web_id` — Safari Web Push ID (from env)
/// - `notify_button_enabled` — Show OneSignal native prompt button
///
/// ## Database
///
/// - `enabled` — Enable in-app database notifications
/// - `polling_interval` — Polling interval in seconds
final Map<String, dynamic> notificationsConfig = {
  'notifications': {
    // -------------------------------------------------------------------------
    // Push Notifications
    // -------------------------------------------------------------------------
    'push': {
      'driver': 'onesignal',
      'app_id': env('ONESIGNAL_APP_ID', ''),
      'safari_web_id': env('ONESIGNAL_SAFARI_WEB_ID', ''),
      'notify_button_enabled': false,
    },

    // -------------------------------------------------------------------------
    // Database (In-App) Notifications
    // -------------------------------------------------------------------------
    'database': {'enabled': true, 'polling_interval': 30},

    // -------------------------------------------------------------------------
    // Soft Prompt (Pre-OS Permission Dialog)
    // -------------------------------------------------------------------------
    'soft_prompt': {
      'enabled': true,
      'title': 'Enable Notifications',
      'message':
          'Stay updated with task results, agent questions, and pipeline progress.',
    },
  },
};
