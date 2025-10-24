import SwiftUI

struct TabBar: UIViewRepresentable {
    
    var size: CGSize
    var barTint: Color = .gray.opacity(0.15)
    @Binding var activeTabItem: TabItem
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UISegmentedControl {
        let items = TabItem.allCases.compactMap({ _ in ""})
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        
        DispatchQueue.main.async {
            for subview in control.subviews {
                if subview is UIImageView && subview != control.subviews.last {
                    subview.alpha = 0
                }
            }
        }
        
        control.selectedSegmentTintColor = UIColor(barTint)
        
        control.addTarget(context.coordinator, action: #selector(context.coordinator.tabSelected(_:)), for: .valueChanged)
        return control
    }
    
    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        return size
    }
    
    class Coordinator: NSObject {
        var parent: TabBar
        init(parent: TabBar) {
            self.parent = parent
        }
        
        @objc func tabSelected (_ control: UISegmentedControl) {
            parent.activeTabItem = TabItem.allCases[control.selectedSegmentIndex]
        }
    }
}

enum TabItem: String, CaseIterable {
    case home = "Home"
    case exercises = "Exercises"
    case templates = "Template"
    case profile = "Profile"
    
    var symbol: String {
        switch self {
        case .home:
            "house"
        case .exercises:
            "dumbbell"
        case .templates:
            "list.dash.header.rectangle"
        case .profile:
            "person"
        }
    }
    
    var actionSymbol: String {
        switch self {
        case .home:
            "plus"
        case .exercises:
            "plus"
        case .templates:
            "plus"
        case .profile:
            "gear"
        }
    }
    
    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

