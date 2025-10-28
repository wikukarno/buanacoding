---
title: "Service Discovery in Microservices Golang - Consul and etcd Implementation"
date: 2025-09-29T08:00:00+07:00
draft: false
url: /2025/09/service-discovery-microservices-golang-consul-etcd.html
tags:
  - Go
  - Microservices
  - Service Discovery
  - Consul
  - etcd
  - Distributed Systems
description: "Master service discovery in Go microservices using Consul and etcd. Complete implementation guide with registration, health checks, load balancing, and production best practices."
keywords: ["golang service discovery", "consul golang", "etcd golang", "microservices golang", "service registry", "distributed systems go", "consul health check", "etcd watch api"]
faq:
  - question: "What’s the difference between Consul and etcd for service discovery?"
    answer: "Consul ships with first-class service discovery primitives (health checks, DNS, key/value) and is easy to adopt. etcd offers a strongly consistent key-value store with efficient watch APIs, great for custom discovery. Choose Consul for batteries-included discovery, etcd when you need a general-purpose, consistent store."
  - question: "Should I use client-side or server-side discovery?"
    answer: "Client-side discovery queries the registry directly and picks an instance; it’s simple and fast but adds logic to clients. Server-side discovery offloads selection to a proxy/load balancer (e.g., Envoy), centralizing policies and enabling advanced traffic management. Many systems use both."
  - question: "How do I implement health checks effectively?"
    answer: "Expose /health endpoints with meaningful checks (DB, cache). Register checks in Consul or use TTL-based heartbeats. Ensure failing instances are quickly removed and use retries with backoff."
  - question: "How do I secure service discovery traffic?"
    answer: "Enable mTLS between services and the registry, use ACLs (Consul) or RBAC with TLS (etcd), and restrict access at the network layer. Rotate certificates and keep minimal privileges for each service."
  - question: "What happens during network partitions?"
    answer: "Design for partial failures: set sensible timeouts, retries, and circuit breakers. etcd prioritizes consistency and may reject writes during quorum loss; Consul uses anti-entropy and eventually converges--plan fallback behavior accordingly."
  - question: "Do I still need a service mesh if I use Consul/etcd?"
    answer: "A registry solves discovery; a mesh adds mTLS, retries, timeouts, traffic shaping, and observability without code changes. Use a mesh when you need uniform cross-cutting policies at scale."
---

In the early days of web development, finding services was simple. Your database lived at `localhost:5432`, your cache at `localhost:6379`, and everything was predictable. But when you move to microservices, suddenly you have dozens of services spinning up and down across multiple servers, and nobody knows where anything is anymore.

This is where service discovery becomes your lifeline. Instead of hardcoding addresses and hoping for the best, you get a dynamic phone book that keeps track of who's available, where they live, and whether they're actually working. After building several distributed systems in Go, I can tell you that getting service discovery right is often the difference between a system that scales gracefully and one that becomes an operational nightmare.

Today, we'll implement service discovery using two of the most popular tools in the ecosystem: Consul and etcd. Both have their strengths, and understanding how to work with each will make you a more effective distributed systems engineer. We'll build real implementations that handle service registration, health checking, and automatic failover.

## Understanding Service Discovery Fundamentals

Before diving into implementation, let's understand what service discovery solves. In a traditional monolithic application, components communicate through direct method calls or well-known local endpoints. When you break that monolith into microservices, those components become separate processes that need to find and communicate with each other over the network.

The challenge isn't just finding services - it's finding healthy instances. Services crash, get overloaded, or become temporarily unavailable. A good service discovery system automatically removes unhealthy instances from rotation and adds them back when they recover.

Service discovery operates on two main patterns: client-side and server-side discovery. In client-side discovery, the service consumer queries the service registry directly and chooses which instance to call. In server-side discovery, clients make requests to a load balancer that queries the service registry and forwards requests to healthy instances.

Both Consul and etcd excel at different aspects of this problem. Consul provides built-in health checking, DNS integration, and a robust HTTP API. etcd offers strong consistency guarantees, efficient watching mechanisms, and excellent performance under high load. Understanding when to use each is crucial for building resilient systems.

