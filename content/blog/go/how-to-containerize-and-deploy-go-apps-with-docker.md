---
title: "How to Containerize and Deploy Go Apps with Docker"
description: "Complete guide to containerizing Go applications with Docker. Learn multi-stage builds, optimization techniques, Docker Compose, deployment strategies, and production best practices for Go containers."
date: 2025-10-07T06:00:00+07:00
draft: false
url: /2025/10/how-to-containerize-and-deploy-go-apps-with-docker.html
tags:
    - Go
    - Docker
    - DevOps
    - Deployment
    - Container
    - Tutorial
    - Production
keywords: ["docker go", "containerize go app", "golang docker tutorial", "docker multi-stage build go", "deploy go with docker", "go docker best practices", "docker compose golang", "kubernetes go deployment", "go docker optimization", "production docker go"]
schema: "Article"
author: "BuanaCoding"
datePublished: "2025-10-07"
dateModified: "2025-10-07"

faq:
  - question: "What is Docker and why use it for Go applications?"
    answer: "Docker is a containerization platform that packages your Go application with all its dependencies into a portable container. You use Docker for Go apps because it ensures your application runs consistently across development, testing, and production environments. Docker eliminates 'works on my machine' problems, simplifies deployment, enables easy scaling, and provides isolation from other applications on the same server."

  - question: "How do you create a Dockerfile for a Go application?"
    answer: "To create a Dockerfile for Go, start with a Go base image, copy your source code, download dependencies with go mod download, build the binary with go build, and set the entry point to run your application. For production, use multi-stage builds - build in a golang image and copy only the binary to a minimal alpine or distroless image. This reduces image size from 800MB to under 20MB."

  - question: "What is multi-stage build and why is it important for Go?"
    answer: "Multi-stage build uses multiple FROM statements in one Dockerfile. You build your Go application in a full golang image with all build tools, then copy only the compiled binary to a minimal final image. This is crucial for Go because the build environment needs 700-800MB but the final binary only needs 10-30MB. Multi-stage builds create production images that are 30-40x smaller, faster to deploy, and more secure."

  - question: "How do you optimize Docker images for Go applications?"
    answer: "Optimize Go Docker images by using multi-stage builds to separate build and runtime, choosing minimal base images like alpine or distroless, enabling Go modules caching to speed up builds, compiling with CGO_ENABLED=0 for static binaries, using .dockerignore to exclude unnecessary files, and building with -ldflags='-w -s' to strip debug information. These techniques reduce image size from 800MB to 10-20MB and cut build time by 50-70%."

  - question: "Can you run multiple Go services together with Docker?"
    answer: "Yes, you can run multiple Go services together using Docker Compose. Create a docker-compose.yml file that defines each service, their dependencies, networks, and volumes. Docker Compose handles service orchestration, networking between containers, and managing shared resources like databases. This is perfect for microservices architectures where you have multiple Go services, a database, Redis, and other dependencies running together."

  - question: "How do you deploy Docker containers to production?"
    answer: "Deploy Docker containers to production using container orchestration platforms. For small to medium apps, use Docker Compose on a VPS or cloud VM. For larger applications, use Kubernetes which handles automatic scaling, load balancing, health checks, and rolling updates. Managed services like AWS ECS, Google Cloud Run, or Azure Container Instances simplify deployment by handling infrastructure. Always use proper secrets management, health checks, logging, and monitoring in production."

  - question: "What are the security best practices for Go Docker containers?"
    answer: "Secure Go Docker containers by running as non-root user, using minimal base images to reduce attack surface, scanning images for vulnerabilities with tools like Trivy, keeping base images updated, not embedding secrets in images, using read-only filesystems when possible, and limiting container capabilities. Always use multi-stage builds to exclude build tools from production images and validate all environment variables at startup."

---


Deploying Go applications used to mean SSH into servers, copying binaries, managing dependencies, and praying everything works. Different machines had different library versions. Production behaved differently than development. Debugging deployment issues wasted hours.

**What is Docker for Go?** Docker is a containerization platform that packages your Go application and all its dependencies into a portable container image. Instead of installing Go and dependencies on every server, Docker bundles everything your app needs into a container that runs identically everywhere - from your laptop to production servers.

Containers solve the deployment problem. Build once, run anywhere. Your Go app runs the same on MacOS, Linux, and Windows. Development matches production. Scaling means starting more containers, not configuring more servers.

