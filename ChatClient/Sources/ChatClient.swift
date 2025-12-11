import Foundation
import WebSocketKit
import ArgumentParser
import NIOCore
import NIOPosix

@main
struct ChatClient: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat-client",
        abstract: "Terminal chat client for Vapor chat server"
    )
    
    @Option(name: .shortAndLong, help: "Server URL")
    var server: String = "http://localhost:8080"
    
    @Option(name: .shortAndLong, help: "Your username")
    var username: String?
    
    @Option(name: .shortAndLong, help: "Room ID to join (optional)")
    var room: String?
    
    func run() async throws {
        print("╔════════════════════════════════════════╗")
        print("║   Terminal Chat Client (Swift)        ║")
        print("╚════════════════════════════════════════╝")
        print("")
        
        let client = ChatAPIClient(baseURL: server)
        
        // Check server health
        print("🔍 Checking server connection...")
        guard await client.checkHealth() else {
            print("❌ Cannot connect to server at \(server)")
            print("💡 Please start the server with: swift run")
            throw ExitCode.failure
        }
        print("✅ Server is online\n")
        
        // Get username
        let username = self.username ?? readLine(prompt: "Enter your username: ")
        
        // List available rooms
        print("\n📋 Fetching available rooms...")
        let rooms = try await client.listRooms()
        
        if !rooms.isEmpty {
            print("\n💬 Available rooms:")
            for room in rooms {
                let lock = room.hasPassword ? "🔒" : "🔓"
                print("  \(lock) [\(room.userCount) users] \(room.name)")
                print("     ID: \(room.id)")
            }
            print("")
        } else {
            print("📭 No rooms available.\n")
        }
        
        // Create or join room
        let choice = readLine(prompt: "Do you want to (c)reate a new room or (j)oin an existing one? [c/j]: ")
        
        let roomId: String
        let roomName: String
        
        if choice.lowercased() == "c" {
            // Create room
            let name = readLine(prompt: "Enter room name: ")
            let password = readLine(prompt: "Enter password (leave empty for no password): ", secure: true)
            
            print("\n🔨 Creating room...")
            let room = try await client.createRoom(name: name, password: password.isEmpty ? nil : password)
            roomId = room.id
            roomName = room.name
            print("✅ Room created: \(roomName)")
        } else {
            // Join existing room
            roomId = self.room ?? readLine(prompt: "Enter room ID: ")
            let password = readLine(prompt: "Enter room password (if any): ", secure: true)
            
            print("\n🚪 Joining room...")
            let response = try await client.joinRoom(roomId: roomId, username: username, password: password.isEmpty ? nil : password)
            roomName = response.room.name
            print("✅ Joined '\(roomName)'")
            print("👥 Users in room: \(response.users.map { $0.username }.joined(separator: ", "))")
        }
        
        // Get userId
        guard let joinResponse = try? await client.joinRoom(roomId: roomId, username: username, password: nil) else {
            print("❌ Failed to get user ID")
            throw ExitCode.failure
        }
        
        let userId = joinResponse.userId
        
        print("\n💬 Loading chat interface...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Room: \(roomName) | User: @\(username)")
        print("Press Ctrl+C to exit")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        // Start chat session
        let chatSession = ChatSession(
            client: client,
            roomId: roomId,
            userId: userId,
            username: username,
            roomName: roomName
        )
        
        try await chatSession.start()
    }
    
    func readLine(prompt: String, secure: Bool = false) -> String {
        print(prompt, terminator: "")
        fflush(stdout)
        
        if secure {
            // Hide input for passwords
            let password = String(cString: getpass(""))
            return password
        } else {
            return Swift.readLine() ?? ""
        }
    }
}

// MARK: - Models

struct RoomResponse: Codable {
    let id: String
    let name: String
    let hasPassword: Bool
    let userCount: Int
    let createdAt: String
}

