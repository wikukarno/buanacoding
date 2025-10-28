---
title: "API Gateway with Golang - Load Balancing and Rate Limiting Implementation"
date: 2025-09-29T07:00:00+07:00
draft: false
url: /2025/09/api-gateway-golang-load-balancing-rate-limiting.html
tags:
  - Go
  - API Gateway
  - Load Balancing
  - Rate Limiting
  - Microservices
  - Performance
description: "Learn how to build a production-ready API Gateway in Go with advanced load balancing algorithms and rate limiting mechanisms. Complete implementation guide with real-world examples and best practices."
keywords: ["golang api gateway", "load balancing go", "rate limiting golang", "microservices gateway", "reverse proxy go", "api rate limiting", "round robin load balancer", "golang middleware"]
faq:
  - question: "What's the difference between Round Robin and Weighted Round Robin load balancing?"
    answer: "Round Robin distributes requests equally--each backend gets same number of requests in rotation: Backend1 -> Backend2 -> Backend3 -> repeat. Simple, fair for identical backends. Weighted Round Robin assigns different traffic proportions based on backend capacity--powerful server gets weight 3, weaker gets weight 1, so powerful server handles 3× traffic. Use Round Robin when: all backends identical specs, simple setup needed. Use Weighted when: mixed server specs (8-core and 4-core instances), gradual migration (new version weight 1, old version weight 9 during canary deploy), premium/economy tiers. Algorithm: Weighted tracks current weights, increments by backend's weight each round, selects highest, then subtracts total weight from selected. Ensures proportional distribution over time. Production: most start with Round Robin, switch to Weighted when adding heterogeneous backends or doing canary releases."
  - question: "Should I use in-memory or Redis-based rate limiting for production?"
    answer: "Use Redis for distributed systems (multiple gateway instances), in-memory for single instance. In-memory rate limiting: (1) Faster--no network latency, ~1μs decision. (2) Simple--no external dependency. (3) Per-instance--if 3 gateways, each allows 100 req/s = 300 total. (4) Lost on restart--limits reset. Use when: single gateway, low traffic, development. Redis rate limiting: (1) Centralized--all gateways share limits, 100 req/s total across all instances. (2) Persistent--survives gateway restarts. (3) Slower--network round trip adds ~1-5ms. (4) Scales horizontally. Use when: multiple gateways, need exact limits, high availability. Hybrid approach: in-memory for first-pass (fast rejection), Redis for accurate tracking (check only if in-memory allows). Implementation: use golang.org/x/time/rate for in-memory, sorted sets in Redis for sliding window. Production: start in-memory for speed, add Redis when scaling to multiple instances."
  - question: "How do I handle backend health checks without overloading backends?"
    answer: "Passive health checks + adaptive active checks. Passive: track request failures--if backend returns 3 consecutive 5xx errors, mark unhealthy, retry after cooldown. No extra load, reacts to real traffic. Active: periodic health endpoint checks--but smart intervals: (1) Start with 30s for healthy backends. (2) Increase to 10s if one 5xx seen (warning state). (3) Check every 5s when marked unhealthy (trying to recover). (4) Return to 30s after 3 successful checks. Avoid: checking every 1s--10 backends = 10 req/s just for health, wastes resources. Health endpoint: lightweight /health that checks: (1) Can connect to database (connection pool check, not query). (2) Disk not full. (3) Memory available. Don't: run expensive queries, external API calls. Circuit breaker pattern: after 5 consecutive failures, open circuit (stop sending traffic), half-open after 30s (send 1 test request), close if succeeds. Code: track lastHealthCheck timestamp, adjust interval based on state. This balances quick failure detection with minimal overhead."
  - question: "Why does my API Gateway run out of file descriptors in production?"
    answer: "File descriptor exhaustion happens when gateway opens more connections than OS limit. Each backend connection + client connection uses FD. Default limit often 1024, production needs 10k-100k. Causes: (1) No connection reuse--creating new HTTP client per request instead of shared client with connection pool. (2) No timeouts--hung connections never close. (3) Too many backends--100 backends × 100 idle conns = 10k FDs. (4) Leaking connections--not closing response bodies: resp.Body.Close(). Fixes: (1) Shared HTTP client: var client = &http.Client{Transport: &http.Transport{MaxIdleConns: 100, MaxIdleConnsPerHost: 10}}. (2) Set timeouts: ReadTimeout, WriteTimeout on http.Server. (3) OS limits: ulimit -n 65535, or systemd LimitNOFILE=65535. (4) Close bodies: defer resp.Body.Close() after every request. (5) Monitor: track open FDs with lsof -p <pid> | wc -l. (6) Connection pooling: reuse connections via keep-alive. Production tuning: start with MaxIdleConnsPerHost=50, adjust based on load testing. Each backend connection stays open ~90s by default, plan accordingly."
  - question: "How do I implement per-user rate limiting instead of per-IP?"
    answer: "Extract user ID from authentication token instead of IP address. Implementation: (1) Parse JWT/API key from Authorization header: claims := parseJWT(r.Header.Get(\"Authorization\")), userID := claims.Sub. (2) Use userID as rate limit key: rateLimiter.Allow(userID). (3) Fallback to IP for unauthenticated: clientID := userID; if clientID == \"\" { clientID = getClientIP(r) }. (4) Different limits per tier: premium users 1000 req/min, free users 100 req/min. Store limits in config/database keyed by user tier. Code pattern: type RateLimitConfig struct { Free: int; Premium: int }; limit := config.Free; if user.Tier == \"premium\" { limit = config.Premium }; limiter := rate.NewLimiter(rate.Limit(limit), burst). Challenges: (1) Anonymous users--still need IP-based limit for unauthenticated endpoints. (2) Token refresh--don't count auth endpoints against user limit (separate bucket). (3) Shared accounts--team API key, limit per key not per user. Advanced: hierarchical limits--100 req/s per user, 10k req/s per organization. Use Redis hash: key 'org:123:user:456' tracks user, 'org:123' tracks org total. Check both, reject if either exceeds."
  - question: "What's the best way to handle WebSocket connections through API Gateway?"
    answer: "Use httputil.ReverseProxy with custom Director for WebSocket upgrade. Standard reverse proxy works but needs WebSocket awareness: (1) Preserve Upgrade headers: proxy.Director = func(req *http.Request) { req.Header.Set(\"Upgrade\", \"websocket\"); req.Header.Set(\"Connection\", \"Upgrade\") }. (2) Disable buffering: proxy.FlushInterval = -1 (required for streaming). (3) Long timeouts: ReadHeaderTimeout = 0 or very high (websockets stay open for hours). (4) Sticky sessions--same user always hits same backend: use consistent hashing based on user ID/session cookie. Round robin breaks stateful websockets. Implementation: detect websocket: if r.Header.Get(\"Upgrade\") == \"websocket\" { useConsistentHashing() } else { useRoundRobin() }. Challenges: (1) Rate limiting websockets--limit connection attempts, not messages (hard to count without parsing). (2) Connection draining--when removing backend, allow existing websockets to finish (grace period). (3) Scaling--websockets tie connections to specific backends, harder to load balance. Consider: dedicated websocket gateway vs HTTP gateway, or use sticky sessions with session affinity cookies. Production: AWS ALB/NLB handle websockets better than custom gateway for high scale."
