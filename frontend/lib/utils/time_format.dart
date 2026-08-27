/// Small time-formatting helpers shared by the UI layer.
library;

/// Formats a [DateTime] as a compact relative label, e.g. "just now",
/// "5m ago", "3h ago", "2d ago", or an absolute "12 Jan 2025" fallback for
/// anything older than a week.
String timeAgo(DateTime? time, {DateTime? now}) {
  if (time == null) return '';
  final reference = now ?? DateTime.now();
  final difference = reference.difference(time);
  if (difference.isNegative) return 'just now';

  if (difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${time.day} ${months[time.month - 1]} ${time.year}';
}
