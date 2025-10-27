import Foundation

public struct _DigitsOnlyPolicy: InputPolicy {
    
    public var maxDigits: Int
    public var allowNegative: Bool

    public init(maxDigits: Int, allowNegative: Bool) {
        self.maxDigits = maxDigits
        self.allowNegative = allowNegative
    }

    public func apply(_ key: NumpadKey, to v: NumericValue) -> EditResult {
        switch key {
        case .digit(let ch):
            guard ch.isNumber else { return .rejected }
            return insertDigit(ch, v)

        case .minus:
            guard allowNegative else { return .rejected }
            return toggleMinus(v)

        case .decimal:
            return .rejected

        case .backspace:
            return .updated(backspace(v))
        case .deleteForward:
            return .updated(deleteForward(v))
        case .clear:
            return .updated(NumericValue(text: "", caret: 0, selection: nil))
        case .selectAll:
            var t = v; let n = t.text.utf16Count
            t.selection = n > 0 ? 0..<n : nil
            t.caret = n
            return .updated(t)
        case .next, .prev, .done:
            return .updated(v)
        }
    }

    private func insertDigit(_ ch: Character, _ v: NumericValue) -> EditResult {
        let existingDigits = countDigits(v.text)
        let removedDigits = v.selection.map { countDigits(in: v.text, utf16Range: $0) } ?? 0
        let remaining = maxDigits - (existingDigits - removedDigits)
        guard remaining > 0 else { return .rejected }

        var t = deleteSelectionIfAny(v)
        let i = t.caret
        t.text.insert(ch, at: stringIndex(fromUTF16: i, in: t.text))
        t.caret = i + 1
        t.selection = nil
        clampCaret(&t)
        if countDigits(t.text) > maxDigits { return .rejected }
        return .updated(t)
    }

    private func toggleMinus(_ v: NumericValue) -> EditResult {
        var t = deleteSelectionIfAny(v)
        if t.text.hasPrefix("-") {
            t.text.removeFirst()
            if t.caret > 0 { t.caret -= 1 }
            if let sel = t.selection { t.selection = max(0, sel.lowerBound - 1)..<max(0, sel.upperBound - 1) }
        } else {
            t.text.insert("-", at: t.text.startIndex)
            t.caret += 1
            if let sel = t.selection { t.selection = (sel.lowerBound + 1)..<(sel.upperBound + 1) }
        }
        clampCaret(&t)
        if !allowNegative && t.text.contains("-") { return .rejected }
        return .updated(t)
    }

    private func backspace(_ v: NumericValue) -> NumericValue {
        var t = v
        if let sel = t.selection {
            removeRangeUTF16(&t.text, sel)
            t.caret = sel.lowerBound
            t.selection = nil
            return t
        }
        guard t.caret > 0 else { return t }
        let i = t.caret - 1
        t.text.remove(at: stringIndex(fromUTF16: i, in: t.text))
        t.caret = i
        return t
    }

    private func deleteForward(_ v: NumericValue) -> NumericValue {
        var t = v
        if let sel = t.selection {
            removeRangeUTF16(&t.text, sel)
            t.caret = sel.lowerBound
            t.selection = nil
            return t
        }
        guard t.caret < t.text.utf16Count else { return t }
        let i = t.caret
        t.text.remove(at: stringIndex(fromUTF16: i, in: t.text))
        return t
    }
}