## Setting Up the Development Environment

Let's start by setting up both Consul and etcd locally, then build our Go services that can work with either system. This approach gives you flexibility to choose the right tool for your specific requirements.

First, install Consul and etcd. On macOS with Homebrew:

```bash
brew install consul
brew install etcd
```

For other operating systems, download the binaries from their respective websites. Create our project structure:

```bash
mkdir service-discovery-go
cd service-discovery-go
go mod init service-discovery-go
```

Set up the project structure:

```
service-discovery-go/
├── main.go
├── internal/
│   ├── discovery/
│   │   ├── consul.go
│   │   ├── etcd.go
│   │   └── registry.go
│   ├── service/
│   │   └── userservice.go
│   └── config/
│       └── config.go
├── cmd/
│   ├── user-service/
│   │   └── main.go
│   └── api-gateway/
│       └── main.go
└── configs/
    └── config.yaml
```

Install the required dependencies:

```bash
go get github.com/hashicorp/consul/api
go get go.etcd.io/etcd/clientv3/v3
go get github.com/gorilla/mux
go get gopkg.in/yaml.v2
go get github.com/google/uuid
```

## Building the Service Registry Interface

Let's start with a common interface that can work with both Consul and etcd. This abstraction allows us to switch between implementations without changing our service code:

```go
// internal/discovery/registry.go
package discovery

import (
    "context"
    "time"
)

type ServiceInstance struct {
    ID       string            `json:"id"`
    Name     string            `json:"name"`
    Address  string            `json:"address"`
    Port     int               `json:"port"`
    Tags     []string          `json:"tags"`
    Metadata map[string]string `json:"metadata"`
    Health   string            `json:"health"`
}

type ServiceRegistry interface {
    Register(ctx context.Context, instance *ServiceInstance) error
    Deregister(ctx context.Context, instanceID string) error
    Discover(ctx context.Context, serviceName string) ([]*ServiceInstance, error)
    Watch(ctx context.Context, serviceName string) (<-chan []*ServiceInstance, error)
    HealthCheck(ctx context.Context, instanceID string) error
    Close() error
}

type RegistryConfig struct {
    Type     string `yaml:"type"`     // "consul" or "etcd"
    Address  string `yaml:"address"`
    Username string `yaml:"username"`
    Password string `yaml:"password"`
    Timeout  time.Duration `yaml:"timeout"`
}
```

## Implementing Consul Service Discovery

Consul's strength lies in its built-in health checking and DNS integration. Here's our Consul implementation:

