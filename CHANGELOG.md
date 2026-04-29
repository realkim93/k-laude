# Changelog

All notable changes to **k-laude** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `klaude --check` mode prints the resolved install layout and exits without
  spawning tmux/claude. Used by `setup-deps.sh` and `test-smoke.sh` to catch
  symlink-resolution regressions.
- `scripts/test-smoke.sh` — 9-case regression suite covering FoundationModels
  linkage, glossary substitution, Hangul short-circuit timing, code-span
  preservation, project-local glossary discovery, and symlink invocation.
- `setup-deps.sh` now invokes `klaude --check` through the installed symlink
  as a final post-install validation step.

## [0.3.0] — 2026-04-29

### Added
- **Project-local glossary** at `.k-laude/glossary.txt`, discovered by walking
  up from cwd. Merged on top of the global glossary; project keys override
  global keys.
- **Hangul-only short-circuit** — when glossary substitution leaves no Korean
  behind, the LLM call is skipped entirely. Measured ~57× speedup
  (0.46s → 0.008s) for prompts dominated by glossary terms.
- **Code-span preservation in prompt rules** — backtick spans are listed in
  the prompt as "must appear verbatim", and the system-instructions slot
  reinforces it.
- `KLAUDE_DEBUG=1` env var prints each pipeline stage to stderr.

### Changed
- Glossary merging is dictionary-based (project key wins), then re-sorted
  longest-first so compound phrases beat their substrings.

### Removed
- ⟦KL…⟧ Unicode placeholder protection. The 3B on-device model interpreted
  them as semantic tokens rather than opaque markers, so they were reverted
  in favor of trusting the model's "preserve English/code verbatim" rule.

## [0.2.0] — 2026-04-29

### Added
- **Apple FoundationModels backend** — `translate-bin.swift` calls the
  on-device 3B SLM via `LanguageModelSession` and outputs English to stdout.
  No network, no API key, no per-call cost.
- `~/.config/k-laude/glossary.txt` — `한글=English` pairs applied as
  deterministic pre-substitution before the LLM sees the text.
- `~/.config/k-laude/instructions.md` — free-form text appended to the
  translation prompt for tone/style guidance.
- `examples/glossary.txt` and `examples/instructions.md` — starter configs.
- `SessionStart` hook (`hooks/hooks.json`) auto-compiles the Swift binary
  and creates the `~/.local/bin/klaude` symlink on first plugin session.
- Symlink-aware `SCRIPT_DIR` resolution in the launcher so it works when
  invoked through PATH symlinks.

### Changed
- **Launcher renamed:** `kc` → `klaude`.
- **Env var prefix:** `KC_*` → `KLAUDE_*`. `KC_*` is still honored as a
  fallback for users who started on 0.1.
- Repo renamed to `k-laude`.
- README rewritten around FoundationModels.

### Removed
- macOS Shortcuts dependency. Users no longer need to manually create a
  Translate-Text shortcut in the Shortcuts app.

## [0.1.0] — 2026-04-29

### Added
- Initial release.
- `/ko` slash command — translates a Korean argument and uses the English
  output as the actual prompt body, so the model never sees Korean.
- `kc` tmux launcher — split-pane Korean-input REPL on the left, `claude`
  TUI on the right; submitted lines are translated and injected into the
  TUI via `tmux paste-buffer`.
- macOS Shortcuts-based translation backend (replaced in 0.2.0).
- `KC_RESPONSE_LANG` env var (`ko` / `en` / `auto`) appends a system prompt
  via `--append-system-prompt` to control claude's response language.
