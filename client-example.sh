#!/bin/bash

# Terminal Chat Client with TUI
# Requires: websocat, jq, bash 4.0+

# Enable debug mode: DEBUG=1 ./client-example.sh
DEBUG=${DEBUG:-0}
DEBUG_LOG="/tmp/chat_debug_$$.log"

# Debug function - only logs if DEBUG=1
d() {
    [ $DEBUG -eq 1 ] && echo "[$(date '+%H:%M:%S')] $1" >> "$DEBUG_LOG"
}

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

API_URL="http://localhost:8080"
WS_PID=""
ROOM_ID=""
USER_ID=""
USERNAME=""
ROOM_NAME=""
CLEANUP_DONE=0
IN_CHAT_MODE=0

# Temporary files
MSG_FILE="/tmp/chat_messages_$$"
USER_FILE="/tmp/chat_users_$$"
INPUT_PIPE="/tmp/chat_input_$$"

# Terminal dimensions
get_term_dimensions() {
    TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
    TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
    MSG_HEIGHT=$((TERM_HEIGHT - 6))
    SIDEBAR_WIDTH=25
}

get_term_dimensions

# Initialize temp files
touch "$MSG_FILE" 2>/dev/null || true
touch "$USER_FILE" 2>/dev/null || true

d "Script started"

# Validate UUID format
is_valid_uuid() {
    local uuid="$1"
    [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

# Cleanup function
cleanup() {
    [ $CLEANUP_DONE -eq 1 ] && return
    CLEANUP_DONE=1
    
    d "Cleanup: IN_CHAT_MODE=$IN_CHAT_MODE"
    
    # Restore terminal if in chat mode
    if [ $IN_CHAT_MODE -eq 1 ]; then
        tput cnorm 2>/dev/null || true
        tput rmcup 2>/dev/null || true
        stty echo 2>/dev/null || true
    fi
    
    # Show disconnect message only if connected
    [ -n "$USER_ID" ] && [ -n "$ROOM_ID" ] && echo -e "\n${YELLOW}Disconnecting...${NC}"
    
    # Kill WebSocket
    if [ -n "$WS_PID" ]; then
        d "Killing WS PID: $WS_PID"
        kill $WS_PID 2>/dev/null || true
        wait $WS_PID 2>/dev/null || true
    fi
    
    # Leave room
    if [ -n "$ROOM_ID" ] && [ -n "$USER_ID" ]; then
        d "Leaving room: $ROOM_ID"
        curl -s -X DELETE "$API_URL/api/rooms/$ROOM_ID/leave/$USER_ID" > /dev/null 2>&1 || true
        echo -e "${GREEN}✓ Disconnected from room${NC}"
    fi
    
    # Cleanup files
    rm -f "$MSG_FILE" "$USER_FILE" "$INPUT_PIPE" "$DEBUG_LOG" 2>/dev/null || true
    
    d "Cleanup complete"
}

trap cleanup SIGINT SIGTERM

# Check dependencies
check_dependencies() {
    d "Checking dependencies"
    local missing=0
    
    if ! command -v websocat &> /dev/null; then
        echo -e "${RED}✗ Error: websocat is not installed${NC}"
        echo -e "${YELLOW}  Install it with: ${BOLD}brew install websocat${NC}"
        missing=1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}✗ Error: jq is not installed${NC}"
        echo -e "${YELLOW}  Install it with: ${BOLD}brew install jq${NC}"
        missing=1
    fi
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}✗ Error: curl is not installed${NC}"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        d "Dependencies missing"
        cleanup
        exit 1
    fi
    
    d "Dependencies OK"
}