extension _DigitsOnlyPolicy: KeyboardTreeProviding {
    public func keyboardTree(hostSupportsNavigation: Bool) -> KeyboardNode {
        let style = KeyboardButtonStyle()
        let navPrev: KeyboardNode = hostSupportsNavigation ? .button(title: "Prev", sends: .prev, style: style) : .spacer(flex: 1)
        let navNext: KeyboardNode = hostSupportsNavigation ? .button(title: "Next", sends: .next, style: style) : .spacer(flex: 1)
        let minus: KeyboardNode = allowNegative ? .button(title: "−", sends: .minus, style: style) : .spacer(flex: 1)

        return .vstack(spacing: 8, children: [
            .hstack(spacing: 8, children: [
                .button(title: "1", sends: .digit("1"), style: style),
                .button(title: "2", sends: .digit("2"), style: style),
                .button(title: "3", sends: .digit("3"), style: style),
                navPrev
            ]),
            .hstack(spacing: 8, children: [
                .button(title: "4", sends: .digit("4"), style: style),
                .button(title: "5", sends: .digit("5"), style: style),
                .button(title: "6", sends: .digit("6"), style: style),
                navNext
            ]),
            .hstack(spacing: 8, children: [
                .button(title: "7", sends: .digit("7"), style: style),
                .button(title: "8", sends: .digit("8"), style: style),
                .button(title: "9", sends: .digit("9"), style: style),
                .button(title: "⌫", sends: .backspace, style: style),
            ]),
            .hstack(spacing: 8, children: [
                minus,
                .button(title: "0", sends: .digit("0"), style: style),
                .button(title: "Clear", sends: .clear, style: style),
                .button(title: "Done", sends: .done, style: style),
            ])
        ])
    }
}

public struct _DecimalPolicy: InputPolicy {
    public var allowNegative: Bool
    public var maxIntegerDigits: Int
    public var maxFractionDigits: Int
    public var decimalSeparator: Character

    public init(maxIntegerDigits: Int,
                maxFractionDigits: Int,
                allowNegative: Bool,
                decimalSeparator: Character = ".") {
        self.allowNegative = allowNegative
        self.maxIntegerDigits = maxIntegerDigits
        self.maxFractionDigits = maxFractionDigits
        self.decimalSeparator = decimalSeparator
    }

    public func apply(_ key: NumpadKey, to v: NumericValue) -> EditResult {
        switch key {
        case .digit(let ch):
            guard ch.isNumber else { return .rejected }
            return insert(String(ch), v)

        case .decimal:
            return insert(String(decimalSeparator), v)

        case .minus:
            return insert("-", v)

        case .backspace:
            return delete(using: backspaceRange(v), base: v)

        case .deleteForward:
            return delete(using: deleteForwardRange(v), base: v)

        case .clear:
            return .updated(NumericValue(text: "", caret: 0, selection: nil))

        case .selectAll:
            var t = v; let n = t.text.utf16Count
            t.selection = (n > 0 ? 0..<n : nil); t.caret = n
            return .updated(t)

        case .next, .prev, .done:
            return .updated(v)
        }
    }

    @inline(__always)
    private func isDigitOrSepOrMinus(_ c: Character) -> Bool {
        if c.isNumber { return true }
        if c == "-" { return true }
        return c == decimalSeparator
    }

    @inline(__always)
    private func normalizeInserted(_ s: String) -> String {
        if decimalSeparator == "." {
            return s.map { $0 == "," ? "." : $0 }.reduce(into: "", { $0.append($1) })
        } else if decimalSeparator == "," {
            return s.map { $0 == "." ? "," : $0 }.reduce(into: "", { $0.append($1) })
        } else {
            return s
        }
    }

    @inline(__always)
    private func firstUTF16(of s: String, char target: Character) -> Int? {
        guard let i = s.firstIndex(of: target) else { return nil }
        return s.utf16.distance(from: s.utf16.startIndex, to: i)
    }

    @inline(__always)
    private func countDigitsAroundSep(_ s: String) -> (intDigits: Int, fracDigits: Int, hasSep: Bool, sepUTF16: Int?) {
        var intDigits = 0, fracDigits = 0
        var seenSep = false
        var sepLoc: Int? = nil
        var u16 = 0
        for ch in s {
            if !seenSep {
                if ch == decimalSeparator {
                    seenSep = true; sepLoc = u16
                } else if ch.isNumber {
                    intDigits &+= 1
                }
            } else {
                if ch.isNumber { fracDigits &+= 1 }
            }
            u16 &+= ch.utf16.count
        }
        return (intDigits, fracDigits, seenSep, sepLoc)
    }

