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
import '../report/report_reason_sheet.dart';
import 'post_card.dart';
import 'post_filter_sheet.dart';

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
  State<PostUI> createState() => _PostUIState();
}

class _PostUIState extends State<PostUI> {
  /// Active two-section filter (MY ACTIVITY / DISCOVER). Defaults to
  /// Discover → Newest.
  FeedFilter _feedFilter = FeedFilter.newest;

  /// Inline search on the Post Feed (no separate search screen): when a query
  /// is active the feed body shows search results; clearing returns to the
  /// normal feed.
  final TextEditingController _searchController = TextEditingController();
  bool _searchActive = false;
  String _lastSearchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
    });
    _notifySearchActive();
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
      onApply: (filter) {
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
          // Discover: keep ordering current. Popularity requests the
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
      },
    );
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
    final isSearching = context.select<PostProvider, bool>((p) => p.isSearching);
    final searchError = context.select<PostProvider, String?>((p) => p.searchError);
    // Profile changes rarely; read once for all cards.
    final currentUserId = context.select<ProfileProvider, String?>(
            (p) => p.profile?.userId.toString());

    final posts = _visiblePosts(postProvider);
    final searchResults = postProvider.searchResults;
    final showSearchResults = _searchActive;
    final isMyActivity = _feedFilter.category == FeedFilterCategory.myActivity;
    final isActivityLoading = postProvider.isActivityLoading;
    final activityError = postProvider.activityErrorMessage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Post Feed',
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AppNavigation.toSelectAttraction(context),
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
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

              // Feed / Search content list
              Expanded(
                child: showSearchResults
                    ? _buildSearchContent(
                    postProvider, searchResults, isSearching, searchError, currentUserId)
                    : isMyActivity && isActivityLoading && posts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : isMyActivity && activityError != null && posts.isEmpty
                    ? _buildFeedErrorState(activityError)
                    : isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null && posts.isEmpty
                    ? _buildFeedErrorState(errorMessage)
                    : posts.isEmpty
                    ? _buildEmptyFeedState()
                    : RefreshIndicator(
                  onRefresh: () {
                    final provider = context.read<PostProvider>();
                    if (isMyActivity) {
                      return provider.loadMyActivity();
                    }
                    final popularity =
                        _feedFilter.option == FeedFilterOption.popularity;
                    return provider.loadFeed(
                      category: 'discover',
                      sort: popularity ? 'popularity' : 'newest',
                      min: popularity
                          ? _feedFilter.popularityRange.start.round()
                          : null,
                      max: popularity
                          ? _feedFilter.popularityRange.end.round()
                          : null,
                    );
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.containerMargin,
                      vertical: AppSpacing.stackSm,
                    ),
                    itemCount: posts.length + 1,
                    itemBuilder: (context, i) {
                      if (i == posts.length) {
                        return _buildLabelLegend();
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
      child: TextField(
        controller: _searchController,
        style: AppTypography.bodyMd,
        decoration: InputDecoration(
          hintText: 'What\'s on your mind?',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchActive || _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, size: 20),
            tooltip: 'Clear search',
            onPressed: _clearSearch,
          )
              : null,
          filled: true,
          fillColor: AppColors.surfaceCard,
          border: OutlineInputBorder(
            borderRadius: AppRadii.roundedDefault,
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  /// Search results area shown within the Post Feed (loading / error / empty /
  /// results states).
  Widget _buildSearchContent(PostProvider provider, List<PostModel> results,
      bool isSearching, String? searchError, String? currentUserId) {
    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (searchError != null) {
      return AppErrorState(
        title: 'Search failed',
        message: searchError,
        onRetry: _performSearch,
      );
    }
    if (results.isEmpty) {
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.containerMargin,
        vertical: AppSpacing.stackSm,
      ),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final post = results[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.gutterMd),
          child: RepaintBoundary(
            child: _buildPostCard(context, provider, post, currentUserId),
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
      child: InkWell(
        onTap: _openFilterSheet,
        borderRadius: AppRadii.roundedFull,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: AppRadii.roundedFull,
            border: Border.all(color: AppColors.outlineVariant, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_feedFilter.categoryLabel} · ${_feedFilter.optionLabel}',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLg.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_feedFilter.option == FeedFilterOption.popularity) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: AppRadii.roundedFull,
                  ),
                  child: Text(
                    _feedFilter.rangeLabel,
                    style: AppTypography.labelSm.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
              const Spacer(),
              const Icon(Icons.expand_more, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
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

  Widget _buildEmptyFeedState() {
    final isMyActivity =
        _feedFilter.category == FeedFilterCategory.myActivity;

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
      onRetry: () => isMyActivity
          ? context.read<PostProvider>().loadMyActivity()
          : context.read<PostProvider>().loadFeed(),
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
              AppNavigation.toStatusLoading(
                context,
                heading: 'Deleting Post',
                message:
                'We are safely deleting your post. Please wait a moment.',
              );
              context.read<PostProvider>().deletePost(post.id).then((success) {
                if (!context.mounted) return;
                if (success) {
                  // D-05: close the loading screen and show a green success
                  // banner instead of redirecting to a status screen; the
                  // user stays on the feed they deleted from.
                  Navigator.of(context).pop(); // leave loading screen
                  AppFeedback.show(
                    context,
                    message: 'Post deleted successfully.',
                    isSuccess: true,
                  );
                } else {
                  Navigator.of(context).pop(); // leave loading screen
                  AppFeedback.show(
                    context,
                    message: 'Failed to delete the post. Please try again.',
                    isSuccess: false,
                  );
                }
              });
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

  /// Explicit label legend at the bottom of the feed explaining the four key
  /// relationship states shown on post cards.
  Widget _buildLabelLegend() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: AppSpacing.gutterMd),
      padding: const EdgeInsets.all(AppSpacing.gutterMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadii.roundedDefault,
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Label Legend',
            style: AppTypography.labelLg.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _legendItem(Icons.person_outline, AppColors.success, 'My Post'),
              _legendItem(Icons.flag_outlined, AppColors.error, 'Reported'),
              _legendItem(
                  Icons.chat_bubble_outline, const Color(0xFF5C6BC0), 'You Commented'),
              _legendItem(Icons.favorite, AppColors.primary, 'Liked'),
              _legendItem(Icons.bookmark, const Color(0xFF7B61FF), 'Saved'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'My Post takes priority when you are the author.',
            style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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