This guide covers everything - from basic Dockerfiles to production-ready multi-stage builds, Docker Compose for multi-service apps, optimization techniques, and deployment strategies. You'll learn how to build images under 20MB, deploy to Kubernetes, and follow security best practices.

## Why Docker for Go Applications

Go compiles to static binaries. You might wonder why bother with Docker. Just copy the binary to a server and run it, right?

That works until it doesn't. I deployed a Go API this way once. Worked perfectly locally. On the production server, it crashed with "library not found" errors. The server had a different glibc version. Took me three hours to debug.

**What Docker provides for Go:**

Consistency - Your app runs identically in development, testing, staging, and production. No environment-specific bugs.

Dependencies - Go might be statically compiled, but what about PostgreSQL, Redis, or other services? Docker bundles everything.

Isolation - Multiple apps run on one server without conflicts. Each container has its own filesystem and network.

Portability - Build once, deploy anywhere. AWS, Google Cloud, your own servers - same container works everywhere.

Scaling - Need more capacity? Start more containers. Kubernetes and other orchestrators make this automatic.

Version control - Docker images are versioned. Rollback to previous versions in seconds if something breaks.

Development parity - Developers run the exact same environment as production. "Works on my machine" becomes "works in the container."

For Go applications specifically, Docker shines because Go's small binary size means tiny container images. A Go app container can be 10-20MB compared to 500MB+ for Node.js or Python apps.

## Understanding Docker Basics

Before diving into Go-specific containers, understand Docker fundamentals.

**Docker Image** - A read-only template containing your application code, dependencies, and filesystem. Think of it as a snapshot of your application and environment.

**Container** - A running instance of an image. Like how a process is a running instance of a program, a container is a running instance of an image.

**Dockerfile** - A text file with instructions to build a Docker image. Defines base image, dependencies, files to copy, commands to run, and how to start your app.

**Docker Registry** - A repository for storing and distributing images. Docker Hub is the default public registry. You can also run private registries.

**Docker Compose** - A tool for defining and running multi-container applications. Perfect for local development with multiple services.

The typical workflow:
1. Write a Dockerfile
2. Build an image: `docker build`
3. Run a container: `docker run`
4. Push to registry: `docker push`
5. Deploy anywhere: Pull image and run

Docker uses layers. Each instruction in a Dockerfile creates a layer. Layers are cached and reused, making subsequent builds fast.

## Creating Your First Go Dockerfile

Let's start with a simple Go web server and containerize it.

Sample Go application (`main.go`):

```go
package main

import (
    "fmt"
    "log"
    "net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hello from Go in Docker!")
}

func main() {
    http.HandleFunc("/", handler)

    log.Println("Server starting on :8080")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatal(err)
    }
}
```

Basic `Dockerfile`:

```dockerfile
# Use official Go image
FROM golang:1.21-alpine

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Build the application
RUN go build -o main .

# Expose port
EXPOSE 8080

# Run the application
CMD ["./main"]
```

Build and run:

```bash
# Build image
docker build -t mygoapp .

# Run container
docker run -p 8080:8080 mygoapp

# Test
curl http://localhost:8080
# Hello from Go in Docker!
```

This works, but the image is huge - around 300MB. Most of that is the Go toolchain and build dependencies we don't need at runtime.

## Multi-Stage Builds for Go

Multi-stage builds solve the bloat problem. Build in one image, run in another.

Optimized `Dockerfile`:

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build with optimizations
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o main .

# Runtime stage
FROM alpine:latest

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
```

Size difference:

```
Single-stage build: 300MB
Multi-stage build: 15MB

20x smaller!
```

What changed:

**Builder stage** - Uses full golang image with all build tools. Compiles the application.

**Runtime stage** - Uses tiny alpine image. Only copies the compiled binary.

**CGO_ENABLED=0** - Produces a fully static binary with no C library dependencies.

**-ldflags="-w -s"** - Strips debug information and symbol tables. Smaller binary, harder to debug but fine for production.

The final image only contains the binary and minimal OS utilities. Everything else stays in the builder stage and gets discarded.

## Optimizing Go Docker Builds

Beyond multi-stage builds, several techniques optimize Docker images for Go.

### Using Distroless Images

Google's distroless images are even smaller than alpine and more secure:

```dockerfile
# Build stage
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o main .

