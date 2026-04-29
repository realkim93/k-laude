#!/usr/bin/env python3
"""kc-repl: Korean input REPL that injects translated English into a tmux pane.

Reads each line from the user, runs translate.sh if Korean is detected, and
delivers the result to the target tmux pane via load-buffer + paste-buffer +
Enter so it appears to Claude Code's TUI as if the user typed it.
"""

from __future__ import annotations

import os
import readline  # noqa: F401 — enables line editing/history
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
TRANSLATE_SH = SCRIPT_DIR / "translate.sh"

C_RESET = "\033[0m"
C_DIM = "\033[2m"
C_PROMPT = "\033[1;33m"
C_INFO = "\033[1;36m"
C_ERR = "\033[1;31m"


def has_korean(text: str) -> bool:
    for ch in text:
        cp = ord(ch)
        if 0xAC00 <= cp <= 0xD7A3:
            return True
        if 0x1100 <= cp <= 0x11FF:
            return True
        if 0x3130 <= cp <= 0x318F:
            return True
    return False


def translate(text: str) -> str:
    try:
        result = subprocess.run(
            ["bash", str(TRANSLATE_SH)],
            input=text,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except subprocess.TimeoutExpired:
        print(f"{C_ERR}[ko-translator] Timeout — passing through original.{C_RESET}",
              file=sys.stderr)
        return text
    out = result.stdout.strip()
    if not out:
        return text
    return out


def send_to_pane(target: str, text: str) -> None:
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
        f.write(text)
        tmpfile = f.name
    try:
        subprocess.run(["tmux", "load-buffer", tmpfile], check=True)
        subprocess.run(["tmux", "paste-buffer", "-t", target, "-d"], check=True)
        subprocess.run(["tmux", "send-keys", "-t", target, "Enter"], check=True)
    finally:
        os.unlink(tmpfile)


def main() -> int:
    target = os.environ.get("KC_TARGET")
    if len(sys.argv) > 1:
        target = sys.argv[1]
    if not target:
        print("Usage: kc-repl.py <tmux_target>", file=sys.stderr)
        return 2

    print(f"{C_INFO}╭─ ko-translator ─────────────────────────────╮{C_RESET}")
    print(f"{C_INFO}│{C_RESET} 한글 입력  → 자동 영문 번역 후 Claude로 전달")
    print(f"{C_INFO}│{C_RESET} 영문/혼용  → 그대로 전달")
    print(f"{C_INFO}│{C_RESET} 멀티라인  → 줄 끝에 ' \\' 붙이면 다음 줄로 이어짐")
    print(f"{C_INFO}│{C_RESET} 종료      → Ctrl-D")
    print(f"{C_INFO}╰─────────────────────────────────────────────╯{C_RESET}")
    print()

    buffer: list[str] = []
    while True:
        prompt = f"{C_PROMPT}{'..>' if buffer else 'ko>'}{C_RESET} "
        try:
            line = input(prompt)
        except EOFError:
            print()
            return 0
        except KeyboardInterrupt:
            if buffer:
                buffer = []
                print(f"{C_DIM}  (buffer cleared){C_RESET}")
                continue
            print()
            return 0

        if line.endswith(" \\"):
            buffer.append(line[:-2])
            continue

        buffer.append(line)
        full = "\n".join(buffer)
        buffer = []

        if not full.strip():
            continue

        if has_korean(full):
            translated = translate(full)
            print(f"{C_DIM}  → {translated}{C_RESET}")
        else:
            translated = full

        try:
            send_to_pane(target, translated)
        except subprocess.CalledProcessError as exc:
            print(f"{C_ERR}[ko-translator] tmux send failed: {exc}{C_RESET}",
                  file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
