import Vapor

struct WebSocketController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.webSocket("ws", ":roomId", ":userId", onUpgrade: handleWebSocket)
    }
    
    @Sendable
    func handleWebSocket(req: Request, ws: WebSocket) async {
        guard let roomId = req.parameters.get("roomId", as: UUID.self),
              let userId = req.parameters.get("userId", as: UUID.self) else {
            try? await ws.close(code: .normalClosure)
            return
        }
        
        // Verify user is in the room
        guard let user = await ChatManager.shared.getUser(userId: userId, in: roomId) else {
            try? await ws.close(code: .normalClosure)
            return
        }
        
        // Add WebSocket to manager
        await ChatManager.shared.addWebSocket(ws, userId: userId, roomId: roomId)
        
        req.logger.info("WebSocket connected: User \(user.username) in room \(roomId)")
        
        // Handle incoming messages
        ws.onText { ws, text in
            await handleIncomingMessage(text: text, ws: ws, userId: userId, roomId: roomId, username: user.username, logger: req.logger)
        }
        
        // Handle connection close
        ws.onClose.whenComplete { _ in
            Task {
                await ChatManager.shared.removeWebSocket(userId: userId, roomId: roomId)
                req.logger.info("WebSocket disconnected: User \(user.username) from room \(roomId)")

                // Remove user from room after disconnect
                do {
                    if let removedUser = try await ChatManager.shared.leaveRoom(roomId: roomId, userId: userId) {
                        // Broadcast user left message
                        let message = Message(
                            roomId: roomId,
                            userId: removedUser.id,
                            username: removedUser.username,
                            content: "\(removedUser.username) left the room (disconnected)",
                            type: .userLeft
                        )
                        await ChatManager.shared.broadcast(message: message, to: roomId)
                        req.logger.info("User \(removedUser.username) removed from room \(roomId) after disconnect")
                    }
                } catch {
                    req.logger.error("Failed to remove user \(userId) from room \(roomId): \(error)")
                }
            }
        }
    }
    
    @Sendable
    private func handleIncomingMessage(
        text: String,
        ws: WebSocket,
        userId: UUID,
        roomId: UUID,
        username: String,
        logger: Logger
    ) async {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let data = text.data(using: .utf8),
              let messageRequest = try? decoder.decode(SendMessageRequest.self, from: data) else {
            logger.warning("Failed to decode message from user \(username)")
            return
        }
        
        do {
            try messageRequest.validate()
        } catch {
            logger.warning("Invalid message from user \(username): \(error)")
            return
        }
        
        let message = Message(
            roomId: roomId,
            userId: userId,
            username: username,
            content: messageRequest.content,
            type: .message
        )
        
        // Broadcast to all users in the room
        await ChatManager.shared.broadcast(message: message, to: roomId)
        
        logger.info("Message broadcast from \(username) in room \(roomId)")
    }
}