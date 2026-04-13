// Custom Flutter bootstrap — disables Flutter's own service worker so it
// does not collide with OneSignal's SW at scope "/". Flutter SW is
// deprecated upstream (see flutter/flutter#156910), so dropping it is
// forward-compatible.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  // serviceWorkerSettings intentionally omitted -> no SW registration.
});
