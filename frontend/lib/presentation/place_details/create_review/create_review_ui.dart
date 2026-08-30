import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:explore_my/providers/hidden_place/review_provider.dart';

class CreateReviewUI extends StatefulWidget {
  final int initialRating;
  final String initialReviewText;

  // Review target. The same UI supports both Google and system-created places.
  final String? placeId;
  final ReviewPlaceType placeType;
  final String? placeName;

  // Create vs update.
  final bool isEdit;
  final int? reviewId;
  final List<dynamic> initialPhotos;

  const CreateReviewUI({
    super.key,
    this.initialRating = 0,
    this.initialReviewText = '',
    this.placeId,
    this.placeType = ReviewPlaceType.google,
    this.placeName,
    this.isEdit = false,
    this.reviewId,
    this.initialPhotos = const [],
  });

  @override
  State<CreateReviewUI> createState() => _CreateReviewUIState();
}

enum ReviewPlaceType {
  google,
  system,
}

class _CreateReviewUIState extends State<CreateReviewUI> {
  late int selectedRating;
  bool _isPosting = false;

  final TextEditingController _reviewController =
  TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  final List<XFile> _selectedPhotos = [];
  final List<Map<String, dynamic>> _existingPhotos = [];
  final List<int> _removedPhotoIds = [];

  @override
  void initState() {
    super.initState();

    selectedRating = widget.initialRating.clamp(0, 5);

    _reviewController.text = widget.initialReviewText;

    _existingPhotos.addAll(
      widget.initialPhotos.map(
            (photo) => Map<String, dynamic>.from(photo),
      ),
    );

  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _postReview() async {
    if (selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating first.'),
        ),
      );
      return;
    }

    if (widget.placeId == null || widget.placeId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to identify this place.'),
        ),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final reviewProvider = context.read<ReviewProvider>();

