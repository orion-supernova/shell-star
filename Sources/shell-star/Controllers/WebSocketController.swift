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
                req.logger.info("WebSocket disconnected: User \(user.username) from room \(roomId)")

                // Remove user immediately when WebSocket closes
                // The client will rejoin if they reconnect
                if let leftUser = try? await ChatManager.shared.leaveRoom(roomId: roomId, userId: userId) {
                    let message = Message(
                        roomId: roomId,
                        userId: leftUser.id,
                        username: leftUser.username,
                        content: "\(leftUser.username) left the room",
                        type: .userLeft
                    )
                    await ChatManager.shared.broadcast(message: message, to: roomId)
                    req.logger.info("User \(user.username) removed from room \(roomId)")
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
        // Ignore ping/pong messages
        if text == "ping" || text == "pong" {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = text.data(using: .utf8),
              let messageRequest = try? decoder.decode(SendMessageRequest.self, from: data) else {
            logger.warning("Failed to decode message from user \(username)")
            // Send error back to user
            let errorMsg = ErrorResponse(reason: "Invalid message format")
            if let errorData = try? JSONEncoder().encode(errorMsg),
               let errorText = String(data: errorData, encoding: .utf8) {
                try? await ws.send(errorText)
            }
            return
        }

        do {
            try messageRequest.validate()
        } catch let error as Abort {
            logger.warning("Invalid message from user \(username): \(error.reason)")
            // Send validation error back to user
            let errorMsg = ErrorResponse(reason: error.reason)
            if let errorData = try? JSONEncoder().encode(errorMsg),
               let errorText = String(data: errorData, encoding: .utf8) {
                try? await ws.send(errorText)
            }
            return
        } catch {
            logger.warning("Invalid message from user \(username): \(error)")
            return
        }

        let message = Message(
            roomId: roomId,
            userId: userId,
            username: username,
            content: messageRequest.content.trimmingCharacters(in: .whitespacesAndNewlines),
            type: .message
        )

        // Broadcast to all users in the room
        await ChatManager.shared.broadcast(message: message, to: roomId)

        logger.info("Message broadcast from \(username) in room \(roomId)")
    }
}