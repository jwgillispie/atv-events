import 'package:flutter/material.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/shared/providers/theme_provider.dart';
import 'package:hipop/features/shared/services/theme_preferences_service.dart';

class ThemeToggleTile extends StatelessWidget {
  const ThemeToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.maybeOf(context);
    if (themeProvider == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? HiPopColors.darkSurface : Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
            ? HiPopColors.darkBorder.withOpacity(0.3)
            : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDark ? HiPopColors.accentDustyPlum : HiPopColors.accentDustyPlum).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            ThemePreferencesService.getThemeModeIcon(themeProvider.themeMode),
            color: HiPopColors.accentDustyPlum,
            size: 24,
          ),
        ),
        title: Text(
          'Theme',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? HiPopColors.darkTextPrimary : Colors.black87,
          ),
        ),
        subtitle: Text(
          ThemePreferencesService.getThemeModeLabel(themeProvider.themeMode),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? HiPopColors.darkTextSecondary : Colors.black54,
          ),
        ),
        trailing: PopupMenuButton<ThemeMode>(
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDark ? HiPopColors.darkTextSecondary : Colors.black54,
          ),
          color: isDark ? HiPopColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark
                ? HiPopColors.darkBorder.withOpacity(0.3)
                : Colors.grey.shade200,
            ),
          ),
          onSelected: (ThemeMode mode) {
            themeProvider.updateThemeMode(mode);
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<ThemeMode>(
              value: ThemeMode.system,
              child: Row(
                children: [
                  Icon(
                    Icons.brightness_auto,
                    size: 20,
                    color: themeProvider.themeMode == ThemeMode.system
                      ? HiPopColors.accentDustyPlum
                      : (isDark ? HiPopColors.darkTextSecondary : Colors.black54),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'System',
                    style: TextStyle(
                      color: isDark ? HiPopColors.darkTextPrimary : Colors.black87,
                      fontWeight: themeProvider.themeMode == ThemeMode.system
                        ? FontWeight.bold
                        : FontWeight.normal,
                    ),
                  ),
                  if (themeProvider.themeMode == ThemeMode.system) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 16,
                      color: HiPopColors.accentDustyPlum,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem<ThemeMode>(
              value: ThemeMode.light,
              child: Row(
                children: [
                  Icon(
                    Icons.light_mode,
                    size: 20,
                    color: themeProvider.themeMode == ThemeMode.light
                      ? HiPopColors.accentDustyPlum
                      : (isDark ? HiPopColors.darkTextSecondary : Colors.black54),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Light',
                    style: TextStyle(
                      color: isDark ? HiPopColors.darkTextPrimary : Colors.black87,
                      fontWeight: themeProvider.themeMode == ThemeMode.light
                        ? FontWeight.bold
                        : FontWeight.normal,
                    ),
                  ),
                  if (themeProvider.themeMode == ThemeMode.light) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 16,
                      color: HiPopColors.accentDustyPlum,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem<ThemeMode>(
              value: ThemeMode.dark,
              child: Row(
                children: [
                  Icon(
                    Icons.dark_mode,
                    size: 20,
                    color: themeProvider.themeMode == ThemeMode.dark
                      ? HiPopColors.accentDustyPlum
                      : (isDark ? HiPopColors.darkTextSecondary : Colors.black54),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Dark',
                    style: TextStyle(
                      color: isDark ? HiPopColors.darkTextPrimary : Colors.black87,
                      fontWeight: themeProvider.themeMode == ThemeMode.dark
                        ? FontWeight.bold
                        : FontWeight.normal,
                    ),
                  ),
                  if (themeProvider.themeMode == ThemeMode.dark) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 16,
                      color: HiPopColors.accentDustyPlum,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}