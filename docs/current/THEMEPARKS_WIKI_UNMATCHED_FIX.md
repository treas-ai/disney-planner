# ThemeParks.wiki unmatched fix

## Added mappings
- Westernland Shootin' Gallery
  -> `tdl_westernland_shooting_gallery`
- DisneySea Electric Railway (American Waterfront)
  -> `tds_aw_a_004`
- DisneySea Electric Railway (Port Discovery)
  -> `tds_pd_a_003`

The collector now prefers ThemeParks.wiki source UUID mappings before normalized
name aliases.

## Transit Steamer Line
The current Disney Planner facility master does not contain the following two
ThemeParks.wiki entities, so no fictional internal facility ID is created:

- DisneySea Transit Steamer Line (American Waterfront)
- DisneySea Transit Steamer Line (Lost River Delta)

Their source UUIDs are explicitly placed in `ignoredSourceEntityIds`. This makes
the unmatched report clean without inserting wait observations against a
nonexistent facility. If Transit Steamer Line is added to the facility master
later, remove the ignore entries and add proper sourceEntityAliases.
