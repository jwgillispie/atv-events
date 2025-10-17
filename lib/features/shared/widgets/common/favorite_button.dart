import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/blocs/favorites/favorites_bloc.dart';


enum FavoriteType { post, vendor, market, event }

class FavoriteButton extends StatelessWidget {
  final String itemId; // Can be postId, vendorId, marketId, or eventId
  final FavoriteType type;
  final double size;
  final Color? favoriteColor;
  final Color? unfavoriteColor;
  final bool showBackground;
  final bool showLabel;

  const FavoriteButton({
    super.key,
    required this.itemId,
    required this.type,
    this.size = 24,
    this.favoriteColor,
    this.unfavoriteColor,
    this.showBackground = false,
    this.showLabel = false,
  });

  // Legacy constructor for backward compatibility
  const FavoriteButton.post({
    super.key,
    required String postId,
    String? vendorId,
    this.size = 24,
    this.favoriteColor,
    this.unfavoriteColor,
    this.showBackground = false,
    this.showLabel = false,
  }) : itemId = postId, type = FavoriteType.post;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesBloc, FavoritesState>(
      builder: (context, state) {
        bool isFavorited;
        switch (type) {
          case FavoriteType.post:
            isFavorited = state.isPostFavorite(itemId);
            break;
          case FavoriteType.vendor:
            isFavorited = state.isVendorFavorite(itemId);
            break;
          case FavoriteType.market:
            isFavorited = state.isMarketFavorite(itemId);
            break;
          case FavoriteType.event:
            isFavorited = state.isEventFavorite(itemId);
            break;
        }
        
        return GestureDetector(
          onTap: () {
            // Provide haptic feedback for better UX
            HapticFeedback.lightImpact();
            
            final authState = context.read<AuthBloc>().state;
            final userId = authState is Authenticated ? authState.user.uid : null;
            
            switch (type) {
              case FavoriteType.post:
                context.read<FavoritesBloc>().add(TogglePostFavorite(postId: itemId, userId: userId));
                break;
              case FavoriteType.vendor:
                context.read<FavoritesBloc>().add(ToggleVendorFavorite(vendorId: itemId, userId: userId));
                break;
              case FavoriteType.market:
                context.read<FavoritesBloc>().add(ToggleMarketFavorite(marketId: itemId, userId: userId));
                break;
              case FavoriteType.event:
                context.read<FavoritesBloc>().add(ToggleEventFavorite(eventId: itemId, userId: userId));
                break;
            }
          },
          child: Container(
            padding: showBackground ? const EdgeInsets.all(8) : EdgeInsets.zero,
            decoration: showBackground
                ? BoxDecoration(
                    color: Colors.white.withOpacity( 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity( 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  )
                : null,
            child: showLabel 
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFavorited ? Icons.favorite : Icons.favorite_border,
                        size: size,
                        color: isFavorited
                            ? (favoriteColor ?? Colors.red)
                            : (unfavoriteColor ?? Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isFavorited ? 'Favorited' : 'Add to Favorites',
                        style: TextStyle(
                          color: isFavorited 
                              ? (favoriteColor ?? Colors.red)
                              : (unfavoriteColor ?? Colors.grey[600]),
                          fontWeight: isFavorited ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  )
                : Icon(
                    isFavorited ? Icons.favorite : Icons.favorite_border,
                    size: size,
                    color: isFavorited
                        ? (favoriteColor ?? Colors.red)
                        : (unfavoriteColor ?? Colors.grey[600]),
                  ),
          ),
        );
      },
    );
  }
}

class AnimatedFavoriteButton extends StatefulWidget {
  final String itemId;
  final FavoriteType type;
  final double size;
  final Color? favoriteColor;
  final Color? unfavoriteColor;

  const AnimatedFavoriteButton({
    super.key,
    required this.itemId,
    required this.type,
    this.size = 24,
    this.favoriteColor,
    this.unfavoriteColor,
  });

  // Legacy constructor for backward compatibility
  const AnimatedFavoriteButton.post({
    super.key,
    required String postId,
    String? vendorId,
    this.size = 24,
    this.favoriteColor,
    this.unfavoriteColor,
  }) : itemId = postId, type = FavoriteType.post;

  @override
  State<AnimatedFavoriteButton> createState() => _AnimatedFavoriteButtonState();
}

class _AnimatedFavoriteButtonState extends State<AnimatedFavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTap() {
    // Provide haptic feedback for better UX
    HapticFeedback.lightImpact();
    
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    
    final authState = context.read<AuthBloc>().state;
    final userId = authState is Authenticated ? authState.user.uid : null;
    
    switch (widget.type) {
      case FavoriteType.post:
        context.read<FavoritesBloc>().add(TogglePostFavorite(postId: widget.itemId, userId: userId));
        break;
      case FavoriteType.vendor:
        context.read<FavoritesBloc>().add(ToggleVendorFavorite(vendorId: widget.itemId, userId: userId));
        break;
      case FavoriteType.market:
        context.read<FavoritesBloc>().add(ToggleMarketFavorite(marketId: widget.itemId, userId: userId));
        break;
      case FavoriteType.event:
        context.read<FavoritesBloc>().add(ToggleEventFavorite(eventId: widget.itemId, userId: userId));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesBloc, FavoritesState>(
      builder: (context, state) {
        bool isFavorited;
        switch (widget.type) {
          case FavoriteType.post:
            isFavorited = state.isPostFavorite(widget.itemId);
            break;
          case FavoriteType.vendor:
            isFavorited = state.isVendorFavorite(widget.itemId);
            break;
          case FavoriteType.market:
            isFavorited = state.isMarketFavorite(widget.itemId);
            break;
          case FavoriteType.event:
            isFavorited = state.isEventFavorite(widget.itemId);
            break;
        }
        
        return GestureDetector(
          onTap: _onTap,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: widget.size,
                  color: isFavorited
                      ? (widget.favoriteColor ?? Colors.red)
                      : (widget.unfavoriteColor ?? Colors.grey[600]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}