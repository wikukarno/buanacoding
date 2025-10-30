---
title: "How to Implement Background Jobs in Go with Asynq and Redis"
description: "Complete guide to implementing background job processing in Go using Asynq and Redis. Learn task queues, worker pools, retries, scheduled tasks, error handling, and production deployment strategies."
date: 2025-10-06T16:00:00+07:00
draft: false
url: /2025/10/how-to-implement-background-jobs-in-go-with-asynq-and-redis.html
tags:
    - Go
    - Redis
    - Asynq
    - Background Jobs
    - Queue
    - Backend
    - Tutorial
keywords: ["go background jobs", "asynq tutorial", "golang task queue", "redis job queue go", "background processing golang", "asynq redis", "async tasks go", "worker pool golang", "job scheduling go", "golang queue system"]
schema: "Article"
author: "BuanaCoding"
datePublished: "2025-10-06"
dateModified: "2025-10-06"

faq:
  - question: "Why use Asynq instead of other job queue libraries in Go?"
    answer: "Asynq is built specifically for Go with Redis as the backend. It handles automatic retries with exponential backoff, scheduled tasks, priority queues, and worker pools with concurrency control. You also get built-in monitoring and a web UI for inspecting tasks. Unlike generic message queues that force you to write boilerplate, Asynq gives you patterns built for background job processing right out of the box."

  - question: "How does Asynq handle job failures and retries?"
    answer: "Asynq automatically retries failed tasks with exponential backoff. You configure max retries, timeout per attempt, and custom retry logic. Failed tasks move through stages - retry queue first, then archived queue after max retries, and finally dead queue for permanent failures. You can manually retry archived tasks from the web UI or programmatically if needed."

  - question: "Can you use Asynq without Redis?"
    answer: "No, you cannot use Asynq without Redis. Asynq requires Redis as its backend because Redis provides the persistence, atomicity, and pub/sub features that make Asynq work. However, Redis is lightweight and easy to deploy. For development, you can run Redis in Docker with a single command. For production, use managed Redis services like Redis Cloud, AWS ElastiCache, or Google Cloud Memorystore."

  - question: "How do you handle tasks that take longer than expected in Asynq?"
    answer: "To handle long-running tasks in Asynq, first set appropriate timeout values using asynq.Timeout() when enqueuing tasks. For tasks that run longer than an hour, break them into smaller chunks and chain them together. You can use task.ResultWriter to stream progress updates to your users. Monitor task duration metrics in production and adjust timeouts based on actual performance data. Use unique task options to prevent the same long-running job from being queued multiple times accidentally."

  - question: "What's the difference between queues and task priorities in Asynq?"
    answer: "Queues are completely separate namespaces - a worker processes tasks from specific queues. Task priority within a queue determines processing order (high priority tasks run before low priority). Use different queues for different types of work (emails, images, reports). Use priorities when tasks in the same queue have different urgency levels."

  - question: "How do you monitor Asynq tasks in production?"
    answer: "You can monitor Asynq tasks in production using the built-in web UI called asynqmon. It shows you active tasks, scheduled tasks, retry queue, archived tasks, and failed tasks in real-time. For deeper insights, expose Prometheus metrics to track task counts, processing time, failure rates, and queue sizes. These metrics integrate seamlessly with monitoring tools like Datadog or New Relic that you might already be using in your infrastructure."

  - question: "How does Asynq ensure tasks are processed exactly once?"
    answer: "Asynq uses Redis transactions and unique task IDs to prevent duplicate processing. When you set a task ID using asynq.TaskID(), Asynq checks if a task with that ID already exists in the queue. If it does, the new task gets rejected. For operations that need to be idempotent, use asynq.Unique() with a TTL to deduplicate tasks within a specific time window."

---


Your API is slow. Not because the code is inefficient, but because you're doing too much in the HTTP request cycle. Sending emails, processing images, generating reports - all blocking the response while the user waits. That's not how you scale.

**What are background jobs?** Background jobs are tasks that run asynchronously outside the main request-response cycle. Instead of making users wait while your server processes heavy workloads, you push these tasks into a queue and handle them separately in worker processes. This keeps your API fast and responsive.

Background jobs solve this. Push slow work into a queue, return a response immediately, and process tasks asynchronously in worker processes. Your API stays fast, users get instant feedback, and heavy workloads don't crash your server.

Asynq is a Go library built specifically for this. It uses Redis as a message broker and provides everything you need: automatic retries with exponential backoff, task scheduling, priority queues, worker pools, and a web UI for monitoring. Unlike generic message queues that require boilerplate, Asynq gives you a complete background job system with minimal setup.

This guide covers everything - from basic task enqueueing to production deployment with monitoring, error handling, and performance optimization. We'll build a real system that sends emails, processes images, and generates reports in the background while keeping your API responsive.

## Why Background Jobs Matter in Go Applications

Imagine a user uploads a profile picture. Without background jobs, your handler does this synchronously:

```go
func uploadAvatar(w http.ResponseWriter, r *http.Request) {
    file, _ := r.FormFile("avatar")

    // All of this blocks the HTTP response
    resized := resizeImage(file)      // 2 seconds
    thumbnail := createThumbnail(file) // 1 second
    uploadToS3(resized)                // 3 seconds
    uploadToS3(thumbnail)              // 2 seconds
    updateDatabase(userID, urls)       // 0.5 seconds

    w.Write([]byte("Upload complete")) // 8.5 seconds later!
}
```

The user waits 8+ seconds staring at a loading spinner. If 10 users upload simultaneously, your server is processing 10 images concurrently, maxing out CPU and memory.

With background jobs:

```go
func uploadAvatar(w http.ResponseWriter, r *http.Request) {
    file, _ := r.FormFile("avatar")

    // Save to temp storage
    tempPath := saveToTemp(file) // 100ms

    // Enqueue background job
    client.Enqueue(tasks.NewProcessAvatarTask(userID, tempPath))

    w.Write([]byte("Upload started")) // 100ms response!
}
```

Response returns in 100ms. Image processing happens in the background. If 10 users upload, jobs queue up and process at a controlled rate. Your API stays responsive.

**When to use background jobs:**

Sending emails - SMTP calls can take seconds and fail unpredictably.

