import Foundation
import SwiftUI

protocol SetChildEditStore: ObservableObject, Equatable, Identifiable {
    associatedtype DTO: SetChildDTO
    func setSetType (to setType: SetType)
    func setWeightTarget (to target: Double?)
    func setRepsTarget (min: Int?, max: Int?)
    func setOrder (_ order: Int)
    func snapshot () -> DTO
    var setTypeColor: Color { get }
    var repsType: RepsType { get }
    var repsTargetDisplay: String { get }
    var repsTargetColor: Color { get }
    var setDTO: DTO { get set}
}
