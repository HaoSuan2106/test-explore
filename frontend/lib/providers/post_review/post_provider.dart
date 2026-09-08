import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../api_communication/http_client/http_client.dart';
import '../../models/post_review/post_model.dart';
import '../../utilities/error_message.dart';
import '../session_scoped_provider.dart';

/// Result of a content-aware refresh ([PostProvider.refreshFeedWithFeedback]).
enum FeedRefreshOutcome {
  /// Fresh data differs from what was displayed before → "Updated
  /// successfully".
  changed,

  /// Fresh data is identical to what was displayed before → "Already up to
  /// date".
  unchanged,

  /// The refresh request failed; previously loaded data stays visible →
  /// "Couldn't refresh. Please try again."
  error,

  /// A newer feed operation superseded this refresh while it was in flight;
  /// no toast is shown.
  superseded,
}

/// UI-facing community post model. Maps from the API [PostSummaryModel].
class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String location;
  final String title;
  final String description;
  final String imageUrl;
  final List<String> galleryImages;
  int likes;
  int commentsCount;
  bool isLiked;
  // Mutable (like isSaved/isLiked): flipped in place right after a
  // successful report submission so the card reacts IMMEDIATELY, without
  // waiting for a network reload to confirm the new reported state.
  bool isReportedByCurrentUser;
  bool isSaved;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.location,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.galleryImages = const [],
    this.likes = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isReportedByCurrentUser = false,
    this.isSaved = false,
    required this.createdAt,
  });

  factory PostModel.fromSummary(PostSummaryModel s) => PostModel(
        id: s.postId,
        authorId: s.authorId.toString(),
        authorName: s.authorName,
        authorAvatar: s.authorAvatarUrl ?? '',
        location: s.taggedPlaceName.isNotEmpty
            ? s.taggedPlaceName
            : s.taggedPlaceAddress,
        title: s.title ?? '',
        description: s.description,
        imageUrl: s.imageUrls.isNotEmpty ? s.imageUrls.first : '',
        galleryImages: s.imageUrls,
        likes: s.reactionCount,
        commentsCount: s.commentCount,
        isLiked: s.isReactedByCurrentUser,
        isReportedByCurrentUser: s.isReportedByCurrentUser,
        isSaved: s.isSavedByCurrentUser,
        createdAt: s.createdAt,
      );
}

class UserCommentItem {
  final String commentId;
  final String postId;
  final String postTitle;
  String content;
  final int authorId;
  final String authorName;
  final String authorAvatar;
  int likes;
  bool isLiked;
  final DateTime createdAt;

  UserCommentItem({
    required this.commentId,
    required this.postId,
    required this.postTitle,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorAvatar = '',
    this.likes = 0,
    this.isLiked = false,
    required this.createdAt,
  });

  factory UserCommentItem.fromApi(PostCommentModel c) => UserCommentItem(
        commentId: c.commentId,
        postId: c.postId,
        postTitle: c.postTitle,
        content: c.content,
        authorId: c.authorId,
        authorName: c.authorName,
        authorAvatar: c.authorAvatarUrl ?? '',
        likes: c.likesCount,
        createdAt: c.createdAt,
      );
}

class UserReportItem {
  final String reportId;
  final String postId;
  final String postTitle;
  final String postedBy;
  final String reason;
  final String? details;
  final DateTime submittedAt;

  UserReportItem({
    required this.reportId,
    required this.postId,
    required this.postTitle,
    required this.postedBy,
    required this.reason,
    this.details,
    required this.submittedAt,
  });

  factory UserReportItem.fromApi(PostReportModel r) => UserReportItem(
        reportId: r.reportId,
        postId: r.postId,
        postTitle: r.postTitle,
        postedBy: r.postedBy,
        reason: r.reason,
        details: r.postDescription.isNotEmpty ? r.postDescription : null,
        submittedAt: r.createdAt,
      );
}

/// Real-API-only community post provider. Every loader and mutation talks to
/// the backend through [HttpClient]; there is no in-memory mock / demo feed.
class PostProvider with ChangeNotifier implements SessionScopedProvider {
  final HttpClient? httpClient;

