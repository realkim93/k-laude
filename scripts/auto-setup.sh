#!/usr/bin/env bash
# auto-setup.sh — silent self-installer triggered by SessionStart hook.
# Runs once: compiles translate-bin and creates kc symlink. Subsequent
# sessions exit fast via the marker file. Output is suppressed so the
# Claude Code session stays clean; failures land in $MARKER_DIR/setup.log.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
MARKER_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ko-translator"
MARKER="$MARKER_DIR/setup-complete"
LOG="$MARKER_DIR/setup.log"
SOURCE="$SCRIPT_DIR/translate-bin.swift"
BINARY="$SCRIPT_DIR/translate-bin"

mkdir -p "$MARKER_DIR" 2>/dev/null || exit 0

if [[ -f "$MARKER" && -x "$BINARY" && "$BINARY" -nt "$SOURCE" ]]; then
  exit 0
fi

{
  echo "=== ko-translator auto-setup $(date) ==="
  bash "$SCRIPT_DIR/setup-deps.sh"
} >>"$LOG" 2>&1

if [[ -x "$BINARY" ]]; then
  date > "$MARKER"
fi

exit 0