Image/video processing - CPU-intensive work that shouldn't block requests.

Report generation - Complex queries and PDF generation take time.

External API calls - Third-party APIs are slow and unreliable.

Scheduled tasks - Daily cleanup, weekly reports, monthly billing.

Webhooks - Calling user webhooks shouldn't delay your response.

Basically, anything that takes >100ms or can fail should be a background job.

## Understanding Asynq Architecture

Asynq has three main components:

**Client** - Enqueues tasks into Redis. Your web application uses the client to push work into queues.

**Server** - Worker process that pulls tasks from Redis and executes them. Run multiple servers to scale horizontally.

**Redis** - Message broker that stores tasks, manages queues, and coordinates between clients and servers.

The flow:

```
Web App (Client)  ->  Redis  ->  Worker (Server)
     ↓                  ↓           ↓
  Enqueue Task    Store in Queue  Process Task
```

Tasks are stored in Redis lists. Workers use BLPOP to atomically pull tasks and process them. If a worker crashes mid-task, Asynq detects it and requeues the task.

Asynq creates several Redis queues automatically:

- **Active queue** - Tasks currently being processed
- **Pending queue** - Tasks waiting to be processed
- **Scheduled queue** - Tasks scheduled for future execution
- **Retry queue** - Failed tasks waiting for retry
- **Archived queue** - Tasks that exceeded max retries
- **Dead queue** - Permanently failed tasks

You define custom queues (default, critical, low_priority) to separate different types of work.

## Installing Asynq and Redis

Install Asynq:

```bash
go get -u github.com/hibiken/asynq
```

For development, run Redis with Docker:

```bash
docker run -d --name redis -p 6379:6379 redis:7-alpine
```

Or install Redis locally:

```bash
# macOS
brew install redis
brew services start redis

# Ubuntu/Debian
sudo apt install redis-server
sudo systemctl start redis

# Verify
redis-cli ping
# PONG
```

For production, use managed Redis:
- **Redis Cloud** - Official managed Redis
- **AWS ElastiCache** - AWS managed Redis
- **Google Cloud Memorystore** - GCP managed Redis
- **Azure Cache for Redis** - Azure managed Redis

Asynq requires Redis 4.0+. Redis 7 is recommended for best performance.

## Project Structure for Background Jobs

Here's a production-ready structure for background jobs:

```
myapp/
├── cmd/
│   ├── api/
│   │   └── main.go          # Web API server
│   └── worker/
│       └── main.go          # Background worker
├── internal/
│   ├── tasks/
│   │   ├── email.go         # Email tasks
│   │   ├── image.go         # Image processing tasks
│   │   └── report.go        # Report generation tasks
│   ├── worker/
│   │   └── worker.go        # Worker setup
│   └── queue/
│       └── client.go        # Queue client
├── go.mod
└── go.sum
```

Separate API and worker into different binaries. This lets you scale them independently - run 5 API servers and 20 workers, or vice versa.

## Creating Your First Task

Tasks are functions that perform background work. Create `internal/tasks/email.go`:

```go
package tasks

import (
    "context"
    "encoding/json"
    "fmt"
    "log"

    "github.com/hibiken/asynq"
)

// Task type constants
const (
    TypeEmailWelcome  = "email:welcome"
    TypeEmailPassword = "email:password_reset"
)

// EmailWelcomePayload is the task payload
type EmailWelcomePayload struct {
    UserID int    `json:"user_id"`
    Email  string `json:"email"`
    Name   string `json:"name"`
}

// NewEmailWelcomeTask creates a new welcome email task
func NewEmailWelcomeTask(userID int, email, name string) (*asynq.Task, error) {
    payload, err := json.Marshal(EmailWelcomePayload{
        UserID: userID,
        Email:  email,
        Name:   name,
    })
    if err != nil {
        return nil, err
    }

    return asynq.NewTask(TypeEmailWelcome, payload), nil
}

// HandleEmailWelcomeTask processes the task
func HandleEmailWelcomeTask(ctx context.Context, t *asynq.Task) error {
    var p EmailWelcomePayload
    if err := json.Unmarshal(t.Payload(), &p); err != nil {
        return fmt.Errorf("json.Unmarshal failed: %v", err)
    }

    log.Printf("Sending welcome email to %s (user_id=%d)", p.Email, p.UserID)

    // Actual email sending logic
    if err := sendEmail(p.Email, "Welcome!", welcomeEmailTemplate(p.Name)); err != nil {
        return fmt.Errorf("failed to send email: %w", err)
    }

    log.Printf("Successfully sent welcome email to %s", p.Email)
    return nil
}

func sendEmail(to, subject, body string) error {
    // Implement with your email provider (SendGrid, AWS SES, etc.)
    // For now, simulate email sending
    // time.Sleep(2 * time.Second)
    return nil
}

func welcomeEmailTemplate(name string) string {
    return fmt.Sprintf("Hi %s,\n\nWelcome to our platform!\n\nBest regards,\nThe Team", name)
}
```

**Task anatomy:**

**Task Type** - String constant identifying the task (TypeEmailWelcome).

**Payload** - JSON-serialized data containing task parameters.

**Constructor** - Creates asynq.Task with type and payload (NewEmailWelcomeTask).

**Handler** - Function that processes the task (HandleEmailWelcomeTask).

The handler signature must be `func(context.Context, *asynq.Task) error`. Return nil on success, error on failure.

## Setting Up the Queue Client

The client enqueues tasks. Create `internal/queue/client.go`:

```go
package queue

import (
    "github.com/hibiken/asynq"
)

// Client wraps asynq.Client
type Client struct {
    *asynq.Client
}

// NewClient creates a new queue client
func NewClient(redisAddr string) *Client {
    client := asynq.NewClient(asynq.RedisClientOpt{
        Addr: redisAddr,
    })

    return &Client{Client: client}
}

// Close closes the client connection
func (c *Client) Close() error {
    return c.Client.Close()
}
```

Use the client in your web application. Update `cmd/api/main.go`:

