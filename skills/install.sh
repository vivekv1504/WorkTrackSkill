#!/bin/bash
DEST=~/.claude/skills/work-track
mkdir -p "$DEST"
cp config.json team.json SKILL.md CONFIG.md INSTALL.md README.md reference.md "$DEST/"
echo "Installed to $DEST"
