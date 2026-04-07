import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// A collapsible section widget with a tappable header and expandable body.
///
/// Renders a title row with an optional trailing widget and a chevron toggle.
/// Tapping the header expands or collapses the child content.
///
/// ## Usage
///
/// ```dart
/// CollapsibleSection(
///   title: 'Details',
///   initiallyExpanded: true,
///   trailing: StatusBadge(label: '3'),
///   child: WDiv(
///     className: 'flex flex-col gap-2',
///     children: [...],
///   ),
/// )
/// ```
class CollapsibleSection extends StatefulWidget {
  /// Section header label.
  final String title;

  /// Optional widget displayed between the title and the chevron.
  final Widget? trailing;

  /// Body content shown when expanded.
  final Widget child;

  /// Whether the section starts expanded. Defaults to `false`.
  final bool initiallyExpanded;

  const CollapsibleSection({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col',
      children: [
        WAnchor(
          onTap: () => setState(() => _expanded = !_expanded),
          child: WDiv(
            className: 'flex flex-row items-center gap-2 w-full py-2',
            children: [
              WText(
                widget.title,
                className:
                    'flex-1 text-base font-semibold text-slate-700 dark:text-slate-300',
              ),
              if (widget.trailing != null) widget.trailing!,
              WIcon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                className: 'text-base text-slate-400',
              ),
            ],
          ),
        ),
        if (_expanded) widget.child,
      ],
    );
  }
}
