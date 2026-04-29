# k-laude

> [!TIP]
> **가장 쉬운 설치 방법: 이 레포의 URL을 Claude에게 알려주시고 설치를 부탁해보세요!**
>
> 아래 프롬프트를 복사하셔서 Claude Code에 그대로 붙여넣기만 하시면 됩니다.
> 나머지 의존성 설치, 컴파일, 심볼릭 링크 생성까지 알아서 처리해드립니다.
>
> ```
> https://github.com/realkim93/k-laude 이 Claude Code 플러그인 설치해줘. README 보고 그대로 따라하면 돼.
> ```

> 한국어 사용자를 위한 Claude Code 토큰 절약 도구입니다.
> 한글 프롬프트를 Apple Intelligence 온디바이스 LLM(`FoundationModels`)으로
> 자동 영문 번역해 Claude Code에 전달합니다. **입력 토큰 약 2.5배 절감**.

```
ko> 인증 모듈 리팩토링 계획 세워줘
  → Plan a refactor of the authentication module.
                              ↓ tmux paste-buffer
> Plan a refactor of the authentication module.
```

## 들어가며

찾아주셔서 감사합니다. 만들게 된 배경을 짧게 공유드립니다.

같은 문장이라도 한국어는 영어 대비 약 **2.59배의 토큰**을 소모한다고 합니다
(Anthropic 모델 토크나이저 기준). 같은 요금제에서 영어 사용자가 10번 쓸 때
한국어 사용자는 4번도 쓰기 어려운 구조입니다.

`k-laude`는 사용자가 **한글로 편하게 입력**해도 Claude Code가 받는 프롬프트는
**영문**이 되도록 중간에서 자동으로 번역해드립니다. 번역은 Apple의 온디바이스
LLM(`FoundationModels`)으로 처리하기 때문에 **외부 API 비용이 없고**,
**네트워크도 필요 없고**, **데이터가 외부로 나가지 않습니다**.

## 사용 방식

두 가지 방식 중 편하신 쪽을 선택하실 수 있습니다.

### 1. `klaude` — tmux 분할 화면 (권장)

새 터미널에서 한 줄이면 됩니다.

```bash
$ klaude
```

```
┌─ ko 입력 (30%) ─────────┐ ┌─ Claude Code TUI (70%) ────────┐
│ ko> 인증 모듈 리팩토링   │ │ Welcome to Claude Code!        │
│   → Refactor auth...    │ │ > Refactor auth module         │
│ ko>                     │ │ Sure, here's the plan...       │
└─────────────────────────┘ └────────────────────────────────┘
```

- 왼쪽 패인에 한글로 입력하시고 Enter를 누르시면 됩니다.
- `FoundationModels`가 영문으로 번역해드립니다.
- 번역된 영문은 `tmux paste-buffer`를 통해 오른쪽 `claude` TUI로 자동 주입됩니다.
- Claude Code 입장에서는 사용자가 영어로 타이핑한 것과 동일하게 인식하므로
  슬래시 커맨드, 멀티라인 입력, 파일 첨부 등 모든 기능이 정상 동작합니다.