# Check server
check_server() {
    d "Checking server: $API_URL"
    echo -e "${CYAN}Checking server connection...${NC}"
    
    local response=$(curl -s -w "\n%{http_code}" --connect-timeout 5 --max-time 10 "$API_URL/health" 2>&1)
    local curl_exit=$?
    
    d "Curl exit: $curl_exit"
    
    if [ $curl_exit -ne 0 ]; then
        echo -e "${RED}✗ Cannot connect to server at $API_URL${NC}"
        echo -e "${YELLOW}  Please start the server with: ${BOLD}swift run${NC}"
        d "Server unreachable"
        cleanup
        exit 1
    fi
    
    # Extract status code (last line) and body (everything except last line)
    local status=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | sed '$d')
    
    d "Server status: $status"
    d "Server body: $body"
    
    if [ "$status" != "200" ]; then
        echo -e "${RED}✗ Server returned status: $status${NC}"
        cleanup
        exit 1
    fi
    
    if ! echo "$body" | jq -e '.status' > /dev/null 2>&1; then
        echo -e "${RED}✗ Invalid server response${NC}"
        d "Invalid JSON"
        cleanup
        exit 1
    fi
    
    echo -e "${GREEN}✓ Server is online${NC}"
    d "Server OK"
    sleep 0.5
}

