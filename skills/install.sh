#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES=(config.json team.json SKILL.md CONFIG.md INSTALL.md README.md reference.md)

DESTINATIONS=(
  "$HOME/.claude/skills/work-track"
  "$HOME/.agents/skills/work-track"
)

for DEST in "${DESTINATIONS[@]}"; do
  mkdir -p "$DEST"
  cp "${FILES[@]/#/$SOURCE_DIR/}" "$DEST/"
  echo "Installed to $DEST"
done

echo "Restart Claude Code and Codex so both runtimes load the updated work-track skill."