---

When you're building distributed systems, one component stands between chaos and order: the API Gateway. Think of it as the bouncer at an exclusive club - it decides who gets in, where they go, and how fast they can enter. After working with various microservice architectures, I can tell you that a well-implemented API Gateway is often the difference between a system that scales gracefully and one that crumbles under pressure.

Building an API Gateway might sound intimidating, but Go's excellent standard library and concurrency model make it surprisingly straightforward. Today, we'll build a complete API Gateway that handles load balancing across multiple backend services and implements intelligent rate limiting to protect your infrastructure from abuse.

The beauty of implementing this in Go lies in its simplicity and performance. While enterprise solutions like Kong or AWS API Gateway are fantastic, sometimes you need something tailored to your specific requirements. Plus, understanding how these systems work under the hood makes you a better architect.

## Why You Need an API Gateway

Before diving into implementation, let's understand why API Gateways have become essential in modern architectures. In a monolithic application, you typically have one entry point. But when you break that monolith into microservices, suddenly your client applications need to know about dozens of different service endpoints.

An API Gateway solves several critical problems. First, it provides a single entry point for all client requests, hiding the complexity of your backend architecture. Your mobile app doesn't need to know whether user authentication lives on one server while payment processing happens on another.

Second, it centralizes cross-cutting concerns like authentication, logging, and monitoring. Instead of implementing these features in every microservice, you handle them once at the gateway level. This reduces code duplication and ensures consistent behavior across your entire API surface.

