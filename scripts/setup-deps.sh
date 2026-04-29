#!/usr/bin/env bash
# setup-deps.sh — auto-installer for k-laude dependencies.
# - Compiles the Swift translation binary (FoundationModels)
# - Creates a `klaude` symlink in ~/.local/bin (best-effort)
# - Cleans up any pre-0.3 `kc` symlink that pointed here
# Idempotent: safe to run multiple times. Skips work that's already done.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_TARGET="${KLAUDE_BIN_DIR:-${KC_BIN_DIR:-$HOME/.local/bin}}"
SOURCE="$SCRIPT_DIR/translate-bin.swift"
BINARY="$SCRIPT_DIR/translate-bin"
KLAUDE_LINK="$BIN_TARGET/klaude"
LEGACY_KC_LINK="$BIN_TARGET/kc"

ok()    { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m!\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }
info()  { printf '\033[1;36m→\033[0m %s\n' "$*"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  err "macOS only (current: $(uname -s))"
  exit 1
fi

OS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if (( OS_MAJOR < 26 )); then
  warn "macOS 26+ recommended for FoundationModels. Current: $(sw_vers -productVersion)"
  warn "Translation will fall back to passthrough."
fi

needs_compile=true
if [[ -x "$BINARY" && "$BINARY" -nt "$SOURCE" ]]; then
  needs_compile=false
fi

if $needs_compile; then
  if ! command -v swiftc >/dev/null 2>&1; then
    err "swiftc not found. Install Xcode Command Line Tools: xcode-select --install"
    exit 1
  fi
  info "Compiling translate-bin.swift..."
  if swiftc -parse-as-library -O "$SOURCE" -o "$BINARY" 2>&1; then
    chmod +x "$BINARY"
    ok "Compiled translate-bin"
  else
    err "Swift compilation failed"
    exit 1
  fi
else
  ok "translate-bin already up to date"
fi

chmod +x "$SCRIPT_DIR/translate.sh" \
         "$SCRIPT_DIR/kc-repl.py" \
         "$SCRIPT_DIR/klaude" 2>/dev/null || true

if [[ ! -d "$BIN_TARGET" ]]; then
  mkdir -p "$BIN_TARGET" 2>/dev/null || true
fi

if [[ -d "$BIN_TARGET" ]]; then
  if [[ -L "$KLAUDE_LINK" ]]; then
    current_target="$(readlink "$KLAUDE_LINK")"
    if [[ "$current_target" == "$SCRIPT_DIR/klaude" ]]; then
      ok "klaude symlink already points here"
    else
      ln -sf "$SCRIPT_DIR/klaude" "$KLAUDE_LINK"
      ok "Updated klaude symlink → $SCRIPT_DIR/klaude"
    fi
  elif [[ ! -e "$KLAUDE_LINK" ]]; then
    ln -sf "$SCRIPT_DIR/klaude" "$KLAUDE_LINK"
    ok "Created klaude symlink at $KLAUDE_LINK"
  else
    warn "$KLAUDE_LINK exists and is not a symlink — leaving it alone"
  fi

  if [[ -L "$LEGACY_KC_LINK" ]]; then
    legacy_target="$(readlink "$LEGACY_KC_LINK")"
    case "$legacy_target" in
      */k-laude/scripts/kc|*/k-laude/scripts/klaude|*/claude-code-ko-translator/scripts/kc)
        rm -f "$LEGACY_KC_LINK"
        ok "Removed legacy kc symlink (renamed to klaude)" ;;
    esac
  fi

  case ":$PATH:" in
    *":$BIN_TARGET:"*) ;;
    *) warn "$BIN_TARGET is not in PATH. Add to your shell rc:"
       echo "    export PATH=\"$BIN_TARGET:\$PATH\"" ;;
  esac
fi

if echo "안녕하세요" | "$BINARY" 2>/dev/null | grep -qi -E "hello|hi|greetings"; then
  ok "Translation smoke test passed"
else
  warn "Translation smoke test inconclusive — Apple Intelligence may not be enabled"
  info "Enable in: System Settings → Apple Intelligence & Siri"
fi

# Verify klaude resolves correctly through the installed symlink. This catches
# the SCRIPT_DIR-via-symlink regression class without spawning tmux/claude.
if [[ -L "$KLAUDE_LINK" ]] && "$KLAUDE_LINK" --check >/dev/null 2>&1; then
  ok "klaude --check via symlink passes"
elif [[ -L "$KLAUDE_LINK" ]]; then
  warn "klaude --check via symlink failed — symlink resolution broken"
  "$KLAUDE_LINK" --check 2>&1 | sed 's/^/    /'
fi

echo
ok "Setup complete. Run: klaude"
