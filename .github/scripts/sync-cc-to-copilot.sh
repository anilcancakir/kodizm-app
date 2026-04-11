#!/usr/bin/env bash
#
# Sync Claude Code rules to GitHub Copilot instructions.
# Source: .claude/rules/*.md -> Target: .github/instructions/*.instructions.md
#
# Run from project root: bash .github/scripts/sync-cc-to-copilot.sh

set -euo pipefail

RULES_DIR=".claude/rules"
INSTRUCTIONS_DIR=".github/instructions"

if [ ! -d "$RULES_DIR" ]; then
  echo "No rules directory found at $RULES_DIR"
  exit 1
fi

mkdir -p "$INSTRUCTIONS_DIR"

get_meta() {
  local filename="$1"
  local field="$2"
  case "$filename" in
    flutter)
      case "$field" in
        name) echo "Flutter / Magic Framework" ;;
        description) echo "Flutter and Magic framework conventions for all Dart files" ;;
      esac
      ;;
    views)
      case "$field" in
        name) echo "Views & Widgets (Wind UI + Atomic Design)" ;;
        description) echo "Wind UI widget system, atomic design, view layout patterns" ;;
      esac
      ;;
    models)
      case "$field" in
        name) echo "Magic ORM Models" ;;
        description) echo "Magic ORM model structure, conventions, typed accessors" ;;
      esac
      ;;
    tests)
      case "$field" in
        name) echo "Testing (TDD with Magic Framework)" ;;
        description) echo "TDD flow, test patterns, widget and state testing" ;;
      esac
      ;;
    *)
      case "$field" in
        name) echo "$filename" ;;
        description) echo "Conventions for $filename" ;;
      esac
      ;;
  esac
}

count=0
for rule in "$RULES_DIR"/*.md; do
  [ -f "$rule" ] || continue

  filename=$(basename "$rule" .md)
  target="$INSTRUCTIONS_DIR/${filename}.instructions.md"

  # Extract path: glob from CC frontmatter
  apply_to=$(awk '/^---$/{c++; next} c==1 && /^path:/{gsub(/^path: *"?|"? *$/,"",$0); print}' "$rule")

  # Extract body (everything after second ---)
  body=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$rule")

  name=$(get_meta "$filename" "name")
  description=$(get_meta "$filename" "description")

  cat > "$target" <<EOF
---
name: '$name'
description: '$description'
applyTo: '$apply_to'
---

$body
EOF

  count=$((count + 1))
  echo "Synced: $rule -> $target"
done

echo "Done. $count instruction files generated."
