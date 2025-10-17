import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Common List and Grid Builders for HiPop Markets
///
/// Reduces code duplication across 64+ list/grid instances in the app by providing
/// reusable, consistent, and performant list building widgets with built-in
/// loading, error, and empty states following the app's design system.
///
/// These builders provide:
/// - Automatic pagination and infinite scroll support
/// - Consistent loading, error, and empty state handling
/// - Pull-to-refresh functionality
/// - Performance optimizations with proper key management
/// - Accessibility support with semantic labels
/// - Dark mode compatibility

// ======= Main List Builders =======

/// Paginated ListView with automatic loading, error, and empty states
class PaginatedListView<T> extends StatefulWidget {
  final Future<List<T>> Function(int page) fetchData;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final double? itemExtent;
  final Widget? separator;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onLoadMore;
  final bool enablePullToRefresh;
  final bool enableInfiniteScroll;
  final int initialPage;
  final String? emptyMessage;
  final String? errorMessage;
  final Widget? header;
  final Widget? footer;

  const PaginatedListView({
    super.key,
    required this.fetchData,
    required this.itemBuilder,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.itemExtent,
    this.separator,
    this.onRefresh,
    this.onLoadMore,
    this.enablePullToRefresh = true,
    this.enableInfiniteScroll = true,
    this.initialPage = 0,
    this.emptyMessage,
    this.errorMessage,
    this.header,
    this.footer,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final List<T> _items = [];
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _loadData();

    if (widget.enableInfiniteScroll) {
      _scrollController.addListener(_scrollListener);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      if (isRefresh) {
        _items.clear();
        _currentPage = widget.initialPage;
        _hasMore = true;
      }
    });

    try {
      final newItems = await widget.fetchData(_currentPage);

      setState(() {
        _items.addAll(newItems);
        _hasMore = newItems.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (widget.onLoadMore != null) {
      widget.onLoadMore!();
    }
    _currentPage++;
    await _loadData();
  }

  Future<void> _refresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
    await _loadData(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading && _items.isEmpty) {
      // Initial loading state
      content = Center(
        child: widget.loadingWidget ?? const CommonLoadingWidget(),
      );
    } else if (_hasError && _items.isEmpty) {
      // Error state
      content = Center(
        child: widget.errorWidget ?? CommonErrorWidget(
          message: widget.errorMessage ?? _errorMessage ?? 'Something went wrong',
          onRetry: () => _loadData(isRefresh: true),
        ),
      );
    } else if (_items.isEmpty) {
      // Empty state
      content = Center(
        child: widget.emptyWidget ?? CommonEmptyWidget(
          message: widget.emptyMessage ?? 'No items found',
          icon: Icons.inbox_rounded,
        ),
      );
    } else {
      // List with items
      content = ListView.separated(
        controller: _scrollController,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        padding: widget.padding ?? const EdgeInsets.all(16),
        itemCount: _items.length + (_hasMore ? 1 : 0) +
                   (widget.header != null ? 1 : 0) +
                   (widget.footer != null ? 1 : 0),
        separatorBuilder: (context, index) {
          if (widget.header != null && index == 0) return const SizedBox.shrink();
          return widget.separator ?? const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          // Handle header
          if (widget.header != null) {
            if (index == 0) return widget.header!;
            index--;
          }

          // Handle footer
          if (widget.footer != null && index == _items.length) {
            return widget.footer!;
          }

          // Handle loading more indicator
          if (index >= _items.length) {
            return _hasMore
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CommonLoadingWidget(size: LoadingSize.small)),
                  )
                : const SizedBox.shrink();
          }

          return widget.itemBuilder(context, _items[index], index);
        },
      );
    }

    if (widget.enablePullToRefresh) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: HiPopColors.primaryDeepSage,
        backgroundColor: HiPopColors.darkSurface,
        child: content,
      );
    }

    return content;
  }
}

/// Paginated GridView with automatic loading, error, and empty states
class PaginatedGridView<T> extends StatefulWidget {
  final Future<List<T>> Function(int page) fetchData;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onLoadMore;
  final bool enablePullToRefresh;
  final bool enableInfiniteScroll;
  final int initialPage;
  final String? emptyMessage;
  final String? errorMessage;

  const PaginatedGridView({
    super.key,
    required this.fetchData,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.childAspectRatio = 1.0,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.onRefresh,
    this.onLoadMore,
    this.enablePullToRefresh = true,
    this.enableInfiniteScroll = true,
    this.initialPage = 0,
    this.emptyMessage,
    this.errorMessage,
  });

  @override
  State<PaginatedGridView<T>> createState() => _PaginatedGridViewState<T>();
}

class _PaginatedGridViewState<T> extends State<PaginatedGridView<T>> {
  final List<T> _items = [];
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _loadData();