```go
package main

import (
    "log"
    "net/http"
    "os"

    "github.com/hibiken/asynq"
    "myapp/internal/queue"
    "myapp/internal/tasks"
)

func main() {
    redisAddr := os.Getenv("REDIS_ADDR")
    if redisAddr == "" {
        redisAddr = "localhost:6379"
    }

    // Create queue client
    queueClient := queue.NewClient(redisAddr)
    defer queueClient.Close()

    // Register handlers
    http.HandleFunc("/signup", signupHandler(queueClient))

    log.Println("API server starting on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}

func signupHandler(queueClient *queue.Client) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // Parse request
        email := r.FormValue("email")
        name := r.FormValue("name")

        // Create user in database
        userID := createUser(email, name) // Your DB logic

        // Enqueue welcome email task
        task, err := tasks.NewEmailWelcomeTask(userID, email, name)
        if err != nil {
            http.Error(w, "Failed to create task", 500)
            return
        }

        info, err := queueClient.Enqueue(task)
        if err != nil {
            log.Printf("Failed to enqueue task: %v", err)
            http.Error(w, "Failed to enqueue task", 500)
            return
        }

        log.Printf("Enqueued task: id=%s queue=%s", info.ID, info.Queue)

        w.Write([]byte("Signup successful! Check your email."))
    }
}

func createUser(email, name string) int {
    // Database logic here
    return 123 // Mock user ID
}
```

The API enqueues the task and returns immediately. Email sending happens in the background.

## Setting Up the Worker

Workers pull tasks from Redis and execute them. Create `cmd/worker/main.go`:

```go
package main

import (
    "log"
    "os"
    "os/signal"
    "syscall"

    "github.com/hibiken/asynq"
    "myapp/internal/tasks"
)

func main() {
    redisAddr := os.Getenv("REDIS_ADDR")
    if redisAddr == "" {
        redisAddr = "localhost:6379"
    }

    srv := asynq.NewServer(
        asynq.RedisClientOpt{Addr: redisAddr},
        asynq.Config{
            // Number of concurrent workers
            Concurrency: 10,

            // Queue priorities (higher number = higher priority)
            Queues: map[string]int{
                "critical": 6,
                "default":  3,
                "low":      1,
            },
        },
    )

    // Register task handlers
    mux := asynq.NewServeMux()
    mux.HandleFunc(tasks.TypeEmailWelcome, tasks.HandleEmailWelcomeTask)
    // Add more handlers as needed

    // Handle graceful shutdown
    go func() {
        sigterm := make(chan os.Signal, 1)
        signal.Notify(sigterm, syscall.SIGINT, syscall.SIGTERM)
        <-sigterm
        log.Println("Shutting down worker...")
        srv.Shutdown()
    }()

    log.Println("Worker starting...")
    if err := srv.Run(mux); err != nil {
        log.Fatalf("Could not run worker: %v", err)
    }
}
```

**Worker configuration:**

**Concurrency** - Number of tasks processed simultaneously (10 workers).

**Queues** - Map of queue names to priorities. Workers pull from high-priority queues first.

**ServeMux** - Router that maps task types to handlers.

Start the worker:

```bash
go run cmd/worker/main.go
# Worker starting...
```

Now when your API enqueues a task, the worker picks it up and processes it.

## Enqueuing Tasks with Options

Asynq provides options to customize task behavior:

```go
// Basic enqueue
task, _ := tasks.NewEmailWelcomeTask(userID, email, name)
client.Enqueue(task)

// Enqueue to specific queue
client.Enqueue(task, asynq.Queue("critical"))

// Set max retry attempts
client.Enqueue(task, asynq.MaxRetry(5))

// Set timeout
client.Enqueue(task, asynq.Timeout(30*time.Second))

// Process after delay
client.Enqueue(task, asynq.ProcessIn(5*time.Minute))

// Process at specific time
client.Enqueue(task, asynq.ProcessAt(time.Date(2025, 10, 7, 9, 0, 0, 0, time.UTC)))

// Set task priority (higher = more important)
client.Enqueue(task, asynq.Priority(10))

// Unique task - prevent duplicates
client.Enqueue(task, asynq.Unique(24*time.Hour))

// Custom task ID
client.Enqueue(task, asynq.TaskID("user-welcome-123"))

// Combine multiple options
client.Enqueue(task,
    asynq.Queue("critical"),
    asynq.MaxRetry(3),
    asynq.Timeout(1*time.Minute),
    asynq.Priority(10),
)
```

**Common patterns:**

Critical tasks (password resets) -> critical queue with high priority.

Scheduled reports -> ProcessAt with specific time.

Deduplication -> Unique option to prevent duplicate jobs.

Long-running tasks -> Higher timeout and lower concurrency.

## Handling Task Failures and Retries

Asynq automatically retries failed tasks with exponential backoff. Default behavior:

1. Task fails (handler returns error)
2. Asynq waits with exponential backoff
3. Retries up to MaxRetry times (default 25)
4. After max retries, moves to archived queue

**Custom retry logic:**

```go
func HandleEmailWelcomeTask(ctx context.Context, t *asynq.Task) error {
    var p EmailWelcomePayload
    if err := json.Unmarshal(t.Payload(), &p); err != nil {
        // Permanent failure - don't retry
        return fmt.Errorf("json.Unmarshal failed: %w: %v", asynq.SkipRetry, err)
    }

    // Attempt to send email
    if err := sendEmail(p.Email, "Welcome!", welcomeEmailTemplate(p.Name)); err != nil {
        // Check if error is retryable
        if isTemporaryError(err) {
            // Will retry automatically
            return fmt.Errorf("temporary error sending email: %w", err)
        }

        // Permanent error - don't retry
        return fmt.Errorf("permanent error: %w: %v", asynq.SkipRetry, err)
    }

    return nil
}

func isTemporaryError(err error) bool {
    // Check for network errors, rate limits, etc.
    return strings.Contains(err.Error(), "timeout") ||
           strings.Contains(err.Error(), "temporary")
}
```

**asynq.SkipRetry** - Wrapping an error with this tells Asynq not to retry.

**Custom retry delays:**

```go
srv := asynq.NewServer(
    asynq.RedisClientOpt{Addr: redisAddr},
    asynq.Config{
        Concurrency: 10,

        // Custom retry delays
        RetryDelayFunc: func(n int, err error, task *asynq.Task) time.Duration {
            // n is the retry count
            return time.Duration(n*n) * time.Second // 1s, 4s, 9s, 16s...
        },
    },
)
```

