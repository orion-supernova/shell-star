import Vapor

struct User: Codable {
    let id: UUID
    let username: String
    let roomId: UUID
    let joinedAt: Date
    
    init(id: UUID = UUID(), username: String, roomId: UUID) {
        self.id = id
        self.username = username
        self.roomId = roomId
        self.joinedAt = Date()
    }
}

extension User: Content {}
extension User: Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}