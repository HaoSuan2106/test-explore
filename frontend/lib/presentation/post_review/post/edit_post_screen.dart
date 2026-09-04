import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_header.dart';
import '../../../../widgets/app_button.dart';
import '../../../../providers/post_review/post_provider.dart';
import '../../../../providers/auth_profile/profile_provider.dart';
import '../../../../widgets/app_feedback.dart';
import '../../../../widgets/content_constraint.dart';
import '../../navigation/app_navigation.dart';
import 'post_image_sizes.dart';

/// Result contract returned to the parent screen when the editor closes.
/// [updated] means the post was saved; [unchanged] is unused today but kept
/// for explicit no-op return symmetry. A cancelled edit pops with no result.
enum PostEditResult {
  updated,
  unchanged,
}

class EditPostScreen extends StatefulWidget {
  final String? postId;
  final String? initialTaggedLocation;
  final String? initialTaggedPlaceId;

  const EditPostScreen({
    super.key,
    this.postId,
    this.initialTaggedLocation,
    this.initialTaggedPlaceId,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _taggedLocation;
  String _taggedPlaceId = '';
  bool _isUploading = false;

  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _photos = [];

  /// Authoritative backend limit: max images per post (PostImageLimits.MaxImages).
  static const int _maxPhotos = 5;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PostProvider>();
    if (widget.postId != null) {
      _initEdit(provider, widget.postId!);
    } else {
      _titleCtrl = TextEditingController(text: provider.draftTitle);
      _descCtrl = TextEditingController(text: provider.draftDescription);
      _taggedLocation = widget.initialTaggedLocation ?? provider.draftLocation;
      _taggedPlaceId = widget.initialTaggedPlaceId ?? provider.draftTaggedPlaceId;
    }
  }

  /// Prefills the edit form from the cached post, or fetches from the API
  /// if the post is not cached (never shows an empty form for edit).
  void _initEdit(PostProvider provider, String postId) {
    final post = provider.getPostById(postId);

    // Synchronous prefill from cache (fast path). When the post is not in
    // the cache the fields start empty and are filled by the async fetch
    // below, so the form is never silently presented as an empty edit.
    _titleCtrl = TextEditingController(text: post?.title ?? '');
    _descCtrl = TextEditingController(text: post?.description ?? '');
    _taggedLocation = post?.location ?? widget.initialTaggedLocation ?? '';
    _taggedPlaceId = widget.initialTaggedPlaceId ?? '';
    _photos.addAll(post?.galleryImages ?? const []);

    if (post != null) return; // prefill complete from cache.

    // Post not cached — fetch from API asynchronously and backfill fields.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final fetched = await provider.fetchPostById(postId);
      if (!mounted) return;
      if (fetched == null) {
        AppFeedback.show(context,
          message: 'Could not load post data. Please try again.',
          isSuccess: false,
        );
        return;
      }
      setState(() {
        _titleCtrl.text = fetched.title;
        _descCtrl.text = fetched.description;
        _taggedLocation = fetched.location;
        _photos
          ..clear()
          ..addAll(fetched.galleryImages);
      });
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// Returns true when creating a new post (not editing) and the user has
  /// entered any content beyond the initial empty state (D4).
  bool _hasDraftInput() {
    if (widget.postId != null) return false; // D4 applies to Create Post only.
    return _titleCtrl.text.trim().isNotEmpty
        || _descCtrl.text.trim().isNotEmpty
        || _photos.isNotEmpty
        || _taggedPlaceId.isNotEmpty;
  }

  /// Shows the D4 discard confirmation dialog. Returns true if the user chose
  /// [Discard]; false if [Keep Editing] was chosen.
  Future<bool> _confirmDiscard() async {
    if (!_hasDraftInput()) return true; // nothing to lose → allow discard.

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _syncDraftToProvider() {
    context.read<PostProvider>().setDraft(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      location: _taggedLocation,
      taggedPlaceId: _taggedPlaceId,
      photos: _photos,
    );
  }

  /// Returns `true` if the title is valid; otherwise shows a toast and
  /// returns `false`. Called before navigating to Preview or saving directly.
  bool _validateTitle() {
    if (_titleCtrl.text.trim().isEmpty) {
      AppFeedback.show(context, message: 'Post title is required.', isSuccess: false);
      return false;
    }
    if (_titleCtrl.text.trim().length > 100) {
      AppFeedback.show(context, message: 'Post title must not exceed 100 characters.', isSuccess: false);
      return false;
    }
    return true;
  }

  /// Pick one or more images from the gallery in a single selection, validate
  /// format/size for each, upload them to the backend, and append the returned
  /// URLs to the local photo list. Every selected image belongs to the SAME
  /// post — the picker is multi-select (pickMultiImage) so the user can choose
  /// several images in one gallery interaction instead of one tap per image.
  Future<void> _pickAndUploadImage() async {
    final provider = context.read<PostProvider>();

    // Enforce the authoritative max (5, REQ501_4) across the whole batch.
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;

    final picked = await _imagePicker.pickMultiImage(
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked.isEmpty) return;

    // Honor the max-5 limit: only take as many as still fit.
    final accepted = picked.take(remaining).toList();
    final skippedCount = picked.length - accepted.length;

    setState(() => _isUploading = true);

    try {
      final uploadedUrls = <String>[];
      for (final image in accepted) {
        final file = File(image.path);

        // Validate file size (max 5 MB, REQ501_4) — per image.
        final bytes = await file.length();
        if (bytes > 5 * 1024 * 1024) {
          if (mounted) {
            AppFeedback.show(context,
              message: '${image.name} exceeds the 5 MB size limit.', isSuccess: false);
          }
          continue;
        }

        // Validate format (JPEG/PNG only, REQ501_4) — per image.
        final ext = image.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png'].contains(ext)) {
          if (mounted) {
            AppFeedback.show(context,
              message: '${image.name}: unsupported image type. Allowed: JPEG, PNG.',
              isSuccess: false);
          }
          continue;
        }

        // The provider routes to the real multipart upload endpoint.
        final url = await provider.uploadPostImage(file);
        if (url.isNotEmpty) uploadedUrls.add(url);
      }

      if (mounted && uploadedUrls.isNotEmpty) {
        setState(() => _photos.addAll(uploadedUrls));
      }
      if (mounted && skippedCount > 0) {
        AppFeedback.show(context,
          message: 'You can add up to $_maxPhotos photos. '
              '$skippedCount ${skippedCount == 1 ? 'image was' : 'images were'} skipped.',
          isSuccess: false);
      }
    } catch (e) {
      if (!mounted) return;
      var message = 'Failed to upload images. Please try again.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] is String) {
          message = data['message'] as String;
        }
      }
      AppFeedback.show(context, message: message, isSuccess: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  /// Guards Back/Cancel navigation with the D4 discard confirmation when the
  /// user has entered content. Discard clears the draft and returns to the
  /// Post Feed; Keep Editing stays on the form.
  Future<void> _handleBack() async {
    final discard = await _confirmDiscard();
    if (!mounted || !discard) return;
    context.read<PostProvider>().clearDraft();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Targeted subscriptions: only the profile object and the loading flag
    // drive this screen's build. A like/save/reaction elsewhere in the app
    // (which notifies PostProvider) must NOT rebuild the whole editor.
    final profile = context.select<ProfileProvider, dynamic>((p) => p.profile);
    final isSaving = context.select<PostProvider, bool>((p) => p.isLoading);

    return PopScope(
      canPop: !_hasDraftInput(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: widget.postId != null ? 'Edit Post' : 'Create Post',
        showBack: true,
        onBack: _handleBack,
      ),
      body: SafeArea(
        child: ContentConstraint(
          maxWidth: 600,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // 1. Display-Only Profile Card
              _buildProfileSection(profile),
              const SizedBox(height: AppSpacing.stackLg),

              // 2. Tagged Attraction
              _buildLabel('Tagged Attraction', isRequired: true),
              const SizedBox(height: AppSpacing.stackSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: AppRadii.roundedDefault,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_taggedLocation, style: AppTypography.bodyMd),
                    ),
                    const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackLg),

              // 3. Post Title
              _buildLabel('Post Title', isRequired: true),
              const SizedBox(height: AppSpacing.stackSm),
              _buildTextInput(controller: _titleCtrl, maxLength: 100),
              const SizedBox(height: AppSpacing.stackLg),

              // 4. Description
              _buildLabel('Description', isRequired: true),
              const SizedBox(height: AppSpacing.stackSm),
              _buildTextInput(controller: _descCtrl, maxLines: 4, maxLength: 2000),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _descCtrl,
                    builder: (context, value, _) => Text(
                      '${value.text.length}/2000',
                      style: AppTypography.labelSm,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.stackLg),

              // 5. Photos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Photos (Max 5)', style: AppTypography.labelLg),
                  Text('${_photos.length}/5', style: AppTypography.labelSm),
                ],
              ),
              const SizedBox(height: AppSpacing.stackSm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ..._photos.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.stackMd),
                      child: _buildPhotoThumbnail(entry.value, entry.key),
                    )),
                    if (_photos.length < 5)
                      InkWell(
                        onTap: _isUploading ? null : _pickAndUploadImage,
                        borderRadius: AppRadii.roundedDefault,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: AppRadii.roundedDefault,
                            border: Border.all(color: AppColors.outlineVariant),
                          ),
                          child: _isUploading
                              ? const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
                                    const SizedBox(height: 2),
                                    Text('Add', style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
                                  ],
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // 6. Action Buttons (Preview & Save Changes)
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Preview',
                      icon: Icons.visibility_outlined,
                      variant: AppButtonVariant.outline,
                      isLoading: isSaving,
                      onPressed: () {
                        if (!_validateTitle()) return;
                        _syncDraftToProvider();
                        AppNavigation.toPreviewChanges(
                          context,
                          postId: widget.postId,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gutterMd),
                  Expanded(
                    child: AppButton(
                      text: 'Save Changes',
                      icon: Icons.check,
                      isLoading: isSaving,
                      onPressed: () async {
                        if (!_validateTitle()) return;
                        _syncDraftToProvider();
                        final provider = context.read<PostProvider>();
                        final postId = await provider.publishDraft(postId: widget.postId);
                        if (!context.mounted) return;
                        if (postId != null) {
                          AppFeedback.show(context,
                            message: widget.postId != null
                                ? 'Post updated successfully.'
                                : 'Post published successfully.',
                            isSuccess: true,
                          );
                          if (widget.postId != null) {
                            // Edit flow: return to Post Details with the
                            // result so the parent can refresh authoritative data.
                            Navigator.of(context).pop(PostEditResult.updated);
                          } else {
                            // Create flow: return to the Feed (root shell).
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        } else {
                          AppFeedback.show(context,
                            message: provider.errorMessage ?? 'Failed to save the post. Please try again.',
                            isSuccess: false,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildProfileSection(dynamic profile) {
    final username = (profile?.username != null && profile!.username.isNotEmpty)
        ? profile.username
        : 'Traveler';
    final avatarUrl = profile?.profilePictureUrl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadii.roundedLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadii.roundedFull,
            child: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? CachedNetworkImage(
              imageUrl: avatarUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              memCacheWidth: PostImageSizes.avatar,
              memCacheHeight: PostImageSizes.avatar,
              errorWidget: (_, _, _) => _buildDefaultAvatar(),
            )
                : _buildDefaultAvatar(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sharing to Travel Community',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFDDE9FF),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Color(0xFF3F51B5), size: 28),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(text, style: AppTypography.labelLg),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  Widget _buildTextInput({required TextEditingController controller, int maxLines = 1, int? maxLength}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadii.roundedDefault,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: AppTypography.bodyMd,
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, counterText: ''),
      ),
    );
  }

  Widget _buildPhotoThumbnail(String url, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: AppRadii.roundedDefault,
          child: CachedNetworkImage(
            imageUrl: url,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            memCacheWidth: PostImageSizes.editThumbnail,
            memCacheHeight: PostImageSizes.editThumbnail,
            errorWidget: (_, _, _) => Container(
              width: 80,
              height: 80,
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.image, color: AppColors.textMuted),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}