    @inline(__always)
    private func countMinusAndValidatePosition(_ s: String) -> (count: Int, firstIsMinus: Bool) {
        var cnt = 0
        var firstIsMinus = false
        var i = 0
        for ch in s {
            if ch == "-" {
                cnt &+= 1
                if i == 0 { firstIsMinus = true }
            }
            i &+= 1
        }
        return (cnt, firstIsMinus)
    }

    @inline(__always)
    private func idxInUTF16(_ s: String, offset: Int) -> String.Index? {
        guard let u16 = s.utf16.index(s.utf16.startIndex, offsetBy: offset, limitedBy: s.utf16.endIndex) else { return nil }
        return String.Index(u16, within: s)
    }

    @inline(__always)
    private func nsRange(from v: NumericValue) -> NSRange {
        if let sel = v.selection {
            return NSRange(location: sel.lowerBound, length: sel.count)
        } else {
            return NSRange(location: v.caret, length: 0)
        }
    }

    @inline(__always)
    private func backspaceRange(_ v: NumericValue) -> NSRange {
        if let sel = v.selection { return NSRange(location: sel.lowerBound, length: sel.count) }
        guard v.caret > 0 else { return NSRange(location: 0, length: 0) }
        return NSRange(location: v.caret - 1, length: 1)
    }

    @inline(__always)
    private func deleteForwardRange(_ v: NumericValue) -> NSRange {
        if let sel = v.selection { return NSRange(location: sel.lowerBound, length: sel.count) }
        guard v.caret < v.text.utf16Count else { return NSRange(location: v.caret, length: 0) }
        return NSRange(location: v.caret, length: 1)
    }

    private func insert(_ raw: String, _ v: NumericValue) -> EditResult {
        let ins = normalizeInserted(raw)
        for ch in ins { if !isDigitOrSepOrMinus(ch) { return .rejected } }

        let sel = nsRange(from: v)
        guard let (newText, newSel) = safeInsertion(currentText: v.text, selection: sel, inserted: ins) else {
            return .rejected
        }
        return .updated(NumericValue(
            text: newText,
            caret: newSel.location,
            selection: newSel.length > 0 ? (newSel.location ..< newSel.location + newSel.length) : nil
        ))
    }

    private func delete(using range: NSRange, base v: NumericValue) -> EditResult {
        guard let (newText, newSel) = safeDeletion(currentText: v.text, deletionRange: range) else {
            return .rejected
        }
        return .updated(NumericValue(
            text: newText,
            caret: newSel.location,
            selection: newSel.length > 0 ? (newSel.location ..< newSel.location + newSel.length) : nil
        ))
    }

