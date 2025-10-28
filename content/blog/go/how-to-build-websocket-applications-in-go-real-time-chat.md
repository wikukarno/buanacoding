---
title: 'How to Build WebSocket Applications in Go - Real-time Chat Example'
date: 2025-10-15T10:00:00.000+07:00
draft: false
url: /2025/10/how-to-build-websocket-applications-in-go-real-time-chat.html
tags:
- Go
- WebSocket
- Real-time
- Tutorial
description: "Learn how to build real-time WebSocket applications in Go with gorilla/websocket. Build a complete chat app with connection pooling, broadcasting, and production-ready patterns."
keywords: ["go websocket", "golang websocket", "gorilla websocket", "real-time chat go", "websocket server go", "websocket client go", "go chat application", "websocket broadcasting", "golang real-time"]
faq:
  - question: "What is WebSocket and when should I use it?"
    answer: "WebSocket is a communication protocol that provides full-duplex communication channels over a single TCP connection. Unlike HTTP, which is request-response based, WebSocket allows bidirectional real-time data flow. Use WebSocket for real-time applications like chat systems, live notifications, collaborative editing, gaming, live dashboards, or any scenario where the server needs to push updates to clients immediately without polling."
  - question: "Why use gorilla/websocket instead of the standard library?"
    answer: "While Go's standard library includes `golang.org/x/net/websocket`, the gorilla/websocket package is the industry standard. It offers better RFC 6455 compliance, comprehensive API, better error handling, built-in ping/pong support for keepalive, compression support, and active maintenance. The gorilla/websocket API is also more intuitive and battle-tested in production environments."
  - question: "How do I handle multiple WebSocket connections efficiently in Go?"
    answer: "Use a connection pool pattern with a Hub/Manager struct that maintains a map of active connections. Use goroutines for each connection's read/write loops, and employ channels for thread-safe broadcasting. Always use a mutex when accessing the connection map. Implement graceful shutdown with context cancellation, and set read/write deadlines to prevent resource leaks from stale connections."
  - question: "What are common WebSocket errors and how to handle them?"
    answer: "Common errors include: 1) Connection closed unexpectedly - implement reconnection logic with exponential backoff on the client. 2) Message size limits - set MaxMessageSize on the Upgrader. 3) Read/write deadlines exceeded - adjust timeouts based on your use case or implement ping/pong. 4) Origin mismatch - configure CheckOrigin properly for CORS. 5) Concurrent writes - always protect WriteMessage calls with a mutex or use a single write goroutine with a channel."
  - question: "How do I implement authentication and authorization for WebSocket connections?"
    answer: "Authenticate during the HTTP upgrade handshake: validate JWT tokens from query parameters, cookies, or custom headers before calling Upgrader.Upgrade(). After successful upgrade, store user identity in the connection wrapper struct. For authorization, check permissions before broadcasting messages to specific connections. Never trust client messages - always validate and sanitize data server-side. Consider implementing rate limiting per connection to prevent abuse."
  - question: "How can I scale WebSocket applications horizontally?"
    answer: "For horizontal scaling across multiple servers, use a message broker like Redis Pub/Sub, NATS, or Kafka. When a message arrives at one server, publish it to the broker. All servers subscribe to the broker and broadcast received messages to their local connections. Use sticky sessions (session affinity) at the load balancer level to ensure clients reconnect to the same server, or implement a distributed connection registry. Consider connection draining during deployments."

---

Ever wanted to build a real-time chat app, live notification system, or multiplayer game? WebSocket is your answer. Unlike regular HTTP where clients have to constantly ask "got any updates?", WebSocket keeps a persistent connection open so the server can push data whenever it wants. No more polling, no more delays--just instant, bidirectional communication.

In this tutorial, we're building a production-ready chat application from scratch using Go and the **gorilla/websocket** package. By the end, you'll have a working chat app where multiple users can send messages in real-time.

Here's what we'll cover:

* Understanding WebSocket and when you actually need it
* Building your first WebSocket server
* Managing multiple connections with [goroutines and channels]({{< relref "concurrency-in-go-goroutines-and-channels-explained.md" >}})
* The Hub pattern for broadcasting messages
* Production-ready features (auth, rate limiting, graceful shutdown)
* Deployment tips and security best practices

