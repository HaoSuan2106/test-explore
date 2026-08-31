import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_header.dart';
import '../../../../widgets/app_button.dart';
import '../../../../providers/post_review/post_provider.dart';
import '../../navigation/app_navigation.dart';

/// Full-screen search for community posts. Pulls results from the real API
/// (no fake data). Shows loading, results, empty, error+retry, and clear.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _hasSubmitted = true);
    context.read<PostProvider>().searchPosts(query);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _hasSubmitted = false);
    context.read<PostProvider>().clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to search-scoped changes only. A like/save elsewhere must not
    // rebuild this screen; only search start/results/error/clear do.
    context.select<PostProvider, int>((p) => p.searchVersion);
    final provider = context.read<PostProvider>();
    final results = provider.searchResults;
    final isSearching = provider.isSearching;
    final searchError = provider.searchError;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Search Posts',
        showBack: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.containerMargin,
              AppSpacing.stackMd,
              AppSpacing.containerMargin,
              AppSpacing.stackSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: AppTypography.bodyMd,
                    decoration: InputDecoration(
                      hintText: 'Search posts by title, place, author…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
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
                    ),
                    onSubmitted: (_) => _performSearch(),
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: AppSpacing.stackSm),
                AppButton(
                  text: 'Search',
                  height: 44,
                  onPressed: _performSearch,
                ),
              ],
            ),
          ),

          // Results area
          Expanded(
            child: _buildContent(provider, results, isSearching, searchError),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PostProvider provider, List<PostModel> results,
      bool isSearching, String? searchError) {
    if (!_hasSubmitted) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.stackMd),
            Text(
              'Search for community posts',
              style: AppTypography.headlineMd.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Find posts by title, description, place or author name.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.stackMd),
              Text(
                'Search failed',
                style: AppTypography.headlineMd,
              ),
              const SizedBox(height: 4),
              Text(
                searchError,
                style: AppTypography.bodyMd,
                textAlign: TextAlign.center,
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
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 64, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.stackMd),
              Text(
                'No posts found',
                style: AppTypography.headlineMd,
              ),
              const SizedBox(height: 4),
              Text(
                'No results for "${provider.lastSearchQuery}". Try a different search term.',
                style: AppTypography.bodyMd,
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
          child: _buildResultCard(context, post),
        );
      },
    );
  }

  Widget _buildResultCard(BuildContext context, PostModel post) {
    // A simple card showing the post, reusing the feed-card layout.
    // We show a compact version: title, author, place, description excerpt.
    final relativeDate = _formatDate(post.createdAt);
    return Card(
      color: AppColors.surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedDefault),
      child: InkWell(
        borderRadius: AppRadii.roundedDefault,
        onTap: () => AppNavigation.toPostDetails(context, postId: post.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutterMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      post.authorName.isNotEmpty
                          ? post.authorName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: Text(
                      post.authorName,
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    relativeDate,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackSm),
              // Title
              if (post.title.isNotEmpty) ...[
                Text(
                  post.title,
                  style: AppTypography.headlineMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              // Description excerpt
              Text(
                post.description,
                style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.stackSm),
              // Footer
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      post.location,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.stackMd),
                  Icon(Icons.favorite_border,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    '${post.likes}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.stackMd),
                  Icon(Icons.comment_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    '${post.commentsCount}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final months = const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}