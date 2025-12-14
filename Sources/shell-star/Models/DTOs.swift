import Vapor

// Request DTOs
struct CreateRoomRequest: Content {
    let name: String
    let password: String?

    func validate() throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw Abort(.badRequest, reason: "Room name cannot be empty")
        }
        guard trimmedName.count >= 2 else {
            throw Abort(.badRequest, reason: "Room name too short (min 2 characters)")
        }
        guard trimmedName.count <= 100 else {
            throw Abort(.badRequest, reason: "Room name too long (max 100 characters)")
        }
        // Validate password if provided
        if let pwd = password, !pwd.isEmpty {
            guard pwd.count >= 4 else {
                throw Abort(.badRequest, reason: "Password too short (min 4 characters)")
            }
            guard pwd.count <= 128 else {
                throw Abort(.badRequest, reason: "Password too long (max 128 characters)")
            }
        }
    }
}

struct JoinRoomRequest: Content {
    let username: String
    let password: String?

    func validate() throws {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            throw Abort(.badRequest, reason: "Username cannot be empty")
        }
        guard trimmedUsername.count >= 2 else {
            throw Abort(.badRequest, reason: "Username too short (min 2 characters)")
        }
        guard trimmedUsername.count <= 50 else {
            throw Abort(.badRequest, reason: "Username too long (max 50 characters)")
        }
        // Basic validation: no special characters that could break things
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        guard trimmedUsername.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            throw Abort(.badRequest, reason: "Username contains invalid characters (only letters, numbers, spaces, -, _ allowed)")
        }
    }
}

struct SendMessageRequest: Content {
    let content: String

    func validate() throws {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw Abort(.badRequest, reason: "Message content cannot be empty")
        }
        guard trimmedContent.count <= 2000 else {
            throw Abort(.badRequest, reason: "Message too long (max 2000 characters)")
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