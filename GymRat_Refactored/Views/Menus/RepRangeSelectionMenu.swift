import SwiftUI
import Foundation

struct RepRangeSelectionMenu: View {
    
    // Arguments
    let editStore: any SetChildEditStore
    var close: (@escaping () -> ()) -> ()
    
    // View propertires
    @State private var selected: RepsType
    @State private var minReps: Int?
    @State private var maxReps: Int?
    @State private var dragOffset: CGFloat = 0
    @State private var dragItemRect: CGRect = .zero
    @State private var containerRect: CGRect = .zero
    @State private var dragAnchorRect: CGRect = .zero
    @State private var items: [RepsType: CGRect] = [:]
    
    init (
        editStore: any SetChildEditStore,
        close: @escaping (
            @escaping () -> ()
        ) -> ()
    ) {
        self.editStore = editStore
        self.close = close
        self.selected = editStore.repsType
        self._minReps = State(initialValue: editStore.setDTO.minReps)
        self._maxReps = State(initialValue: editStore.setDTO.maxReps)
    }
    
    var body: some View {
        VStack (spacing: 16) {
            HStack {
                pickerItemView(for: .single)
                pickerItemView(for: .range)
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: .infinity).fill(Color(red: 0.937, green: 0.937, blue: 0.937))
                    .onGeometryChange(for: CGRect.self) {
                        $0.frame(in: .global)
                    } action: { newValue in
                        containerRect = newValue
                    }
                    .overlay(alignment: .topLeading) {
                        if containerRect != .zero, let target = items[selected], (target.width.isFinite && target.width > 0 && target.minX.isFinite && target.minX > 0) {
                            let x = target.minX - containerRect.minX
                            
                            RoundedRectangle(cornerRadius: .infinity).fill(.indigo.opacity(1))
                                .frame(width: target.width, height: 44)
                                .glassEffect(.clear.interactive(true), in: .rect(cornerRadius: .infinity))
                                .shadow(color: .indigo, radius: 4)
                                .offset(x: dragOffset + x)
                                .animation(.snappy, value: selected)
                                .animation(.snappy, value: dragOffset)
                        }
                    }
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.1)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .first(true):
                            dragAnchorRect = items[selected] ?? .zero
                        case .second(true, let drag?):
                            let translation = drag.translation.width
                            dragOffset = clampedOffset(for: translation,
                                                       anchor: dragAnchorRect,
                                                       container: containerRect)
                        default: break
                        }
                    }
                    .onEnded { value in
                        switch value {
                        case .first(true):
                            dragOffset = 0
                        case .second(true, let drag?):
                            let t = clampedOffset(for: drag.translation.width,
                                                  anchor: dragAnchorRect,
                                                  container: containerRect)
                            let center = CGPoint(x: dragAnchorRect.midX + t,
                                                 y: dragAnchorRect.midY)
                            
                            if let new = items.first(where: { $0.value.contains(center) })?.key,
                               new != selected {
                                withAnimation {
                                    selected = new
                                }
                            }
                            dragOffset = 0
                        default: break
                        }
                    }
            )
            
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4)) {
                ForEach(1..<21, id: \.self) { rep in
                    repPickerView(for: rep)
                }
            }
            .frame(maxWidth: .infinity)
            
            Button {
                if selected == .single {
                    maxReps = nil
                }
                
                close {
                    editStore.setRepsTarget(min: minReps, max: maxReps)
                }
            } label: {
                RoundedRectangle(cornerRadius: 12).fill(.indigo)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay (alignment: .center) {
                        Text("Apply")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
            }

        }
        .padding()
        .frame(width: 200)
    }
    
    func clampedOffset(
        for translation: CGFloat,
        anchor: CGRect,
        container: CGRect
    ) -> CGFloat {
        let minOffset = container.minX - anchor.minX
        let maxOffset = container.maxX - anchor.maxX
        return min(max(translation, minOffset), maxOffset)
    }
    
    @ViewBuilder
    func pickerItemView (for selection: RepsType) -> some View {
        
        var isSelected: Bool {
            selection == selected
        }
        
        Text(selection.rawValue)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(isSelected ? .white : .black)
            .onTapGesture {
                guard !isSelected else { return }
                withAnimation {
                    selected = selection
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .compositingGroup()
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: { newValue in
                items[selection] = newValue
            }
        
    }
    
    @ViewBuilder
    func repPickerView (for rep: Int) -> some View {
        
        var isSelected: Bool {
            switch selected {
            case .single:
                if let selectedMin = minReps, rep == selectedMin {
                    return true
                }
                return false
            case .range:
                return (rep == minReps || rep == maxReps)
            case .none:
                return false
            }
        }
        
        var isBetween: Bool {
            guard let min = minReps, let max = maxReps, selected == .range else { return false }
            
            if rep > min && rep < max {
                return true
            }else {
                return false
            }
        }
        
        var backgroundColor: Color {
            if isSelected {
                return .indigo
            }else if isBetween {
                return .indigo.opacity(0.5)
            }else {
                return Color(red: 0.937, green: 0.937, blue: 0.937)
            }
        }
        
        Circle()
            .fill(backgroundColor)
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: .indigo.opacity(isSelected ? 1 : 0), radius: 4)
            .overlay (alignment: .center) {
                Text("\(rep)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .onTapGesture {
                switch selected {
                case .single:
                    guard minReps != rep else {
                        withAnimation {
                            minReps = nil
                        }
                        return
                    }
                    withAnimation {
                        minReps = rep
                    }
                    
                    if let maxSelected = maxReps, let minSelected = minReps, minSelected >= maxSelected {
                        maxReps = nil
                    }
                case .range:
                    if let _ = minReps, let _ = maxReps {
                        withAnimation {
                            minReps = rep
                            maxReps = nil
                        }
                    }else if let selectedMin = minReps {
                        if rep > selectedMin {
                            withAnimation {
                                maxReps = rep
                            }
                        }else if rep == selectedMin {
                            withAnimation {
                                minReps = nil
                            }
                        }else {
                            withAnimation {
                                minReps = rep
                            }
                        }
                    }else {
                        withAnimation {
                            minReps = rep
                        }
                    }
                case .none:
                    break
                }
            }
    }
}