# Runtime stage with distroless
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/main /main
EXPOSE 8080
ENTRYPOINT ["/main"]
```

Distroless images contain only your app and runtime dependencies. No shell, no package manager, minimal attack surface. Size: 10-12MB.

### Leveraging Go Modules Cache

Cache Go modules between builds for faster iterations:

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app

# Copy go.mod and go.sum first
COPY go.mod go.sum ./

# Download dependencies (cached layer)
RUN go mod download

# Copy source code (this layer changes frequently)
COPY . .

# Build
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
```

By copying `go.mod` and `go.sum` before source code, Docker caches the `go mod download` layer. When you change code, dependencies don't re-download.

Build time comparison:

```
First build: 60 seconds
Subsequent builds (code changes only): 5 seconds

12x faster!
```

### Using .dockerignore

Exclude unnecessary files from the build context:

`.dockerignore`:

```
# Git files
.git
.gitignore

# IDE files
.vscode
.idea

# Test files
*_test.go
testdata

# Documentation
README.md
docs

# Build artifacts
*.exe
*.dll
*.so
*.dylib
main

# Temporary files
tmp
*.tmp
```

Smaller build context means faster uploads to Docker daemon and faster builds.

### Scratch Image for Ultimate Minimalism

For truly static binaries with no external dependencies:

```dockerfile
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags="-w -s" -o main .

# Use scratch (empty image)
FROM scratch
COPY --from=builder /app/main /main
EXPOSE 8080
ENTRYPOINT ["/main"]
```

Scratch image is empty - literally nothing except your binary. Final size: 5-8MB depending on your app.

Limitations: No shell for debugging, no SSL certificates (copy them manually), no timezone data. Only works if your app needs nothing from the OS.

## Go Application with Dependencies

Real applications have databases, Redis, and other services. Let's containerize a Go API with PostgreSQL.

Project structure:

```
myapp/
├── cmd/
│   └── api/
│       └── main.go
├── internal/
│   ├── database/
│   │   └── db.go
│   └── handlers/
│       └── handlers.go
├── go.mod
├── go.sum
├── Dockerfile
└── docker-compose.yml
```

`main.go`:

```go
package main

import (
    "database/sql"
    "fmt"
    "log"
    "net/http"
    "os"

    _ "github.com/lib/pq"
)

func main() {
    dbHost := os.Getenv("DB_HOST")
    dbUser := os.Getenv("DB_USER")
    dbPassword := os.Getenv("DB_PASSWORD")
    dbName := os.Getenv("DB_NAME")

    connStr := fmt.Sprintf(
        "host=%s user=%s password=%s dbname=%s sslmode=disable",
        dbHost, dbUser, dbPassword, dbName,
    )

    db, err := sql.Open("postgres", connStr)
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    if err := db.Ping(); err != nil {
        log.Fatal("Cannot connect to database:", err)
    }

    log.Println("Connected to database")

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        var count int
        db.QueryRow("SELECT COUNT(*) FROM users").Scan(&count)
        fmt.Fprintf(w, "User count: %d\n", count)
    })

    log.Println("Server starting on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

`Dockerfile`:

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o main ./cmd/api

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
```

Build:

```bash
docker build -t myapp .
```

Run with environment variables:

```bash
docker run -p 8080:8080 \
  -e DB_HOST=localhost \
  -e DB_USER=postgres \
  -e DB_PASSWORD=secret \
  -e DB_NAME=mydb \
  myapp
```

But this fails because the container can't reach localhost. That's where Docker Compose comes in.

## Docker Compose for Multi-Service Apps

Docker Compose manages multiple containers as one application.

`docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DB_HOST=db
      - DB_USER=postgres
      - DB_PASSWORD=secret
      - DB_NAME=mydb
    depends_on:
      - db
    networks:
      - app-network

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=secret
      - POSTGRES_DB=mydb
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - app-network

networks:
  app-network:
    driver: bridge

volumes:
  postgres-data:
```

Start everything:

```bash
docker-compose up

# Or in detached mode
docker-compose up -d

# View logs
docker-compose logs -f app

# Stop everything
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

**How it works:**

**Services** - Defines app and db containers.

**Networks** - Both services join app-network. They can communicate using service names as hostnames (app can reach db at hostname "db").

**Volumes** - postgres-data persists database data across container restarts.

**depends_on** - Ensures db starts before app.

Docker Compose automatically handles networking, DNS resolution between containers, and dependency management.

### Complete Stack with Redis

Add Redis for caching:

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DB_HOST=db
      - DB_USER=postgres
      - DB_PASSWORD=secret
      - DB_NAME=mydb
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    depends_on:
      - db
      - redis
    networks:
      - app-network

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=secret
      - POSTGRES_DB=mydb
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    networks:
      - app-network

networks:
  app-network:

volumes:
  postgres-data:
```

Your Go app can now connect to both PostgreSQL (host=db) and Redis (host=redis).

## Environment Variables and Configuration

Hardcoding config in Docker Compose is bad for production. Use environment files.

`.env`:

```bash
# Database
DB_HOST=db
DB_USER=postgres
DB_PASSWORD=supersecretpassword
DB_NAME=mydb

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# App
PORT=8080
ENV=development
```

`docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "${PORT}:8080"
    env_file:
      - .env
    depends_on:
      - db
      - redis
    networks:
      - app-network

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=${DB_NAME}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    networks:
      - app-network

networks:
  app-network:

volumes:
  postgres-data:
```

Now change config by editing `.env` instead of `docker-compose.yml`.

**Production secrets:** Never commit `.env` to git. Add to `.gitignore`:

```
.env
.env.local
.env.production
```

For production, use secret management systems like Docker Secrets, Kubernetes Secrets, AWS Secrets Manager, or HashiCorp Vault.

## Health Checks and Readiness Probes

Production containers need health checks so orchestrators know if they're working.

Add health check to Go app:

```go
package main

import (
    "database/sql"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "time"

    _ "github.com/lib/pq"
)

var db *sql.DB

func healthHandler(w http.ResponseWriter, r *http.Request) {
    // Check database connection
    if err := db.Ping(); err != nil {
        w.WriteHeader(http.StatusServiceUnavailable)
        json.NewEncoder(w).Encode(map[string]string{
            "status": "unhealthy",
            "error":  err.Error(),
        })
        return
    }

    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{
        "status": "healthy",
    })
}

func main() {
    // Database setup
    connStr := fmt.Sprintf(
        "host=%s user=%s password=%s dbname=%s sslmode=disable",
        os.Getenv("DB_HOST"),
        os.Getenv("DB_USER"),
        os.Getenv("DB_PASSWORD"),
        os.Getenv("DB_NAME"),
    )

    var err error
    db, err = sql.Open("postgres", connStr)
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(5 * time.Minute)

    // Wait for database
    for i := 0; i < 30; i++ {
        if err := db.Ping(); err == nil {
            break
        }
        log.Println("Waiting for database...")
        time.Sleep(time.Second)
    }

    log.Println("Connected to database")

    // Routes
    http.HandleFunc("/health", healthHandler)
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "Hello World")
    })

    log.Println("Server starting on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

Update `Dockerfile` with health check:

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o main ./cmd/api

FROM alpine:latest
RUN apk --no-cache add ca-certificates curl
WORKDIR /root/
COPY --from=builder /app/main .

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["./main"]
```

Docker Compose health check:

```yaml
services:
  app:
    build: .
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 5s
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:15-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 3s
      retries: 3
```

Health checks ensure containers are actually working, not just running. Orchestrators automatically restart unhealthy containers.

## Docker Networking and Service Discovery

Containers on the same Docker network can communicate using service names.

Custom network example:

```yaml
version: '3.8'

services:
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - API_URL=http://backend:8080
    networks:
      - frontend-network

  backend:
    build: ./backend
    environment:
      - DB_HOST=database
    networks:
      - frontend-network
      - backend-network

  database:
    image: postgres:15-alpine
    networks:
      - backend-network

networks:
  frontend-network:
  backend-network:
```

**Frontend** connects to backend via `http://backend:8080`.

**Backend** connects to database via `database:5432`.

**Database** is isolated from frontend - only backend can access it.

This network segmentation improves security. External services can't directly access internal services.

## Volume Management for Persistence

Containers are ephemeral. Data disappears when containers stop. Volumes persist data.

### Named Volumes

Docker-managed storage:

