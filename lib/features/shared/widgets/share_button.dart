import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:atv_events/features/shared/services/communication/share_service.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// A reusable share button widget with consistent UI and functionality
class ShareButton extends StatefulWidget {
  /// The content to share when the button is pressed
  final Future<String> Function() onGetShareContent;
  
  /// Optional subject for the share action
  final String? subject;
  
  /// Button style variant
  final ShareButtonStyle style;
  
  /// Optional icon to use instead of default share icon
  final IconData? customIcon;
  
  /// Optional text label for the button
  final String? label;
  
  /// Button size
  final ShareButtonSize size;
  
  /// Whether the button is enabled
  final bool enabled;
  
  /// Custom callback when share is completed successfully
  final VoidCallback? onShareSuccess;
  
  /// Custom callback when share fails or is dismissed
  final void Function(String message)? onShareError;

  const ShareButton({
    super.key,
    required this.onGetShareContent,
    this.subject,
    this.style = ShareButtonStyle.icon,
    this.customIcon,
    this.label,
    this.size = ShareButtonSize.medium,
    this.enabled = true,
    this.onShareSuccess,
    this.onShareError,
  });

  /// Factory for creating a share button for popup events
  factory ShareButton.popup({
    Key? key,
    required Future<String> Function() onGetShareContent,
    ShareButtonStyle style = ShareButtonStyle.icon,
    ShareButtonSize size = ShareButtonSize.medium,
    bool enabled = true,
    VoidCallback? onShareSuccess,
    void Function(String message)? onShareError,
  }) {
    return ShareButton(
      key: key,
      onGetShareContent: onGetShareContent,
      subject: 'Check out this pop-up on HiPop!',
      style: style,
      size: size,
      enabled: enabled,
      onShareSuccess: onShareSuccess,
      onShareError: onShareError,
    );
  }

  /// Factory for creating a share button for events
  factory ShareButton.event({
    Key? key,
    required Future<String> Function() onGetShareContent,
    ShareButtonStyle style = ShareButtonStyle.icon,
    ShareButtonSize size = ShareButtonSize.medium,
    bool enabled = true,
    VoidCallback? onShareSuccess,
    void Function(String message)? onShareError,
  }) {
    return ShareButton(
      key: key,
      onGetShareContent: onGetShareContent,
      subject: 'Check out this event on HiPop!',
      style: style,
      size: size,
      enabled: enabled,
      onShareSuccess: onShareSuccess,
      onShareError: onShareError,
    );
  }

  /// Factory for creating a share button for markets
  factory ShareButton.market({
    Key? key,
    required Future<String> Function() onGetShareContent,
    ShareButtonStyle style = ShareButtonStyle.icon,
    ShareButtonSize size = ShareButtonSize.medium,
    bool enabled = true,
    VoidCallback? onShareSuccess,
    void Function(String message)? onShareError,
  }) {
    return ShareButton(
      key: key,
      onGetShareContent: onGetShareContent,
      subject: 'Check out this market on HiPop!',
      style: style,
      size: size,
      enabled: enabled,
      onShareSuccess: onShareSuccess,
      onShareError: onShareError,
    );
  }

  @override
  State<ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<ShareButton> {
  bool _isSharing = false;
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (widget.style) {
      case ShareButtonStyle.icon:
        return _buildIconButton(theme);
      case ShareButtonStyle.text:
        return _buildTextButton(theme);
      case ShareButtonStyle.elevated:
        return _buildElevatedButton(theme, colorScheme);
      case ShareButtonStyle.outlined:
        return _buildOutlinedButton(theme, colorScheme);
      case ShareButtonStyle.fab:
        return _buildFabButton(colorScheme);
    }
  }

