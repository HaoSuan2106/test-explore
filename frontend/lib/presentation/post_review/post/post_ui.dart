import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_header.dart';
import '../../../../widgets/app_button.dart';
import '../../../../providers/auth_profile/profile_provider.dart';
import '../../../../widgets/app_error_state.dart';
import '../../../../widgets/app_feedback.dart';
import '../../../../widgets/content_constraint.dart';
import '../../../providers/post_review/post_provider.dart';
import '../../navigation/app_navigation.dart';
import '../../navigation/app_router.dart' show rootNavigatorKey;
import '../report/report_reason_sheet.dart';
import 'post_card.dart';
import 'post_filter_sheet.dart';

Widget _buildPaginationFooter({
  bool hasMore = true,
  bool isLoadingMore = false,
  bool hasError = false,
  VoidCallback? onRetry,
}) {
  if (isLoadingMore) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.stackSm,
        AppSpacing.containerMargin,
        AppSpacing.stackMd,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.stackMd,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: AppRadii.roundedDefault,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Text(
              'Loading more posts...',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (hasError) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.stackSm,
        AppSpacing.containerMargin,
        AppSpacing.stackMd,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.stackMd),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: AppRadii.roundedDefault,
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 22,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              'Could not load more posts.',
              style: AppTypography.labelLg.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.stackSm),
            AppButton(
              text: 'Try Again',
              variant: AppButtonVariant.outline,
              height: 40,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }

  if (!hasMore) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.stackSm,
        AppSpacing.containerMargin,
        AppSpacing.stackMd,
      ),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.stackSm,
            ),
            child: Text(
              'No more posts',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  // More pages exist and nothing is loading/failing: the scroll listener
  // prefetches automatically, so no footer is shown for this state.
  return const SizedBox.shrink();
}

class PostUI extends StatefulWidget {
  const PostUI({super.key, this.onSearchActiveChanged});

  /// Called whenever the Post Feed's inline-search state changes. Reports
  /// `true` while search results are shown or text is typed — i.e. the states
  /// where PostUI's own PopScope consumes the system back to clear the search.
  /// Reports `false` when the feed is in its normal idle state. MainPage uses
  /// this to decide whether it may switch tabs on system back (instead of
  /// letting the app exit) without stealing PostUI's search-clearing back.
  final ValueChanged<bool>? onSearchActiveChanged;

  @override
  State<PostUI> createState() => PostUIState();
}

class PostUIState extends State<PostUI> {
  /// Active two-section filter (MY ACTIVITY / DISCOVER). Defaults to
  /// Discover → Newest.
  FeedFilter _feedFilter = FeedFilter.newest;

  /// Inline search on the Post Feed (no separate search screen): when a query
  /// is active the feed body shows search results; clearing returns to the
  /// normal feed.
  final TextEditingController _searchController = TextEditingController();
  bool _searchActive = false;
  String _lastSearchQuery = '';

  /// Scroll listener driving AUTOMATIC early pagination: fires when the user
  /// is still ~10 posts (feedPageSize / 2) away from the end of the loaded
  /// list — well before the bottom — so the next page is already loading
  /// while the user reads. Guards in [PostProvider.loadNextPage] make the
  /// extra scroll events harmless (no duplicate requests, no requests after
  /// end-of-feed or while an error footer waits for Retry).
  final ScrollController _feedScrollController = ScrollController();

