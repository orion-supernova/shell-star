import XCTest
import Vapor
@testable import testVapor

final class ChatServerTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
        app = nil
    }
    
    func testHealthCheck() async throws {
        try await app.test(.GET, "health") { res async in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode([String: String].self)
            XCTAssertEqual(response["status"], "healthy")
        }
    }
    
    func testListRoomsEmpty() async throws {
        try await app.test(.GET, "api/rooms") { res async in
            XCTAssertEqual(res.status, .ok)
            let rooms = try res.content.decode([RoomResponse].self)
            XCTAssertTrue(rooms.isEmpty)
        }
    }
    
    func testCreateRoom() async throws {
        let createRequest = CreateRoomRequest(name: "Test Room", password: nil)
        
        try await app.test(.POST, "api/rooms", beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            let room = try res.content.decode(RoomResponse.self)
            XCTAssertEqual(room.name, "Test Room")
            XCTAssertFalse(room.hasPassword)
            XCTAssertEqual(room.userCount, 0)
        }
    }
    
    func testCreateRoomWithPassword() async throws {
        let createRequest = CreateRoomRequest(name: "Secret Room", password: "secret123")
        
        try await app.test(.POST, "api/rooms", beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            let room = try res.content.decode(RoomResponse.self)
            XCTAssertEqual(room.name, "Secret Room")
            XCTAssertTrue(room.hasPassword)
        }
    }
    
    func testJoinRoom() async throws {
        // First create a room
        let createRequest = CreateRoomRequest(name: "Test Room", password: nil)
        var roomId: UUID?
        
        try await app.test(.POST, "api/rooms", beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { res async in
            let room = try res.content.decode(RoomResponse.self)
            roomId = room.id
        }
        
        guard let roomId = roomId else {
            XCTFail("Room ID is nil")
            return
        }
        
        // Join the room
        let joinRequest = JoinRoomRequest(username: "TestUser", password: nil)
        
        try await app.test(.POST, "api/rooms/\(roomId)/join", beforeRequest: { req in
            try req.content.encode(joinRequest)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(JoinRoomResponse.self)
            XCTAssertEqual(response.room.userCount, 1)
            XCTAssertEqual(response.users.count, 1)
            XCTAssertEqual(response.users[0].username, "TestUser")
        }
    }
    
    func testJoinRoomWithDuplicateUsername() async throws {
        // Create room
        let createRequest = CreateRoomRequest(name: "Test Room", password: nil)
        var roomId: UUID?
        
        try await app.test(.POST, "api/rooms", beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { res async in
            let room = try res.content.decode(RoomResponse.self)
            roomId = room.id
        }
        
        guard let roomId = roomId else {
            XCTFail("Room ID is nil")
            return
        }
        
        // First user joins
        let joinRequest1 = JoinRoomRequest(username: "TestUser", password: nil)
        try await app.test(.POST, "api/rooms/\(roomId)/join", beforeRequest: { req in
            try req.content.encode(joinRequest1)
        }) { _ async in }
        
        // Second user tries to join with same username
        let joinRequest2 = JoinRoomRequest(username: "TestUser", password: nil)
        try await app.test(.POST, "api/rooms/\(roomId)/join", beforeRequest: { req in
            try req.content.encode(joinRequest2)
        }) { res async in
            XCTAssertEqual(res.status, .conflict)
        }
    }
    
    func testLeaveRoom() async throws {
        // Create room and join
        let createRequest = CreateRoomRequest(name: "Test Room", password: nil)
        var roomId: UUID?
        var userId: UUID?
        
        try await app.test(.POST, "api/rooms", beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { res async in
            let room = try res.content.decode(RoomResponse.self)
            roomId = room.id
        }
        
        guard let roomId = roomId else {
            XCTFail("Room ID is nil")
            return
        }
        
        let joinRequest = JoinRoomRequest(username: "TestUser", password: nil)
        try await app.test(.POST, "api/rooms/\(roomId)/join", beforeRequest: { req in
            try req.content.encode(joinRequest)
        }) { res async in
            let response = try res.content.decode(JoinRoomResponse.self)
            userId = response.userId
        }
        
        guard let userId = userId else {
            XCTFail("User ID is nil")
            return
        }
        
        // Leave the room
        try await app.test(.DELETE, "api/rooms/\(roomId)/leave/\(userId)") { res async in
            XCTAssertEqual(res.status, .ok)
        }
        
        // Room should be deleted (empty)
        try await app.test(.GET, "api/rooms/\(roomId)") { res async in
            XCTAssertEqual(res.status, .notFound)
        }
    }
    
    func testRoomWithPassword() async throws {
        // Create password-protected room
        let createRequest = CreateRoomRequest(name: "Secret Room", password: "secret123")
        var roomId: UUID?
        
        try await app.test(.POST, "api/rooms", beforeRequest: { req in
            try req.content.encode(createRequest)
        }) { res async in
            let room = try res.content.decode(RoomResponse.self)
            roomId = room.id
        }
        
        guard let roomId = roomId else {
            XCTFail("Room ID is nil")
            return
        }
        
        // Try to join without password
        let joinRequestNoPassword = JoinRoomRequest(username: "TestUser", password: nil)
        try await app.test(.POST, "api/rooms/\(roomId)/join", beforeRequest: { req in
            try req.content.encode(joinRequestNoPassword)
        }) { res async in
            XCTAssertEqual(res.status, .unauthorized)
        }
        
        // Try with wrong password
        let joinRequestWrongPassword = JoinRoomRequest(username: "TestUser", password: "wrong")
        try await app.test(.POST, "api/rooms/\(roomId)/join", beforeRequest: { req in
            try req.content.encode(joinRequestWrongPassword)
        }) { res async in
            XCTAssertEqual(res.status, .unauthorized)
        }
        
        // Join with correct password
        let joinRequestCorrect = JoinRoomRequest(username: "TestUser", password: "secret123")
        try await app.test(.POST, "api/rooms/\(roomId)/join", beforeRequest: { req in
            try req.content.encode(joinRequestCorrect)
        }) { res async in
            XCTAssertEqual(res.status, .ok)
        }
    }
}