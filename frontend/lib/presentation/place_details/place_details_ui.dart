import 'package:flutter/material.dart';
import '../../models/foot_tracker/exploration_model.dart';
import '../../models/hidden_place/recommended_place_model.dart';
import '../../providers/hidden_place/hidden_place_provider.dart';
import '../../widgets/app_feedback.dart';
import 'community_verification/place_report_sheet.dart';
import 'create_review/create_review_ui.dart';
import 'community_verification/community_verification_ui.dart';
import '../navigation/app_navigation.dart';
import '../hidden_place_discovery/hidden_place_discovery_ui.dart';
import '../community/share_location/share_to_community_sheet.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../providers/hidden_place/review_provider.dart';
import 'package:explore_my/providers/auth_profile/profile_provider.dart';

// Import by Ian navigation screen
import '../../providers/foot_tracker/favourite_provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

enum PlaceReviewTargetType { google, system }

class PlaceDetailUI extends StatefulWidget {
  final PlaceData place;
  final VoidCallback? onClose;
  final PlaceReviewTargetType reviewTargetType;
  final ValueChanged<double>? onSheetExtentChanged;

  const PlaceDetailUI({
    super.key,
    required this.place,
    this.onClose,
    this.reviewTargetType = PlaceReviewTargetType.google,
    this.onSheetExtentChanged,
  });

  @override
  State<PlaceDetailUI> createState() => _PlaceDetailUIState();
}

class _PlaceDetailUIState extends State<PlaceDetailUI> {
  static const Color accent = Color(0xFFFF6242);

  // ============================================================
  // PROVIDER-BACKED AUTHORITATIVE STATE (PHASE 5)
  // ============================================================
  // For community recommendations, HiddenPlaceProvider is the single source of
  // truth for verification/report state (castVote / reportPlace / refreshPlace
  // all update the provider model). These getters prefer the provider's fresh
  // model and fall back to local fields (correct for normal Google places,
  // which the provider does not track).
  //
  // Aggregate isVerified (does the place meet the threshold) is kept separate
  // from isVerifiedByCurrentUser (did THIS user vote) — never conflated.
  RecommendedPlaceModel? get _communityModel {
    final provider = context.read<HiddenPlaceProvider>();
    final key = widget.place.recommendPlaceId ?? widget.place.placeId;
    return provider.getPlaceById(key);
  }

  bool get _hasReported => _communityModel?.isReportedByCurrentUser
      ?? _localHasReported;

  bool get _hasUserVerified => _communityModel?.isVerifiedByCurrentUser
      ?? _localHasUserVerified;

  bool get _isReportedClosed => _communityModel?.isReportedClosed
      ?? _localIsReportedClosed;

  /// Local fallback for Google-place report state (provider does not track
  /// Google places). Initialized from the widget snapshot at build time.
  bool _localHasReported = false;
  bool _localHasUserVerified = false;
  bool _localIsReportedClosed = false;

  /// True while the persisted report state is still being loaded from the
  /// backend (`hidden_place_suppression`). While true the Report Place button
  /// stays disabled so the user cannot accidentally submit a duplicate report
  /// before the button knows whether it is already reported.
  bool _isReportStatusLoading = true;

  int _selectedTab = 0;

  // ============================================================
  // TEMPORARY UI-ONLY REVIEW STATE
  // ============================================================
  // false = show the "Start your review" UI.
  // true  = show the current user's existing review.
  //
  // This is intentionally local/mock for now. Later the backend
  // can provide this value and the user's actual review data.
  bool _hasUserReviewed = false;
  bool _isLoadingMyReview = true;
  //Add by Ian for favourite place
  bool _isFavourite = false;
  bool _isTogglingFavourite = false;
  Map<String, dynamic>? _myReview;

  List<dynamic> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();

    // Initialize local Google-place fallbacks from the widget snapshot. For
    // community places the getters read the provider instead, so these only
    // matter when the provider does not track this place (normal Google place).
    _localHasReported = widget.place.isReportedByCurrentUser;
    _localHasUserVerified = widget.place.isVerifiedByCurrentUser;
    _localIsReportedClosed = widget.place.isReportedClosed;

