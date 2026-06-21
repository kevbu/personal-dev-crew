#!/bin/bash
set -e

SKILLS_DIR="$HOME/.claude/skills"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)/skills"

echo "Installing personal-dev-crew skills to $SKILLS_DIR..."

mkdir -p "$SKILLS_DIR"

for skill_dir in "$REPO_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  target="$SKILLS_DIR/$skill_name"

  if [ -d "$target" ]; then
    echo "  skip   $skill_name (already exists — delete manually to reinstall)"
  else
    cp -r "$skill_dir" "$target"
    echo "  copy   $skill_name"
  fi
done

echo ""
echo "Done. Restart Claude Code to pick up new skills."
echo ""
echo "GitHub backlog workflow (built-in, no plugin needed):"
echo "  /product-manager          # prioritize GitHub Issues → _workflow/pm-backlog.md"
echo "  /work-backlog [--limit N] # implement top N issues autonomously"
echo "  /work-backlog --dry-run   # preview selected tickets without executing"
echo ""
echo "Optional: install additional PM skills via Claude Code:"
echo "  /plugin marketplace add deanpeters/Product-Manager-Skills"
echo "  /plugin install prd-development@pm-skills"
echo "  /plugin install user-story@pm-skills"
echo "  /plugin install problem-statement@pm-skills"
echo "  /plugin install prioritization-advisor@pm-skills"
echo "  /plugin install epic-breakdown-advisor@pm-skills"
echo "  /plugin install jobs-to-be-done@pm-skills"
