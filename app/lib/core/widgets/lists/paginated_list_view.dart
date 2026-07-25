import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

/// A callback that fetches a page of items.
/// Returns a list of items for the given [pageKey] and [pageSize].
typedef FetchPage<T> = Future<List<T>> Function(int pageKey, int pageSize);

/// Generic paginated list view with pull-to-refresh,
/// built-in loading/error states, and separator support.
class PaginatedListView<T> extends StatefulWidget {
  final FetchPage<T> fetchPage;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int pageSize;
  final Widget Function(BuildContext, int)? separatorBuilder;
  final Widget? noItemsFoundWidget;
  final Widget? firstPageErrorWidget;
  final EdgeInsetsGeometry? padding;

  const PaginatedListView({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.pageSize = 20,
    this.separatorBuilder,
    this.noItemsFoundWidget,
    this.firstPageErrorWidget,
    this.padding,
  });

  /// Creates a sliver variant for use inside [CustomScrollView].
  static Widget sliver<T>({
    Key? key,
    required FetchPage<T> fetchPage,
    required Widget Function(BuildContext context, T item, int index)
        itemBuilder,
    int pageSize = 20,
    Widget Function(BuildContext, int)? separatorBuilder,
    Widget? noItemsFoundWidget,
    Widget? firstPageErrorWidget,
  }) {
    return _PaginatedSliverList<T>(
      key: key,
      fetchPage: fetchPage,
      itemBuilder: itemBuilder,
      pageSize: pageSize,
      separatorBuilder: separatorBuilder,
      noItemsFoundWidget: noItemsFoundWidget,
      firstPageErrorWidget: firstPageErrorWidget,
    );
  }

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final PagingController<int, T> _pagingController =
      PagingController(firstPageKey: 0);

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final items = await widget.fetchPage(pageKey, widget.pageSize);
      final isLastPage = items.length < widget.pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        _pagingController.appendPage(items, pageKey + 1);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _pagingController.refresh(),
      child: _buildList(),
    );
  }

  Widget _buildList() {
    if (widget.separatorBuilder != null) {
      return PagedListView<int, T>.separated(
        pagingController: _pagingController,
        padding: widget.padding,
        separatorBuilder: widget.separatorBuilder!,
        builderDelegate: _buildDelegate(),
      );
    }

    return PagedListView<int, T>(
      pagingController: _pagingController,
      padding: widget.padding,
      builderDelegate: _buildDelegate(),
    );
  }

  PagedChildBuilderDelegate<T> _buildDelegate() {
    return PagedChildBuilderDelegate<T>(
      itemBuilder: widget.itemBuilder,
      firstPageProgressIndicatorBuilder: (_) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      newPageProgressIndicatorBuilder: (_) => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(),
        ),
      ),
      noItemsFoundIndicatorBuilder: widget.noItemsFoundWidget != null
          ? (_) => widget.noItemsFoundWidget!
          : null,
      firstPageErrorIndicatorBuilder: widget.firstPageErrorWidget != null
          ? (_) => widget.firstPageErrorWidget!
          : (context) => _DefaultErrorWidget(
                onRetry: () => _pagingController.refresh(),
              ),
    );
  }
}

/// Sliver variant for use inside [CustomScrollView].
class _PaginatedSliverList<T> extends StatefulWidget {
  final FetchPage<T> fetchPage;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int pageSize;
  final Widget Function(BuildContext, int)? separatorBuilder;
  final Widget? noItemsFoundWidget;
  final Widget? firstPageErrorWidget;

  const _PaginatedSliverList({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.pageSize = 20,
    this.separatorBuilder,
    this.noItemsFoundWidget,
    this.firstPageErrorWidget,
  });

  @override
  State<_PaginatedSliverList<T>> createState() =>
      _PaginatedSliverListState<T>();
}

class _PaginatedSliverListState<T> extends State<_PaginatedSliverList<T>> {
  final PagingController<int, T> _pagingController =
      PagingController(firstPageKey: 0);

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final items = await widget.fetchPage(pageKey, widget.pageSize);
      final isLastPage = items.length < widget.pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(items);
      } else {
        _pagingController.appendPage(items, pageKey + 1);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.separatorBuilder != null) {
      return PagedSliverList<int, T>.separated(
        pagingController: _pagingController,
        separatorBuilder: widget.separatorBuilder!,
        builderDelegate: _buildDelegate(),
      );
    }

    return PagedSliverList<int, T>(
      pagingController: _pagingController,
      builderDelegate: _buildDelegate(),
    );
  }

  PagedChildBuilderDelegate<T> _buildDelegate() {
    return PagedChildBuilderDelegate<T>(
      itemBuilder: widget.itemBuilder,
      firstPageProgressIndicatorBuilder: (_) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      newPageProgressIndicatorBuilder: (_) => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(),
        ),
      ),
      noItemsFoundIndicatorBuilder: widget.noItemsFoundWidget != null
          ? (_) => widget.noItemsFoundWidget!
          : null,
      firstPageErrorIndicatorBuilder: widget.firstPageErrorWidget != null
          ? (_) => widget.firstPageErrorWidget!
          : (context) => _DefaultErrorWidget(
                onRetry: () => _pagingController.refresh(),
              ),
    );
  }
}

/// Default error widget with a retry button.
class _DefaultErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const _DefaultErrorWidget({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