- 영문이나 영문 혼용 입력은 번역 없이 그대로 전달됩니다.
- 멀티라인이 필요하실 땐 줄 끝에 ` \` 를 붙이시면 됩니다.
- 종료하실 땐 `Ctrl-D`를 눌러주세요.

### 2. `/ko` — Claude Code 슬래시 커맨드

tmux를 사용하지 않으시는 경우를 위해 슬래시 커맨드도 함께 제공해드립니다.

```
> /ko 인증 모듈 리팩토링 계획 세워줘
```

이 커맨드는 한글 인자를 받아 내부적으로 번역 스크립트를 실행하고, **영문 결과만**
프롬프트로 사용합니다. tmux를 띄우지 않으셔도 토큰 절약 효과를 누리실 수 있습니다.

## 설치

### 사전 요구사항

| 항목 | 비고 |
|---|---|
| macOS | 26.0 이상 (FoundationModels 필요) |
| Apple Silicon | M1 이상 (Apple Intelligence 자격 요건) |
| Apple Intelligence | System Settings에서 활성화 필요 |
| Xcode CLT | `xcode-select --install` (`swiftc` 컴파일에 사용) |
| `tmux` | `brew install tmux` |
| `python3` | macOS 기본 또는 Homebrew |
| `claude` | Claude Code CLI |

### 방법 1. Claude Code 플러그인으로 설치 (권장)

```
/plugin marketplace add realkim93/k-laude
/plugin install k-laude
```

플러그인을 설치하시면 `SessionStart` 훅이 다음을 자동으로 처리해드립니다.

1. `swiftc`로 `translate-bin` 컴파일
2. `~/.local/bin/klaude` 심볼릭 링크 생성
3. `/ko` 슬래시 커맨드 활성화

설치 로그는 `~/.local/state/ko-translator/setup.log`에서 확인하실 수 있습니다.

PATH 설정이 필요하시면 shell rc에 다음 줄을 추가해주시면 됩니다.

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 방법 2. 직접 클론

플러그인 시스템을 쓰지 않으시는 경우엔 직접 클론하셔도 됩니다.

```bash
git clone https://github.com/realkim93/k-laude ~/GitHub/k-laude
cd ~/GitHub/k-laude
bash scripts/setup-deps.sh
```

### 설치 확인

설치가 잘 되었는지 확인하시려면 아래 명령어를 사용해주세요.

```bash
klaude --check        # 설치 레이아웃 진단 (tmux/claude 띄우지 않음)
bash scripts/test-smoke.sh   # 9개 회귀 테스트 일괄 실행
```

직접 번역기만 시험해보고 싶으시다면 다음과 같이 호출하실 수 있습니다.

```bash
echo "안녕하세요, 코드 한 줄만 짜주세요" | ./scripts/translate.sh
# → Hello, please provide one line of code.
```

## 번역 결과 커스터마이징

3B 온디바이스 모델은 도메인 용어와 고유어 처리에 다소 약한 면이 있습니다.
이를 보완하실 수 있도록 두 가지 설정 파일을 지원해드립니다.

### 글로서리 — 단어 매핑

`~/.config/k-laude/glossary.txt`에 `한글=English` 형태로 매핑을 적어두시면,
**LLM 호출 전에** 우선 치환됩니다. 결정적이라 매번 동일한 결과를 보장해드립니다.

```
도커=Docker
쿠버네티스=Kubernetes
리액트=React
임베딩=embedding
```

여러 단어가 겹치는 경우 더 긴 표현이 우선 매칭됩니다
(예: `쿠버네티스 클러스터`가 `클러스터`보다 먼저 잡힙니다).

샘플 글로서리는 `examples/glossary.txt`에 준비해두었습니다.

```bash
mkdir -p ~/.config/k-laude
cp examples/glossary.txt ~/.config/k-laude/glossary.txt
```

#### 프로젝트별 글로서리

회사 서비스명이나 프로젝트 고유 용어처럼 한 곳에서만 쓰는 단어들이 있으시다면,
프로젝트 루트에 `.k-laude/glossary.txt`를 두실 수 있습니다.
현재 작업 디렉토리에서 위로 탐색하며 발견한 첫 파일을 글로벌 글로서리에 머지하고,
충돌 시 프로젝트 글로서리가 우선합니다.

```
프로젝트 루트/
├── .k-laude/
│   └── glossary.txt    # 오로라=Aurora, 쿠리어=Courier 등
└── ...
```

### 커스텀 인스트럭션 — 톤과 스타일

`~/.config/k-laude/instructions.md`에 자유 텍스트로 번역 톤과 스타일을 지시하실 수
있습니다. 이 내용은 LLM 프롬프트에 부착됩니다.

```markdown
- Use imperative tone for requests
- Preserve identifiers and code verbatim
- Do not add politeness padding
```

샘플은 `examples/instructions.md`에 있습니다.

### 효과 비교

```
"도커 컨테이너 안에서 쿠버 파드 디버깅 좀 해줘"
  글로서리 적용 전:  "Debugging Kubernetes Pods in Docker..."  (운 좋게 맞음)
  글로서리 적용 후:  "Debugging Kubernetes Pods inside Docker containers." (보장됨)

