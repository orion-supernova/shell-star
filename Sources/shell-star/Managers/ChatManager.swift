import Vapor

actor ChatManager {
    static let shared = ChatManager()

    private var rooms: [UUID: Room] = [:]
    private var webSockets: [UUID: [UUID: WebSocket]] = [:] // roomId: [userId: WebSocket]
    private var messageHistory: [UUID: [Message]] = [:] // roomId: [messages]
    private let maxMessagesPerRoom = 100 // Keep last 100 messages per room

    // Heartbeat tracking
    private var userHeartbeats: [UUID: [UUID: Int]] = [:] // roomId: [userId: missedHeartbeats]
    private let maxMissedHeartbeats = 3
    private var heartbeatTask: Task<Void, Never>?
    private var isHeartbeatStarted = false

    private init() {}
    
    // MARK: - Room Management
    
    func createRoom(name: String, password: String?) throws -> Room {
        let room = Room(name: name, password: password)
        rooms[room.id] = room
        return room
    }
    
    func getRoom(id: UUID) -> Room? {
        rooms[id]
    }
    
    func getAllRooms() -> [Room] {
        Array(rooms.values)
    }
    
    func deleteRoom(id: UUID) {
        if let sockets = webSockets[id] {
            for socket in sockets.values {
                try? socket.close()
            }
        }
        webSockets.removeValue(forKey: id)
        messageHistory.removeValue(forKey: id) // Clear message history
        userHeartbeats.removeValue(forKey: id) // Clear heartbeat tracking
        rooms.removeValue(forKey: id)
    }
    
    func deleteRoomIfEmpty(id: UUID) {
        if let room = rooms[id], room.isEmpty {
            deleteRoom(id: id)
        }
    }
    
    // MARK: - User Management
    
    func joinRoom(roomId: UUID, username: String, password: String?) throws -> (room: Room, user: User) {
        guard var room = rooms[roomId] else {
            throw Abort(.notFound, reason: "Room not found")
        }
        
        // Check password
        if let roomPassword = room.password {
            guard password == roomPassword else {
                throw Abort(.unauthorized, reason: "Invalid room password")
            }
        }
        
        // Check username uniqueness
        guard !room.hasUsername(username) else {
            throw Abort(.conflict, reason: "Username '\(username)' already exists in this room")
        }
        
        let user = User(username: username, roomId: roomId)
        try room.addUser(user)
        rooms[roomId] = room
        
        return (room, user)
    }
    
    func leaveRoom(roomId: UUID, userId: UUID) throws -> User? {
        guard var room = rooms[roomId] else {
            throw Abort(.notFound, reason: "Room not found")
        }
        
        let user = room.users.first { $0.id == userId }
        room.removeUser(userId: userId)
        rooms[roomId] = room
        
        // Remove WebSocket
        webSockets[roomId]?.removeValue(forKey: userId)
        
        // Delete room if empty
        deleteRoomIfEmpty(id: roomId)
        
        return user
    }
    
    func getUser(userId: UUID, in roomId: UUID) -> User? {
        rooms[roomId]?.users.first { $0.id == userId }
    }
    
    // MARK: - WebSocket Management

    func addWebSocket(_ ws: WebSocket, userId: UUID, roomId: UUID) {
        if webSockets[roomId] == nil {
            webSockets[roomId] = [:]
        }
        webSockets[roomId]?[userId] = ws

        // Initialize heartbeat tracking
        if userHeartbeats[roomId] == nil {
            userHeartbeats[roomId] = [:]
        }
        userHeartbeats[roomId]?[userId] = 0 // Reset missed heartbeats

        // Start heartbeat monitor on first WebSocket connection
        if !isHeartbeatStarted {
            startHeartbeatMonitor()
            isHeartbeatStarted = true
        }
    }

    func removeWebSocket(userId: UUID, roomId: UUID) {
        webSockets[roomId]?.removeValue(forKey: userId)
        userHeartbeats[roomId]?.removeValue(forKey: userId)
    }
    
    func broadcast(message: Message, to roomId: UUID, excludingUserId: UUID? = nil) async {
        // Store message in history
        addMessageToHistory(message, roomId: roomId)

        guard let sockets = webSockets[roomId] else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(message),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        for (userId, socket) in sockets {
            if let excludingUserId = excludingUserId, userId == excludingUserId {
                continue
            }
            try? await socket.send(text)
        }
    }

    // MARK: - Message History

    private func addMessageToHistory(_ message: Message, roomId: UUID) {
        if messageHistory[roomId] == nil {
            messageHistory[roomId] = []
        }

        messageHistory[roomId]?.append(message)

        // Keep only the last N messages
        if let count = messageHistory[roomId]?.count, count > maxMessagesPerRoom {
            messageHistory[roomId]?.removeFirst(count - maxMessagesPerRoom)
        }
    }

    func getMessageHistory(roomId: UUID, limit: Int? = nil) -> [Message] {
        guard let messages = messageHistory[roomId] else {
            return []
        }

        if let limit = limit {
            let startIndex = max(0, messages.count - limit)
            return Array(messages[startIndex...])
        }

        return messages
    }

    func sendToUser(message: Message, userId: UUID, in roomId: UUID) async {
        guard let socket = webSockets[roomId]?[userId] else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(message),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        try? await socket.send(text)
    }

    // MARK: - Heartbeat Monitor

    private func startHeartbeatMonitor() {
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                await checkHeartbeats()
            }
        }
    }

    private func checkHeartbeats() async {
        for (roomId, sockets) in webSockets {
            for (userId, socket) in sockets {
                // Try to ping the socket
                do {
                    try await socket.send("ping")
                    // Reset missed heartbeats on successful ping
                    userHeartbeats[roomId]?[userId] = 0
                } catch {
                    // Failed to ping, increment missed heartbeats
                    let currentMissed = userHeartbeats[roomId]?[userId] ?? 0
                    userHeartbeats[roomId]?[userId] = currentMissed + 1

                    // Check if max missed heartbeats exceeded
                    if currentMissed + 1 >= maxMissedHeartbeats {
                        print("⚠️  User \(userId) in room \(roomId) failed \(maxMissedHeartbeats) heartbeats, removing...")

                        // Close the socket
                        try? await socket.close()

                        // Remove user from room
                        if let user = try? await leaveRoom(roomId: roomId, userId: userId) {
                            let message = Message(
                                roomId: roomId,
                                userId: user.id,
                                username: user.username,
                                content: "\(user.username) left the room (connection timeout)",
                                type: .userLeft
                            )
                            await broadcast(message: message, to: roomId)
                        }
                    }
                }
            }
        }
    }

    deinit {
        heartbeatTask?.cancel()
    }
}