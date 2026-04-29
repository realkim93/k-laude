#!/usr/bin/env bash
# Translate Korean text to English using Apple's on-device FoundationModels.
# Reads input from stdin or $@, writes English translation to stdout.
# Falls back to printing the original input on any failure (exit 0).

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN="${KO_TRANSLATOR_BIN:-$SCRIPT_DIR/translate-bin}"

if [[ $# -gt 0 ]]; then
  INPUT="$*"
else
  INPUT="$(cat)"
fi

if [[ -z "${INPUT//[[:space:]]/}" ]]; then
  exit 0
fi

if [[ ! -x "$BIN" ]]; then
  printf '%s' "$INPUT"
  echo "[ko-translator] translate-bin not built. Run: ${SCRIPT_DIR}/setup-deps.sh" >&2
  exit 0
fi

OUTPUT="$(printf '%s' "$INPUT" | "$BIN" 2>/dev/null || true)"

if [[ -n "$OUTPUT" ]]; then
  printf '%s' "$OUTPUT"
else
  printf '%s' "$INPUT"
fi