```yaml
services:
  db:
    image: postgres:15-alpine
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

Data persists across container restarts and removals.

### Bind Mounts

Mount host directories into containers:

```yaml
services:
  app:
    build: .
    volumes:
      - ./logs:/app/logs  # Host ./logs -> Container /app/logs
      - ./config:/app/config:ro  # Read-only mount
```

Useful for development (live code reload) and accessing logs from host.

### tmpfs Mounts

In-memory storage for temporary data:

```yaml
services:
  app:
    build: .
    tmpfs:
      - /tmp
      - /app/cache
```

Fast but data is lost when container stops.

## Building for Multiple Architectures

Build images that run on both AMD64 (Intel/AMD) and ARM64 (Apple Silicon, AWS Graviton):

```bash
# Enable buildx
docker buildx create --use

# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myapp:latest \
  --push \
  .
```

Or in Dockerfile:

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -ldflags="-w -s" -o main .

FROM alpine:latest
COPY --from=builder /app/main /main
CMD ["/main"]
```

This creates a universal image that works on any architecture.

## Production Deployment Strategies

### Deploy to VPS with Docker Compose

Simple deployment for small to medium apps:

```bash
# On your VPS
git clone https://github.com/you/myapp.git
cd myapp

# Create .env with production secrets
nano .env

# Start services
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose logs -f

# Update (pull new code, rebuild, restart)
git pull
docker-compose up -d --build
```

`docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  app:
    build: .
    restart: unless-stopped
    ports:
      - "8080:8080"
    env_file:
      - .env
    depends_on:
      - db
      - redis
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  db:
    image: postgres:15-alpine
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - postgres-data:/var/lib/postgresql/data
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - app

volumes:
  postgres-data:
```

### Deploy to Kubernetes

For production scale, use Kubernetes.

Deployment manifest (`deployment.yaml`):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myregistry/myapp:latest
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          value: postgres-service
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 3
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
```

Deploy:

```bash
# Create secret
kubectl create secret generic db-secret \
  --from-literal=username=postgres \
  --from-literal=password=supersecret

# Deploy application
kubectl apply -f deployment.yaml

# Check status
kubectl get pods
kubectl get services

# View logs
kubectl logs -f deployment/myapp

# Scale
kubectl scale deployment myapp --replicas=5
```

Kubernetes handles automatic scaling, load balancing, rolling updates, and self-healing.

### Deploy to Cloud Services

**AWS ECS (Elastic Container Service):**

```bash
# Build and push
docker build -t myapp .
docker tag myapp:latest <aws-account-id>.dkr.ecr.us-east-1.amazonaws.com/myapp:latest
docker push <aws-account-id>.dkr.ecr.us-east-1.amazonaws.com/myapp:latest

# Create ECS task definition and service via AWS Console or Terraform
```

**Google Cloud Run:**

```bash
# Build and deploy in one command
gcloud run deploy myapp \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

**Azure Container Instances:**

```bash
az container create \
  --resource-group myResourceGroup \
  --name myapp \
  --image myregistry.azurecr.io/myapp:latest \
  --dns-name-label myapp \
  --ports 8080
```

Cloud services handle infrastructure, scaling, and monitoring for you.

## Comparison: Deployment Options

| Method | Best For | Complexity | Cost | Scaling | Management |
|--------|----------|------------|------|---------|------------|
| **Docker Compose on VPS** | Small apps, 1-5 services | Low | Low ($5-20/mo) | Manual | Self-managed |
| **Docker Swarm** | Medium apps, simple orchestration | Medium | Low-Medium | Automatic | Self-managed |
| **Kubernetes** | Large apps, microservices | High | Medium-High | Automatic | Self or managed |
| **AWS ECS** | AWS ecosystem | Medium | Medium | Automatic | Managed |
| **Google Cloud Run** | Serverless containers | Low | Pay-per-use | Automatic | Fully managed |
| **Azure Container Instances** | Simple containers | Low | Pay-per-use | Limited | Fully managed |
| **Heroku** | Rapid deployment | Very Low | High | Automatic | Fully managed |

**Recommendations:**

Start small: Docker Compose on VPS ($10/month DigitalOcean droplet).

Growing: Migrate to managed Kubernetes (GKE, EKS, AKS) when you need 10+ services.

Serverless: Google Cloud Run or AWS Fargate for variable traffic.

Enterprise: Self-managed Kubernetes for full control and cost optimization at scale.

## Security Best Practices for Docker Go Apps

