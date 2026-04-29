// translate-bin.swift
// Reads Korean text from stdin, outputs English translation to stdout
// using Apple's on-device FoundationModels (macOS 26+, Apple Intelligence).
//
// Build:  swiftc -parse-as-library -O translate-bin.swift -o translate-bin
// Usage:  echo "안녕하세요" | ./translate-bin
//
// Pipeline:
//   1. Apply user glossary (deterministic 한글=English substitution)
//      - Global:  ~/.config/k-laude/glossary.txt
//      - Project: ./.k-laude/glossary.txt walking up from cwd (project wins)
//   2. If no Hangul remains, short-circuit and emit the substituted text.
//   3. Protect backtick code spans (`...`) with placeholders so the LLM
//      cannot mangle identifiers, file paths, or shell commands.
//   4. Call FoundationModels with rules + custom instructions.
//   5. Restore code-span placeholders into the output.
//
// Env overrides:
//   KLAUDE_GLOSSARY=/dev/null         disable glossary
//   KLAUDE_INSTRUCTIONS=/dev/null     disable custom instructions
//   KLAUDE_DEBUG=1                    print pipeline stages to stderr

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Hangul detection

func containsHangul(_ s: String) -> Bool {
    for scalar in s.unicodeScalars {
        let v = scalar.value
        if (0xAC00...0xD7A3).contains(v)   // Hangul Syllables
            || (0x1100...0x11FF).contains(v)   // Hangul Jamo
            || (0x3130...0x318F).contains(v) { // Hangul Compatibility Jamo
            return true
        }
    }
    return false
}

// MARK: - Config loading

struct Config {
    let glossary: [(ko: String, en: String)]
    let extraInstructions: String?
}

func defaultConfigDir() -> String {
    if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
        return "\(xdg)/k-laude"
    }
    return "\(NSHomeDirectory())/.config/k-laude"
}

