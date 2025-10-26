import Foundation
import Combine

final class RestSessionEditStore: ObservableObject {
    let id: UUID = UUID()
    
    private let get: () -> RestSession?
    private let set: (RestSession?) -> Void
    private let onChange: () -> Void
    
    init (
        get: @escaping () -> RestSession?,
        set: @escaping (RestSession?) -> Void,
        onChange: @escaping () -> Void
    ) {
        self.get = get
        self.set = set
        self.onChange = onChange
    }
    
    private var rest: RestSession? {
        get {
            get()
        }
        set {
            set(newValue)
            onChange()
        }
    }
    
    var duration: Int {
        rest?.duration ?? 0
    }
    
    func setDuration (_ seconds: Int) {
        guard var rest = rest else { return }
        rest.duration = max(0, seconds)
        self.rest = rest
    }
}