## Processing Multiple Task Types

As your app grows, you'll have many task types. Organize them by domain:

**Email tasks** (`internal/tasks/email.go`):

```go
package tasks

const (
    TypeEmailWelcome       = "email:welcome"
    TypeEmailPasswordReset = "email:password_reset"
    TypeEmailInvoice       = "email:invoice"
)

func NewEmailPasswordResetTask(email, resetToken string) (*asynq.Task, error) {
    payload, _ := json.Marshal(map[string]string{
        "email": email,
        "token": resetToken,
    })
    return asynq.NewTask(TypeEmailPasswordReset, payload), nil
}

func HandleEmailPasswordResetTask(ctx context.Context, t *asynq.Task) error {
    var p map[string]string
    json.Unmarshal(t.Payload(), &p)

    resetURL := fmt.Sprintf("https://example.com/reset?token=%s", p["token"])
    body := fmt.Sprintf("Click here to reset your password: %s", resetURL)

    return sendEmail(p["email"], "Password Reset", body)
}
```

**Image tasks** (`internal/tasks/image.go`):

```go
package tasks

import (
    "context"
    "encoding/json"
    "fmt"

    "github.com/hibiken/asynq"
)

const (
    TypeImageResize    = "image:resize"
    TypeImageThumbnail = "image:thumbnail"
)

type ImageResizePayload struct {
    ImageURL  string `json:"image_url"`
    Width     int    `json:"width"`
    Height    int    `json:"height"`
    OutputURL string `json:"output_url"`
}

func NewImageResizeTask(imageURL string, width, height int, outputURL string) (*asynq.Task, error) {
    payload, _ := json.Marshal(ImageResizePayload{
        ImageURL:  imageURL,
        Width:     width,
        Height:    height,
        OutputURL: outputURL,
    })
    return asynq.NewTask(TypeImageResize, payload), nil
}

func HandleImageResizeTask(ctx context.Context, t *asynq.Task) error {
    var p ImageResizePayload
    if err := json.Unmarshal(t.Payload(), &p); err != nil {
        return err
    }

    // Download image
    img, err := downloadImage(p.ImageURL)
    if err != nil {
        return fmt.Errorf("download failed: %w", err)
    }

    // Resize
    resized, err := resizeImage(img, p.Width, p.Height)
    if err != nil {
        return fmt.Errorf("resize failed: %w", err)
    }

    // Upload to S3 or storage
    if err := uploadImage(p.OutputURL, resized); err != nil {
        return fmt.Errorf("upload failed: %w", err)
    }

    return nil
}

// Placeholder functions
func downloadImage(url string) ([]byte, error) { return nil, nil }
func resizeImage(img []byte, w, h int) ([]byte, error) { return nil, nil }
func uploadImage(url string, img []byte) error { return nil }
```

**Report tasks** (`internal/tasks/report.go`):

```go
package tasks

import (
    "context"
    "encoding/json"
    "time"

    "github.com/hibiken/asynq"
)

const (
    TypeReportDaily   = "report:daily"
    TypeReportMonthly = "report:monthly"
)

type ReportPayload struct {
    UserID    int       `json:"user_id"`
    StartDate time.Time `json:"start_date"`
    EndDate   time.Time `json:"end_date"`
}

func NewDailyReportTask(userID int, date time.Time) (*asynq.Task, error) {
    payload, _ := json.Marshal(ReportPayload{
        UserID:    userID,
        StartDate: date,
        EndDate:   date.Add(24 * time.Hour),
    })
    return asynq.NewTask(TypeReportDaily, payload), nil
}

func HandleDailyReportTask(ctx context.Context, t *asynq.Task) error {
    var p ReportPayload
    json.Unmarshal(t.Payload(), &p)

    // Generate report
    data := fetchReportData(p.UserID, p.StartDate, p.EndDate)
    pdf := generatePDF(data)

    // Send via email
    return sendReportEmail(p.UserID, pdf)
}

func fetchReportData(userID int, start, end time.Time) interface{} { return nil }
func generatePDF(data interface{}) []byte { return nil }
func sendReportEmail(userID int, pdf []byte) error { return nil }
```

Register all handlers in worker:

```go
// cmd/worker/main.go
mux := asynq.NewServeMux()

// Email handlers
mux.HandleFunc(tasks.TypeEmailWelcome, tasks.HandleEmailWelcomeTask)
mux.HandleFunc(tasks.TypeEmailPasswordReset, tasks.HandleEmailPasswordResetTask)
mux.HandleFunc(tasks.TypeEmailInvoice, tasks.HandleEmailInvoiceTask)

// Image handlers
mux.HandleFunc(tasks.TypeImageResize, tasks.HandleImageResizeTask)
mux.HandleFunc(tasks.TypeImageThumbnail, tasks.HandleImageThumbnailTask)

// Report handlers
mux.HandleFunc(tasks.TypeReportDaily, tasks.HandleDailyReportTask)
mux.HandleFunc(tasks.TypeReportMonthly, tasks.HandleMonthlyReportTask)
```

## Scheduled and Periodic Tasks

Asynq supports cron-like scheduled tasks. Create a scheduler:

```go
// cmd/scheduler/main.go
package main

import (
    "log"
    "os"

    "github.com/hibiken/asynq"
    "myapp/internal/tasks"
)

func main() {
    redisAddr := os.Getenv("REDIS_ADDR")
    if redisAddr == "" {
        redisAddr = "localhost:6379"
    }

    scheduler := asynq.NewScheduler(
        asynq.RedisClientOpt{Addr: redisAddr},
        &asynq.SchedulerOpts{
            Location: time.UTC,
        },
    )

    // Daily report at 9 AM
    _, err := scheduler.Register("0 9 * * *", tasks.NewDailyReportTask(0, time.Now()))
    if err != nil {
        log.Fatal(err)
    }

    // Cleanup old data every Sunday at midnight
    cleanupTask, _ := tasks.NewCleanupTask()
    _, err = scheduler.Register("0 0 * * 0", cleanupTask)
    if err != nil {
        log.Fatal(err)
    }

    // Send weekly digest every Monday at 10 AM
    digestTask, _ := tasks.NewWeeklyDigestTask()
    _, err = scheduler.Register("0 10 * * 1", digestTask)
    if err != nil {
        log.Fatal(err)
    }

    log.Println("Scheduler starting...")
    if err := scheduler.Run(); err != nil {
        log.Fatal(err)
    }
}
```