      if (widget.isEdit) {
        if (widget.reviewId == null) {
          throw Exception('Review ID is missing.');
        }

        await reviewProvider.updateReview(
          reviewId: widget.reviewId!,
          rating: selectedRating,
          comment: _reviewController.text.trim(),
        );

        for (final photoId in _removedPhotoIds) {
          await reviewProvider.deleteReviewPhoto(
            reviewId: widget.reviewId!,
            reviewPhotoId: photoId,
          );
        }

        if (_selectedPhotos.isNotEmpty) {
          await reviewProvider.uploadReviewPhotos(
            reviewId: widget.reviewId!,
            files: _selectedPhotos
                .map((photo) => File(photo.path))
                .toList(),
          );
        }
      } else {
        final isGooglePlace =
            widget.placeType == ReviewPlaceType.google;

        final response = await reviewProvider.createReview(
          googlePlaceId: isGooglePlace ? widget.placeId : null,
          recommendPlaceId: isGooglePlace ? null : widget.placeId,
          rating: selectedRating,
          comment: _reviewController.text.trim(),
        );

        final reviewId = (response['reviewId'] as num?)?.toInt();

        if (reviewId == null) {
          throw Exception('Failed to get created review ID.');
        }

        if (_selectedPhotos.isNotEmpty) {
          await reviewProvider.uploadReviewPhotos(
            reviewId: reviewId,
            files: _selectedPhotos
                .map((photo) => File(photo.path))
                .toList(),
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'Review updated successfully.'
                : 'Review posted successfully.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post review: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_existingPhotos.length + _selectedPhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload a maximum of 5 photos.'),
        ),
      );
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedPhotos.add(picked);
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  void _removeExistingPhoto(int index) {
    final photo = _existingPhotos[index];

    final photoId =
    (photo['reviewPhotoId'] as num?)?.toInt();

    if (photoId != null) {
      _removedPhotoIds.add(photoId);
    }

    setState(() {
      _existingPhotos.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xffff6547);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // ============================================================
            // MAIN CONTENT
            // ============================================================
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                22,
                8,
                22,
                120,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ======================================================
                  // HEADER
                  // ======================================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.placeName ?? 'RING Café',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff202020),
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.close,
                          size: 30,
                          color: Color(0xff777777),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ======================================================
                  // USER
                  // ======================================================
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 23,
                        backgroundColor: Color(0xffffd7cf),
                        child: Text(
                          'B',
                          style: TextStyle(
                            color: accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(width: 18),

                      const Text(
                        'Boon Boon',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff303030),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ======================================================
                  // RATING STARS
                  // ======================================================
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        5,
                            (index) {
                          final starNumber = index + 1;
                          final isSelected =
                              starNumber <= selectedRating;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedRating = starNumber;
                              });
                            },
                            child: Padding(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 7,
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 46,
                                color: accent,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ======================================================
                  // REVIEW TEXT BOX
                  // ======================================================
                  Container(
                    height: 156,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xfff8f8f8),
                      border: Border.all(
                        color: const Color(0xffdddddd),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: TextField(
                      controller: _reviewController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xff333333),
                      ),
                      decoration: const InputDecoration(
                        hintText:
                        'Share details of your own experience at this place',
                        hintStyle: TextStyle(
                          color: Color(0xffb9b9b9),
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ======================================================
                  // UPLOAD PHOTOS TITLE
                  // ======================================================
                  const Text(
                    'Upload Photos (Max 5)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff333333),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ======================================================
                  // PHOTO BUTTONS
                  // ======================================================
                  Row(
                    children: [
                      if (_existingPhotos.length + _selectedPhotos.length < 5) ...[
                        _buildAddPhotoButton(),
                        const SizedBox(width: 13),
                      ],

                      ...List.generate(
                        _existingPhotos.length,
                            (index) => Padding(
                          padding: const EdgeInsets.only(right: 13),
                          child: _buildExistingPhoto(index),
                        ),
                      ),

                      ...List.generate(
                        _selectedPhotos.length,
                            (index) => Padding(
                          padding: const EdgeInsets.only(right: 13),
                          child: _buildSelectedPhoto(index),
                        ),
                      ),

                      ...List.generate(
                        5 - _existingPhotos.length - _selectedPhotos.length -
                            (_existingPhotos.length + _selectedPhotos.length < 5
                                ? 1
                                : 0),
                            (_) => Padding(
                          padding: const EdgeInsets.only(right: 13),
                          child: _buildPhotoPlaceholder(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ============================================================
            // BOTTOM POST BUTTON
            // ============================================================
            Positioned(
              left: 22,
              right: 22,
              bottom: 0,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isPosting ? null : _postReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isPosting
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    widget.isEdit ? 'Update' : 'Post',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // ADD PHOTO BUTTON
  // ================================================================
  Widget _buildAddPhotoButton() {
    const accent = Color(0xffff6547);

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: accent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () {
          _showAddPhotoPopup();
        },
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 25,
              color: Color(0xff666666),
            ),
            SizedBox(height: 3),
            Text(
              'ADD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xff666666),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPhoto(int index) {
    final photo = _selectedPhotos[index];

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.file(
            File(photo.path),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),

        Positioned(
          top: 3,
          right: 3,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingPhoto(int index) {
    final photo = _existingPhotos[index];

    final photoUrl =
        photo['photoUrl']?.toString() ?? '';

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.network(
            photoUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xffeeeeee),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.broken_image_outlined,
                  size: 22,
                  color: Color(0xffaaaaaa),
                ),
              );
            },
          ),
        ),

        Positioned(
          top: 3,
          right: 3,
          child: GestureDetector(
            onTap: () => _removeExistingPhoto(index),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddPhotoPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Small drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Add Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 16),

                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                  ),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhoto(ImageSource.camera);
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.close,
                  ),
                  title: const Text('Cancel'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // ================================================================
  // EMPTY PHOTO PLACEHOLDER
  // ================================================================
  Widget _buildPhotoPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xffeeeeee),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 22,
          color: Color(0xffdddddd),
        ),
      ),
    );
  }
}