Most importantly for our discussion today, it provides traffic management capabilities. Load balancing ensures your requests are distributed efficiently across healthy backend instances, while rate limiting protects your services from being overwhelmed by traffic spikes or malicious attacks.

## Setting Up the Project Structure

Let's start with a clean project structure that will make our code maintainable and testable. If you're new to Go project organization, check out our guide on [structuring Go projects with clean architecture]({{< relref "blog/go/structuring-go-projects-clean-project-structure-and-best-practices.md" >}}) for more detailed insights.

```bash
mkdir api-gateway
cd api-gateway
go mod init api-gateway
```

Create the following directory structure:

```
api-gateway/
├── main.go
├── internal/
│   ├── gateway/
│   │   ├── gateway.go
│   │   ├── loadbalancer.go
│   │   └── ratelimiter.go
│   ├── config/
│   │   └── config.go
│   └── middleware/
│       ├── logging.go
│       └── recovery.go
├── pkg/
│   └── healthcheck/
│       └── healthcheck.go
└── configs/
    └── gateway.yaml
```

Install the required dependencies:

```bash
go get github.com/gorilla/mux
go get github.com/go-redis/redis/v8
go get golang.org/x/time/rate
go get gopkg.in/yaml.v2
```

## Building the Core Gateway Structure

Let's start with the configuration structure that will drive our gateway behavior:

```go
// internal/config/config.go
package config

import (
    "io/ioutil"
    "gopkg.in/yaml.v2"
)

type Config struct {
    Gateway   GatewayConfig   `yaml:"gateway"`
    Services  []ServiceConfig `yaml:"services"`
    RateLimit RateLimitConfig `yaml:"rateLimit"`
}

type GatewayConfig struct {
    Port    string `yaml:"port"`
    Timeout int    `yaml:"timeout"`
}

type ServiceConfig struct {
    Name      string   `yaml:"name"`
    Path      string   `yaml:"path"`
    Instances []string `yaml:"instances"`
    Strategy  string   `yaml:"strategy"`
}

type RateLimitConfig struct {
    RequestsPerSecond int    `yaml:"requestsPerSecond"`
    BurstSize         int    `yaml:"burstSize"`
    RedisURL          string `yaml:"redisURL"`
}

func LoadConfig(path string) (*Config, error) {
    data, err := ioutil.ReadFile(path)
    if err != nil {
        return nil, err
    }

    var config Config
    err = yaml.Unmarshal(data, &config)
    if err != nil {
        return nil, err
    }

    return &config, nil
}
```

Create a configuration file that defines your services and policies:

```yaml
# configs/gateway.yaml
gateway:
  port: ":8080"
  timeout: 30

services:
  - name: "user-service"
    path: "/api/users"
    instances:
      - "http://localhost:8081"
      - "http://localhost:8082"
      - "http://localhost:8083"
    strategy: "round_robin"

  - name: "order-service"
    path: "/api/orders"
    instances:
      - "http://localhost:8084"
      - "http://localhost:8085"
    strategy: "weighted_round_robin"

rateLimit:
  requestsPerSecond: 100
  burstSize: 10
  redisURL: "redis://localhost:6379"
```

## Implementing Load Balancing Algorithms

Now let's implement the heart of our gateway - the load balancer. We'll support multiple algorithms because different scenarios call for different strategies:

