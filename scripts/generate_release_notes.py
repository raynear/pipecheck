#!/usr/bin/env python3
"""
Release Notes Generator — Conventional Commits → fastlane metadata

Parses git log between tags, classifies commits by type (feat/fix/perf),
converts technical commit messages to user-friendly text using a hybrid
strategy (pattern matching → category fallback), translates to multiple
locales, and writes fastlane metadata files for iOS and Android.

Phase A: base locale generation.
Phase B: multi-locale translation (pattern matching + category fallback per locale).

Usage:
    python3 scripts/generate_release_notes.py \
        --prev-tag v1.2.0 \
        --version 1.3.0 \
        --build-number 28 \
        --app-config fastlane/release_notes_config.json
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# 1. Conventional Commits parser
# ---------------------------------------------------------------------------

COMMIT_RE = re.compile(
    r"^(?P<type>feat|fix|perf|chore|ci|test|docs|refactor|improve|style|build)"
    r"(?:\((?P<scope>[^)]+)\))?!?:\s*(?P<description>.+)$"
)

USER_FACING_TYPES = {"feat", "fix", "perf", "improve"}
EXCLUDED_TYPES = {"chore", "ci", "test", "docs", "style", "build", "refactor"}


def parse_commits(raw_log: str) -> list[dict]:
    """Parse raw git log lines into structured commit dicts."""
    commits = []
    for line in raw_log.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        m = COMMIT_RE.match(line)
        if m:
            commits.append({
                "type": m.group("type"),
                "scope": m.group("scope") or "",
                "description": m.group("description").strip(),
            })
    return commits


def filter_user_facing(commits: list[dict]) -> list[dict]:
    """Keep only user-facing commit types (feat, fix, perf, improve)."""
    return [c for c in commits if c["type"] in USER_FACING_TYPES]


# ---------------------------------------------------------------------------
# 2. Hybrid user-friendly transformation (multi-locale)
# ---------------------------------------------------------------------------

# Pattern-matching dictionary per locale.
# Each entry: (commit_type, regex_on_description, template_per_locale)
# {1}..{n} = capture groups from the regex.
# "en" is the base pattern language (matches against English commit messages).

TRANSFORM_PATTERNS: list[tuple[str, str, dict[str, str]]] = [
    # -- feat --
    ("feat", r"add (?:haptic|vibration) feedback", {
        "en": "Added vibration feedback on touch",
        "ja": "タッチ時の振動フィードバックを追加しました",
        "ko": "터치 시 진동 피드백이 추가되었습니다",
        "zh": "新增触摸振动反馈",
    }),
    ("feat", r"add (.+?) (?:mode|feature)", {
        "en": "Added {1} feature",
        "ja": "{1}機能を追加しました",
        "ko": "{1} 기능이 추가되었습니다",
        "zh": "新增{1}功能",
    }),
    ("feat", r"add (.+)", {
        "en": "Added {1}",
        "ja": "{1}を追加しました",
        "ko": "{1}이(가) 추가되었습니다",
        "zh": "新增{1}",
    }),
    ("feat", r"implement (.+)", {
        "en": "Added {1}",
        "ja": "{1}を追加しました",
        "ko": "{1}이(가) 추가되었습니다",
        "zh": "新增{1}",
    }),
    ("feat", r"support (.+)", {
        "en": "Added support for {1}",
        "ja": "{1}に対応しました",
        "ko": "{1} 지원이 추가되었습니다",
        "zh": "新增{1}支持",
    }),
    ("feat", r"introduce (.+)", {
        "en": "Introduced {1}",
        "ja": "{1}を導入しました",
        "ko": "{1}이(가) 도입되었습니다",
        "zh": "引入{1}",
    }),
    ("feat", r"enable (.+)", {
        "en": "Enabled {1}",
        "ja": "{1}を有効にしました",
        "ko": "{1}이(가) 활성화되었습니다",
        "zh": "启用{1}",
    }),

    # -- fix --
    ("fix", r"(?:cache|caching) (?:invalidation|issue) (?:on|during|for) (.+)", {
        "en": "Fixed progress display during {1}",
        "ja": "{1}時の表示を修正しました",
        "ko": "{1} 시 진행 상황 표시가 수정되었습니다",
        "zh": "修复了{1}时的显示问题",
    }),
    ("fix", r"crash (?:on|when|during) (.+)", {
        "en": "Fixed a crash that occurred during {1}",
        "ja": "{1}時のクラッシュを修正しました",
        "ko": "{1} 중 발생하던 충돌이 수정되었습니다",
        "zh": "修复了{1}时的崩溃问题",
    }),
    ("fix", r"(.+?) (?:not (?:working|showing|loading|displaying))", {
        "en": "Fixed {1} display issue",
        "ja": "{1}の表示を修正しました",
        "ko": "{1} 표시 문제가 수정되었습니다",
        "zh": "修复了{1}显示问题",
    }),
    ("fix", r"(.+?) (?:issue|bug|error|problem)", {
        "en": "Fixed {1} issue",
        "ja": "{1}の問題を修正しました",
        "ko": "{1} 문제가 수정되었습니다",
        "zh": "修复了{1}问题",
    }),
    ("fix", r"incorrect (.+)", {
        "en": "Fixed incorrect {1}",
        "ja": "{1}の誤りを修正しました",
        "ko": "잘못된 {1}이(가) 수정되었습니다",
        "zh": "修复了错误的{1}",
    }),
    ("fix", r"wrong (.+)", {
        "en": "Fixed incorrect {1}",
        "ja": "{1}の誤りを修正しました",
        "ko": "잘못된 {1}이(가) 수정되었습니다",
        "zh": "修复了错误的{1}",
    }),
    ("fix", r"missing (.+)", {
        "en": "Fixed missing {1}",
        "ja": "{1}の欠落を修正しました",
        "ko": "누락된 {1}이(가) 수정되었습니다",
        "zh": "修复了缺失的{1}",
    }),

    # -- perf --
    ("perf", r"(?:improve|optimize|speed up) (.+?) (?:loading|rendering|performance)", {
        "en": "Improved {1} performance",
        "ja": "{1}のパフォーマンスを改善しました",
        "ko": "{1} 성능이 개선되었습니다",
        "zh": "优化了{1}性能",
    }),
    ("perf", r"(?:improve|optimize|speed up) (.+)", {
        "en": "Improved {1} performance",
        "ja": "{1}のパフォーマンスを改善しました",
        "ko": "{1} 성능이 개선되었습니다",
        "zh": "优化了{1}性能",
    }),
    ("perf", r"reduce (.+?) (?:time|size|usage)", {
        "en": "Reduced {1}",
        "ja": "{1}を削減しました",
        "ko": "{1}이(가) 줄었습니다",
        "zh": "减少了{1}",
    }),
    ("perf", r"(?:faster|quicker) (.+)", {
        "en": "Faster {1}",
        "ja": "{1}が高速化されました",
        "ko": "{1}이(가) 빨라졌습니다",
        "zh": "加快了{1}",
    }),

    # -- improve --
    ("improve", r"(.+?) (?:ui|ux|design|layout)", {
        "en": "Improved {1} design",
        "ja": "{1}のデザインを改善しました",
        "ko": "{1} 디자인이 개선되었습니다",
        "zh": "优化了{1}设计",
    }),
    ("improve", r"(.+)", {
        "en": "Improved {1}",
        "ja": "{1}を改善しました",
        "ko": "{1}이(가) 개선되었습니다",
        "zh": "优化了{1}",
    }),
]

# Category fallback text per locale (when no pattern matches)
CATEGORY_FALLBACK: dict[str, dict[str, str]] = {
    "feat": {
        "en": "New features added",
        "ja": "新機能を追加しました",
        "ko": "새로운 기능이 추가되었습니다",
        "zh": "新增功能",
    },
    "fix": {
        "en": "Stability improvements",
        "ja": "安定性を改善しました",
        "ko": "안정성이 개선되었습니다",
        "zh": "提升了稳定性",
    },
    "perf": {
        "en": "Performance improvements",
        "ja": "パフォーマンスを改善しました",
        "ko": "성능이 향상되었습니다",
        "zh": "优化了性能",
    },
    "improve": {
        "en": "Various improvements",
        "ja": "各種改善を行いました",
        "ko": "다양한 개선이 이루어졌습니다",
        "zh": "进行了多项优化",
    },
}

# Empty release notes fallback per locale
EMPTY_RELEASE_FALLBACK: dict[str, str] = {
    "en": "Stability and performance improvements.",
    "ja": "安定性とパフォーマンスを改善しました。",
    "ko": "안정성 및 성능을 개선했습니다.",
    "zh": "提升了稳定性和性能。",
}

# Compiled patterns cache
_COMPILED_PATTERNS: list[tuple[str, re.Pattern, dict[str, str]]] | None = None


def _get_compiled_patterns() -> list[tuple[str, re.Pattern, dict[str, str]]]:
    global _COMPILED_PATTERNS
    if _COMPILED_PATTERNS is None:
        _COMPILED_PATTERNS = [
            (ctype, re.compile(pattern, re.IGNORECASE), templates)
            for ctype, pattern, templates in TRANSFORM_PATTERNS
        ]
    return _COMPILED_PATTERNS


def _resolve_locale_key(locale: str) -> str:
    """
    Map a locale identifier to the key used in translation dicts.
    'en-US' → 'en', 'ja' → 'ja', 'ja-JP' → 'ja',
    'ko' → 'ko', 'ko-KR' → 'ko', 'zh-Hans' → 'zh', 'zh-CN' → 'zh'.
    """
    lang = locale.split("-")[0]
    return lang


def transform_to_user_text(commit: dict, locale_key: str = "en") -> tuple[str, bool]:
    """
    Convert a commit to user-friendly text for the given locale.
    Returns (text, matched) where matched=True if pattern matched,
    False if category fallback was used.
    """
    ctype = commit["type"]
    desc = commit["description"]

    for pat_type, pattern, templates in _get_compiled_patterns():
        if pat_type != ctype:
            continue
        m = pattern.search(desc)
        if m:
            groups = m.groups()
            # Pick template for the requested locale, fall back to "en"
            template = templates.get(locale_key, templates.get("en", ""))
            text = template
            for i, g in enumerate(groups, 1):
                text = text.replace(f"{{{i}}}", g)
            return (text, True)

    # Fallback: use category default text for this locale
    fallback_dict = CATEGORY_FALLBACK.get(ctype, {})
    fallback_text = fallback_dict.get(locale_key, fallback_dict.get("en", desc))
    return (fallback_text, False)


# ---------------------------------------------------------------------------
# 3. Release notes formatter (multi-locale)
# ---------------------------------------------------------------------------

def build_release_notes(
    commits: list[dict],
    config: dict,
    locale_key: str,
    max_length: int = 500,
) -> tuple[str, list[dict]]:
    """
    Build release notes text from user-facing commits for a specific locale.
    Returns (notes_text, unmatched_commits).
    """
    categories = config.get("categories", {})

    # Determine category labels for the locale
    cat_labels = {}
    for cat_type, labels in categories.items():
        cat_labels[cat_type] = labels.get(locale_key, labels.get("en", cat_type.capitalize()))

    # Group commits by type
    grouped: dict[str, list[str]] = {}
    unmatched: list[dict] = []

    for commit in commits:
        text, matched = transform_to_user_text(commit, locale_key)
        ctype = commit["type"]
        # Map 'improve' to 'perf' for category grouping
        group_key = "perf" if ctype == "improve" else ctype
        if group_key not in grouped:
            grouped[group_key] = []
        grouped[group_key].append(text)
        if not matched:
            unmatched.append(commit)

    # Handle empty commits
    if not grouped:
        empty_text = EMPTY_RELEASE_FALLBACK.get(locale_key, EMPTY_RELEASE_FALLBACK["en"])
        return (empty_text, [])

    # Build text
    sections: list[str] = []
    category_order = ["feat", "fix", "perf"]

    for cat in category_order:
        items = grouped.get(cat, [])
        if not items:
            continue
        label = cat_labels.get(cat, cat.capitalize())
        # Deduplicate identical entries
        seen = set()
        unique_items = []
        for item in items:
            if item not in seen:
                seen.add(item)
                unique_items.append(item)
        bullet_lines = [f"- {item}" for item in unique_items]
        sections.append(f"{label}\n" + "\n".join(bullet_lines))

    notes = "\n\n".join(sections)

    # Enforce max_length
    if len(notes) > max_length:
        notes = _truncate_notes(notes, max_length, grouped, cat_labels, category_order)

    return (notes, unmatched)


def _truncate_notes(
    notes: str,
    max_length: int,
    grouped: dict[str, list[str]],
    cat_labels: dict[str, str],
    category_order: list[str],
) -> str:
    """Truncate notes to max_length, keeping most recent items first."""
    total_extra = 0
    for cat in category_order:
        total_extra += max(0, len(grouped.get(cat, [])) - 1)

    # Progressively remove items from the end
    while len(notes) > max_length and total_extra > 0:
        for cat in reversed(category_order):
            items = grouped.get(cat, [])
            if len(items) > 1:
                removed_count = len(items) - 1
                grouped[cat] = items[:1]
                total_extra -= removed_count
                break

        # Rebuild
        sections = []
        for cat in category_order:
            items = grouped.get(cat, [])
            if not items:
                continue
            label = cat_labels.get(cat, cat.capitalize())
            bullet_lines = [f"- {item}" for item in items]
            sections.append(f"{label}\n" + "\n".join(bullet_lines))
        notes = "\n\n".join(sections)

    if len(notes) > max_length:
        notes = notes[: max_length - 3] + "..."

    return notes


# ---------------------------------------------------------------------------
# 4. Locale mapping helpers
# ---------------------------------------------------------------------------

# iOS locale → Android locale mapping
IOS_TO_ANDROID_LOCALE: dict[str, str] = {
    "en-US": "en-US",
    "ja": "ja-JP",
    "ko": "ko-KR",
    "zh-Hans": "zh-CN",
}


def _find_matching_locale(target_locale: str, locale_list: list[str]) -> str | None:
    """Find the locale in locale_list that matches target_locale."""
    # Exact match
    if target_locale in locale_list:
        return target_locale

    # Language-only match (e.g., "ja" matches "ja-JP")
    lang = target_locale.split("-")[0]
    for loc in locale_list:
        if loc == lang or loc.startswith(f"{lang}-"):
            return loc

    return None


def _get_all_locale_keys(config: dict) -> list[str]:
    """
    Collect all unique locale keys from config, deduped.
    Returns keys like 'en', 'ja', 'ko', 'zh'.
    """
    seen = set()
    keys = []
    locales_config = config.get("locales", {})
    for platform_locales in locales_config.values():
        for loc in platform_locales:
            k = _resolve_locale_key(loc)
            if k not in seen:
                seen.add(k)
                keys.append(k)
    return keys


# ---------------------------------------------------------------------------
# 5. Fastlane file writer (multi-locale)
# ---------------------------------------------------------------------------

def write_fastlane_files(
    notes_by_locale: dict[str, str],
    config: dict,
    build_number: str,
) -> list[str]:
    """
    Write release notes to fastlane metadata files for all locales.
    Returns list of written file paths.
    """
    written_files: list[str] = []
    locales_config = config.get("locales", {})
    ios_locales = locales_config.get("ios", [])
    android_locales = locales_config.get("android", [])
    # 경로 계약 (P0-8): 메타데이터 SSOT는 <root>/metadata (fastlane repo 분리 이후)
    base_dir = Path("metadata")

    for locale_key, notes_text in notes_by_locale.items():
        # Find matching iOS locale dir
        ios_loc = _find_matching_locale_for_key(locale_key, ios_locales)
        if ios_loc:
            ios_path = base_dir / "ios" / ios_loc / "release_notes.txt"
            _write_file(ios_path, notes_text)
            written_files.append(str(ios_path))

        # Find matching Android locale dir
        android_loc = _find_matching_locale_for_key(locale_key, android_locales)
        if android_loc:
            android_path = base_dir / "android" / android_loc / "changelogs" / f"{build_number}.txt"
            _write_file(android_path, notes_text)
            written_files.append(str(android_path))

    return written_files


def _find_matching_locale_for_key(locale_key: str, locale_list: list[str]) -> str | None:
    """Find the locale dir name in locale_list for a given locale key (e.g., 'ja' → 'ja' or 'ja-JP')."""
    for loc in locale_list:
        if _resolve_locale_key(loc) == locale_key:
            return loc
    return None


def _write_file(path: Path, content: str) -> None:
    """Write content to file, creating directories if needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip("\n") + "\n", encoding="utf-8")


