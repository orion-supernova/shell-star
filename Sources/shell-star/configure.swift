import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // Configure server hostname (port is set in entrypoint.swift)
    app.http.server.configuration.hostname = "0.0.0.0"

    // Enable CORS if needed
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors)
    
    // Register routes
    try routes(app)
}