```go
// internal/discovery/consul.go
package discovery

import (
    "context"
    "fmt"
    "strconv"
    "strings"
    "time"

    "github.com/hashicorp/consul/api"
)

type ConsulRegistry struct {
    client *api.Client
    config *RegistryConfig
}

func NewConsulRegistry(config *RegistryConfig) (*ConsulRegistry, error) {
    consulConfig := api.DefaultConfig()
    consulConfig.Address = config.Address

    if config.Username != "" {
        consulConfig.HttpAuth = &api.HttpBasicAuth{
            Username: config.Username,
            Password: config.Password,
        }
    }

    client, err := api.NewClient(consulConfig)
    if err != nil {
        return nil, fmt.Errorf("failed to create consul client: %w", err)
    }

    return &ConsulRegistry{
        client: client,
        config: config,
    }, nil
}

func (c *ConsulRegistry) Register(ctx context.Context, instance *ServiceInstance) error {
    registration := &api.AgentServiceRegistration{
        ID:      instance.ID,
        Name:    instance.Name,
        Tags:    instance.Tags,
        Port:    instance.Port,
        Address: instance.Address,
        Meta:    instance.Metadata,
        Check: &api.AgentServiceCheck{
            HTTP:                           fmt.Sprintf("http://%s:%d/health", instance.Address, instance.Port),
            Interval:                       "10s",
            Timeout:                        "5s",
            DeregisterCriticalServiceAfter: "30s",
        },
    }

    return c.client.Agent().ServiceRegister(registration)
}

func (c *ConsulRegistry) Deregister(ctx context.Context, instanceID string) error {
    return c.client.Agent().ServiceDeregister(instanceID)
}

func (c *ConsulRegistry) Discover(ctx context.Context, serviceName string) ([]*ServiceInstance, error) {
    services, _, err := c.client.Health().Service(serviceName, "", true, nil)
    if err != nil {
        return nil, fmt.Errorf("failed to discover services: %w", err)
    }

    var instances []*ServiceInstance
    for _, service := range services {
        health := "passing"
        for _, check := range service.Checks {
            if check.Status != "passing" {
                health = check.Status
                break
            }
        }

        instance := &ServiceInstance{
            ID:       service.Service.ID,
            Name:     service.Service.Service,
            Address:  service.Service.Address,
            Port:     service.Service.Port,
            Tags:     service.Service.Tags,
            Metadata: service.Service.Meta,
            Health:   health,
        }
        instances = append(instances, instance)
    }

    return instances, nil
}

func (c *ConsulRegistry) Watch(ctx context.Context, serviceName string) (<-chan []*ServiceInstance, error) {
    ch := make(chan []*ServiceInstance, 1)

    go func() {
        defer close(ch)

        params := map[string]interface{}{
            "type":    "service",
            "service": serviceName,
        }

        plan, err := api.WatchPlan(params)
        if err != nil {
            return
        }

        plan.Handler = func(idx uint64, data interface{}) {
            if entries, ok := data.([]*api.ServiceEntry); ok {
                var instances []*ServiceInstance
                for _, entry := range entries {
                    health := "passing"
                    for _, check := range entry.Checks {
                        if check.Status != "passing" {
                            health = check.Status
                            break
                        }
                    }

                    instance := &ServiceInstance{
                        ID:       entry.Service.ID,
                        Name:     entry.Service.Service,
                        Address:  entry.Service.Address,
                        Port:     entry.Service.Port,
                        Tags:     entry.Service.Tags,
                        Metadata: entry.Service.Meta,
                        Health:   health,
                    }
                    instances = append(instances, instance)
                }

                select {
                case ch <- instances:
                case <-ctx.Done():
                    return
                }
            }
        }

        go plan.RunWithContext(ctx)
    }()

    return ch, nil
}

func (c *ConsulRegistry) HealthCheck(ctx context.Context, instanceID string) error {
    checks, err := c.client.Agent().Checks()
    if err != nil {
        return fmt.Errorf("failed to get health checks: %w", err)
    }

    for _, check := range checks {
        if strings.Contains(check.ServiceID, instanceID) && check.Status != "passing" {
            return fmt.Errorf("service %s health check failing: %s", instanceID, check.Output)
        }
    }

    return nil
}

func (c *ConsulRegistry) Close() error {
    return nil
}
```

## Implementing etcd Service Discovery

etcd excels at strong consistency and efficient watching. Here's our etcd implementation:

