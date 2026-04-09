import 'dart:async';

import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// ConnectionStatusBanner
// ---------------------------------------------------------------------------

/// A top-of-screen banner that reflects WebSocket connection health.
///
/// Wraps [child] and overlays a slim colour-coded banner at the top of the
/// stack whenever the connection enters a degraded state:
///
/// - **reconnecting** — amber banner with spinner
/// - **disconnected** — red banner with wifi-off icon
/// - **back online** (connected after degraded) — green banner, auto-hides
///   after 2 seconds
/// - **initial connecting / connected** — no banner rendered
///
/// ## Usage
///
/// ```dart
/// ConnectionStatusBanner(
///   child: MyPageContent(),
/// )
/// ```
class ConnectionStatusBanner extends StatefulWidget {
  /// Creates a [ConnectionStatusBanner].
  const ConnectionStatusBanner({super.key, required this.child});

  /// The content widget to render beneath the banner.
  final Widget child;

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  // -------
  // State
  // -------

  /// Whether the socket has ever reached [BroadcastConnectionState.connected].
  ///
  /// Banners are suppressed until the first successful connection so the app
  /// does not flash a banner during the normal boot sequence.
  bool _hasBeenConnected = false;

  /// Whether to show the "back online" green banner.
  ///
  /// Set to `true` on the degraded → connected transition, then auto-reset
  /// after 2 seconds by [_backOnlineTimer].
  bool _showBackOnline = false;

  /// The last state processed by [_onConnectionState] to avoid re-processing
  /// the same event on rebuilds triggered by [setState].
  BroadcastConnectionState? _lastProcessedState;

  Timer? _backOnlineTimer;

  // -------
  // Lifecycle
  // -------

  @override
  void dispose() {
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  // -------
  // Helpers
  // -------

  /// Handles each new [BroadcastConnectionState] emitted by [Echo.connectionState].
  ///
  /// Drives [_hasBeenConnected] and [_showBackOnline] transitions.
  void _onConnectionState(BroadcastConnectionState state) {
    if (state == _lastProcessedState) return;
    _lastProcessedState = state;

    if (state == BroadcastConnectionState.connected) {
      final wasDegraded = _hasBeenConnected;

      setState(() {
        _hasBeenConnected = true;
        _showBackOnline = wasDegraded;
      });

      if (wasDegraded) {
        _backOnlineTimer?.cancel();
        _backOnlineTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showBackOnline = false);
        });
      }
    } else if (state == BroadcastConnectionState.reconnecting ||
        state == BroadcastConnectionState.disconnected) {
      _backOnlineTimer?.cancel();
      setState(() => _showBackOnline = false);
    }
  }

  /// Builds the coloured banner for [state], or [SizedBox.shrink] when hidden.
  Widget _buildBanner(BroadcastConnectionState? state) {
    if (!_hasBeenConnected) return const SizedBox.shrink();

    if (_showBackOnline) {
      return WDiv(
        className:
            'w-full p-2 bg-emerald-500 flex flex-row items-center justify-center gap-2',
        children: [
          WIcon(Icons.check_circle_outline, className: 'text-white text-xs'),
          WText(
            trans('connection.connected'),
            className: 'text-white text-xs font-medium',
          ),
        ],
      );
    }

    if (state == BroadcastConnectionState.reconnecting) {
      return WDiv(
        className:
            'w-full p-2 bg-amber-500 flex flex-row items-center justify-center gap-2',
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white,
            ),
          ),
          WText(
            trans('connection.reconnecting'),
            className: 'text-white text-xs font-medium',
          ),
        ],
      );
    }

    if (state == BroadcastConnectionState.disconnected) {
      return WDiv(
        className:
            'w-full p-2 bg-red-500 flex flex-row items-center justify-center gap-2',
        children: [
          WIcon(Icons.wifi_off, className: 'text-white text-xs'),
          WText(
            trans('connection.disconnected'),
            className: 'text-white text-xs font-medium',
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // -------
  // Build
  // -------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BroadcastConnectionState>(
      stream: Echo.connectionState,
      builder: (context, snapshot) {
        final state = snapshot.data;

        if (state != null) {
          // Drive state machine outside of build — schedule post-frame so we
          // don't call setState during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onConnectionState(state);
          });
        }

        final banner = _buildBanner(state);
        final isBannerVisible =
            _hasBeenConnected &&
            (_showBackOnline ||
                state == BroadcastConnectionState.reconnecting ||
                state == BroadcastConnectionState.disconnected);

        if (!isBannerVisible) return widget.child;

        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: banner,
              ),
            ),
          ],
        );
      },
    );
  }
}