    private func safeInsertion(currentText: String, selection: NSRange, inserted: String) -> (String, NSRange)? {
        let base = currentText as NSString
        var candidate = base.replacingCharacters(in: selection, with: inserted)

        var sepCount = 0
        for ch in candidate { if ch == decimalSeparator { sepCount &+= 1; if sepCount > 1 { return nil } } }

        let minusInfo = countMinusAndValidatePosition(candidate)
        if minusInfo.count > 1 { return nil }
        if minusInfo.count == 1 && !minusInfo.firstIsMinus { return nil }
        if !allowNegative && minusInfo.count > 0 { return nil }

        var around = countDigitsAroundSep(candidate)
        var intDigits = around.intDigits
        var fracDigits = around.fracDigits
        let hasSep = around.hasSep
        let sepUTF16 = around.sepUTF16

        if hasSep && fracDigits > maxFractionDigits {
            let overflow = fracDigits - maxFractionDigits

            let insLen = (inserted as NSString).length
            let insRange = NSRange(location: selection.location, length: insLen)

            let fracStart = (sepUTF16 ?? candidate.utf16.count) + String(decimalSeparator).utf16.count
            let fracRange = NSRange(location: fracStart, length: max(0, candidate.utf16.count - fracStart))

            let overlapStart = max(insRange.location, fracRange.location)
            let overlapEnd   = min(insRange.location + insRange.length, fracRange.location + fracRange.length)
            let overlapLen   = max(0, overlapEnd - overlapStart)
            if overlapLen == 0 { return nil }

            let toRemove = min(overflow, overlapLen)
            guard toRemove > 0 else { return nil }

            guard
                let rmStart = idxInUTF16(candidate, offset: overlapEnd - toRemove),
                let rmEnd   = idxInUTF16(candidate, offset: overlapEnd)
            else { return nil }
            candidate.removeSubrange(rmStart..<rmEnd)

            around = countDigitsAroundSep(candidate)
            fracDigits = around.fracDigits
        }

        if intDigits > maxIntegerDigits {
            if hasSep {
                let insLen = (inserted as NSString).length
                let insRange = NSRange(location: selection.location, length: insLen)
                let intEnd = sepUTF16 ?? candidate.utf16.count
                let intRange = NSRange(location: 0, length: intEnd)

                let overlapStart = max(insRange.location, intRange.location)
                let overlapEnd   = min(insRange.location + insRange.length, intRange.location + intRange.length)
                let overlapLen   = max(0, overlapEnd - overlapStart)
                if overlapLen == 0 { return nil }

                let overflow = intDigits - maxIntegerDigits
                let toRemove = min(overflow, overlapLen)
                guard toRemove > 0 else { return nil }

                guard
                    let rmStart = idxInUTF16(candidate, offset: overlapEnd - toRemove),
                    let rmEnd   = idxInUTF16(candidate, offset: overlapEnd)
                else { return nil }
                candidate.removeSubrange(rmStart..<rmEnd)

                intDigits = countDigitsAroundSep(candidate).intDigits
                if intDigits > maxIntegerDigits { return nil }
            } else {
                var insertedAnyDigit = false
                for ch in inserted { if ch.isNumber { insertedAnyDigit = true; break } }
                if insertedAnyDigit { return nil }
            }
        }

        let baseWithoutSel = base.replacingCharacters(in: selection, with: "")
        let deltaLen = candidate.utf16.count - baseWithoutSel.utf16.count
        let newLoc = selection.location + max(0, deltaLen)

        return (candidate, NSRange(location: newLoc, length: 0))
    }

    private func safeDeletion(currentText: String, deletionRange: NSRange) -> (String, NSRange)? {
        guard !currentText.isEmpty else { return nil }

        let delRange = deletionRange
        if delRange.length == 0 { return nil }

        let ns = currentText as NSString
        var candidate = ns.replacingCharacters(in: delRange, with: "")

        if candidate.last == decimalSeparator {
            candidate.removeLast()
        }

        let minusInfo = countMinusAndValidatePosition(candidate)
        if minusInfo.count > 1 { return nil }
        if minusInfo.count == 1 && !minusInfo.firstIsMinus { return nil }
        if !allowNegative && minusInfo.count > 0 { return nil }
        if allowNegative && candidate == "-" { candidate = "" }
        let around = countDigitsAroundSep(candidate)
        if !around.hasSep {
            let totalDigits = candidate.reduce(0) { $0 + ($1.isNumber ? 1 : 0) }
            if totalDigits > maxIntegerDigits { return nil }
        }

        if maxFractionDigits >= 0,
           let sepPos = firstUTF16(of: candidate, char: decimalSeparator) {
            let sepLen = String(decimalSeparator).utf16.count
            let fracStart = sepPos + sepLen
            let fracLen = max(0, candidate.utf16.count - fracStart)
            if fracLen > maxFractionDigits {
                let keep = maxFractionDigits
                if let start = idxInUTF16(candidate, offset: fracStart + keep) {
                    candidate.removeSubrange(start..<candidate.endIndex)
                }
            }
        }

        return (candidate, NSRange(location: delRange.location, length: 0))
    }
}

