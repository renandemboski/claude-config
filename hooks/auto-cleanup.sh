#!/usr/bin/env bash
# Limpeza automática de artefatos antigos do ~/.claude.
# Disparada pelo hook SessionStart (async). Roda no máximo 1x por dia.
# Nunca toca: projects/ (transcrições ficam com o cleanupPeriodDays nativo,
# memórias são sagradas), agents/, commands/, rules/, hooks/, settings.

C="$HOME/.claude"
stamp="$C/.last-auto-cleanup"

if [ -f "$stamp" ] && [ -n "$(find "$stamp" -mtime -1 2>/dev/null)" ]; then
  exit 0
fi
touch "$stamp"

find "$C/file-history" -type f -mtime +14 -delete 2>/dev/null
find "$C/shell-snapshots" -type f -mtime +7 -delete 2>/dev/null
find "$C/plans" -name '*.md' -mtime +14 -delete 2>/dev/null
find "$C/backups" -name '*.corrupted.*' -mtime +7 -delete 2>/dev/null
find "$C/paste-cache" -type f -mtime +14 -delete 2>/dev/null
find "$C/debug" -type f -mtime +7 -delete 2>/dev/null

exit 0
