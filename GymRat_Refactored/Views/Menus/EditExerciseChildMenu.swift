import Foundation
import SwiftUI

struct EditExerciseChildMenu: View {
    
    private enum SectionState {
        case initial
        case addWarmupSets
        case updateRestTimers
    }
    
    let settings: ExerciseSettings
    let standaloneNumpadHost: FocusOnlyHost
    let pageAnimation: Animation
    let onAddWarmupSets: (Int?) -> Void
    let onUpdateRestTimers: (_ warmup: Int?, _ working: Int?) -> Void
    let onAddRestTimers: () -> Void
    let onReplaceExercise: () -> Void
    let onDeleteSelf: () -> Void
    let close: (@escaping () -> Void) -> Void
    
    
    @State private var state: SectionState = .initial
    @State private var goingBack: Bool = false
    
    @State private var addWarmupSetsFieldId: UUID = UUID()
    @State private var addWarmupSetsText: String = "0"
    
    @State private var warmupRestTimerFieldId: UUID = UUID()
    @State private var warmupRestTimerText: String = ""
    var initialWarmupRestTimerText: String {
        return formatRest(settings.warmupRestDuration)
    }
    
    @State private var workingRestTimerFieldId: UUID = UUID()
    @State private var workingRestTimerText: String = ""
    var initalWorkingRestTimerText: String {
        return formatRest(settings.setRestDuration)
    }
    
    init(
        settings: ExerciseSettings,
        standaloneNumpadHost: FocusOnlyHost,
        pageAnimation: Animation,
        onAddWarmupSets: @escaping (Int?) -> Void,
        onUpdateRestTimers: @escaping (_ warmup: Int?, _ working: Int?) -> Void,
        onAddRestTimers: @escaping () -> Void,
        onReplaceExercise: @escaping () -> Void,
        onDeleteSelf:  @escaping () -> Void,
        close: @escaping (@escaping () -> Void) -> Void,
    ) {
        self.settings = settings
        self.standaloneNumpadHost = standaloneNumpadHost
        self.pageAnimation = pageAnimation
        self.onAddWarmupSets = onAddWarmupSets
        self.onUpdateRestTimers = onUpdateRestTimers
        self.onAddRestTimers = onAddRestTimers
        self.onReplaceExercise = onReplaceExercise
        self.onDeleteSelf = onDeleteSelf
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
                    addWarmupSetsView()
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

                }
            }
            
            labelView(title: "Add warmup sets", image: "plusminus") {
                navigate(to: .addWarmupSets, goingBack: false)
            }
            
            labelView(title: "Update rest timers", image: "timer") {
                navigate(to: .updateRestTimers, goingBack: false)
            }
            
            labelView(title: "Add rest timers", image: "text.badge.plus") {
                close {
                    onAddRestTimers()
                }
            }
            
            labelView(title: "Replace exercise", image: "arrow.trianglehead.2.clockwise") {
                close {
                    onReplaceExercise()
                }
            }
            
            Button {
                close {
                    onDeleteSelf()
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
                    onUpdateRestTimers(parseNormalizedRest(warmupRestTimerText), parseNormalizedRest(workingRestTimerText))
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
    func addWarmupSetsView () -> some View {
        VStack {
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
            
            FieldRow(
                id: addWarmupSetsFieldId,
                host: standaloneNumpadHost,
                inputPolicy: InputPolicies.digitsOnly(maxDigits: 1, allowNegative: false),
                config: .init(),
                text: $addWarmupSetsText
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 44, alignment: .center)
            .onAppear {
                standaloneNumpadHost.setActive(addWarmupSetsFieldId)
            }
            
            Button {
                close {
                    onAddWarmupSets(parse(addWarmupSetsText))
                }
            } label: {
                Text("Add")
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
}


