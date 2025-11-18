import Foundation
import SwiftUI

struct EditExerciseChildMenu: View {
    
    private enum SectionState {
        case initial
        case addWarmupSets
        case updateRestTimers
    }
    
    let editStore: any ExerciseChildEditStore
    let standaloneNumpadHost: FocusOnlyHost
    let pageAnimation: Animation
    let onReplaceExercise: () -> Void
    let close: (@escaping () -> Void) -> Void
    
    
    @State private var state: SectionState = .initial
    @State private var goingBack: Bool = false
    
    @State private var addSetsFieldId: UUID = UUID()
    @State private var addSetsCountText: String = "0"
    @State private var addSetsSetType: SetType = .regular
    
    @State private var warmupRestTimerFieldId: UUID = UUID()
    @State private var warmupRestTimerText: String = ""
    var initialWarmupRestTimerText: String {
        return formatRest(editStore.exerciseChildDTO.settings.warmupRestDuration)
    }
    
    @State private var workingRestTimerFieldId: UUID = UUID()
    @State private var workingRestTimerText: String = ""
    var initalWorkingRestTimerText: String {
        return formatRest(editStore.exerciseChildDTO.settings.setRestDuration)
    }
    
    init(
        editStore: any ExerciseChildEditStore,
        standaloneNumpadHost: FocusOnlyHost,
        pageAnimation: Animation,
        onReplaceExercise: @escaping () -> Void,
        close: @escaping (@escaping () -> Void) -> Void,
    ) {
        self.editStore = editStore
        self.standaloneNumpadHost = standaloneNumpadHost
        self.pageAnimation = pageAnimation
        self.onReplaceExercise = onReplaceExercise
        self.close = close
        
        self._warmupRestTimerText = State(initialValue: initialWarmupRestTimerText)
        self._workingRestTimerText = State(initialValue: initalWorkingRestTimerText)
        
    }
    
