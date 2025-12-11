import Vapor

struct RoomController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let rooms = routes.grouped("api", "rooms")

        rooms.get(use: listRooms)
        rooms.post(use: createRoom)
        rooms.get(":roomId", use: getRoom)
        rooms.post(":roomId", "join", use: joinRoom)
        rooms.delete(":roomId", "leave", ":userId", use: leaveRoom)
        rooms.get(":roomId", "users", use: getRoomUsers)
        rooms.get(":roomId", "messages", use: getMessages)
    }
    
    // GET /api/rooms - List all rooms
    @Sendable
    func listRooms(req: Request) async throws -> [RoomResponse] {
        let rooms = await ChatManager.shared.getAllRooms()
        return rooms.map { RoomResponse(from: $0) }
    }
    
    // POST /api/rooms - Create a new room
    @Sendable
    func createRoom(req: Request) async throws -> RoomResponse {
        let createRequest = try req.content.decode(CreateRoomRequest.self)
        try createRequest.validate()
        
        let room = try await ChatManager.shared.createRoom(
            name: createRequest.name,
            password: createRequest.password
        )
        
        return RoomResponse(from: room)
    }
    
    // GET /api/rooms/:roomId - Get room details
    @Sendable
    func getRoom(req: Request) async throws -> RoomResponse {
        guard let roomId = req.parameters.get("roomId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid room ID")
        }
        
        guard let room = await ChatManager.shared.getRoom(id: roomId) else {
            throw Abort(.notFound, reason: "Room not found")
        }
        
        return RoomResponse(from: room)
    }
    
    // POST /api/rooms/:roomId/join - Join a room
    @Sendable
    func joinRoom(req: Request) async throws -> JoinRoomResponse {
        guard let roomId = req.parameters.get("roomId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid room ID")
        }
        
        let joinRequest = try req.content.decode(JoinRoomRequest.self)
        try joinRequest.validate()
        
        let (room, user) = try await ChatManager.shared.joinRoom(
            roomId: roomId,
            username: joinRequest.username,
            password: joinRequest.password
        )
        
        // Broadcast user joined message
        let message = Message(
            roomId: roomId,
            userId: user.id,
            username: user.username,
            content: "\(user.username) joined the room",
            type: .userJoined
        )
        await ChatManager.shared.broadcast(message: message, to: roomId)
        
        return JoinRoomResponse(
            userId: user.id,
            room: RoomResponse(from: room),
            users: room.users.map { UserResponse(from: $0) }
        )
    }
    
    // DELETE /api/rooms/:roomId/leave/:userId - Leave a room
    @Sendable
    func leaveRoom(req: Request) async throws -> SuccessResponse {
        guard let roomId = req.parameters.get("roomId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid room ID")
        }
        
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        guard let user = try await ChatManager.shared.leaveRoom(roomId: roomId, userId: userId) else {
            throw Abort(.notFound, reason: "User not found in room")
        }
        
        // Broadcast user left message
        let message = Message(
            roomId: roomId,
            userId: user.id,
            username: user.username,
            content: "\(user.username) left the room",
            type: .userLeft
        )
        await ChatManager.shared.broadcast(message: message, to: roomId)
        
        return SuccessResponse(message: "Successfully left the room")
    }
    
    // GET /api/rooms/:roomId/users - Get all users in a room
    @Sendable
    func getRoomUsers(req: Request) async throws -> [UserResponse] {
        guard let roomId = req.parameters.get("roomId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid room ID")
        }

        guard let room = await ChatManager.shared.getRoom(id: roomId) else {
            throw Abort(.notFound, reason: "Room not found")
        }

        return room.users.map { UserResponse(from: $0) }
    }

    // GET /api/rooms/:roomId/messages - Get message history for a room
    @Sendable
    func getMessages(req: Request) async throws -> [Message] {
        guard let roomId = req.parameters.get("roomId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid room ID")
        }

        // Verify room exists
        guard await ChatManager.shared.getRoom(id: roomId) != nil else {
            throw Abort(.notFound, reason: "Room not found")
        }

        // Get optional limit query parameter
        let limit = try? req.query.get(Int.self, at: "limit")

        return await ChatManager.shared.getMessageHistory(roomId: roomId, limit: limit)
    }
}