```go
// internal/discovery/etcd.go
package discovery

import (
    "context"
    "encoding/json"
    "fmt"
    "path"
    "strings"
    "time"

    clientv3 "go.etcd.io/etcd/client/v3"
)

type EtcdRegistry struct {
    client     *clientv3.Client
    config     *RegistryConfig
    leaseID    clientv3.LeaseID
    ttl        int64
    keepalive  <-chan *clientv3.LeaseKeepAliveResponse
}

func NewEtcdRegistry(config *RegistryConfig) (*EtcdRegistry, error) {
    etcdConfig := clientv3.Config{
        Endpoints:   []string{config.Address},
        DialTimeout: config.Timeout,
    }

    if config.Username != "" {
        etcdConfig.Username = config.Username
        etcdConfig.Password = config.Password
    }

    client, err := clientv3.New(etcdConfig)
    if err != nil {
        return nil, fmt.Errorf("failed to create etcd client: %w", err)
    }

    registry := &EtcdRegistry{
        client: client,
        config: config,
        ttl:    30, // 30 seconds TTL
    }

    // Create lease for service registration
    lease, err := client.Grant(context.Background(), registry.ttl)
    if err != nil {
        return nil, fmt.Errorf("failed to create lease: %w", err)
    }

    registry.leaseID = lease.ID

    // Start keepalive
    keepalive, kaerr := client.KeepAlive(context.Background(), lease.ID)
    if kaerr != nil {
        return nil, fmt.Errorf("failed to start keepalive: %w", kaerr)
    }

    registry.keepalive = keepalive

    // Consume keepalive messages
    go func() {
        for ka := range keepalive {
            _ = ka // Consume to prevent channel blocking
        }
    }()

    return registry, nil
}

func (e *EtcdRegistry) Register(ctx context.Context, instance *ServiceInstance) error {
    key := fmt.Sprintf("/services/%s/%s", instance.Name, instance.ID)

    // Add health status to metadata
    if instance.Metadata == nil {
        instance.Metadata = make(map[string]string)
    }
    instance.Metadata["last_heartbeat"] = time.Now().Format(time.RFC3339)

    data, err := json.Marshal(instance)
    if err != nil {
        return fmt.Errorf("failed to marshal instance: %w", err)
    }

    _, err = e.client.Put(ctx, key, string(data), clientv3.WithLease(e.leaseID))
    if err != nil {
        return fmt.Errorf("failed to register service: %w", err)
    }

    return nil
}

func (e *EtcdRegistry) Deregister(ctx context.Context, instanceID string) error {
    // Find and delete the key for this instance
    prefix := "/services/"
    resp, err := e.client.Get(ctx, prefix, clientv3.WithPrefix())
    if err != nil {
        return fmt.Errorf("failed to get services: %w", err)
    }

    for _, kv := range resp.Kvs {
        var instance ServiceInstance
        if err := json.Unmarshal(kv.Value, &instance); err != nil {
            continue
        }

        if instance.ID == instanceID {
            _, err := e.client.Delete(ctx, string(kv.Key))
            return err
        }
    }

    return fmt.Errorf("instance %s not found", instanceID)
}

func (e *EtcdRegistry) Discover(ctx context.Context, serviceName string) ([]*ServiceInstance, error) {
    prefix := fmt.Sprintf("/services/%s/", serviceName)
    resp, err := e.client.Get(ctx, prefix, clientv3.WithPrefix())
    if err != nil {
        return nil, fmt.Errorf("failed to discover services: %w", err)
    }

    var instances []*ServiceInstance
    for _, kv := range resp.Kvs {
        var instance ServiceInstance
        if err := json.Unmarshal(kv.Value, &instance); err != nil {
            continue
        }

        // Check if service is still healthy based on last heartbeat
        if lastHeartbeat, exists := instance.Metadata["last_heartbeat"]; exists {
            if heartbeatTime, err := time.Parse(time.RFC3339, lastHeartbeat); err == nil {
                if time.Since(heartbeatTime) > time.Duration(e.ttl)*time.Second {
                    instance.Health = "critical"
                } else {
                    instance.Health = "passing"
                }
            }
        }

        instances = append(instances, &instance)
    }

    return instances, nil
}

func (e *EtcdRegistry) Watch(ctx context.Context, serviceName string) (<-chan []*ServiceInstance, error) {
    ch := make(chan []*ServiceInstance, 1)
    prefix := fmt.Sprintf("/services/%s/", serviceName)

    go func() {
        defer close(ch)

        // Send initial state
        if instances, err := e.Discover(ctx, serviceName); err == nil {
            select {
            case ch <- instances:
            case <-ctx.Done():
                return
            }
        }

        // Watch for changes
        watchCh := e.client.Watch(ctx, prefix, clientv3.WithPrefix())
        for watchResp := range watchCh {
            if watchResp.Err() != nil {
                return
            }

            // Fetch current state after any change
            if instances, err := e.Discover(ctx, serviceName); err == nil {
                select {
                case ch <- instances:
                case <-ctx.Done():
                    return
                }
            }
        }
    }()

    return ch, nil
}

func (e *EtcdRegistry) HealthCheck(ctx context.Context, instanceID string) error {
    instances, err := e.Discover(ctx, "")
    if err != nil {
        return fmt.Errorf("failed to get instances for health check: %w", err)
    }

    for _, instance := range instances {
        if instance.ID == instanceID {
            if instance.Health == "passing" {
                return nil
            }
            return fmt.Errorf("instance %s is unhealthy: %s", instanceID, instance.Health)
        }
    }

    return fmt.Errorf("instance %s not found", instanceID)
}

func (e *EtcdRegistry) Close() error {
    if e.leaseID != 0 {
        _, err := e.client.Revoke(context.Background(), e.leaseID)
        if err != nil {
            return fmt.Errorf("failed to revoke lease: %w", err)
        }
    }
    return e.client.Close()
}
```