"이거 순서가 다르잖아 고쳐"
  인스트럭션 적용 전:  "This order is different, please fix it."
  인스트럭션 적용 후:  "This is different. Fix it."  (imperative + 패딩 제거)
```

### 백틱으로 감싸면 그대로 보존

`` `handleLogin` ``, `` `src/auth.ts` ``, `` `kubectl get pods` `` 처럼 백틱으로 감싼 부분은
LLM이 절대 건드리지 않도록 프롬프트 규칙으로 보장해드립니다. 함수명, 파일 경로,
셸 명령어 등은 백틱으로 감싸 입력하시면 안전합니다.

## 환경 변수

세부 동작을 환경 변수로 조정하실 수 있습니다.

| 변수 | 기본값 | 용도 |
|---|---|---|
| `KLAUDE_RESPONSE_LANG` | `ko` | claude 응답 언어 (`ko` / `en` / `auto`) |
| `KLAUDE_CLAUDE_BIN` | `claude` | claude CLI 경로 |
| `KLAUDE_INPUT_WIDTH` | `30` | 왼쪽 입력 패인 너비 (%) |
| `KLAUDE_BIN_DIR` | `~/.local/bin` | `klaude` 심볼릭 링크 위치 |
| `KLAUDE_GLOSSARY` | `~/.config/k-laude/glossary.txt` | 글로서리 파일 경로 (`/dev/null`로 비활성화 가능) |
| `KLAUDE_INSTRUCTIONS` | `~/.config/k-laude/instructions.md` | 커스텀 인스트럭션 파일 경로 |
| `KLAUDE_DEBUG` | (미설정) | `1` 설정 시 파이프라인 각 단계를 stderr로 출력 |
| `KO_TRANSLATOR_BIN` | `scripts/translate-bin` | Swift 바이너리 경로 |
| `XDG_CONFIG_HOME` | `~/.config` | 설정 디렉토리 부모 (XDG 표준) |

## 한계와 안내 사항

- **macOS 26 + Apple Silicon + Apple Intelligence 활성화가 필수**입니다.
  세 가지 중 하나라도 충족되지 않으시면 한글이 번역되지 않고 그대로 통과됩니다.
- **응답 언어**: 기본은 한글 응답(`ko`)입니다. 출력 토큰까지 줄이고 싶으시면
  `export KLAUDE_RESPONSE_LANG=en`으로 영문 응답을 받으실 수 있습니다.
- **번역 품질**: 도메인 용어나 고유 명사가 많으면 한 번 확인해보시는 것을 권장드립니다.
  왼쪽 패인에 `→ ...` 형태로 번역 결과를 미리 보여드립니다.
- **3B 모델 비결정성**: 같은 입력이라도 결과가 조금씩 달라질 수 있습니다.
  중요한 단어는 글로서리에 등록해두시면 일관성이 보장됩니다.
- **Claude TUI 종료 시**: 오른쪽 패인이 닫혀도 왼쪽 REPL은 별도로 `Ctrl-D`를
  눌러 종료해주셔야 합니다.
- **Linux / Windows는 지원되지 않습니다**: Apple FoundationModels에 의존하기 때문입니다.

## 기여와 피드백

버그 제보, 글로서리 개선 제안, 새로운 워크플로 아이디어 모두 환영합니다.
[Issues](https://github.com/realkim93/k-laude/issues)에 편하게 남겨주세요.

## 라이선스

MIT 라이선스로 배포됩니다. 자유롭게 사용하시고 수정하셔도 됩니다.
