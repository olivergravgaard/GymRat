import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class WorkoutTemplateSyncService: SyncServiceProtocol {
    private let workoutTemplateRepo: TemplateRepository
    let db: Firestore
    
    var debounceTask: Task<Void, Never>?
    var debounceInterval: Int = 5
    
    init(
        workoutTemplateRepo: TemplateRepository,
        db: Firestore = Firestore.firestore()
    ) {
        self.workoutTemplateRepo = workoutTemplateRepo
        self.db = db
    }
    
    func pullRemote (userId: String) async throws {
        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("workoutTemplates")
            .getDocuments()
        
        for doc in snapshot.documents {
            do {
                let remote = try doc.data(as: RemoteWorkoutTemplateDTO.self)
                
                try workoutTemplateRepo.upsertFromRemote(remote: remote, ownerId: userId)
            }catch {
                print("Failed to decode or upsert remote workout template: \(error)")
            }
        }
    }
    
    func pushRemote (userId: String) async throws {
        let pending = await workoutTemplateRepo.pendingTemplates(for: userId)
        guard !pending.isEmpty else { return }
        
        for workoutTemplate in pending {
            let remote = RemoteWorkoutTemplateDTO(
                docId: workoutTemplate.id.uuidString,
                id: workoutTemplate.id.uuidString,
                workoutTemplate: workoutTemplate,
                updatedAt: Date(),
                isDeleted: false
            )
            
            let ref = db
                .collection("users")
                .document(userId)
                .collection("workoutTemplates")
                .document(remote.id)
            
            try ref.setData(from: remote, merge: true)
            try workoutTemplateRepo.markSynced(workoutTemplate)
        }
    }
}
