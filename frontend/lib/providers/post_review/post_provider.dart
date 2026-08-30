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

class PostProvider with ChangeNotifier implements SessionScopedProvider {
  final HttpClient? httpClient;

  /// Phase 1 (frontend-only) demo mode: when true, every loader and mutation
  /// operates on seeded in-memory data instead of calling the backend, so the
  /// complete Post Feed / My Activity / Discover UX can be demonstrated before
  /// the API exists. Phase 2 will construct the provider with `demoMode: false`
  /// once the real endpoints are wired up.
  final bool demoMode;

  PostProvider({this.httpClient, this.demoMode = false}) {
    _seedFallback();
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

  /// Searches active community posts. In real mode this calls the API
  /// `GET /api/posts/search?q=`; in demo mode it searches the seeded
  /// in-memory feed so the search UX works without a backend session.
  /// Populates [searchResults]; sets [searchError] on failure.
  Future<void> searchPosts(String query) async {
    final trimmed = query.trim();
    _lastSearchQuery = trimmed;
    if (trimmed.isEmpty) {
      _searchResults.clear();
      _searchError = null;
      _isSearching = false;
      notifyListeners();
      return;
    }
    if (demoMode) {
      _isSearching = true;
      _searchError = null;
      notifyListeners();
      final needle = trimmed.toLowerCase();
      final results = _feedPosts.where((p) {
        return p.title.toLowerCase().contains(needle) ||
            p.description.toLowerCase().contains(needle) ||
            p.location.toLowerCase().contains(needle) ||
            p.authorName.toLowerCase().contains(needle);
      }).toList();
      _searchResults
        ..clear()
        ..addAll(results);
      _isSearching = false;
      notifyListeners();
      return;
    }
    final client = httpClient;
    if (client == null) return;
    _isSearching = true;
    _searchError = null;
    notifyListeners();
    try {
      final results = await client.searchPosts(trimmed, pageSize: 50);
      _searchResults
        ..clear()
        ..addAll(results.map(PostModel.fromSummary));
    } catch (_) {
      _searchError = 'Failed to search posts. Please try again.';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults.clear();
    _searchError = null;
    _isSearching = false;
    _lastSearchQuery = '';
    notifyListeners();
  }

  // ---------------- Draft (create / edit) ----------------
  String _draftTitle = '';
  String _draftDescription = '';
  String _draftLocation = '';
  String _draftTaggedPlaceId = '';
  List<String> _draftPhotos = [];

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
    notifyListeners();
  }

  void clearDraft() {
    _draftTitle = '';
    _draftDescription = '';
    _draftLocation = '';
    _draftTaggedPlaceId = '';
    _draftPhotos = [];
    notifyListeners();
  }

  // ---------------- Data ----------------
  final List<PostModel> _feedPosts = [];
  final List<PostModel> _myPosts = [];
  final List<UserCommentItem> _userComments = [];
  final List<UserReportItem> _userReports = [];
  final Map<String, List<UserCommentItem>> _postComments = {};

  List<PostModel> get feedPosts => List.unmodifiable(_feedPosts);
  List<PostModel> get userPosts => List.unmodifiable(_myPosts);
  List<UserCommentItem> get userComments => List.unmodifiable(_userComments);
  List<UserReportItem> get userReports => List.unmodifiable(_userReports);

  /// Post ids the current user has commented on (drives the "Commented"
  /// card label and the My Activity → Commented filter).
  Set<String> get commentedPostIds =>
      _userComments.map((c) => c.postId).toSet();

  /// Feed posts the current user has commented on (My Activity → Commented).
  List<PostModel> get commentedPosts =>
      _feedPosts.where((p) => commentedPostIds.contains(p.id)).toList();

  /// Feed posts the current user has reported (My Activity → Reported).
  List<PostModel> get reportedPosts {
    final reportedIds = _userReports.map((r) => r.postId).toSet();
    return _feedPosts
        .where((p) => p.isReportedByCurrentUser || reportedIds.contains(p.id))
        .toList();
  }

  /// Feed posts the current user has saved (Discover → Saved).
  List<PostModel> get savedPosts => _feedPosts.where((p) => p.isSaved).toList();

  List<String> _reportReasons = [];
  List<String> get reportReasons => List.unmodifiable(_reportReasons);

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
    return null;
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
    if (demoMode) {
      _isLoading = false;
      _errorMessage = null;
      // Demo data is pre-seeded; sort in place so Discover filters behave.
      final sortMode = sort ?? (filter == 'popular' ? 'popularity' : null);
      if (sortMode == 'popularity') {
        _feedPosts.sort(
          (a, b) => (b.likes + b.commentsCount).compareTo(a.likes + a.commentsCount),
        );
      } else {
        _feedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      notifyListeners();
      return;
    }
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
    if (demoMode) {
      _isLoading = false;
      _errorMessage = null;
      // Post and comments are pre-seeded; make sure a comment thread exists
      // for this post (own comments show up via getCommentsForPost).
      if (!_postComments.containsKey(postId)) {
        final mine = _userComments.where((c) => c.postId == postId).toList();
        if (mine.isNotEmpty) _postComments[postId] = mine;
      }
      notifyListeners();
      return null;
    }
    if (client == null) return null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final details = await client.getPostDetails(postId);
      _upsertPost(PostModel.fromSummary(details));
      _postComments[postId] = details.comments.map(UserCommentItem.fromApi).toList();
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
  Future<void> loadMyActivity() async {
    _isActivityLoading = true;
    _activityErrorMessage = null;
    _errorMessage = null;
    notifyListeners();
    await Future.wait([loadMyPosts(), loadMyComments(), loadMyReports()]);
    _isActivityLoading = false;
    notifyListeners();
  }

  Future<void> loadMyPosts() async {
    final client = httpClient;
    if (demoMode) {
      _activityErrorMessage = null;
      notifyListeners();
      return;
    }
    if (client == null) return;
    try {
      final posts = await client.getMyPosts();
      _myPosts
        ..clear()
        ..addAll(posts.map(PostModel.fromSummary));
    } catch (_) {
      _activityErrorMessage = 'Failed to load your activity. Pull to refresh or tap Retry.';
    }
    notifyListeners();
  }

  Future<void> loadMyComments() async {
    final client = httpClient;
    if (demoMode) {
      _activityErrorMessage = null;
      notifyListeners();
      return;
    }
    if (client == null) return;
    try {
      final comments = await client.getMyComments();
      _userComments
        ..clear()
        ..addAll(comments.map(UserCommentItem.fromApi));
    } catch (_) {
      _activityErrorMessage = 'Failed to load your activity. Pull to refresh or tap Retry.';
    }
    notifyListeners();
  }

  Future<void> loadMyReports() async {
    final client = httpClient;
    if (demoMode) {
      _activityErrorMessage = null;
      notifyListeners();
      return;
    }
    if (client == null) return;
    try {
      final reports = await client.getMyReports();
      _userReports
        ..clear()
        ..addAll(reports.map(UserReportItem.fromApi));
    } catch (_) {
      _activityErrorMessage = 'Failed to load your activity. Pull to refresh or tap Retry.';
    }
    notifyListeners();
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
    if (demoMode) {
      _isLoading = false;
      _errorMessage = null;
      _hasEligibleAttractions = _eligibleAttractions.isNotEmpty;
      notifyListeners();
      return;
    }
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

  /// Uploads a post image and returns its public URL.
  ///
  /// Real mode: multipart upload to `POST /api/posts/images/upload`; the
  /// backend validates the file type/size, stores it in Supabase Storage and
  /// returns the public image URL. Backend errors surface to the caller.
  ///
  /// Demo mode: there is no backend session in the demo, so a stable
  /// placeholder URL is returned instead (same image source the seeded demo
  /// posts use) so the full pick → upload → preview → create → display flow
  /// can be demonstrated without a live storage service.
  Future<String> uploadPostImage(File file) async {
    if (demoMode) {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      return 'https://picsum.photos/seed/post$stamp/800/500';
    }
    final client = httpClient;
    if (client == null) return '';
    return client.uploadPostImage(file);
  }

  /// Creates a new post (no [postId]) or updates an existing one.
  /// Returns the created/updated post id on success, or null on failure.
  Future<String?> publishDraft({String? postId}) async {
    if (demoMode) {
      // Same validation as the API path: title compulsory, ≤ 100 chars.
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
      if (postId != null) {
        // Edit flow: rebuild the post from the draft and upsert it.
        final existing = getPostById(postId);
        final updated = PostModel(
          id: postId,
          authorId: existing?.authorId ?? _mockCurrentUserId,
          authorName: existing?.authorName ?? _mockCurrentUserName,
          authorAvatar: existing?.authorAvatar ?? '',
          location: existing?.location ?? _draftLocation,
          title: _draftTitle,
          description: _draftDescription,
          imageUrl: _draftPhotos.isNotEmpty
              ? _draftPhotos.first
              : (existing?.imageUrl ?? ''),
          galleryImages: _draftPhotos.isNotEmpty
              ? _draftPhotos
              : (existing?.galleryImages ?? const []),
          likes: existing?.likes ?? 0,
          commentsCount: existing?.commentsCount ?? 0,
          isLiked: existing?.isLiked ?? false,
          isReportedByCurrentUser: existing?.isReportedByCurrentUser ?? false,
          isSaved: existing?.isSaved ?? false,
          createdAt: existing?.createdAt ?? DateTime.now(),
        );
        _upsertPost(updated);
        notifyListeners();
        return postId;
      }
      if (_draftTaggedPlaceId.isEmpty) {
        _errorMessage = 'Please select an attraction to tag.';
        notifyListeners();
        return null;
      }
      final newId = 'post-${DateTime.now().millisecondsSinceEpoch}';
      final newPost = PostModel(
        id: newId,
        authorId: _mockCurrentUserId,
        authorName: _mockCurrentUserName,
        authorAvatar: '',
        location: _draftLocation,
        title: _draftTitle,
        description: _draftDescription,
        imageUrl: _draftPhotos.isNotEmpty ? _draftPhotos.first : '',
        galleryImages: _draftPhotos,
        createdAt: DateTime.now(),
      );
      _feedPosts.insert(0, newPost);
      _myPosts.insert(0, newPost);
      clearDraft();
      notifyListeners();
      return newId;
    }
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
    if (demoMode) {
      _feedPosts.removeWhere((p) => p.id == postId);
      _myPosts.removeWhere((p) => p.id == postId);
      _userComments.removeWhere((c) => c.postId == postId);
      _userReports.removeWhere((r) => r.postId == postId);
      _postComments.remove(postId);
      notifyListeners();
      return true;
    }
    if (client == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      await client.deletePost(postId);
      _feedPosts.removeWhere((p) => p.id == postId);
      _myPosts.removeWhere((p) => p.id == postId);
      _userComments.removeWhere((c) => c.postId == postId);
      _userReports.removeWhere((r) => r.postId == postId);
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
    if (demoMode) {
      _isCommentSubmitting = true;
      _errorMessage = null;
      notifyListeners();
      final post = getPostById(postId);
      final item = UserCommentItem(
        commentId: 'comment-${DateTime.now().millisecondsSinceEpoch}',
        postId: postId,
        postTitle: post?.title ?? '',
        content: content.trim(),
        authorId: _mockCurrentUserIdInt,
        authorName: _mockCurrentUserName,
        createdAt: DateTime.now(),
      );
      if (post != null) post.commentsCount++;
      _userComments.insert(0, item);
      (_postComments[postId] ??= []).add(item);
      _isCommentSubmitting = false;
      notifyListeners();
      return true;
    }
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
        _userComments.insert(0, item);
        (_postComments[postId] ??= []).add(item);
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
    if (demoMode) {
      final index = _userComments.indexWhere((c) => c.commentId == commentId);
      if (index == -1) return false;
      _userComments[index].content = updatedContent.trim();
      final postId = _userComments[index].postId;
      final perPost = _postComments[postId];
      if (perPost != null) {
        final idx = perPost.indexWhere((c) => c.commentId == commentId);
        if (idx != -1) perPost[idx].content = updatedContent.trim();
      }
      notifyListeners();
      return true;
    }
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
    if (demoMode) {
      _isCommentDeleting = true;
      _errorMessage = null;
      notifyListeners();
      final index = _userComments.indexWhere((c) => c.commentId == commentId);
      if (index != -1) {
        final postId = _userComments[index].postId;
        final post = getPostById(postId);
        if (post != null && post.commentsCount > 0) post.commentsCount--;
        _userComments.removeAt(index);
        _postComments[postId]?.removeWhere((c) => c.commentId == commentId);
      }
      _isCommentDeleting = false;
      notifyListeners();
      return true;
    }
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
    if (demoMode) {
      if (_likesInFlight.contains(postId)) return false; // guard against double-tap
      _likesInFlight.add(postId);
      post.isLiked = !post.isLiked;
      post.likes += post.isLiked ? 1 : -1;
      if (post.likes < 0) post.likes = 0;
      _likesInFlight.remove(postId);
      notifyListeners();
      return true;
    }
    if (client == null) return false;
    if (_likesInFlight.contains(postId)) return false; // guard against double-tap

    _likesInFlight.add(postId);

    try {
      final response = await client.toggleReaction(postId);
      post.isLiked = response.isReacted;
      post.likes = response.reactionCount;
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to update the reaction.';
      notifyListeners();
      return false;
    } finally {
      _likesInFlight.remove(postId);
    }
  }

  /// Submits a report for a post; on success reloads the user's reports.
  /// Returns the created report id, or null on failure.
  Future<String?> submitReport(String postId, String reason) async {
    if (demoMode) {
      final reportId = 'report-${DateTime.now().millisecondsSinceEpoch}';
      final post = getPostById(postId);
      _userReports.insert(
        0,
        UserReportItem(
          reportId: reportId,
          postId: postId,
          postTitle: post?.title ?? '',
          postedBy: post?.authorName ?? '',
          reason: reason,
          submittedAt: DateTime.now(),
        ),
      );
      if (post != null && !post.isReportedByCurrentUser) {
        _upsertPost(_withReportedFlag(post, true));
      }
      notifyListeners();
      return reportId;
    }
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
    if (demoMode) {
      if (_savesInFlight.contains(postId)) return false; // guard against double-tap
      _savesInFlight.add(postId);
      post.isSaved = !post.isSaved;
      _savesInFlight.remove(postId);
      notifyListeners();
      return true;
    }
    if (client == null) return false;
    if (_savesInFlight.contains(postId)) return false; // guard against double-tap

    _savesInFlight.add(postId);

    try {
      if (post.isSaved) {
        await client.unsavePost(postId);
        post.isSaved = false;
      } else {
        await client.savePost(postId);
        post.isSaved = true;
      }
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to update the saved state.';
      notifyListeners();
      return false;
    } finally {
      _savesInFlight.remove(postId);
    }
  }

  // ---------------- Fallback / seed (no API session) ----------------
  void _seedFallback() {
    if (_reportReasons.isEmpty) {
      _reportReasons = _fallbackReportReasons;
    }
    // Phase 1 demo: seed a realistic feed so every filter and card label can
    // be demonstrated without the backend.
    if (demoMode && _feedPosts.isEmpty) {
      _seedMockData();
    }
  }

  /// Phase 1 demo identity. Ownership is resolved against the authenticated
  /// user id (ProfileProvider.profile.userId), so the demo posts use the same
  /// numeric ids the login users have (demo user alice = userId 1).
  static const String _mockCurrentUserId = '1';
  static const String _mockCurrentUserName = 'Aisyah Nur';
  static const int _mockCurrentUserIdInt = 1;

  /// The demo-mode current user id (string form). Demo posts are authored by
  /// this identity, so ownership in demo mode must resolve against it — the
  /// real logged-in profile id differs from the demo seed ids.
  String? get demoCurrentUserId => demoMode ? _mockCurrentUserId : null;

  void _seedMockData() {
    final now = DateTime.now();
    _feedPosts.addAll([
      PostModel(
        id: 'post-101',
        authorId: _mockCurrentUserId,
        authorName: _mockCurrentUserName,
        authorAvatar: '',
        location: 'Batu Caves, Gombak, Selangor',
        title: 'Sunset views from the Batu Caves steps',
        description:
            'The 272 steps are worth it at golden hour — the whole city lights up from here.',
        imageUrl: 'https://picsum.photos/seed/batucaves/800/500',
        galleryImages: const [
          'https://picsum.photos/seed/batucaves/800/500',
          'https://picsum.photos/seed/batucaves2/800/500',
        ],
        likes: 142,
        commentsCount: 32,
        isLiked: true,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      PostModel(
        id: 'post-102',
        authorId: '2',
        authorName: 'Bryan Lim',
        authorAvatar: '',
        location: 'Chinatown, Kuala Lumpur',
        title: 'Hidden café above the wet market',
        description: 'Tucked away on the third floor — the coconut latte is a must.',
        imageUrl: 'https://picsum.photos/seed/cafe/800/500',
        likes: 85,
        commentsCount: 4,
        isSaved: true,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      PostModel(
        id: 'post-103',
        authorId: '3',
        authorName: 'Chloe Tan',
        authorAvatar: '',
        location: 'KL Tower, Kuala Lumpur',
        title: 'Rooftop garden above KL Tower',
        description:
            'A small garden deck with a view you will not find in the guidebooks.',
        imageUrl: 'https://picsum.photos/seed/rooftop/800/500',
        likes: 55,
        commentsCount: 12,
        isReportedByCurrentUser: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      PostModel(
        id: 'post-104',
        authorId: '2',
        authorName: 'Bryan Lim',
        authorAvatar: '',
        location: 'Taman Tugu, Kuala Lumpur',
        title: 'Early morning Taman Tugu trail',
        description:
            'Quietest at 7am — you will have the boardwalk almost to yourself.',
        imageUrl: 'https://picsum.photos/seed/trail/800/500',
        likes: 210,
        commentsCount: 45,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ]);

    _myPosts.add(_feedPosts.first);

    _userComments.add(UserCommentItem(
      commentId: 'comment-1001',
      postId: 'post-102',
      postTitle: 'Hidden café above the wet market',
      content: 'What a great find — adding this to my list!',
      authorId: _mockCurrentUserIdInt,
      authorName: _mockCurrentUserName,
      likes: 2,
      createdAt: now.subtract(const Duration(hours: 4)),
    ));

    _userReports.add(UserReportItem(
      reportId: 'report-1001',
      postId: 'post-103',
      postTitle: 'Rooftop garden above KL Tower',
      postedBy: 'Chloe Tan',
      reason: _fallbackReportReasons.first,
      submittedAt: now.subtract(const Duration(hours: 20)),
    ));

    // A community comment thread on the own post so Post Details shows
    // comments from other users alongside the current user's.
    _postComments['post-101'] = [
      UserCommentItem(
        commentId: 'comment-1002',
        postId: 'post-101',
        postTitle: 'Sunset views from the Batu Caves steps',
        content: 'Gorgeous shot — what time did you go?',
        authorId: 2,
        authorName: 'Bryan Lim',
        likes: 5,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
    ];

    _eligibleAttractions.addAll(const [
      EligibleAttractionModel(
        placeId: 'place-001',
        name: 'Batu Caves',
        address: 'Gombak, 68100 Batu Caves, Selangor',
        category: 'Historical Site',
        description: 'Iconic limestone hill with the famous 272-step stairway.',
      ),
      EligibleAttractionModel(
        placeId: 'place-002',
        name: 'Perdana Botanical Gardens',
        address: 'Jalan Kebun Bunga, 55100 Kuala Lumpur',
        category: 'Nature & Parks',
        description: 'Lakeside gardens in the heart of the city.',
      ),
      EligibleAttractionModel(
        placeId: 'place-003',
        name: 'Central Market Annexe',
        address: 'Jalan Hang Kasturi, 50050 Kuala Lumpur',
        category: 'Shopping & Market',
        description: 'Colourful arts district behind the historic market.',
      ),
    ]);
    _hasEligibleAttractions = true;
  }

  /// Returns a copy of [post] with [isReportedByCurrentUser] flipped — the
  /// field is final, so a new instance is required when a report is submitted
  /// or withdrawn (demo mode).
  PostModel _withReportedFlag(PostModel post, bool reported) => PostModel(
        id: post.id,
        authorId: post.authorId,
        authorName: post.authorName,
        authorAvatar: post.authorAvatar,
        location: post.location,
        title: post.title,
        description: post.description,
        imageUrl: post.imageUrl,
        galleryImages: post.galleryImages,
        likes: post.likes,
        commentsCount: post.commentsCount,
        isLiked: post.isLiked,
        isReportedByCurrentUser: reported,
        isSaved: post.isSaved,
        createdAt: post.createdAt,
      );

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
  }

  /// Drops everything cached for the signed-in user (feed, my posts, comments,
  /// reports, drafts and search), then re-seeds the demo fallback so the
  /// provider is usable again for the next session.
  @override
  void clearSessionData() {
    _feedPosts.clear();
    _myPosts.clear();
    _userComments.clear();
    _userReports.clear();
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
    _seedFallback();
    notifyListeners();
  }
}
