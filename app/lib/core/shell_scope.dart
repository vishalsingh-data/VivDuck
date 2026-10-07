import 'package:flutter/widgets.dart';

/// Marks screens shown inside the desktop app shell. They drop their own logo
/// and account controls (the sidebar has those) and use a narrower,
/// chat-style column.
class ShellScope extends InheritedWidget {
  /// The sidebar entry currently open (a session id, or `#class`).
  final ValueNotifier<String?> selected;

  const ShellScope({super.key, required this.selected, required super.child});

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope old) => old.selected != selected;
}

extension InShell on BuildContext {
  bool get inShell => ShellScope.maybeOf(this) != null;
}
