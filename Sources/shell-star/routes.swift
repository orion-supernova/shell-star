import Vapor

func routes(_ app: Application) throws {
    // Health check
    app.get { req async in
        return [
            "status": "running",
            "message": "Chat Server API",
            "version": "1.0.0"
        ]
    }
    
    app.get("health") { req async in
        return ["status": "healthy"]
    }
    
    // Register controllers
    try app.register(collection: RoomController())
    try app.register(collection: WebSocketController())
}