Cron syntax: `minute hour day month weekday`

Examples:
- `0 9 * * *` - Every day at 9 AM
- `*/5 * * * *` - Every 5 minutes
- `0 0 * * 0` - Every Sunday at midnight
- `0 10 * * 1-5` - Weekdays at 10 AM

Run scheduler as a separate process:

```bash
go run cmd/scheduler/main.go
```

For one-off delayed tasks, use ProcessIn or ProcessAt when enqueuing:

```go
// Process in 1 hour
task, _ := tasks.NewEmailReminderTask(userID)
client.Enqueue(task, asynq.ProcessIn(1*time.Hour))

// Process at specific time
processTime := time.Date(2025, 10, 7, 14, 0, 0, 0, time.UTC)
client.Enqueue(task, asynq.ProcessAt(processTime))
```

## Middleware and Logging

Add middleware for logging, metrics, and error handling:

```go
// internal/worker/middleware.go
package worker

import (
    "context"
    "log"
    "time"

    "github.com/hibiken/asynq"
)

// LoggingMiddleware logs task execution
func LoggingMiddleware(h asynq.Handler) asynq.Handler {
    return asynq.HandlerFunc(func(ctx context.Context, t *asynq.Task) error {
        start := time.Now()

        log.Printf("Processing task: type=%s id=%s", t.Type(), t.ResultWriter().TaskID())

        err := h.ProcessTask(ctx, t)

        duration := time.Since(start)
        if err != nil {
            log.Printf("Task failed: type=%s id=%s duration=%v error=%v",
                t.Type(), t.ResultWriter().TaskID(), duration, err)
        } else {
            log.Printf("Task completed: type=%s id=%s duration=%v",
                t.Type(), t.ResultWriter().TaskID(), duration)
        }

        return err
    })
}

// RecoveryMiddleware recovers from panics
func RecoveryMiddleware(h asynq.Handler) asynq.Handler {
    return asynq.HandlerFunc(func(ctx context.Context, t *asynq.Task) (err error) {
        defer func() {
            if r := recover(); r != nil {
                log.Printf("Task panicked: type=%s panic=%v", t.Type(), r)
                err = fmt.Errorf("panic: %v", r)
            }
        }()
        return h.ProcessTask(ctx, t)
    })
}

// MetricsMiddleware tracks metrics
func MetricsMiddleware(h asynq.Handler) asynq.Handler {
    return asynq.HandlerFunc(func(ctx context.Context, t *asynq.Task) error {
        start := time.Now()
        err := h.ProcessTask(ctx, t)
        duration := time.Since(start)

        // Send to your metrics system (Prometheus, DataDog, etc.)
        recordTaskMetrics(t.Type(), duration, err)

        return err
    })
}

func recordTaskMetrics(taskType string, duration time.Duration, err error) {
    // Implement metrics collection
}
```

Apply middleware in worker:

```go
// cmd/worker/main.go
srv := asynq.NewServer(
    asynq.RedisClientOpt{Addr: redisAddr},
    asynq.Config{
        Concurrency: 10,
        Queues: map[string]int{
            "critical": 6,
            "default":  3,
            "low":      1,
        },
    },
)

mux := asynq.NewServeMux()

// Apply middleware
mux.Use(worker.RecoveryMiddleware)
mux.Use(worker.LoggingMiddleware)
mux.Use(worker.MetricsMiddleware)

// Register handlers
mux.HandleFunc(tasks.TypeEmailWelcome, tasks.HandleEmailWelcomeTask)
// ... more handlers
```

Middleware runs in order: Recovery -> Logging -> Metrics -> Handler.

## Monitoring Background Jobs with Asynq Web UI

Asynq provides a web UI for monitoring tasks. Install asynqmon:

```bash
go install github.com/hibiken/asynq/tools/asynqmon@latest
```

Run the web UI:

```bash
asynqmon --redis-addr=localhost:6379
```

Open http://localhost:8080 to see:

- **Active tasks** - Currently processing
- **Pending tasks** - Waiting in queue
- **Scheduled tasks** - Future execution
- **Retry queue** - Failed tasks waiting for retry
- **Archived** - Exhausted retries
- **Dead** - Permanently failed

You can manually retry, delete, or archive tasks from the UI.

For production, embed asynqmon in your app:

```go
// cmd/monitor/main.go
package main

import (
    "log"
    "net/http"

    "github.com/hibiken/asynq"
    "github.com/hibiken/asynqmon"
)

func main() {
    h := asynqmon.New(asynqmon.Options{
        RootPath:     "/monitoring",
        RedisConnOpt: asynq.RedisClientOpt{Addr: "localhost:6379"},
    })

    http.Handle(h.RootPath(), h)

    log.Println("Monitoring UI available at http://localhost:8080/monitoring")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

Protect the monitoring endpoint with authentication in production.

## Task Context and Cancellation

Use context for cancellation and timeouts:

```go
func HandleLongRunningTask(ctx context.Context, t *asynq.Task) error {
    // Check context before expensive operations
    select {
    case <-ctx.Done():
        return ctx.Err() // Cancelled or timed out
    default:
    }

    // Long running work
    for i := 0; i < 1000; i++ {
        // Check context periodically
        if err := ctx.Err(); err != nil {
            log.Printf("Task cancelled at iteration %d", i)
            return err
        }

        processItem(i)
    }

    return nil
}
```

Set timeout when enqueueing:

```go
// Task will be cancelled after 5 minutes
client.Enqueue(task, asynq.Timeout(5*time.Minute))
```

Get task metadata from context:

```go
func HandleTask(ctx context.Context, t *asynq.Task) error {
    // Get task ID
    taskID, _ := asynq.GetTaskID(ctx)
    log.Printf("Processing task %s", taskID)

    // Get retry count
    retryCount, _ := asynq.GetRetryCount(ctx)
    log.Printf("Retry attempt %d", retryCount)

    // Get max retry
    maxRetry, _ := asynq.GetMaxRetry(ctx)
    log.Printf("Max retries: %d", maxRetry)

    return nil
}
```

## Unique Tasks and Deduplication

Prevent duplicate tasks with the Unique option:

```go
// Only one password reset task per user for 1 hour
task, _ := tasks.NewEmailPasswordResetTask(email, token)
client.Enqueue(task,
    asynq.Unique(1*time.Hour),
    asynq.TaskID(fmt.Sprintf("password-reset-%s", email)),
)
```

If you enqueue the same task (same TaskID) within 1 hour, Asynq ignores it.

For custom uniqueness:

```go
// Only one report generation per user per day
reportDate := time.Now().Format("2006-01-02")
uniqueID := fmt.Sprintf("daily-report-%d-%s", userID, reportDate)