  PostProvider({this.httpClient}) {
    // Predefine the report reasons as a graceful fallback (they mirror the
    // backend's PostReportReasons.All) so the report sheet always has options
    // even if the reasons endpoint is temporarily unreachable. These are
    // predefined report reasons, not Post Feed mock data.
    if (_reportReasons.isEmpty) {
      _reportReasons = _fallbackReportReasons;
    }
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// True while a [deletePost] is in flight. Doubles as the double-tap /
  /// duplicate-confirmation guard for the delete flow (ONE delete per
  /// action). Resets in `finally` on success AND failure.
  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;

  /// Tombstones for posts deleted during this session. Server responses that
  /// raced a delete (issued before the DELETE completed) can still carry the
  /// deleted post; filtering such rows at ingestion keeps a deleted post from
  /// reappearing in the feed (delete+refresh / delete+pagination races).
  static const Duration _deleteTombstoneTtl = Duration(minutes: 1);
  final Map<String, DateTime> _recentlyDeletedIds = {};

  /// Whether [postId] was recently deleted server-side (tombstone active).
  /// Lazily drops expired tombstones.
  bool _isRecentlyDeleted(String postId) {
    final at = _recentlyDeletedIds[postId];
    if (at == null) return false;
    if (DateTime.now().difference(at) > _deleteTombstoneTtl) {
      _recentlyDeletedIds.remove(postId);
      return false;
    }
    return true;
  }

  /// Extracts a user-facing message from a caught error: the backend's business
  /// message (409 duplicate report, 403 reporter view-only rules, 400
  /// validation, "Post not found") and network/timeout text come through
  /// the shared [messageForError] mapper; the caller's generic fallback is used
  /// only when the backend sent nothing usable (or the error is not HTTP).
  /// Commenting is allowed for BOTH owner and normal user — the old "403
  /// self-comment" backend rule was removed; only reporters with an active
  /// report are view-only.
  static String _errorText(Object error, String fallback) =>
      error is DioException ? messageForError(error) ?? fallback : fallback;

  bool _isActivityLoading = false;
  bool get isActivityLoading => _isActivityLoading;

  String? _activityErrorMessage;
  String? get activityErrorMessage => _activityErrorMessage;

  bool _isCommentSubmitting = false;
  bool get isCommentSubmitting => _isCommentSubmitting;

  bool _isCommentDeleting = false;
  bool get isCommentDeleting => _isCommentDeleting;

  final Set<String> _likesInFlight = {};
  bool isLikeInFlight(String postId) => _likesInFlight.contains(postId);

  final Set<String> _savesInFlight = {};
  bool isSaveInFlight(String postId) => _savesInFlight.contains(postId);

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ---------------- Feed pagination (automatic scroll-load) ----------------
  // Offset pagination over the frozen two-section feed contract. [loadFeed]
  // always (re)loads page 1 and stores the exact query so [loadNextPage] can
  // request the SAME query with page+1 — filters are therefore preserved on
  // every automatic page load (category/sort/min/max/type).
  /// Query of the currently loaded feed, captured for loadNextPage.
  String? _feedCategory;
  String? _feedType;
  String? _feedSort;
  int? _feedMin;
  int? _feedMax;
  String? _feedFilterParam;

  /// Active search inside the unified feed engine. When set, feed requests go
  /// to the paginated `GET /api/posts/search` endpoint with the SAME
  /// page/pageSize rules as every other feed configuration — search is just
  /// another FeedQuery value, not a separate one-shot result list.
  String? _feedSearchQuery;

  /// Last successfully loaded feed page. Never advanced on failure, so a
  /// retry requests the SAME failed page.
  int _feedPage = 1;

  /// Fixed feed page size (server default; backend validates page/pageSize >= 1).
  static const int feedPageSize = 20;

  /// False once a page returns fewer rows than [feedPageSize] — the end of
  /// the feed. No further automatic requests are made.
  bool _feedHasMore = true;

  /// True while an automatic next-page request is in flight. Guards against
  /// duplicate requests from rapid scroll events.
  bool _isLoadingMore = false;

  /// Last pagination failure. While set, auto-load stays stopped (no spinning
  /// retry loop); the user resumes explicitly via [retryLoadNextPage].
  String? _paginationError;

  /// Monotonic feed generation. Bumped by every [loadFeed] (refresh / filter
  /// change) so a slow in-flight [loadNextPage] can never append into a feed
  /// that was reset meanwhile.
  int _feedSeq = 0;

  /// Minimum time the "Loading more posts..." footer stays visible. A very
  /// fast pagination response would otherwise flip the footer in and out
  /// within a single frame, which reads as flicker instead of feedback
  /// ("more posts are loading"). The API request itself is NEVER delayed —
  /// it starts immediately; only the [isLoadingMore] = false transition
  /// waits out the remaining time when the request finished in under 500 ms.
  static const Duration _paginationMinIndicatorVisible =
      Duration(milliseconds: 500);

  int get feedPage => _feedPage;
  bool get feedHasMore => _feedHasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get paginationError => _paginationError;

  /// Search mode of the unified feed engine: true while the current feed is
  /// driven by an active search query (the feed list itself holds the
  /// results — there is no separate search result collection anymore).
  bool get isSearchMode => _feedSearchQuery != null;

  /// The active search query, for the UI (e.g. "no results for …" copy).
  String? get activeSearchQuery => _feedSearchQuery;

  /// Cheap count for the scroll listener (avoids copying the list per event).
  int get feedPostCount => _feedPosts.length;

  // ---------------- Search (unified feed engine) ----------------
  // Search is a FeedQuery value of the SAME pagination engine as every other
  // feed configuration: [searchPosts] is a thin wrapper over [loadFeed]
  // (complete reset, page 1, seq bump) and [loadNextPage] re-requests the
  // captured search query with page+1 via the paginated backend
  // `GET /api/posts/search` endpoint. There is no separate search result
  // list, no separate search page counter and no separate loading flag.

  /// Last submitted search text, for the UI's "no results for …" copy.
  String _lastSearchQuery = '';
  String get lastSearchQuery => _lastSearchQuery;

  /// Monotonic My Activity sequence. Guards against stale sub-load results
  /// from a prior filter switch overwriting a newer load (stale-response
  /// protection). Mirrors the feed [_feedSeq] pattern.
  int _activitySeq = 0;

  /// Runs an in-feed search: full feed reset (stop old pagination, invalidate
  /// in-flight requests, page 1, clear error/loading state) and loads the
  /// search configuration. A slow earlier query can never overwrite a newer
  /// one — every [loadFeed] bumps the shared [_feedSeq].
  Future<void> searchPosts(String query) async {
    final trimmed = query.trim();
    _lastSearchQuery = trimmed;
    if (trimmed.isEmpty) {
      await clearSearch();
      return;
    }
    _feedSearchQuery = trimmed;
    await loadFeed(search: trimmed);
  }

  /// Exits search mode and reloads the plain feed (Discover → Newest, page 1).
  /// The stale search FeedQuery is discarded, matching the filter-change
  /// reset semantics; the Post Feed filter chip resets to Newest in step.
  Future<void> clearSearch() async {
    _feedSearchQuery = null;
    _lastSearchQuery = '';
    await loadFeed(category: 'discover', sort: 'newest');
  }

  // ---------------- Draft (create / edit) ----------------
  String _draftTitle = '';
  String _draftDescription = '';
  String _draftLocation = '';
  String _draftTaggedPlaceId = '';
  List<String> _draftPhotos = [];

  /// Draft-scoped version, bumped on every draft write. Lets the Edit/Preview
  /// screens subscribe via a cheap `context.select` on an int instead of
  /// watching the whole provider (draft writes must not rebuild the feed).
  int _draftVersion = 0;
  int get draftVersion => _draftVersion;

  String get draftTitle => _draftTitle;
  String get draftDescription => _draftDescription;
  String get draftLocation => _draftLocation;
  String get draftTaggedPlaceId => _draftTaggedPlaceId;
  List<String> get draftPhotos => _draftPhotos;

  void setDraft({
    required String title,
    required String description,
    required String location,
    String taggedPlaceId = '',
    required List<String> photos,
  }) {
    _draftTitle = title;
    _draftDescription = description;
    _draftLocation = location;
    _draftTaggedPlaceId = taggedPlaceId;
    _draftPhotos = photos;
    _draftVersion++;
    notifyListeners();
  }

  void clearDraft() {
    _draftTitle = '';
    _draftDescription = '';
    _draftLocation = '';
    _draftTaggedPlaceId = '';
    _draftPhotos = [];
    _draftVersion++;
    notifyListeners();
  }

  // ---------------- Data ----------------
  final List<PostModel> _feedPosts = [];
  final List<PostModel> _myPosts = [];
  final List<UserCommentItem> _userComments = [];
  final List<UserReportItem> _userReports = [];
  final List<PostModel> _savedPosts = [];
  final List<PostModel> _likedPosts = [];

  /// Posts the current user has an ACTIVE report on (My Activity → Reported).
  /// Server-loaded from the paginated `myActivity&type=reported` feed
  /// configuration — NOT derived from [_feedPosts]: the discover feed now
  /// excludes reported-by-current-user posts at the DB level, so the Reported
  /// view needs its own authoritative source.
  final List<PostModel> _reportedFeedPosts = [];
  PostModel? _singlePost;
  final Map<String, List<UserCommentItem>> _postComments = {};

  /// Post ids the current user has commented on, maintained incrementally so
  /// feed cards can query it cheaply (no per-build Set rebuild).
  final Set<String> _commentedPostIds = {};

  /// First user-comment preview per post id, maintained incrementally.
  final Map<String, String> _commentPreviewByPost = {};

  /// Monotonic per-post revision counter. Bumped whenever a single post's
  /// mutable state (likes/saved/comments) changes so cards can subscribe to
  /// their own post only via `context.select<PostProvider, int>(...)`.
  final Map<String, int> _postRevisions = {};

  /// Monotonic feed/activity version. Bumped whenever the feed, my-activity
  /// or search result *lists* change, so the Post Feed screen rebuilds only
  /// on real list changes (not on single-post like/save/comment).
  int _dataVersion = 0;

  List<PostModel> get feedPosts => List.unmodifiable(_feedPosts);
  List<PostModel> get userPosts => List.unmodifiable(_myPosts);
  List<UserCommentItem> get userComments => List.unmodifiable(_userComments);
  List<UserReportItem> get userReports => List.unmodifiable(_userReports);
  List<PostModel> get likedPosts => List.unmodifiable(_likedPosts);

  /// Version of the feed/activity/search lists. Subscribe to this (instead of
  /// watching the whole provider) to rebuild the feed only when a list change
  /// actually happened.
  int get dataVersion => _dataVersion;

  /// Post ids the current user has commented on (drives the "Commented"
  /// card label and the My Activity → Commented filter). Cheap O(1) lookup.
  Set<String> get commentedPostIds => _commentedPostIds;

  /// First line of the current user's comment on [postId], if any.
  String? commentPreviewFor(String postId) => _commentPreviewByPost[postId];

  /// Current revision for [postId]; cards subscribe to this value.
  int postRevision(String postId) => _postRevisions[postId] ?? 0;

  void _bumpPostRevision(String postId) {
    _postRevisions[postId] = (_postRevisions[postId] ?? 0) + 1;
  }

  void _bumpDataVersion() => _dataVersion++;

  /// Keeps the My Activity collections consistent with an in-place post
  /// mutation so the filtered views stay logically correct WITHOUT a reload:
  ///   Liked — post joins/leaves [_likedPosts] following [post.isLiked]
  ///   Saved — post joins/leaves [_savedPosts] following [post.isSaved]
  /// Called after a successful like/unlike or save/unsave. Membership
  /// changes bump [_dataVersion] so the PostUI list (which selects on it)
  /// rebuilds in the same frame — e.g. unsave while the Saved filter is
  /// active makes the post disappear immediately, no pull-to-refresh.
  void _syncPostMembership(PostModel post) {
    var changed = false;
    void reconcile(List<PostModel> list, bool member) {
      final index = list.indexWhere((p) => p.id == post.id);
      if (member && index == -1) {
        list.insert(0, post);
        changed = true;
      } else if (!member && index != -1) {
        list.removeAt(index);
        changed = true;
      } else if (member) {
        list[index] = post; // keep counts/state live on the stored copy
      }
    }

    reconcile(_likedPosts, post.isLiked);
    reconcile(_savedPosts, post.isSaved);
    if (changed) _bumpDataVersion();
  }

  /// Every in-memory copy of [postId] across the feed and activity
  /// collections. Each collection stores its OWN PostModel instance, so a
  /// state flip (like/save) must hit all of them — mutating only the feed
  /// copy leaves the Saved/Liked views logically wrong, and a flip resolved
  /// from an activity-only post would not touch the feed copy at all.
  List<PostModel> _copiesOf(String postId) {
    return [
      for (final list in [
        _feedPosts,
        _myPosts,
        _savedPosts,
        _likedPosts,
        _reportedFeedPosts,
      ])
        for (final p in list)
          if (p.id == postId) p,
    ];
  }

  /// Rebuilds [commentedPostIds] and [commentPreviewByPost] from the current
  /// user comments. Called after every mutation of [_userComments].
  void _refreshCommentDerivatives() {
    _commentedPostIds.clear();
    _commentPreviewByPost.clear();
    for (final c in _userComments) {
      _commentedPostIds.add(c.postId);
      _commentPreviewByPost.putIfAbsent(c.postId, () {
        final text = c.content;
        return text.length > 60 ? '${text.substring(0, 60)}…' : text;
      });
    }
  }

  /// Feed posts the current user has commented on (My Activity → Commented).
  List<PostModel> get commentedPosts =>
      _feedPosts.where((p) => _commentedPostIds.contains(p.id)).toList();

  /// Posts the current user has reported (My Activity → Reported).
  /// Authoritative source: the server's reported-feed list
  /// ([_reportedFeedPosts], loaded by [loadMyReports]). A stale
  /// [_userReports] entry without a matching post is filtered out by the
  /// load itself, so no cross-list fallback is needed here.
  List<PostModel> get reportedPosts {
    final reportedIds = _userReports.map((r) => r.postId).toSet();
    return _reportedFeedPosts
        .where((p) => p.isReportedByCurrentUser || reportedIds.contains(p.id))
        .toList();
  }

  /// Feed posts the current user has saved (My Activity → Saved).
  List<PostModel> get savedPosts => List.unmodifiable(_savedPosts);

  List<String> _reportReasons = [];
  List<String> get reportReasons => List.unmodifiable(_reportReasons);

  /// Report-reasons-scoped version, bumped when the reason list is (re)loaded.
  /// Lets the Report sheet subscribe via a cheap `context.select` on an int
  /// instead of watching the whole provider.
  int _reportReasonsVersion = 0;
  int get reportReasonsVersion => _reportReasonsVersion;

  bool _hasEligibleAttractions = false;
  bool get hasEligibleAttractions => _hasEligibleAttractions;

  List<EligibleAttractionModel> _eligibleAttractions = [];
  List<EligibleAttractionModel> get eligibleAttractions =>
      List.unmodifiable(_eligibleAttractions);

  PostModel? getPostById(String postId) {
    for (final list in [_feedPosts, _myPosts]) {
      try {
        return list.firstWhere((p) => p.id == postId);
      } catch (_) {}
    }
    // Fallback: check the single-post cache (populated by fetchPostById).
    if (_singlePost?.id == postId) return _singlePost;
    return null;
  }

  /// Fetches a single post from the API by its ID and caches it in
  /// [_singlePost]. Used by EditPostScreen when the post is not in the
  /// feed or my-posts cache (e.g. opened from a search result or details
  /// screen). Returns the fetched [PostModel] or null on error.
  Future<PostModel?> fetchPostById(String postId) async {
    final client = httpClient;
    if (client == null) return null;
    try {
      final details = await client.getPostDetails(postId);
      _singlePost = PostModel.fromSummary(details);
      _bumpDataVersion();
      notifyListeners();
      return _singlePost;
    } catch (_) {
      return null;
    }
  }

  List<UserCommentItem> getCommentsForPost(String postId) {
    return _postComments[postId] ?? _userComments.where((c) => c.postId == postId).toList();
  }

  // ---------------- Loaders ----------------

  /// Loads the community post feed (frozen two-section contract):
  ///   MY ACTIVITY — [category]=myActivity&[type]=posted|commented|reported
  ///   DISCOVER — [category]=discover&[sort]=newest|popularity|saved,
  ///              with optional [min]/[max] engagement range (likes+comments).
  /// [filter] mirrors the legacy backend `filter` param for compatibility.
  /// [search] routes the SAME engine to the paginated
  /// `GET /api/posts/search` endpoint — search is a FeedQuery value, not a
  /// separate pipeline.
  ///
  /// Always loads page 1 and RESETS pagination state (page counter, hasMore,
  /// pagination error, loading-more flag) — this is both the initial load,
  /// the pull-to-refresh path and the filter-change path. The query is
  /// captured verbatim so [loadNextPage] re-requests it with page+1.
  Future<void> loadFeed({
    String? category,
    String? type,
    String? sort,
    int? min,
    int? max,
    String? filter,
    String? search,
  }) async {
    final client = httpClient;
    if (client == null) return;
    // A non-empty [search] switches the engine to the paginated search
    // endpoint; any other load (bare, filtered or refreshed) leaves search
    // mode — search is only active while its query is the captured one.
    if (search != null && search.isNotEmpty) {
      _feedSearchQuery = search;
    } else {
      _feedSearchQuery = null;
    }
    // Remember the exact query for automatic next-page loads. Search mode
    // uses only the search endpoint, so the other query fields stay null and
    // cannot leak into a search pagination request.
    final useSearch = _feedSearchQuery != null;
    _feedCategory = useSearch ? null : category;
    _feedType = useSearch ? null : type;
    _feedSort = useSearch ? null : sort;
    _feedMin = useSearch ? null : min;
    _feedMax = useSearch ? null : max;
    _feedFilterParam = useSearch ? null : filter;
    _feedPage = 1;
    _feedHasMore = true;
    _paginationError = null;
    _isLoadingMore = false;
    final seq = ++_feedSeq; // invalidates any in-flight loadNextPage
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final posts = useSearch
          ? await client.searchPosts(
              _feedSearchQuery ?? '', page: 1, pageSize: feedPageSize)
          : await client.getPostFeed(
              category: category,
              type: type,
              sort: sort,
              min: min,
              max: max,
              filter: filter,
              page: 1,
              pageSize: feedPageSize,
            );
      if (seq != _feedSeq) return; // stale — a newer load superseded this one
      _feedPosts
        ..clear()
        ..addAll(posts
            .where((s) => !_isRecentlyDeleted(s.postId))
            .map(PostModel.fromSummary));
      // A short (or empty) first page means there is nothing more to load.
      // hasMore reflects the SERVER page size (raw row count), so filtering
      // a tombstoned row out locally never changes the pagination contract.
      _feedHasMore = posts.length >= feedPageSize;
      _bumpDataVersion();
    } catch (e) {
      if (seq != _feedSeq) return;
      _errorMessage = useSearch
          ? _errorText(e, 'Failed to search posts. Please try again.')
          : _errorText(e, 'Failed to load the post feed.');
    } finally {
      if (seq == _feedSeq) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Refresh path for pull-to-refresh / explicit refresh: reloads page 1 of
  /// the CURRENT feed configuration verbatim (search, category, sort,
  /// engagement range all preserved) with the standard full reset. Filters
  /// are never cleared by a refresh.
  Future<void> refreshFeed() {
    return loadFeed(
      category: _feedCategory,
      type: _feedType,
      sort: _feedSort,
      min: _feedMin,
      max: _feedMax,
      filter: _feedFilterParam,
      search: _feedSearchQuery,
    );
  }

  /// Content-aware refresh (Part 4/9 of the refresh-feedback spec): reloads
  /// page 1 of the CURRENT configuration — exactly like [refreshFeed] — but
  /// compares the fresh page-1 payload against what was displayed before the
  /// refresh and reports whether meaningful feed data changed.
  ///
  /// HTTP 200 alone is NOT treated as "data changed": the comparison covers
  /// post id, title, description, author, images, like/save state and
  /// comment count (the fields that shape the visible feed). Volatile fields
  /// that change without content change are not part of the fingerprint.
  ///
  /// Concurrency safety: the previous page-1 fingerprint is captured
  /// synchronously before the request fires; the result is only reported if
  /// this refresh is still the newest feed operation (its [seq] matches
  /// [_feedSeq] when it finishes), so a slow stale refresh can never report a
  /// change over a feed a newer request already replaced. Failure returns
  /// [FeedRefreshOutcome.error] and leaves the previously loaded list fully
  /// intact (loadFeed's stale-guard already discards failed responses).
  ///
  /// Pagination-only refreshes (user scrolled to page 3, pulls to refresh):
  /// page 1 is reset to the fresh page 1 — appended pages 2+ are gone either
  /// way, so the page-1 comparison is the correct "did anything change"
  /// basis.
  Future<FeedRefreshOutcome> refreshFeedWithFeedback() async {
    // 1. Fingerprint of what the user currently sees (page 1 data).
    final before = _feedFingerprint(_feedPosts);

    // 2. Standard reload of the captured configuration (reset, seq bump).
    //    refreshFeed() bumps [_feedSeq] exactly once; capturing the pre-call
    //    value lets us detect any OTHER feed operation that ran while we
    //    were awaiting (user changed filters, searched, logged out…).
    final preSeq = _feedSeq;
    await refreshFeed();

    // 3. Stale check: a newer feed operation superseded this refresh — do
    //    not claim any outcome about data the user no longer sees.
    if (_feedSeq != preSeq + 1) return FeedRefreshOutcome.superseded;

    // 4. Failure path: loadFeed set the error and kept the old list.
    if (_errorMessage != null) return FeedRefreshOutcome.error;

    // 5. Compare the refreshed page-1 content against the previous list.
    //    The refresh intentionally RESETS pagination — a shorter list that is
    //    identical to the old list's first page is NOT a data change (the
    //    user sees the same posts, minus pages they had scrolled into).
    //    listEquals (NOT ==): two lists with identical contents are distinct
    //    instances, so identity comparison would always report "changed".
    final fresh = _feedFingerprint(_feedPosts);
    final beforeComparable =
        before.length > fresh.length ? before.sublist(0, fresh.length) : before;
    return listEquals(fresh, beforeComparable)
        ? FeedRefreshOutcome.unchanged
        : FeedRefreshOutcome.changed;
  }

  /// Stable fingerprint of the visible feed data (page 1) for refresh
  /// comparison. Covers the fields that affect what the user sees: id,
  /// title, description, author info, images, reaction state/count, comment
  /// count, save state. createdAt is intentionally included (it is part of
  /// the card content) but volatile bookkeeping fields are not.
  static List<String> _feedFingerprint(List<PostModel> posts) {
    return [
      for (final p in posts)
        [
          p.id,
          p.title,
          p.description,
          p.authorId,
          p.authorName,
          p.location,
          p.galleryImages.join('|'),
          p.likes.toString(),
          p.isLiked.toString(),
          p.commentsCount.toString(),
          p.isSaved.toString(),
          p.isReportedByCurrentUser.toString(),
          p.createdAt.toIso8601String(),
        ].join('\u0001'),
    ];
  }

  /// Automatic scroll-based next-page load (appends; never replaces page 1).
  ///
  /// Guard order matters: skip entirely when already loading, when the feed
  /// ended, or when an unresolved pagination error is showing — the last one
  /// stops auto-retry loops until the user taps Retry. On failure the feed
  /// list is untouched and [paginationError] is set.
  ///
  /// Minimum-indicator rule: the API request fires immediately (never
  /// delayed), but the loading footer is kept visible for at least
  /// [_paginationMinIndicatorVisible] (500 ms) so fast responses do not
  /// flicker. The wait happens AFTER the response arrives — append and error
  /// handling run first, only the isLoadingMore=false transition is deferred.
  /// A feed reset (seq mismatch) skips the wait entirely.
  Future<void> loadNextPage() async {
    final client = httpClient;
    if (client == null) return;
    if (_isLoadingMore) return; // one request at a time
    if (!_feedHasMore) return; // end of feed
    if (_paginationError != null) return; // wait for explicit Retry
    if (_isLoading) return; // initial load / refresh in progress
    final indicatorStart = DateTime.now(); // min-visibility clock starts here
    _isLoadingMore = true;
    _paginationError = null;
    notifyListeners();
    final seq = _feedSeq; // loadFeed() bumps this to invalidate us
    final nextPage = _feedPage + 1;
    try {
      // SAME configuration as page 1 — only the page number changes. Search
      // mode re-requests the captured query on the search endpoint; every
      // other mode re-requests the captured feed query verbatim, so filter
      // parameters can never be lost between pages.
      final posts = _feedSearchQuery != null
          ? await client.searchPosts(_feedSearchQuery!,
              page: nextPage, pageSize: feedPageSize)
          : await client.getPostFeed(
              category: _feedCategory,
              type: _feedType,
              sort: _feedSort,
              min: _feedMin,
              max: _feedMax,
              filter: _feedFilterParam,
              page: nextPage,
              pageSize: feedPageSize,
            );
      if (seq != _feedSeq) return; // feed was reset while we were loading
      _feedPosts.addAll(posts
          .where((s) => !_isRecentlyDeleted(s.postId))
          .map(PostModel.fromSummary));
      _feedPage = nextPage;
      // Fewer rows than requested ⇒ last page reached (page 4 = 2 rows).
      // Raw server row count — tombstone filtering must not alter it.
      _feedHasMore = posts.length >= feedPageSize;
      _bumpDataVersion();
    } catch (e) {
      if (seq != _feedSeq) return;
      _paginationError =
          _errorText(e, 'Could not load more posts. Please try again.');
    } finally {
      if (seq == _feedSeq) {
        // Keep the indicator up for the remainder of the 500 ms window when
        // the request finished faster. Applies on success AND error so the
        // footer never flashes before the error card replaces it.
        final elapsed = DateTime.now().difference(indicatorStart);
        final remaining = _paginationMinIndicatorVisible - elapsed;
        if (remaining > Duration.zero) {
          await Future<void>.delayed(remaining);
        }
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Explicit Retry from the pagination error footer. Re-requests the SAME
  /// failed page (page counter was never advanced on failure), then clears
  /// the error so automatic loading can resume.
  Future<void> retryLoadNextPage() async {
    _paginationError = null;
    notifyListeners();
    await loadNextPage();
  }

  /// Loads a single post's details and caches its comments.
  Future<PostDetailsModel?> loadPostDetails(String postId) async {
    final client = httpClient;
    if (client == null) return null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final details = await client.getPostDetails(postId);
      _upsertPost(PostModel.fromSummary(details));
      _postComments[postId] = details.comments.map(UserCommentItem.fromApi).toList();
      _bumpDataVersion();
      return details;
    } catch (e) {
      _errorMessage = _errorText(e, 'Failed to load the post.');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads My Activity data: my posts, my comments, and reported posts.
  /// Runs the four sub-loads in parallel but notifies listeners only once
  /// (was previously 5 notifications per refresh) to avoid rebuild storms.
  ///
  /// Race protection: each call captures a fresh [_activitySeq]. Sub-loads
  /// apply their results only if the captured seq is still current, so a
  /// slower request from an earlier filter switch can never overwrite the
  /// results of a newer one.
  Future<void> loadMyActivity() async {
    final seq = ++_activitySeq;
    _isActivityLoading = true;
    _activityErrorMessage = null;
    _errorMessage = null;
    notifyListeners();
    await Future.wait([
      loadMyPosts(notify: false, seq: seq),
      loadMyComments(notify: false, seq: seq),
      loadMyReports(notify: false, seq: seq),
      loadMySaved(notify: false, seq: seq),
      loadMyLiked(notify: false, seq: seq),
    ]);
    if (seq != _activitySeq) return; // a newer load superseded this one
    _isActivityLoading = false;
    notifyListeners();
  }

  Future<void> loadMySaved({bool notify = true, int? seq}) async {
    final client = httpClient;
    if (client == null) return;
    try {
      final posts = await client.getSavedPosts();
      if (seq != null && seq != _activitySeq) return; // stale
      _savedPosts
        ..clear()
        ..addAll(posts.map(PostModel.fromSummary));
    } catch (e) {
      if (seq != null && seq != _activitySeq) return; // stale
      _activityErrorMessage = _errorText(e, 'Failed to load your activity. Pull to refresh or tap Retry.');
    }
    _bumpDataVersion();
    if (notify) notifyListeners();
  }

  /// Posts the current user has an ACTIVE like on (My Activity → Liked).
  Future<void> loadMyLiked({bool notify = true, int? seq}) async {
    final client = httpClient;
    if (client == null) return;
    try {
      final posts = await client.getMyLikedPosts();
      if (seq != null && seq != _activitySeq) return; // stale
      _likedPosts
        ..clear()
        ..addAll(posts.map(PostModel.fromSummary));
    } catch (e) {
      if (seq != null && seq != _activitySeq) return; // stale
      _activityErrorMessage = _errorText(e, 'Failed to load your activity. Pull to refresh or tap Retry.');
    }
    _bumpDataVersion();
    if (notify) notifyListeners();
  }

  Future<void> loadMyPosts({bool notify = true, int? seq}) async {
    final client = httpClient;
    if (client == null) return;
    try {
      final posts = await client.getMyPosts();
      if (seq != null && seq != _activitySeq) return; // stale
      _myPosts
        ..clear()
        ..addAll(posts.map(PostModel.fromSummary));
    } catch (e) {
      if (seq != null && seq != _activitySeq) return; // stale
      _activityErrorMessage = _errorText(e, 'Failed to load your activity. Pull to refresh or tap Retry.');
    }
    _bumpDataVersion();
    if (notify) notifyListeners();
  }

  Future<void> loadMyComments({bool notify = true, int? seq}) async {
    final client = httpClient;
    if (client == null) return;
    try {
      final comments = await client.getMyComments();
      if (seq != null && seq != _activitySeq) return; // stale
      _userComments
        ..clear()
        ..addAll(comments.map(UserCommentItem.fromApi));
      _refreshCommentDerivatives();
    } catch (e) {
      if (seq != null && seq != _activitySeq) return; // stale
      _activityErrorMessage = _errorText(e, 'Failed to load your activity. Pull to refresh or tap Retry.');
    }
    _bumpDataVersion();
    if (notify) notifyListeners();
  }

  Future<void> loadMyReports({bool notify = true, int? seq}) async {
    final client = httpClient;
    if (client == null) return;
    try {
      final reports = await client.getMyReports();
      if (seq != null && seq != _activitySeq) return; // stale
      _userReports
        ..clear()
        ..addAll(reports
            .where((r) => r.status != 'WITHDRAWN')
            .map(UserReportItem.fromApi));
      // The Reported view needs the posts themselves, not just report rows.
      // The discover feed now EXCLUDES reported-by-current-user posts (DB
      // level), so the posts are fetched from the same paginated feed
      // engine with the reported configuration (category=myActivity,
      // type=reported) — the authoritative source of that list.
      final reportedPosts = await client.getPostFeed(
        category: 'myActivity',
        type: 'reported',
        page: 1,
        pageSize: 50,
      );
      if (seq != null && seq != _activitySeq) return; // stale
      _reportedFeedPosts
        ..clear()
        ..addAll(reportedPosts.map(PostModel.fromSummary));
    } catch (e) {
      if (seq != null && seq != _activitySeq) return; // stale
      _activityErrorMessage = _errorText(e, 'Failed to load your activity. Pull to refresh or tap Retry.');
    }
    _bumpDataVersion();
    if (notify) notifyListeners();
  }

  Future<void> loadReportReasons() async {
    final client = httpClient;
    if (client == null) return;
    try {
      _reportReasons = await client.getReportReasons();
      if (_reportReasons.isEmpty) {
        _reportReasons = _fallbackReportReasons;
      }
    } catch (_) {
      // Non-fatal: fall back to the predefined reasons (REQ501_13).
      _reportReasons = _fallbackReportReasons;
    }
    _reportReasonsVersion++;
    notifyListeners();
  }

  static const List<String> _fallbackReportReasons = [
    'Inappropriate or misleading location imagery',
    'Commercial Spam Promotion',
    'Unauthorized Private Property Access',
    'Inaccurate or outdated place details',
    'Other violation',
  ];

  /// Loads the eligible attractions for tagging a post (REQ501_3/_27).
  Future<void> loadEligibleAttractions() async {
    final client = httpClient;
    if (client == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _eligibleAttractions = await client.getEligibleAttractions();
      _hasEligibleAttractions = _eligibleAttractions.isNotEmpty;
    } catch (e) {
      _errorMessage = _errorText(e, 'Failed to load eligible attractions.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------- Mutations ----------------

  /// Uploads a post image via multipart `POST /api/posts/images/upload` and
  /// returns its public URL. Backend errors surface to the caller.
  Future<String> uploadPostImage(File file) async {
    final client = httpClient;
    if (client == null) return '';
    return client.uploadPostImage(file);
  }

  /// In-flight guard for [publishDraft] (create OR update): a rapid double
  /// tap on Create/Save Changes must never issue a second POST/PUT (same
  /// contract as [_isDeleting] for the delete flow). Resets in `finally` on
  /// success AND failure.
  bool _isPublishing = false;
  bool get isPublishing => _isPublishing;

  /// Creates a new post (no [postId]) or updates an existing one.
  /// Returns the created/updated post id on success, or null on failure.
  Future<String?> publishDraft({String? postId}) async {
    final client = httpClient;
    if (client == null) return null;
    // Re-entry guard: the Save/Create handler also ignores taps while
    // [isPublishing] is up, so a same-frame double tap can never send a
    // duplicate write. This provider-side check is the last line of defense.
    if (_isPublishing) return null;
    // Post title is compulsory (business decision H-4) — enforced both in the
    // UI (edit/preview screens) and here as a last line of defense.
    if (_draftTitle.trim().isEmpty) {
      _errorMessage = 'Post title is required.';
      notifyListeners();
      return null;
    }
    if (_draftTitle.trim().length > 100) {
      _errorMessage = 'Post title must not exceed 100 characters.';
      notifyListeners();
      return null;
    }
    _isPublishing = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final images = <PostImageRequest>[
        for (var i = 0; i < _draftPhotos.length; i++)
          PostImageRequest(imageUrl: _draftPhotos[i], displayOrder: i + 1),
      ];

      if (postId != null) {
        final response = await client.updatePost(
          postId,
          UpdatePostRequest(
            title: _draftTitle.isNotEmpty ? _draftTitle : null,
            description: _draftDescription,
            images: images,
          ),
        );
        // The backend re-reads the persisted row after saving, so
        // response.post is the AUTHORITATIVE updated post. Apply it to every
        // cached list by real post id BEFORE the reloads: the feed and Post
        // Details then show the updated title/description/images immediately,
        // with no app restart or manual refresh required.
        var appliedAuthoritative = false;
        final fresh = response.post;
        if (fresh != null) {
          final model = PostModel.fromSummary(fresh);
          _upsertPost(model);
          if (_singlePost?.id == postId) {
            _singlePost = model; // keep the single-post fallback cache fresh
          }
          _bumpDataVersion();
          appliedAuthoritative = true;
        }
        // Authoritative refresh of the wider list caches (existing reload
        // architecture: feed ordering + My Posts). loadFeed/loadMyPosts
        // catch their own transport errors and surface them via
        // _errorMessage instead of throwing, so a flaky reload can never
        // discard a persisted update.
        await loadFeed();
        // L-12: keep My Activity (My Posts tab) in sync after an edit.
        await loadMyPosts();
        if (appliedAuthoritative || _errorMessage == null) {
          return postId;
        }
        // No authoritative body and the reloads failed: the client cannot
        // prove the edit landed — report failure honestly.
        return null;
      } else {
        if (_draftTaggedPlaceId.isEmpty) {
          _errorMessage = 'Please select an attraction to tag.';
          return null;
        }
        final response = await client.createPost(
          CreatePostRequest(
            taggedPlaceId: _draftTaggedPlaceId,
            title: _draftTitle.isNotEmpty ? _draftTitle : null,
            description: _draftDescription,
            images: images,
          ),
        );
        // The post is persisted server-side the moment createPost resolves —
        // consume the draft NOW so a retry can never create a duplicate.
        clearDraft();
        // The create endpoint returns only the postId (CreatePostResponseDto
        // { postId, message }), so obtain the authoritative created post via
        // the EXISTING details endpoint and upsert it into the provider state
        // immediately — the SAME mechanism the edit path uses (one source of
        // truth: PostModel parsed from the same API). The feed then shows the
        // new post with no app restart or manual pull-to-refresh.
        var appliedAuthoritative = false;
        try {
          final details = await client.getPostDetails(response.postId);
          _upsertPost(PostModel.fromSummary(details));
          _bumpDataVersion();
          appliedAuthoritative = true;
        } catch (_) {
          // Details fetch failed: the persisted post is still real, and the
          // authoritative reloads below reconcile the lists.
        }
        // Authoritative refresh of the wider list caches (existing reload
        // architecture, same as the edit path). loadFeed/loadMyPosts catch
        // their own transport errors, so a flaky reload cannot discard the
        // successful creation.
        await loadFeed();
        // _upsertPost inserts into the feed only; the My Posts tab is
        // reconciled from the server so the new post appears there too.
        await loadMyPosts();
        if (appliedAuthoritative || _errorMessage == null) {
          return response.postId;
        }
        // No authoritative fetch and the reloads failed: the client cannot
        // prove the creation landed — report failure honestly.
        return null;
      }
    } catch (e) {
      _errorMessage = _errorText(e, 'Failed to save the post. Please try again.');
      return null;
    } finally {
      _isLoading = false;
      _isPublishing = false;
      notifyListeners();
    }
  }

  Future<bool> deletePost(String postId) async {
    final client = httpClient;
    if (client == null) return false;
    // Re-entry guard (double tap / duplicate confirmation): ONE delete per
    // action. Without it, N rapid taps issue N HTTP DELETEs and each
    // completion runs its own pop + feedback (the reported loop).
    if (_isDeleting) return false;
    _isDeleting = true;
    _isLoading = true;
    notifyListeners();
    try {
      await client.deletePost(postId);
      _feedPosts.removeWhere((p) => p.id == postId);
      _myPosts.removeWhere((p) => p.id == postId);
      _userComments.removeWhere((c) => c.postId == postId);
      _userReports.removeWhere((r) => r.postId == postId);
      _reportedFeedPosts.removeWhere((p) => p.id == postId);
      // Activity collections must drop the deleted post too — otherwise the
      // Saved/Liked filters show a post that no longer exists (stale list).
      _savedPosts.removeWhere((p) => p.id == postId);
      _likedPosts.removeWhere((p) => p.id == postId);
      // Tombstone: a feed/pagination response that raced this delete (was
      // issued before the DELETE completed) still carries the post. Filtering
      // it at ingestion keeps the deleted post from reappearing (§16).
      _recentlyDeletedIds
        ..removeWhere((_, at) =>
            DateTime.now().difference(at) > _deleteTombstoneTtl)
        ..[postId] = DateTime.now();
      _refreshCommentDerivatives();
      _bumpDataVersion();
      return true;
    } catch (e) {
      _errorMessage = _errorText(e, 'Failed to delete the post.');
      return false;
    } finally {
      // Deleting state resets on success AND failure (single transition).
      _isDeleting = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addComment(String postId, String content) async {
    if (content.trim().isEmpty) return false;
    final client = httpClient;
    if (client == null) return false;

    _isCommentSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await client.createComment(postId, content.trim());
      if (response.comment != null) {
        final item = UserCommentItem.fromApi(response.comment!);
        final post = getPostById(postId);
        if (post != null) post.commentsCount++;
        // Only a genuinely NEW comment relationship changes the Commented
        // filter membership, so only then bump _dataVersion (rebuilds the
        // feed list). Appending/editing on an already-commented post must
        // only bump the post revision — that rebuilds the single affected
        // card (PostCard subscribes to its own revision) and the card
        // re-reads commentedPostIds / commentPreview via context.read.
        final isNewlyCommented = !_commentedPostIds.contains(postId);
        _userComments.insert(0, item);
        (_postComments[postId] ??= []).add(item);
        _refreshCommentDerivatives();
        _bumpPostRevision(postId);
        // Keep the activity copies (saved/liked) on the SAME instance so
        // their comment counts stay live too.
        if (post != null) _syncPostMembership(post);
        if (isNewlyCommented) {
          // The post just joined the Commented filter, but `post` may come
          // from _myPosts (author viewing own post) — _feedPosts is the
          // Commented view's source. Seed the feed cache so the Commented
          // view actually shows the post instead of relying on a reload.
          if (post != null && _feedPosts.indexWhere((p) => p.id == postId) == -1) {
            _feedPosts.insert(0, post);
          }
          _bumpDataVersion();
        }
      }
      return true;
    } catch (e) {
      _errorMessage = _errorText(e, 'Failed to add the comment.');
      return false;
    } finally {
      _isCommentSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> editComment(String commentId, String updatedContent) async {
    if (updatedContent.trim().isEmpty) return false;
    final client = httpClient;
    if (client == null) return false;

    try {
      final response = await client.updateComment(commentId, updatedContent.trim());
      if (response.comment != null) {
        final updated = UserCommentItem.fromApi(response.comment!);
        final index = _userComments.indexWhere((c) => c.commentId == commentId);
        if (index != -1) {
          _userComments[index] = updated;
        }
        final perPost = _postComments[updated.postId];
        if (perPost != null) {
          final idx = perPost.indexWhere((c) => c.commentId == commentId);
          if (idx != -1) perPost[idx] = updated;
        }
        _refreshCommentDerivatives();
        _bumpPostRevision(updated.postId);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = _errorText(e, 'Failed to update the comment.');
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> deleteComment(String commentId) async {
    if (_isCommentDeleting) return false; // guard against double-submit
    final client = httpClient;
    if (client == null) return false;

    _isCommentDeleting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await client.deleteComment(commentId);
      final index = _userComments.indexWhere((c) => c.commentId == commentId);
      if (index != -1) {
        final postId = _userComments[index].postId;
        final post = getPostById(postId);
        if (post != null && post.commentsCount > 0) post.commentsCount--;
        _userComments.removeAt(index);
        _postComments[postId]?.removeWhere((c) => c.commentId == commentId);
        _refreshCommentDerivatives();
        _bumpPostRevision(postId);
        // Keep the activity copies (saved/liked) on the SAME instance so
        // their comment counts stay live too.
        if (post != null) _syncPostMembership(post);
        // Removing the user's LAST comment on a post drops it out of the
        // Commented filter — rebuild the visible list in the same frame so
        // the Commented view never keeps a post the user no longer qualifies.
        if (!_commentedPostIds.contains(postId)) _bumpDataVersion();
      }
      return true;
    } catch (e) {
      _errorMessage = _errorText(e, 'Failed to delete the comment.');
      return false;
    } finally {
      _isCommentDeleting = false;
      notifyListeners();
    }
  }

  Future<bool> togglePostLike(String postId) async {
    final client = httpClient;
    if (client == null) return false;
    if (_likesInFlight.contains(postId)) return false; // guard against double-tap
    // Resolve EVERY copy: the tap can come from the discover feed, My Posts,
    // or a Liked/Saved activity card — each renders its own PostModel.
    final copies = _copiesOf(postId);
    if (copies.isEmpty) return false;

    _likesInFlight.add(postId);
    // Notify immediately so the single affected card (which subscribes to its
    // own revision) can show the in-flight spinner without rebuilding the feed.
    _bumpPostRevision(postId);
    notifyListeners();

    try {
      final response = await client.toggleReaction(postId);
      for (final p in copies) {
        p.isLiked = response.isReacted;
        p.likes = response.reactionCount;
      }
      // Liked-filter membership must follow the like state IMMEDIATELY —
      // without this sync the Liked view kept a post the user just unliked
      // (and hid one they just liked) until a manual pull-to-refresh.
      _syncPostMembership(copies.first);
      _bumpPostRevision(postId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _errorText(e, 'Failed to update the reaction.');
      _bumpPostRevision(postId);
      notifyListeners();
      return false;
    } finally {
      _likesInFlight.remove(postId);
    }
  }

  /// Submits a report for a post; on success reloads the user's reports.
  /// Returns the created report id, or null on failure. On failure the
  /// backend's business message (e.g. 409 "You have already reported this
  /// post.") is preserved in [errorMessage] for the caller to surface.
  Future<String?> submitReport(String postId, String reason) async {
    final client = httpClient;
    if (client == null) return null;
    try {
      final reportId = await client.reportPost(postId, reason);
      // Immediate UI effect: the server accepted the report, so mark every
      // in-memory copy of the post as reported and bump its per-post
      // revision. The card (subscribed to its own revision) rebuilds in the
      // same frame and hides all interaction affordances (Like, Comment,
      // Bookmark, Save, commented-preview) — reported posts render only the
      // Reported markers.
      for (final list in [
        _feedPosts,
        _myPosts,
        _savedPosts,
        _likedPosts,
        _reportedFeedPosts,
      ]) {
        for (final post in list) {
          if (post.id == postId) {
            post.isReportedByCurrentUser = true;
          }
        }
      }
      _bumpPostRevision(postId);
      await loadMyReports();
      return reportId;
    } catch (e) {
      _errorMessage = _errorText(e, 'Failed to submit the report. Please try again.');
      return null;
    }
  }

  /// Saves or unsaves a post for the authenticated user. Updates the
  /// in-memory [PostModel.isSaved] state so the More menu label flips
  /// between Save and Unsave immediately. Returns true on success.
  Future<bool> toggleSavePost(String postId) async {
    final client = httpClient;
    if (client == null) return false;
    if (_savesInFlight.contains(postId)) return false; // guard against double-tap
    // Resolve EVERY copy: the tap can come from the discover feed, My Posts,
    // or a Saved/Liked activity card — each renders its own PostModel. The
    // old getPostById() lookup missed activity-only posts entirely, so
    // saving/unsaving from a Saved/Liked card silently FAILED.
    final copies = _copiesOf(postId);
    if (copies.isEmpty) return false;
    final post = copies.first;

    _savesInFlight.add(postId);
    // Notify immediately so the single affected card (which subscribes to its
    // own revision) can show the in-flight save spinner without rebuilding
    // the feed.
    _bumpPostRevision(postId);
    notifyListeners();

    try {
      if (post.isSaved) {
        await client.unsavePost(postId);
      } else {
        await client.savePost(postId);
      }
      for (final p in copies) {
        p.isSaved = !post.isSaved; // server accepted the opposite state
      }
      _savesInFlight.remove(postId);
      // Saved-filter membership must follow the save state IMMEDIATELY —
      // without this sync the Saved view kept a post the user just unsaved
      // until a manual pull-to-refresh (the reported Saved-filter bug).
      _syncPostMembership(post);
      _bumpPostRevision(postId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _errorText(e, 'Failed to update the saved state.');
      _savesInFlight.remove(postId);
      _bumpPostRevision(postId);
      notifyListeners();
      return false;
    } finally {
      // Safety net: ensure the id is always removed from the in-flight set.
      _savesInFlight.remove(postId);
    }
  }

  void _upsertPost(PostModel post) {
    final index = _feedPosts.indexWhere((p) => p.id == post.id);
    if (index != -1) {
      _feedPosts[index] = post;
    } else {
      _feedPosts.insert(0, post);
    }
    final myIndex = _myPosts.indexWhere((p) => p.id == post.id);
    if (myIndex != -1) {
      _myPosts[myIndex] = post;
    }
    _bumpPostRevision(post.id);
  }

  /// Drops everything cached for the signed-in user (feed, my posts, comments,
  /// reports, drafts and search) so the provider starts clean for the next
  /// session.
  @override
  void clearSessionData() {
    _feedPosts.clear();
    // Pagination state must reset too: a logout during an in-flight
    // next-page request otherwise leaks isLoadingMore/_feedPage/pagination
    // error into the next session and blocks it (or appends the previous
    // user's page into the new session's feed). Bumping _feedSeq invalidates
    // any in-flight loadNextPage exactly like a filter change does.
    _feedCategory = null;
    _feedType = null;
    _feedSort = null;
    _feedMin = null;
    _feedMax = null;
    _feedFilterParam = null;
    _feedSearchQuery = null;
    _lastSearchQuery = '';
    _feedPage = 1;
    _feedHasMore = true;
    _isLoadingMore = false;
    _paginationError = null;
    _feedSeq++;
    _myPosts.clear();
    _userComments.clear();
    _userReports.clear();
    _reportedFeedPosts.clear();
    _savedPosts.clear();
    _likedPosts.clear();
    _postComments.clear();
    _likesInFlight.clear();
    _savesInFlight.clear();
    _eligibleAttractions = [];
    _hasEligibleAttractions = false;
    _errorMessage = null;
    _activityErrorMessage = null;
    _isLoading = false;
    _isActivityLoading = false;
    clearDraft();
    notifyListeners();
  }
}
