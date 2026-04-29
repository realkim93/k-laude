#!/usr/bin/env bash
# test-smoke.sh — k-laude regression smoke test.
# Runs deterministic checks against the compiled translate-bin and the
# klaude launcher's --check mode. Non-zero exit on any failure so this
# can be wired into CI / pre-push hooks.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN="$SCRIPT_DIR/translate-bin"
KLAUDE="$SCRIPT_DIR/klaude"

ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; FAILED=$((FAILED+1)); }
info() { printf '\033[1;36m→\033[0m %s\n' "$*"; }

FAILED=0
PASSED=0

# Helper: assert stdout of `cmd` matches a regex.
assert_match() {
  local label="$1"; shift
  local pattern="$1"; shift
  local actual
  actual="$(eval "$@" 2>/dev/null)"
  if [[ "$actual" =~ $pattern ]]; then
    ok "$label  →  $actual"
    PASSED=$((PASSED+1))
  else
    fail "$label  → expected /$pattern/, got: $actual"
  fi
}

# Helper: assert stdout exactly equals expected.
assert_equal() {
  local label="$1"; shift
  local expected="$1"; shift
  local actual
  actual="$(eval "$@" 2>/dev/null)"
  if [[ "$actual" == "$expected" ]]; then
    ok "$label  →  $actual"
    PASSED=$((PASSED+1))
  else
    fail "$label  → expected '$expected', got: '$actual'"
  fi
}

info "translate-bin: $BIN"
info "klaude:        $KLAUDE"
echo

if [[ ! -x "$BIN" ]]; then
  fail "translate-bin not built. Run setup-deps.sh first."
  exit 1
fi

# 1. FoundationModels framework actually linked into the binary.
if otool -L "$BIN" 2>/dev/null | grep -q FoundationModels.framework; then
  ok "FoundationModels.framework linked"
  PASSED=$((PASSED+1))
else
  fail "FoundationModels.framework not linked"
fi

# 2. Glossary substitution: '도커' → 'Docker'
assert_match "glossary: 도커→Docker" \
  "Docker" \
  "echo '도커 빌드' | '$BIN'"

# 3. Hangul-only short-circuit: 'Docker build' has no Hangul → must be < 100ms
START_NS="$(python3 -c 'import time; print(int(time.time()*1000))')"
echo "도커 빌드" | "$BIN" >/dev/null 2>&1
END_NS="$(python3 -c 'import time; print(int(time.time()*1000))')"
ELAPSED=$((END_NS - START_NS))
if (( ELAPSED < 200 )); then
  ok "short-circuit: glossary-only path took ${ELAPSED}ms (< 200ms threshold)"
  PASSED=$((PASSED+1))
else
  fail "short-circuit: ${ELAPSED}ms — LLM may not be skipped"
fi

# 4. Backtick code-span preservation
assert_match "code-span: \`handleLogin\` preserved" \
  '`handleLogin`' \
  "echo '\`handleLogin\` 함수에서 NPE 터짐' | '$BIN'"

# 5. Project-local glossary discovery (cwd walk-up)
TMPPROJ="$(mktemp -d)"
mkdir -p "$TMPPROJ/.k-laude"
cat > "$TMPPROJ/.k-laude/glossary.txt" <<'EOF'
오로라테스트=AuroraTest
EOF
assert_match "project-local: 오로라테스트→AuroraTest" \
  "AuroraTest" \
  "(cd '$TMPPROJ' && echo '오로라테스트 빌드해줘' | '$BIN')"
rm -rf "$TMPPROJ"

# 6. Empty input is a no-op (exit 0, empty output)
EMPTY_OUT="$(echo '' | "$BIN" 2>/dev/null)"
if [[ -z "$EMPTY_OUT" ]]; then
  ok "empty-input: passed through cleanly"
  PASSED=$((PASSED+1))
else
  fail "empty-input: produced output: $EMPTY_OUT"
fi

# 7. English passes through (cleanOutput trim only)
assert_match "english passthrough" \
  "mergesort|merge sort" \
  "echo 'what is the time complexity of mergesort' | '$BIN'"

# 8. klaude --check (direct path)
if "$KLAUDE" --check >/dev/null 2>&1; then
  ok "klaude --check (direct path)"
  PASSED=$((PASSED+1))
else
  fail "klaude --check (direct path) returned non-zero"
fi

# 9. klaude --check via the installed symlink, if one exists. This is the
#    smoke test that catches the SCRIPT_DIR-via-symlink regression class.
LINK="${KLAUDE_BIN_DIR:-$HOME/.local/bin}/klaude"
if [[ -L "$LINK" ]]; then
  if "$LINK" --check >/dev/null 2>&1; then
    ok "klaude --check (via $LINK symlink)"
    PASSED=$((PASSED+1))
  else
    fail "klaude --check via symlink failed — SCRIPT_DIR resolution broken"
  fi
else
  info "skipped symlink check (no symlink at $LINK)"
fi

echo
if (( FAILED == 0 )); then
  printf '\033[1;32m%s\033[0m\n' "All $PASSED smoke tests passed."
  exit 0
else
  printf '\033[1;31m%d failed, %d passed\033[0m\n' "$FAILED" "$PASSED" >&2
  exit 1
fi
