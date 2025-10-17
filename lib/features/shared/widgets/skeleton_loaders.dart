import 'package:flutter/material.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import '../../../core/constants/ui_constants.dart';

/// World-class skeleton loader for feed cards
/// Inspired by Instagram, LinkedIn, and Twitter's smooth loading patterns
/// Features:
/// - No shimmer for cleaner look
/// - Smooth fade-in/out pulse animation
/// - Exact dimension matching to prevent layout shifts
/// - Staggered animations for multiple items
class FeedCardSkeleton extends StatefulWidget {
  final int itemCount;
  final bool enableAnimation;
  final Duration animationDuration;
  
  const FeedCardSkeleton({
    super.key,
    this.itemCount = 3,
    this.enableAnimation = true,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<FeedCardSkeleton> createState() => _FeedCardSkeletonState();
}

class _FeedCardSkeletonState extends State<FeedCardSkeleton>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.itemCount,
      (index) => AnimationController(
        duration: widget.animationDuration,
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.3,
        end: 0.6,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // Start animations with staggered delay for smooth effect
    if (widget.enableAnimation) {
      for (int i = 0; i < _controllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) {
            _controllers[i].repeat(reverse: true);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        widget.itemCount,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index < widget.itemCount - 1 ? UIConstants.smallSpacing : 0,
          ),
          child: AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return _buildSkeletonCard(
                context,
                opacity: widget.enableAnimation ? _animations[index].value : 0.3,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonCard(BuildContext context, {required double opacity}) {
    return Card(
      color: HiPopColors.darkSurface,
      margin: const EdgeInsets.symmetric(
        horizontal: 0,
        vertical: UIConstants.smallSpacing,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.cardBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row - exactly matching FeedCard layout
            Row(
              children: [
                // Icon placeholder - matching exact FeedCard icon container
                _SkeletonBox(
                  width: 40,
                  height: 40,
                  borderRadius: UIConstants.smallBorderRadius,
                  opacity: opacity,
                ),
                const SizedBox(width: UIConstants.contentSpacing),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title skeleton
                      _SkeletonBox(
                        width: 180,
                        height: 16,
                        opacity: opacity,
                      ),
                      const SizedBox(height: 4),
                      // Subtitle skeleton
                      _SkeletonBox(
                        width: 120,
                        height: 14,
                        opacity: opacity,
                      ),
                    ],
                  ),
                ),
                // Action buttons placeholder - matching FeedCard buttons
                Row(
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        left: index > 0 ? UIConstants.smallSpacing : 0,
                      ),
                      child: _SkeletonBox(
                        width: 20,
                        height: 20,
                        isCircle: true,
                        opacity: opacity,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: UIConstants.contentSpacing),
            // Location row - matching FeedCard location layout
            Row(
              children: [
                _SkeletonBox(
                  width: UIConstants.iconSizeSmall,
                  height: UIConstants.iconSizeSmall,
                  isCircle: true,
                  opacity: opacity * 0.7,
                ),
                const SizedBox(width: 4),
                _SkeletonBox(
                  width: 200,
                  height: 13,
                  opacity: opacity * 0.8,
                ),
              ],
            ),
            const SizedBox(height: UIConstants.smallSpacing),
            // Description lines
            _SkeletonBox(
              width: double.infinity,
              height: 13,
              opacity: opacity * 0.6,
            ),
            const SizedBox(height: 4),
            _SkeletonBox(
              width: MediaQuery.of(context).size.width * 0.65,
              height: 13,
              opacity: opacity * 0.5,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom skeleton box widget for consistent styling
class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;
  final bool isCircle;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.opacity,
    this.isCircle = false,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: HiPopColors.darkTextTertiary.withOpacity( opacity),
        borderRadius: isCircle
            ? null
            : BorderRadius.circular(borderRadius),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}

/// World-class skeleton loader for vendor cards with photo preview
/// Matches Instagram's story/post loading pattern
class VendorCardSkeleton extends StatefulWidget {
  final bool enableAnimation;
  final Duration animationDuration;
  
  const VendorCardSkeleton({
    super.key,
    this.enableAnimation = true,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<VendorCardSkeleton> createState() => _VendorCardSkeletonState();
}

class _VendorCardSkeletonState extends State<VendorCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.enableAnimation) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = widget.enableAnimation ? _animation.value : 0.3;
        
        return Card(
          color: HiPopColors.darkSurface,
          margin: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: UIConstants.smallSpacing,
          ),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.cardBorderRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo preview skeleton with gradient effect
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(UIConstants.cardBorderRadius),
                    topRight: Radius.circular(UIConstants.cardBorderRadius),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      HiPopColors.darkTextTertiary.withOpacity( opacity * 0.8),
                      HiPopColors.darkTextTertiary.withOpacity( opacity * 0.6),
                      HiPopColors.darkTextTertiary.withOpacity( opacity * 0.4),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(UIConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header matching FeedCard vendor layout
                    Row(
                      children: [
                        _SkeletonBox(
                          width: 40,
                          height: 40,
                          borderRadius: UIConstants.smallBorderRadius,
                          opacity: opacity,
                        ),
                        const SizedBox(width: UIConstants.contentSpacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SkeletonBox(
                                width: 160,
                                height: 16,
                                opacity: opacity,
                              ),
                              const SizedBox(height: 4),
                              _SkeletonBox(
                                width: 100,
                                height: 14,
                                opacity: opacity * 0.8,
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        Row(
                          children: List.generate(
                            3,
                            (index) => Padding(
                              padding: EdgeInsets.only(
                                left: index > 0 ? UIConstants.smallSpacing : 0,
                              ),
                              child: _SkeletonBox(
                                width: 20,
                                height: 20,
                                isCircle: true,
                                opacity: opacity * 0.7,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: UIConstants.contentSpacing),
                    // Location
                    Row(
                      children: [
                        _SkeletonBox(
                          width: UIConstants.iconSizeSmall,
                          height: UIConstants.iconSizeSmall,
                          isCircle: true,
                          opacity: opacity * 0.6,
                        ),
                        const SizedBox(width: 4),
                        _SkeletonBox(
                          width: 180,
                          height: 13,
                          opacity: opacity * 0.7,
                        ),
                      ],
                    ),
                    const SizedBox(height: UIConstants.smallSpacing),
                    // Content lines
                    _SkeletonBox(
                      width: double.infinity,
                      height: 13,
                      opacity: opacity * 0.5,
                    ),
                    const SizedBox(height: 4),
                    _SkeletonBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: 13,
                      opacity: opacity * 0.4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// LinkedIn-style list item skeleton loader
/// Clean, professional loading pattern for lists
class ListItemSkeleton extends StatefulWidget {
  final int itemCount;
  final bool enableAnimation;
  final Duration animationDuration;
  
  const ListItemSkeleton({
    super.key,
    this.itemCount = 5,
    this.enableAnimation = true,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<ListItemSkeleton> createState() => _ListItemSkeletonState();
}

class _ListItemSkeletonState extends State<ListItemSkeleton>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.itemCount,
      (index) => AnimationController(
        duration: widget.animationDuration,
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.25,
        end: 0.5,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // Staggered animation start for smooth wave effect
    if (widget.enableAnimation) {
      for (int i = 0; i < _controllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 80), () {
          if (mounted) {
            _controllers[i].repeat(reverse: true);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            final opacity = widget.enableAnimation ? _animations[index].value : 0.3;
            
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: UIConstants.smallSpacing,
                horizontal: UIConstants.defaultPadding,
              ),
              child: Row(
                children: [
                  // Avatar skeleton
                  _SkeletonBox(
                    width: 48,
                    height: 48,
                    isCircle: true,
                    opacity: opacity,
                  ),
                  const SizedBox(width: UIConstants.contentSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Primary text
                        _SkeletonBox(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 16,
                          opacity: opacity,
                        ),
                        const SizedBox(height: 6),
                        // Secondary text
                        _SkeletonBox(
                          width: MediaQuery.of(context).size.width * 0.4,
                          height: 14,
                          opacity: opacity * 0.7,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Smooth fade transition wrapper for loading to content
/// Provides Instagram-style content reveal animation
class SmoothContentTransition extends StatefulWidget {
  final bool isLoading;
  final Widget loadingWidget;
  final Widget contentWidget;
  final Duration fadeInDuration;
  final Curve fadeInCurve;
  
  const SmoothContentTransition({
    super.key,
    required this.isLoading,
    required this.loadingWidget,
    required this.contentWidget,
    this.fadeInDuration = const Duration(milliseconds: 350),
    this.fadeInCurve = Curves.easeOut,
  });

  @override
  State<SmoothContentTransition> createState() => _SmoothContentTransitionState();
}

class _SmoothContentTransitionState extends State<SmoothContentTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.fadeInCurve,
      ),
    );

    if (!widget.isLoading) {
      _showContent = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SmoothContentTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.isLoading && !widget.isLoading) {
      // Transition from loading to content
      setState(() {
        _showContent = true;
      });
      _controller.forward();
    } else if (!oldWidget.isLoading && widget.isLoading) {
      // Transition from content to loading
      _controller.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showContent = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showContent) {
      return widget.loadingWidget;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: widget.contentWidget,
    );
  }
}

/// Advanced staggered fade-in animation for lists
/// Twitter-style progressive content reveal
class StaggeredListAnimation extends StatefulWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration fadeInDuration;
  final Curve fadeInCurve;
  
  const StaggeredListAnimation({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 50),
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.fadeInCurve = Curves.easeOut,
  });

  @override
  State<StaggeredListAnimation> createState() => _StaggeredListAnimationState();
}

class _StaggeredListAnimationState extends State<StaggeredListAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.children.length,
      (index) => AnimationController(
        duration: widget.fadeInDuration,
        vsync: this,
      ),
    );

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: widget.fadeInCurve,
        ),
      );
    }).toList();

    _slideAnimations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0.0, 0.02),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: widget.fadeInCurve,
        ),
      );
    }).toList();

    // Start staggered animations
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(widget.itemDelay * i, () {
        if (mounted) {
          _controllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        widget.children.length,
        (index) => AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimations[index],
              child: SlideTransition(
                position: _slideAnimations[index],
                child: widget.children[index],
              ),
            );
          },
        ),
      ),
    );
  }
}