  Widget _buildIconButton(ThemeData theme) {
    return IconButton(
      key: _buttonKey,
      onPressed: widget.enabled && !_isSharing ? _handleShare : null,
      icon: _isSharing 
        ? SizedBox(
            width: _getIconSize(),
            height: _getIconSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.darkTextPrimary),
            ),
          )
        : Icon(
            widget.customIcon ?? Icons.share,
            size: _getIconSize(),
            color: HiPopColors.darkTextPrimary,
          ),
      tooltip: 'Share',
      splashRadius: _getSplashRadius(),
    );
  }

  Widget _buildTextButton(ThemeData theme) {
    return TextButton.icon(
      key: _buttonKey,
      onPressed: widget.enabled && !_isSharing ? _handleShare : null,
      icon: _isSharing 
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            widget.customIcon ?? Icons.share,
            size: 18,
          ),
      label: Text(widget.label ?? 'Share'),
    );
  }

  Widget _buildElevatedButton(ThemeData theme, ColorScheme colorScheme) {
    return ElevatedButton.icon(
      key: _buttonKey,
      onPressed: widget.enabled && !_isSharing ? _handleShare : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: _getButtonPadding(),
      ),
      icon: _isSharing 
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
            ),
          )
        : Icon(
            widget.customIcon ?? Icons.share,
            size: 18,
          ),
      label: Text(widget.label ?? 'Share'),
    );
  }

  Widget _buildOutlinedButton(ThemeData theme, ColorScheme colorScheme) {
    return OutlinedButton.icon(
      key: _buttonKey,
      onPressed: widget.enabled && !_isSharing ? _handleShare : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.primary),
        padding: _getButtonPadding(),
      ),
      icon: _isSharing 
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          )
        : Icon(
            widget.customIcon ?? Icons.share,
            size: 18,
          ),
      label: Text(widget.label ?? 'Share'),
    );
  }

  Widget _buildFabButton(ColorScheme colorScheme) {
    return FloatingActionButton(
      key: _buttonKey,
      onPressed: widget.enabled && !_isSharing ? _handleShare : null,
      backgroundColor: colorScheme.secondary,
      foregroundColor: colorScheme.onSecondary,
      child: _isSharing 
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onSecondary),
            ),
          )
        : Icon(widget.customIcon ?? Icons.share),
    );
  }

  double _getIconSize() {
    switch (widget.size) {
      case ShareButtonSize.small:
        return 18.0;
      case ShareButtonSize.medium:
        return 24.0;
      case ShareButtonSize.large:
        return 32.0;
    }
  }

  double _getSplashRadius() {
    switch (widget.size) {
      case ShareButtonSize.small:
        return 18.0;
      case ShareButtonSize.medium:
        return 24.0;
      case ShareButtonSize.large:
        return 32.0;
    }
  }

  EdgeInsetsGeometry _getButtonPadding() {
    switch (widget.size) {
      case ShareButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case ShareButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case ShareButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
  }

  Future<void> _handleShare() async {
    if (!ShareService.isShareAvailable()) {
      _showErrorMessage('Sharing is not available on this device');
      return;
    }

    setState(() {
      _isSharing = true;
    });

    try {
      // Get the content to share
      final content = await widget.onGetShareContent();
      
      // Get button position for iPad popover
      Rect? sharePositionOrigin;
      if (_buttonKey.currentContext != null) {
        final RenderBox? renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;
          sharePositionOrigin = Rect.fromLTWH(
            position.dx,
            position.dy,
            size.width,
            size.height,
          );
        }
      }
      
      // Perform the share action with position for iPad
      final result = await Share.share(
        content,
        subject: widget.subject,
        sharePositionOrigin: sharePositionOrigin,
      );

      // Handle the result
      final message = ShareService.getShareErrorMessage(result.status);
      
      if (result.status == ShareResultStatus.success) {
        widget.onShareSuccess?.call();
        _showSuccessMessage(message);
      } else if (result.status == ShareResultStatus.dismissed) {
        // User cancelled, don't show error message
        widget.onShareError?.call(message);
      } else {
        widget.onShareError?.call(message);
        _showErrorMessage(message);
      }
    } catch (e) {
      final message = 'Failed to share: $e';
      widget.onShareError?.call(message);
      _showErrorMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Different styles for the share button
enum ShareButtonStyle {
  /// Plain icon button
  icon,
  /// Text button with icon
  text,
  /// Elevated button with icon and label
  elevated,
  /// Outlined button with icon and label
  outlined,
  /// Floating action button
  fab,
}

/// Different sizes for the share button
enum ShareButtonSize {
  small,
  medium,
  large,
}