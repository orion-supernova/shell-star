import Vapor

struct WebSocketController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
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

                // Don't remove user immediately - let heartbeat monitor handle it
                // This gives users a chance to reconnect (up to 30 seconds)
                req.logger.info("User \(user.username) marked as disconnected, waiting for reconnect or timeout...")
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