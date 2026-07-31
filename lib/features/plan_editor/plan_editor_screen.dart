import 'package:flutter/material.dart';

import '../facility/facility_browser_screen.dart';

class PlanEditorScreen extends StatelessWidget {
  const PlanEditorScreen({
    super.key,
    required this.searchController,
    required this.onReviewPlanPressed,
  });

  final TextEditingController searchController;
  final VoidCallback onReviewPlanPressed;

  @override
  Widget build(BuildContext context) {
    return FacilityBrowserScreen(
      searchController: searchController,
      onReviewPlanPressed: onReviewPlanPressed,
    );
  }
}
