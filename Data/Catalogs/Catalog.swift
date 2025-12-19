import Foundation
import CryptoKit

enum Catalog {
    static let muscleGroupNamespace: UUID = UUID(uuidString: "AAAAAAAA-DEAD-BEEF-DEAD-BEEFDEADBEEF")!
    static let exerciseNamespace: UUID = UUID(uuidString: "BBBBBBBB-DEAD-BEEF-DEAD-BEEFDEADBEEF")!
    
    static func uuidV5(namespace: UUID, idString: String) -> UUID {
        let namespaceBytes = withUnsafeBytes(of: namespace.uuid) { Array($0)}
        let idStringBytes = Array(idString.utf8)

        let data = Data(namespaceBytes + idStringBytes)
        let digest = Insecure.SHA1.hash(data: data)
        
        var uuidBytes = Array(digest.prefix(16))
        
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x50
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80

        let uuid = uuidBytes.withUnsafeBytes {
            UUID(uuid: $0.load(as: uuid_t.self))
        }
        return uuid
    }
}
