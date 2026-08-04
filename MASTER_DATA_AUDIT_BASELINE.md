# Master Data Audit Baseline

- Generated: 2026-08-04
- Facilities: 253
- Errors: 0
- Warnings: 11
- Information: 0

## Counts by park
- `tokyo_disneyland`: 167
- `tokyo_disneysea`: 86

## Counts by category
- `attraction`: 67
- `greeting`: 11
- `parade`: 6
- `restaurant`: 95
- `service`: 10
- `shop`: 56
- `show`: 8

## Issue summary
- **WARNING** `missing_character_reference`: 6
- **WARNING** `missing_menu_url`: 1
- **WARNING** `missing_representative_menu`: 4

## Purpose

This baseline records the current master-data quality before TDL/TDS completion work. Run `dart run tool/audit_master_data.dart` to generate the detailed per-row report.
