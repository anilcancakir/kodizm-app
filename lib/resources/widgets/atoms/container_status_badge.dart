import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Container status className helpers
// ---------------------------------------------------------------------------

/// Returns the badge className for a container [status] slug.
String containerStatusBadgeClassName(String status) {
  return switch (status) {
    'creating' => 'bg-blue-500/10 text-blue-500',
    'running' => 'bg-green-500/10 text-green-500',
    'stopped' => 'bg-gray-500/10 text-gray-500',
    'failed' => 'bg-red-500/10 text-red-500',
    _ => 'bg-gray-500/10 text-gray-500',
  };
}

/// Returns the i18n label for a container [status] slug.
String containerStatusLabel(String status) {
  return trans('projects.container.status_$status');
}

// ---------------------------------------------------------------------------
// ContainerStatusBadge widget
// ---------------------------------------------------------------------------

/// A badge that renders container status with brand colours.
///
/// ## Usage
///
/// ```dart
/// ContainerStatusBadge(status: 'running')
/// ContainerStatusBadge(status: 'failed')
/// ```
class ContainerStatusBadge extends StatelessWidget {
  /// Creates a [ContainerStatusBadge] for the given [status] slug.
  const ContainerStatusBadge({required this.status, super.key});

  /// The container status slug (e.g. `'creating'`, `'running'`, `'stopped'`, `'failed'`).
  final String status;

  @override
  Widget build(BuildContext context) {
    final cn = containerStatusBadgeClassName(status);
    return WDiv(
      className: 'px-2 py-0.5 rounded-full $cn',
      child: WText(
        containerStatusLabel(status),
        className: 'text-xs font-semibold',
      ),
    );
  }
}