## Creating a Service that Registers Itself

Now let's build a user service that automatically registers with our service discovery system. This demonstrates the self-registration pattern common in microservices:

```go
// internal/service/userservice.go
package service

import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "os/signal"
    "strconv"
    "syscall"
    "time"

    "service-discovery-go/internal/discovery"

    "github.com/google/uuid"
    "github.com/gorilla/mux"
)

type UserService struct {
    registry   discovery.ServiceRegistry
    instance   *discovery.ServiceInstance
    server     *http.Server
    shutdownCh chan os.Signal
}

type User struct {
    ID       string `json:"id"`
    Name     string `json:"name"`
    Email    string `json:"email"`
    Created  time.Time `json:"created"`
}

func NewUserService(registry discovery.ServiceRegistry, address string, port int) (*UserService, error) {
    instanceID := uuid.New().String()
    instance := &discovery.ServiceInstance{
        ID:      instanceID,
        Name:    "user-service",
        Address: address,
        Port:    port,
        Tags:    []string{"user", "api", "v1"},
        Metadata: map[string]string{
            "version":   "1.0.0",
            "region":    "us-east-1",
            "zone":      "us-east-1a",
        },
        Health: "passing",
    }

    service := &UserService{
        registry:   registry,
        instance:   instance,
        shutdownCh: make(chan os.Signal, 1),
    }

    // Setup HTTP routes
    router := mux.NewRouter()
    router.HandleFunc("/health", service.healthHandler).Methods("GET")
    router.HandleFunc("/users", service.getUsersHandler).Methods("GET")
    router.HandleFunc("/users/{id}", service.getUserHandler).Methods("GET")
    router.HandleFunc("/info", service.infoHandler).Methods("GET")

    service.server = &http.Server{
        Addr:         fmt.Sprintf("%s:%d", address, port),
        Handler:      router,
        ReadTimeout:  15 * time.Second,
        WriteTimeout: 15 * time.Second,
    }

    return service, nil
}

func (u *UserService) Start(ctx context.Context) error {
    // Register service
    if err := u.registry.Register(ctx, u.instance); err != nil {
        return fmt.Errorf("failed to register service: %w", err)
    }

    log.Printf("User service registered with ID: %s", u.instance.ID)

    // Setup graceful shutdown
    signal.Notify(u.shutdownCh, syscall.SIGINT, syscall.SIGTERM)

    // Start HTTP server
    go func() {
        log.Printf("User service starting on %s", u.server.Addr)
        if err := u.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Printf("HTTP server error: %v", err)
        }
    }()

    // Start periodic health updates for etcd
    go u.startPeriodicHealthUpdate(ctx)

    // Wait for shutdown signal
    <-u.shutdownCh
    log.Println("Shutting down user service...")

    // Deregister service
    if err := u.registry.Deregister(ctx, u.instance.ID); err != nil {
        log.Printf("Failed to deregister service: %v", err)
    }

    // Shutdown HTTP server
    shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    return u.server.Shutdown(shutdownCtx)
}

func (u *UserService) startPeriodicHealthUpdate(ctx context.Context) {
    ticker := time.NewTicker(10 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ticker.C:
            // Update metadata with current timestamp for etcd health checking
            u.instance.Metadata["last_heartbeat"] = time.Now().Format(time.RFC3339)
            if err := u.registry.Register(ctx, u.instance); err != nil {
                log.Printf("Failed to update service registration: %v", err)
            }
        case <-ctx.Done():
            return
        }
    }
}

func (u *UserService) healthHandler(w http.ResponseWriter, r *http.Request) {
    health := map[string]interface{}{
        "status":    "healthy",
        "timestamp": time.Now().Format(time.RFC3339),
        "service":   u.instance.Name,
        "instance":  u.instance.ID,
        "version":   u.instance.Metadata["version"],
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(health)
}

func (u *UserService) getUsersHandler(w http.ResponseWriter, r *http.Request) {
    users := []User{
        {
            ID:      "1",
            Name:    "John Doe",
            Email:   "john@example.com",
            Created: time.Now().Add(-24 * time.Hour),
        },
        {
            ID:      "2",
            Name:    "Jane Smith",
            Email:   "jane@example.com",
            Created: time.Now().Add(-12 * time.Hour),
        },
    }

    response := map[string]interface{}{
        "users":   users,
        "total":   len(users),
        "served_by": u.instance.ID,
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func (u *UserService) getUserHandler(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    userID := vars["id"]

    user := User{
        ID:      userID,
        Name:    fmt.Sprintf("User %s", userID),
        Email:   fmt.Sprintf("user%s@example.com", userID),
        Created: time.Now().Add(-6 * time.Hour),
    }

    response := map[string]interface{}{
        "user":      user,
        "served_by": u.instance.ID,
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func (u *UserService) infoHandler(w http.ResponseWriter, r *http.Request) {
    info := map[string]interface{}{
        "service":  u.instance.Name,
        "instance": u.instance.ID,
        "address":  u.instance.Address,
        "port":     u.instance.Port,
        "tags":     u.instance.Tags,
        "metadata": u.instance.Metadata,
        "health":   u.instance.Health,
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(info)
}
```

