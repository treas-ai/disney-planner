$ErrorActionPreference = "Stop"

$obsolete = @(
    "test\covered_wish_cross_anchor_repack_test.dart"
    "test\covered_wish_rolling_show_anchor_test.dart"
    "test\covered_wish_ten_minute_slot_search_test.dart"
    "test\covered_wish_timing_local_repack_test.dart"
    "test\flexible_meal_time_slot_search_test.dart"
    "test\free_time_wish_backfill_test.dart"
    "test\generation_ui_responsiveness_structure_test.dart"
    "test\minimum_wait_lexicographic_structure_test.dart"
    "test\opening_coverage_and_reason_test.dart"
    "test\optimization_mode_structure_test.dart"
    "test\planner_generation_contract_structure_test.dart"
    "test\remaining_capacity_bundle_structure_test.dart"
    "test\rolling_wait_opportunity_test.dart"
    "test\unified_full_day_optimizer_structure_test.dart"
    "test\wait_spread_opportunity_priority_test.dart"
    "test\wish_coverage_forward_priority_test.dart"
    "test\wish_coverage_single_relocation_test.dart"
)

foreach ($path in $obsolete) {
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "Removed source-structure test: $path"
    }
}

Write-Host "Source-structure test cleanup complete."
Write-Host "Behavioral/unit/widget tests were left in place."
