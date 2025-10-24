import Foundation
import SwiftUI

enum SetType: String, Codable, CaseIterable, Identifiable, Sendable {
    var id: String {
        rawValue
    }
    
    case regular = "Regular"
    case warmup = "Warmup"
    case coolDown = "CoolDown"
    case dropSet = "DropSet"
    
    var initials: String {
        switch self {
        case .regular:
            return "R"
        case .warmup:
            return "W"
        case .coolDown:
            return "C"
        case .dropSet:
            return "D"
        }
    }
    
    var color: Color {
        switch self {
        case .regular:
            return Color.black
        case .warmup:
            return Color.orange
        case .coolDown:
            return Color.blue
        case .dropSet:
            return Color.green
        }
    }
}

enum MetricType: String, Codable, CaseIterable, Identifiable, Sendable {
    var id: String {
        rawValue
    }
    
    case kg = "kg"
    case lb = "lb"
}

enum RepsType: String, Codable, CaseIterable, Identifiable, Sendable {
    var id: String { rawValue }
    case single = "Single"
    case range = "Range"
    case none = "None"
}
