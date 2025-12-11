import Vapor

// Request DTOs
struct CreateRoomRequest: Content {
    let name: String
    let password: String?
    
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Room name cannot be empty")
        }
        guard name.count <= 50 else {
            throw Abort(.badRequest, reason: "Room name too long (max 50 characters)")
        }
    }
}

struct JoinRoomRequest: Content {
    let username: String
    let password: String?
    
    func validate() throws {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Username cannot be empty")
        }
        guard username.count <= 30 else {
            throw Abort(.badRequest, reason: "Username too long (max 30 characters)")
        }
    }
}

struct SendMessageRequest: Content {
    let content: String
    
    func validate() throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Message content cannot be empty")
        }
        guard content.count <= 1000 else {
            throw Abort(.badRequest, reason: "Message too long (max 1000 characters)")
        }
    }
}

// Response DTOs
struct RoomResponse: Content {
    let id: UUID
    let name: String
    let hasPassword: Bool
    let userCount: Int
    let createdAt: Date
    
    init(from room: Room) {
        self.id = room.id
        self.name = room.name
        self.hasPassword = room.password != nil
        self.userCount = room.users.count
        self.createdAt = room.createdAt
    }
}

struct JoinRoomResponse: Content {
    let userId: UUID
    let room: RoomResponse
    let users: [UserResponse]
}

struct UserResponse: Content {
    let id: UUID
    let username: String
    let joinedAt: Date
    
    init(from user: User) {
        self.id = user.id
        self.username = user.username
        self.joinedAt = user.joinedAt
    }
}

struct ErrorResponse: Content {
    let error: Bool
    let reason: String
    
    init(reason: String) {
        self.error = true
        self.reason = reason
    }
}

struct SuccessResponse: Content {
    let success: Bool
    let message: String
    
    init(message: String = "Success") {
        self.success = true
        self.message = message
    }
}