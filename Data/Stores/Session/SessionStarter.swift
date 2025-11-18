import Foundation

@MainActor
struct SessionStarter {
    let draftStore: SessionDraftStore

    enum Behavior {
        case ask
        case resume
        case overwrite
    }

    enum StartResult {
        case started(WorkoutSessionDTO)
        case conflict(active: WorkoutSessionDTO)
    }

    func startBlank(name: String, behavior: Behavior = .ask) async throws -> StartResult {
        try await start(intent: .blank(name: name), behavior: behavior)
    }

    func start(from template: WorkoutTemplateDTO, behavior: Behavior = .ask) async throws -> StartResult {
        try await start(intent: .fromTemplate(template), behavior: behavior)
    }

    func overwriteBlank(name: String, muscleGroupIDs: [UUID] = []) async throws -> WorkoutSessionDTO {
        await draftStore.clear()
        let dto = makeBlankDTO(name: name)
        await draftStore.replace(dto, persistImmediately: true)
        return dto
    }

    func overwrite(from template: WorkoutTemplateDTO) async throws -> WorkoutSessionDTO {
        await draftStore.clear()
        let dto = makeDTO(from: template)
        await draftStore.replace(dto, persistImmediately: true)
        return dto
    }

    func resumeActive() async -> WorkoutSessionDTO? {
        await draftStore.load()
    }

    private enum Intent {
        case blank(name: String)
        case fromTemplate(WorkoutTemplateDTO)
    }

    private func start(intent: Intent, behavior: Behavior) async throws -> StartResult {
        if let active = await draftStore.load() {
            switch behavior {
            case .resume:
                return .started(active)
            case .overwrite:
                await draftStore.clear()
                return .started(try await createAndPersist(intent))
            case .ask:
                return .conflict(active: active)
            }
        } else {
            return .started(try await createAndPersist(intent))
        }
    }

    private func createAndPersist(_ intent: Intent) async throws -> WorkoutSessionDTO {
        let dto: WorkoutSessionDTO
        
        switch intent {
            case .blank(let name):
                dto = makeBlankDTO(name: name)
            case .fromTemplate(let template):
                dto = makeDTO(from: template)
        }
        
        await draftStore.replace(dto, persistImmediately: true)
        
        return dto
    }

    private func makeBlankDTO(name: String) -> WorkoutSessionDTO {
        WorkoutSessionDTO(
            id: UUID(),
            name: name,
            startedAt: .now,
            endedAt: nil,
            muscleGroupIDs: [],
            exercises: [],
            version: 0
        )
    }

    private func makeDTO(from template: WorkoutTemplateDTO) -> WorkoutSessionDTO {
        let exercises = template.exerciseTemplates
            .sorted { $0.order < $1.order }
            .map { et in
                ExerciseSessionDTO(
                    id: UUID(),
                    exerciseId: et.exerciseId,
                    order: et.order,
                    settings: et.settings,
                    sets: et.sets
                        .sorted { $0.order < $1.order }
                        .map { st in
                            SetSessionDTO(
                                id: UUID(),
                                order: st.order,
                                weightTarget: st.weightTarget,
                                minReps: st.minReps,
                                maxReps: st.maxReps,
                                weight: 0.0,
                                reps: 0,
                                setType: st.setType,
                                performed: false,
                                restSession: (st.restTemplate == nil ? nil : .init(from: st.restTemplate!))
                            )
                        },
                    notes: et.notes
                )
            }

        return WorkoutSessionDTO(
            id: UUID(),
            name: template.name,
            startedAt: .now,
            endedAt: nil,
            muscleGroupIDs: template.muscleGroupsIDs,
            exercises: exercises,
            version: 0
        )
    }
}