struct CreateRoomRequest: Codable {
    let name: String
    let password: String?
}

struct JoinRoomRequest: Codable {
    let username: String
    let password: String?
}

struct JoinRoomResponse: Codable {
    let userId: String
    let room: RoomResponse
    let users: [UserResponse]
}

struct UserResponse: Codable {
    let id: String
    let username: String
    let joinedAt: String
}

struct Message: Codable {
    let id: String
    let roomId: String
    let userId: String
    let username: String
    let content: String
    let timestamp: String
    let type: MessageType
}

enum MessageType: String, Codable {
    case message
    case userJoined
    case userLeft
    case system
}

struct SendMessageRequest: Codable {
    let content: String
}

// MARK: - API Client

actor ChatAPIClient {
    let baseURL: String
    
    init(baseURL: String) {
        self.baseURL = baseURL
    }
    
    func checkHealth() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    func listRooms() async throws -> [RoomResponse] {
        guard let url = URL(string: "\(baseURL)/api/rooms") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([RoomResponse].self, from: data)
    }
    
    func createRoom(name: String, password: String?) async throws -> RoomResponse {
        guard let url = URL(string: "\(baseURL)/api/rooms") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = CreateRoomRequest(name: name, password: password)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(RoomResponse.self, from: data)
    }
    
    func joinRoom(roomId: String, username: String, password: String?) async throws -> JoinRoomResponse {
        guard let url = URL(string: "\(baseURL)/api/rooms/\(roomId)/join") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = JoinRoomRequest(username: username, password: password)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(JoinRoomResponse.self, from: data)
    }
    
    func leaveRoom(roomId: String, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/rooms/\(roomId)/leave/\(userId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        _ = try await URLSession.shared.data(for: request)
    }
}

// MARK: - Chat Session

actor ChatSession {
    let client: ChatAPIClient
    let roomId: String
    let userId: String
    let username: String
    let roomName: String
    
    private var ws: WebSocket?
    
    init(client: ChatAPIClient, roomId: String, userId: String, username: String, roomName: String) {
        self.client = client
        self.roomId = roomId
        self.userId = userId
        self.username = username
        self.roomName = roomName
    }
    
    func start() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            try? eventLoopGroup.syncShutdownGracefully()
        }
        
        let wsURL = "ws://localhost:8080/ws/\(roomId)/\(userId)"
        
        try await WebSocket.connect(to: wsURL, on: eventLoopGroup) { ws in
            Task {
                await self.handleWebSocket(ws)
            }
        }.get()
    }
    
    private func handleWebSocket(_ ws: WebSocket) async {
        self.ws = ws
        
        // Handle incoming messages
        ws.onText { ws, text in
            Task {
                await self.handleMessage(text)
            }
        }
        
        ws.onClose.whenComplete { _ in
            print("\n\n🔌 Disconnected from server")
            exit(0)
        }
        
        // Handle user input
        Task {
            while true {
                if let line = readLine() {
                    await self.sendMessage(line)
                }
            }
        }
        
        // Keep running
        try? await Task.sleep(for: .seconds(999999))
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(Message.self, from: data) else {
            return
        }
        
        switch message.type {
        case .message:
            if message.username == username {
                print("💚 You: \(message.content)")
            } else {
                print("💙 \(message.username): \(message.content)")
            }
        case .userJoined:
            print("→ \(message.content)")
        case .userLeft:
            print("← \(message.content)")
        case .system:
            print("🔔 [SYSTEM] \(message.content)")
        }
    }
    
    private func sendMessage(_ content: String) async {
        guard !content.isEmpty, let ws = ws else { return }
        
        let message = SendMessageRequest(content: content)
        if let data = try? JSONEncoder().encode(message),
           let json = String(data: data, encoding: .utf8) {
            ws.send(json)
        }
    }
    
    deinit {
        Task {
            try? await client.leaveRoom(roomId: roomId, userId: userId)
        }
    }
}