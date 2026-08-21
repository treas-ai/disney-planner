#!/usr/bin/env python3
"""Audit Tokyo Disney wait-profile coverage without inventing facility mappings.

Checks:
1. active mapped attractions that do not have a generated wait profile;
2. time-band sample coverage (using raw history when available, otherwise profile values);
3. mapping targets that do not exist in the master data and unresolved unmatched entries.

The script is read-only. It writes a Markdown report unless --check-only is used.
"""
from __future__ import annotations

import argparse
import csv
import gzip
import json
import re
import subprocess
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/master/master_manifest.json"
MAPPING = ROOT / "assets/master/live_mapping/themeparks_wiki_tokyo.json"
REPORT = ROOT / "docs/current/WAIT_PROFILE_COVERAGE_AUDIT.md"
PARKS = ("tokyo_disneyland", "tokyo_disneysea")
JST = timezone(timedelta(hours=9))
BANDS = (
    ("afterOpening", "開園直後", 0, 660),
    ("beforeLunch", "昼前", 660, 720),
    ("afterLunch", "昼過ぎ", 720, 900),
    ("aroundShows", "ショー前後", 900, 1020),
    ("beforeDinner", "夕食前", 1020, 1080),
    ("afterDinner", "夕食後", 1080, 1200),
    ("beforeClosing", "閉園前", 1200, 24 * 60),
)


def normalize(value: str) -> str:
    value = value.lower().replace("&", "and")
    return re.sub(r"[^a-z0-9]", "", value)


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_master_facilities() -> dict[str, dict]:
    manifest = load_json(MANIFEST)
    facilities: dict[str, dict] = {}
    for relative in manifest.get("facilityFiles", []):
        path = ROOT / relative
        if not path.exists():
            continue
        for item in load_json(path):
            if isinstance(item, dict) and item.get("id"):
                facilities[str(item["id"])] = item
    return facilities


def read_profile(park_id: str) -> dict:
    path = ROOT / "assets/master/wait_profiles" / f"{park_id}.json"
    return load_json(path) if path.exists() else {"items": []}


def band_key(observed_at: datetime) -> str:
    # ThemeParks.wiki timestamps are UTC (Z). Planning bands are Tokyo local time.
    local = observed_at.astimezone(JST) if observed_at.tzinfo else observed_at.replace(tzinfo=JST)
    minute = local.hour * 60 + local.minute
    for key, _, start, end in BANDS:
        if start <= minute < end:
            return key
    return "beforeClosing"


def history_counts(data_root: Path, park_id: str) -> tuple[Counter, dict[str, Counter]]:
    totals: Counter = Counter()
    by_band: dict[str, Counter] = defaultdict(Counter)
    def consume(handle) -> None:
        for row in csv.DictReader(handle):
            facility_id = (row.get("facilityId") or "").strip()
            observed = (row.get("observedAt") or "").strip()
            if not facility_id or not observed:
                continue
            try:
                dt = datetime.fromisoformat(observed.replace("Z", "+00:00"))
            except ValueError:
                continue
            totals[facility_id] += 1
            by_band[facility_id][band_key(dt)] += 1

    root = data_root / "github_history"
    if root.exists():
        for path in root.rglob(f"*_{park_id}.csv"):
            try:
                with path.open("r", encoding="utf-8", newline="") as handle:
                    consume(handle)
            except OSError:
                continue

    archive = data_root / "archive" / "github_history"
    if archive.exists():
        for path in archive.rglob(f"*_{park_id}_waits.csv.gz"):
            try:
                with gzip.open(path, "rt", encoding="utf-8", newline="") as handle:
                    consume(handle)
            except (OSError, EOFError):
                continue
    return totals, by_band


