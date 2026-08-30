import 'package:flutter/material.dart';
import 'create_review/create_review_ui.dart';
import 'report_review/report_review_ui.dart';
import 'community_verification/community_verification_ui.dart';
import '../hidden_place_discovery/hidden_place_discovery_ui.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../providers/hidden_place/review_provider.dart';


enum PlaceReviewTargetType {
  google,
  system,
}

class PlaceDetailUI extends StatefulWidget {
  final PlaceData place;
  final VoidCallback? onClose;
  final PlaceReviewTargetType reviewTargetType;

  const PlaceDetailUI({
    super.key,
    required this.place,
    this.onClose,
    this.reviewTargetType = PlaceReviewTargetType.google,
  });

  @override
  State<PlaceDetailUI> createState() => _PlaceDetailUIState();
}

class _PlaceDetailUIState extends State<PlaceDetailUI> {
  static const Color accent = Color(0xFFFF6242);

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
  Map<String, dynamic>? _myReview;

  List<dynamic> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();

    _loadMyReview();
    _loadReviews();
  }

  // Shows the compact title bar only after the original place
  // header has completely scrolled out of the visible sheet.
  bool _showStickyHeader = false;

  String _selectedFilter = 'Most Relevant';

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

  Future<void> _loadMyReview() async {
    try {
      final reviewProvider = context.read<ReviewProvider>();

      final review = await reviewProvider.getMyReview(
        googlePlaceId:
        widget.reviewTargetType == PlaceReviewTargetType.google
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
        googlePlaceId:
        widget.reviewTargetType == PlaceReviewTargetType.google
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
      builder: (
          BuildContext context,
          ScrollController scrollController,
          ) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
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
                    final headerTop =
                        headerBox.localToGlobal(Offset.zero).dy;
                    final headerBottom =
                        headerTop + headerBox.size.height;
                    final scrollTop =
                        scrollBox.localToGlobal(Offset.zero).dy;

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
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
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
                        onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
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
          child: Container(
            height: 1,
            color: const Color(0xFFD9D9D9),
          ),
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
                      widget.place.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '★★★★★',
                      style: TextStyle(
                        color: accent,
                        fontSize: 17,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '(${widget.place.ratingCount} reviews)',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.directions_car_outlined,
                      size: 15,
                      color: Colors.grey.shade800,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '4 minute(TODO)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _businessStatusText(widget.place.businessStatus),
                  style: TextStyle(
                    color: widget.place.businessStatus.toUpperCase() == 'OPERATIONAL'
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
            icon: const Icon(
              Icons.close,
              size: 27,
              color: Color(0xff333333),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // ACTION BUTTONS
  // =========================

  Widget _buildActions() {
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
          _actionButton(Icons.favorite_border, 'Save'),
          const SizedBox(width: 6),
          _actionButton(Icons.share_outlined, 'Share'),
          const SizedBox(width: 6),
          _actionButton(Icons.verified_outlined, 'Verified'),
        ],
      ),
    );
  }

  Widget _actionButton(
      IconData icon,
      String text, {
        bool selected = false,
      }) {
    return Expanded(
      child: Material(
        color: selected ? accent : const Color(0xfff4f4f4),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () {
            if (text == 'Verified') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CommunityVerificationUI(
                    placeStatus: CommunityPlaceStatus.verified,
                    userVote: CommunityUserVote.none,
                    placeName: 'RING Café',
                    recommendedBy: 'Rikki',
                  ),
                ),
              );
              return;
            }

            if (text == 'Unverified') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CommunityVerificationUI(
                    placeStatus: CommunityPlaceStatus.unverified,
                    userVote: CommunityUserVote.none,
                    placeName: 'RING Café',
                    recommendedBy: 'Rikki',
                  ),
                ),
              );
              return;
            }

            if (text == 'Reported') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CommunityVerificationUI(
                    placeStatus: CommunityPlaceStatus.unverified,
                    userVote: CommunityUserVote.report,
                    placeName: 'RING Café',
                    recommendedBy: 'Rikki',
                  ),
                ),
              );
              return;
            }

            if (text == 'Voted') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CommunityVerificationUI(
                    placeStatus: CommunityPlaceStatus.unverified,
                    userVote: CommunityUserVote.verify,
                    placeName: 'RING Café',
                    recommendedBy: 'Rikki',
                  ),
                ),
              );
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$text selected'),
              ),
            );
          },
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

  // =========================
  // PHOTOS
  // =========================

  Widget _buildPhotos() {
    // Keep the existing BIG photo exactly the same size (355 x 408-ish).
    // The photos beside it are now arranged like Google Maps:
    // BIG photo on the left + two SMALL photos stacked on the right.
    // Swipe horizontally to move to the next BIG photo/gallery group.
    return SizedBox(
      height: 430,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
        physics: const BouncingScrollPhysics(),
        children: [
          _photoGalleryGroup(),
          const SizedBox(width: 8),
          _photoGalleryGroup(),
        ],
      ),
    );
  }

  Widget _photoGalleryGroup() {
    // IMPORTANT: the BIG image remains width 355, matching the previous UI.
    return SizedBox(
      width: 608, // 355 big + 8 gap + 145 thumbnail column
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 355,
            child: _imagePlaceholder(
              radius: 14,
              iconSize: 48,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 245,
            child: Column(
              children: [
                Expanded(
                  child: _imagePlaceholder(
                    radius: 14,
                    iconSize: 30,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _imagePlaceholder(
                    radius: 14,
                    iconSize: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder({
    required double radius,
    required double iconSize,
  }) {
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
        border: Border(
          bottom: BorderSide(
            color: Color(0xffc8c8c8),
            width: 1,
          ),
        ),
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
      children: [
        _buildOverviewInfoCards(),
        _buildOverviewReviews(),
      ],
    );
  }

  Widget _buildOverviewInfoCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.place.address != null &&
            widget.place.address!.isNotEmpty)
          _infoCard(
            Icons.location_on_outlined,
            widget.place.address!,
          ),

        if (widget.place.phoneNumber != null &&
            widget.place.phoneNumber!.isNotEmpty)
          _infoCard(
            Icons.phone_outlined,
            widget.place.phoneNumber!,
          ),

        if (widget.place.websiteUri != null &&
            widget.place.websiteUri!.isNotEmpty)
          _infoCard(
            Icons.language,
            widget.place.websiteUri!,
          ),
      ],
    );
  }

  Widget _buildOverviewReviews() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 17, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),

          // Rating summary appears before the review cards, like the Figma.
          Row(
            children: [
              const Text(
                '4.2',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                '★',
                style: TextStyle(
                  color: accent,
                  fontSize: 19,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '(67)',
                style: TextStyle(
                  color: Color(0xff555555),
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // Horizontal scrolling review cards.
          SizedBox(
            height: 184,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              children: [
                _overviewReviewCard(
                  name: 'Tomorin',
                  ago: '2 months ago',
                  text:
                  "One of the best cafes I've discovered recently. Beautiful interior, fast service, and perfect for taking photos.",
                ),
                const SizedBox(width: 10),
                _overviewReviewCard(
                  name: 'AnonTokyo',
                  ago: '2 months ago',
                  text:
                  'Great coffee, delicious food, and a nice atmosphere. The only thing that could be improved is the customer service.',
                ),
                const SizedBox(width: 10),
                _overviewReviewCard(
                  name: 'Mina',
                  ago: '3 months ago',
                  text:
                  'Nice place to relax and the drinks were good. Would come back again.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Figma-style button leading to the full Reviews tab/page.
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
                  side: const BorderSide(
                    color: accent,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View All Reviews',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewReviewCard({
    required String name,
    required String ago,
    required String text,
  }) {
    return SizedBox(
      width: 245,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xfffafafa),
          border: Border.all(
            color: const Color(0xffd8d8d8),
          ),
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
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
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
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              '★★★★★',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(
      IconData icon,
      String text,
      ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xfff5f5f5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: const Color(0xff222222),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsPreview() {
    final otherReviews = _reviews.where((review) {
      final reviewMap = review as Map<String, dynamic>;

      if (_myReview == null) {
        return true;
      }

      return reviewMap['reviewId'] != _myReview!['reviewId'];
    }).take(2).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            )
          else
            ...otherReviews.map((review) {
              final reviewMap = review as Map<String, dynamic>;

              final username =
                  reviewMap['username']?.toString() ?? 'Unknown User';

              final rating =
                  (reviewMap['rating'] as num?)?.toInt() ?? 0;

              final comment =
                  reviewMap['comment']?.toString() ?? '';

              final createdAt =
              reviewMap['createdAt']?.toString();

              return _review(
                username,
                comment,
                rating: rating,
                time: _formatReviewTime(createdAt),
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _reviewFilter(
                'Most Relevant',
                selected: _selectedFilter == 'Most Relevant',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'Most Relevant';
                  });
                },
              ),
              const SizedBox(width: 4),

              _reviewFilter(
                'Newest',
                selected: _selectedFilter == 'Newest',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'Newest';
                  });
                },
              ),
              const SizedBox(width: 4),

              _reviewFilter(
                'Highest Rating',
                selected: _selectedFilter == 'Highest Rating',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'Highest Rating';
                  });
                },
              ),
              const SizedBox(width: 4),

              _reviewFilter(
                'Lowest Rating',
                selected: _selectedFilter == 'Lowest Rating',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'Lowest Rating';
                  });
                },
              ),
              const SizedBox(width: 4),

              _reviewFilter(
                'With Photo',
                selected: _selectedFilter == 'With Photo',
                onTap: () {
                  setState(() {
                    _selectedFilter = 'With Photo';
                  });
                },
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
          else if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No reviews yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            ..._reviews
                .where((review) {
              final reviewMap = review as Map<String, dynamic>;

              // Don't show the current user's review again
              // in the "other users" section.
              if (_myReview == null) {
                return true;
              }

              return reviewMap['reviewId'] != _myReview!['reviewId'];
            })
                .map((review) {
              final reviewMap = review as Map<String, dynamic>;

              final username = reviewMap['username']?.toString() ?? 'Unknown User';
              final rating = (reviewMap['rating'] as num?)?.toInt() ?? 0;
              final comment = reviewMap['comment']?.toString() ?? '';

              final createdAt = reviewMap['createdAt']?.toString();

              final photos =
                  (reviewMap['photos'] as List<dynamic>?) ?? [];

              return Column(
                children: [
                  _review(
                    username,
                    comment,
                    rating: rating,
                    time: _formatReviewTime(createdAt),
                    photos: photos,
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
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your review',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xffffd7cf),
                child: Text(
                  (_myReview?['username']?.toString().isNotEmpty ?? false)
                      ? _myReview!['username'].toString()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Row(
                children: List.generate(
                  5,
                      (index) => GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateReviewUI(
                            initialRating: index + 1,
                            placeId: widget.place.placeId,
                            placeName: widget.place.title,
                            placeType: widget.reviewTargetType == PlaceReviewTargetType.system
                                ? ReviewPlaceType.system
                                : ReviewPlaceType.google,
                          ),
                        ),
                      );
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
    final photos =
        (_myReview?['photos'] as List<dynamic>?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(
        left: 8,
        right: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your review',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xffffd7cf),
                child: Text(
                  'B',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                                    _formatReviewTime(_myReview?['createdAt']?.toString()),
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 3),

                              Text(
                                '★' * ((_myReview?['rating'] as num?)?.toInt() ?? 0),
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
                          onSelected: (value) {
                            if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateReviewUI(
                                    initialRating: (_myReview?['rating'] as num?)?.toInt() ?? 0,
                                    initialReviewText: _myReview?['comment']?.toString() ?? '',
                                    placeId: widget.place.placeId,
                                    placeName: widget.place.title,
                                    placeType: widget.reviewTargetType == PlaceReviewTargetType.system
                                        ? ReviewPlaceType.system
                                        : ReviewPlaceType.google,
                                    isEdit: true,
                                    reviewId: _myReview?['reviewId'],
                                  ),
                                ),
                              );
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
                                      style: TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),
                                    actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                                    actions: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () {
                                                Navigator.pop(dialogContext);
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: const Color(0xffe5e5e5),
                                                foregroundColor: const Color(0xff333333),
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(22),
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
                                                final reviewId = _myReview?['reviewId'];

                                                if (reviewId == null) {
                                                  Navigator.pop(dialogContext);

                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Review ID not found.'),
                                                    ),
                                                  );

                                                  return;
                                                }

                                                try {
                                                  await context.read<ReviewProvider>().deleteReview(
                                                    reviewId: (reviewId as num).toInt(),
                                                  );

                                                  if (!mounted) return;

                                                  Navigator.of(context).pop();

                                                  setState(() {
                                                    _myReview = null;
                                                    _hasUserReviewed = false;
                                                  });

                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Review deleted successfully.'),
                                                    ),
                                                  );

                                                  setState(() {
                                                    _myReview = null;
                                                    _hasUserReviewed = false;
                                                  });

                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Review deleted successfully.'),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  if (!mounted) return;

                                                  Navigator.of(context).pop();

                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Failed to delete review: $e'),
                                                    ),
                                                  );
                                                }
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: accent,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(22),
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
                                style: TextStyle(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              height: 30,
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'Delete review',
                                style: TextStyle(
                                  fontSize: 13,
                                ),
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
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                            ),
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
                                      photos[index]['photoUrl']?.toString() ?? '';

                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.network(
                                      photoUrl,
                                      width: 180,
                                      height: 180,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
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
            child: Text(
              '$rating',
              style: const TextStyle(fontSize: 9),
            ),
          ),
          const Icon(
            Icons.star,
            size: 10,
            color: accent,
          ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? accent
                : const Color(0xffd9d9d9),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check,
                color: Colors.white,
                size: 11,
              ),
              const SizedBox(width: 2),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.black,
                fontSize: 9,
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.w400,
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
    return Padding(
      padding: const EdgeInsets.all(14),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (context, index) {
          return _imagePlaceholder(
            radius: 8,
            iconSize: 30,
          );
        },
      ),
    );
  }

  // =========================
  // REVIEW CARD
  // =========================

  Widget _review(
      String name,
      String text, {
        String time = '2 months ago',
        int rating = 5,
        List<dynamic> photos = const [],
      }) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 8,
        right: 0,
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================
          // PROFILE
          // =========================
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xffffd7cf),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReportReviewUI(),
                            ),
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
                            style: TextStyle(
                              fontSize: 13,
                            ),
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
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                        ),
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