extension _DecimalPolicy: KeyboardTreeProviding {
    public func keyboardTree(hostSupportsNavigation: Bool) -> KeyboardNode {
        let style = KeyboardButtonStyle()
        let navPrev: KeyboardNode = hostSupportsNavigation ? .button(title: "Prev", sends: .prev, style: style) : .spacer(flex: 1)
        let navNext: KeyboardNode = hostSupportsNavigation ? .button(title: "Next", sends: .next, style: style) : .spacer(flex: 1)
        let minus: KeyboardNode = allowNegative ? .button(title: "−", sends: .minus, style: style) : .spacer(flex: 1)
        let dotTitle = String(decimalSeparator)

        return .vstack(spacing: 8, children: [
            .hstack(spacing: 8, children: [
                .button(title: "1", sends: .digit("1"), style: style),
                .button(title: "2", sends: .digit("2"), style: style),
                .button(title: "3", sends: .digit("3"), style: style),
                navPrev
            ]),
            .hstack(spacing: 8, children: [
                .button(title: "4", sends: .digit("4"), style: style),
                .button(title: "5", sends: .digit("5"), style: style),
                .button(title: "6", sends: .digit("6"), style: style),
                navNext
            ]),
            .hstack(spacing: 8, children: [
                .button(title: "7", sends: .digit("7"), style: style),
                .button(title: "8", sends: .digit("8"), style: style),
                .button(title: "9", sends: .digit("9"), style: style),
                .button(title: "⌫", sends: .backspace, style: style),
            ]),
            .hstack(spacing: 8, children: [
                .button(title: dotTitle, sends: .decimal, style: style),
                .button(title: "0", sends: .digit("0"), style: style),
                minus,
                .button(title: "Done", sends: .done, style: style),
            ])
        ])
    }
}

public struct _TimePolicy: InputPolicy {

    public enum MaxTimeLimit: Equatable {
        case seconds
        case minutes
        case hours
        case days
    }

    public var allowNegative: Bool
    public var maxTimeLimit: MaxTimeLimit

    public init(allowNegative: Bool = false, maxTimeLimit: MaxTimeLimit) {
        self.allowNegative = allowNegative
        self.maxTimeLimit = maxTimeLimit
    }

    // MARK: - _InputPolicy
    public func apply(_ key: NumpadKey, to v: NumericValue) -> EditResult {
        switch key {
        case .digit(let ch):
            guard ch.isNumber else { return .rejected }
            return insertString(String(ch), into: v)

        case .minus:
            guard allowNegative else { return .rejected }
            return insertString("-", into: v)

        case .decimal:
            return .rejected // ingen punktum i tidsformat

        case .backspace:
            return .updated(applyDeletion(v, mode: .backspace))

        case .deleteForward:
            return .updated(applyDeletion(v, mode: .deleteForward))

        case .clear:
            return .updated(NumericValue(text: "", caret: 0, selection: nil))

        case .selectAll:
            var t = v; let n = t.text.utf16Count
            t.selection = (n > 0 ? 0..<n : nil); t.caret = n
            return .updated(t)

        case .next, .prev, .done:
            return .updated(v) // fokus håndteres af hosten
        }
    }

    // MARK: - Insertion

    private func insertString(_ s: String, into v: NumericValue) -> EditResult {
        guard let replaced = replaceRange(in: v.text, selection: nsRange(from: v), with: s) else { return .rejected }
        guard let normalized = normalize(raw: replaced, allowNegative: allowNegative) else { return .rejected }

        if let cap = capacity(for: maxTimeLimit), normalized.digits.count > cap {
            return .rejected
        }

        let pretty = format(digits: normalized.digits, negative: normalized.negative, limit: maxTimeLimit)
        let nv = NumericValue(text: pretty, caret: pretty.utf16.count, selection: nil)
        return .updated(nv)
    }

    // MARK: - Deletion

    private enum DeleteMode { case backspace, deleteForward }

    private func applyDeletion(_ v: NumericValue, mode: DeleteMode) -> NumericValue {
        guard !v.text.isEmpty else { return v }

        var delRange: NSRange
        if let sel = v.selection {
            delRange = NSRange(location: sel.lowerBound, length: sel.count)
        } else {
            switch mode {
            case .backspace:
                guard v.caret > 0 else { return v }
                delRange = NSRange(location: v.caret - 1, length: 1)
            case .deleteForward:
                guard v.caret < v.text.utf16Count else { return v }
                delRange = NSRange(location: v.caret, length: 1)
            }
        }

        guard let afterDelete = replaceRange(in: v.text, selection: delRange, with: "") else { return v }
        guard let normalized = normalize(raw: afterDelete, allowNegative: allowNegative) else { return v }

        let pretty = format(digits: normalized.digits, negative: normalized.negative, limit: maxTimeLimit)
        return NumericValue(text: pretty, caret: pretty.utf16.count, selection: nil)
    }

