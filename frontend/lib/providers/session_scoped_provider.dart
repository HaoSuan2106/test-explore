import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'auth_profile/profile_provider.dart';
import 'foot_tracker/favourite_provider.dart';
import 'hidden_place/hidden_place_provider.dart';
import 'post_review/post_provider.dart';

/// Implemented by every provider that caches data belonging to the signed-in
/// user, so logging out (or a session expiring) cannot leave one user's data
/// visible to the next person who signs in on the same device (FR103-14).
abstract class SessionScopedProvider {
  /// Drops everything cached for the current user.
  void clearSessionData();
}

/// Clears the cached data of every session-scoped provider in one call.
///
/// Kept in one place so a newly added provider only has to be listed here
/// once, instead of being forgotten in each logout path.
void clearSessionScopedProviders(BuildContext context) {
  context.read<ProfileProvider>().clearSessionData();
  context.read<FavouriteProvider>().clearSessionData();
  context.read<HiddenPlaceProvider>().clearSessionData();
  context.read<PostProvider>().clearSessionData();
}
