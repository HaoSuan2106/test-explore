import 'report_review_ui.dart' show ReportReviewUI;

/// Navigation payload for routing to [ReportReviewUI] through GoRouter (P6.1).
class ReportReviewArgs {
  final int reviewId;

  const ReportReviewArgs({required this.reviewId});
}