    // MARK: - Helpers (samme ånd som din gamle TimePolicy)

    private func capacity(for limit: MaxTimeLimit) -> Int? {
        switch limit {
            case .seconds: return 2
            case .minutes: return 4
            case .hours:   return 6
            case .days:    return 8
        }
    }

    private func nsRange(from v: NumericValue) -> NSRange {
        if let sel = v.selection {
            return NSRange(location: sel.lowerBound, length: sel.count)
        } else {
            return NSRange(location: v.caret, length: 0)
        }
    }

    private func replaceRange(in base: String, selection: NSRange, with inserted: String) -> String? {
        guard let r = Range(selection, in: base) else { return nil }
        var s = base
        s.replaceSubrange(r, with: inserted)
        return s
    }

    // Fjerner ":" og whitespace, accepterer evt. et foranstillet "-" (hvis tilladt),
    // og samler kun cifre. Afviser øvrige tegn.
    private func normalize(raw: String, allowNegative: Bool) -> (negative: Bool, digits: [Character])? {
        let trimmed = raw.filter { $0 != ":" && !$0.isWhitespace }
        var negative = false
        var digits: [Character] = []

        for (idx, ch) in trimmed.enumerated() {
            if ch == "-" {
                if allowNegative && idx == 0 && !negative {
                    negative = true
                } else {
                    return nil
                }
            } else if ch.isNumber {
                digits.append(ch)
            } else {
                return nil
            }
        }

        digits = canonicalDigits(from: digits)
        return (negative, digits)
    }

    // Fjern ledende nuller (beholder en enkelt 0 hvis alt er nul)
    private func canonicalDigits(from digits: [Character]) -> [Character] {
        var d = digits
        while d.count > 1, d.first == "0" { d.removeFirst() }
        if d.isEmpty { return [] }
        return d
    }

    // Bygger det pæne kolon-formaterede udtryk for valgt limit.
    private func format(digits: [Character], negative: Bool, limit: MaxTimeLimit) -> String {
        if digits.isEmpty { return negative ? "-" : "" }

        func takeRight(_ n: Int, from arr: [Character]) -> (left: [Character], right: [Character]) {
            let right = Array(arr.suffix(n))
            let left  = Array(arr.dropLast(min(n, arr.count)))
            return (left, right)
        }
        func pad2(_ s: String) -> String { s.count == 1 ? "0" + s : (s.isEmpty ? "00" : s) }

        switch limit {
        case .seconds:
            let ss = String(Array(digits.suffix(2)))
            return (negative ? "-" : "") + ss

        case .minutes:
            var left = digits
            let r1 = takeRight(2, from: left); left = r1.left; let ssRaw = String(r1.right)
            let mmRaw = String(left)

            var groups: [String] = []
            if !mmRaw.isEmpty { groups.append(mmRaw) }
            groups.append(ssRaw)

            while groups.count > 1, (groups.first ?? "") == "" || Int(groups.first!) == 0 {
                groups.removeFirst()
            }

            if groups.count == 1 {
                return (negative ? "-" : "") + groups[0]
            } else {
                let head = groups.first!
                let tail = groups.dropFirst().map { pad2($0) }
                return (negative ? "-" : "") + ([head] + tail).joined(separator: ":")
            }

        case .hours:
            var left = digits
            let r1 = takeRight(2, from: left); left = r1.left; let ssRaw = String(r1.right)
            let r2 = takeRight(2, from: left); left = r2.left; let mmRaw = String(r2.right)
            let hhRaw = String(left)

            var groups: [String] = []
            if !hhRaw.isEmpty { groups.append(hhRaw) }
            if !mmRaw.isEmpty || !groups.isEmpty { groups.append(mmRaw) }
            groups.append(ssRaw)

            while groups.count > 1, (groups.first ?? "") == "" || Int(groups.first!) == 0 {
                groups.removeFirst()
            }

            if groups.count == 1 {
                return (negative ? "-" : "") + groups[0]
            } else {
                let head = groups.first!
                let tail = groups.dropFirst().map { pad2($0) }
                return (negative ? "-" : "") + ([head] + tail).joined(separator: ":")
            }

        case .days:
            var left = digits
            let r1 = takeRight(2, from: left); left = r1.left; let ssRaw = String(r1.right)
            let r2 = takeRight(2, from: left); left = r2.left; let mmRaw = String(r2.right)
            let r3 = takeRight(2, from: left); left = r3.left; let hhRaw = String(r3.right)
            let ddRaw = String(left)

            var groups: [String] = []
            if !ddRaw.isEmpty { groups.append(ddRaw) }
            if !hhRaw.isEmpty || !groups.isEmpty { groups.append(hhRaw) }
            if !mmRaw.isEmpty || !groups.isEmpty { groups.append(mmRaw) }
            groups.append(ssRaw)

            while groups.count > 1, (groups.first ?? "") == "" || Int(groups.first!) == 0 {
                groups.removeFirst()
            }

            if groups.count == 1 {
                return (negative ? "-" : "") + groups[0]
            } else {
                let head = groups.first!
                let tail = groups.dropFirst().map { pad2($0) }
                return (negative ? "-" : "") + ([head] + tail).joined(separator: ":")
            }
        }
    }

