import Vapor

struct Room: Codable {
    let id: UUID
    var name: String
    var password: String?
    var users: [User]
    let createdAt: Date
    
    init(id: UUID = UUID(), name: String, password: String?) {
        self.id = id
        self.name = name
        self.password = password
        self.users = []
        self.createdAt = Date()
    }
    
    mutating func addUser(_ user: User) throws {
        guard !users.contains(where: { $0.username == user.username }) else {
            throw Abort(.conflict, reason: "Username '\(user.username)' already exists in this room")
        }
        users.append(user)
    }
    
    mutating func removeUser(userId: UUID) {
        users.removeAll { $0.id == userId }
    }
    
    func hasUser(userId: UUID) -> Bool {
        users.contains { $0.id == userId }
    }
    
    func hasUsername(_ username: String) -> Bool {
        users.contains { $0.username == username }
    }
    
    var isEmpty: Bool {
        users.isEmpty
    }
}

extension Room: Content {}