# Draw UI components
draw_header() {
    local y=1
    tput cup $y 0 2>/dev/null || return
    echo -ne "${BLUE}${BOLD}"
    printf '╔%.0s' $(seq 1 $TERM_WIDTH)
    echo -ne "${NC}"
    
    ((y++))
    tput cup $y 0 2>/dev/null || return
    echo -ne "${BLUE}${BOLD}║${NC}"
    local title="  💬 Terminal Chat Client - Room: ${ROOM_NAME}"
    local padding=$((TERM_WIDTH - ${#title} - 3))
    echo -ne " ${CYAN}${BOLD}${title}${NC}"
    printf ' %.0s' $(seq 1 $padding)
    echo -ne "${BLUE}${BOLD}║${NC}"
    
    ((y++))
    tput cup $y 0 2>/dev/null || return
    echo -ne "${BLUE}${BOLD}"
    printf '╠%.0s' $(seq 1 $((TERM_WIDTH - SIDEBAR_WIDTH - 1)))
    echo -ne "╦"
    printf '%.0s' $(seq 1 $((SIDEBAR_WIDTH - 1)))
    printf '╣'
    echo -ne "${NC}"
}

draw_sidebar_header() {
    local y=3
    local x=$((TERM_WIDTH - SIDEBAR_WIDTH))
    tput cup $y $x 2>/dev/null || return
    echo -ne "${BLUE}${BOLD}║${NC} ${CYAN}Users Online${NC}"
}

draw_divider() {
    local y=$((TERM_HEIGHT - 3))
    tput cup $y 0 2>/dev/null || return
    echo -ne "${BLUE}${BOLD}"
    printf '╠%.0s' $(seq 1 $((TERM_WIDTH - SIDEBAR_WIDTH - 1)))
    echo -ne "╩"
    printf '%.0s' $(seq 1 $((SIDEBAR_WIDTH - 1)))
    printf '╣'
    echo -ne "${NC}"
}

draw_footer() {
    local y=$((TERM_HEIGHT - 2))
    tput cup $y 0 2>/dev/null || return
    echo -ne "${BLUE}${BOLD}║${NC} ${GREEN}You@${USERNAME}:${NC} "
    tput cup $((y + 1)) 0 2>/dev/null || return
    echo -ne "${BLUE}${BOLD}"
    printf '╚%.0s' $(seq 1 $TERM_WIDTH)
    echo -ne "${NC}"
}

draw_messages() {
    local start_y=4
    local end_y=$((TERM_HEIGHT - 4))
    local max_width=$((TERM_WIDTH - SIDEBAR_WIDTH - 3))
    
    # Clear message area
    for ((y=start_y; y<=end_y; y++)); do
        tput cup $y 0 2>/dev/null || return
        echo -ne "${BLUE}${BOLD}║${NC}"
        printf ' %.0s' $(seq 1 $max_width)
    done
    
    # Draw messages
    local line_count=0
    [ -f "$MSG_FILE" ] && line_count=$(wc -l < "$MSG_FILE" 2>/dev/null || echo 0)
    
    local skip=$((line_count - (end_y - start_y + 1)))
    [ $skip -lt 0 ] && skip=0
    
    local y=$start_y
    local count=0
    while IFS= read -r line && [ $y -le $end_y ]; do
        if [ $count -ge $skip ]; then
            tput cup $y 0 2>/dev/null || return
            echo -ne "${BLUE}${BOLD}║${NC} "
            
            [ ${#line} -gt $((max_width - 2)) ] && line="${line:0:$((max_width - 5))}..."
            
            echo -ne "$line"
            ((y++))
        fi
        ((count++))
    done < "$MSG_FILE"
}

draw_users() {
    local start_y=4
    local end_y=$((TERM_HEIGHT - 4))
    local x=$((TERM_WIDTH - SIDEBAR_WIDTH))
    
    # Clear user area
    for ((y=start_y; y<=end_y; y++)); do
        tput cup $y $x 2>/dev/null || return
        echo -ne "${BLUE}${BOLD}║${NC}"
        printf ' %.0s' $(seq 1 $((SIDEBAR_WIDTH - 2)))
    done
    
    # Draw users
    local y=$start_y
    if [ -f "$USER_FILE" ]; then
        while IFS= read -r username && [ $y -le $end_y ]; do
            if [ -n "$username" ]; then
                tput cup $y $x 2>/dev/null || return
                echo -ne "${BLUE}${BOLD}║${NC} ${GREEN}●${NC} "
                
                [ ${#username} -gt $((SIDEBAR_WIDTH - 6)) ] && username="${username:0:$((SIDEBAR_WIDTH - 9))}..."
                
                echo -ne "$username"
                ((y++))
            fi
        done < "$USER_FILE"
    fi
}

draw_sidebar_borders() {
    local start_y=4
    local end_y=$((TERM_HEIGHT - 4))
    local x=$((TERM_WIDTH - SIDEBAR_WIDTH))
    
    for ((y=start_y; y<=end_y; y++)); do
        tput cup $y $x 2>/dev/null || return
        echo -ne "${BLUE}${BOLD}║${NC}"
    done
}

refresh_ui() {
    tput cup 0 0 2>/dev/null || return
    draw_header
    draw_sidebar_header
    draw_messages
    draw_users
    draw_sidebar_borders
    draw_divider
    draw_footer
    tput cup $((TERM_HEIGHT - 2)) $((${#USERNAME} + 13)) 2>/dev/null || return
}

add_message() {
    local msg="$1"
    echo -e "$msg" >> "$MSG_FILE" 2>/dev/null || return
    
    local line_count=$(wc -l < "$MSG_FILE" 2>/dev/null || echo 0)
    if [ $line_count -gt 1000 ]; then
        tail -n 1000 "$MSG_FILE" > "${MSG_FILE}.tmp" 2>/dev/null || return
        mv "${MSG_FILE}.tmp" "$MSG_FILE" 2>/dev/null || return
    fi
    
    draw_messages
    draw_sidebar_borders
    tput cup $((TERM_HEIGHT - 2)) $((${#USERNAME} + 13)) 2>/dev/null || return
}

update_users() {
    draw_users
    draw_sidebar_borders
    tput cup $((TERM_HEIGHT - 2)) $((${#USERNAME} + 13)) 2>/dev/null || return
}

# WebSocket message handler
handle_ws_message() {
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        TYPE=$(echo "$line" | jq -r '.type' 2>/dev/null)
        USERNAME_MSG=$(echo "$line" | jq -r '.username' 2>/dev/null)
        CONTENT=$(echo "$line" | jq -r '.content' 2>/dev/null)
        
        d "WS msg: type=$TYPE user=$USERNAME_MSG"
        
        case "$TYPE" in
            "message")
                [ "$USERNAME_MSG" = "$USERNAME" ] && add_message "${GREEN}You:${NC} $CONTENT" || add_message "${CYAN}${USERNAME_MSG}:${NC} $CONTENT"
                ;;
            "userJoined")
                add_message "${YELLOW}→ $CONTENT${NC}"
                fetch_users &
                ;;
            "userLeft")
                add_message "${YELLOW}← $CONTENT${NC}"
                fetch_users &
                ;;
            "system")
                add_message "${RED}[SYSTEM]${NC} $CONTENT"
                ;;
        esac
    done
}

# Fetch user list
fetch_users() {
    local response=$(curl -s "$API_URL/api/rooms/$ROOM_ID/users" 2>/dev/null)
    if echo "$response" | jq -e '.[0]' > /dev/null 2>&1; then
        echo "$response" | jq -r '.[].username' > "$USER_FILE"
        update_users
    fi
}

# Setup phase
setup() {
    d "Setup start"
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║   Terminal Chat Client Setup          ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_dependencies
    check_server
    
    echo ""
    echo -ne "${GREEN}Enter your username: ${NC}"
    read USERNAME
    
    d "Username: $USERNAME"
    
    if [ -z "$USERNAME" ]; then
        echo -e "${RED}✗ Username cannot be empty${NC}"
        cleanup
        exit 1
    fi
    
    echo -e "\n${CYAN}Fetching available rooms...${NC}"
    ROOMS=$(curl -s "$API_URL/api/rooms" 2>/dev/null)
    
    d "Rooms fetched"
    
    if ! echo "$ROOMS" | jq -e '.' > /dev/null 2>&1; then
        echo -e "${RED}✗ Failed to fetch rooms${NC}"
        cleanup
        exit 1
    fi
    
    local room_count=$(echo "$ROOMS" | jq '. | length' 2>/dev/null || echo 0)
    d "Room count: $room_count"
    
    if [ "$room_count" -gt 0 ]; then
        echo -e "\n${YELLOW}Available rooms:${NC}"
        echo "$ROOMS" | jq -r '.[] | "  [\(.userCount) users] \(.name) - ID: \(.id)"'
        echo ""
    else
        echo -e "${YELLOW}No rooms available.${NC}\n"
    fi
    
    echo -ne "${GREEN}Do you want to (c)reate a new room or (j)oin an existing one? [c/j]: ${NC}"
    read CHOICE
    
    d "Choice: $CHOICE"
    
    if [ "$CHOICE" = "c" ]; then
        echo -ne "${GREEN}Enter room name: ${NC}"
        read ROOM_NAME_INPUT
        
        [ -z "$ROOM_NAME_INPUT" ] && { echo -e "${RED}✗ Room name cannot be empty${NC}"; cleanup; exit 1; }
        
        echo -ne "${GREEN}Enter password (leave empty for no password): ${NC}"
        read -s ROOM_PASSWORD
        echo ""
        
        [ -z "$ROOM_PASSWORD" ] && ROOM_JSON="{\"name\":\"$ROOM_NAME_INPUT\"}" || ROOM_JSON="{\"name\":\"$ROOM_NAME_INPUT\",\"password\":\"$ROOM_PASSWORD\"}"
        
        echo -e "\n${CYAN}Creating room...${NC}"
        ROOM=$(curl -s -X POST "$API_URL/api/rooms" -H "Content-Type: application/json" -d "$ROOM_JSON" 2>/dev/null)
        
        d "Room created"
        
        if ! echo "$ROOM" | jq -e '.' > /dev/null 2>&1; then
            echo -e "${RED}✗ Failed to create room${NC}"
            cleanup
            exit 1
        fi
        
        if echo "$ROOM" | jq -e '.error' > /dev/null 2>&1; then
            ERROR_MSG=$(echo "$ROOM" | jq -r '.reason')
            echo -e "${RED}✗ Error: $ERROR_MSG${NC}"
            cleanup
            exit 1
        fi
        
        ROOM_ID=$(echo "$ROOM" | jq -r '.id')
        ROOM_NAME="$ROOM_NAME_INPUT"
        d "Room ID: $ROOM_ID"
        echo -e "${GREEN}✓ Room created${NC}"
    else
        echo -ne "${GREEN}Enter room ID: ${NC}"
        read ROOM_ID
        
        [ -z "$ROOM_ID" ] && { echo -e "${RED}✗ Room ID cannot be empty${NC}"; cleanup; exit 1; }
        
        # Validate UUID format
        if ! is_valid_uuid "$ROOM_ID"; then
            echo -e "${RED}✗ Invalid room ID format${NC}"
            echo -e "${YELLOW}  Room ID must be a valid UUID (e.g., 550e8400-e29b-41d4-a716-446655440000)${NC}"
            cleanup
            exit 1
        fi
        
        echo -ne "${GREEN}Enter room password (if any): ${NC}"
        read -s ROOM_PASSWORD
        echo ""
    fi
    
    [ -z "$ROOM_PASSWORD" ] && JOIN_JSON="{\"username\":\"$USERNAME\"}" || JOIN_JSON="{\"username\":\"$USERNAME\",\"password\":\"$ROOM_PASSWORD\"}"
    
    echo -e "\n${CYAN}Joining room...${NC}"
    JOIN_RESPONSE=$(curl -s -X POST "$API_URL/api/rooms/$ROOM_ID/join" -H "Content-Type: application/json" -d "$JOIN_JSON" 2>/dev/null)
    
    d "Join response received"
    
    if ! echo "$JOIN_RESPONSE" | jq -e '.' > /dev/null 2>&1; then
        echo -e "${RED}✗ Failed to join room${NC}"
        cleanup
        exit 1
    fi
    
    if echo "$JOIN_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$JOIN_RESPONSE" | jq -r '.reason')
        echo -e "${RED}✗ Error: $ERROR_MSG${NC}"
        cleanup
        exit 1
    fi
    
    USER_ID=$(echo "$JOIN_RESPONSE" | jq -r '.userId')
    ROOM_NAME=$(echo "$JOIN_RESPONSE" | jq -r '.room.name')
    
    d "User ID: $USER_ID, Room: $ROOM_NAME"
    
    if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
        echo -e "${RED}✗ Failed to get user ID${NC}"
        cleanup
        exit 1
    fi
    
    echo "$JOIN_RESPONSE" | jq -r '.users[].username' > "$USER_FILE" 2>/dev/null
    
    echo -e "${GREEN}✓ Successfully joined '$ROOM_NAME'${NC}"
    echo -e "${YELLOW}Loading chat interface...${NC}"
    d "Setup complete"
    sleep 1
}

# Main chat interface
start_chat() {
    d "Chat start"
    IN_CHAT_MODE=1
    
    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true
    stty -echo 2>/dev/null || true
    
    get_term_dimensions
    clear
    refresh_ui
    
    rm -f "$INPUT_PIPE" 2>/dev/null
    mkfifo "$INPUT_PIPE" 2>/dev/null || true
    
    websocat "ws://localhost:8080/ws/$ROOM_ID/$USER_ID" 2>/dev/null | handle_ws_message &
    WS_PID=$!
    d "WS PID: $WS_PID"
    
    sleep 0.5
    if ! kill -0 $WS_PID 2>/dev/null; then
        IN_CHAT_MODE=0
        tput rmcup 2>/dev/null
        tput cnorm 2>/dev/null
        stty echo 2>/dev/null
        echo -e "${RED}✗ Failed to connect to WebSocket${NC}"
        d "WS connection failed"
        cleanup
        exit 1
    fi
    
    (
        while true; do
            [ -e "$INPUT_PIPE" ] && while IFS= read -r msg; do
                [ -n "$msg" ] && { d "Send: $msg"; echo "{\"content\":\"$msg\"}" | websocat "ws://localhost:8080/ws/$ROOM_ID/$USER_ID" -n1 2>/dev/null || true; }
            done < "$INPUT_PIPE"
            sleep 0.1
        done
    ) &
    
    tput cnorm 2>/dev/null || true
    d "Input loop start"
    
    local input=""
    local input_y=$((TERM_HEIGHT - 2))
    local input_x=$((${#USERNAME} + 13))
    
    while true; do
        tput cup $input_y $input_x 2>/dev/null || break
        IFS= read -r -s -n1 char
        
        case "$char" in
            $'\x7f'|$'\x08')
                if [ ${#input} -gt 0 ]; then
                    input="${input%?}"
                    tput cup $input_y $input_x 2>/dev/null || break
                    printf '%-*s' $((TERM_WIDTH - input_x - 2)) "$input"
                fi
                ;;
            "")
                if [ -n "$input" ]; then
                    echo "$input" > "$INPUT_PIPE" 2>/dev/null || true
                    input=""
                    tput cup $input_y $input_x 2>/dev/null || break
                    printf '%-*s' $((TERM_WIDTH - input_x - 2)) ""
                fi
                ;;
            *)
                if [ ${#input} -lt $((TERM_WIDTH - input_x - 3)) ]; then
                    input="${input}${char}"
                    tput cup $input_y $input_x 2>/dev/null || break
                    echo -n "$input"
                fi
                ;;
        esac
    done
}

# Main
main() {
    d "Main start"
    setup
    start_chat
    d "Main end"
}

main