  @override
  void dispose() {
    _feedScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Early auto-load trigger. The user is ~10 posts (half of a 20-post page)
  /// away from the end of the loaded list when [PostProvider.loadNextPage]
  /// fires — well before the absolute bottom, so page N+1 is already loading
  /// while the user is still reading page N. The remaining distance is
  /// measured in average rendered row heights ((scroll extent + viewport) /
  /// rows), NOT raw pixels, so the same ≈10-post threshold holds on any
  /// phone/tablet. Guard states (already loading, end of feed, pagination
  /// error waiting for Retry) are enforced inside [PostProvider.loadNextPage],
  /// making repeated scroll events harmless.
  void _onFeedScroll() {
    final controller = _feedScrollController;
    if (!controller.hasClients) return;
    final position = controller.position;
    // Nothing scrollable (content fits the screen): nothing to prefetch.
    if (position.maxScrollExtent <= 0) return;
    final provider = context.read<PostProvider>();
    final rowCount = provider.feedPostCount + 1; // +1 = pagination footer row
    if (rowCount <= 1) return;
    final averageRowExtent =
        (position.maxScrollExtent + position.viewportDimension) / rowCount;
    final remainingPosts = position.extentAfter / averageRowExtent;
    if (remainingPosts <= PostProvider.feedPageSize / 2) {
      provider.loadNextPage();
    }
  }

  /// Scrolls the feed back to the top without reloading anything (filter
  /// change / refresh / Back to Top). Guarded for the not-yet-laid-out case.
  void _scrollToTop() {
    if (!_feedScrollController.hasClients) return;
    if (_feedScrollController.offset == 0) return;
    _feedScrollController.jumpTo(0);
  }

  @override
  void initState() {
    super.initState();
    _feedScrollController.addListener(_onFeedScroll);
    // Load the feed on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PostProvider>().loadFeed();
    });
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searchActive = true;
      _lastSearchQuery = query;
    });
    _notifySearchActive();
    context.read<PostProvider>().searchPosts(query);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<PostProvider>().clearSearch();
    setState(() {
      _searchActive = false;
      _lastSearchQuery = '';
      // Provider.reloads Discover → Newest page 1; keep the filter chip label
      // in step with what the feed actually shows.
      _feedFilter = FeedFilter.newest;
    });
    _notifySearchActive();
    _scrollToTop();
  }

  /// True while search results are shown or text is typed — the states where
  /// PostUI's own PopScope consumes the system back to clear the search.
  bool get _searchStateActive => _searchActive || _searchController.text.isNotEmpty;

  void _notifySearchActive() {
    widget.onSearchActiveChanged?.call(_searchStateActive);
  }

  /// The posts shown for the active filter. My Activity sections derive from
  /// provider activity data; Discover sections from the community feed.
  List<PostModel> _visiblePosts(PostProvider provider) {
    switch (_feedFilter.option) {
      case FeedFilterOption.posted:
        return provider.userPosts;
      case FeedFilterOption.commented:
        return provider.commentedPosts;
      case FeedFilterOption.reported:
        return provider.reportedPosts;
      case FeedFilterOption.liked:
        return provider.likedPosts;
      case FeedFilterOption.saved:
        return provider.savedPosts;
      case FeedFilterOption.popularity:
        final range = _feedFilter.popularityRange;
        return provider.feedPosts
            .where((p) {
          final engagement = p.likes + p.commentsCount;
          return engagement >= range.start && engagement <= range.end;
        })
            .toList()
          ..sort((a, b) =>
              (b.likes + b.commentsCount).compareTo(a.likes + a.commentsCount));
      case FeedFilterOption.newest:
        return provider.feedPosts;
    }
  }

  /// Opens the two-section filter sheet (MY ACTIVITY / DISCOVER).
  void _openFilterSheet() {
    PostFilterSheet.show(
      context,
      current: _feedFilter,
      onApply: applyFilter,
    );
  }

  /// Applies [filter] exactly like the sheet's Apply button: switches the
  /// visible section, refreshes the backing data and scrolls to top.
  void applyFilter(FeedFilter filter) {
    setState(() => _feedFilter = filter);
    final provider = context.read<PostProvider>();

    switch (filter.option) {
      case FeedFilterOption.posted:
      case FeedFilterOption.commented:
      case FeedFilterOption.reported:
      case FeedFilterOption.liked:
      case FeedFilterOption.saved:
      // MY ACTIVITY sections read from provider.userPosts /
      // commentedPosts / reportedPosts / likedPosts / savedPosts. Those
      // collections are only populated by loadMyActivity() — which runs
      // the five sub-loads (my posts, my comments, my reports, my likes,
      // saved posts), so every My Activity option renders real data on
      // first use.
        provider.loadMyActivity();
        break;
      case FeedFilterOption.newest:
      case FeedFilterOption.popularity:
      // Discover: server-side ordering. Popularity requests the
      // server-side engagement sort and range (D2).
        final popularity = filter.option == FeedFilterOption.popularity;
        provider.loadFeed(
          category: 'discover',
          sort: popularity ? 'popularity' : 'newest',
          min: popularity
              ? filter.popularityRange.start.round()
              : null,
          max: popularity ? filter.popularityRange.end.round() : null,
        );
        break;
    }
    // Filter change = complete feed reset: page 1, old pagination
    // discarded (seq bump in loadFeed) and back to the top.
    _scrollToTop();
  }

  Future<void> _toggleLike(String postId) async {
    final success = await context.read<PostProvider>().togglePostLike(postId);
    if (!mounted) return;
    if (!success) {
      AppFeedback.show(context, message: 'Failed to update the reaction. Please try again.', isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Coarse-grained subscriptions — rebuild only when the feed list, loading
    // or search state actually changes (not on every single-post mutation).
    final postProvider = context.read<PostProvider>();
    context.select<PostProvider, int>((p) => p.dataVersion);
    final isLoading = context.select<PostProvider, bool>((p) => p.isLoading);
    final errorMessage = context.select<PostProvider, String?>((p) => p.errorMessage);
    // Automatic pagination state (Discover feed AND search results share the
    // same engine, so the same footer/scroll logic covers both).
    final feedHasMore = context.select<PostProvider, bool>((p) => p.feedHasMore);
    final isLoadingMore = context.select<PostProvider, bool>((p) => p.isLoadingMore);
    final paginationError = context.select<PostProvider, String?>((p) => p.paginationError);
    final feedPage = context.select<PostProvider, int>((p) => p.feedPage);
    // Profile changes rarely; read once for all cards.
    final currentUserId = context.select<ProfileProvider, String?>(
            (p) => p.profile?.userId.toString());

    // Search mode renders the SAME unified list: feedPosts holds the search
    // results, the scroll listener, the pagination footer and retry behave
    // identically — no separate search pipeline.
    final posts = _searchActive
        ? postProvider.feedPosts
        : _visiblePosts(postProvider);
    final showSearchResults = _searchActive;
    final isMyActivity = _feedFilter.category == FeedFilterCategory.myActivity;
    final isActivityLoading = postProvider.isActivityLoading;
    final activityError = postProvider.activityErrorMessage;

    // Back to Top appears once ~3 pages have been loaded (spec #13): scroll
    // to top ONLY — no reload, no filter reset, no page-1 re-request.
    final showBackToTop =
        !isMyActivity && posts.isNotEmpty && feedPage >= 3;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Post Feed',
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBackToTop) ...[
            FloatingActionButton.small(
              heroTag: 'postFeedBackToTop',
              onPressed: _scrollToTop,
              tooltip: 'Back to top',
              backgroundColor: AppColors.surfaceCard,
              foregroundColor: AppColors.primary,
              elevation: 3,
              child: const Icon(Icons.arrow_upward, size: 22),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            onPressed: () => AppNavigation.toSelectAttraction(context),
            backgroundColor: AppColors.primary,
            shape: const CircleBorder(),
            elevation: 4,
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ],
      ),
      // PopScope intercepts the system-back / edge-swipe gesture: when search
      // is active (results shown or text typed), back clears the search query
      // instead of popping the screen. A second Back (no search) pops normally.
      body: PopScope(
        canPop: !_searchActive && _searchController.text.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            if (_searchController.text.isNotEmpty && !_searchActive) {
              // Text typed but search not submitted yet — just clear the field.
              _searchController.clear();
              setState(() {});
            } else if (_searchActive) {
              _clearSearch();
            }
          }
        },
        child: ContentConstraint(
          maxWidth: 800,
          child: Column(
            children: [
              // Inline search field (results appear within this same screen).
              _buildSearchBar(),

              if (!showSearchResults) ...[
                // Two-section filter bar (MY ACTIVITY / DISCOVER)
                _buildFilterBar(),
              ],

              // Feed / Search content list — ONE shared body: initial loading,
              // error, empty and the paginated list with its footer behave
              // identically for Discover filters and for search results.
              Expanded(
                child: isMyActivity && isActivityLoading && posts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : isMyActivity && activityError != null && posts.isEmpty
                    ? _buildFeedErrorState(activityError)
                    : isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null && posts.isEmpty
                    ? _buildFeedErrorState(errorMessage)
                    : posts.isEmpty
                    ? _buildEmptyRefreshable()
                    : RefreshIndicator(
                  onRefresh: _onFeedRefresh,
                  child: ListView.builder(
                    controller: _feedScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.containerMargin,
                      vertical: AppSpacing.stackSm,
                    ),
                    itemCount: posts.length + 1,
                    itemBuilder: (context, i) {
                      if (i == posts.length) {
                        // My Activity sections are whole-list loads (the
                        // backend /mine, /comments/mine and /reports/mine
                        // endpoints have no pagination) — no footer there.
                        // A failed sub-load is a real terminal state: render
                        // the error card instead of a bare blank slot.
                        if (isMyActivity) {
                          return activityError != null
                              ? _buildActivityLoadErrorCard(activityError)
                              : const SizedBox.shrink();
                        }
                        return _buildPaginationFooter(
                          hasMore: feedHasMore,
                          isLoadingMore: isLoadingMore,
                          hasError: paginationError != null,
                          onRetry: () => context
                              .read<PostProvider>()
                              .retryLoadNextPage(),
                        );
                      }

                      final post = posts[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.gutterMd),
                        child: RepaintBoundary(
                          child: _buildPostCard(context, postProvider, post, currentUserId),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Search field rendered directly on the Post Feed. Submitting runs the
  /// search; the suffix clear button clears the query and returns to the
  /// normal feed. A camera shortcut on the right launches the create-post flow.
  /// Search field rendered directly on the Post Feed.
  /// Submitting runs search. Clear button removes query.
  /// Camera shortcut launches create-post flow.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.stackSm,
        AppSpacing.containerMargin,
        0,
      ),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _searchController,
          style: AppTypography.bodyMd,
          decoration: InputDecoration(
            hintText: 'What\'s on your mind?',
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon: _searchActive ||
                _searchController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(
                Icons.clear,
                size: 18,
              ),
              tooltip: 'Clear search',
              padding: EdgeInsets.zero,
              onPressed: _clearSearch,
            )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            filled: true,
            fillColor: AppColors.surfaceCard,
            border: OutlineInputBorder(
              borderRadius: AppRadii.roundedDefault,
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          onSubmitted: (_) => _performSearch(),
          onChanged: (value) {
            final wasEmpty = _searchController.text.isEmpty;
            final isEmpty = value.isEmpty;

            if (wasEmpty != isEmpty) {
              setState(() {});
            }

            _notifySearchActive();
          },
          textInputAction: TextInputAction.search,
        ),
      ),
    );
  }

  // NOTE: there is no separate search-results builder anymore. Search runs
  // through the SAME feed body (initial loader, error card, empty state,
  // paginated list + footer + retry) as every filter configuration — see
  // _performSearch / PostProvider.searchPosts.

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        6,
        AppSpacing.containerMargin,
        6,
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: InkWell(
                onTap: _openFilterSheet,
                borderRadius: AppRadii.roundedFull,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: AppRadii.roundedFull,
                    border: Border.all(
                      color: AppColors.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_list,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_feedFilter.categoryLabel} · '
                              '${_feedFilter.optionLabel}',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_feedFilter.option ==
                          FeedFilterOption.popularity) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: AppRadii.roundedFull,
                          ),
                          child: Text(
                            _feedFilter.rangeLabel,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),
          IconButton(
            onPressed: _showLabelGuide,
            icon: const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            tooltip: 'Post label guide',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.containerMargin,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Text(
              title,
              style: AppTypography.headlineMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              message,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.stackMd),
              action,
            ],
          ],
        ),
      ),
    );
  }

  bool get isMyActivityFilter =>
      _feedFilter.category == FeedFilterCategory.myActivity;

  /// Shared refresh handler for the populated list AND the empty state:
  /// stays on the CURRENT filter, never resets to Newest.
  Future<void> _onFeedRefresh() async {
    final provider = context.read<PostProvider>();
    if (isMyActivityFilter) {
      // Refresh stays on the CURRENT My Activity filter — the provider
      // reloads all five activity collections, the UI list keeps deriving
      // from _feedFilter.
      await provider.loadMyActivity();
      return;
    }
    // Refresh = full page-1 reset of the CURRENT captured configuration
    // (search/category/sort/engagement all preserved), then scroll back to
    // the top. The outcome toast reflects real data comparison, not HTTP
    // success (spec Part 4/5): changed → "Updated successfully",
    // identical → "Already up to date", failure → error toast with the old
    // feed intact, superseded → silent.
    _scrollToTop();
    final outcome = await provider.refreshFeedWithFeedback();
    if (!mounted) return;
    switch (outcome) {
      case FeedRefreshOutcome.changed:
        AppFeedback.show(context,
            message: 'Updated successfully', isSuccess: true);
      case FeedRefreshOutcome.unchanged:
        AppFeedback.show(context,
            message: 'Already up to date', isSuccess: true);
      case FeedRefreshOutcome.error:
        AppFeedback.show(context,
            message: "Couldn't refresh. Please try again.", isSuccess: false);
      case FeedRefreshOutcome.superseded:
        break;
    }
  }

  /// Empty state MUST still support pull-to-refresh (every filter supports
  /// it, even when nothing matches). The plain empty widget is not
  /// scrollable, so wrap it in a full-height scroll view with
  /// AlwaysScrollableScrollPhysics inside a RefreshIndicator.
  Widget _buildEmptyRefreshable() {
    return RefreshIndicator(
      onRefresh: _onFeedRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: _buildEmptyFeedState(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFeedState() {
    final isMyActivity =
        _feedFilter.category == FeedFilterCategory.myActivity;
    if (_searchActive) {
      // Empty SEARCH results share the same body contract as every other
      // feed configuration (empty query result, not a separate pipeline).
      return _buildEmptyState(
        icon: Icons.search_off_outlined,
        title: 'No results found',
        message:
            'No posts match "$_lastSearchQuery". Try a different search.',
        action: AppButton(
          text: 'Clear Search',
          variant: AppButtonVariant.outline,
          height: 44,
          onPressed: _clearSearch,
        ),
      );
    }

    return _buildEmptyState(
      icon: isMyActivity
          ? Icons.person_outline
          : Icons.article_outlined,
      title: isMyActivity
          ? 'No activity yet'
          : 'No posts yet',
      message: isMyActivity
          ? 'Your posts, comments, reports and saved places will appear here.'
          : 'Be the first explorer to share a story!',
    );
  }

  Widget _buildFeedErrorState(String message) {
    final isMyActivity = _feedFilter.category == FeedFilterCategory.myActivity;
    return AppErrorState(
      title: isMyActivity ? 'Could not load your activity' : 'Could not load the feed',
      message: message,
      // Retry re-requests the SAME failed page-1 configuration (search,
      // category, sort, engagement all preserved) — never a bare reset that
      // would silently clear the user's active filters.
      onRetry: () => isMyActivity
          ? context.read<PostProvider>().loadMyActivity()
          : context.read<PostProvider>().refreshFeed(),
    );
  }

  /// Inline error card shown at the end of a My Activity list when one of
  /// its sub-loads failed while earlier data already rendered (the screen
  /// error/empty branches above only cover the nothing-loaded case).
  Widget _buildActivityLoadErrorCard(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.stackMd),
      child: AppErrorState(
        title: 'Could not load your activity',
        message: message,
        onRetry: () => context.read<PostProvider>().loadMyActivity(),
      ),
    );
  }

  /// Shows a confirmation dialog before deleting a post (REQ501_42).
  void _confirmDeletePost(BuildContext context, PostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Full-screen loading while the deletion runs (shared status
              // architecture), then land on the Post Deleted success screen.
              final postProvider = context.read<PostProvider>();
              // Double-tap protection: if a delete is already running, the
              // loading screen was already pushed for it — do not push a
              // second one and do not re-issue the delete (§9).
              if (postProvider.isDeleting) return;
              // Push/completion must use the SCREEN's context (State.context),
              // never the ListView itemBuilder context this handler received:
              // when the delete completes, the provider removes the post and
              // rebuilds the feed — the deleted item's element is disposed, so
              // `context.mounted` flips false and a naive guard skips BOTH the
              // pop and the feedback, stranding the loading screen forever
              // (the reported infinite "Deleting Post" spinner, reproduced on
              // device 2026-07-15).
              AppNavigation.toStatusLoading(
                this.context,
                heading: 'Deleting Post',
                message:
                'We are safely deleting your post. Please wait a moment.',
              );
              postProvider.deletePost(post.id).then((success) async {
                if (!mounted) {
                  // The whole screen is gone — still clear the loading route
                  // through the root navigator so the spinner cannot strand.
                  _popLoadingRouteViaRoot();
                  return;
                }
                // Wait one frame so the pushed loading route is actually
                // materialized before popping. A fast resolve (or an instant
                // error) otherwise runs this pop BEFORE the router has
                // inserted the '/status/loading' page: the pop then sees the
                // pre-push stack — a no-op here (or the wrong page on the
                // details flow) — and the loading screen lands afterwards and
                // stays on the stack forever (the reported infinite
                // "Deleting Post" spinner). One endOfFrame guarantees the
                // completion pop happens after the pushed page exists.
                await WidgetsBinding.instance.endOfFrame;
                if (!mounted) {
                  _popLoadingRouteViaRoot();
                  return;
                }
                // Router-consistent pop: Navigator.pop can race the router
                // and remove the wrong page when the pushed loading screen
                // has not been materialized yet (the reported loop).
                AppNavigation.popTopRoute(this.context); // leave loading screen
                AppFeedback.show(
                  this.context,
                  message: success
                      ? 'Post deleted successfully.'
                      : 'Failed to delete the post. Please try again.',
                  isSuccess: success,
                );
              });
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Safety net for the delete flow: pops the top route of the ROOT navigator
  /// directly. If the PostUI state itself is gone by delete completion (the
  /// whole feed screen was replaced), the router-context pop above is
  /// impossible — this guarantees the '/status/loading' route still leaves
  /// the stack so the spinner can never strand.
  void _popLoadingRouteViaRoot() {
    final navigator = rootNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  /// Builds a [PostCard] for the feed, wiring all user actions to the
  /// screen-level handlers that own provider orchestration. Derived flags
  /// (isCommented / isLikeInFlight / myCommentPreview) are computed inside
  /// [PostCard] from the provider, so only the affected card rebuilds.
  Widget _buildPostCard(
      BuildContext context, PostProvider postProvider, PostModel post, String? currentUserId) {
    final isOwner = currentUserId != null && post.authorId == currentUserId;

    return PostCard(
      post: post,
      isOwner: isOwner,
      onTap: () => AppNavigation.toPostDetails(
        context,
        postId: post.id,
      ),
      onReaction: () => _toggleLike(post.id),
      onSave: () => _toggleSave(context, post),
      onReport: () async {
        final result =
        await ReportReasonSheet.show(context, postId: post.id);
        if (!context.mounted) return;
        if (result == ReportResult.submitted) {
          AppNavigation.toReportSubmittedSuccess(context);
        }
      },
      onEdit: () => AppNavigation.toEditPost(context, postId: post.id),
      onDelete: () => _confirmDeletePost(context, post),
    );
  }

  /// Opens the larger post-label guide from the info button.
  void _showLabelGuide() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Post Label Guide',
                        style: AppTypography.headlineMd.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.stackSm),
                _labelGuideItem(
                  Icons.person_outline,
                  AppColors.success,
                  'My Post',
                  'You created this post.',
                ),
                _labelGuideItem(
                  Icons.flag_outlined,
                  AppColors.error,
                  'Reported Post',
                  'You reported this post.',
                ),
                _labelGuideItem(
                  Icons.chat_bubble_outline,
                  const Color(0xFF5C6BC0),
                  'You Commented',
                  'You commented on this post.',
                ),
                _labelGuideItem(
                  Icons.favorite,
                  AppColors.primary,
                  'Liked',
                  'You liked this post.',
                ),
                _labelGuideItem(
                  Icons.bookmark,
                  const Color(0xFF7B61FF),
                  'Saved',
                  'You saved this post.',
                ),
                const SizedBox(height: 4),
                Text(
                  'A post can have more than one label. '
                      'Several labels can appear on the same post.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _labelGuideItem(
      IconData icon,
      Color color,
      String title,
      String meaning,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLg.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  meaning,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSave(BuildContext context, PostModel post) async {
    final success =
    await context.read<PostProvider>().toggleSavePost(post.id);
    if (!context.mounted) return;
    if (success) {
      AppFeedback.show(context,
          message: post.isSaved ? 'Post saved.' : 'Post unsaved.',
          isSuccess: true);
    } else {
      AppFeedback.show(context,
          message: 'Failed to update the saved state. Please try again.',
          isSuccess: false);
    }
  }
}