```go
// internal/gateway/loadbalancer.go
package gateway

import (
    "net/http"
    "net/http/httputil"
    "net/url"
    "sync"
    "sync/atomic"
    "time"
)

type Backend struct {
    URL          *url.URL
    Alive        bool
    ReverseProxy *httputil.ReverseProxy
    Weight       int
    Connections  int64
}

type LoadBalancer interface {
    GetNextBackend() *Backend
    MarkBackendStatus(backend *Backend, alive bool)
}

type RoundRobinBalancer struct {
    backends []*Backend
    current  uint64
    mutex    sync.RWMutex
}

func NewRoundRobinBalancer(urls []string) *RoundRobinBalancer {
    var backends []*Backend

    for _, u := range urls {
        url, _ := url.Parse(u)
        backend := &Backend{
            URL:          url,
            Alive:        true,
            ReverseProxy: httputil.NewSingleHostReverseProxy(url),
            Weight:       1,
        }
        backends = append(backends, backend)
    }

    return &RoundRobinBalancer{
        backends: backends,
    }
}

func (rb *RoundRobinBalancer) GetNextBackend() *Backend {
    rb.mutex.RLock()
    defer rb.mutex.RUnlock()

    if len(rb.backends) == 0 {
        return nil
    }

    next := atomic.AddUint64(&rb.current, 1)
    return rb.backends[(next-1)%uint64(len(rb.backends))]
}

func (rb *RoundRobinBalancer) MarkBackendStatus(backend *Backend, alive bool) {
    rb.mutex.Lock()
    defer rb.mutex.Unlock()
    backend.Alive = alive
}

type WeightedRoundRobinBalancer struct {
    backends        []*Backend
    currentWeights  []int
    totalWeight     int
    mutex          sync.RWMutex
}

func NewWeightedRoundRobinBalancer(urls []string, weights []int) *WeightedRoundRobinBalancer {
    var backends []*Backend
    totalWeight := 0

    for i, u := range urls {
        url, _ := url.Parse(u)
        weight := 1
        if i < len(weights) {
            weight = weights[i]
        }

        backend := &Backend{
            URL:          url,
            Alive:        true,
            ReverseProxy: httputil.NewSingleHostReverseProxy(url),
            Weight:       weight,
        }
        backends = append(backends, backend)
        totalWeight += weight
    }

    return &WeightedRoundRobinBalancer{
        backends:       backends,
        currentWeights: make([]int, len(backends)),
        totalWeight:    totalWeight,
    }
}

func (wrb *WeightedRoundRobinBalancer) GetNextBackend() *Backend {
    wrb.mutex.Lock()
    defer wrb.mutex.Unlock()

    if len(wrb.backends) == 0 {
        return nil
    }

    var selected *Backend
    maxWeight := -1

    for i, backend := range wrb.backends {
        if !backend.Alive {
            continue
        }

        wrb.currentWeights[i] += backend.Weight

        if wrb.currentWeights[i] > maxWeight {
            maxWeight = wrb.currentWeights[i]
            selected = backend
        }
    }

    if selected != nil {
        for i, backend := range wrb.backends {
            if backend == selected {
                wrb.currentWeights[i] -= wrb.totalWeight
                break
            }
        }
    }

    return selected
}

func (wrb *WeightedRoundRobinBalancer) MarkBackendStatus(backend *Backend, alive bool) {
    wrb.mutex.Lock()
    defer wrb.mutex.Unlock()
    backend.Alive = alive
}
```

## Implementing Rate Limiting

Rate limiting is crucial for protecting your backend services from abuse. We'll implement both in-memory and Redis-based rate limiting:

```go
// internal/gateway/ratelimiter.go
package gateway

import (
    "context"
    "fmt"
    "net/http"
    "time"

    "github.com/go-redis/redis/v8"
    "golang.org/x/time/rate"
)

type RateLimiter interface {
    Allow(clientID string) bool
}

type InMemoryRateLimiter struct {
    limiters map[string]*rate.Limiter
    rate     rate.Limit
    burst    int
}

func NewInMemoryRateLimiter(r rate.Limit, b int) *InMemoryRateLimiter {
    return &InMemoryRateLimiter{
        limiters: make(map[string]*rate.Limiter),
        rate:     r,
        burst:    b,
    }
}

func (rl *InMemoryRateLimiter) Allow(clientID string) bool {
    limiter, exists := rl.limiters[clientID]
    if !exists {
        limiter = rate.NewLimiter(rl.rate, rl.burst)
        rl.limiters[clientID] = limiter
    }

    return limiter.Allow()
}

type RedisRateLimiter struct {
    client *redis.Client
    window time.Duration
    limit  int64
}

func NewRedisRateLimiter(redisURL string, window time.Duration, limit int64) (*RedisRateLimiter, error) {
    opt, err := redis.ParseURL(redisURL)
    if err != nil {
        return nil, err
    }

    client := redis.NewClient(opt)

    return &RedisRateLimiter{
        client: client,
        window: window,
        limit:  limit,
    }, nil
}

func (rl *RedisRateLimiter) Allow(clientID string) bool {
    ctx := context.Background()
    now := time.Now()
    key := fmt.Sprintf("rate_limit:%s", clientID)

    pipe := rl.client.TxPipeline()

    // Remove expired entries
    pipe.ZRemRangeByScore(ctx, key, "0", fmt.Sprintf("%d", now.Add(-rl.window).UnixNano()))

    // Add current request
    pipe.ZAdd(ctx, key, &redis.Z{
        Score:  float64(now.UnixNano()),
        Member: now.UnixNano(),
    })

    // Count requests in window
    countCmd := pipe.ZCard(ctx, key)

    // Set expiration
    pipe.Expire(ctx, key, rl.window)

    _, err := pipe.Exec(ctx)
    if err != nil {
        return false
    }

    count := countCmd.Val()
    return count <= rl.limit
}
```