## Building a Service Discovery Client

Now let's create a client that discovers and communicates with services. This demonstrates how to build resilient clients that adapt to changing service topology:

```go
// cmd/api-gateway/main.go
package main

import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "math/rand"
    "net/http"
    "time"

    "service-discovery-go/internal/discovery"

    "github.com/gorilla/mux"
)

type APIGateway struct {
    registry   discovery.ServiceRegistry
    services   map[string][]*discovery.ServiceInstance
    httpClient *http.Client
}

func NewAPIGateway(registry discovery.ServiceRegistry) *APIGateway {
    return &APIGateway{
        registry: registry,
        services: make(map[string][]*discovery.ServiceInstance),
        httpClient: &http.Client{
            Timeout: 10 * time.Second,
        },
    }
}

func (gw *APIGateway) Start(ctx context.Context) error {
    // Start watching for user service instances
    go gw.watchService(ctx, "user-service")

    // Setup HTTP routes
    router := mux.NewRouter()
    router.HandleFunc("/api/users", gw.proxyToUserService).Methods("GET")
    router.HandleFunc("/api/users/{id}", gw.proxyToUserService).Methods("GET")
    router.HandleFunc("/api/services", gw.listServices).Methods("GET")
    router.HandleFunc("/health", gw.healthHandler).Methods("GET")

    server := &http.Server{
        Addr:    ":8080",
        Handler: router,
    }

    log.Println("API Gateway starting on :8080")
    return server.ListenAndServe()
}

func (gw *APIGateway) watchService(ctx context.Context, serviceName string) {
    watchCh, err := gw.registry.Watch(ctx, serviceName)
    if err != nil {
        log.Printf("Failed to watch service %s: %v", serviceName, err)
        return
    }

    for {
        select {
        case instances := <-watchCh:
            if instances == nil {
                log.Printf("Watch channel closed for service %s", serviceName)
                return
            }

            // Filter healthy instances
            var healthyInstances []*discovery.ServiceInstance
            for _, instance := range instances {
                if instance.Health == "passing" {
                    healthyInstances = append(healthyInstances, instance)
                }
            }

            gw.services[serviceName] = healthyInstances
            log.Printf("Updated %s instances: %d healthy out of %d total",
                serviceName, len(healthyInstances), len(instances))

        case <-ctx.Done():
            return
        }
    }
}

func (gw *APIGateway) getHealthyInstance(serviceName string) *discovery.ServiceInstance {
    instances := gw.services[serviceName]
    if len(instances) == 0 {
        return nil
    }

    // Simple random load balancing
    return instances[rand.Intn(len(instances))]
}

func (gw *APIGateway) proxyToUserService(w http.ResponseWriter, r *http.Request) {
    instance := gw.getHealthyInstance("user-service")
    if instance == nil {
        http.Error(w, "No healthy user service instances available", http.StatusServiceUnavailable)
        return
    }

    // Build target URL
    targetURL := fmt.Sprintf("http://%s:%d%s", instance.Address, instance.Port, r.URL.Path)
    if r.URL.RawQuery != "" {
        targetURL += "?" + r.URL.RawQuery
    }

    // Create proxy request
    proxyReq, err := http.NewRequest(r.Method, targetURL, r.Body)
    if err != nil {
        http.Error(w, "Failed to create proxy request", http.StatusInternalServerError)
        return
    }

    // Copy headers
    for key, values := range r.Header {
        for _, value := range values {
            proxyReq.Header.Add(key, value)
        }
    }

    // Add tracking headers
    proxyReq.Header.Set("X-Gateway-Instance", instance.ID)
    proxyReq.Header.Set("X-Gateway-Time", time.Now().Format(time.RFC3339))

    // Make request
    resp, err := gw.httpClient.Do(proxyReq)
    if err != nil {
        http.Error(w, "Failed to proxy request", http.StatusBadGateway)
        return
    }
    defer resp.Body.Close()

    // Copy response headers
    for key, values := range resp.Header {
        for _, value := range values {
            w.Header().Add(key, value)
        }
    }

    w.WriteHeader(resp.StatusCode)

    // Copy response body
    buf := make([]byte, 32*1024)
    for {
        n, err := resp.Body.Read(buf)
        if n > 0 {
            w.Write(buf[:n])
        }
        if err != nil {
            break
        }
    }
}

func (gw *APIGateway) listServices(w http.ResponseWriter, r *http.Request) {
    services := make(map[string]interface{})

    for serviceName, instances := range gw.services {
        serviceInfo := map[string]interface{}{
            "name":      serviceName,
            "instances": len(instances),
            "healthy":   len(instances), // All stored instances are healthy
            "endpoints": make([]string, 0, len(instances)),
        }

        for _, instance := range instances {
            endpoint := fmt.Sprintf("%s:%d", instance.Address, instance.Port)
            serviceInfo["endpoints"] = append(serviceInfo["endpoints"].([]string), endpoint)
        }

        services[serviceName] = serviceInfo
    }

    response := map[string]interface{}{
        "services":  services,
        "timestamp": time.Now().Format(time.RFC3339),
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func (gw *APIGateway) healthHandler(w http.ResponseWriter, r *http.Request) {
    health := map[string]interface{}{
        "status":    "healthy",
        "timestamp": time.Now().Format(time.RFC3339),
        "services":  len(gw.services),
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(health)
}

func main() {
    // Create service registry (choose consul or etcd)
    registryType := "consul" // or "etcd"

    config := &discovery.RegistryConfig{
        Type:    registryType,
        Address: "localhost:8500", // consul address, change to "localhost:2379" for etcd
        Timeout: 10 * time.Second,
    }

    var registry discovery.ServiceRegistry
    var err error

    switch registryType {
    case "consul":
        registry, err = discovery.NewConsulRegistry(config)
    case "etcd":
        config.Address = "localhost:2379"
        registry, err = discovery.NewEtcdRegistry(config)
    default:
        log.Fatal("Unknown registry type")
    }

    if err != nil {
        log.Fatalf("Failed to create registry: %v", err)
    }
    defer registry.Close()

    // Create and start API gateway
    gateway := NewAPIGateway(registry)

    ctx := context.Background()
    if err := gateway.Start(ctx); err != nil {
        log.Fatalf("Failed to start gateway: %v", err)
    }
}
```

