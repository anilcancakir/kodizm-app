import 'package:magic/magic.dart';

/// WebSocket configuration for Laravel Reverb (Pusher-compatible protocol).
///
/// Values are resolved at runtime from the `.env` asset via magic's [env]
/// helper. Access via:
/// ```dart
/// Config.get('websocket.url')          // WebSocket server URL
/// Config.get('websocket.app_key')      // Pusher app key
/// Config.get('websocket.reconnect_max_delay_seconds')  // 30
/// Config.get('websocket.auth_endpoint') // '/broadcasting/auth'
/// ```
Map<String, dynamic> get websocketConfig => {
  'websocket': {
    'url': env('WS_URL', 'ws://localhost:8080'),
    'app_key': env('WS_APP_KEY', 'kodizm-local'),
    'reconnect_max_delay_seconds': 30,
    'auth_endpoint': '/broadcasting/auth',
  },
};
