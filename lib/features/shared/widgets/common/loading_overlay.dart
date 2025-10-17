import 'package:flutter/material.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

/// Loading overlay widget that blocks user interaction
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;
  final Color? indicatorColor;

  const LoadingOverlay({
    super.key,
    this.message,
    this.backgroundColor,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: HiPopColors.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: HiPopColors.primaryDeepSage.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  indicatorColor ?? HiPopColors.primaryDeepSage,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}