    _loadReportStatus();
    _loadMyReview();
    _loadReviews();
    //Added by Ian for favourite place
    _loadFavouriteStatus();
  }

  /// Loads the persisted report state from the backend (`hidden_place_suppression`)
  /// so the Report Place button shows "Reported"/disabled on open, not only after
  /// a duplicate-report attempt.
  ///
  /// - Recommended place: the existing recommendation-details endpoint already
  ///   returns `isReportedByCurrentUser` (resolved via the canonical
  ///   recommend_place_id on the backend) — refresh the provider model and let the
  ///   `_communityModel` getter pick it up.
  /// - Normal Google place: no submission row exists, so check `hidden_place_suppression`
  ///   directly with the Google place_id via the report-status endpoint.
  ///
  /// Failure is safe: the flag flips false so the button becomes clickable, and the
  /// existing 409-duplicate path still protects the user on submit.
  Future<void> _loadReportStatus() async {
    final provider = context.read<HiddenPlaceProvider>();
    final recommendPlaceId = widget.place.recommendPlaceId;

    if (recommendPlaceId != null) {
      // Recommended place — details endpoint already carries the state.
      await provider.loadRecommendationDetails(recommendPlaceId);
    } else {
      // Normal Google place — direct suppression check by Google place_id.
      final reported = await provider.checkPlaceReportStatus(widget.place.placeId);
      if (reported != null && mounted) {
        setState(() {
          _localHasReported = reported;
          if (reported) {
            _localIsReportedClosed = true;
          }
        });
      }
    }

    if (mounted) {
      setState(() => _isReportStatusLoading = false);
    }
  }

  // Shows the compact title bar only after the original place
  // header has completely scrolled out of the visible sheet.
  bool _showStickyHeader = false;

  String _selectedFilter = 'Newest';

  String _priceLevelText(int? priceLevel) {
    if (priceLevel == null) {
      return '';
    }

    switch (priceLevel) {
      case 0:
        return 'Free';
      case 1:
        return '\$';
      case 2:
        return '\$\$';
      case 3:
        return '\$\$\$';
      case 4:
        return '\$\$\$\$';
      default:
        return '';
    }
  }

  String _businessStatusText(String status) {
    final hours = _openingHours();

    if (status.toUpperCase() == 'CLOSED_TEMPORARILY') {
      return 'Temporarily closed';
    }

    if (status.toUpperCase() == 'CLOSED_PERMANENTLY') {
      return 'Permanently closed';
    }

    if (hours != null) {
      final openNow = hours['openNow'];

      if (openNow == true) {
        return 'Open now';
      }

      if (openNow == false) {
        return 'Closed now';
      }
    }

    if (status.toUpperCase() == 'OPERATIONAL') {
      return 'Operational';
    }

    return 'Status unavailable';
  }

  Map<String, dynamic>? _openingHours() {
    final jsonString = widget.place.regularOpeningHoursJson;

    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  //Used by Ian favourite place
  Future<void> _loadFavouriteStatus() async {
    final favouriteProvider = context.read<FavouriteProvider>();
    if (favouriteProvider.places.isEmpty) {
      await favouriteProvider.loadPlaces();
    }
    if (!mounted) return;
    setState(() {
      _isFavourite = favouriteProvider.isFavourite(widget.place.placeId);
    });
  }

  Future<void> _toggleFavourite() async {
    if (_isTogglingFavourite) return;
    setState(() => _isTogglingFavourite = true);

    final favouriteProvider = context.read<FavouriteProvider>();
    final wasFavourite = _isFavourite;

    try {
      if (wasFavourite) {
        await favouriteProvider.removeFavouritePlaceByPlaceId(
          widget.place.placeId,
        );
      } else {
        await favouriteProvider.addFavouritePlace(
          placeId: widget.place.placeId,
          name: widget.place.title,
          primaryType: widget.place.primaryType,
          address: widget.place.address,
          latitude: widget.place.position.latitude,
          longitude: widget.place.position.longitude,
        );
      }
      if (!mounted) return;
      setState(() {
        _isFavourite = !wasFavourite;
        _isTogglingFavourite = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTogglingFavourite = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasFavourite
                ? 'Failed to remove favourite.'
                : 'Failed to add favourite.',
          ),
        ),
      );
    }
  }
  //Until up only Ian

  Future<void> _loadMyReview() async {
    try {
      final reviewProvider = context.read<ReviewProvider>();

      final review = await reviewProvider.getMyReview(
        googlePlaceId: widget.reviewTargetType == PlaceReviewTargetType.google
            ? widget.place.placeId
            : null,
        recommendPlaceId:
        widget.reviewTargetType == PlaceReviewTargetType.system
            ? widget.place.placeId
            : null,
      );

      if (!mounted) return;

      setState(() {
        _myReview = review;
        _hasUserReviewed = review != null;
        _isLoadingMyReview = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMyReview = false;
      });

      debugPrint('Failed to load my review: $e');
    }
  }

  Future<void> _loadReviews() async {
    try {
      final reviewProvider = context.read<ReviewProvider>();

      final reviews = await reviewProvider.getReviews(
        googlePlaceId: widget.reviewTargetType == PlaceReviewTargetType.google
            ? widget.place.placeId
            : null,
        recommendPlaceId:
        widget.reviewTargetType == PlaceReviewTargetType.system
            ? widget.place.placeId
            : null,
      );

      if (!mounted) return;

      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingReviews = false;
      });

      debugPrint('Failed to load reviews: $e');
    }
  }

  String _formatReviewTime(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) {
      return '';
    }

    final date = DateTime.tryParse(createdAt);

    if (date == null) {
      return '';
    }

    final difference = DateTime.now().difference(date);

    if (difference.inDays >= 365) {
      return '${difference.inDays ~/ 365}y ago';
    }

    if (difference.inDays >= 30) {
      return '${difference.inDays ~/ 30}mo ago';
    }

    if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    }

    if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    }

    if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    }

    return 'Just now';
  }

  // Used to measure the real position of the original header instead of
  // relying on a hard-coded scroll offset.
  final GlobalKey _placeHeaderKey = GlobalKey();
  final GlobalKey _scrollViewKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // This widget is now intended to be layered over the real discovery map.
    // The discovery screen owns the GoogleMap; this widget owns only the
    // draggable place-detail sheet.
    return DraggableScrollableSheet(
      initialChildSize: 0.43,
      minChildSize: 0.10,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.10, 0.43, 0.92],
      builder: (BuildContext context, ScrollController scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            widget.onSheetExtentChanged?.call(notification.extent);
            return false;
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 18,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 &&
                    notification is ScrollUpdateNotification) {
                  final headerContext = _placeHeaderKey.currentContext;
                  final scrollContext = _scrollViewKey.currentContext;

                  bool shouldShow = false;

                  if (headerContext != null && scrollContext != null) {
                    final headerBox =
                    headerContext.findRenderObject() as RenderBox?;
                    final scrollBox =
                    scrollContext.findRenderObject() as RenderBox?;

                    if (headerBox != null && scrollBox != null) {
                      final headerTop = headerBox.localToGlobal(Offset.zero).dy;
                      final headerBottom = headerTop + headerBox.size.height;
                      final scrollTop = scrollBox.localToGlobal(Offset.zero).dy;

                      // Show the compact header only when the entire
                      shouldShow = headerBottom <= scrollTop + 80;
                    }
                  }

                  if (shouldShow != _showStickyHeader) {
                    setState(() => _showStickyHeader = shouldShow);
                  }
                }
                return false;
              },
              child: Stack(
                children: [
                  CustomScrollView(
                    key: _scrollViewKey,
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _buildDragHandle(),
                            _buildPlaceHeader(),
                            _buildActions(),
                            // Community (recommended) places show their
                            // aggregate Verification Status here; normal
                            // Google places render nothing (returns shrink).
                            _buildVerificationStatus(),
                            _buildPhotos(),
                            _buildTabs(),
                          ],
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _buildSelectedTabContent(),
                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // This is an OVERLAY, not part of the scroll content.
                  // It only appears after the user scrolls upward.
                  if (_showStickyHeader)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildStickyPlaceHeader(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 9, bottom: 5),
        width: 96,
        height: 5,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  // =========================
  // STICKY COMPACT PLACE HEADER
  // =========================

  Widget _buildStickyPlaceHeader() {
    return Stack(
      children: [
        Container(
          height: 72,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              // Same handle area as the initial sheet.
              Container(
                margin: const EdgeInsets.only(top: 9, bottom: 2),
                width: 96,
                height: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.place.title,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed:
                        widget.onClose ??
                                () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.close,
                          size: 24,
                          color: Colors.black87,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(height: 1, color: const Color(0xFFD9D9D9)),
        ),
      ],
    );
  }

  // =========================
  // PLACE HEADER
  // =========================

  Widget _buildPlaceHeader() {
    return Padding(
      key: _placeHeaderKey,
      padding: const EdgeInsets.fromLTRB(22, 10, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.place.title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      widget.place.category,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _priceLevelText(widget.place.priceLevel),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.directions_car_outlined,
                      size: 15,
                      color: Colors.grey.shade800,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Distance',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _businessStatusText(widget.place.businessStatus),
                  style: TextStyle(
                    color:
                    widget.place.businessStatus.toUpperCase() ==
                        'OPERATIONAL'
                        ? const Color(0xff25a35a)
                        : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            onPressed: widget.onClose ?? () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 27, color: Color(0xff333333)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMUNITY / VERIFICATION STATUS
  // ============================================================
  // Shown ONLY for recommended (community) places — i.e. when
  // [PlaceData.recommendPlaceId] is non-null. For normal Google places
  // this renders an empty box so no Community / Verification UI appears.
  //
  // The badge reflects the AGGREGATE community verification status
  // ([PlaceData.isVerified]), which is deliberately kept separate from the
  // current user's own vote ([PlaceData.isVerifiedByCurrentUser]) — the
  // Community Verification screen handles the per-user vote/withdraw.
  Widget _buildVerificationStatus() {
    if (widget.place.recommendPlaceId == null) {
      return const SizedBox.shrink();
    }

    final bool verified = widget.place.isVerified;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: verified ? const Color(0xffe8f7ee) : const Color(0xfff3f3f3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: verified ? const Color(0xffb7e3c8) : const Color(0xffdddddd),
          ),
        ),
        child: Row(
          children: [
            Icon(
              verified ? Icons.verified_outlined : Icons.schedule,
              size: 17,
              color: verified ? const Color(0xff25a35a) : const Color(0xff666666),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                verified ? 'Verified' : 'Not yet verified',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: verified ? const Color(0xff1d7a44) : const Color(0xff555555),
                ),
              ),
            ),
            if (verified)
              const Text(
                'By the community',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xff888888),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =========================
  // ACTION BUTTONS
  // =========================

  Widget _buildActions() {
    final bool isCommunity =
        widget.place.recommendPlaceId != null;

    // Report Place is shown for BOTH place kinds. For a recommended place it
    // appears NEXT TO Community (recommended places keep Community /
    // Verification and gain Report Place). The button is disabled while the
    // persisted report state is still loading, so the user cannot submit a
    // duplicate report before the button knows whether it is already reported.
    final reportButton = _actionButton(
      _hasReported
          ? Icons.check
          : Icons.report_outlined,
      _hasReported ? 'Reported' : 'Report Place',
      enabled: !_hasReported && !_isReportStatusLoading,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [
          _actionButton(
            Icons.directions,
            'Direction',
            selected: true,
          ),

          const SizedBox(width: 6),

          _actionButton(
            _isFavourite
                ? Icons.favorite
                : Icons.favorite_border,
            'Save',
          ),

          const SizedBox(width: 6),

          _actionButton(
            Icons.share_outlined,
            'Share',
          ),

          const SizedBox(width: 6),

          if (isCommunity) ...[
            _actionButton(
              Icons.verified_outlined,
              'Community',
            ),
            const SizedBox(width: 6),
            reportButton,
          ] else
            reportButton,
        ],
      ),
    );
  }

  Widget _actionButton(
      IconData icon,
      String text, {
        bool selected = false,
        bool enabled = true,
      }) {
    return Expanded(
      child: Material(
        color: selected
            ? accent
            : (enabled
            ? const Color(0xfff4f4f4)
            : const Color(0xFFE7E7E7)),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: enabled
              ? () async {
            // ============================================================
            // COMMUNITY
            // Only community recommendations can open verification.
            // ============================================================
            if (text == 'Community') {
              final recommendPlaceId =
                  widget.place.recommendPlaceId;

              // Normal Google place cannot enter Community Verification.
              if (recommendPlaceId == null) {
                return;
              }

              // debugPrint(
              //   'COMMUNITY VERIFICATION DATA: '
              //       'place_id=${widget.place.placeId}, '
              //       'recommend_place_id=$recommendPlaceId, '
              //       'submission_id=$recommendPlaceId',
              // );

              // Community verification uses recommend_place_id,
              // NOT Google place_id.
              final result =
              await AppNavigation.toCommunityVerification(
                context,
                placeId: recommendPlaceId,
                placeStatus: widget.place.isVerified
                    ? CommunityPlaceStatus.verified
                    : CommunityPlaceStatus.unverified,
                userVote: _hasUserVerified
                    ? CommunityUserVote.verify
                    : CommunityUserVote.none,
                placeName: widget.place.title,
                recommendedBy: widget.place.recommendedBy,
                hasReported: _hasReported,
                isReportedClosed: _isReportedClosed,
              );

              // Sync current user's verification state after returning.
              // Prefer the provider's authoritative model (which was refreshed
              // by the child's castVote call) over the raw result, so that any
              // server-side enforcement (e.g. minimum voting period) is reflected.
              if (!mounted) return;

              if (result != null) {
                final provider = context.read<HiddenPlaceProvider>();
                final fresh = provider.getPlaceById(recommendPlaceId);
                setState(() {
                  _localHasUserVerified = fresh?.isVerifiedByCurrentUser
                      ?? (result == CommunityUserVote.verify);
                });
              }

              return;
            }

            // ============================================================
            // REPORT PLACE (both Google and recommended places)
            // The sheet posts to /reports which the backend resolves: a
            // recommended place's submission GUID maps to its canonical
            // recommend_place_id; a Google place_id is used directly.
            // ============================================================
            if (text == 'Report Place') {
              await _openPlaceReportSheet();
              return;
            }

            // ============================================================
            // DIRECTION
            // ============================================================
            if (text == 'Direction') {
              // Pass real Google place_id so FootTracker
              // can save the visited place correctly.
              AppNavigation.toDirection(
                context,
                destinationName: widget.place.title,
                destinationAddress: widget.place.address ?? '',
                destinationLat: widget.place.position.latitude,
                destinationLng: widget.place.position.longitude,
                destinationPlaceId: widget.place.placeId,
                destinationCategory: FavouritePlace.mapToUiCategory(
                  widget.place.primaryType,
                ),
              );

              return;
            }

            // ============================================================
            // SAVE
            // ============================================================
            if (text == 'Save') {
              _toggleFavourite();
              return;
            }

            // ============================================================
            // SHARE
            // Opens the Communication module's "share to a joined group
            // chat" picker (Share Location). Added here as the entry point
            // Place Details already has a stub button for; the picker,
            // provider method, and message rendering all live in the
            // Communication module.
            // ============================================================
            if (text == 'Share') {
              await ShareToCommunitySheet.show(context, place: widget.place);
              return;
            }

            // ============================================================
            // DEFAULT
            // ============================================================
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$text selected'),
              ),
            );
          }
              : null,
          child: SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? Colors.white
                      : const Color(0xff333333),
                ),
                const SizedBox(width: 3),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? Colors.white
                        : const Color(0xff333333),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPlaceReportSheet() async {
    // PlaceReportSheet submits to POST /reports with a single identifier. For a
    // recommended place that is the submission GUID (recommendPlaceId), which
    // the backend resolves to the canonical recommend_place_id; for a Google
    // place it is the Google place_id itself. Both identities are accepted.
    final submissionId =
        widget.place.recommendPlaceId ?? widget.place.placeId;

    if (submissionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to report this place.'),
        ),
      );
      return;
    }

    final result = await PlaceReportSheet.show(
      context,
      submissionId: submissionId,
    );

    if (!mounted) return;

    final provider = context.read<HiddenPlaceProvider>();

    // 409 = already reported.
    if (result == null) {
      if (provider.lastReportWasDuplicate) {
        setState(() {
          _localHasReported = true;
        });
      }
      return;
    }

    // Report succeeded.
    setState(() {
      _localHasReported = true;
      _localIsReportedClosed =
          result.placeStatus == 'REPORTED_CLOSED';
    });

    AppFeedback.show(
      context,
      message: result.message,
      isSuccess: true,
    );
  }
  // =========================
  // PHOTOS
  // =========================

  List<String> _getPlacePhotoUrls() {
    final photoUrls = <String>[];

    // 1. ONE system/Google photo.
    if (widget.place.imageUrl.isNotEmpty) {
      photoUrls.add(widget.place.imageUrl);
    }

    // 2. Photos from ACTIVE user reviews only.
    for (final review in _reviews) {
      if (review is! Map<String, dynamic>) continue;

      // Ignore deleted reviews completely.
      final status = review['status']?.toString().toUpperCase();

      if (status != null && status != 'ACTIVE') {
        continue;
      }

      final photos = review['photos'];

      if (photos is! List) continue;

      for (final photo in photos) {
        if (photo is! Map<String, dynamic>) continue;

        final photoUrl = photo['photoUrl']?.toString() ?? '';

        if (photoUrl.isNotEmpty && !photoUrls.contains(photoUrl)) {
          photoUrls.add(photoUrl);
        }
      }
    }

    return photoUrls;
  }

  Widget _buildPhotos() {
    final allPhotos = _getPlacePhotoUrls();

    if (allPhotos.isEmpty) {
      return SizedBox(
        height: 300,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: const Color(0xffe1e1e1),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 48,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No photos yet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ============================================================
    // OVERVIEW PHOTO LIMIT
    // ============================================================
    //
    // Only show the first 8 photos in Overview.
    //
    // Photos tab still contains ALL photos.
    //
    const maxOverviewPhotos = 8;

    final hasMorePhotos = allPhotos.length > maxOverviewPhotos;

    final photos = allPhotos.take(maxOverviewPhotos).toList();

    // Every 3 photos = one gallery group.
    //
    // [0,1,2]
    // [3,4,5]
    // [6,7]
    //
    final groupCount = (photos.length + 2) ~/ 3;

    return SizedBox(
      height: 430,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
        physics: const BouncingScrollPhysics(),
        itemCount: groupCount,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, groupIndex) {
          final start = groupIndex * 3;
          final end = (start + 3 > photos.length) ? photos.length : start + 3;

          final group = photos.sublist(start, end);

          final isLastGroup = groupIndex == groupCount - 1;

          return _photoGalleryGroup(
            group,
            isLastGroup: isLastGroup,
            hasMorePhotos: hasMorePhotos,
          );
        },
      ),
    );
  }

  Widget _photoGalleryGroup(
      List<String> photos, {
        required bool isLastGroup,
        required bool hasMorePhotos,
      }) {
    const double bigWidth = 366;
    const double smallWidth = 234;

    // ============================================================
    // 1 PHOTO
    //
    // ┌──────────────────────┬──────────────┐
    // │                      │ No more      │
    // │       photo 0        ├──────────────┤
    // │                      │ View All     │
    // └──────────────────────┴──────────────┘
    // ============================================================

    if (photos.length == 1) {
      return SizedBox(
        width: bigWidth + 8 + smallWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: bigWidth,
              child: _networkPhoto(photos[0], radius: 14, iconSize: 48),
            ),

            const SizedBox(width: 8),

            SizedBox(
              width: smallWidth,
              child: Column(
                children: [
                  Expanded(child: _noMorePhotosTile()),

                  const SizedBox(height: 8),

                  Expanded(child: _viewAllPhotosTile()),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ============================================================
    // 2 PHOTOS
    //
    // ┌──────────────────────┬──────────────┐
    // │                      │ photo 1      │
    // │       photo 0        ├──────────────┤
    // │                      │ No more      │
    // └──────────────────────┴──────────────┘
    // ============================================================

    if (photos.length == 2) {
      return SizedBox(
        width: bigWidth + 8 + smallWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: bigWidth,
              child: _networkPhoto(photos[0], radius: 14, iconSize: 48),
            ),

            const SizedBox(width: 8),

            SizedBox(
              width: smallWidth,
              child: Column(
                children: [
                  Expanded(
                    child: _networkPhoto(photos[1], radius: 14, iconSize: 30),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: (isLastGroup && hasMorePhotos)
                        ? _viewAllPhotosTile()
                        : _noMorePhotosTile(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ============================================================
    // 3 PHOTOS
    //
    // ┌──────────────────────┬──────────────┐
    // │                      │ photo 1      │
    // │       photo 0        ├──────────────┤
    // │                      │ photo 2      │
    // └──────────────────────┴──────────────┘
    // ============================================================

    if (photos.length == 3) {
      return SizedBox(
        width: bigWidth + 8 + smallWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: bigWidth,
              child: _networkPhoto(photos[0], radius: 14, iconSize: 48),
            ),

            const SizedBox(width: 8),

            SizedBox(
              width: smallWidth,
              child: Column(
                children: [
                  Expanded(
                    child: _networkPhoto(photos[1], radius: 14, iconSize: 30),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: _networkPhoto(photos[2], radius: 14, iconSize: 30),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _viewAllPhotosTile() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: const Color(0xffe1e1e1),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedTab = 2;
            });
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 30, color: accent),
                const SizedBox(height: 6),
                Text(
                  'View all photos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _noMorePhotosTile() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: const Color(0xffe1e1e1),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 30,
                color: Colors.grey.shade500,
              ),
              const SizedBox(height: 6),
              Text(
                'No more photos',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _networkPhoto(
      String photoUrl, {
        required double radius,
        required double iconSize,
      }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _FullScreenPhotoViewer(photoUrl: photoUrl),
            ),
          );
        },
        child: Image.network(
          photoUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _imagePlaceholder(radius: radius, iconSize: iconSize);
          },
        ),
      ),
    );
  }

  Widget _imagePlaceholder({required double radius, required double iconSize}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xffe1e1e1),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: iconSize,
          color: const Color(0xffa0a0a0),
        ),
      ),
    );
  }

  // =========================
  // TABS
  // =========================

  Widget _buildTabs() {
    const tabs = ['Overview', 'Reviews', 'Photos'];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffc8c8c8), width: 1)),
      ),
      child: Row(
        children: List.generate(
          tabs.length,
              (index) => Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _selectedTab = index);
              },
              child: SizedBox(
                height: 39,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      tabs[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedTab == index
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: _selectedTab == index
                            ? accent
                            : const Color(0xff222222),
                      ),
                    ),
                    const SizedBox(height: 7),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      height: 2,
                      width: _selectedTab == index ? 72 : 0,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTab) {
      case 1:
        return _buildAllReviews();
      case 2:
        return _buildPhotoTab();
      default:
        return _buildOverview();
    }
  }

  // =========================
  // OVERVIEW
  // =========================

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildOverviewInfoCards(), _buildOverviewReviews()],
    );
  }

  Widget _buildOverviewInfoCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.place.address != null && widget.place.address!.isNotEmpty)
          _infoCard(Icons.location_on_outlined, widget.place.address!),

        if (widget.place.phoneNumber != null &&
            widget.place.phoneNumber!.isNotEmpty)
          _infoCard(Icons.phone_outlined, widget.place.phoneNumber!),

        if (widget.place.websiteUri != null &&
            widget.place.websiteUri!.isNotEmpty)
          _infoCard(Icons.language, widget.place.websiteUri!),
      ],
    );
  }

  Widget _buildOverviewReviews() {
    final activeReviews = _reviews
        .where((review) {
      if (review is! Map<String, dynamic>) return false;

      final status = review['status']?.toString().toUpperCase();

      return status == null || status == 'ACTIVE';
    })
        .whereType<Map<String, dynamic>>()
        .toList();

    // Newest first
    activeReviews.sort((a, b) {
      final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '');

      final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '');

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    // Overview only shows 3 reviews.
    final previewReviews = activeReviews.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 17, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 3),

          if (_isLoadingReviews)
            const SizedBox(
              height: 184,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (previewReviews.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: SizedBox(height: 184, child: _emptyOverviewReviewCard()),
            )
          else
            SizedBox(
              height: 184,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 20),
                itemCount: previewReviews.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final review = previewReviews[index];

                  final username =
                      review['username']?.toString() ?? 'Unknown User';

                  final comment = review['comment']?.toString() ?? '';

                  final rating = (review['rating'] as num?)?.toInt() ?? 0;

                  final createdAt = review['createdAt']?.toString();

                  final photos = review['photos'] is List
                      ? review['photos'] as List<dynamic>
                      : <dynamic>[];

                  return _overviewReviewCard(
                    name: username,
                    ago: _formatReviewTime(createdAt),
                    text: comment,
                    rating: rating,
                    photos: photos,
                    profilePhotoUrl: _getReviewProfilePhotoUrl(review),
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _selectedTab = 1);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: const BorderSide(color: accent, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View All Reviews',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyOverviewReviewCard() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xfffafafa),
          border: Border.all(color: const Color(0xffd8d8d8)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.rate_review_outlined,
                size: 32,
                color: Color(0xffb0b0b0),
              ),
              SizedBox(height: 8),
              Text(
                'No reviews yet',
                style: TextStyle(fontSize: 12, color: Color(0xff888888)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overviewReviewCard({
    required String name,
    required String ago,
    required String text,
    required int rating,
    required List<dynamic> photos,
    String? profilePhotoUrl,
  }) {
    return SizedBox(
      width: 245,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xfffafafa),
          border: Border.all(color: const Color(0xffd8d8d8)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xffffd7cf),
                  backgroundImage: profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
                      ? NetworkImage(profilePhotoUrl)
                      : null,
                  child: profilePhotoUrl == null || profilePhotoUrl.isEmpty
                      ? Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  ago,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 8.5),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${'★' * rating}${'☆' * (5 - rating)}',
              style: const TextStyle(
                color: accent,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      text,
                      maxLines: photos.isNotEmpty ? 4 : 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, height: 1.35),
                    ),
                  ),

                  if (photos.isNotEmpty) ...[
                    const SizedBox(width: 8),

                    _overviewReviewPhoto(photos.first),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewReviewPhoto(dynamic photo) {
    final photoUrl = photo is Map<String, dynamic>
        ? photo['photoUrl']?.toString() ?? ''
        : '';

    if (photoUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Image.network(
        photoUrl,
        width: 55,
        height: 55,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 55,
            height: 55,
            color: const Color(0xffe1e1e1),
            child: const Icon(
              Icons.broken_image_outlined,
              size: 20,
              color: Color(0xff999999),
            ),
          );
        },
      ),
    );
  }

  Widget _infoCard(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xfff5f5f5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xff222222)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredReviews() {
    final reviews = _reviews
        .whereType<Map<String, dynamic>>()
        .where((review) {
      final status = review['status']?.toString().toUpperCase();

      // Only show active reviews.
      return status == null || status == 'ACTIVE';
    })
        .where((review) {
      // Don't show the current user's review again
      // in the "other users" section.
      if (_myReview == null) {
        return true;
      }

      return review['reviewId'] != _myReview!['reviewId'];
    })
        .toList();

    switch (_selectedFilter) {
      case 'Newest':
        reviews.sort((a, b) {
          final aDate =
          DateTime.tryParse(a['createdAt']?.toString() ?? '');
          final bDate =
          DateTime.tryParse(b['createdAt']?.toString() ?? '');

          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;

          return bDate.compareTo(aDate);
        });
        break;

      case 'Highest Rating':
        reviews.sort((a, b) {
          final aRating = (a['rating'] as num?)?.toDouble() ?? 0;
          final bRating = (b['rating'] as num?)?.toDouble() ?? 0;

          return bRating.compareTo(aRating);
        });
        break;

      case 'Lowest Rating':
        reviews.sort((a, b) {
          final aRating = (a['rating'] as num?)?.toDouble() ?? 0;
          final bRating = (b['rating'] as num?)?.toDouble() ?? 0;

          return aRating.compareTo(bRating);
        });
        break;

      case 'With Photo':
        reviews.removeWhere((review) {
          final photos = review['photos'];

          if (photos is! List) {
            return true;
          }

          return photos.isEmpty;
        });
        break;
    }

    return reviews;
  }

  Widget _buildReviewsPreview() {
    final otherReviews = _reviews
        .where((review) {
      final reviewMap = review as Map<String, dynamic>;

      if (_myReview == null) {
        return true;
      }

      return reviewMap['reviewId'] != _myReview!['reviewId'];
    })
        .take(2)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 9),

          if (_isLoadingReviews)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (otherReviews.isEmpty)
            const Text(
              'No reviews yet.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          else
            ...otherReviews.map((review) {
              final reviewMap = review as Map<String, dynamic>;

              final username =
                  reviewMap['username']?.toString() ?? 'Unknown User';

              final profilePhotoUrl =
              _getReviewProfilePhotoUrl(reviewMap);

              final rating = (reviewMap['rating'] as num?)?.toInt() ?? 0;

              final comment = reviewMap['comment']?.toString() ?? '';

              final createdAt = reviewMap['createdAt']?.toString();

              final photos =
                  (reviewMap['photos'] as List<dynamic>?) ?? [];

              return _review(
                username,
                comment,
                reviewId: (reviewMap['reviewId'] as num).toInt(),
                rating: rating,
                time: _formatReviewTime(createdAt),
                photos: photos,
                profilePhotoUrl: profilePhotoUrl,
              );
            }),
        ],
      ),
    );
  }

  // =========================
  // ALL REVIEWS
  // =========================

  Widget _buildAllReviews() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================
          // YOUR REVIEW
          // =========================
          _hasUserReviewed
              ? _buildExistingUserReview()
              : _buildStartUserReview(),

          const SizedBox(height: 14),

          // Separator between "Your review" and other people's reviews.
          Container(
            height: 1,
            width: double.infinity,
            color: const Color(0xffd2d2d2),
          ),

          const SizedBox(height: 10),

          // =========================
          // FILTERS
          // =========================
          Row(
            children: [
              Expanded(
                child: _reviewFilter(
                  'Newest',
                  selected: _selectedFilter == 'Newest',
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'Newest';
                    });
                  },
                ),
              ),
              const SizedBox(width: 4),

              Expanded(
                child: _reviewFilter(
                  'Highest Rating',
                  selected: _selectedFilter == 'Highest Rating',
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'Highest Rating';
                    });
                  },
                ),
              ),
              const SizedBox(width: 4),

              Expanded(
                child: _reviewFilter(
                  'Lowest Rating',
                  selected: _selectedFilter == 'Lowest Rating',
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'Lowest Rating';
                    });
                  },
                ),
              ),
              const SizedBox(width: 4),

              Expanded(
                child: _reviewFilter(
                  'With Photo',
                  selected: _selectedFilter == 'With Photo',
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'With Photo';
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // =========================
          // REVIEWS
          // =========================
          if (_isLoadingReviews)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_getFilteredReviews().isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No reviews yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            )
          else
            ..._getFilteredReviews().map((reviewMap) {
              final username =
                  reviewMap['username']?.toString() ?? 'Unknown User';

              final profilePhotoUrl =
              _getReviewProfilePhotoUrl(reviewMap);

              final rating =
                  (reviewMap['rating'] as num?)?.toInt() ?? 0;

              final comment =
                  reviewMap['comment']?.toString() ?? '';

              final createdAt =
              reviewMap['createdAt']?.toString();

              final photos =
                  (reviewMap['photos'] as List<dynamic>?) ?? [];

              return Column(
                children: [
                  _review(
                    username,
                    comment,
                    reviewId: (reviewMap['reviewId'] as num).toInt(),
                    rating: rating,
                    time: _formatReviewTime(createdAt),
                    photos: photos,
                    profilePhotoUrl: profilePhotoUrl,
                  ),
                  const Divider(
                    height: 1,
                    color: Color(0xffdddddd),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }),
        ],
      ),
    );
  }

  // ============================================================
  // USER HAS NOT REVIEWED YET
  // ============================================================

  Widget _buildStartUserReview() {
    final profileProvider = context.watch<ProfileProvider>();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your review',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xffffd7cf),
                backgroundImage: profileProvider.avatarImage,
                child: profileProvider.avatarImage == null
                    ? Text(
                  profileProvider.profile?.username.isNotEmpty == true
                      ? profileProvider.profile!.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 28),
              Row(
                children: List.generate(
                  5,
                      (index) => GestureDetector(
                    onTap: () async {
                      final result = await AppNavigation.toCreateReview(
                        context,
                        initialRating: index + 1,
                        placeId: widget.place.placeId,
                        placeName: widget.place.title,
                        placeType: widget.reviewTargetType ==
                            PlaceReviewTargetType.system
                            ? ReviewPlaceType.system
                            : ReviewPlaceType.google,
                      );

                      if (result == true && mounted) {
                        await _loadMyReview();
                        await _loadReviews();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.star_border_rounded,
                        color: accent,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // USER HAS ALREADY REVIEWED
  // ============================================================

  Widget _buildExistingUserReview() {
    final photos = (_myReview?['photos'] as List<dynamic>?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your review',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xffffd7cf),
                backgroundImage: _getReviewProfilePhotoUrl(_myReview ?? {}) != null
                    ? NetworkImage(_getReviewProfilePhotoUrl(_myReview ?? {})!)
                    : null,
                child: _getReviewProfilePhotoUrl(_myReview ?? {}) == null
                    ? Text(
                  (_myReview?['username']?.toString().isNotEmpty ?? false)
                      ? _myReview!['username'].toString()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT COLUMN
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _myReview?['username']?.toString() ?? 'You',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(width: 6),

                                  const Text(
                                    '•',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(width: 4),

                                  Text(
                                    _formatReviewTime(
                                      _myReview?['createdAt']?.toString(),
                                    ),
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 3),

                              Text(
                                '★' *
                                    ((_myReview?['rating'] as num?)?.toInt() ??
                                        0),
                                style: const TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // RIGHT COLUMN
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          icon: const Icon(
                            Icons.more_vert,
                            color: Color(0xff555555),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 100,
                            maxWidth: 120,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(
                              color: Color(0xffd9d9d9),
                              width: 1,
                            ),
                          ),
                          elevation: 2,
                          onSelected: (value) async {
                            if (value == 'edit') {
                              final result = await AppNavigation.toCreateReview(
                                context,
                                initialRating: (_myReview?['rating'] as num?)
                                    ?.toInt() ?? 0,
                                initialReviewText:
                                    _myReview?['comment']?.toString() ?? '',
                                placeId: widget.place.placeId,
                                placeName: widget.place.title,
                                placeType: widget.reviewTargetType ==
                                    PlaceReviewTargetType.system
                                    ? ReviewPlaceType.system
                                    : ReviewPlaceType.google,
                                isEdit: true,
                                reviewId: _myReview?['reviewId'],
                                initialPhotos:
                                    (_myReview?['photos'] as List<dynamic>?) ?? [],
                              );

                              if (result == true && mounted) {
                                await _loadMyReview();
                                await _loadReviews();
                              }
                            } else if (value == 'delete') {
                              showDialog<void>(
                                context: context,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: const Text(
                                      'Delete this review?',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    content: const Text(
                                      'Deleted reviews cannot be recovered.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    actionsPadding: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      14,
                                    ),
                                    actions: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () {
                                                Navigator.pop(dialogContext);
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xffe5e5e5,
                                                ),
                                                foregroundColor: const Color(
                                                  0xff333333,
                                                ),
                                                padding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(22),
                                                ),
                                              ),
                                              child: const Text(
                                                'No',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 14),

                                          Expanded(
                                            child: TextButton(
                                              onPressed: () async {
                                                final reviewId =
                                                _myReview?['reviewId'];

                                                if (reviewId == null) {
                                                  Navigator.pop(dialogContext);

                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Review ID not found.',
                                                      ),
                                                    ),
                                                  );

                                                  return;
                                                }

                                                try {
                                                  await context
                                                      .read<ReviewProvider>()
                                                      .deleteReview(
                                                    reviewId:
                                                    (reviewId as num)
                                                        .toInt(),
                                                  );

                                                  if (!mounted) return;

                                                  Navigator.of(context).pop();

                                                  setState(() {
                                                    _myReview = null;
                                                    _hasUserReviewed = false;
                                                  });

                                                  await _loadReviews();

                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Review deleted successfully.',
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  if (!mounted) return;

                                                  Navigator.of(context).pop();

                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Failed to delete review: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: accent,
                                                foregroundColor: Colors.white,
                                                padding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(22),
                                                ),
                                              ),
                                              child: const Text(
                                                'Yes',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              height: 30,
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'Edit review',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              height: 30,
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'Delete review',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _myReview?['comment']?.toString() ?? '',
                            style: const TextStyle(fontSize: 11, height: 1.35),
                          ),

                          const SizedBox(height: 9),

                          if (photos.isNotEmpty) ...[
                            const SizedBox(height: 9),
                            SizedBox(
                              height: 180,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: photos.length,
                                separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final photoUrl =
                                      photos[index]['photoUrl']?.toString() ??
                                          '';

                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => _FullScreenPhotoViewer(
                                              photoUrl: photoUrl,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Image.network(
                                        photoUrl,
                                        width: 180,
                                        height: 180,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            width: 180,
                                            height: 180,
                                            color: const Color(0xffe1e1e1),
                                            child: const Center(
                                              child: Icon(
                                                Icons.broken_image_outlined,
                                                size: 34,
                                                color: Color(0xffa0a0a0),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(int rating, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text('$rating', style: const TextStyle(fontSize: 9)),
          ),
          const Icon(Icons.star, size: 10, color: accent),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: count / 42,
                minHeight: 3.5,
                backgroundColor: const Color(0xffdddddd),
                valueColor: const AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewFilter(
      String label, {
        bool selected = false,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : const Color(0xffd9d9d9),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              const Icon(Icons.check, color: Colors.white, size: 11),
              const SizedBox(width: 2),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontSize: 8.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // PHOTOS TAB
  // =========================

  Widget _buildPhotoTab() {
    final photos = _getPlacePhotoUrls();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 8, 2, 6),
            child: Text(
              'All Photos',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),

          if (photos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 42,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No photos yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            MasonryGridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return _photoTabImage(photos[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _photoTabImage(String photoUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenPhotoViewer(photoUrl: photoUrl),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          photoUrl,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          errorBuilder: (_, __, ___) {
            return _imagePlaceholder(radius: 8, iconSize: 30);
          },
        ),
      ),
    );
  }

  String? _getReviewProfilePhotoUrl(Map<String, dynamic> review) {
    const possibleKeys = [
      'profilePhotoUrl',
      'profilePictureUrl',
      'profileImageUrl',
      'avatarUrl',
      'profilePhoto',
      'profilePicture',
      'profileImage',
    ];

    for (final key in possibleKeys) {
      final value = review[key]?.toString().trim();

      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  // =========================
  // REVIEW CARD
  // =========================

  Widget _review(
      String name,
      String text, {
        required int reviewId,
        String time = '2 months ago',
        int rating = 5,
        List<dynamic> photos = const [],
        String? profilePhotoUrl,
      }) {
    final reviewProvider = context.read<ReviewProvider>();

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 0, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================
          // PROFILE
          // =========================
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xffffd7cf),
            backgroundImage: profilePhotoUrl != null
                ? NetworkImage(profilePhotoUrl)
                : null,
            child: profilePhotoUrl == null
                ? Text(
              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            )
                : null,
          ),

          const SizedBox(width: 14),

          // =========================
          // REVIEW CONTENT
          // =========================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NAME + TIME + REPORT BUTTON
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '•',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                time,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '★' * rating,
                            style: const TextStyle(
                              color: accent,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xff555555),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 100,
                        maxWidth: 120,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(
                          color: Color(0xffd9d9d9),
                          width: 1,
                        ),
                      ),
                      elevation: 2,
                      onSelected: (value) {
                        if (value == 'report') {
                          AppNavigation.toReportReview(
                            context,
                            reviewId: reviewId,
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'report',
                          height: 30,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Report review',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // REVIEW TEXT + OPTIONAL PHOTO
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: const TextStyle(fontSize: 11, height: 1.35),
                      ),

                      if (photos.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        SizedBox(
                          height: 150,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final photoUrl =
                                  photos[index]['photoUrl']?.toString() ?? '';

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => _FullScreenPhotoViewer(
                                          photoUrl: photoUrl,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    photoUrl,
                                    width: 180,
                                    height: 150,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 180,
                                        height: 150,
                                        color: const Color(0xffe1e1e1),
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            size: 34,
                                            color: Color(0xffa0a0a0),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
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

class _FullScreenPhotoViewer extends StatelessWidget {
  final String photoUrl;

  const _FullScreenPhotoViewer({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen image
          Positioned.fill(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) {
                    return const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 60,
                    );
                  },
                ),
              ),
            ),
          ),

          // Back button
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}