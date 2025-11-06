import Foundation


public var decSep: String {
    return Locale.current.decimalSeparator ?? "."
}

public func formatWeightTarget (_ v: Double?) -> String {
    guard let v = v else { return ""}
    let s = String(v)
    return decSep == "." ? s : s.replacingOccurrences(of: ".", with: decSep)
}

public func parseWeightTarget (_ s: String) -> Double? {
    return Double(s.replacingOccurrences(of: decSep, with: "."))
}

public func formatRest(_ v: Int?) -> String {
    guard let v = v else { return "" }
    var total = v
    if total < 0 { total = -total } // fjern evt. hvis du ikke vil håndtere negative værdier

    let days  = total / 86_400; total %= 86_400
    let hours = total / 3_600;  total %= 3_600
    let mins  = total / 60
    let secs  = total % 60

    func pad2(_ x: Int) -> String { String(format: "%02d", x) }

    if days > 0 {
        return "\(days):\(pad2(hours)):\(pad2(mins)):\(pad2(secs))"
    } else if hours > 0 {
        return "\(hours):\(pad2(mins)):\(pad2(secs))"
    } else if mins > 0 {
        return "\(mins):\(pad2(secs))"
    } else {
        return "\(secs)"
    }
}

public func formatTime(_ v: Int) -> String {
    var seconds = v
    
    let days = seconds / 86400
    seconds %= 86400
    
    let hours = seconds / 3600
    seconds %= 3600
    
    let minutes = seconds / 60
    seconds %= 60

    var parts: [String] = []
    
    if days > 0 {
        parts.append("\(days)d")
    }
    
    if hours > 0 {
        parts.append("\(hours)h")
    }
    
    if minutes > 0 || hours > 0 {
        let m = (hours > 0 && minutes == 0) ? "00" : "\(minutes)"
        parts.append("\(m)m")
    }
    
    if parts.isEmpty {
        parts.append("\(seconds)s")
    } else {
        parts.append("\(seconds)s")
    }
    
    return parts.joined(separator: " ")
}

public func parseRest(_ s: String) -> Int? {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let parts = trimmed.split(separator: ":").map(String.init)
    guard (1...4).contains(parts.count) else { return nil }

    let nums = parts.compactMap { Int($0) }
    guard nums.count == parts.count else { return nil }

    switch nums.count {
    case 1:
        let ss = nums[0]
        guard ss >= 0 else { return nil }
        return ss

    case 2:
        let (mm, ss) = (nums[0], nums[1])
        guard mm >= 0, (0...59).contains(ss) else { return nil }
        return mm * 60 + ss

    case 3:
        let (hh, mm, ss) = (nums[0], nums[1], nums[2])
        guard hh >= 0, (0...59).contains(mm), (0...59).contains(ss) else { return nil }
        return hh * 3_600 + mm * 60 + ss

    case 4:
        let (dd, hh, mm, ss) = (nums[0], nums[1], nums[2], nums[3])
        guard dd >= 0, (0...23).contains(hh), (0...59).contains(mm), (0...59).contains(ss) else { return nil }
        return dd * 86_400 + hh * 3_600 + mm * 60 + ss

    default:
        return nil
    }
}

public func parseNormalizedRest(_ s: String) -> Int? {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let rawParts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
    guard (1...4).contains(rawParts.count),
          rawParts.allSatisfy({ !$0.isEmpty }) else { return nil }

    var values = [Int]()
    values.reserveCapacity(rawParts.count)
    for p in rawParts {
        guard let n = Int(p), n >= 0 else { return nil }
        values.append(n)
    }
    
    let multipliers = [1, 60, 3600, 86400]
    var total = 0
    for (i, v) in values.reversed().enumerated() {
        total += v * multipliers[i]
    }
    return total
}

public func formatWeight (_ v: Double) -> String {
    let s = String(v)
    return decSep == "." ? s : s.replacingOccurrences(of: ".", with: decSep)
}

public func parseWeight (_ s: String) -> Double? {
    Double(s.replacingOccurrences(of: decSep, with: "."))
}

public func parse (_ s: String) -> Int? {
    Int(s)
}