## Testing Your Service Discovery Implementation

Let's create a comprehensive test setup. First, start Consul or etcd:

For Consul:
```bash
consul agent -dev -node machine -bind=127.0.0.1 -enable-script-checks
```

For etcd:
```bash
etcd --listen-client-urls 'http://localhost:2379' \
     --advertise-client-urls 'http://localhost:2379'
```

Now create the user service executable:

```go
// cmd/user-service/main.go
package main

import (
    "context"
    "flag"
    "log"
    "time"

    "service-discovery-go/internal/discovery"
    "service-discovery-go/internal/service"
)

func main() {
    var (
        registryType = flag.String("registry", "consul", "Registry type (consul or etcd)")
        address      = flag.String("address", "localhost", "Service address")
        port         = flag.Int("port", 8081, "Service port")
    )
    flag.Parse()

    config := &discovery.RegistryConfig{
        Type:    *registryType,
        Address: "localhost:8500", // Default consul
        Timeout: 10 * time.Second,
    }

    if *registryType == "etcd" {
        config.Address = "localhost:2379"
    }

    var registry discovery.ServiceRegistry
    var err error

    switch *registryType {
    case "consul":
        registry, err = discovery.NewConsulRegistry(config)
    case "etcd":
        registry, err = discovery.NewEtcdRegistry(config)
    default:
        log.Fatal("Unknown registry type")
    }

    if err != nil {
        log.Fatalf("Failed to create registry: %v", err)
    }
    defer registry.Close()

    userService, err := service.NewUserService(registry, *address, *port)
    if err != nil {
        log.Fatalf("Failed to create user service: %v", err)
    }

    ctx := context.Background()
    if err := userService.Start(ctx); err != nil {
        log.Fatalf("Failed to start user service: %v", err)
    }
}
```