def git_show_text(ref: str, relative: str) -> str | None:
    try:
        result = subprocess.run(
            ["git", "show", f"{ref}:{relative}"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        return result.stdout
    except (OSError, subprocess.CalledProcessError):
        return None


def unmatched_lines(data_root: Path | None, park_id: str, live_ref: str | None) -> list[str]:
    if data_root is not None:
        path = data_root / "unmatched" / f"{park_id}.txt"
        if path.exists():
            return [line for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if live_ref:
        text = git_show_text(live_ref, f"tool/wait_data/unmatched/{park_id}.txt")
        if text is not None:
            return [line for line in text.splitlines() if line.strip()]
    return []


def classify_unmatched(lines: Iterable[str], park_mapping: dict) -> tuple[list[str], list[str], list[str]]:
    aliases = {normalize(k): str(v) for k, v in (park_mapping.get("aliases") or {}).items()}
    source_aliases = {str(k): str(v) for k, v in (park_mapping.get("sourceEntityAliases") or {}).items()}
    ignored = {str(v) for v in (park_mapping.get("ignoredSourceEntityIds") or [])}
    unresolved, resolved, ignored_rows = [], [], []
    for line in lines:
        parts = line.split("\t", 1)
        name = parts[0].strip()
        source_id = parts[1].strip() if len(parts) > 1 else ""
        if source_id in ignored:
            ignored_rows.append(line)
        elif source_id in source_aliases or normalize(name) in aliases:
            resolved.append(line)
        else:
            unresolved.append(line)
    return unresolved, resolved, ignored_rows


def render_report(data_root: Path | None, live_ref: str | None) -> tuple[str, int]:
    facilities = load_master_facilities()
    mapping = load_json(MAPPING)
    lines = [
        "# Wait Profile Coverage Audit",
        "",
        f"Generated: {datetime.now(JST).isoformat(timespec='seconds')}",
        "",
        "This report does not invent facility IDs. Mapping issues are reported for manual verification.",
        "",
    ]
    actionable = 0
    for park_id in PARKS:
        park_mapping = mapping.get(park_id, {})
        aliases = {str(v) for v in (park_mapping.get("aliases") or {}).values()}
        source_aliases = {str(v) for v in (park_mapping.get("sourceEntityAliases") or {}).values()}
        mapped = aliases | source_aliases
        park_facilities = {fid: f for fid, f in facilities.items() if f.get("parkId") == park_id}
        active_attractions = {
            fid: f for fid, f in park_facilities.items()
            if f.get("category") == "attraction" and f.get("status") == "open" and f.get("isOperating", True) is not False
        }
        profile = read_profile(park_id)
        profile_items = {str(item.get("facilityId")): item for item in profile.get("items", []) if item.get("facilityId")}
        invalid_targets = sorted(mapped - set(park_facilities))
        profile_unknown = sorted(set(profile_items) - set(park_facilities))
        missing_profiles = sorted((mapped & set(active_attractions)) - set(profile_items))
        unmapped_active = sorted(set(active_attractions) - mapped)

        totals: Counter = Counter()
        by_band: dict[str, Counter] = defaultdict(Counter)
        if data_root is not None:
            totals, by_band = history_counts(data_root, park_id)

        lines += [f"## {park_id}", ""]
        lines += [
            f"- Active master attractions: {len(active_attractions)}",
            f"- Mapped active attractions: {len(mapped & set(active_attractions))}",
            f"- Generated profiles: {len(profile_items)}",
            f"- Profile source observations: {profile.get('sampleCount', 0)}",
            "",
        ]

        lines += ["### 1. Profile missing facilities", ""]
        if missing_profiles:
            actionable += len(missing_profiles)
            for fid in missing_profiles:
                f = active_attractions[fid]
                obs = totals.get(fid, 0) if totals else None
                suffix = f"; raw observations={obs}" if obs is not None else ""
                lines.append(f"- `{fid}` — {f.get('name', '')}{suffix}")
        else:
            lines.append("- None among currently mapped active attractions.")
        lines.append("")

        lines += ["### 2. Time-band coverage", ""]
        weak = []
        for fid, item in sorted(profile_items.items()):
            if fid not in active_attractions:
                continue
            missing = []
            for key, label, _, _ in BANDS:
                if by_band and fid in by_band:
                    if by_band[fid].get(key, 0) == 0:
                        missing.append(label)
                else:
                    typical = (((item.get("ranges") or {}).get(key) or {}).get("typicalMinutes") or 0)
                    if typical <= 0:
                        missing.append(label)
            if missing:
                weak.append((fid, missing))
        if weak:
            for fid, missing in weak:
                name = active_attractions.get(fid, {}).get("name", "")
                lines.append(f"- `{fid}` — {name}: no usable samples in {', '.join(missing)}")
        else:
            lines.append("- All generated active-attraction profiles cover all seven bands.")
        lines.append("")

        lines += ["### 2b. Low-confidence time bands (<3 samples)", ""]
        low_confidence = []
        if by_band:
            for fid in sorted(profile_items):
                if fid not in active_attractions:
                    continue
                for key, label, _, _ in BANDS:
                    count = by_band[fid].get(key, 0)
                    if 0 < count < 3:
                        low_confidence.append((fid, label, count))
        if low_confidence:
            for fid, label, count in low_confidence:
                name = active_attractions.get(fid, {}).get("name", "")
                lines.append(f"- `{fid}` — {name}: {label} = {count} samples")
        else:
            lines.append("- None in available raw history.")
        lines.append("")

        lines += ["### 3. Facility-ID mapping audit", ""]
        if invalid_targets:
            actionable += len(invalid_targets)
            lines.append("**Mapping targets not found in master data:**")
            lines.extend(f"- `{fid}`" for fid in invalid_targets)
        else:
            lines.append("- All mapping targets exist in master facility data.")
        if profile_unknown:
            actionable += len(profile_unknown)
            lines.append("- Profile IDs missing from master data:")
            lines.extend(f"  - `{fid}`" for fid in profile_unknown)
        if unmapped_active:
            lines.append("- Active master attractions without a ThemeParks.wiki mapping (may be intentional if the source has no standby wait):")
            for fid in unmapped_active:
                lines.append(f"  - `{fid}` — {active_attractions[fid].get('name', '')}")

        raw_unmatched = unmatched_lines(data_root, park_id, live_ref)
        unresolved, resolved, ignored_rows = classify_unmatched(raw_unmatched, park_mapping)
        if unresolved:
            actionable += len(unresolved)
            lines.append("- Currently unresolved unmatched entries:")
            lines.extend(f"  - `{row}`" for row in unresolved)
        else:
            lines.append("- No currently actionable unmatched entries in the available unmatched file.")
        if resolved:
            lines.append(f"- Historical unmatched entries now resolved by current mapping: {len(resolved)}")
        if ignored_rows:
            lines.append(f"- Historical unmatched entries intentionally ignored: {len(ignored_rows)}")
        lines.append("")

    lines += [
        "## Interpretation",
        "",
        "- A 0/0/0 range is treated as unavailable by the scheduling engine and is therefore reported as missing coverage.",
        "- v7.4.8 stores sampleCount per time band; nearest-band fallback requires at least 3 samples. Direct-band observations remain usable even when thin, but the source text exposes the exact band sample count.",
        "- ThemeParks.wiki timestamps are UTC; time-band coverage must be classified after conversion to JST.",
        "- An active master attraction without mapping is not automatically an error; some source entities do not expose a standby wait queue.",
        "",
    ]
    return "\n".join(lines) + "\n", actionable


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-root", type=Path, default=None, help="Wait-data root, e.g. .live-data/tool/wait_data")
    parser.add_argument("--live-ref", default="origin/live-data", help="Git ref used to read unmatched files when data-root is unavailable")
    parser.add_argument("--output", type=Path, default=REPORT)
    parser.add_argument("--check-only", action="store_true", help="Do not write the report")
    args = parser.parse_args()
    text, actionable = render_report(args.data_root, args.live_ref)
    if not args.check_only:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
        print(f"wrote {args.output.relative_to(ROOT) if args.output.is_relative_to(ROOT) else args.output}")
    print(f"actionable mapping/profile issues: {actionable}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
