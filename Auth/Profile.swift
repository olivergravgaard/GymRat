import Foundation
import FirebaseFirestore

struct Profile: Identifiable, Equatable {
    let id: String
    let email: String
    let username: String
    let firstname: String
    let lastname: String
    let createdAt: Date?
    let followersCount: Int
    let followingCount: Int
    
    var fullname: String {
        "\(firstname) \(lastname)"
    }
    
    init (
        id: String,
        email: String,
        username: String,
        firstname: String,
        lastname: String,
        createdAt: Date? = nil,
        followersCount: Int,
        followingCount: Int
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.firstname = firstname
        self.lastname = lastname
        self.createdAt = createdAt
        self.followersCount = 0
        self.followingCount = 0
    }
    
    init? (doc: DocumentSnapshot) {
        guard let data = doc.data(),
                let email = data["email"] as? String,
              let username = data["username"] as? String,
              let firstname = data["firstname"] as? String,
              let lastname = data["lastname"] as? String
        else {
            return nil
        }
        
        let timestamp = data["createdAt"] as? Timestamp
        let followersCount = data["followersCount"] as? Int ?? 0
        let followingCount = data["followingCount"] as? Int ?? 0
        
        self.init(
            id: doc.documentID,
            email: email,
            username: username,
            firstname: firstname,
            lastname: lastname,
            createdAt: timestamp?.dateValue(),
            followersCount: followersCount,
            followingCount: followingCount
        )
    }
}
