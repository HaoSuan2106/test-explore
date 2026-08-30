import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps a downloaded copy of the signed-in user's avatar on the device.
///
/// Only the *URL* is stored server-side and in [ProfileModel], so without this
/// the avatar is re-fetched over the network on every app launch and shows the
/// placeholder icon whenever the connection is down. This writes the actual
/// bytes to the app's private support directory and remembers which URL they
/// came from, so the picture keeps rendering offline.
///
/// Exactly one avatar is cached — the current user's. [clear] is called on
/// logout so the next account to sign in on this device never inherits it.
class ProfileImageCache {
  ProfileImageCache({Dio? dio}) : _dio = dio ?? Dio();

  /// Plain Dio, not the app's authenticated client: avatars live in a public
  /// Supabase bucket, and sending the session token to a third-party host
  /// would leak it.
  final Dio _dio;

  static const _urlKey = 'cached_profile_avatar_url';
  static const _fileName = 'profile_avatar.img';

  Future<File> _target() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  /// The avatar already on disk, or null if nothing has been cached yet.
  ///
  /// Safe to call before — or entirely without — a network round trip, which
  /// is what makes the picture available on an offline launch.
  Future<File?> load() async {
    try {
      final file = await _target();
      return await file.exists() ? file : null;
    } catch (_) {
      // No writable directory (or no plugin, e.g. under unit tests). The UI
      // falls back to the network URL.
      return null;
    }
  }

  /// Brings the on-disk copy in line with [url], downloading it if the URL is
  /// new or nothing is cached yet. Returns the local file to display, or null
  /// if there is nothing to show.
  ///
  /// A failed download is not an error: whatever is already cached is returned
  /// instead, so a dropped connection never blanks out an avatar the user
  /// could still see a moment ago.
  Future<File?> sync(String? url) async {
    if (url == null || url.isEmpty) {
      await clear();
      return null;
    }

    try {
      final file = await _target();
      final prefs = await SharedPreferences.getInstance();

      if (prefs.getString(_urlKey) == url && await file.exists()) {
        return file;
      }

      return await _download(url, file, prefs) ?? (await file.exists() ? file : null);
    } catch (_) {
      return load();
    }
  }

  Future<File?> _download(String url, File file, SharedPreferences prefs) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;

      // Write to a sibling first and rename over the target, so an interrupted
      // download can never leave a half-written file to be decoded.
      final temp = File('${file.path}.part');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);

      await prefs.setString(_urlKey, url);

      // The path never changes, so Flutter's image cache would keep serving
      // the previous picture after a photo change until it is evicted.
      await FileImage(file).evict();

      return file;
    } catch (_) {
      return null;
    }
  }

  /// Drops the cached picture. Call on logout — the file outlives the session
  /// otherwise, and would be shown to whoever signs in next.
  Future<void> clear() async {
    try {
      final file = await _target();
      if (await file.exists()) {
        await FileImage(file).evict();
        await file.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_urlKey);
    } catch (_) {
      // Best effort — nothing here is worth failing a logout over.
    }
  }
}