### Run as Non-Root User

Never run containers as root:

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

WORKDIR /home/appuser
COPY --from=builder /app/main .

# Change ownership
RUN chown -R appuser:appuser /home/appuser

# Switch to non-root user
USER appuser

EXPOSE 8080
CMD ["./main"]
```

If a vulnerability is exploited, the attacker only has limited user privileges, not root.

### Scan Images for Vulnerabilities

Use Trivy or other scanners:

```bash
# Install Trivy
brew install aquasecurity/trivy/trivy

# Scan image
trivy image myapp:latest

# Fail build on high/critical vulnerabilities
trivy image --severity HIGH,CRITICAL --exit-code 1 myapp:latest
```

Integrate into CI/CD:

```yaml
# GitHub Actions
- name: Run Trivy scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myapp:latest'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'
```

### Don't Embed Secrets

Never put secrets in Dockerfile or image:

```dockerfile
# WRONG - Secret in image
ENV API_KEY=supersecret123

# CORRECT - Pass at runtime
ENV API_KEY=
```

Pass secrets via environment variables, Docker secrets, or secret management systems.

### Use Read-Only Filesystem

Make containers immutable:

```yaml
services:
  app:
    build: .
    read_only: true
    tmpfs:
      - /tmp
      - /app/cache
```

Prevents attackers from modifying files even if they compromise the container.

### Limit Container Capabilities

Drop unnecessary Linux capabilities:

```yaml
services:
  app:
    build: .
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only if binding to port <1024
```

Reduces attack surface by removing privileges containers rarely need.

## Monitoring and Logging

Production containers need observability.

### Structured Logging

Log in JSON for easier parsing:

```go
package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "time"
)

type LogEntry struct {
    Level     string    `json:"level"`
    Timestamp time.Time `json:"timestamp"`
    Message   string    `json:"message"`
    Context   map[string]interface{} `json:"context,omitempty"`
}

func logJSON(level, message string, context map[string]interface{}) {
    entry := LogEntry{
        Level:     level,
        Timestamp: time.Now().UTC(),
        Message:   message,
        Context:   context,
    }
    json.NewEncoder(os.Stdout).Encode(entry)
}

func main() {
    logJSON("info", "Server starting", map[string]interface{}{
        "port": 8080,
    })

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        logJSON("info", "Request received", map[string]interface{}{
            "method": r.Method,
            "path":   r.URL.Path,
            "ip":     r.RemoteAddr,
        })
        w.Write([]byte("Hello"))
    })

    if err := http.ListenAndServe(":8080", nil); err != nil {
        logJSON("error", "Server failed", map[string]interface{}{
            "error": err.Error(),
        })
        os.Exit(1)
    }
}
```

Structured logs work well with log aggregation systems like ELK stack, Loki, or cloud logging.

### Container Metrics

Expose Prometheus metrics:

```go
package main

import (
    "net/http"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequests = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )

    httpDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
)

func init() {
    prometheus.MustRegister(httpRequests)
    prometheus.MustRegister(httpDuration)
}

func main() {
    http.Handle("/metrics", promhttp.Handler())

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        timer := prometheus.NewTimer(httpDuration.WithLabelValues(r.Method, r.URL.Path))
        defer timer.ObserveDuration()

        // Handle request
        w.Write([]byte("Hello"))

        httpRequests.WithLabelValues(r.Method, r.URL.Path, "200").Inc()
    })

    http.ListenAndServe(":8080", nil)
}
```

Scrape with Prometheus and visualize in Grafana.

## CI/CD Pipeline for Docker Go Apps

Automate build, test, and deployment.

GitHub Actions example (`.github/workflows/docker.yml`):

```yaml
name: Docker Build and Deploy

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Set up Go
      uses: actions/setup-go@v4
      with:
        go-version: '1.21'

    - name: Run tests
      run: go test -v ./...

  build:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
    - uses: actions/checkout@v3

    - name: Log in to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v4
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}

    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}

    - name: Scan image
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
        severity: 'CRITICAL,HIGH'

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
    - name: Deploy to production
      run: |
        # SSH to server and pull new image
        # kubectl apply or docker-compose pull
        echo "Deploy to production"