    // Valgfrit: kan kaldes når feltet forlader fokus hvis du vil normalisere yderligere
    public func finalizeDisplay(_ currentText: String) -> String {
        guard let norm = normalize(raw: currentText, allowNegative: allowNegative) else { return currentText }
        let negative = norm.negative
        var d = 0, h = 0, m = 0, s = 0

        func read2(_ arr: [Character]) -> (left: [Character], val: Int) {
            let right = Array(arr.suffix(2))
            let left  = Array(arr.dropLast(min(2, arr.count)))
            let v = Int(String(right)) ?? 0
            return (left, v)
        }

        var digits = norm.digits
        var r = read2(digits); digits = r.left; s = r.val
        if maxTimeLimit != .seconds { r = read2(digits); digits = r.left; m = r.val }
        if maxTimeLimit == .hours || maxTimeLimit == .days { r = read2(digits); digits = r.left; h = r.val }
        if maxTimeLimit == .days { d = Int(String(digits)) ?? 0 }

        if maxTimeLimit != .seconds { m += s / 60; s = s % 60 }
        if maxTimeLimit == .hours || maxTimeLimit == .days { h += m / 60; m = m % 60 }
        if maxTimeLimit == .days { d += h / 24; h = h % 24 }

        func pad2(_ x: Int) -> String { String(format: "%02d", x) }
        var groups: [String] = []
        switch maxTimeLimit {
        case .seconds: groups = ["\(s)"]
        case .minutes: groups = ["\(m)", pad2(s)]
        case .hours:   groups = ["\(h)", pad2(m), pad2(s)]
        case .days:    groups = ["\(d)", pad2(h), pad2(m), pad2(s)]
        }
        while groups.count > 1, (Int(groups.first ?? "") ?? 0) == 0 { groups.removeFirst() }
        return (negative ? "-" : "") + groups.joined(separator: ":")
    }
}