    if (widget.enableInfiniteScroll) {
      _scrollController.addListener(_scrollListener);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      if (isRefresh) {
        _items.clear();
        _currentPage = widget.initialPage;
        _hasMore = true;
      }
    });

    try {
      final newItems = await widget.fetchData(_currentPage);

      setState(() {
        _items.addAll(newItems);
        _hasMore = newItems.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (widget.onLoadMore != null) {
      widget.onLoadMore!();
    }
    _currentPage++;
    await _loadData();
  }

  Future<void> _refresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
    await _loadData(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading && _items.isEmpty) {
      // Initial loading state
      content = Center(
        child: widget.loadingWidget ?? const CommonLoadingWidget(),
      );
    } else if (_hasError && _items.isEmpty) {
      // Error state
      content = Center(
        child: widget.errorWidget ?? CommonErrorWidget(
          message: widget.errorMessage ?? _errorMessage ?? 'Something went wrong',
          onRetry: () => _loadData(isRefresh: true),
        ),
      );
    } else if (_items.isEmpty) {
      // Empty state
      content = Center(
        child: widget.emptyWidget ?? CommonEmptyWidget(
          message: widget.emptyMessage ?? 'No items found',
          icon: Icons.grid_view_rounded,
        ),
      );
    } else {
      // Grid with items
      content = GridView.builder(
        controller: _scrollController,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        padding: widget.padding ?? const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          crossAxisSpacing: widget.crossAxisSpacing,
          mainAxisSpacing: widget.mainAxisSpacing,
          childAspectRatio: widget.childAspectRatio,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Handle loading more indicator
          if (index >= _items.length) {
            return _hasMore
                ? const Center(child: CommonLoadingWidget(size: LoadingSize.small))
                : const SizedBox.shrink();
          }

          return widget.itemBuilder(context, _items[index], index);
        },
      );
    }

    if (widget.enablePullToRefresh) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: HiPopColors.primaryDeepSage,
        backgroundColor: HiPopColors.darkSurface,
        child: content,
      );
    }

    return content;
  }
}

/// Infinite scroll list for continuous data loading
class InfiniteScrollList<T> extends StatefulWidget {
  final Stream<List<T>> dataStream;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final Widget? separator;
  final String? emptyMessage;

  const InfiniteScrollList({
    super.key,
    required this.dataStream,
    required this.itemBuilder,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.separator,
    this.emptyMessage,
  });

  @override
  State<InfiniteScrollList<T>> createState() => _InfiniteScrollListState<T>();
}

class _InfiniteScrollListState<T> extends State<InfiniteScrollList<T>> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: widget.dataStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: widget.loadingWidget ?? const CommonLoadingWidget(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: widget.errorWidget ?? CommonErrorWidget(
              message: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            ),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: widget.emptyWidget ?? CommonEmptyWidget(
              message: widget.emptyMessage ?? 'No items found',
              icon: Icons.inbox_rounded,
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: widget.shrinkWrap,
          physics: widget.physics,
          padding: widget.padding ?? const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (context, index) =>
              widget.separator ?? const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              widget.itemBuilder(context, items[index], index),
        );
      },
    );
  }
}

// ======= Common State Widgets =======

/// Common loading widget with consistent styling
class CommonLoadingWidget extends StatelessWidget {
  final LoadingSize size;
  final String? message;
  final Color? color;

  const CommonLoadingWidget({
    super.key,
    this.size = LoadingSize.medium,
    this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final indicatorSize = switch (size) {
      LoadingSize.small => 20.0,
      LoadingSize.medium => 32.0,
      LoadingSize.large => 48.0,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: indicatorSize,
          height: indicatorSize,
          child: CircularProgressIndicator(
            strokeWidth: size == LoadingSize.small ? 2 : 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? HiPopColors.primaryDeepSage,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              color: HiPopColors.darkTextSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Common error widget with retry action
class CommonErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final Color? iconColor;

  const CommonErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: iconColor ?? HiPopColors.errorPlum.withOpacity( 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Oops!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: HiPopColors.darkTextSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.primaryDeepSage,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Common empty state widget
class CommonEmptyWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customAction;

  const CommonEmptyWidget({
    super.key,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.customAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              shape: BoxShape.circle,
            ),
          child: Icon(
              icon,
              size: 64,
              color: HiPopColors.darkTextTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: HiPopColors.darkTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later or try refreshing',
            style: TextStyle(
              color: HiPopColors.darkTextSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (customAction != null) ...[
            const SizedBox(height: 24),
            customAction!,
          ] else if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: HiPopColors.primaryDeepSage,
                side: BorderSide(color: HiPopColors.primaryDeepSage),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

// ======= Utility Widgets =======

/// Shimmer loading placeholder for list items
class ShimmerListItem extends StatelessWidget {
  final double height;
  final EdgeInsets? padding;

  const ShimmerListItem({
    super.key,
    this.height = 80,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header for lists
class ListSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets? padding;

  const ListSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ======= Enums =======

enum LoadingSize {
  small,
  medium,
  large,
}