# ---------------------------------------------------------------------------
# 6. Git helpers
# ---------------------------------------------------------------------------

def get_git_log(prev_tag: str | None) -> str:
    """Get git log between prev_tag and HEAD."""
    if prev_tag:
        cmd = ["git", "log", f"{prev_tag}..HEAD", "--no-merges", "--pretty=format:%s"]
    else:
        cmd = ["git", "log", "--no-merges", "--pretty=format:%s"]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return result.stdout


# ---------------------------------------------------------------------------
# 7. Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Generate release notes from git commits")
    parser.add_argument("--prev-tag", default="", help="Previous git tag (empty for first release)")
    parser.add_argument("--version", required=True, help="Current version string")
    parser.add_argument("--build-number", required=True, help="Build number for Android changelog filename")
    parser.add_argument("--app-config", required=True, help="Path to release_notes_config.json")
    args = parser.parse_args()

    # Load config
    config_path = Path(args.app_config)
    if not config_path.exists():
        print(f"Error: config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)

    with open(config_path, encoding="utf-8") as f:
        config = json.load(f)

    max_length = config.get("max_length", 500)
    base_locale = config.get("base_locale", "en-US")
    base_locale_key = _resolve_locale_key(base_locale)

    # Get git log
    prev_tag = args.prev_tag if args.prev_tag else None
    raw_log = get_git_log(prev_tag)

    if not raw_log.strip():
        print("No commits found between tags.")

    # Parse and filter
    commits = parse_commits(raw_log)
    user_facing = filter_user_facing(commits)

    # Collect all locale keys to generate
    all_locale_keys = _get_all_locale_keys(config)

    # Build notes for each locale
    notes_by_locale: dict[str, str] = {}
    unmatched: list[dict] = []

    for locale_key in all_locale_keys:
        notes, locale_unmatched = build_release_notes(user_facing, config, locale_key, max_length)
        notes_by_locale[locale_key] = notes
        # Unmatched commits are the same across locales; capture once from base
        if locale_key == base_locale_key:
            unmatched = locale_unmatched

    # Write files for all locales
    written = write_fastlane_files(notes_by_locale, config, args.build_number)

    # Report
    print(f"Version: {args.version}")
    print(f"Total commits: {len(commits)}")
    print(f"User-facing commits: {len(user_facing)}")
    print(f"Pattern-matched: {len(user_facing) - len(unmatched)}")
    print(f"Fallback used: {len(unmatched)}")
    if len(user_facing) > 0:
        coverage = ((len(user_facing) - len(unmatched)) / len(user_facing)) * 100
        print(f"Coverage: {coverage:.1f}%")
    print(f"Locales generated: {', '.join(all_locale_keys)}")
    print(f"Files written: {len(written)}")
    for fp in written:
        print(f"  - {fp}")

    # Report unmatched commits for manual review
    if unmatched:
        print("\n[Manual review needed] Unmatched commits:")
        for c in unmatched:
            print(f"  - {c['type']}: {c['description']}")

    # Write summary as GitHub Actions output (if running in CI)
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as f:
            f.write(f"notes_generated=true\n")
            f.write(f"total_commits={len(commits)}\n")
            f.write(f"user_facing={len(user_facing)}\n")
            f.write(f"unmatched_count={len(unmatched)}\n")
            coverage_val = ((len(user_facing) - len(unmatched)) / len(user_facing) * 100) if user_facing else 0
            f.write(f"coverage={coverage_val:.1f}\n")
            f.write(f"locales={','.join(all_locale_keys)}\n")
            f.write(f"files_written={len(written)}\n")
            # Multi-line output for unmatched list
            if unmatched:
                f.write("unmatched_commits<<EOF\n")
                for c in unmatched:
                    f.write(f"- {c['type']}: {c['description']}\n")
                f.write("EOF\n")


if __name__ == "__main__":
    main()
