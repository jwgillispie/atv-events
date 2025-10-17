import 'package:flutter/material.dart';

class ThemeProvider extends InheritedWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) updateThemeMode;

  const ThemeProvider({
    super.key,
    required this.themeMode,
    required this.updateThemeMode,
    required super.child,
  });

  static ThemeProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
  }

  static ThemeProvider of(BuildContext context) {
    final ThemeProvider? result = maybeOf(context);
    assert(result != null, 'No ThemeProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return themeMode != oldWidget.themeMode;
  }
}