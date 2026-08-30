import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_header.dart';
import '../../../../widgets/app_button.dart';
import '../../../../providers/auth_profile/profile_provider.dart';
import '../../../../utils/time_format.dart';
import '../../../../widgets/app_feedback.dart';
import '../../../../widgets/content_constraint.dart';
import '../../../providers/post_review/post_provider.dart';
import '../../../models/community/message_model.dart';
import '../../community/share_to_chat/share_to_chat_sheet.dart';
import '../../navigation/app_navigation.dart';
import '../report/report_reason_sheet.dart';
import 'post_filter_sheet.dart';

class PostUI extends StatefulWidget {
  const PostUI({super.key});

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
    context.read<PostProvider>().searchPosts(query);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<PostProvider>().clearSearch();
    setState(() {
      _searchActive = false;
      _lastSearchQuery = '';
    });
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
        // Keep Discover ordering current when switching to it. Popularity
        // requests the server-side engagement sort and range (D2).
        final popularity = filter.option == FeedFilterOption.popularity;
        context.read<PostProvider>().loadFeed(
              category: 'discover',
              sort: popularity ? 'popularity' : 'newest',
              min: popularity
                  ? filter.popularityRange.start.round()
                  : null,
              max: popularity ? filter.popularityRange.end.round() : null,
            );
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
    final postProvider = context.watch<PostProvider>();
    final posts = _visiblePosts(postProvider);
    final searchResults = postProvider.searchResults;
    final isSearching = postProvider.isSearching;
    final searchError = postProvider.searchError;
    final showSearchResults = _searchActive;

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
                        postProvider, searchResults, isSearching, searchError)
                    : postProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : postProvider.errorMessage != null && posts.isEmpty
                    ? _buildFeedErrorState(postProvider.errorMessage!)
                    : posts.isEmpty
                    ? _buildEmptyFeedState()
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                    vertical: AppSpacing.stackSm,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, i) {
                    final post = posts[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.gutterMd),
                      child: _buildFeedCard(context, post),
                    );
                  },
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
  /// normal feed.
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
          hintText: 'Search posts by title, place, author…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchActive || _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
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
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  /// Search results area shown within the Post Feed (loading / error / empty /
  /// results states).
  Widget _buildSearchContent(
      PostProvider provider, List<PostModel> results, bool isSearching, String? searchError) {
    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (searchError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.stackMd),
            Text('Search failed', style: AppTypography.headlineMd),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(searchError, style: AppTypography.bodyMd, textAlign: TextAlign.center),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            AppButton(
              text: 'Retry',
              icon: Icons.refresh,
              variant: AppButtonVariant.outline,
              height: 44,
              onPressed: _performSearch,
            ),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.stackMd),
            Text('No results found', style: AppTypography.headlineMd),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'No posts match "$_lastSearchQuery". Try a different search.',
                style: AppTypography.bodyMd,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            AppButton(
              text: 'Clear Search',
              variant: AppButtonVariant.outline,
              height: 44,
              onPressed: _clearSearch,
            ),
          ],
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
          child: _buildFeedCard(context, post),
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

  Widget _buildEmptyFeedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.article_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.stackMd),
          Text('No posts yet', style: AppTypography.headlineMd),
          const SizedBox(height: 4),
          Text('Be the first explorer to share a story!', style: AppTypography.bodyMd),
        ],
      ),
    );
  }

  Widget _buildFeedErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 64, color: AppColors.error),
          const SizedBox(height: AppSpacing.stackMd),
          Text('Could not load the feed', style: AppTypography.headlineMd),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, style: AppTypography.bodyMd, textAlign: TextAlign.center),
          ),
          const SizedBox(height: AppSpacing.stackMd),
          AppButton(
            text: 'Retry',
            icon: Icons.refresh,
            variant: AppButtonVariant.outline,
            height: 44,
            onPressed: () => context.read<PostProvider>().loadFeed(),
          ),
        ],
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

  Widget _buildFeedCard(BuildContext context, PostModel post) {
    final postProvider = context.watch<PostProvider>();
    // Ownership is resolved against the current user id, compared as strings:
    // in demo mode the demo identity owns the seeded posts (the real profile
    // id differs from the demo seed ids); in real mode the authenticated
    // profile id must equal the post's authorId.
    final currentUserId = postProvider.demoMode
        ? postProvider.demoCurrentUserId
        : context.watch<ProfileProvider>().profile?.userId.toString();
    final isOwner = currentUserId != null && post.authorId == currentUserId;

    return InkWell(
      onTap: () => AppNavigation.toPostDetails(context, postId: post.id),
      borderRadius: AppRadii.roundedLg,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.gutterMd),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadii.roundedLg,
          border: Border.all(color: AppColors.outline),
          boxShadow: AppShadows.softElevation,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top author row with 3-dot popup menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: AppRadii.roundedFull,
                  child: Image.network(
                    post.authorAvatar,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.person, color: Colors.white, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.authorName,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelLg.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            timeAgo(post.createdAt),
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(width: 4),
                          _buildCardPopupMenu(context, post, isOwner),
                        ],
                      ),
                      Text(
                        post.location,
                        style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isOwner ||
                (post.isReportedByCurrentUser && !isOwner) ||
                (postProvider.commentedPostIds.contains(post.id) && !isOwner) ||
                (post.isSaved && !isOwner)) ...[
              const SizedBox(height: AppSpacing.stackSm),
              _buildCardLabels(context, post, isOwner),
            ],
            const SizedBox(height: AppSpacing.stackMd),

            // Large rounded post image
            ClipRRect(
              borderRadius: AppRadii.roundedDefault,
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.image, size: 40, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),

            // Title and Description
            Text(
              post.title,
              style: AppTypography.headlineMd.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              post.description,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.stackMd),

            // Engagement footer — Wrap allows actions to flow to the next
            // line on narrow screens so no button is clipped.
            Wrap(
              spacing: AppSpacing.gutterMd,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  onTap: post.isReportedByCurrentUser
                      ? null
                      : postProvider.isLikeInFlight(post.id)
                          ? null
                          : () => _toggleLike(post.id),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        postProvider.isLikeInFlight(post.id)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                post.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 18,
                                color: post.isReportedByCurrentUser
                                    ? AppColors.textMuted
                                    : post.isLiked
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                              ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.likes}',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post.commentsCount}',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => showShareToChatSheet(
                    context,
                    sharedPost: SharedPostRequest(
                      postId: post.id,
                      postTitle: post.title,
                      postImageUrl: post.imageUrl,
                      postLocation: post.location,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.share_outlined, size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Share',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Small status chips on the feed card that make the post's relationship to
  /// the current user explicit:
  ///   - "MY POST"   (own post → Edit/Delete available)
  ///   - "REPORTED"  (current user reported this post)
  ///   - "YOU COMMENTED" (current user commented on this post)
  ///   - "SAVED"     (current user saved this post)
  /// A normal community post shows no chip.
  Widget _buildCardLabels(BuildContext context, PostModel post, bool isOwner) {
    final provider = context.watch<PostProvider>();
    final isCommented = provider.commentedPostIds.contains(post.id);
    final chips = <Widget>[];
    if (isOwner) {
      chips.add(_labelChip('MY POST', AppColors.primary));
    } else {
      if (post.isReportedByCurrentUser) {
        chips.add(_labelChip('REPORTED', AppColors.error));
      }
      if (isCommented) {
        chips.add(_labelChip('YOU COMMENTED', const Color(0xFF5C6BC0)));
      }
      if (post.isSaved) {
        chips.add(_labelChip('SAVED', const Color(0xFF7B61FF)));
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }

  Widget _labelChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadii.roundedFull,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == 'MY POST'
                ? Icons.person_outline
                : label == 'REPORTED'
                    ? Icons.flag_outlined
                    : label == 'SAVED'
                        ? Icons.bookmark
                        : Icons.chat_bubble_outline,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPopupMenu(BuildContext context, PostModel post, bool isOwner) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedDefault),
      onSelected: (val) {
        if (val == 'edit') {
          AppNavigation.toEditPost(context, postId: post.id);
        } else if (val == 'delete') {
          _confirmDeletePost(context, post);
        } else if (val == 'report') {
          ReportReasonSheet.show(context, postId: post.id);
        } else if (val == 'save') {
          _toggleSave(context, post);
        } else if (val == 'unsave') {
          _toggleSave(context, post);
        }
      },
      itemBuilder: (context) => [
        if (isOwner) ...[
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ] else if (post.isReportedByCurrentUser) ...[
          // Final scope: a report is recorded and cannot be withdrawn, so the
          // reported post card shows a non-actionable indicator only.
          const PopupMenuItem(
            enabled: false,
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('Reported', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ] else ...[
          PopupMenuItem(
            value: post.isSaved ? 'unsave' : 'save',
            child: Row(
              children: [
                Icon(
                  post.isSaved
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 8),
                Text(post.isSaved ? 'Unsave' : 'Save'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: AppColors.error),
                SizedBox(width: 8),
                Text('Report', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
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