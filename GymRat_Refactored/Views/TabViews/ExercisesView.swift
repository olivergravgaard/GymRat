import SwiftUI
import Foundation

private enum ExerciseRoute: Hashable {
    case editExercise(UUID)
}

struct ExercisesView: View {
    @EnvironmentObject private var appComp: AppComposition
    @EnvironmentObject var tabActions: TabActionCenter
    
    @ObservedObject var filterStore: ExerciseFilterStore
    
    @State private var showCreateExerciseSheet: Bool = false
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack (path: $path) {
            ScrollView(.vertical) {
                LazyVStack (spacing: 8) {
                    ForEach(filterStore.sections) { section in
                        SectionHeader(title: section.title, count: section.items.count)
                        
                        ForEach(section.items) { exercise in
                            NavigationLink(value: ExerciseRoute.editExercise(exercise.id)) {
                                ExerciseRowView(exercise: exercise)
                                    .equatable()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .fadedBottomSafeArea()
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top) {
                TopBar(filterStore: filterStore)
                    .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: [.top])
            .navigationDestination(for: ExerciseRoute.self) { route in
                switch route {
                    case .editExercise(let id):
                    if let exerciseDTO = filterStore.allExercises.first(where: { $0.id == id}) {
                        let editStore = ExerciseFormStore(
                            mode: .edit(exercise: exerciseDTO),
                            exerciseProvider: appComp.exerciseProvider,
                            muscleGroupProvider: appComp.muscleGroupProvider
                        )
                        
                        EditExerciseView(
                            editStore: editStore,
                            originalDTO: exerciseDTO
                        )
                        .navigationBarBackButtonHidden()
                    }else {
                        Text("Template not found")
                    }
                }
            }
        }
        .onAppear(perform: {
            tabActions.register(.exercises) {
                showCreateExerciseSheet.toggle()
            }
        })
        .onDisappear(perform: {
            tabActions.unregister(.exercises)
        })
        .sheet(isPresented: $showCreateExerciseSheet) {
            CreateExerciseSheet(
                isPresented: $showCreateExerciseSheet,
                exerciseProvider: appComp.exerciseProvider,
                muscleGroupProvider: appComp.muscleGroupProvider
            )
        }
    }
}

fileprivate struct TopBar: View {
    
    @ObservedObject var filterStore: ExerciseFilterStore
    
    var body: some View {
        VStack (alignment: .leading, spacing: 8) {
            Text("Exercises")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            SearchField(placeholder: "Search for exercise", input: $filterStore.searchText)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .padding(.top, 55)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadii: .init(bottomLeading: 12, bottomTrailing: 12)))
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
    }
}

fileprivate struct SectionHeader: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack (alignment: .firstTextBaseline) {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
                .padding(.leading)
            
            Spacer(minLength: 8)
            
            Text("\(count) exercises")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.gray)
                .padding(.trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

fileprivate struct ExerciseRowView: View, Equatable {
    
    @EnvironmentObject var appComp: AppComposition
    let exercise: ExerciseDTO
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.exercise == rhs.exercise
    }
    
    var body: some View {
        HStack {
            Text(appComp.exerciseLookupSource.name(for: exercise.id))
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer(minLength: 8)
            Text(appComp.muscleGroupLookupSource.name(for: exercise.muscleGroupID))
                .font(.caption)
                .fontWeight(.bold)
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
}