task, _ := tasks.NewDailyReportTask(userID, time.Now())
client.Enqueue(task,
    asynq.TaskID(uniqueID),
    asynq.Unique(24*time.Hour),
)
```

This ensures you don't accidentally generate the same report multiple times.

## Task Result and Progress Tracking

Track task progress for long-running jobs:

```go
func HandleLargeExportTask(ctx context.Context, t *asynq.Task) error {
    var p ExportPayload
    json.Unmarshal(t.Payload(), &p)

    items := fetchItems(p.UserID) // 10,000 items
    total := len(items)

    for i, item := range items {
        processItem(item)

        // Update progress every 100 items
        if i%100 == 0 {
            progress := float64(i) / float64(total) * 100
            updateProgress(p.UserID, progress)
            log.Printf("Export progress: %.2f%%", progress)
        }

        // Check for cancellation
        if err := ctx.Err(); err != nil {
            return err
        }
    }

    return nil
}
```

Store progress in Redis or database and show it in your UI.

## Error Handling Best Practices

**Distinguish temporary vs permanent errors:**

```go
func HandleAPICallTask(ctx context.Context, t *asynq.Task) error {
    resp, err := httpClient.Get(apiURL)
    if err != nil {
        // Network error - retry
        return fmt.Errorf("network error: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode == 429 {
        // Rate limited - retry with backoff
        return fmt.Errorf("rate limited, will retry")
    }

    if resp.StatusCode == 404 {
        // Resource not found - don't retry
        return fmt.Errorf("%w: resource not found", asynq.SkipRetry)
    }

    if resp.StatusCode >= 500 {
        // Server error - retry
        return fmt.Errorf("server error: status %d", resp.StatusCode)
    }

    if resp.StatusCode >= 400 {
        // Client error - don't retry
        return fmt.Errorf("%w: client error %d", asynq.SkipRetry, resp.StatusCode)
    }

    // Process successful response
    return processResponse(resp.Body)
}
```

**Log errors with context:**

```go
func HandleTask(ctx context.Context, t *asynq.Task) error {
    taskID, _ := asynq.GetTaskID(ctx)
    retryCount, _ := asynq.GetRetryCount(ctx)

    err := doWork()
    if err != nil {
        log.Printf("Task %s failed (retry %d): %v", taskID, retryCount, err)
        return err
    }

    return nil
}
```

**Implement circuit breaker for external services:**

```go
var circuitBreaker = &CircuitBreaker{
    maxFailures: 5,
    timeout:     30 * time.Second,
}

func HandleExternalAPITask(ctx context.Context, t *asynq.Task) error {
    if !circuitBreaker.Allow() {
        return fmt.Errorf("circuit breaker open, skipping")
    }

    err := callExternalAPI()

    if err != nil {
        circuitBreaker.RecordFailure()
        return err
    }

    circuitBreaker.RecordSuccess()
    return nil
}
```

## Production Deployment Strategies

**Environment variables:**

```bash
# .env
REDIS_ADDR=redis.production.com:6379
REDIS_PASSWORD=secret
WORKER_CONCURRENCY=20
QUEUE_CRITICAL_PRIORITY=6
QUEUE_DEFAULT_PRIORITY=3
QUEUE_LOW_PRIORITY=1
```

**Production worker configuration:**

```go
// cmd/worker/main.go
func main() {
    redisAddr := os.Getenv("REDIS_ADDR")
    redisPassword := os.Getenv("REDIS_PASSWORD")
    concurrency := getEnvInt("WORKER_CONCURRENCY", 10)

    srv := asynq.NewServer(
        asynq.RedisClientOpt{
            Addr:     redisAddr,
            Password: redisPassword,
            DB:       0,

            // Connection pool settings
            PoolSize:     concurrency * 2,
            MinIdleConns: 5,

            // Timeouts
            DialTimeout:  5 * time.Second,
            ReadTimeout:  3 * time.Second,
            WriteTimeout: 3 * time.Second,
        },
        asynq.Config{
            Concurrency: concurrency,

            Queues: map[string]int{
                "critical": getEnvInt("QUEUE_CRITICAL_PRIORITY", 6),
                "default":  getEnvInt("QUEUE_DEFAULT_PRIORITY", 3),
                "low":      getEnvInt("QUEUE_LOW_PRIORITY", 1),
            },

            // Strict priority mode
            StrictPriority: true,

            // Error handler
            ErrorHandler: asynq.ErrorHandlerFunc(func(ctx context.Context, task *asynq.Task, err error) {
                taskID, _ := asynq.GetTaskID(ctx)
                log.Printf("Task error: id=%s type=%s error=%v", taskID, task.Type(), err)

                // Send to error tracking (Sentry, Rollbar, etc.)
                reportError(task, err)
            }),

            // Health check endpoint
            HealthCheckFunc: func(err error) {
                if err != nil {
                    log.Printf("Health check failed: %v", err)
                }
            },

            HealthCheckInterval: 15 * time.Second,
        },
    )

    // ... setup handlers and run
}

func getEnvInt(key string, defaultVal int) int {
    val := os.Getenv(key)
    if val == "" {
        return defaultVal
    }
    i, _ := strconv.Atoi(val)
    return i
}

func reportError(task *asynq.Task, err error) {
    // Integrate with your error tracking service
}
```

**Docker deployment:**

```dockerfile
# Dockerfile.worker
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o worker ./cmd/worker

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/worker .
CMD ["./worker"]
```

**Docker Compose:**

```yaml
# docker-compose.yml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data

  worker:
    build:
      context: .
      dockerfile: Dockerfile.worker
    environment:
      - REDIS_ADDR=redis:6379
      - WORKER_CONCURRENCY=10
    depends_on:
      - redis
    deploy:
      replicas: 3  # Run 3 worker instances

volumes:
  redis-data:
```

**Kubernetes deployment:**

```yaml
# worker-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: asynq-worker
spec:
  replicas: 5
  selector:
    matchLabels:
      app: asynq-worker
  template:
    metadata:
      labels:
        app: asynq-worker
    spec:
      containers:
      - name: worker
        image: myapp/worker:latest
        env:
        - name: REDIS_ADDR
          value: "redis-service:6379"
        - name: WORKER_CONCURRENCY
          value: "20"
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
```

## Monitoring and Metrics

Expose Prometheus metrics:

```go
// internal/worker/metrics.go
package worker

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    tasksProcessed = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "asynq_tasks_processed_total",
            Help: "Total number of tasks processed",
        },
        []string{"task_type", "status"},
    )

    taskDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "asynq_task_duration_seconds",
            Help:    "Task processing duration",
            Buckets: prometheus.DefBuckets,
        },
        []string{"task_type"},
    )

    queueSize = promauto.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "asynq_queue_size",
            Help: "Current queue size",
        },
        []string{"queue"},
    )
)

