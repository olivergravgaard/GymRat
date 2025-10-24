import Foundation

public protocol RepositoryProtocol: Actor, Sendable {
    associatedtype DTO: Sendable
    
    func boot () async throws
    func snapshotDTOs () async -> [DTO]
    func streamDiffs () -> AsyncStream<EntityDiff<UUID>>
    func fetchDTOs (ids: [UUID]) async throws -> [DTO]
    func fetchDTOByName (_ name: String) async throws -> DTO?
}
