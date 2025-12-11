{
  "api": {
    "name": "Chat Server API",
    "version": "1.0.0",
    "description": "Real-time chat server built with Vapor (Swift web framework) for terminal and web applications",
    "baseUrl": "http://localhost:8080",
    "protocol": "HTTP/1.1 + WebSocket",
    "contentType": "application/json",
    "dateFormat": "ISO 8601"
  },
  "features": [
    "No authentication required",
    "Room-based chat system",
    "Optional password protection for rooms",
    "Per-room unique usernames",
    "Real-time WebSocket messaging",
    "Automatic room and user cleanup",
    "Thread-safe with Swift Actors",
    "Comprehensive input validation",
    "CORS enabled for web clients",
    "System notifications (join/leave)",
    "Message broadcasting to all room participants"
  ],
  "technology": {
    "language": "Swift 6.0",
    "framework": "Vapor 4.115.0+",
    "networking": "Swift NIO (Non-blocking I/O)",
    "concurrency": "Swift Actors",
    "websocket": "RFC 6455 compliant",
    "platform": "macOS 13+, Linux"
  },
  "endpoints": {
    "rest": [
      {
        "method": "GET",
        "path": "/",
        "name": "Root Endpoint",
        "description": "Server status and basic information",
        "authentication": "none",
        "requestBody": null,
        "responseBody": {
          "status": "running",
          "message": "Chat Server API",
          "version": "1.0.0"
        },
        "responseCode": 200,
        "example": {
          "curl": "curl http://localhost:8080/",
          "response": "{\n  \"status\": \"running\",\n  \"message\": \"Chat Server API\",\n  \"version\": \"1.0.0\"\n}"
        }
      },
      {
        "method": "GET",
        "path": "/health",
        "name": "Health Check",
        "description": "Simple health check endpoint for monitoring",
        "authentication": "none",
        "requestBody": null,
        "responseBody": {
          "status": "healthy"
        },
        "responseCode": 200,
        "example": {
          "curl": "curl http://localhost:8080/health",
          "response": "{\n  \"status\": \"healthy\"\n}"
        }
      },
      {
        "method": "GET",
        "path": "/api/rooms",
        "name": "List All Rooms",
        "description": "Retrieve a list of all available chat rooms",
        "authentication": "none",
        "requestBody": null,
        "responseBody": [
          {
            "id": "UUID",
            "name": "string",
            "hasPassword": "boolean",
            "userCount": "integer",
            "createdAt": "ISO8601 date string"
          }
        ],
        "responseCode": 200,
        "example": {
          "curl": "curl http://localhost:8080/api/rooms",
          "response": "[\n  {\n    \"id\": \"550e8400-e29b-41d4-a716-446655440000\",\n    \"name\": \"General Chat\",\n    \"hasPassword\": false,\n    \"userCount\": 5,\n    \"createdAt\": \"2024-01-15T10:30:00Z\"\n  },\n  {\n    \"id\": \"660e8400-e29b-41d4-a716-446655440001\",\n    \"name\": \"Private Room\",\n    \"hasPassword\": true,\n    \"userCount\": 2,\n    \"createdAt\": \"2024-01-15T11:00:00Z\"\n  }\n]"
        },
        "errors": []
      },
      {
        "method": "POST",
        "path": "/api/rooms",
        "name": "Create Room",
        "description": "Create a new chat room with optional password protection",
        "authentication": "none",
        "requestBody": {
          "name": "string (required, max 50 chars)",
          "password": "string (optional)"
        },
        "responseBody": {
          "id": "UUID",
          "name": "string",
          "hasPassword": "boolean",
          "userCount": "integer",
          "createdAt": "ISO8601 date string"
        },
        "responseCode": 200,
        "example": {
          "curl": "curl -X POST http://localhost:8080/api/rooms \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"My Room\",\"password\":\"secret123\"}'",
          "request": "{\n  \"name\": \"My Room\",\n  \"password\": \"secret123\"\n}",
          "response": "{\n  \"id\": \"770e8400-e29b-41d4-a716-446655440002\",\n  \"name\": \"My Room\",\n  \"hasPassword\": true,\n  \"userCount\": 0,\n  \"createdAt\": \"2024-01-15T12:00:00Z\"\n}"
        },
        "errors": [
          {
            "code": 400,
            "reason": "Room name cannot be empty"
          },
          {
            "code": 400,
            "reason": "Room name too long (max 50 characters)"
          }
        ]
      },
      {
        "method": "GET",
        "path": "/api/rooms/:roomId",
        "name": "Get Room Details",
        "description": "Get detailed information about a specific room",
        "authentication": "none",
        "parameters": {
          "roomId": "UUID (required)"
        },
        "requestBody": null,
        "responseBody": {
          "id": "UUID",
          "name": "string",
          "hasPassword": "boolean",
          "userCount": "integer",
          "createdAt": "ISO8601 date string"
        },
        "responseCode": 200,
        "example": {
          "curl": "curl http://localhost:8080/api/rooms/550e8400-e29b-41d4-a716-446655440000",
          "response": "{\n  \"id\": \"550e8400-e29b-41d4-a716-446655440000\",\n  \"name\": \"General Chat\",\n  \"hasPassword\": false,\n  \"userCount\": 5,\n  \"createdAt\": \"2024-01-15T10:30:00Z\"\n}"
        },
        "errors": [
          {
            "code": 400,
            "reason": "Invalid room ID"
          },
          {
            "code": 404,
            "reason": "Room not found"
          }
        ]
      },
      {
        "method": "POST",
        "path": "/api/rooms/:roomId/join",
        "name": "Join Room",
        "description": "Join an existing room with a username and optional password",
        "authentication": "none",
        "parameters": {
          "roomId": "UUID (required)"
        },
        "requestBody": {
          "username": "string (required, max 30 chars)",
          "password": "string (optional, required if room has password)"
        },
        "responseBody": {
          "userId": "UUID",
          "room": {
            "id": "UUID",
            "name": "string",
            "hasPassword": "boolean",
            "userCount": "integer",
            "createdAt": "ISO8601 date string"
          },
          "users": [
            {
              "id": "UUID",
              "username": "string",
              "joinedAt": "ISO8601 date string"
            }
          ]
        },
        "responseCode": 200,
        "example": {
          "curl": "curl -X POST http://localhost:8080/api/rooms/550e8400-e29b-41d4-a716-446655440000/join \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"username\":\"john_doe\",\"password\":\"secret123\"}'",
          "request": "{\n  \"username\": \"john_doe\",\n  \"password\": \"secret123\"\n}",
          "response": "{\n  \"userId\": \"880e8400-e29b-41d4-a716-446655440003\",\n  \"room\": {\n    \"id\": \"550e8400-e29b-41d4-a716-446655440000\",\n    \"name\": \"General Chat\",\n    \"hasPassword\": false,\n    \"userCount\": 6,\n    \"createdAt\": \"2024-01-15T10:30:00Z\"\n  },\n  \"users\": [\n    {\n      \"id\": \"880e8400-e29b-41d4-a716-446655440003\",\n      \"username\": \"john_doe\",\n      \"joinedAt\": \"2024-01-15T12:30:00Z\"\n    },\n    {\n      \"id\": \"990e8400-e29b-41d4-a716-446655440004\",\n      \"username\": \"jane_smith\",\n      \"joinedAt\": \"2024-01-15T12:15:00Z\"\n    }\n  ]\n}"
        },
        "errors": [
          {
            "code": 400,
            "reason": "Invalid room ID"
          },
          {
            "code": 400,
            "reason": "Username cannot be empty"
          },
          {
            "code": 400,
            "reason": "Username too long (max 30 characters)"
          },
          {
            "code": 401,
            "reason": "Invalid room password"
          },
          {
            "code": 404,
            "reason": "Room not found"
          },
          {
            "code": 409,
            "reason": "Username 'john_doe' already exists in this room"
          }
        ]
      },
      {
        "method": "DELETE",
        "path": "/api/rooms/:roomId/leave/:userId",
        "name": "Leave Room",
        "description": "Leave a room and disconnect from chat",
        "authentication": "none",
        "parameters": {
          "roomId": "UUID (required)",
          "userId": "UUID (required)"
        },
        "requestBody": null,
        "responseBody": {
          "success": true,
          "message": "Successfully left the room"
        },
        "responseCode": 200,
        "example": {
          "curl": "curl -X DELETE http://localhost:8080/api/rooms/550e8400-e29b-41d4-a716-446655440000/leave/880e8400-e29b-41d4-a716-446655440003",
          "response": "{\n  \"success\": true,\n  \"message\": \"Successfully left the room\"\n}"
        },
        "errors": [
          {
            "code": 400,
            "reason": "Invalid room ID"
          },
          {
            "code": 400,
            "reason": "Invalid user ID"
          },
          {
            "code": 404,
            "reason": "Room not found"
          },
          {
            "code": 404,
            "reason": "User not found in room"
          }
        ]
      },
      {
        "method": "GET",
        "path": "/api/rooms/:roomId/users",
        "name": "Get Room Users",
        "description": "Get a list of all users currently in a room",
        "authentication": "none",
        "parameters": {
          "roomId": "UUID (required)"
        },
        "requestBody": null,
        "responseBody": [
          {
            "id": "UUID",
            "username": "string",
            "joinedAt": "ISO8601 date string"
          }
        ],
        "responseCode": 200,
        "example": {
          "curl": "curl http://localhost:8080/api/rooms/550e8400-e29b-41d4-a716-446655440000/users",
          "response": "[\n  {\n    \"id\": \"880e8400-e29b-41d4-a716-446655440003\",\n    \"username\": \"john_doe\",\n    \"joinedAt\": \"2024-01-15T12:30:00Z\"\n  },\n  {\n    \"id\": \"990e8400-e29b-41d4-a716-446655440004\",\n    \"username\": \"jane_smith\",\n    \"joinedAt\": \"2024-01-15T12:15:00Z\"\n  }\n]"
        },
        "errors": [
          {
            "code": 400,
            "reason": "Invalid room ID"
          },
          {
            "code": 404,
            "reason": "Room not found"
          }
        ]
      }
    ],
    "websocket": {
      "url": "ws://localhost:8080/ws/:roomId/:userId",
      "protocol": "WebSocket (RFC 6455)",
      "description": "Real-time bidirectional communication for chat messages",
      "authentication": "User must have already joined the room via REST API",
      "parameters": {
        "roomId": "UUID (required) - The room to connect to",
        "userId": "UUID (required) - The user ID obtained from joining the room"
      },
      "connectionFlow": [
        "1. Join room via POST /api/rooms/:roomId/join to get userId",
        "2. Connect to WebSocket at ws://localhost:8080/ws/:roomId/:userId",
        "3. Server validates user is in the room",
        "4. Connection established - ready to send/receive messages",
        "5. On disconnect, call DELETE /api/rooms/:roomId/leave/:userId"
      ],
      "sendingMessages": {
        "description": "Send JSON message through WebSocket",
        "format": {
          "content": "string (required, max 1000 chars)"
        },
        "example": "{\n  \"content\": \"Hello everyone!\"\n}",
        "validation": [
          "Content cannot be empty",
          "Content max length is 1000 characters"
        ]
      },
      "receivingMessages": {
        "description": "Messages are broadcast to all users in the room",
        "format": {
          "id": "UUID",
          "roomId": "UUID",
          "userId": "UUID",
          "username": "string",
          "content": "string",
          "timestamp": "ISO8601 date string",
          "type": "message | userJoined | userLeft | system"
        },
        "messageTypes": [
          {
            "type": "message",
            "description": "Regular chat message from a user",
            "example": "{\n  \"id\": \"aa0e8400-e29b-41d4-a716-446655440005\",\n  \"roomId\": \"550e8400-e29b-41d4-a716-446655440000\",\n  \"userId\": \"880e8400-e29b-41d4-a716-446655440003\",\n  \"username\": \"john_doe\",\n  \"content\": \"Hello everyone!\",\n  \"timestamp\": \"2024-01-15T12:35:00Z\",\n  \"type\": \"message\"\n}"
          },
          {
            "type": "userJoined",
            "description": "System notification when a user joins the room",
            "example": "{\n  \"id\": \"bb0e8400-e29b-41d4-a716-446655440006\",\n  \"roomId\": \"550e8400-e29b-41d4-a716-446655440000\",\n  \"userId\": \"990e8400-e29b-41d4-a716-446655440004\",\n  \"username\": \"jane_smith\",\n  \"content\": \"jane_smith joined the room\",\n  \"timestamp\": \"2024-01-15T12:40:00Z\",\n  \"type\": \"userJoined\"\n}"
          },
          {
            "type": "userLeft",
            "description": "System notification when a user leaves the room",
            "example": "{\n  \"id\": \"cc0e8400-e29b-41d4-a716-446655440007\",\n  \"roomId\": \"550e8400-e29b-41d4-a716-446655440000\",\n  \"userId\": \"880e8400-e29b-41d4-a716-446655440003\",\n  \"username\": \"john_doe\",\n  \"content\": \"john_doe left the room\",\n  \"timestamp\": \"2024-01-15T12:45:00Z\",\n  \"type\": \"userLeft\"\n}"
          },
          {
            "type": "system",
            "description": "System-wide announcements or notifications",
            "example": "{\n  \"id\": \"dd0e8400-e29b-41d4-a716-446655440008\",\n  \"roomId\": \"550e8400-e29b-41d4-a716-446655440000\",\n  \"userId\": \"00000000-0000-0000-0000-000000000000\",\n  \"username\": \"system\",\n  \"content\": \"Server maintenance in 5 minutes\",\n  \"timestamp\": \"2024-01-15T12:50:00Z\",\n  \"type\": \"system\"\n}"
          }
        ]
      },
      "examples": {
        "javascript": "const ws = new WebSocket('ws://localhost:8080/ws/550e8400-e29b-41d4-a716-446655440000/880e8400-e29b-41d4-a716-446655440003');\n\nws.onopen = () => {\n  console.log('Connected to chat');\n  ws.send(JSON.stringify({ content: 'Hello!' }));\n};\n\nws.onmessage = (event) => {\n  const message = JSON.parse(event.data);\n  console.log(`${message.username}: ${message.content}`);\n};\n\nws.onerror = (error) => {\n  console.error('WebSocket error:', error);\n};\n\nws.onclose = () => {\n  console.log('Disconnected from chat');\n};",
        "python": "import websocket\nimport json\n\ndef on_message(ws, message):\n    data = json.loads(message)\n    print(f\"{data['username']}: {data['content']}\")\n\ndef on_open(ws):\n    print('Connected to chat')\n    ws.send(json.dumps({'content': 'Hello!'}))\n\ndef on_error(ws, error):\n    print(f'Error: {error}')\n\ndef on_close(ws):\n    print('Disconnected from chat')\n\nws = websocket.WebSocketApp(\n    'ws://localhost:8080/ws/550e8400-e29b-41d4-a716-446655440000/880e8400-e29b-41d4-a716-446655440003',\n    on_message=on_message,\n    on_open=on_open,\n    on_error=on_error,\n    on_close=on_close\n)\n\nws.run_forever()",
        "swift": "import Foundation\n\nlet url = URL(string: \"ws://localhost:8080/ws/550e8400-e29b-41d4-a716-446655440000/880e8400-e29b-41d4-a716-446655440003\")!\nlet ws = URLSessionWebSocketTask(url: url)\n\nfunc receiveMessage() {\n    ws.receive { result in\n        switch result {\n        case .success(let message):\n            switch message {\n            case .string(let text):\n                if let data = text.data(using: .utf8),\n                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {\n                    print(\"\\(json[\"username\"] ?? \"\"): \\(json[\"content\"] ?? \"\")\")\n                }\n            case .data(let data):\n                print(\"Received data: \\(data)\")\n            @unknown default:\n                break\n            }\n            receiveMessage()\n        case .failure(let error):\n            print(\"Error: \\(error)\")\n        }\n    }\n}\n\nws.resume()\nreceiveMessage()\n\nlet message = [\"content\": \"Hello!\"]\nif let data = try? JSONSerialization.data(withJSONObject: message),\n   let text = String(data: data, encoding: .utf8) {\n    ws.send(.string(text)) { error in\n        if let error = error {\n            print(\"Send error: \\(error)\")\n        }\n    }\n}",
        "bash": "# Using websocat (install: brew install websocat)\nROOM_ID=\"550e8400-e29b-41d4-a716-446655440000\"\nUSER_ID=\"880e8400-e29b-41d4-a716-446655440003\"\n\necho '{\"content\":\"Hello from terminal!\"}' | websocat ws://localhost:8080/ws/$ROOM_ID/$USER_ID"
      }
    }
  },
  "dataModels": {
    "Room": {
      "description": "Represents a chat room",
      "fields": {
        "id": {
          "type": "UUID",
          "description": "Unique identifier for the room",
          "required": true,
          "generated": "Automatically generated on creation"
        },
        "name": {
          "type": "String",
          "description": "Display name of the room",
          "required": true,
          "validation": "1-50 characters, cannot be empty"
        },
        "password": {
          "type": "String?",
          "description": "Optional password for private rooms",
          "required": false,
          "validation": "Any string, null if no password"
        },
        "users": {
          "type": "[User]",
          "description": "Array of users currently in the room",
          "required": true,
          "default": "Empty array"
        },
        "createdAt": {
          "type": "Date",
          "description": "Timestamp when room was created",
          "required": true,
          "format": "ISO 8601",
          "generated": "Automatically set on creation"
        }
      },
      "methods": {
        "addUser": "Add a user to the room (checks for username uniqueness)",
        "removeUser": "Remove a user from the room by userId",
        "hasUser": "Check if a user exists in the room by userId",
        "hasUsername": "Check if a username is taken in the room",
        "isEmpty": "Returns true if room has no users"
      },
      "lifecycle": "Rooms are automatically deleted when the last user leaves"
    },
    "User": {
      "description": "Represents a user in a chat room",
      "fields": {
        "id": {
          "type": "UUID",
          "description": "Unique identifier for the user",
          "required": true,
          "generated": "Automatically generated when joining room"
        },
        "username": {
          "type": "String",
          "description": "Display name of the user",
          "required": true,
          "validation": "1-30 characters, must be unique per room"
        },
        "roomId": {
          "type": "UUID",
          "description": "ID of the room the user belongs to",
          "required": true
        },
        "joinedAt": {
          "type": "Date",
          "description": "Timestamp when user joined the room",
          "required": true,
          "format": "ISO 8601",
          "generated": "Automatically set when joining"
        }
      },
      "constraints": [
        "Username must be unique within a room",
        "Username cannot be changed after joining",
        "User is removed from room on disconnect"
      ]
    },
    "Message": {
      "description": "Represents a chat message",
      "fields": {
        "id": {
          "type": "UUID",
          "description": "Unique identifier for the message",
          "required": true,
          "generated": "Automatically generated"
        },
        "roomId": {
          "type": "UUID",
          "description": "ID of the room this message belongs to",
          "required": true
        },
        "userId": {
          "type": "UUID",
          "description": "ID of the user who sent the message",
          "required": true
        },
        "username": {
          "type": "String",
          "description": "Username of the sender (for display)",
          "required": true
        },
        "content": {
          "type": "String",
          "description": "The actual message content",
          "required": true,
          "validation": "1-1000 characters, cannot be empty"
        },
        "timestamp": {
          "type": "Date",
          "description": "When the message was sent",
          "required": true,
          "format": "ISO 8601",
          "generated": "Automatically set on creation"
        },
        "type": {
          "type": "MessageType",
          "description": "Type of message",
          "required": true,
          "default": "message",
          "enum": ["message", "userJoined", "userLeft", "system"]
        }
      },
      "persistence": "Messages are not persisted - real-time only"
    },
    "DTOs": {
      "CreateRoomRequest": {
        "description": "Request body for creating a room",
        "fields": {
          "name": {
            "type": "String",
            "required": true,
            "validation": "1-50 characters"
          },
          "password": {
            "type": "String?",
            "required": false
          }
        }
      },
      "JoinRoomRequest": {
        "description": "Request body for joining a room",
        "fields": {
          "username": {
            "type": "String",
            "required": true,
            "validation": "1-30 characters"
          },
          "password": {
            "type": "String?",
            "required": false,
            "note": "Required if room has a password"
          }
        }
      },
      "SendMessageRequest": {
        "description": "Request body for sending a message via WebSocket",
        "fields": {
          "content": {
            "type": "String",
            "required": true,
            "validation": "1-1000 characters"
          }
        }
      },
      "RoomResponse": {
        "description": "Response format for room information",
        "fields": {
          "id": "UUID",
          "name": "String",
          "hasPassword": "Boolean",
          "userCount": "Integer",
          "createdAt": "ISO8601 date string"
        }
      },
      "JoinRoomResponse": {
        "description": "Response when successfully joining a room",
        "fields": {
          "userId": "UUID",
          "room": "RoomResponse",
          "users": "[UserResponse]"
        }
      },
      "UserResponse": {
        "description": "Response format for user information",
        "fields": {
          "id": "UUID",
          "username": "String",
          "joinedAt": "ISO8601 date string"
        }
      },
      "ErrorResponse": {
        "description": "Standard error response format",
        "fields": {
          "error": "Boolean (always true)",
          "reason": "String (error description)"
        }
      },
      "SuccessResponse": {
        "description": "Standard success response format",
        "fields": {
          "success": "Boolean (always true)",
          "message": "String (success message)"
        }
      }
    }
  },
  "validationRules": {
    "roomName": {
      "minLength": 1,
      "maxLength": 50,
      "rules": [
        "Cannot be empty or only whitespace",
        "Trimmed before validation"
      ]
    },
    "username": {
      "minLength": 1,
      "maxLength": 30,
      "rules": [
        "Cannot be empty or only whitespace",
        "Must be unique within a room",
        "Trimmed before validation",
        "Case-sensitive"
      ]
    },
    "messageContent": {
      "minLength": 1,
      "maxLength": 1000,
      "rules": [
        "Cannot be empty or only whitespace",
        "Trimmed before validation"
      ]
    },
    "password": {
      "minLength": 0,
      "maxLength": "unlimited",
      "rules": [
        "Optional field",
        "If provided for room, required to join",
        "Exact match required (case-sensitive)"
      ]
    },
    "uuid": {
      "format": "RFC 4122 compliant UUID",
      "rules": [
        "Must be valid UUID format",
        "Hyphenated lowercase format preferred"
      ]
    }
  },
  "completeUsageFlow": {
    "description": "Step-by-step guide to using the chat server",
    "steps": [
      {
        "step": 1,
        "action": "Check server health",
        "endpoint": "GET /health",
        "purpose": "Verify server is running",
        "example": "curl http://localhost:8080/health"
      },
      {
        "step": 2,
        "action": "List available rooms",
        "endpoint": "GET /api/rooms",
        "purpose": "See existing rooms or verify none exist",
        "example": "curl http://localhost:8080/api/rooms"
      },
      {
        "step": 3,
        "action": "Create a new room (or skip if joining existing)",
        "endpoint": "POST /api/rooms",
        "purpose": "Create your own chat room",
        "example": "curl -X POST http://localhost:8080/api/rooms \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"name\":\"My Chat Room\",\"password\":\"secret\"}'"
      },
      {
        "step": 4,
        "action": "Join the room",
        "endpoint": "POST /api/rooms/:roomId/join",
        "purpose": "Register your username and get userId",
        "example": "curl -X POST http://localhost:8080/api/rooms/ROOM_ID/join \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"username\":\"alice\",\"password\":\"secret\"}'"
      },
      {
        "step": 5,
        "action": "Connect to WebSocket",
        "endpoint": "ws://localhost:8080/ws/:roomId/:userId",
        "purpose": "Establish real-time connection for messaging",
        "example": "websocat ws://localhost:8080/ws/ROOM_ID/USER_ID"
      },
      {
        "step": 6,
        "action": "Send messages",
        "method": "Send JSON through WebSocket",
        "purpose": "Chat with other users in the room",
        "example": "echo '{\"content\":\"Hello everyone!\"}' | websocat ws://localhost:8080/ws/ROOM_ID/USER_ID"
      },
      {
        "step": 7,
        "action": "Receive messages",
        "method": "Listen to WebSocket messages",
        "purpose": "Get messages from other users",
        "note": "Messages are automatically broadcast to all connected users"
      },
      {
        "step": 8,
        "action": "Leave the room",
        "endpoint": "DELETE /api/rooms/:roomId/leave/:userId",
        "purpose": "Clean disconnect and remove user from room",
        "example": "curl -X DELETE http://localhost:8080/api/rooms/ROOM_ID/leave/USER_ID"
      }
    ],
    "notes": [
      "Steps 1-2 are optional but recommended",
      "You can join existing rooms (skip step 3)",
      "Always disconnect properly (step 8) to clean up resources",
      "Room is automatically deleted when last user leaves"
    ]
  },
  "clientImplementationGuide": {
    "terminal": {
      "description": "Example implementation for terminal/CLI clients",
      "tools": {
        "curl": "For REST API calls",
        "websocat": "For WebSocket connections (install: brew install websocat)",
        "jq": "For JSON parsing (install: brew install jq)"
      },
      "fullExample": "#!/bin/bash\n\n# Configuration\nAPI_URL=\"http://localhost:8080\"\nROOM_NAME=\"Terminal Chat\"\nUSERNAME=\"$1\"\n\nif [ -z \"$USERNAME\" ]; then\n  echo \"Usage: $0 <username>\"\n  exit 1\nfi\n\n# Create room\necho \"Creating room...\"\nROOM_RESPONSE=$(curl -s -X POST $API_URL/api/rooms \\\n  -H \"Content-Type: application/json\" \\\n  -d \"{\\\"name\\\":\\\"$ROOM_NAME\\\"}\")\n\nROOM_ID=$(echo $ROOM_RESPONSE | jq -r '.id')\necho \"Room created: $ROOM_ID\"\n\n# Join room\necho \"Joining room...\"\nJOIN_RESPONSE=$(curl -s -X POST $API_URL/api/rooms/$ROOM_ID/join \\\n  -H \"Content-Type: application/json\" \\\n  -d \"{\\\"username\\\":\\\"$USERNAME\\\"}\")\n\nUSER_ID=$(echo $JOIN_RESPONSE | jq -r '.userId')\necho \"Joined as: $USERNAME (ID: $USER_ID)\"\n\n# Cleanup on exit\ntrap \"curl -s -X DELETE $API_URL/api/rooms/$ROOM_ID/leave/$USER_ID > /dev/null; echo 'Disconnected'; exit\" INT TERM\n\n# Connect to WebSocket\necho \"Connecting to chat...\"\nwebsocat ws://localhost:8080/ws/$ROOM_ID/$USER_ID",
      "considerations": [
     Handle SIGINT/SIGTERM for graceful shutdown",
        "Display different colors for different message types",
        "Parse JSON responses for error handling",
        "Show user join/leave notifications"
      ]
    },
    "web": {
      "description": "Example implementation for web clients",
      "technologies": ["JavaScript", "HTML5 WebSocket API", "Fetch API"],
      "fullExample": "<!DOCTYPE html>\n<html>\n<head>\n  <title>Web Chat Client</title>\n</head>\n<body>\n  <div id=\"app\">\n    <div id=\"messages\"></div>\n    <input id=\"messageInput\" type=\"text\" placeholder=\"Type a message...\">\n    <button id=\"sendBtn\">Send</button>\n  </div>\n\n  <script>\n    const API_URL = 'http://localhost:8080';\n    let ws = null;\n    let roomId = null;\n    let userId = null;\n\n    async function createRoom(name) {\n      const response = await fetch(`${API_URL}/api/rooms`, {\n        method: 'POST',\n        headers: { 'Content-Type': 'application/json' },\n        body: JSON.stringify({ name })\n      });\n      return await response.json();\n    }\n\n    async function joinRoom(roomId, username) {\n      const response = await fetch(`${API_URL}/api/rooms/${roomId}/join`, {\n        method: 'POST',\n        headers: { 'Content-Type': 'application/json' },\n        body: JSON.stringify({ username })\n      });\n      return await response.json();\n    }\n\n    function connectWebSocket(roomId, userId) {\n      ws = new WebSocket(`ws://localhost:8080/ws/${roomId}/${userId}`);\n      \n      ws.onopen = () => console.log('Connected to chat');\n      \n      ws.onmessage = (event) => {\n        const message = JSON.parse(event.data);\n        displayMessage(message);\n      };\n      \n      ws.onerror = (error) => console.error('WebSocket error:', error);\n      \n      ws.onclose = () => console.log('Disconnected from chat');\n    }\n\n    function displayMessage(message) {\n      const messagesDiv = document.getElementById('messages');\n      const messageEl = document.createElement('div');\n      messageEl.className = `message message-${message.type}`;\n      messageEl.textContent = `[${message.username}] ${message.content}`;\n      messagesDiv.appendChild(messageEl);\n      messagesDiv.scrollTop = messagesDiv.scrollHeight;\n    }\n\n    function sendMessage(content) {\n      if (ws && ws.readyState === WebSocket.OPEN) {\n        ws.send(JSON.stringify({ content }));\n      }\n    }\n\n    // Initialize\n    (async () => {\n      const room = await createRoom('Web Chat');\n      roomId = room.id;\n      \n      const join = await joinRoom(roomId, 'WebUser');\n      userId = join.userId;\n      \n      connectWebSocket(roomId, userId);\n      \n      document.getElementById('sendBtn').onclick = () => {\n        const input = document.getElementById('messageInput');\n        sendMessage(input.value);\n        input.value = '';\n      };\n    })();\n  </script>\n</body>\n</html>",
      "considerations": [
        "Handle reconnection on disconnect",
        "Implement typing indicators",
        "Show online user list",
        "Add message timestamps",
        "Implement auto-scroll for new messages"
      ]
    },
    "mobile": {
      "description": "Considerations for mobile app clients (iOS/Android)",
      "platforms": {
        "iOS": {
          "framework": "Swift + URLSession WebSocketTask",
          "networking": "URLSession for REST, URLSessionWebSocketTask for WebSocket",
          "example": "import Foundation\n\nclass ChatClient {\n    let baseURL = \"http://localhost:8080\"\n    var webSocketTask: URLSessionWebSocketTask?\n    \n    func createRoom(name: String, password: String? = nil) async throws -> Room {\n        var request = URLRequest(url: URL(string: \"\\(baseURL)/api/rooms\")!)\n        request.httpMethod = \"POST\"\n        request.addValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")\n        \n        let body = [\"name\": name, \"password\": password]\n        request.httpBody = try JSONSerialization.data(withJSONObject: body)\n        \n        let (data, _) = try await URLSession.shared.data(for: request)\n        return try JSONDecoder().decode(Room.self, from: data)\n    }\n    \n    func connectWebSocket(roomId: UUID, userId: UUID) {\n        let url = URL(string: \"ws://localhost:8080/ws/\\(roomId)/\\(userId)\")!\n        webSocketTask = URLSession.shared.webSocketTask(with: url)\n        webSocketTask?.resume()\n        receiveMessage()\n    }\n    \n    func receiveMessage() {\n        webSocketTask?.receive { [weak self] result in\n            switch result {\n            case .success(let message):\n                switch message {\n                case .string(let text):\n                    print(\"Received: \\(text)\")\n                case .data(let data):\n                    print(\"Received data: \\(data)\")\n                @unknown default:\n                    break\n                }\n                self?.receiveMessage()\n            case .failure(let error):\n                print(\"Error: \\(error)\")\n            }\n        }\n    }\n    \n    func sendMessage(_ content: String) {\n        let message = [\"content\": content]\n        guard let data = try? JSONSerialization.data(withJSONObject: message),\n              let text = String(data: data, encoding: .utf8) else { return }\n        \n        webSocketTask?.send(.string(text)) { error in\n            if let error = error {\n                print(\"Send error: \\(error)\")\n            }\n        }\n    }\n}"
        },
        "Android": {
          "framework": "Kotlin + OkHttp",
          "networking": "Retrofit for REST, OkHttp WebSocket for WebSocket",
          "example": "import okhttp3.*\nimport okio.ByteString\n\nclass ChatClient {\n    private val client = OkHttpClient()\n    private var webSocket: WebSocket? = null\n    \n    fun connectWebSocket(roomId: String, userId: String) {\n        val request = Request.Builder()\n            .url(\"ws://localhost:8080/ws/$roomId/$userId\")\n            .build()\n        \n        webSocket = client.newWebSocket(request, object : WebSocketListener() {\n            override fun onOpen(webSocket: WebSocket, response: Response) {\n                println(\"Connected to chat\")\n            }\n            \n            override fun onMessage(webSocket: WebSocket, text: String) {\n                println(\"Received: $text\")\n            }\n            \n            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {\n                println(\"Error: ${t.message}\")\n            }\n            \n            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {\n                webSocket.close(1000, null)\n                println(\"Disconnected\")\n            }\n        })\n    }\n    \n    fun sendMessage(content: String) {\n        val json = \"\"\"{ \"content\": \"$content\" }\"\"\"\n        webSocket?.send(json)\n    }\n}"
        }
      },
      "considerations": [
        "Handle app backgrounding (disconnect WebSocket)",
        "Reconnect on app foregrounding",
        "Show push notifications for new messages",
        "Handle network changes",
        "Implement local message caching",
        "Battery optimization for WebSocket"
      ]
    }
  },
  "errorHandling": {
    "httpStatusCodes": {
      "200": "Success - Request completed successfully",
      "400": "Bad Request - Invalid input or malformed request",
      "401": "Unauthorized - Invalid password for protected room",
      "404": "Not Found - Room or user doesn't exist",
      "409": "Conflict - Username already taken in room",
      "500": "Internal Server Error - Server-side error"
    },
    "errorResponseFormat": {
      "structure": {
        "error": "Boolean (always true)",
        "reason": "String describing the error"
      },
      "example": "{\n  \"error\": true,\n  \"reason\": \"Username 'john_doe' already exists in this room\"\n}"
    },
    "commonErrors": [
      {
        "error": "Room name cannot be empty",
        "cause": "Attempting to create room with empty or whitespace-only name",
        "solution": "Provide a non-empty room name (1-50 characters)"
      },
      {
        "error": "Room name too long (max 50 characters)",
        "cause": "Room name exceeds 50 characters",
        "solution": "Shorten the room name to 50 characters or less"
      },
      {
        "error": "Username cannot be empty",
        "cause": "Attempting to join with empty or whitespace-only username",
        "solution": "Provide a non-empty username (1-30 characters)"
      },
      {
        "error": "Username too long (max 30 characters)",
        "cause": "Username exceeds 30 characters",
        "solution": "Shorten the username to 30 characters or less"
      },
      {
        "error": "Username 'xyz' already exists in this room",
        "cause": "Another user in the room already has this username",
        "solution": "Choose a different username"
      },
      {
        "error": "Invalid room password",
        "cause": "Provided password doesn't match room's password",
        "solution": "Use the correct password or ask room creator"
      },
      {
        "error": "Room not found",
        "cause": "Room ID doesn't exist or room was deleted",
        "solution": "Verify room ID or create a new room"
      },
      {
        "error": "User not found in room",
        "cause": "Attempting to perform action with invalid user ID",
        "solution": "Verify user ID or rejoin the room"
      },
      {
        "error": "Invalid room ID",
        "cause": "Room ID is not a valid UUID format",
        "solution": "Provide a valid UUID"
      },
      {
        "error": "Invalid user ID",
        "cause": "User ID is not a valid UUID format",
        "solution": "Provide a valid UUID"
      },
      {
        "error": "Message content cannot be empty",
        "cause": "Attempting to send empty or whitespace-only message",
        "solution": "Provide non-empty message content"
      },
      {
        "error": "Message too long (max 1000 characters)",
        "cause": "Message content exceeds 1000 characters",
        "solution": "Shorten the message to 1000 characters or less"
      }
    ],
    "websocketErrors": [
      {
        "error": "Connection closed with code 1000",
        "cause": "Normal closure - user left or connection ended properly",
        "action": "No action needed - expected behavior"
      },
      {
        "error": "Connection closed immediately after connect",
        "cause": "User not in room or invalid room/user ID",
        "action": "Verify you joined the room via REST API first"
      },
      {
        "error": "Connection timeout",
        "cause": "Network issues or server unreachable",
        "action": "Check network connection and server status"
      },
      {
        "error": "Message send failure",
        "cause": "WebSocket not connected or message validation failed",
        "action": "Check connection status and message format"
      }
    ],
    "bestPractices": [
      "Always check HTTP status code before parsing response",
      "Display user-friendly error messages from 'reason' field",
      "Implement retry logic for network errors",
      "Validate input on client side before sending to server",
      "Handle WebSocket disconnections gracefully",
      "Log errors for debugging but don't expose internals to users"
    ]
  },
  "securityConsiderations": {
    "authentication": {
      "current": "No authentication required",
      "implications": [
        "Anyone can create rooms",
        "Anyone can join any room (with password if set)",
        "No user identity verification",
        "No rate limiting on endpoints"
      ],
      "recommendations": "For production, implement authentication system"
    },
    "passwords": {
      "storage": "Stored in plain text in memory",
      "transmission": "Sent in plain text via HTTP",
      "security": "Not secure - for demonstration purposes only",
      "recommendations": [
        "Use HTTPS in production",
        "Hash passwords with bcrypt or similar",
        "Implement password strength requirements",
        "Add rate limiting for password attempts"
      ]
    },
    "dataValidation": {
      "current": "Input validation on all endpoints",
      "validations": [
        "Room name length (1-50 chars)",
        "Username length (1-30 chars)",
        "Message content length (1-1000 chars)",
        "UUID format validation"
      ],
      "protections": [
        "Prevents empty inputs",
        "Limits string lengths to prevent DoS",
        "Trims whitespace automatically",
        "Validates UUID formats"
      ]
    },
    "cors": {
      "status": "Enabled for all origins",
      "configuration": "Allows all origins (*)",
      "implications": "Any web application can access the API",
      "recommendations": "In production, restrict to specific origins"
    },
    "rateLimiting": {
      "current": "Not implemented",
      "risks": [
        "API abuse",
        "Spam messages",
        "Resource exhaustion",
        "DoS attacks"
      ],
      "recommendations": [
        "Implement rate limiting per IP",
        "Limit messages per user per minute",
        "Limit room creation per IP",
        "Add connection limits per room"
      ]
    },
    "dataPrivacy": {
      "storage": "All data in memory only",
      "persistence": "No data persisted to disk",
      "retention": "Data deleted when server restarts or rooms close",
      "implications": [
        "No message history",
        "No user data tracking",
        "Complete data deletion on restart"
      ]
    },
    "productionRecommendations": [
      "Use HTTPS/WSS instead of HTTP/WS",
      "Implement JWT-based authentication",
      "Add rate limiting middleware",
      "Hash passwords with bcrypt",
      "Implement IP-based connection limits",
      "Add input sanitization for XSS prevention",
      "Enable logging and monitoring",
      "Implement CORS whitelist",
      "Add API versioning",
      "Use environment variables for configuration",
      "Implement graceful shutdown",
      "Add health check endpoints with metrics",
      "Consider adding Redis for distributed state",
      "Implement message size limits",
      "Add profanity filter for messages"
    ]
  },
  "troubleshooting": {
    "serverNotStarting": [
      {
        "symptom": "Port 8080 already in use",
        "cause": "Another process is using port 8080",
        "solution": "Stop the other process or change port in configure.swift: app.http.server.configuration.port = 8081"
      },
      {
        "symptom": "Swift build fails",
        "cause": "Missing dependencies or incompatible Swift version",
        "solution": "Run 'swift package update' and ensure Swift 6.0+ is installed"
      },
      {
        "symptom": "Module not found errors",
        "cause": "Dependencies not downloaded",
        "solution": "Run 'swift package resolve' to download dependencies"
      }
    ],
    "cannotConnectToServer": [
      {
        "symptom": "Connection refused",
        "cause": "Server not running",
        "solution": "Start the server with 'swift run' or 'make run'"
      },
      {
        "symptom": "Timeout when connecting",
        "cause": "Firewall blocking connection",
        "solution": "Check firewall settings and allow port 8080"
      },
      {
        "symptom": "Connection works on localhost but not from other machines",
        "cause": "Server bound to 127.0.0.1 only",
        "solution": "Change hostname to 0.0.0.0 in configure.swift to accept external connections"
      }
    ],
    "roomIssues": [
      {
        "symptom": "Room not found after creation",
        "cause": "Server restarted (in-memory storage)",
        "solution": "Rooms are deleted on server restart - create room again"
      },
      {
        "symptom": "Cannot join room with correct password",
        "cause": "Password is case-sensitive",
        "solution": "Ensure exact password match including case"
      },
      {
        "symptom": "Room disappeared while chatting",
        "cause": "Room auto-deleted when all users left",
        "solution": "Expected behavior - create new room or join existing one"
      }
    ],
    "websocketIssues": [
      {
        "symptom": "WebSocket connection closes immediately",
        "cause": "User not joined to room via REST API first",
        "solution": "Call POST /api/rooms/:roomId/join before connecting WebSocket"
      },
      {
        "symptom": "Messages not received by other users",
        "cause": "Invalid message format or validation failure",
        "solution": "Ensure message is valid JSON: {\"content\":\"text\"} and content is 1-1000 chars"
      },
      {
        "symptom": "WebSocket disconnects randomly",
        "cause": "Network issues or client timeout",
        "solution": "Implement reconnection logic and ping/pong heartbeat"
      }
    ],
    "clientIssues": [
      {
        "symptom": "websocat command not found",
        "cause": "websocat not installed",
        "solution": "Install with: brew install websocat (macOS) or from https://github.com/vi/websocat"
      },
      {
        "symptom": "jq command not found",
        "cause": "jq not installed",
        "solution": "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
      },
      {
        "symptom": "Bash script permission denied",
        "cause": "Script not executable",
        "solution": "Run: chmod +x client-example.sh"
      }
    ],
    "debuggingTips": [
      "Enable verbose logging in Vapor (LOG_LEVEL=debug)",
      "Use browser DevTools Network tab for WebSocket debugging",
      "Check server logs for error messages",
      "Verify JSON format with jsonlint or jq",
      "Test REST endpoints with curl -v for verbose output",
      "Use websocat -v for verbose WebSocket debugging",
      "Check if room and user IDs are valid UUIDs",
      "Verify Content-Type header is application/json for POST requests"
    ]
  },
  "bestPractices": {
    "clientDevelopment": [
      "Always validate user input before sending to server",
      "Implement exponential backoff for reconnection",
      "Handle all message types (message, userJoined, userLeft, system)",
      "Display user-friendly error messages",
      "Implement loading states for async operations",
      "Clean up resources on disconnect (call leave endpoint)",
      "Store room/user IDs securely if persisting session",
      "Implement message queuing for offline scenarios",
      "Add typing indicators for better UX",
      "Show connection status to users"
    ],
    "serverDeployment": [
      "Use environment variables for configuration",
      "Implement proper logging and monitoring",
      "Set up health check endpoints",
      "Use reverse proxy (nginx) for SSL termination",
      "Implement rate limiting",
      "Set up auto-restart on crash",
      "Use process manager (systemd, PM2, etc.)",
      "Configure proper log rotation",
      "Set up metrics collection (Prometheus, etc.)",
      "Implement graceful shutdown"
    ],
    "performance": [
      "Limit max connections per room",
      "Implement message batching for high traffic",
      "Use connection pooling",
      "Monitor memory usage (in-memory storage)",
      "Set WebSocket timeout appropriately",
      "Implement message throttling per user",
      "Clean up inactive connections",
      "Use CDN for static assets if web client"
    ],
    "testing": [
      "Test with multiple concurrent users",
      "Test edge cases (empty inputs, max lengths, etc.)",
      "Test network failures and reconnection",
      "Load test with expected peak traffic",
      "Test WebSocket message ordering",
      "Test room cleanup on user disconnect",
      "Test password-protected rooms",
      "Test username uniqueness enforcement"
    ]
  },
  "installation": {
    "requirements": {
      "swift": "6.0 or higher",
      "platform": "macOS 13+ or Linux (Ubuntu 20.04+)",
      "tools": ["Xcode (for macOS)", "curl", "Optional: Docker"]
    },
    "steps": [
      {
        "step": 1,
        "title": "Clone or download the project",
        "command": "git clone <repository-url> && cd testVapor"
      },
      {
        "step": 2,
        "title": "Resolve dependencies",
        "command": "swift package resolve"
      },
      {
        "step": 3,
        "title": "Build the project",
        "command": "swift build"
      },
      {
        "step": 4,
        "title": "Run the server",
        "command": "swift run"
      },
      {
        "step": 5,
        "title": "Verify server is running",
        "command": "curl http://localhost:8080/health"
      }
    ],
    "alternativeMethods": {
      "makefile": {
        "description": "Use Makefile commands",
        "commands": {
          "build": "make build",
          "run": "make run",
          "test": "make test",
          "clean": "make clean",
          "client": "make client"
        }
      },
      "docker": {
        "description": "Run with Docker",
        "commands": {
          "build": "docker compose build",
          "run": "docker compose up app"
        }
      }
    }
  },
  "performanceAndScalability": {
    "currentArchitecture": {
      "design": "Single-instance in-memory storage with Swift Actor concurrency",
      "limitations": [
        "All data in memory (lost on restart)",
        "Single server instance (no horizontal scaling)",
        "No load balancing",
        "No persistent storage",
        "No distributed state management"
      ],
      "strengths": [
        "Very fast (no database queries)",
        "Low latency for real-time messaging",
        "Simple architecture",
        "Thread-safe with Actor model"
      ]
    },
    "expectedPerformance": {
      "messagesPerSecond": "10,000+ messages/sec per room",
      "concurrentConnections": "10,000+ WebSocket connections",
      "roomLimit": "Limited by memory (thousands of rooms)",
      "latency": "<10ms for message broadcast within room",
      "memoryUsage": "~100MB base + ~1KB per user"
    },
    "bottlenecks": [
      "Memory usage grows with number of users",
      "All state on single server",
      "No message persistence",
      "WebSocket fan-out for large rooms"
    ],
    "scalingStrategies": {
      "verticalScaling": {
        "description": "Increase server resources",
        "steps": [
          "Increase RAM for more concurrent users",
          "Use faster CPU for message processing",
          "Optimize Swift compiler flags for production"
        ],
        "limits": "Single server can handle 10k-50k concurrent connections"
      },
      "horizontalScaling": {
        "description": "Multiple server instances",
        "requirements": [
          "Shared state storage (Redis, PostgreSQL)",
          "Message broker (Redis Pub/Sub, RabbitMQ)",
          "Load balancer (nginx, HAProxy)",
          "Sticky sessions for WebSocket"
        ],
        "architecture": "Load Balancer → Multiple Vapor instances → Redis (shared state + pub/sub)"
      },
      "databaseIntegration": {
        "description": "Add persistent storage",
        "options": [
          "PostgreSQL with Fluent ORM",
          "MongoDB for document storage",
          "Redis for fast in-memory + persistence"
        ],
        "benefits": [
          "Message history",
          "User persistence across restarts",
          "Room persistence",
          "Analytics and logging"
        ]
      }
    },
    "optimizations": [
      "Use messagepack instead of JSON for smaller payload",
      "Implement message batching to reduce WebSocket sends",
      "Add connection pooling for database",
      "Use compression for WebSocket messages",
      "Implement lazy loading for user lists",
      "Add caching layer (Redis) for frequently accessed data",
      "Use binary protocols for high-throughput scenarios",
      "Optimize JSON encoding/decoding with custom coders"
    ]
  },
  "faq": [
    {
      "question": "Is message history persisted?",
      "answer": "No, all messages are real-time only. Messages are not stored and are lost when the server restarts or when all users leave a room."
    },
    {
      "question": "What happens when the server restarts?",
      "answer": "All rooms and users are deleted. This is because everything is stored in memory only. Clients need to recreate rooms and rejoin."
    },
    {
      "question": "Can I use this in production?",
      "answer": "This implementation is designed for demonstration and learning. For production use, you should add authentication, rate limiting, database persistence, HTTPS/WSS, and proper security measures."
    },
    {
      "question": "How many users can be in one room?",
      "answer": "There's no hard limit, but performance depends on server resources. With current architecture, thousands of users per room is feasible."
    },
    {
      "question": "Are passwords secure?",
      "answer": "No. Passwords are stored in plain text in memory and transmitted over HTTP. For production, use HTTPS and hash passwords."
    },
    {
      "question": "Can I deploy this to production as-is?",
      "answer": "Not recommended. Add HTTPS, authentication, rate limiting, database persistence, monitoring, and proper error handling first."
    },
    {
      "question": "Why use actors instead of traditional locking?",
      "answer": "Swift Actors provide compile-time safety against data races and simpler concurrency model compared to locks and queues."
    },
    {
      "question": "Can I connect from a web browser?",
      "answer": "Yes! CORS is enabled. Use the WebSocket API in JavaScript to connect from browsers."
    },
    {
      "question": "What happens if two users join with the same username?",
      "answer": "The second user will receive a 409 Conflict error. Usernames must be unique within each room."
    },
    {
      "question": "How do I change the server port?",
      "answer": "Modify the port in Sources/testVapor/configure.swift: app.http.server.configuration.port = YOUR_PORT"
    },
    {
      "question": "Can I use this with mobile apps?",
      "answer": "Yes! Use URLSession WebSocketTask for iOS or OkHttp WebSocket for Android. See client implementation guide."
    },
    {
      "question": "Is there a message size limit?",
      "answer": "Yes, message content is limited to 1000 characters. This can be adjusted in the validation rules."
    },
    {
      "question": "How do I implement user authentication?",
      "answer": "Add JWT middleware, create user registration/login endpoints, and require tokens for protected routes. Consider using Vapor's authentication package."
    },
    {
      "question": "Can rooms have custom metadata?",
      "answer": "Currently no, but you can extend the Room model to include additional fields like description, tags, max users, etc."
    },
    {
      "question": "How do I implement private messaging?",
      "answer": "You can extend the API to support direct messages by creating special 1-on-1 rooms or adding a separate DM endpoint and message routing."
    }
  ],
  "quickReference": {
    "baseUrl": "http://localhost:8080",
    "endpointsSummary": [
      "GET / - Server info",
      "GET /health - Health check",
      "GET /api/rooms - List rooms",
      "POST /api/rooms - Create room",
      "GET /api/rooms/:roomId - Get room details",
      "POST /api/rooms/:roomId/join - Join room",
      "DELETE /api/rooms/:roomId/leave/:userId - Leave room",
      "GET /api/rooms/:roomId/users - Get room users",
      "WS /ws/:roomId/:userId - WebSocket connection"
    ],
    "commonCommands": {
      "createRoom": "curl -X POST http://localhost:8080/api/rooms -H 'Content-Type: application/json' -d '{\"name\":\"My Room\"}'",
      "listRooms": "curl http://localhost:8080/api/rooms",
      "joinRoom": "curl -X POST http://localhost:8080/api/rooms/ROOM_ID/join -H 'Content-Type: application/json' -d '{\"username\":\"alice\"}'",
      "connectWebSocket": "websocat ws://localhost:8080/ws/ROOM_ID/USER_ID",
      "leaveRoom": "curl -X DELETE http://localhost:8080/api/rooms/ROOM_ID/leave/USER_ID"
    }
  }
}
