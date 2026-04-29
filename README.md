# k-laude

> 한글 프롬프트를 **Apple Intelligence 온디바이스 LLM**(`FoundationModels`)으로 자동 번역해
> Claude Code 에 영문으로 전달 → 입력 토큰 **약 2.5배 절감**.

```
ko> 인증 모듈 리팩토링 계획 세워줘
  → Plan a refactor of the authentication module.
                              ↓ tmux paste-buffer
> Plan a refactor of the authentication module.
```

## 왜 만들었나

같은 문장이라도 한국어는 영어 대비 약 **2.59배 토큰**을 소모합니다 (Anthropic 모델 토크나이저 기준).
같은 요금제에서 영어 사용자가 10번 쓸 때 한국어 사용자는 4번도 못 쓰는 구조.

`k-laude` 는 사용자가 한글로 입력해도 **Claude 가 받는 프롬프트는 영문**이 되도록 중간에서 자동 번역합니다.
번역은 Apple 의 온디바이스 LLM(`FoundationModels`)으로 수행 — **외부 API 비용 없음, 네트워크 없음, 프라이버시 안전**.

## 두 가지 사용 방식

### 1. `kc` — tmux 분할 (권장, 강제 자동 번역)

```bash
$ kc
```

```
┌─ ko 입력 (30%) ─────────┐ ┌─ Claude Code TUI (70%) ────────┐
│ ko> 인증 모듈 리팩토링   │ │ Welcome to Claude Code!        │
│   → Refactor auth...    │ │ > Refactor auth module         │
│ ko>                     │ │ Sure, here's the plan...       │
└─────────────────────────┘ └────────────────────────────────┘
```

- 왼쪽 패인에 한글 입력 → Enter
- `FoundationModels` 호출 → 영문 번역
- `tmux paste-buffer` 로 오른쪽 `claude` TUI 에 영문만 주입
- claude 입장에선 사용자가 영어로 타이핑한 것과 동일 → 슬래시 커맨드 / 멀티라인 / 파일 첨부 전부 정상 작동
- 영문/혼용 입력은 번역 없이 그대로 전달
- 멀티라인은 줄 끝에 ` \` 추가, 종료는 Ctrl-D

### 2. `/ko` — Claude Code 슬래시 커맨드 (보너스)

```
> /ko 인증 모듈 리팩토링 계획 세워줘
```

- 슬래시 커맨드 body 가 `translate.sh` 를 실행하고 영문 출력만 프롬프트로 사용
- tmux 안 쓰는 환경에서도 토큰 절약

## 설치

### 사전 요구사항

| 항목 | 비고 |
|---|---|
| macOS | **26.0 이상** (FoundationModels 필요) |
| Apple Silicon | M1 이상 (Apple Intelligence 자격) |
| Apple Intelligence | System Settings 에서 활성화 |
| Xcode CLT | `xcode-select --install` (`swiftc` 컴파일용) |
| `tmux` | `brew install tmux` |
| `python3` | 기본 또는 Homebrew |
| `claude` | Claude Code CLI |

### Claude Code 플러그인으로 설치 (권장)

```
/plugin marketplace add realkim93/k-laude
/plugin install k-laude
```

플러그인이 설치되면 `SessionStart` 훅이 자동으로:

1. `swiftc` 로 `translate-bin` 컴파일
2. `~/.local/bin/kc` 심볼릭 링크 생성
3. `/ko` 슬래시 커맨드 활성화

설치 로그: `~/.local/state/ko-translator/setup.log`

PATH 가 안 맞으면 shell rc 에 추가:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 또는 직접 클론

```bash
git clone https://github.com/realkim93/k-laude ~/GitHub/k-laude
cd ~/GitHub/k-laude
bash scripts/setup-deps.sh
```

## 동작 검증

```bash
echo "안녕하세요, 코드 한 줄만 짜주세요" | ./scripts/translate.sh
# → Hello, please provide one line of code.
```

## 환경 변수

| 변수 | 기본값 | 용도 |
|---|---|---|
| `KC_RESPONSE_LANG` | `ko` | claude 응답 언어 (`ko` / `en` / `auto`) |
| `KC_CLAUDE_BIN` | `claude` | claude CLI 경로 |
| `KC_INPUT_WIDTH` | `30` | 왼쪽 입력 패인 너비 (%) |
| `KC_BIN_DIR` | `~/.local/bin` | `kc` 심볼릭 링크 위치 |
| `KO_TRANSLATOR_BIN` | `scripts/translate-bin` | Swift 바이너리 경로 |

## 한계 및 알려진 이슈

- **macOS 26 + Apple Silicon + Apple Intelligence 활성화 필수** — 미충족 시 한글이 그대로 통과됨
- **응답 언어**: 기본 `ko` (한글 응답 → 사용자 가독성 우선). 출력 토큰까지 절약하려면 `export KC_RESPONSE_LANG=en`
- **번역 품질**: 코드/도메인 용어가 많으면 결과를 한 번 확인 권장 (왼쪽 패인에 `→ ...` 로 표시됨)
- **Claude TUI 종료 시**: 오른쪽 패인 닫혀도 왼쪽 REPL 별도 종료 필요 (Ctrl-D)
- **Linux / Windows 미지원**: Apple FoundationModels 의존

## 라이선스

MIT
