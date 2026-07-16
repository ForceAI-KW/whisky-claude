import Foundation

/// Decodes/encodes text typed with the Arabic-101 keyboard layout switched on
/// while the physical keys pressed correspond to English (QWERTY) letters.
///
/// ## Why this exists
/// The Arabic-101 and US-QWERTY layouts share physical key positions. Typing
/// English words with the Arabic layout active produces Arabic-script
/// "gibberish" that is 1:1 reversible back to the original English, because
/// every Arabic character was produced by pressing an English-labeled key
/// (e.g. `صاثقث شقث صث` = "where are we"). This lets someone type normally
/// while the screen shows nonsense Arabic — a shoulder-surfing privacy
/// trick, NOT real encryption: the map is fixed and public, so it hides
/// content from a glance, not from logs or anyone who knows the trick.
///
/// ## Scope / limitations (documented, not bugs)
/// - Only the unshifted letter row plus a handful of well-established
///   punctuation keys are modeled. Digits and their shifted symbols
///   (`!@#$…`) are identical on both layouts in the common configuration,
///   so they're left untouched rather than duplicated in the table — same
///   for any character with no entry (spaces, Latin text already typed
///   normally, emoji, etc).
/// - Arabic script has no letter case. `encode()` folds uppercase English
///   input to the same key as lowercase, and `decode()` can never recover
///   the original casing. This is inherent, not a bug.
/// - The physical `b` key on a real Arabic-101 keyboard is a dedicated
///   ligature key that types "لا" (lam-alef, two Unicode characters) in one
///   keystroke — distinct from pressing `g` then `h`, which individually
///   type "ل" then "ا" (the same two characters, typed separately).
///   `decode()` greedily reads a "لا" pair as `b`, so encoding "gh" and
///   decoding the result comes back as `b`, not `gh`. That's an inherent
///   ambiguity of the physical keyboard itself, not a flaw in this mapping.
enum StealthDecoder {

    /// Arabic key output -> English letter, one entry per physical key,
    /// grouped by row to make the "same physical position" mapping obvious.
    private static let letterMap: [Character: Character] = [
        // Top row: q w e r t y u i o p
        "ض": "q", "ص": "w", "ث": "e", "ق": "r", "ف": "t",
        "غ": "y", "ع": "u", "ه": "i", "خ": "o", "ح": "p",
        // Home row: a s d f g h j k l
        "ش": "a", "س": "s", "ي": "d", "ب": "f", "ل": "g",
        "ا": "h", "ت": "j", "ن": "k", "م": "l",
        // Bottom row: z x c v n m (b is the "لا" ligature key, handled separately)
        "ئ": "z", "ء": "x", "ؤ": "c", "ر": "v", "ى": "n", "ة": "m",
        // Punctuation keys with well-established Arabic-101 positions
        "ذ": "`", "ج": "[", "د": "]", "ك": ";", "ط": "'",
        "و": ",", "ز": ".", "ظ": "/",
    ]

    /// Reverse of `letterMap`, built once. English letter -> Arabic character.
    private static let reverseLetterMap: [Character: Character] = {
        var m: [Character: Character] = [:]
        for (arabic, english) in letterMap { m[english] = arabic }
        return m
    }()

    /// The dedicated `b` key on the Arabic-101 keyboard types this ligature
    /// (lam + alef) in a single keystroke. See the ambiguity note above.
    private static let lamAlefLigature = "لا"

    /// Arabic-layout gibberish -> English. Reverses `encode`.
    ///
    /// Known example: `decode("صاثقث شقث صث") == "where are we"`.
    static func decode(_ s: String) -> String {
        var result = ""
        result.reserveCapacity(s.count)
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            // Greedily consume the "لا" ligature (the dedicated `b` key)
            // before falling back to per-character lookup.
            if i + 1 < chars.count, chars[i] == "ل", chars[i + 1] == "ا" {
                result.append("b")
                i += 2
                continue
            }
            if let mapped = letterMap[chars[i]] {
                result.append(mapped)
            } else {
                result.append(chars[i])
            }
            i += 1
        }
        return result
    }

    /// English -> Arabic-layout gibberish. Reverses `decode` (modulo the
    /// case + ligature limitations documented on the type).
    static func encode(_ s: String) -> String {
        var result = ""
        result.reserveCapacity(s.count)
        for ch in s {
            let lower = Character(ch.lowercased())
            if lower == "b" {
                result.append(lamAlefLigature)
            } else if let mapped = reverseLetterMap[lower] {
                result.append(mapped)
            } else {
                result.append(ch)
            }
        }
        return result
    }

    /// Cheap heuristic: does `s` look like Arabic-layout stealth typing
    /// rather than genuine Arabic text?
    ///
    /// Since `letterMap` covers essentially the full Arabic alphabet, any
    /// Arabic string — genuine or stealth-gibberish — decodes to ASCII
    /// letters by construction, so "decodes to mostly ASCII" alone can't
    /// discriminate. Instead this checks whether the decoded text reads as
    /// plausible English: a majority (or, for very short input, at least
    /// one) of its whitespace-separated tokens are common English words.
    /// Genuine Arabic essentially never decodes into a run of common
    /// English words by chance. Not perfect — just cheap and simple.
    static func isLikelyStealth(_ s: String) -> Bool {
        let hasArabic = s.unicodeScalars.contains { scalar in
            (0x0600...0x06FF).contains(scalar.value)
        }
        guard hasArabic else { return false }

        let decoded = decode(s).lowercased()
        let words = decoded.split(whereSeparator: { !$0.isLetter }).map(String.init)
        guard !words.isEmpty else { return false }

        let matches = words.filter { Self.commonEnglishWords.contains($0) }.count
        if words.count <= 2 { return matches >= 1 }
        return Double(matches) / Double(words.count) >= 0.5
    }

    /// Small set of very common short English words used by `isLikelyStealth`.
    private static let commonEnglishWords: Set<String> = [
        "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
        "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
        "this", "but", "his", "by", "from", "they", "we", "are", "say", "her", "she",
        "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
        "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
        "when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
        "people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
        "than", "then", "now", "look", "only", "come", "its", "over", "think", "also",
        "back", "after", "use", "two", "how", "our", "work", "first", "well", "way",
        "even", "new", "want", "because", "any", "these", "give", "day", "most", "us",
    ]
}

#if DEBUG
/// Lightweight runtime sanity checks. The project has no test target, so
/// these run once on launch in Debug builds instead of an XCTest suite —
/// see `AppDelegate.applicationDidFinishLaunching`.
enum StealthDecoderSelfCheck {
    static func run() {
        let example = StealthDecoder.decode("صاثقث شقث صث")
        assert(example == "where are we", "StealthDecoder mapping regressed: got \"\(example)\"")

        let roundTripPhrases = [
            "send the invoice", "call me later", "not now", "meet at noon", "bring the box",
        ]
        for phrase in roundTripPhrases {
            let roundTrip = StealthDecoder.decode(StealthDecoder.encode(phrase))
            assert(roundTrip == phrase, "round-trip failed for \"\(phrase)\": got \"\(roundTrip)\"")
        }

        assert(StealthDecoder.isLikelyStealth("صاثقث شقث صث"), "canonical example should read as stealth")
        assert(!StealthDecoder.isLikelyStealth("hello there"), "plain English (no Arabic) should never read as stealth")

        NSLog("[WhiskyClaude] StealthDecoder self-check passed")
    }
}
#endif
