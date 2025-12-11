import Vapor

struct Message: Codable {
    let id: UUID
    let roomId: UUID
    let userId: UUID
    let username: String
    let content: String
    let timestamp: Date
    let type: MessageType
    
    init(
        id: UUID = UUID(),
        roomId: UUID,
        userId: UUID,
        username: String,
        content: String,
        type: MessageType = .message
    ) {
        self.id = id
        self.roomId = roomId
        self.userId = userId
        self.username = username
        self.content = content
        self.timestamp = Date()
        self.type = type
    }
}

enum MessageType: String, Codable {
    case message
    case userJoined
    case userLeft
    case system
}

extension Message: Content {}