## What is WebSocket?

Think of WebSocket as a phone call, while HTTP is like sending letters back and forth. With HTTP, the client always has to initiate a request--"Hey server, got anything new?" With WebSocket, once the connection is established, both sides can send data anytime. No more asking. Just instant communication.

WebSocket uses a single, long-lived TCP connection that stays open. This is way more efficient than opening a new HTTP connection for every update.

**When to use WebSocket:**

* Real-time chat apps (we're building one today!)
* Live notifications and alerts
* Collaborative editing (Google Docs style)
* Live dashboards showing metrics
* Multiplayer games
* Trading platforms that need instant price updates
* IoT devices sending/receiving data

**When you DON'T need WebSocket:**

* Building a [regular REST API]({{< relref "how-to-build-a-rest-api-in-go-using-net-http.md" >}}) - stick with HTTP
* Updates happen every few minutes - polling works fine
* Serving static content
* SEO matters - search engines can't crawl WebSocket content

## Installing gorilla/websocket

First, install the gorilla/websocket package:

```bash
go get github.com/gorilla/websocket
```

Create a new project:

```bash
mkdir websocket-chat
cd websocket-chat
go mod init websocket-chat
```

## Building a Basic WebSocket Server

Let's start simple. Here's an echo server that just bounces back whatever you send it:

```go
package main

import (
    "log"
    "net/http"

    "github.com/gorilla/websocket"
)

// Upgrader upgrades HTTP connections to WebSocket
var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 1024,
    // Allow all origins for development (restrict in production!)
    CheckOrigin: func(r *http.Request) bool {
        return true
    },
}

func handleWebSocket(w http.ResponseWriter, r *http.Request) {
    // Upgrade HTTP connection to WebSocket
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        log.Println("Upgrade error:", err)
        return
    }
    defer conn.Close()

    log.Println("Client connected")

    // Read messages in a loop
    for {
        messageType, message, err := conn.ReadMessage()
        if err != nil {
            log.Println("Read error:", err)
            break
        }

        log.Printf("Received: %s", message)

        // Echo the message back
        err = conn.WriteMessage(messageType, message)
        if err != nil {
            log.Println("Write error:", err)
            break
        }
    }

    log.Println("Client disconnected")
}

func main() {
    http.HandleFunc("/ws", handleWebSocket)

    log.Println("Server starting on :8080")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatal(err)
    }
}
```

**What's happening here:**

* `upgrader.Upgrade()` converts a regular HTTP connection to WebSocket
* `conn.ReadMessage()` waits for incoming messages (it blocks the goroutine)
* `conn.WriteMessage()` sends data back to the client
* `CheckOrigin` checks where requests come from - set to allow all for now, but lock this down in production!

## Creating a WebSocket Client (HTML/JavaScript)

Create a simple HTML client to test the server:

```html
<!DOCTYPE html>
<html>
<head>
    <title>WebSocket Chat</title>
</head>
<body>
    <h1>WebSocket Echo Test</h1>
    <input id="messageInput" type="text" placeholder="Type a message" />
    <button onclick="sendMessage()">Send</button>
    <div id="messages"></div>

    <script>
        const ws = new WebSocket('ws://localhost:8080/ws');

        ws.onopen = () => {
            console.log('Connected to server');
            addMessage('Connected to server', 'system');
        };

        ws.onmessage = (event) => {
            console.log('Received:', event.data);
            addMessage(event.data, 'received');
        };

        ws.onclose = () => {
            console.log('Disconnected from server');
            addMessage('Disconnected from server', 'system');
        };

        ws.onerror = (error) => {
            console.error('WebSocket error:', error);
        };

        function sendMessage() {
            const input = document.getElementById('messageInput');
            const message = input.value;
            if (message) {
                ws.send(message);
                addMessage(message, 'sent');
                input.value = '';
            }
        }

        function addMessage(text, type) {
            const messagesDiv = document.getElementById('messages');
            const messageEl = document.createElement('div');
            messageEl.style.color = type === 'system' ? 'gray' : (type === 'sent' ? 'blue' : 'green');
            messageEl.textContent = text;
            messagesDiv.appendChild(messageEl);
        }

        // Allow Enter key to send message
        document.getElementById('messageInput').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendMessage();
        });
    </script>
</body>
</html>
```

Save this as `index.html`, fire up your Go server (`go run .`), and open the HTML in your browser. Type a message, hit send, and watch it bounce right back. Pretty cool, right?

## Building a Real-time Chat Application

The echo server is cute, but let's build something real. We need to handle multiple users chatting at the same time, which means managing lots of connections and broadcasting messages to everyone.

### Architecture Overview

We're using the **Hub pattern**. Think of it as a chat room manager:

1. **Hub** - The brain. It tracks all connected users and routes messages
2. **Client** - Wraps each WebSocket connection with read/write logic
3. **Broadcasting** - When one user sends a message, the Hub pushes it to everyone

This pattern leverages Go's [goroutines and channels]({{< relref "concurrency-in-go-goroutines-and-channels-explained.md" >}}) beautifully. Each client gets two goroutines--one for reading, one for writing. They communicate with the Hub through channels.

### The Hub (Connection Manager)

```go
// hub.go
package main

import (
    "log"
    "sync"
)

type Hub struct {
    // Registered clients
    clients map[*Client]bool

    // Inbound messages from clients
    broadcast chan []byte

    // Register requests from clients
    register chan *Client

    // Unregister requests from clients
    unregister chan *Client

    // Mutex for thread-safe operations (learn more: https://www.buanacoding.com/2025/10/synchronizing-goroutines-in-go-using-syncmutex-and-synconce.html)
    mu sync.RWMutex
}

func NewHub() *Hub {
    return &Hub{
        clients:    make(map[*Client]bool),
        broadcast:  make(chan []byte, 256),
        register:   make(chan *Client),
        unregister: make(chan *Client),
    }
}

func (h *Hub) Run() {
    for {
        select {
        case client := <-h.register:
            h.mu.Lock()
            h.clients[client] = true
            h.mu.Unlock()
            log.Printf("Client registered. Total clients: %d", len(h.clients))

        case client := <-h.unregister:
            h.mu.Lock()
            if _, ok := h.clients[client]; ok {
                delete(h.clients, client)
                close(client.send)
                log.Printf("Client unregistered. Total clients: %d", len(h.clients))
            }
            h.mu.Unlock()

        case message := <-h.broadcast:
            h.mu.RLock()
            for client := range h.clients {
                select {
                case client.send <- message:
                    // Message sent successfully
                default:
                    // Client's send channel is full, close it
                    close(client.send)
                    delete(h.clients, client)
                }
            }
            h.mu.RUnlock()
        }
    }
}
```

### The Client Wrapper

```go
// client.go
package main

import (
    "log"
    "time"

    "github.com/gorilla/websocket"
)

const (
    // Time allowed to write a message to the peer
    writeWait = 10 * time.Second

    // Time allowed to read the next pong message from the peer
    pongWait = 60 * time.Second

    // Send pings to peer with this period (must be less than pongWait)
    pingPeriod = (pongWait * 9) / 10

    // Maximum message size allowed from peer
    maxMessageSize = 512
)

type Client struct {
    hub  *Hub
    conn *websocket.Conn
    send chan []byte
}

func NewClient(hub *Hub, conn *websocket.Conn) *Client {
    return &Client{
        hub:  hub,
        conn: conn,
        send: make(chan []byte, 256),
    }
}

// readPump pumps messages from the WebSocket connection to the hub
func (c *Client) readPump() {
    defer func() {
        c.hub.unregister <- c
        c.conn.Close()
    }()

    c.conn.SetReadDeadline(time.Now().Add(pongWait))
    c.conn.SetPongHandler(func(string) error {
        c.conn.SetReadDeadline(time.Now().Add(pongWait))
        return nil
    })

    c.conn.SetReadLimit(maxMessageSize)

    for {
        _, message, err := c.conn.ReadMessage()
        if err != nil {
            if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
                log.Printf("error: %v", err)
            }
            break
        }

        // Broadcast the message to all clients
        c.hub.broadcast <- message
    }
}

// writePump pumps messages from the hub to the WebSocket connection
func (c *Client) writePump() {
    ticker := time.NewTicker(pingPeriod)
    defer func() {
        ticker.Stop()
        c.conn.Close()
    }()

    for {
        select {
        case message, ok := <-c.send:
            c.conn.SetWriteDeadline(time.Now().Add(writeWait))
            if !ok {
                // The hub closed the channel
                c.conn.WriteMessage(websocket.CloseMessage, []byte{})
                return
            }

            w, err := c.conn.NextWriter(websocket.TextMessage)
            if err != nil {
                return
            }
            w.Write(message)

            // Add queued messages to the current message
            n := len(c.send)
            for i := 0; i < n; i++ {
                w.Write([]byte{'\n'})
                w.Write(<-c.send)
            }

            if err := w.Close(); err != nil {
                return
            }

        case <-ticker.C:
            c.conn.SetWriteDeadline(time.Now().Add(writeWait))
            if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
                return
            }
        }
    }
}
```

### The Main Server

```go
// main.go
package main

import (
    "log"
    "net/http"

    "github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 1024,
    CheckOrigin: func(r *http.Request) bool {
        // In production, validate the origin properly
        return true
    },
}

func serveWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        log.Println(err)
        return
    }

    client := NewClient(hub, conn)
    client.hub.register <- client

    // Start goroutines for reading and writing
    go client.writePump()
    go client.readPump()
}

func main() {
    hub := NewHub()
    go hub.Run()

    http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
        serveWs(hub, w, r)
    })

    // Serve static files (your HTML/CSS/JS)
    http.Handle("/", http.FileServer(http.Dir("./static")))

    log.Println("Chat server starting on :8080")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatal("ListenAndServe:", err)
    }
}
```

### Enhanced Chat Client (HTML)

Create `static/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Real-time Chat</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f0f0f0; }
        .chat-container {
            max-width: 800px;
            margin: 20px auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .chat-header {
            background: #0084ff;
            color: white;
            padding: 20px;
            text-align: center;
        }
        #messages {
            height: 400px;
            overflow-y: auto;
            padding: 20px;
            display: flex;
            flex-direction: column;
        }
        .message {
            margin-bottom: 10px;
            padding: 10px 15px;
            border-radius: 20px;
            max-width: 70%;
            word-wrap: break-word;
        }
        .message.sent {
            background: #0084ff;
            color: white;
            align-self: flex-end;
        }
        .message.received {
            background: #e4e6eb;
            color: black;
            align-self: flex-start;
        }
        .message.system {
            background: #ffeaa7;
            color: #333;
            align-self: center;
            font-size: 12px;
        }
        .chat-input {
            display: flex;
            padding: 20px;
            border-top: 1px solid #ddd;
        }
        #messageInput {
            flex: 1;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 25px;
            outline: none;
            font-size: 14px;
        }
        #sendBtn {
            margin-left: 10px;
            padding: 12px 30px;
            background: #0084ff;
            color: white;
            border: none;
            border-radius: 25px;
            cursor: pointer;
            font-size: 14px;
        }
        #sendBtn:hover { background: #0073e6; }
        #sendBtn:disabled {
            background: #ccc;
            cursor: not-allowed;
        }
    </style>
</head>
<body>
    <div class="chat-container">
        <div class="chat-header">
            <h1>Real-time Chat</h1>
            <p id="status">Connecting...</p>
        </div>
        <div id="messages"></div>
        <div class="chat-input">
            <input id="messageInput" type="text" placeholder="Type a message..." disabled />
            <button id="sendBtn" disabled>Send</button>
        </div>
    </div>

    <script>
        let ws;
        const messagesDiv = document.getElementById('messages');
        const messageInput = document.getElementById('messageInput');
        const sendBtn = document.getElementById('sendBtn');
        const statusEl = document.getElementById('status');

        function connect() {
            ws = new WebSocket('ws://localhost:8080/ws');

            ws.onopen = () => {
                console.log('Connected');
                statusEl.textContent = 'Connected';
                statusEl.style.color = '#00ff00';
                messageInput.disabled = false;
                sendBtn.disabled = false;
                addMessage('You joined the chat', 'system');
            };

            ws.onmessage = (event) => {
                addMessage(event.data, 'received');
            };

            ws.onclose = () => {
                console.log('Disconnected');
                statusEl.textContent = 'Disconnected - Reconnecting...';
                statusEl.style.color = '#ff0000';
                messageInput.disabled = true;
                sendBtn.disabled = true;
                addMessage('Connection lost. Reconnecting...', 'system');

                // Reconnect after 3 seconds
                setTimeout(connect, 3000);
            };

            ws.onerror = (error) => {
                console.error('WebSocket error:', error);
            };
        }

        function sendMessage() {
            const message = messageInput.value.trim();
            if (message && ws.readyState === WebSocket.OPEN) {
                ws.send(message);
                addMessage(message, 'sent');
                messageInput.value = '';
            }
        }

        function addMessage(text, type) {
            const messageEl = document.createElement('div');
            messageEl.className = `message ${type}`;
            messageEl.textContent = text;
            messagesDiv.appendChild(messageEl);
            messagesDiv.scrollTop = messagesDiv.scrollHeight;
        }

        sendBtn.addEventListener('click', sendMessage);
        messageInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendMessage();
        });

        // Connect on page load
        connect();
    </script>
</body>
</html>
```

## Running the Chat Application

Time to see it in action:

1. Save all three Go files (`hub.go`, `client.go`, `main.go`) in your project root
2. Create a `static/` folder and drop the `index.html` in there
3. Run the server: `go run .`
4. Open `http://localhost:8080` in multiple browser tabs/windows
5. Start chatting! Messages appear instantly across all tabs

Try opening it on your phone too (use your local IP like `192.168.1.x:8080`). Watch messages fly between devices in real-time. That's the power of WebSocket!

## Production Best Practices

### 1. Origin Validation

In production, restrict allowed origins:

```go
var upgrader = websocket.Upgrader{
    CheckOrigin: func(r *http.Request) bool {
        origin := r.Header.Get("Origin")
        return origin == "https://yourdomain.com"
    },
}
```

### 2. Authentication

Never trust anonymous connections in production. Validate [JWT tokens]({{< relref "how-to-implement-jwt-authentication-in-go-secure-rest-api.md" >}}) before the upgrade:

```go
func serveWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
    // Validate JWT token from query param or cookie
    token := r.URL.Query().Get("token")
    if !validateToken(token) {
        http.Error(w, "Unauthorized", http.StatusUnauthorized)
        return
    }

    conn, err := upgrader.Upgrade(w, r, nil)
    // ... rest of the code
}
```

You can also check auth via cookies or custom headers. The key is: **authenticate BEFORE upgrading to WebSocket**, not after.

### 3. Rate Limiting

Someone will try to spam your chat. Guaranteed. Add simple rate limiting to keep things civil:

```go
type Client struct {
    // ... existing fields
    lastMessageTime time.Time
    messageCount    int
}

func (c *Client) readPump() {
    // ... setup code

    for {
        _, message, err := c.conn.ReadMessage()
        if err != nil {
            break
        }

        // Rate limiting: max 10 messages per second
        now := time.Now()
        if now.Sub(c.lastMessageTime) < time.Second {
            c.messageCount++
            if c.messageCount > 10 {
                log.Println("Rate limit exceeded")
                continue
            }
        } else {
            c.messageCount = 0
            c.lastMessageTime = now
        }

        c.hub.broadcast <- message
    }
}
```

### 4. Message Size Limits

We already set `maxMessageSize = 512` bytes earlier. Adjust this based on your use case. Text chat? 512 is plenty. Sharing code snippets? Bump it to 4096 or higher. Just don't allow unlimited sizes--someone will send the entire Bee Movie script and crash your server.

### 5. Graceful Shutdown

When deploying updates, don't just kill the server. Give active connections time to close properly. Here's how to handle shutdown signals gracefully using [context]({{< relref "using-context-in-go-cancellation-timeout-and-deadlines-explained.md" >}}):

```go
func main() {
    hub := NewHub()
    go hub.Run()

    // ... setup routes

    server := &http.Server{
        Addr: ":8080",
    }

    // Handle shutdown signals
    go func() {
        sigint := make(chan os.Signal, 1)
        signal.Notify(sigint, os.Interrupt, syscall.SIGTERM)
        <-sigint

        log.Println("Shutting down server...")
        ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
        defer cancel()

        if err := server.Shutdown(ctx); err != nil {
            log.Printf("Server shutdown error: %v", err)
        }
    }()

    log.Println("Server starting on :8080")
    if err := server.ListenAndServe(); err != http.ErrServerClosed {
        log.Fatal(err)
    }
}
```

### 6. TLS/WSS in Production

**Never run WebSocket over plain `ws://` in production.** Always use secure WebSocket (`wss://`) with TLS certificates:

```go
// Use Let's Encrypt certificates
log.Fatal(http.ListenAndServeTLS(":443", "cert.pem", "key.pem", nil))
```

Update your client to use `wss://`:

```javascript
const ws = new WebSocket('wss://yourdomain.com/ws');
```

Without TLS, anyone on the network can read your chat messages. Not cool.

## Testing the Application

Testing WebSocket is tricky since it involves persistent connections. Here's a basic test to get you started:

```go
// hub_test.go
package main

import (
    "testing"
    "time"
)

func TestHubBroadcast(t *testing.T) {
    hub := NewHub()
    go hub.Run()

    // Simulate message broadcast
    testMessage := []byte("Hello, World!")
    hub.broadcast <- testMessage

    // Give time for processing
    time.Sleep(100 * time.Millisecond)

    // In real tests, you'd verify client received the message
    // This is a simplified example
}
```

For more thorough testing, check out [Testing in Go]({{< relref "testing-in-go-writing-unit-tests-with-the-testing-package.md" >}}) and use the `httptest` package to simulate WebSocket upgrades.

## Monitoring and Debugging

Want to know how many people are connected? Add a simple stats endpoint:

```go
func (h *Hub) GetStats() map[string]int {
    h.mu.RLock()
    defer h.mu.RUnlock()

    return map[string]int{
        "clients": len(h.clients),
    }
}

// Add an HTTP endpoint for stats
http.HandleFunc("/stats", func(w http.ResponseWriter, r *http.Request) {
    stats := hub.GetStats()
    json.NewEncoder(w).Encode(stats)
})
```

Hit `/stats` and you'll get JSON like `{"clients": 42}`. In production, pipe this to your monitoring system (Prometheus, Datadog, whatever you use). Track connection counts, message rates, and errors. If you see connections spiking or messages slowing down, you'll know before users start complaining.

## Conclusion

You just built a real-time chat app from scratch! The Hub pattern keeps things organized, goroutines and channels handle the concurrency, and with a few production tweaks, this code is ready for the real world.

**What you learned:**

* WebSocket basics and when to use them
* Building servers with `gorilla/websocket`
* The Hub pattern for managing multiple connections
* Using [goroutines]({{< relref "concurrency-in-go-goroutines-and-channels-explained.md" >}}) for concurrent read/write operations
* Production essentials: auth, rate limiting, graceful shutdown
* Security with origin validation and TLS/WSS

**Take it further:**

* Add user authentication and private rooms
* Store message history in a database like [MongoDB]({{< relref "how-to-work-with-mongodb-in-go-complete-crud-tutorial.md" >}}) or [PostgreSQL]({{< relref "connecting-postgresql-in-go-using-sqlx.md" >}})
* Scale horizontally with [Redis]({{< relref "how-to-use-redis-with-go-caching-session-management.md" >}}) Pub/Sub
* Show who's online (presence detection)
* Add typing indicators ("User is typing...")
* Support file/image sharing

Go and WebSocket make a killer combo for real-time apps. Now go build something awesome!