extension _TimePolicy: KeyboardTreeProviding {
    public func keyboardTree(hostSupportsNavigation: Bool) -> KeyboardNode {
        let style = KeyboardButtonStyle()
        let navPrev: KeyboardNode = hostSupportsNavigation ? .button(title: "Prev", sends: .prev, style: style) : .spacer(flex: 1)
        let navNext: KeyboardNode = hostSupportsNavigation ? .button(title: "Next", sends: .next, style: style) : .spacer(flex: 1)
        let minus: KeyboardNode = allowNegative ? .button(title: "−", sends: .minus, style: style) : .spacer(flex: 1)

        return .vstack(spacing: 8, children: [
            .hstack(spacing: 8, children: [
                .button(title: "1", sends: .digit("1"), style: style),
                .button(title: "2", sends: .digit("2"), style: style),
                .button(title: "3", sends: .digit("3"), style: style),
                navPrev
            ]),
            .hstack(spacing: 8, children: [
                .button(title: "4", sends: .digit("4"), style: style),
                .button(title: "5", sends: .digit("5"), style: style),
                .button(title: "6", sends: .digit("6"), style: style),
                navNext
            ]),
            .hstack(spacing: 8, children: [
                .button(title: "7", sends: .digit("7"), style: style),
                .button(title: "8", sends: .digit("8"), style: style),
                .button(title: "9", sends: .digit("9"), style: style),
                .button(title: "⌫", sends: .backspace, style: style),
            ]),
            .hstack(spacing: 8, children: [
                minus,
                .button(title: "0", sends: .digit("0"), style: style),
                .button(title: "Clear", sends: .clear, style: style),
                .button(title: "Done", sends: .done, style: style),
            ])
        ])
    }
}

public enum InputPolicies {
    public static func digitsOnly(maxDigits: Int, allowNegative: Bool = false) -> InputPolicy {
        _DigitsOnlyPolicy(maxDigits: maxDigits, allowNegative: allowNegative)
    }

    public static func decimal(maxDigits: Int, maxFractionDigits: Int, allowNegative: Bool = false, decimalSeparator: Character = ".") -> InputPolicy {
        _DecimalPolicy(maxIntegerDigits: maxDigits, maxFractionDigits: maxFractionDigits, allowNegative: allowNegative, decimalSeparator: decimalSeparator)
    }
    
    public static func time(limit: _TimePolicy.MaxTimeLimit, allowedNegative: Bool = false) -> InputPolicy {
        _TimePolicy(allowNegative: allowedNegative, maxTimeLimit: limit)
    }
}

@inline(__always)
private func clampCaret(_ v: inout NumericValue) {
    let n = v.text.utf16Count
    v.caret = min(max(0, v.caret), n)
    if let sel = v.selection {
        let lo = min(max(0, sel.lowerBound), n)
        let hi = min(max(0, sel.upperBound), n)
        v.selection = lo < hi ? lo..<hi : nil
    }
}

@inline(__always)
private func stringIndex(fromUTF16 offset: Int, in s: String) -> String.Index {
    let u = s.utf16
    let i = u.index(u.startIndex, offsetBy: offset)
    return String.Index(i, within: s)!
}

@inline(__always)
private func removeRangeUTF16(_ s: inout String, _ r: Range<Int>) {
    s.removeSubrange(stringIndex(fromUTF16: r.lowerBound, in: s)..<stringIndex(fromUTF16: r.upperBound, in: s))
}

@inline(__always)
private func deleteSelectionIfAny(_ v: NumericValue) -> NumericValue {
    guard let sel = v.selection else { return v }
    var t = v
    removeRangeUTF16(&t.text, sel)
    t.caret = sel.lowerBound
    t.selection = nil
    return t
}

@inline(__always)
private func countDigits(_ s: String) -> Int {
    var n = 0; for ch in s { if ch.isNumber { n &+= 1 } }
    return n
}

@inline(__always)
private func countDigits(in s: String, utf16Range: Range<Int>) -> Int {
    var n = 0, pos = 0
    for ch in s {
        let w = ch.utf16.count
        let next = pos + w
        if next > utf16Range.lowerBound && pos < utf16Range.upperBound, ch.isNumber { n &+= 1 }
        pos = next
        if pos >= utf16Range.upperBound { break }
    }
    return n
}

@inline(__always)
private func splitAround(separator sep: Character, in s: String) -> (intPart: Substring, fracPart: Substring?, sepUTF16: Int?) {
    if let idx = s.firstIndex(of: sep) {
        let u16 = s.utf16
        let sepU16 = u16.distance(from: u16.startIndex, to: idx.samePosition(in: u16)!)
        return (s[..<idx], s[s.index(after: idx)..<s.endIndex], sepU16)
    }
    return (s[...], nil, nil)
}
