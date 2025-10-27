import Foundation
import SwiftUI

struct ExercisePickerSheet: View {
    @EnvironmentObject private var appComp: AppComposition
    
    @Binding var isPresented: Bool
    @StateObject private var exercisePickerStore: ExercisePickerStore
    private let onConfirm: (Set<UUID>) -> Void
    private let onCancel: () -> Void
    private let config: ExercisePickerConfig
    
    init (
        isPresented: Binding<Bool>,
        config: ExercisePickerConfig,
        exerciseProvider: ExerciseProvider,
        muscleGroupProvider: MuscleGroupProvider,
        onConfirm: @escaping (Set<UUID>) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.config = config
        self._exercisePickerStore = StateObject(
            wrappedValue: .init(
                config: config,
                exerciseProvider: exerciseProvider,
                muscleGroupProvider: muscleGroupProvider
            )
        )
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack (spacing: 8) {
                ForEach(exercisePickerStore.sections) { section in
                    sectionView(section)
                }
            }
            .padding(.horizontal)
        }
        .interactiveDismissDisabled()
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, content: {
            topBar()
        })
        .safeAreaInset(edge: .bottom) {
            bottomBar()
        }
    }
    
    @ViewBuilder
    func topBar () -> some View {
        VStack (alignment: .leading, spacing: 8) {
            HStack {
                Text(config.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer(minLength: 8)
                
                CloseButton {
                    onCancel()
                }
            }
            
            SearchField(placeholder: "Search for exercise...", input: $exercisePickerStore.searchText)
                .frame(height: 55)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(false), in: .rect(cornerRadii: .init(bottomLeading: 12, bottomTrailing: 12)))
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
    }
    
    @ViewBuilder
    func bottomBar () -> some View {
        Button {
            onConfirm(exercisePickerStore.selected)
            isPresented = false
        } label: {
            Text("Add \(exercisePickerStore.selectionCount) exercises")
                .foregroundStyle(.white)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.indigo)
                }
        }
        .buttonStyle(.plain)
        .disabled(!exercisePickerStore.selectionValid)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func sectionView (_ section: SectionedByMuscleGroup) -> some View {
        VStack {
            HStack (alignment: .firstTextBaseline) {
                Text(section.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                    .padding(.leading)
                
                Spacer(minLength: 8)
                
                Text("\(section.items.count) exercises")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(.gray)
                    .padding(.trailing)
            }
            .frame(maxWidth: .infinity)
            
            ForEach (section.items) { exercise in
                exerciseRowView(exercise)
            }
        }
    }
    
    @ViewBuilder
    private func exerciseRowView (_ exercise: ExerciseDTO) -> some View {
        let isSelected = exercisePickerStore.isSelected(exercise.id)
        Button {
            exercisePickerStore.toggle(exercise.id)
        } label: {
            HStack {
                Text(appComp.exerciseLookupSource.name(for: exercise.id))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer(minLength: 8)
                Text(appComp.muscleGroupLookupSource.name(for: exercise.muscleGroupID))
                    .font(.caption)
                    .fontWeight(.bold)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .black : .gray)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.937, green: 0.937, blue: 0.937))
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
        }
        .buttonStyle(.plain)
    }
}
