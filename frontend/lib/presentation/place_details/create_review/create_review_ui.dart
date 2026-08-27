import 'package:flutter/material.dart';

class CreateReviewUI extends StatefulWidget {
  final int initialRating;
  final String initialReviewText;

  const CreateReviewUI({
    super.key,
    this.initialRating = 0,
    this.initialReviewText = '',
  });

  @override
  State<CreateReviewUI> createState() => _CreateReviewUIState();
}

class _CreateReviewUIState extends State<CreateReviewUI> {
  late int selectedRating;

  final TextEditingController _reviewController =
  TextEditingController();

  @override
  void initState() {
    super.initState();

    selectedRating = widget.initialRating.clamp(0, 5);

    _reviewController.text = widget.initialReviewText;
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
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
                      const Text(
                        'RING Café',
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
                      _buildAddPhotoButton(),
                      const SizedBox(width: 13),
                      ...List.generate(
                        4,
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
                  onPressed: () {
                    // UI ONLY for now.
                    //
                    // Backend/API will be added later.
                    if (selectedRating == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please select a rating first.',
                          ),
                        ),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Review ready to post.',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Post',
                    style: TextStyle(
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

                    // TODO: Connect camera later
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);

                    // TODO: Connect image picker later
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