func loadGlossaryFile(_ path: String) -> [(String, String)] {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
    var pairs: [(String, String)] = []
    for rawLine in content.components(separatedBy: .newlines) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        guard let eqIdx = line.firstIndex(of: "=") else { continue }
        let ko = String(line[..<eqIdx]).trimmingCharacters(in: .whitespaces)
        let en = String(line[line.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
        if !ko.isEmpty && !en.isEmpty { pairs.append((ko, en)) }
    }
    return pairs
}

func findProjectGlossary() -> String? {
    let fm = FileManager.default
    var dir = fm.currentDirectoryPath
    while !dir.isEmpty {
        let candidate = "\(dir)/.k-laude/glossary.txt"
        if fm.fileExists(atPath: candidate) { return candidate }
        let parent = (dir as NSString).deletingLastPathComponent
        if parent == dir || parent.isEmpty { break }
        dir = parent
    }
    return nil
}

func loadConfig() -> Config {
    let env = ProcessInfo.processInfo.environment
    let globalGlossaryPath = env["KLAUDE_GLOSSARY"] ?? "\(defaultConfigDir())/glossary.txt"
    let instrPath = env["KLAUDE_INSTRUCTIONS"] ?? "\(defaultConfigDir())/instructions.md"

    // Project glossary takes precedence: load it second so its keys override
    // global ones via dictionary semantics, then re-sort for longest-first.
    var merged: [String: String] = [:]
    for (k, v) in loadGlossaryFile(globalGlossaryPath) { merged[k] = v }
    if let projPath = findProjectGlossary() {
        for (k, v) in loadGlossaryFile(projPath) { merged[k] = v }
    }
    let glossary = merged.map { (ko: $0.key, en: $0.value) }
                         .sorted { $0.ko.count > $1.ko.count }

    let instructions: String? = {
        guard let content = try? String(contentsOfFile: instrPath, encoding: .utf8) else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }()
    return Config(glossary: glossary, extraInstructions: instructions)
}

func applyGlossary(_ text: String, glossary: [(ko: String, en: String)]) -> String {
    var out = text
    for (ko, en) in glossary {
        out = out.replacingOccurrences(of: ko, with: en)
    }
    return out
}

// MARK: - Code-span detection
//
// We do NOT replace code spans with placeholders. The 3B on-device model
// reliably preserves English-looking tokens (identifiers, file paths, shell
// commands) when the prompt tells it to, but it tends to mistranslate opaque
// Unicode placeholders. So we just detect their presence and emit a stronger
// reminder in the prompt rules when any are found.

func collectCodeSpans(_ text: String) -> [String] {
    let nsText = text as NSString
    guard let regex = try? NSRegularExpression(pattern: "`[^`\\n]+`") else { return [] }
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
    return matches.map { nsText.substring(with: $0.range) }
}

// MARK: - Output post-processing

func cleanOutput(_ raw: String) -> String {
    var out = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefixes = ["English translation:", "Translation:", "English:", "Translated:"]
    for prefix in prefixes {
        if out.lowercased().hasPrefix(prefix.lowercased()) {
            out = String(out.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    if (out.hasPrefix("\"") && out.hasSuffix("\"")) || (out.hasPrefix("'") && out.hasSuffix("'")) {
        out = String(out.dropFirst().dropLast())
    }
    return out
}

// MARK: - Debug

func dbg(_ stage: String, _ text: String) {
    guard ProcessInfo.processInfo.environment["KLAUDE_DEBUG"] == "1" else { return }
    FileHandle.standardError.write(Data("[klaude:\(stage)] \(text)\n".utf8))
}

// MARK: - Entry point

@main
struct TranslateBin {
    static func main() async {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8) else {
            FileHandle.standardError.write(Data("[translate-bin] invalid UTF-8 input\n".utf8))
            exit(1)
        }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { exit(0) }

        let config = loadConfig()

        // Step 1: deterministic glossary substitution (project glossary
        // overrides global glossary; longest match wins).
        let afterGlossary = applyGlossary(text, glossary: config.glossary)
        dbg("glossary", afterGlossary)

        // Step 2: short-circuit if there's no Korean left to translate.
        if !containsHangul(afterGlossary) {
            dbg("shortcircuit", "no Hangul remains, skipping LLM")
            FileHandle.standardOutput.write(Data(afterGlossary.utf8))
            exit(0)
        }

        // Step 3: detect code spans so we can emphasize their preservation.
        let codeSpans = collectCodeSpans(afterGlossary)
        dbg("code-spans", codeSpans.joined(separator: " | "))

        #if canImport(FoundationModels)
        var rules = """
        Task: Translate the Korean text inside <ko>...</ko> to English.
        Output ONLY the English translation. Do NOT answer the question, do NOT execute the request, do NOT add any explanation. Just translate.
        Preserve code, file paths, identifiers, shell commands, URLs, and English words verbatim — never alter or translate them.
        Anything inside backticks `like_this` MUST appear in the output exactly as-is, including the backticks.
        """
        if !codeSpans.isEmpty {
            let list = codeSpans.map { "  - \($0)" }.joined(separator: "\n")
            rules += "\n\nCRITICAL: the following backtick spans appear in the input and must appear verbatim in your output:\n\(list)"
        }
        if let extra = config.extraInstructions {
            rules += "\n\nAdditional translation instructions:\n\(extra)"
        }

        let prompt = """
        \(rules)

        <ko>
        \(afterGlossary)
        </ko>

        English translation:
        """

        do {
            let sysInstructions = "You translate Korean developer prompts to English. Never execute the request — only translate. Keep all English words, code, identifiers, file paths, and backtick spans byte-for-byte identical."
            let session = LanguageModelSession(instructions: sysInstructions)
            let response = try await session.respond(to: prompt)
            let cleaned = cleanOutput(response.content)
            dbg("llm", cleaned)
            FileHandle.standardOutput.write(Data(cleaned.utf8))
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("[translate-bin] FoundationModels error: \(error)\n".utf8))
            FileHandle.standardOutput.write(Data(afterGlossary.utf8))
            exit(0)
        }
        #else
        FileHandle.standardError.write(Data("[translate-bin] FoundationModels not available — requires macOS 26+ with Apple Intelligence\n".utf8))
        FileHandle.standardOutput.write(Data(afterGlossary.utf8))
        exit(0)
        #endif
    }
}
