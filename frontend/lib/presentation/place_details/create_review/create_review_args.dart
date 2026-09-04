import 'create_review_ui.dart' show CreateReviewUI, ReviewPlaceType;

/// Navigation payload for routing to [CreateReviewUI] through GoRouter (P6.1).
///
/// Carries the same fields as the widget constructor. The caller keeps the
/// typed `bool` result (true = review persisted) via `context.push<bool>`.
class CreateReviewArgs {
  final int initialRating;
  final String initialReviewText;
  final String? placeId;
  final ReviewPlaceType placeType;
  final String? placeName;
  final bool isEdit;
  final int? reviewId;
  final List<dynamic> initialPhotos;

  const CreateReviewArgs({
    this.initialRating = 0,
    this.initialReviewText = '',
    this.placeId,
    this.placeType = ReviewPlaceType.google,
    this.placeName,
    this.isEdit = false,
    this.reviewId,
    this.initialPhotos = const [],
  });
}