func MetricsMiddleware(h asynq.Handler) asynq.Handler {
    return asynq.HandlerFunc(func(ctx context.Context, t *asynq.Task) error {
        timer := prometheus.NewTimer(taskDuration.WithLabelValues(t.Type()))
        defer timer.ObserveDuration()

        err := h.ProcessTask(ctx, t)

        status := "success"
        if err != nil {
            status = "failure"
        }
        tasksProcessed.WithLabelValues(t.Type(), status).Inc()

        return err
    })
}
```

Expose metrics endpoint:

```go
// cmd/worker/main.go
import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
    // ... worker setup

    // Metrics endpoint
    go func() {
        http.Handle("/metrics", promhttp.Handler())
        log.Println("Metrics available at :9090/metrics")
        http.ListenAndServe(":9090", nil)
    }()

    // ... run worker
}
```

## Testing Background Jobs

Test task handlers:

```go
// internal/tasks/email_test.go
package tasks

import (
    "context"
    "testing"

    "github.com/hibiken/asynq"
)

func TestHandleEmailWelcomeTask(t *testing.T) {
    // Create test task
    task, err := NewEmailWelcomeTask(123, "test@example.com", "Test User")
    if err != nil {
        t.Fatalf("Failed to create task: %v", err)
    }

    // Execute handler
    ctx := context.Background()
    err = HandleEmailWelcomeTask(ctx, task)

    // Assert
    if err != nil {
        t.Errorf("Expected no error, got: %v", err)
    }

    // Verify email was sent (mock or check test email service)
}

func TestHandleEmailWelcomeTask_InvalidPayload(t *testing.T) {
    // Create task with invalid payload
    task := asynq.NewTask(TypeEmailWelcome, []byte("invalid json"))

    ctx := context.Background()
    err := HandleEmailWelcomeTask(ctx, task)

    // Should return error
    if err == nil {
        t.Error("Expected error for invalid payload")
    }
}
```

Integration test with Redis:

```go
func TestTaskEnqueueAndProcess(t *testing.T) {
    // Setup test Redis
    redisAddr := "localhost:6379"

    client := asynq.NewClient(asynq.RedisClientOpt{Addr: redisAddr})
    defer client.Close()

    // Enqueue task
    task, _ := NewEmailWelcomeTask(123, "test@example.com", "Test")
    info, err := client.Enqueue(task)
    if err != nil {
        t.Fatalf("Failed to enqueue: %v", err)
    }

    // Verify task was enqueued
    if info.Queue != "default" {
        t.Errorf("Expected queue 'default', got %s", info.Queue)
    }

    // TODO: Start worker and verify task is processed
}
```

## Real-World Example: Email Service

Complete email service with multiple task types:

```go
// internal/tasks/email_service.go
package tasks

import (
    "context"
    "fmt"
    "time"

    "github.com/hibiken/asynq"
)

type EmailService struct {
    client *asynq.Client
}

func NewEmailService(client *asynq.Client) *EmailService {
    return &EmailService{client: client}
}

// SendWelcomeEmail sends welcome email immediately
func (s *EmailService) SendWelcomeEmail(userID int, email, name string) error {
    task, err := NewEmailWelcomeTask(userID, email, name)
    if err != nil {
        return err
    }

    _, err = s.client.Enqueue(task,
        asynq.Queue("critical"),
        asynq.MaxRetry(5),
    )
    return err
}

// SendPasswordReset sends password reset with deduplication
func (s *EmailService) SendPasswordReset(email, token string) error {
    task, err := NewEmailPasswordResetTask(email, token)
    if err != nil {
        return err
    }

    // Only one reset email per user per 15 minutes
    _, err = s.client.Enqueue(task,
        asynq.Queue("critical"),
        asynq.TaskID(fmt.Sprintf("password-reset-%s", email)),
        asynq.Unique(15*time.Minute),
    )
    return err
}

// ScheduleReminderEmail schedules reminder for future
func (s *EmailService) ScheduleReminderEmail(userID int, email string, when time.Time) error {
    task, err := NewEmailReminderTask(userID, email)
    if err != nil {
        return err
    }

    _, err = s.client.Enqueue(task,
        asynq.ProcessAt(when),
        asynq.Queue("default"),
    )
    return err
}

// SendBulkEmails sends emails to multiple users
func (s *EmailService) SendBulkEmails(campaign Campaign) error {
    for _, recipient := range campaign.Recipients {
        task, err := NewEmailCampaignTask(recipient.Email, campaign.Subject, campaign.Body)
        if err != nil {
            continue
        }

        // Low priority, spread over time
        delay := time.Duration(rand.Intn(300)) * time.Second
        s.client.Enqueue(task,
            asynq.Queue("low"),
            asynq.ProcessIn(delay),
        )
    }

    return nil
}
```

Usage in your API:

```go
// In your HTTP handler
emailService := tasks.NewEmailService(queueClient)

