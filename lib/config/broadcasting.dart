import 'package:magic/magic.dart';

/// Broadcasting Configuration.
///
/// Configures the broadcast driver and connection settings for real-time
/// event delivery via Laravel Reverb (WebSocket) or the no-op null driver.
///
/// ## Environment Variables
///
/// - `BROADCAST_DRIVER` — active connection (default: `'null'` for local dev)
/// - `REVERB_HOST` — WebSocket server hostname
/// - `REVERB_PORT` — WebSocket server port (integer)
/// - `REVERB_SCHEME` — Transport scheme (`ws` or `wss`)
/// - `REVERB_APP_KEY` — Reverb application key (must match server config)
///
/// ## Usage
/// ```dart
/// Config.get('broadcasting.default')                      // 'null'
/// Config.get('broadcasting.connections.reverb.host')      // 'localhost'
/// Config.get('broadcasting.connections.reverb.port')      // 8080
/// ```
Map<String, dynamic> get broadcastingConfig => {
  'broadcasting': {
    // -------------------------------------------------------------------------
    // Default Connection
    // -------------------------------------------------------------------------
    'default': env('BROADCAST_DRIVER', 'null'),

    // -------------------------------------------------------------------------
    // Connections
    // -------------------------------------------------------------------------
    'connections': {
      'reverb': {
        'driver': 'reverb',
        'host': env('REVERB_HOST', 'localhost'),
        'port': int.tryParse(env('REVERB_PORT', '8080').toString()) ?? 8080,
        'scheme': env('REVERB_SCHEME', 'ws'),
        'app_key': env('REVERB_APP_KEY', 'kodizm-local'),
        'auth_endpoint': '/broadcasting/auth',
        'reconnect': true,
        'max_reconnect_delay': 30,
        'activity_timeout': 30,
      },
      'null': {'driver': 'null'},
    },
  },
};
