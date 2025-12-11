import Vapor
import Logging
import NIOCore
import NIOPosix

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        // Interactive server setup
        print("╔════════════════════════════════════════╗")
        print("║          shell-star v1.0              ║")
        print("║    WebSocket Chat Server (Vapor)      ║")
        print("╚════════════════════════════════════════╝")
        print("")

        // Get port from user or use default
        let port = getPort()

        let app = try await Application.make(env)

        // Set the port
        app.http.server.configuration.port = port

        // This attempts to install NIO as the Swift Concurrency global executor.
        // You can enable it if you'd like to reduce the amount of context switching between NIO and Swift Concurrency.
        // Note: this has caused issues with some libraries that use `.wait()` and cleanly shutting down.
        // If enabled, you should be careful about calling async functions before this point as it can cause assertion failures.
        // let executorTakeoverSuccess = NIOSingletons.unsafeTryInstallSingletonPosixEventLoopGroupAsConcurrencyGlobalExecutor()
        // app.logger.debug("Tried to install SwiftNIO's EventLoopGroup as Swift's global concurrency executor", metadata: ["success": .stringConvertible(executorTakeoverSuccess)])
        
        do {
            try await configure(app)

            // Show startup message
            print("🚀 Server starting on http://\(app.http.server.configuration.hostname):\(port)")
            print("📡 WebSocket endpoint: ws://\(app.http.server.configuration.hostname):\(port)/ws")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("")

            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    static func getPort() -> Int {
        let defaultPort = 3169

        print("Enter server port (press Enter for default \(defaultPort)):")
        print("  💡 Common ports: 3169 (default), 8080, 3000")
        print("")

        guard let input = readLine(strippingNewline: true) else {
            print("✅ Using default port: \(defaultPort)\n")
            return defaultPort
        }

        let trimmed = input.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            print("✅ Using default port: \(defaultPort)\n")
            return defaultPort
        }

        guard let port = Int(trimmed), port >= 1024, port <= 65535 else {
            print("⚠️  Invalid port. Using default: \(defaultPort)\n")
            return defaultPort
        }

        print("✅ Using port: \(port)\n")
        return port
    }
}