    var body: some View {
        Group {
            switch state {
                case .initial:
                    initialView()
                case .addWarmupSets:
                    addSetsView()
                case .updateRestTimers:
                    updateRestTimersView()
                }
        }
        .padding()
        .frame(width: 220)
        .transition(
            .asymmetric(
                insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .scale(scale: 0.8, anchor: goingBack ? .topLeading : .topTrailing)),
                removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .scale(scale: 0.8, anchor: goingBack ? .topTrailing : .topLeading))
            )
        )
    }
    
    @ViewBuilder
    func initialView () -> some View {
        VStack (spacing: 0) {
            labelView(title: "Add note", image: "note") {
                close {
                    editStore.addNote("")
                }
            }
            
            labelView(title: "Add sets", image: "plus") {
                navigate(to: .addWarmupSets, goingBack: false)
            }
            
            labelView(title: "Update rest timers", image: "timer") {
                navigate(to: .updateRestTimers, goingBack: false)
            }
            
            labelView(title: "Add rest timers", image: "text.badge.plus") {
                close {
                    editStore.addMissingRest()
                }
            }
            
            labelView(title: "Replace exercise", image: "arrow.trianglehead.2.clockwise") {
                close {
                    onReplaceExercise()
                }
            }
            
            Button {
                close {
                    editStore.deleteSelf()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 32)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.red))
            }
            .padding(.top)
        }
    }
    
    private func navigate (to destination: SectionState, goingBack: Bool) {
        if standaloneNumpadHost.activeId != nil { standaloneNumpadHost.setActive(nil)}
        self.goingBack = goingBack
        withAnimation(.snappy(duration: 0.3)) {
            state = destination
        }
    }
    
    @ViewBuilder
    func labelView (title: String, image: String, action: @escaping () -> ()) -> some View {
        Button {
            action()
        } label: {
            HStack (alignment: .center) {
                Image(systemName: image)
                    .frame(width: 22)
                    .foregroundStyle(.indigo)
                
                Text(title)
                    .foregroundStyle(.gray)
                    .fontWeight(.semibold)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
        }
    }
    
    @ViewBuilder
    func updateRestTimersView () -> some View {
        VStack {
            HStack {
                DismissButton {
                    navigate(to: .initial, goingBack: true)
                }
                
                Text("Update rest timers")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            FieldRow(
                id: warmupRestTimerFieldId,
                host: standaloneNumpadHost,
                inputPolicy: InputPolicies.time(limit: .hours, allowedNegative: false),
                config: .init(),
                text: $warmupRestTimerText
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 44, alignment: .center)
            .onAppear {
                standaloneNumpadHost.setActive(warmupRestTimerFieldId)
            }
            
            FieldRow(
                id: workingRestTimerFieldId,
                host: standaloneNumpadHost,
                inputPolicy: InputPolicies.time(limit: .hours, allowedNegative: false),
                config: .init(),
                text: $workingRestTimerText
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 44, alignment: .center)
            
            Button {
                close {
                    editStore.updateRestTimers(warmup: parseNormalizedRest(warmupRestTimerText), working: parseNormalizedRest(workingRestTimerText))
                }
            } label: {
                Text("Update")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 44, alignment: .center)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.indigo)
                    }
            }
        }
    }

    @ViewBuilder
    func addSetsView () -> some View {
        
        var selectSetTypeLabelWidth: CGFloat? = nil
        var isValid: Bool {
            !addSetsCountText.isEmpty && !(Int(addSetsCountText) == 0)
        }
        
        VStack (spacing: 16) {
            HStack {
                DismissButton {
                    navigate(to: .initial, goingBack: true)
                }
                
                Text("Add warmup sets")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            VStack (alignment: .leading, spacing: 4) {
                Text("Count")
                    .foregroundStyle(.gray)
                    .font(.caption)
                    .fontWeight(.bold)
                FieldRow(
                    id: addSetsFieldId,
                    host: standaloneNumpadHost,
                    inputPolicy: InputPolicies.digitsOnly(maxDigits: 1, allowNegative: false),
                    config: .init(),
                    text: $addSetsCountText
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 44, alignment: .center)
                .overlay {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(.indigo.opacity(isValid ? 1 : 0.3), style: .init(lineWidth: 1)).fill(.clear)
                }
                .onAppear {
                    standaloneNumpadHost.setActive(addSetsFieldId)
                }
            }
            
            VStack (alignment: .leading, spacing: 4) {
                Text("Settype")
                    .foregroundStyle(.gray)
                    .font(.caption)
                    .fontWeight(.bold)
                
                    MorphMenuView(
                        numpadHost: standaloneNumpadHost,
                        config: .init(
                            alignment: .top,
                            cornerRadius: 12,
                            extraBounce: 0,
                            animation: .snappy(duration: 0.3),
                            backgroundTapable: false
                        )) {
                            Text(addSetsSetType.rawValue)
                                .foregroundStyle(addSetsSetType.color)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 32, alignment: .center)
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(addSetsSetType.color.opacity(0.3))
                                }
                                .onGeometryChange(for: CGSize.self) {
                                    $0.size
                                } action: { newValue in
                                    guard selectSetTypeLabelWidth == nil else { return }
                                    selectSetTypeLabelWidth = newValue.width
                                }
                            
                        } menu: { close in
                            VStack (spacing: 8) {
                                ForEach(SetType.allCases, id: \.id) { setType in
                                    Button {
                                        guard addSetsSetType != setType else {
                                            close { }
                                            return
                                        }
                                        close {
                                            withAnimation(.smooth(duration: 0.1)) {
                                                addSetsSetType = setType
                                            }
                                        }
                                    } label: {
                                        Text(setType.rawValue)
                                            .foregroundStyle(setType.color)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .frame(width: selectSetTypeLabelWidth ?? 144, height: 32, alignment: .center)
                                            .background {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(setType.fadedColor)
                                            }
                                    }
                                    
                                }
                            }
                            .padding()
                        }
            }
            
            Button {
                close {
                    guard let count = parse(addSetsCountText) else { return }
                    
                    editStore.addSets(setType: addSetsSetType, count: count)
                }
            } label: {
                Text("Add")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isValid ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 32, alignment: .center)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isValid ? .indigo : Color(red: 0.937, green: 0.937, blue: 0.937))
                    }
            }
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.7)
        }
    }
}