Test the complete setup:

```bash
# Terminal 1: Start multiple user service instances
go run cmd/user-service/main.go -port=8081 -registry=consul
go run cmd/user-service/main.go -port=8082 -registry=consul
go run cmd/user-service/main.go -port=8083 -registry=consul

# Terminal 2: Start API gateway
go run cmd/api-gateway/main.go

# Terminal 3: Test the system
curl http://localhost:8080/api/services  # List discovered services
curl http://localhost:8080/api/users     # Get users (load balanced)
curl http://localhost:8080/api/users/123 # Get specific user
```

## Production Considerations and Best Practices

When deploying service discovery in production, several factors become critical. Network partitions and service registry unavailability should never bring down your entire system. Implement circuit breakers and fallback mechanisms that allow services to continue operating with cached service information.

Security is paramount - both Consul and etcd support authentication and encryption. In production environments, always enable TLS and implement proper access controls. Consider using service mesh solutions like [Istio](https://istio.io/) that provide additional security layers.

Performance tuning matters at scale. Consul's gossip protocol works well for clusters up to several hundred nodes, while etcd's consensus mechanism provides stronger consistency guarantees but may require more careful capacity planning. Monitor key metrics like service discovery latency, registry load, and health check performance.

Consider integrating service discovery with your monitoring and alerting systems. Tools like [structured logging in Go using slog]({{< relref "blog/go/complete-guide-slog-go-structured-logging-2025.md" >}}) can help you track service topology changes and debug discovery issues.

## Advanced Service Discovery Patterns

This implementation covers the fundamentals, but production systems often need additional patterns. Consider implementing service mesh integration, where your service discovery integrates with tools like Envoy or Linkerd for advanced traffic management.

Circuit breakers and bulkhead patterns become essential at scale. When a service is discovered but unhealthy, you need sophisticated strategies for handling partial failures while maintaining system availability.

For high-traffic environments, consider implementing client-side caching of service discovery information with TTL-based invalidation. This reduces load on your service registry and improves request latency.

Configuration management often integrates closely with service discovery. Both Consul and etcd can store configuration data alongside service registration information, enabling dynamic configuration updates without service restarts.

Building robust service discovery in Go requires understanding both the technical implementation and the operational patterns that make systems resilient at scale. This foundation gives you the tools to build systems that can grow with your needs while maintaining reliability and performance. Whether you choose Consul for its operational simplicity or etcd for its consistency guarantees, the patterns demonstrated here will serve you well in production environments.

The key is starting simple and evolving your implementation as your requirements grow. Begin with basic registration and discovery, then add health checking, watching, and advanced routing as your system matures. With Go's excellent concurrency support and these robust service discovery tools, you have everything needed to build world-class distributed systems.
