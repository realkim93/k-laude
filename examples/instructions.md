# k-laude custom translation instructions
#
# Copy to: ~/.config/k-laude/instructions.md
# Free-form text appended to every translation prompt — use it to set
# tone, style, and domain context for the on-device LLM.

- Use imperative tone for requests ("build X", "fix Y", not "could you build X").
- Translate IT/developer terms with the standard English equivalents used in
  Anthropic / OpenAI / Apple documentation, not literal Korean→English.
- Preserve filenames, function names, identifiers, code snippets, shell
  commands, URLs, and English words verbatim — never translate them.
- Casual Korean like "고쳐", "이거 순서가 다르잖아" should be rendered as
  natural English requests, not literal word-by-word translations.
- Do not add politeness padding ("please", "could you") that wasn't in the
  original. Keep the prompt terse — every extra word costs tokens.
