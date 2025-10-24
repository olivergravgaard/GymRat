import Foundation
import SwiftUI

struct EditExerciseChildMenu: View {
    
    private enum SectionState {
        case initial
        case addWarmupSets
        case updateRestTimers
    }
    
    let editStore: any ExerciseChildEditStore
    @Binding var replaceExercisePayload: ReplaceExercisePayload?
    let pageAnimation: Animation
    let close: (@escaping () -> Void) -> Void
    @State private var state: SectionState = .initial
    @State private var goingBack: Bool = false
    
    @State private var showReplaceExerciseSheet: Bool = false
    
    init(
        editStore: any ExerciseChildEditStore,
        replaceExercisePayload: Binding<ReplaceExercisePayload?>,
        pageAnimation: Animation,
        close: @escaping (@escaping () -> Void) -> Void,
    ) {
        self.editStore = editStore
        self._replaceExercisePayload = replaceExercisePayload
        self.pageAnimation = pageAnimation
        self.close = close
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
                insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .scale(scale: 0.7, anchor: goingBack ? .topLeading : .topTrailing)),
                removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .scale(scale: 0.7, anchor: goingBack ? .topTrailing : .topLeading))
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
                close {
                    editStore.addWarmupSets(3)
                }
            }
            
            labelView(title: "Update rest timers", image: "timer") {
                
            }
            
            labelView(title: "Replace exercise", image: "arrow.trianglehead.2.clockwise") {
                close {
                    replaceExercisePayload = .init(exerciseId: editStore.exerciseChildDTO.id)
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
    func addWarmupSetsView () -> some View {
        
    }
    
    @ViewBuilder
    func updateRestTimersView () -> some View {
        
    }
}


