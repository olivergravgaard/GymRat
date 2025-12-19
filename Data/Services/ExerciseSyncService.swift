import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class ExerciseSyncService: SyncServiceProtocol {
    private let exerciseRepo: ExerciseRepository
    private let muscleGroupRepo: MuscleGroupRepository
    let db: Firestore
    
    var debounceTask: Task<Void, Never>?
    let debounceInterval: Int = 5
    
    init (
        exerciseRepository: ExerciseRepository,
        muscleGroupRepository: MuscleGroupRepository,
        db: Firestore = Firestore.firestore()
    ) {
        self.exerciseRepo = exerciseRepository
        self.muscleGroupRepo = muscleGroupRepository
        self.db = db
    }
    
    func pullRemote (userId: String) async throws {
        let existingDTOs = await exerciseRepo.getDTOs()
        
        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("exercises")
            .getDocuments()
        
        let muscleGroupIDs = await muscleGroupRepo.snapshotDTOs().map(\.id)
        
        for doc in snapshot.documents {
            do {
                let remote = try doc.data(as: RemoteExerciseDTO.self)
                
                guard remote.origin == "custom" else { continue }
                
                guard let muscleGroupID = muscleGroupIDs.first(where: { $0.uuidString == remote.muscleGroupID}) else {
                    print("Missing MuscleGroup for id \(remote.muscleGroupID) - skipping.")
                    continue
                }
                
                try exerciseRepo.upsertFromRemote(
                    remote: remote,
                    muscleGroupId: muscleGroupID,
                    ownerId: userId
                )
                
                print("Pulled Exercise with name \(remote.name) from database")
            }catch {
                print("Failed to decode remote exercise: \(error)")
            }
        }
    }
    
    func pushRemote (userId: String) async throws {
        let pending = await exerciseRepo.pendingCustomExercises(for: userId)
        
        let muscleGroupDTOs = await muscleGroupRepo.snapshotDTOs()
        
        for exercise in pending {
            let remote = RemoteExerciseDTO(
                docId: exercise.id.uuidString,
                id: exercise.id.uuidString,
                name: exercise.name,
                muscleGroupID: exercise.muscleGroup.id.uuidString,
                origin: exercise.origin.rawValue,
                updatedAt: exercise.updatedAt,
                isDeleted: false
            )
            
            let ref = db
                .collection("users")
                .document(userId)
                .collection("exercises")
                .document(remote.id)
            
            try ref.setData(from: remote, merge: true)
            try exerciseRepo.markSynced(exercise)
            
            print("Pushed Exercise with name \(exercise.name) to database")
        }
    }
}
