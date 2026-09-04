import 'dart:io';

import 'package:flutter/material.dart';
import '../../api_communication/http_client/http_client.dart';
import '../../models/post_review/post_model.dart';
import '../session_scoped_provider.dart';

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
  final bool isReportedByCurrentUser;
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

  // ---------------- Search state ----------------
  bool _isSearching = false;
  bool get isSearching => _isSearching;

  String? _searchError;
  String? get searchError => _searchError;

  final List<PostModel> _searchResults = [];
  List<PostModel> get searchResults => List.unmodifiable(_searchResults);

  String _lastSearchQuery = '';
  String get lastSearchQuery => _lastSearchQuery;

  /// Monotonic search sequence. Guards against a slow earlier query's results
  /// overwriting a newer query (stale-response protection).
  int _searchSeq = 0;

  /// Monotonic My Activity sequence. Guards against stale sub-load results
  /// from a prior filter switch overwriting a newer load (stale-response
  /// protection). Mirrors _searchSeq.
  int _activitySeq = 0;

  /// Search-scoped version. Bumped on every search-state change (start,
  /// results, error, clear). Lets the Search screens subscribe with a cheap
  /// `context.select` on an int instead of watching the whole provider.
  int _searchVersion = 0;
  int get searchVersion => _searchVersion;

  /// Searches active community posts via `GET /api/posts/search?q=`.
  /// Populates [searchResults]; sets [searchError] on failure.
  Future<void> searchPosts(String query) async {
    final trimmed = query.trim();
    _lastSearchQuery = trimmed;
    if (trimmed.isEmpty) {
      _searchSeq++; // invalidate any in-flight search
      _searchResults.clear();
      _searchError = null;
      _isSearching = false;
      _searchVersion++;
      _bumpDataVersion();
      notifyListeners();
      return;
    }
    final client = httpClient;
    if (client == null) return;
    final seq = ++_searchSeq;
    _isSearching = true;
    _searchError = null;
    _searchVersion++;
    notifyListeners();
    try {
      final results = await client.searchPosts(trimmed, pageSize: 50);
      if (seq != _searchSeq) return; // stale — a newer query superseded this one
      _searchResults
        ..clear()
        ..addAll(results.map(PostModel.fromSummary));
      _searchVersion++;
      _bumpDataVersion();
    } catch (_) {
      if (seq != _searchSeq) return;
      _searchError = 'Failed to search posts. Please try again.';
      _searchVersion++;
    } finally {
      if (seq == _searchSeq) {
        _isSearching = false;
        _searchVersion++;
        notifyListeners();
      }
    }
  }

  void clearSearch() {
    _searchSeq++; // invalidate any in-flight search
    _searchResults.clear();
    _searchError = null;
    _isSearching = false;
    _lastSearchQuery = '';
    _searchVersion++;
    _bumpDataVersion();
    notifyListeners();
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

  /// Feed posts the current user has reported (My Activity → Reported).
  List<PostModel> get reportedPosts {
    final reportedIds = _userReports.map((r) => r.postId).toSet();
    return _feedPosts
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
  Future<void> loadFeed({
    String? category,
    String? type,
    String? sort,
    int? min,
    int? max,
    String? filter,
  }) async {
    final client = httpClient;
    if (client == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final posts = await client.getPostFeed(
        category: category,
        type: type,
        sort: sort,
        min: min,
        max: max,
        filter: filter,
        pageSize: 50,
      );
      _feedPosts
        ..clear()
        ..addAll(posts.map(PostModel.fromSummary));
      _bumpDataVersion();
    } catch (e) {
      _errorMessage = 'Failed to load the post feed.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      _errorMessage = 'Failed to load the post.';
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
    } catch (_) {
      if (seq != null && seq != _activitySeq) return; // stale
      _activityErrorMessage = 'Failed to load your activity. Pull to refresh or tap Retry.';
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
    } catch (_) {
      if (seq != null && seq != _activitySeq) return; // stale
      _activityErrorMessage = 'Failed to load your activity. Pull to refresh or tap Retry.';
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
    } catch (_) {
      if (seq != null && seq != _activitySeq) return; // stale
      _activityErrorMessage = 'Failed to load your activity. Pull to refresh or tap Retry.';
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
    } catch (_) {
      if (seq != null && seq != _activitySeq) return; // stale
      _activityErrorMessage = 'Failed to load your activity. Pull to refresh or tap Retry.';
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
    } catch (_) {
      if (seq != null && seq != _activitySeq) return; // stale
      _activityErrorMessage = 'Failed to load your activity. Pull to refresh or tap Retry.';
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
      _errorMessage = 'Failed to load eligible attractions.';
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

  /// Creates a new post (no [postId]) or updates an existing one.
  /// Returns the created/updated post id on success, or null on failure.
  Future<String?> publishDraft({String? postId}) async {
    final client = httpClient;
    if (client == null) return null;
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final images = <PostImageRequest>[
        for (var i = 0; i < _draftPhotos.length; i++)
          PostImageRequest(imageUrl: _draftPhotos[i], displayOrder: i + 1),
      ];

      if (postId != null) {
        await client.updatePost(
          postId,
          UpdatePostRequest(
            title: _draftTitle.isNotEmpty ? _draftTitle : null,
            description: _draftDescription,
            images: images,
          ),
        );
        await loadFeed();
        // L-12: keep My Activity (My Posts tab) in sync after an edit.
        await loadMyPosts();
        return postId;
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
        clearDraft();
        await loadFeed();
        return response.postId;
      }
    } catch (e) {
      _errorMessage = 'Failed to save the post. Please try again.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deletePost(String postId) async {
    final client = httpClient;
    if (client == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      await client.deletePost(postId);
      _feedPosts.removeWhere((p) => p.id == postId);
      _myPosts.removeWhere((p) => p.id == postId);
      _userComments.removeWhere((c) => c.postId == postId);
      _userReports.removeWhere((r) => r.postId == postId);
      _refreshCommentDerivatives();
      _bumpDataVersion();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to delete the post.';
      return false;
    } finally {
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
        if (isNewlyCommented) _bumpDataVersion();
      }
      return true;
    } catch (_) {
      _errorMessage = 'Failed to add the comment.';
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
    } catch (_) {
      _errorMessage = 'Failed to update the comment.';
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
      }
      return true;
    } catch (_) {
      _errorMessage = 'Failed to delete the comment.';
      return false;
    } finally {
      _isCommentDeleting = false;
      notifyListeners();
    }
  }

  Future<bool> togglePostLike(String postId) async {
    final client = httpClient;
    final post = getPostById(postId);
    if (post == null) return false;
    if (client == null) return false;
    if (_likesInFlight.contains(postId)) return false; // guard against double-tap

    _likesInFlight.add(postId);
    // Notify immediately so the single affected card (which subscribes to its
    // own revision) can show the in-flight spinner without rebuilding the feed.
    _bumpPostRevision(postId);
    notifyListeners();

    try {
      final response = await client.toggleReaction(postId);
      post.isLiked = response.isReacted;
      post.likes = response.reactionCount;
      _bumpPostRevision(postId);
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to update the reaction.';
      _bumpPostRevision(postId);
      notifyListeners();
      return false;
    } finally {
      _likesInFlight.remove(postId);
    }
  }

  /// Submits a report for a post; on success reloads the user's reports.
  /// Returns the created report id, or null on failure.
  Future<String?> submitReport(String postId, String reason) async {
    final client = httpClient;
    if (client == null) return null;
    try {
      final reportId = await client.reportPost(postId, reason);
      await loadMyReports();
      return reportId;
    } catch (_) {
      return null;
    }
  }

  /// Saves or unsaves a post for the authenticated user. Updates the
  /// in-memory [PostModel.isSaved] state so the More menu label flips
  /// between Save and Unsave immediately. Returns true on success.
  Future<bool> toggleSavePost(String postId) async {
    final client = httpClient;
    final post = getPostById(postId);
    if (post == null) return false;
    if (client == null) return false;
    if (_savesInFlight.contains(postId)) return false; // guard against double-tap

    _savesInFlight.add(postId);
    // Notify immediately so the single affected card (which subscribes to its
    // own revision) can show the in-flight save spinner without rebuilding
    // the feed.
    _bumpPostRevision(postId);
    notifyListeners();

    try {
      if (post.isSaved) {
        await client.unsavePost(postId);
        post.isSaved = false;
      } else {
        await client.savePost(postId);
        post.isSaved = true;
      }
      _savesInFlight.remove(postId);
      _bumpPostRevision(postId);
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to update the saved state.';
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
    _myPosts.clear();
    _userComments.clear();
    _userReports.clear();
    _savedPosts.clear();
    _likedPosts.clear();
    _postComments.clear();
    _searchResults.clear();
    _likesInFlight.clear();
    _savesInFlight.clear();
    _eligibleAttractions = [];
    _hasEligibleAttractions = false;
    _searchError = null;
    _lastSearchQuery = '';
    _isSearching = false;
    _errorMessage = null;
    _activityErrorMessage = null;
    _isLoading = false;
    _isActivityLoading = false;
    clearDraft();
    notifyListeners();
  }
}
