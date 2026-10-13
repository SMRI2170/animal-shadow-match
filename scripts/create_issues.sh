#!/usr/bin/env bash
set -euo pipefail
REPO="SMRI2170/animal-shadow-match"
command -v gh >/dev/null || { echo 'GitHub CLI gh is required'; exit 1; }
gh auth status >/dev/null
for file in docs/issues/[0-9][0-9]-task.md; do
  title="$(head -n 1 "$file" | sed 's/^# //')"
  echo "Creating: $title"
  gh issue create --repo "$REPO" --title "$title" --body-file "$file"
done
