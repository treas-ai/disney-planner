import 'package:flutter/material.dart';

import 'candidate_review_screen.dart';

class PlanEditorScreen extends StatelessWidget {
  const PlanEditorScreen({
    super.key,
    required this.searchController,
    required this.onWishListPressed,
  });

  final TextEditingController searchController;
  final VoidCallback onWishListPressed;

  @override
  Widget build(BuildContext context) {
    return CandidateReviewScreen(
      onWishListPressed: onWishListPressed,
    );
  }
}
