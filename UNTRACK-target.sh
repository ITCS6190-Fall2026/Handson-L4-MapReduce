#!/bin/bash
# One-off migration for the Hands-on L4 course repository.
#
# Usage:
#   1. Clone the course repo and cd into it
#   2. Copy the bundle files over the clone
#   3. bash UNTRACK-target.sh
#
# Safe to re-run: nothing here fails if a step was already done.

set -euo pipefail

if [ ! -d .git ]; then
  echo "Not a git repository. Run this from inside a clone of the course repo." >&2
  exit 1
fi

echo "Working on branch: $(git rev-parse --abbrev-ref HEAD)"

# --- stop tracking things that should not be in the repo -------------------
git rm -r --cached --ignore-unmatch target >/dev/null 2>&1 || true

# --- remove files the migration replaces -----------------------------------
git rm --cached --ignore-unmatch hadoop.env >/dev/null 2>&1 || true
rm -f hadoop.env

git rm --cached --ignore-unmatch "Java and maven Environment setup.pdf" >/dev/null 2>&1 || true
rm -f "Java and maven Environment setup.pdf"

# --- stage the new and changed files ---------------------------------------
for f in .gitignore config docker-compose.yml pom.xml README.md REPORT.md SETUP.md; do
  if [ -f "$f" ]; then
    git add "$f"
  else
    echo "WARNING: $f is missing - did you copy the bundle into this clone?" >&2
  fi
done

echo
echo "About to commit:"
git status --short
echo
read -r -p "Commit and push? [y/N] " reply
case "$reply" in
  [yY]*)
    git commit -m "Migrate cluster to apache/hadoop:3; add SETUP.md; fix build config; stop tracking target/"
    git push
    echo "Done."
    ;;
  *)
    echo "Nothing committed. Your changes are staged; commit them yourself when ready."
    ;;
esac
