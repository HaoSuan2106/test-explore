import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../../../providers/hidden_place/review_provider.dart';

class ReportReviewUI extends StatelessWidget {
  const ReportReviewUI({
    super.key,
    required this.reviewId,
  });

  final int reviewId;

  static const Color accent = Color(0xffff6547);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // HEADER
            // =========================
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Report Review',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(
                      Icons.close,
                      size: 25,
                      color: Color(0xff999999),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // =========================
            // DESCRIPTION
            // =========================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why are you reporting this review?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  SizedBox(height: 5),

                  Text(
                    'Help us understand what’s wrong with this review.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xff777777),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // =========================
            // SECTION TITLE
            // =========================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'Reason for reporting',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // =========================
            // REPORT OPTIONS
            // =========================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                children: [
                  _reportOption(
                    context,
                    'Off topic',
                  ),

                  const SizedBox(height: 8),

                  _reportOption(
                    context,
                    'Spam',
                  ),

                  const SizedBox(height: 8),

                  _reportOption(
                    context,
                    'Conflict of interest',
                  ),

                  const SizedBox(height: 8),

                  _reportOption(
                    context,
                    'Profanity',
                  ),

                  const SizedBox(height: 8),

                  _reportOption(
                    context,
                    'Harmful',
                  ),

                  const SizedBox(height: 8),

                  _reportOption(
                    context,
                    'Not helpful',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // REPORT OPTION
  // =========================
  Widget _reportOption(
      BuildContext context,
      String title,
      ) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text(
                'Report this review?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Text(
                'Are you sure you want to report this review as $title?',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
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
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);

                          try {
                            final reviewProvider = context.read<ReviewProvider>();

                            await reviewProvider.reportReview(
                              reviewId: reviewId,
                              reason: title,
                            );

                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Report submitted\n'
                                      'Thank you for helping keep our community safe.',
                                ),
                              ),
                            );

                            await Future.delayed(
                              const Duration(milliseconds: 900),
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } on DioException catch (e) {
                            if (!context.mounted) return;

                            if (e.response?.statusCode == 409) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'You have already reported this review.',
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Failed to report review. Please try again.',
                                  ),
                                ),
                              );
                            }
                          } catch (_) {
                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to report review. Please try again.',
                                ),
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
                          'Report',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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
      },
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
        ),
        decoration: BoxDecoration(
          color: const Color(0xfff3f3f3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xffdddddd),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xff333333),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            const Icon(
              Icons.chevron_right,
              size: 25,
              color: Color(0xff222222),
            ),
          ],
        ),
      ),
    );
  }
}