```

This pipeline:
1. Runs tests
2. Builds Docker image
3. Pushes to registry
4. Scans for vulnerabilities
5. Deploys to production (if on main branch)

## Troubleshooting Common Issues

**Container exits immediately:**

Check logs:
```bash
docker logs <container-id>
docker-compose logs app
```

Common cause: Application crashes on startup. Check database connection, missing environment variables.

**Cannot connect to database:**

Verify network:
```bash
docker network ls
docker network inspect <network-name>
```

Ensure services are on same network. Use service name as hostname, not localhost.

**Image build is slow:**

Use build cache effectively. Put frequently changing files (source code) after infrequently changing files (dependencies).

Enable BuildKit:
```bash
export DOCKER_BUILDKIT=1
docker build .
```

**Out of disk space:**

Clean up unused images and containers:
```bash
docker system prune -a
docker volume prune
```

**Permission denied errors:**

Check file ownership. Container user might not have permissions. Use non-root user or fix permissions in Dockerfile.

## Real-World Example: Complete API with Docker

Let's put everything together. Full stack Go API with PostgreSQL, Redis, and Nginx.

Project structure:
```
myapi/
├── cmd/
│   └── api/
│       └── main.go
├── internal/
│   ├── handlers/
│   ├── database/
│   └── cache/
├── migrations/
│   └── 001_create_users.sql
├── nginx/
│   └── nginx.conf
├── Dockerfile
├── docker-compose.yml
├── docker-compose.prod.yml
├── .dockerignore
├── .env.example
└── Makefile
```

`Dockerfile`:

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o main ./cmd/api

FROM alpine:latest
RUN apk --no-cache add ca-certificates curl
RUN addgroup -g 1000 appuser && adduser -D -u 1000 -G appuser appuser
WORKDIR /home/appuser
COPY --from=builder /app/main .
RUN chown appuser:appuser main
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
CMD ["./main"]
```

`docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    environment:
      - DB_HOST=db
      - REDIS_HOST=redis
    env_file:
      - .env
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - backend
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  db:
    image: postgres:15-alpine
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./migrations:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    networks:
      - backend

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/ssl/private:ro
    depends_on:
      - app
    networks:
      - backend

networks:
  backend:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
```

`Makefile`:

```makefile
.PHONY: build run test clean

build:
	docker-compose build

run:
	docker-compose up

run-prod:
	docker-compose -f docker-compose.prod.yml up -d

test:
	go test -v ./...

logs:
	docker-compose logs -f

stop:
	docker-compose down

clean:
	docker-compose down -v
	docker system prune -f

deploy:
	git pull
	docker-compose -f docker-compose.prod.yml up -d --build
```

Deploy to production:

```bash
make deploy
```

This setup is production-ready with health checks, logging, secrets management, and easy deployment.

## Integration with Other Tools

For complete DevOps workflows, combine Docker with other tools.

Integrate with [database migrations](/2025/10/how-to-perform-database-migrations-in-go-using-golang-migrate.html) to manage schema changes across environments.

Use [background job processing with Asynq](/2025/10/how-to-implement-background-jobs-in-go-with-asynq-and-redis.html) for async task processing in containers.

Implement [monitoring and profiling with pprof](/2025/10/how-to-profile-and-optimize-go-applications-with-pprof.html) to optimize containerized applications.

## Wrapping Up

Docker transforms Go application deployment from complex server configuration to simple container orchestration. Multi-stage builds create tiny images under 20MB. Docker Compose manages local development with multiple services. Kubernetes and cloud platforms handle production at scale.

The key patterns: use multi-stage builds for small images, leverage Go's static compilation for minimal base images, implement health checks for reliability, separate build and runtime concerns, use Docker Compose for local development, and deploy with orchestrators for production.

Start simple with a basic Dockerfile. Add multi-stage builds when image size matters. Use Docker Compose when you add databases or Redis. Move to Kubernetes or cloud services when you need scaling and high availability.

Docker makes Go deployment consistent, portable, and scalable. Build once, deploy anywhere, scale automatically. That's the Docker advantage for [Go applications](/tags/go/).

For building complete production systems, check out [REST API development with Gin](/2025/09/building-rest-api-gin-framework-golang-production-ready.html), [email integration](/2025/10/how-to-send-emails-in-go-smtp-sendgrid-mailgun.html), and [CLI tools with Cobra](/2025/10/how-to-build-a-cli-tool-in-go-with-cobra-and-viper.html).