## Building the Gateway Core

Now let's tie everything together in our main gateway implementation:

```go
// internal/gateway/gateway.go
package gateway

import (
    "log"
    "net/http"
    "net/http/httputil"
    "strings"
    "time"

    "api-gateway/internal/config"
)

type Gateway struct {
    config       *config.Config
    loadBalancer map[string]LoadBalancer
    rateLimiter  RateLimiter
}

func NewGateway(cfg *config.Config) (*Gateway, error) {
    gateway := &Gateway{
        config:       cfg,
        loadBalancer: make(map[string]LoadBalancer),
    }

    // Initialize load balancers for each service
    for _, service := range cfg.Services {
        switch service.Strategy {
        case "round_robin":
            gateway.loadBalancer[service.Name] = NewRoundRobinBalancer(service.Instances)
        case "weighted_round_robin":
            // For simplicity, using equal weights. In production, you'd read weights from config
            weights := make([]int, len(service.Instances))
            for i := range weights {
                weights[i] = 1
            }
            gateway.loadBalancer[service.Name] = NewWeightedRoundRobinBalancer(service.Instances, weights)
        default:
            gateway.loadBalancer[service.Name] = NewRoundRobinBalancer(service.Instances)
        }
    }

    // Initialize rate limiter
    if cfg.RateLimit.RedisURL != "" {
        rl, err := NewRedisRateLimiter(cfg.RateLimit.RedisURL, time.Second, int64(cfg.RateLimit.RequestsPerSecond))
        if err != nil {
            return nil, err
        }
        gateway.rateLimiter = rl
    } else {
        gateway.rateLimiter = NewInMemoryRateLimiter(
            rate.Limit(cfg.RateLimit.RequestsPerSecond),
            cfg.RateLimit.BurstSize,
        )
    }

    return gateway, nil
}

func (g *Gateway) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    // Rate limiting
    clientID := g.getClientID(r)
    if !g.rateLimiter.Allow(clientID) {
        http.Error(w, "Rate limit exceeded", http.StatusTooManyRequests)
        return
    }

    // Find matching service
    service := g.findService(r.URL.Path)
    if service == nil {
        http.Error(w, "Service not found", http.StatusNotFound)
        return
    }

    // Get backend from load balancer
    lb := g.loadBalancer[service.Name]
    backend := lb.GetNextBackend()
    if backend == nil || !backend.Alive {
        http.Error(w, "No healthy backends available", http.StatusServiceUnavailable)
        return
    }

    // Update request path
    r.URL.Path = strings.TrimPrefix(r.URL.Path, service.Path)
    r.URL.Host = backend.URL.Host
    r.URL.Scheme = backend.URL.Scheme
    r.Header.Set("X-Forwarded-Host", r.Header.Get("Host"))
    r.Header.Set("X-Origin-Host", backend.URL.Host)

    // Proxy the request
    backend.ReverseProxy.ServeHTTP(w, r)
}

func (g *Gateway) getClientID(r *http.Request) string {
    // In production, you might use API keys, JWT sub claims, or IP addresses
    clientIP := r.Header.Get("X-Forwarded-For")
    if clientIP == "" {
        clientIP = r.Header.Get("X-Real-IP")
    }
    if clientIP == "" {
        clientIP = r.RemoteAddr
    }
    return clientIP
}

func (g *Gateway) findService(path string) *config.ServiceConfig {
    for _, service := range g.config.Services {
        if strings.HasPrefix(path, service.Path) {
            return &service
        }
    }
    return nil
}
```

## Adding Health Checks and Monitoring

A production API Gateway needs robust health checking to remove unhealthy backends from rotation:

```go
// pkg/healthcheck/healthcheck.go
package healthcheck

import (
    "net/http"
    "time"
)

func IsBackendHealthy(url string, timeout time.Duration) bool {
    client := &http.Client{
        Timeout: timeout,
    }

    resp, err := client.Get(url + "/health")
    if err != nil {
        return false
    }
    defer resp.Body.Close()

    return resp.StatusCode == http.StatusOK
}

func StartHealthChecker(backends []*Backend, interval time.Duration) {
    ticker := time.NewTicker(interval)
    go func() {
        for range ticker.C {
            for _, backend := range backends {
                healthy := IsBackendHealthy(backend.URL.String(), 5*time.Second)
                backend.Alive = healthy
            }
        }
    }()
}
```

## Putting It All Together

Finally, let's create our main application that brings all components together:

```go
// main.go
package main

import (
    "log"
    "net/http"
    "time"

    "api-gateway/internal/config"
    "api-gateway/internal/gateway"

    "github.com/gorilla/mux"
)

func main() {
    // Load configuration
    cfg, err := config.LoadConfig("configs/gateway.yaml")
    if err != nil {
        log.Fatal("Failed to load config:", err)
    }

    // Create gateway
    gw, err := gateway.NewGateway(cfg)
    if err != nil {
        log.Fatal("Failed to create gateway:", err)
    }

    // Setup routes
    router := mux.NewRouter()
    router.PathPrefix("/").Handler(gw)

    // Configure server
    server := &http.Server{
        Addr:         cfg.Gateway.Port,
        Handler:      router,
        ReadTimeout:  time.Duration(cfg.Gateway.Timeout) * time.Second,
        WriteTimeout: time.Duration(cfg.Gateway.Timeout) * time.Second,
    }

    log.Printf("API Gateway starting on %s", cfg.Gateway.Port)
    log.Fatal(server.ListenAndServe())
}
```

## Testing Your API Gateway

To test your gateway, you'll need some backend services. Here's a simple test server you can run on different ports:

```go
// test-server/main.go
package main

import (
    "encoding/json"
    "flag"
    "log"
    "net/http"
    "os"
)

func main() {
    port := flag.String("port", "8081", "Server port")
    flag.Parse()

    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        json.NewEncoder(w).Encode(map[string]string{"status": "healthy", "port": *port})
    })

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        hostname, _ := os.Hostname()
        response := map[string]string{
            "message":  "Hello from backend",
            "port":     *port,
            "hostname": hostname,
            "path":     r.URL.Path,
        }
        json.NewEncoder(w).Encode(response)
    })

    log.Printf("Test server starting on :%s", *port)
    log.Fatal(http.ListenAndServe(":"+*port, nil))
}
```

Run multiple instances:

```bash
go run test-server/main.go -port=8081 &
go run test-server/main.go -port=8082 &
go run test-server/main.go -port=8083 &
```

Then start your gateway and test it:

```bash
go run main.go
curl http://localhost:8080/api/users/profile
```

## Performance Considerations and Best Practices

When building production API Gateways, performance is paramount. Go's goroutines make it naturally well-suited for this task, but there are several optimizations to consider.

First, connection pooling is crucial. The default HTTP client in Go reuses connections, but you should tune the transport settings based on your expected load. Consider setting MaxIdleConns and MaxIdleConnsPerHost appropriately.

For rate limiting, Redis provides better scalability across multiple gateway instances, but in-memory limiting offers lower latency. Choose based on your architecture - if you're running a single gateway instance, in-memory might be sufficient.

Health checking frequency should balance between quick failure detection and unnecessary load on your backends. Start with 30-second intervals and adjust based on your requirements.

Monitoring and observability are essential. Consider integrating with [structured logging in Go using slog]({{< relref "blog/go/complete-guide-slog-go-structured-logging-2025.md" >}}) to get better insights into your gateway's behavior.

## Extending Your Gateway

This implementation provides a solid foundation, but production gateways often need additional features. Consider adding authentication middleware, request/response transformation, circuit breakers for handling backend failures gracefully, and metrics collection for monitoring.

You might also want to implement more sophisticated load balancing algorithms like least connections or consistent hashing, especially if you're dealing with stateful backends or want to optimize cache hit rates.

For high-availability deployments, consider how you'll handle configuration updates without downtime and how multiple gateway instances will coordinate, especially for features like rate limiting that require shared state.

Building an API Gateway in Go gives you complete control over your traffic management logic while leveraging Go's excellent performance characteristics. Start with this foundation and extend it based on your specific requirements. The modular design makes it easy to add new features without disrupting existing functionality.

Remember that an API Gateway is a critical piece of infrastructure - invest time in testing, monitoring, and documentation. Your future self and your team will thank you when it's 3 AM and you need to debug a production issue.