// Send welcome email
if err := emailService.SendWelcomeEmail(user.ID, user.Email, user.Name); err != nil {
    log.Printf("Failed to enqueue welcome email: %v", err)
}

// Schedule reminder in 1 day
reminderTime := time.Now().Add(24 * time.Hour)
emailService.ScheduleReminderEmail(user.ID, user.Email, reminderTime)
```

## Advanced Patterns

**Chain tasks** - Execute tasks in sequence:

```go
// Process image, then send notification
func ProcessAndNotify(imageURL string, userID int) error {
    // First task: resize image
    resizeTask, _ := tasks.NewImageResizeTask(imageURL, 800, 600, outputURL)
    info, err := client.Enqueue(resizeTask)
    if err != nil {
        return err
    }

    // Second task: notify user (after 10 seconds to ensure first task completes)
    notifyTask, _ := tasks.NewNotificationTask(userID, "Image processed!")
    client.Enqueue(notifyTask, asynq.ProcessIn(10*time.Second))

    return nil
}
```

For more reliable chaining, handle it in the task itself:

```go
func HandleImageResizeTask(ctx context.Context, t *asynq.Task) error {
    var p ImageResizePayload
    json.Unmarshal(t.Payload(), &p)

    // Resize image
    if err := resizeImage(p); err != nil {
        return err
    }

    // After successful resize, enqueue notification
    notifyTask, _ := tasks.NewNotificationTask(p.UserID, "Image processed!")
    return client.Enqueue(notifyTask)
}
```

**Fan-out pattern** - Process multiple items in parallel:

```go
func ProcessBatch(items []Item) error {
    for _, item := range items {
        task, _ := tasks.NewProcessItemTask(item.ID)
        client.Enqueue(task)
    }
    return nil
}
```

**Rate limiting** - Control task execution rate:

```go
// Limit to 100 emails per minute
var emailRateLimiter = time.NewTicker(600 * time.Millisecond) // 100/min

func HandleEmailTask(ctx context.Context, t *asynq.Task) error {
    <-emailRateLimiter.C // Wait for rate limit slot
    return sendEmail(...)
}
```

## Comparing with Alternatives

Here's how Asynq compares to other job queue solutions:

| Feature | Asynq | RabbitMQ | Kafka | Temporal |
|---------|-------|----------|-------|----------|
| **Setup Complexity** | Simple (Redis only) | Medium | Complex | Complex |
| **Use Case** | Background jobs | Message routing | Event streaming | Long workflows |
| **Language** | Go-native | Language-agnostic | Language-agnostic | Language-agnostic |
| **Retries** | Built-in exponential backoff | Manual config | Not built-in | Built-in |
| **Web UI** | Yes (asynqmon) | Yes (management plugin) | No (use external) | Yes |
| **Durability** | Redis persistence | High | Very high | High |
| **Learning Curve** | Low | Medium | High | High |
| **Best For** | Go background jobs | Complex routing | Event logs | Workflow orchestration |

**When to choose Asynq:**
- Building Go applications with background processing needs
- Want simple setup with Redis
- Need automatic retries and scheduling out of the box
- Prefer Go-native libraries over protocol-based solutions

**When to choose alternatives:**
- **RabbitMQ** - Need advanced message routing or polyglot services
- **Kafka** - Building event-driven architectures with replay capabilities
- **Temporal** - Managing complex multi-step workflows with state

For most [Go applications](/tags/go/), Asynq hits the sweet spot - powerful enough for production, simple enough to understand.

## Integration with Existing Systems

If you're using [Redis for caching](/2025/08/how-to-use-redis-with-go-caching-session-management.html), you can share the same Redis instance for Asynq. Just use different DB numbers:

```go
// Cache uses DB 0
cacheClient := redis.NewClient(&redis.Options{
    Addr: "localhost:6379",
    DB:   0,
})

// Asynq uses DB 1
asynqClient := asynq.NewClient(asynq.RedisClientOpt{
    Addr: "localhost:6379",
    DB:   1,
})
```

For database operations in tasks, consider using [database migrations](/2025/10/how-to-perform-database-migrations-in-go-using-golang-migrate.html) to manage schema changes as your tasks evolve.

If you're processing uploaded files, integrate with [S3 uploads](/2025/10/how-to-upload-files-to-aws-s3-in-go-with-sdk-v2.html) for reliable storage before processing.

## Troubleshooting Common Issues

**Tasks not being processed:**
- Check worker is running: `ps aux | grep worker`
- Verify Redis connection: `redis-cli ping`
- Check queue names match between client and worker
- Look for errors in worker logs

**Tasks failing repeatedly:**
- Check error logs for root cause
- Verify external services (email, S3) are accessible
- Increase timeout if tasks need more time
- Add retry logic for transient errors

**Redis connection issues:**
- Increase connection pool size
- Check Redis max connections: `redis-cli CONFIG GET maxclients`
- Monitor Redis memory: `redis-cli INFO memory`
- Use Redis cluster for high availability

**High memory usage:**
- Reduce worker concurrency
- Process large payloads in chunks
- Clean up completed tasks regularly
- Monitor with `asynqmon` UI

## Wrapping Up

Background jobs are essential for building responsive, scalable [Go applications](/tags/go/). Asynq gives you everything needed for production: automatic retries, scheduling, priorities, monitoring, and graceful shutdown.

Start simple - enqueue emails and image processing. As you grow, add scheduled reports, webhook delivery, and data exports. The patterns scale from small apps to high-traffic systems processing millions of tasks daily.

Key takeaways: return HTTP responses immediately and process work asynchronously, use appropriate queues and priorities for different task types, implement proper error handling and retries, monitor tasks with asynqmon and metrics, test your task handlers like any other code, and deploy workers separately from your API for independent scaling.

Background jobs move slow work out of request cycles. Your API stays fast, users get instant feedback, and heavy workloads run reliably in the background. That's how you build systems that scale.

For production deployments, combine this with [Docker containerization](/tags/docker/), [database migrations](/2025/10/how-to-perform-database-migrations-in-go-using-golang-migrate.html), and proper [monitoring and profiling](/2025/10/how-to-profile-and-optimize-go-applications-with-pprof.html).
