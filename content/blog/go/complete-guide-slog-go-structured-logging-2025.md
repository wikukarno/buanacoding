---
title: "The Complete Guide to slog (Go 1.21+) Modern Structured Logging in Go (2025)"
date: 2025-09-01T08:00:00+07:00
draft: false
url: /2025/09/complete-guide-slog-go-structured-logging-2025.html
description: "Learn Go's built-in structured logger slog: setup, JSON/Text handlers, levels, contextual attributes, custom handlers, HTTP middleware, testing, and production patterns for observability."
keywords: ["go slog", "log/slog", "structured logging go", "go logging best practices", "json logging", "slog handler", "slog examples", "zap vs slog", "logrus vs slog", "go observability"]
tags:
  - Go
  - Logging
  - Observability
  - Production
faq:
  - question: "Why use slog instead of fmt.Println or log.Printf for application logging?"
    answer: "Plain text logging becomes unmanageable at scale—filtering, parsing, and analyzing text logs requires brittle regex. slog emits structured key-value pairs, making logs machine-readable. Benefits: (1) Searchability: {\"level\":\"ERROR\",\"user_id\":42} lets you filter errors for specific users instantly—impossible with \"ERROR: something failed for user 42\". (2) Aggregation: count errors by endpoint, calculate p95 latency, track active users—all from logs. (3) Correlation: add request_id to every log in request, trace entire flow across services. (4) Type safety: slog.Info(\"login\", \"user_id\", 42) vs fmt.Printf(\"login user_id=%d\", 42)—first is parseable JSON, second is string. (5) Observability: ELK, Grafana, Datadog ingest JSON natively—no custom parsers. Cost: slight verbosity (slog.Info(\"msg\", \"key\", val) vs log.Println(\"msg\")), but production benefits outweigh. When to use plain logs: quick scripts, debugging locally. Production apps: always use structured logging—future-you debugging 3am outage will thank you."
  - question: "When should I use TextHandler vs JSONHandler in slog?"
    answer: "Use TextHandler for local development (human-readable), JSONHandler for production/CI (machine-parseable). TextHandler outputs: time=2025-09-01T10:30:15.123+07:00 level=INFO msg=\"server started\" addr=:8080—colorized, easy to read in terminal. JSONHandler outputs: {\"time\":\"2025-09-01T10:30:15.123+07:00\",\"level\":\"INFO\",\"msg\":\"server started\",\"addr\":\":8080\"}—parseable by log aggregators. Pattern: switch based on ENV: if os.Getenv(\"ENV\") == \"prod\" { handler = slog.NewJSONHandler(...) } else { handler = slog.NewTextHandler(...) }. Production: always JSON—Elasticsearch, Loki, CloudWatch expect JSON. Development: text for quick feedback. CI/CD: JSON for archival/analysis. Don't: JSON in development (hard to read), text in production (can't parse). AddSource option: opts.AddSource = true adds file:line to logs—useful in development, slight overhead in production. Trade-off: TextHandler is ~10% faster but loses structure. Best practice: logx package that switches handlers based on environment, one config for entire app."
  - question: "How do I prevent logging sensitive data like passwords or tokens with slog?"
    answer: "Use ReplaceAttr in HandlerOptions to redact sensitive keys before emission. Problem: slog.Info(\"signup\", \"email\", \"user@example.com\", \"password\", \"secret123\") logs password in plaintext—disaster if logs shipped to third-party. Solution: redacting := &slog.HandlerOptions{ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr { switch a.Key { case \"password\", \"token\", \"authorization\", \"api_key\", \"credit_card\": return slog.String(a.Key, \"REDACTED\"); } return a }}; logger := slog.New(slog.NewJSONHandler(os.Stdout, redacting)). Now slog.Info(\"signup\", \"password\", \"secret\") outputs {\"password\":\"REDACTED\"}. Common keys to redact: password, token, authorization, bearer, secret, api_key, access_token, refresh_token, ssn, credit_card, cvv. Pattern matching: use strings.Contains(a.Key, \"password\") for case-insensitive. Nested groups: check groups slice to redact specific paths like user.password. Testing: write test that logs sensitive data, assert REDACTED appears. Don't: rely on code review—use automated redaction. Production: audit logs for leaks: grep -i 'password.*:.*[^R]' logs.json. Also: never log full request/response bodies—contain auth headers, form data. Compliance: GDPR, PCI-DSS require redaction of PII/payment data in logs."
  - question: "Should I migrate to slog or keep using zap/logrus for existing projects?"
    answer: "For new projects: use slog—standard library, zero dependencies, good performance. Existing projects: migrate if zap/logrus causes issues, otherwise defer. slog advantages: (1) Standard library—no dependencies, always compatible. (2) Simplicity—less boilerplate than zap. (3) Stable API—won't break on updates. (4) Good performance—650ns/op vs zap 420ns/op, logrus 3200ns/op (acceptable for most apps). zap advantages: (1) Faster—30-40% lower latency for high-throughput (>100k logs/sec). (2) Mature ecosystem—many integrations. (3) Sampling—reduce log volume under load. When to migrate: (1) High dependency churn—zap/logrus conflicts with other libs. (2) Simplifying stack—reducing dependencies. (3) Team unfamiliarity—new developers know stdlib better. When to keep existing: (1) Performance critical—zap's speed matters (trading systems, game servers). (2) Advanced features—custom encoders, sampling, hooks. (3) No pain—if logging works, don't fix it. Migration strategy: (1) Adapter layer: keep zap interface, swap backend to slog gradually. (2) New code uses slog, old code unchanged. (3) Feature parity first—ensure slog supports all use cases. Don't: rewrite entire codebase for logging—low ROI unless other benefits."
  - question: "How do I add request tracing and correlation IDs with slog in HTTP middleware?"
    answer: "Create middleware that injects request_id into context and logger, ensuring all logs in request include ID. Pattern: (1) Generate request_id at middleware entry. (2) Store in context.Context. (3) Create scoped logger with request_id. (4) Use scoped logger in handlers. Implementation: func RequestLogger(next http.Handler) http.Handler { return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { rid := generateRequestID(); ctx := context.WithValue(r.Context(), RequestIDKey, rid); logger := slog.Default().With(\"request_id\", rid, \"method\", r.Method, \"path\", r.URL.Path); logger.Info(\"request started\"); next.ServeHTTP(w, r.WithContext(ctx)); logger.Info(\"request completed\") }) }. In handlers: retrieve logger from context or use request_id: rid := r.Context().Value(RequestIDKey).(string); slog.Info(\"processing\", \"request_id\", rid). Advanced: store logger in context: type ctxKey string; const LoggerKey ctxKey = \"logger\"; ctx := context.WithValue(r.Context(), LoggerKey, logger); then retrieve: logger := ctx.Value(LoggerKey).(*slog.Logger). Distributed tracing: add trace_id from OpenTelemetry: span := trace.SpanFromContext(ctx); logger = logger.With(\"trace_id\", span.SpanContext().TraceID().String()). Benefits: (1) Filter all logs for single request. (2) Correlate logs across services. (3) Debug user issues by tracing request flow. Production: use UUID or nanoid for request_id—unique across instances. Don't: use sequential IDs (security risk), or skip request_id (impossible to correlate logs)."
  - question: "Does slog have performance overhead compared to plain logging, and how to minimize allocations?"
    answer: "slog allocates ~48 B/op with 1 alloc/op for typical log call—acceptable for most apps, optimize only if profiling shows logging bottleneck. Benchmark: BenchmarkSlog-8 2000000 650 ns/op 48 B/op 1 allocs/op—contrast with fmt.Println (~100 ns/op but unstructured). Allocations come from: (1) Attribute slices. (2) Interface conversion for values. (3) JSON encoding. (4) Time formatting. Optimization techniques: (1) Log level filtering: if slog.Default().Enabled(ctx, slog.LevelDebug) { slog.Debug(...) }—skips expensive attribute collection if level disabled (rarely needed, slog optimizes internally). (2) Reuse loggers with .With(): baseLogger := slog.Default().With(\"service\", \"api\"); use baseLogger everywhere—amortizes attribute cost. (3) Avoid logging in hot loops: batch log every N iterations or use metrics instead. (4) Disable AddSource in production: opts.AddSource = true adds runtime.Caller overhead. (5) io.Writer efficiency: write to buffered writer or async writer, not unbuffered stdout. (6) Reduce attribute count: 3-5 attributes per log ideal, >10 slows encoding. When to optimize: (1) Profiling shows logging >5% CPU. (2) Logs >100k/sec sustained. (3) Latency-sensitive path (p99 <10ms). Don't: premature optimization—650ns is negligible vs 50ms database query. Measure first: go test -bench=. -benchmem -cpuprofile=cpu.out, then go tool pprof cpu.out to identify real bottleneck. For extreme throughput: consider zap (420 ns/op) or async logging."
---

Go 1.21 introduced `log/slog`, a standard structured logging API that finally brings first‑class JSON and attribute‑based logging to the standard library. If you’ve used `zap` or `logrus`, the core ideas will feel familiar—just simpler and standardized.

This guide takes you from zero to production-ready logging with `slog`. We'll start with basic setup, then gradually build up to advanced patterns like HTTP middleware, security, testing, and observability integration. Each section includes working examples you can run immediately.

<!--readmore-->

### Why structured logging matters
------------------------------
Plain text logs are easy to read but hard to search and analyze. Structured logs emit key–value pairs (JSON), which makes it trivial to filter by `traceID`, aggregate by `user_id`, or alert on `level=ERROR`. For API work, check out how we build routes in Go here: [How to Build a REST API in Go using net/http]({{< relref "blog/go/how-to-build-a-rest-api-in-go-using-net-http.md" >}}). Pairing a solid logging strategy with a clean project structure helps in the long run: [Structuring Go Projects: Clean Project Structure and Best Practices]({{< relref "blog/go/structuring-go-projects-clean-project-structure-and-best-practices.md" >}}).

### Quick start: Text vs JSON
-------------------------
`slog` writes through a Handler. Use a colorful text output locally and JSON in production.

```go
package main

import (
    "log/slog"
    "os"
)

func main() {
    // Development: human‑friendly text
    textHandler := slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})

    // Production: machine‑friendly JSON
    jsonHandler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})

    // Choose based on env
    var h slog.Handler = textHandler
    if os.Getenv("ENV") == "prod" {
        h = jsonHandler
    }
    logger := slog.New(h)
    slog.SetDefault(logger) // optional: use slog.Default()

    slog.Info("server starting", "addr", ":8080", "version", "1.0.0")
}
```

**Output examples:**

Development (text format):
```
time=2025-09-01T10:30:15.123+07:00 level=INFO msg="server starting" addr=:8080 version=1.0.0
```

Production (JSON format):
```json
{"time":"2025-09-01T10:30:15.123456+07:00","level":"INFO","msg":"server starting","addr":":8080","version":"1.0.0"}
```

### Understanding slog core concepts
---------------------------------
Before diving deeper, let's understand slog's key building blocks:

- **Logger**: The main logging interface
- **Handler**: Controls output format (JSON/Text) and destination
- **Attributes**: Key-value pairs that add context (`"user_id", 42`)
- **Groups**: Nested attributes under a common key

### Adding context with attributes

Attributes are name–value pairs that add context to your logs. You can add them per-call or create scoped loggers:

```go
// Method 1: Add attributes per call
slog.Info("user action", "user_id", 42, "action", "login", "ip", "203.0.113.10")

// Method 2: Create scoped logger with permanent attributes
userLog := slog.Default().With("user_id", 42, "session", "abc123")
userLog.Info("logged in", "ip", "203.0.113.10")
userLog.Info("viewed profile")  // user_id and session automatically included
```

**Output:**
```json
{"time":"2025-09-01T10:30:15+07:00","level":"INFO","msg":"logged in","user_id":42,"session":"abc123","ip":"203.0.113.10"}
{"time":"2025-09-01T10:30:16+07:00","level":"INFO","msg":"viewed profile","user_id":42,"session":"abc123"}

### Organizing logs with groups
Use `WithGroup` to nest attributes under a key. This keeps related fields organized.

```go
l := slog.Default().WithGroup("http").With("method", "GET", "route", "/users/:id")
l.Info("request completed", "status", 200, "latency_ms", 34)
// JSON example: {"http":{"method":"GET","route":"/users/:id"},"status":200,"latency_ms":34}
```

### Levels and filtering
`slog` supports `DEBUG`, `INFO`, `WARN`, `ERROR`. Configure in `HandlerOptions`.

```go
opts := &slog.HandlerOptions{Level: slog.LevelDebug}
handler := slog.NewJSONHandler(os.Stdout, opts)
logger := slog.New(handler)
logger.Debug("cache miss", "key", "user:42")
```

Dynamic levels (e.g., from env var) are common. Ensure noisy debug logs stay off in production.

---

## Production-Ready Patterns

Now that you understand the basics, let's explore production patterns including security, middleware, and performance.

Handler configuration for production
--------------------------
`HandlerOptions` includes useful knobs:

- `AddSource`: attach source file/line (useful, slight overhead)
- `ReplaceAttr`: transform or redact attributes before emit

Redact sensitive data
---------------------
Never log secrets or PII. Use `ReplaceAttr` to sanitize by key.

```go
redacting := &slog.HandlerOptions{
    Level: slog.LevelInfo,
    ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
        // Redact common sensitive keys
        switch a.Key {
        case "password", "token", "authorization", "api_key":
            return slog.String(a.Key, "REDACTED")
        }
        return a
    },
}
logger := slog.New(slog.NewJSONHandler(os.Stdout, redacting))
logger.Info("signup", "email", "user@example.com", "password", "secret")
```

HTTP middleware with request IDs
--------------------------------
For APIs, enrich logs with `request_id`, method, path, and latency. A minimal net/http middleware:

```go
package middleware

import (
    "context"
    "log/slog"
    "math/rand"
    "net/http"
    "time"
)

type ctxKey string

const RequestIDKey ctxKey = "request_id"

func RequestLogger(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        rid := newRID()
        ctx := context.WithValue(r.Context(), RequestIDKey, rid)

        l := slog.Default().With(
            "request_id", rid,
            "method", r.Method,
            "path", r.URL.Path,
        )

        l.Info("request started")
        rw := &statusRecorder{ResponseWriter: w, status: 200}
        next.ServeHTTP(rw, r.WithContext(ctx))
        l.Info("request completed", "status", rw.status, "latency_ms", time.Since(start).Milliseconds())
    })
}

type statusRecorder struct {
    http.ResponseWriter
    status int
}

func (w *statusRecorder) WriteHeader(code int) {
    w.status = code
    w.ResponseWriter.WriteHeader(code)
}

func newRID() string {
    const letters = "abcdefghijklmnopqrstuvwxyz0123456789"
    b := make([]byte, 12)
    for i := range b {
        b[i] = letters[rand.Intn(len(letters))]
    }
    return string(b)
}
```

Hook this into your server router. If you’re building your own HTTP server, our step‑by‑step REST tutorial may help: [How to Build a REST API in Go using net/http]({{< relref "blog/go/how-to-build-a-rest-api-in-go-using-net-http.md" >}}).

Library APIs: pass loggers or context?
--------------------------------------
Two common approaches:

1) Pass a `*slog.Logger` to constructors and keep it on the type.
```go
type Store struct { log *slog.Logger }

func NewStore(log *slog.Logger) *Store { return &Store{log: log} }
```

2) Derive a logger from `context.Context` at call sites (attach fields per request). You can wrap this yourself by keeping a logger in context and retrieving it in functions. Choose one convention and stick to it to keep call sites clean.

For clean separation of layers and testability, see our guide: [Structuring Go Projects: Clean Project Structure and Best Practices]({{< relref "blog/go/structuring-go-projects-clean-project-structure-and-best-practices.md" >}}).

Emitting errors with details
----------------------------
Log actionable error information: message, error type, and a few high‑signal attributes (IDs, sizes, counts). Avoid dumping full payloads.

```go
if err := svc.Do(ctx, job); err != nil {
    slog.Error("process job failed", "job_id", job.ID, "err", err)
    return err
}
```

Working with JSON payloads
--------------------------
Keep payload logging minimal and scrubbed. For structured data handling basics in Go, revisit: [Working with JSON in Go: Encode, Decode, and Tag Structs]({{< relref "blog/go/working-with-json-in-go-encode-decode-and-tag-structs.md" >}}).

Environment presets
-------------------
Create a small helper that picks sensible defaults based on `ENV`.

```go
package logx

import (
    "log/slog"
    "os"
)

func New() *slog.Logger {
    env := os.Getenv("ENV")
    opts := &slog.HandlerOptions{Level: slog.LevelInfo}
    var h slog.Handler
    if env == "prod" {
        h = slog.NewJSONHandler(os.Stdout, opts)
    } else {
        opts.AddSource = true
        h = slog.NewTextHandler(os.Stdout, opts)
    }
    return slog.New(h)
}
```

Rotation and shipping
---------------------
`slog` doesn’t rotate files—it writes to an `io.Writer`. In containers, write to stdout/stderr and let the platform collect (Docker, systemd, Kubernetes). If you must write files, use external rotation (logrotate) or a service.

Observability integrations
--------------------------
Structured logs complement metrics and traces. If you’re adding tracing next, consider OpenTelemetry for Go; link request IDs between logs and traces for faster incident response.

Testing logs
------------
You can capture output with a buffer for assertions. For broader testing patterns, see: [Testing in Go: Writing Unit Tests with the Testing Package]({{< relref "blog/go/testing-in-go-writing-unit-tests-with-the-testing-package.md" >}}).

```go
package mypkg

import (
    "bytes"
    "log/slog"
    "testing"
)

func TestLogs(t *testing.T) {
    var buf bytes.Buffer
    l := slog.New(slog.NewJSONHandler(&buf, &slog.HandlerOptions{Level: slog.LevelDebug}))
    l.Info("hello", "key", "value")
    out := buf.String()
    if want := "\"hello\""; !bytes.Contains([]byte(out), []byte(want)) {
        t.Fatalf("missing message: %s", out)
    }
}
```

Performance benchmarking
------------------------
`slog` is designed to be fast with minimal allocations. Here's how it compares to popular logging libraries.

```go
package logging_test

import (
    "io"
    "log/slog"
    "testing"

    "go.uber.org/zap"
    "github.com/sirupsen/logrus"
)

func BenchmarkSlog(b *testing.B) {
    logger := slog.New(slog.NewJSONHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelInfo}))
    b.ResetTimer()
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            logger.Info("benchmark message", "user_id", 12345, "action", "login", "ip", "192.168.1.1")
        }
    })
}

func BenchmarkZap(b *testing.B) {
    logger := zap.New(zap.NewCore(
        zap.NewJSONEncoder(zap.NewProductionEncoderConfig()),
        zap.AddSync(io.Discard),
        zap.InfoLevel,
    ))
    b.ResetTimer()
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            logger.Info("benchmark message", zap.Int("user_id", 12345), zap.String("action", "login"), zap.String("ip", "192.168.1.1"))
        }
    })
}

func BenchmarkLogrus(b *testing.B) {
    logger := logrus.New()
    logger.SetOutput(io.Discard)
    logger.SetFormatter(&logrus.JSONFormatter{})
    b.ResetTimer()
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            logger.WithFields(logrus.Fields{"user_id": 12345, "action": "login", "ip": "192.168.1.1"}).Info("benchmark message")
        }
    })
}
```

**Typical results** (your mileage may vary):
```
BenchmarkSlog-8     2000000    650 ns/op    48 B/op    1 allocs/op
BenchmarkZap-8      3000000    420 ns/op    32 B/op    1 allocs/op  
BenchmarkLogrus-8    500000   3200 ns/op   280 B/op   10 allocs/op
```

`slog` offers excellent performance while maintaining simplicity. Zap is still fastest for high-throughput scenarios, but `slog`'s standard library status and ease of use make it ideal for most applications.

---

## Advanced: Observability Integration

The following sections cover enterprise-grade logging patterns. If you're just getting started, you can skip to the "Migration notes" section and return here when you need production observability.

ELK Stack and Grafana integration
---------------------------------
Production logging shines when paired with log aggregation. Here's how to set up `slog` with popular observability stacks.

### Elasticsearch + Logstash + Kibana (ELK)

**Docker Compose setup** (`docker-compose.yml`):
```yaml
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    
  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    ports:
      - "5044:5044"
    depends_on:
      - elasticsearch
    
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

  app:
    build: .
    environment:
      - ENV=prod
      - LOG_OUTPUT=json
    depends_on:
      - logstash
```

**Logstash configuration** (`logstash.conf`):
```ruby
input {
  beats {
    port => 5044
  }
  # Or direct TCP input for simple setups
  tcp {
    port => 5000
    codec => json_lines
  }
}

filter {
  if [fields][service] == "go-api" {
    # Parse slog JSON output
    json {
      source => "message"
    }
    
    # Convert slog timestamp
    date {
      match => [ "time", "ISO8601" ]
    }
    
    # Extract request_id for correlation
    if [request_id] {
      mutate {
        add_tag => [ "has_request_id" ]
      }
    }
    
    # Create structured fields
    mutate {
      add_field => { "service" => "go-api" }
      add_field => { "log_level" => "%{level}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "go-logs-%{+YYYY.MM.dd}"
  }
}
```

**Go application with structured logging**:
```go
package main

import (
    "log/slog"
    "net"
    "os"
    "time"
)

func main() {
    // Configure slog for ELK
    opts := &slog.HandlerOptions{
        Level: slog.LevelInfo,
        ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
            // Ensure timestamp is in ISO8601 format for Logstash
            if a.Key == slog.TimeKey {
                return slog.String(slog.TimeKey, a.Value.Time().Format(time.RFC3339))
            }
            return a
        },
    }
    
    var handler slog.Handler
    if os.Getenv("LOG_OUTPUT") == "logstash" {
        // Send directly to Logstash TCP input
        conn, err := net.Dial("tcp", "logstash:5000")
        if err != nil {
            panic(err)
        }
        handler = slog.NewJSONHandler(conn, opts)
    } else {
        handler = slog.NewJSONHandler(os.Stdout, opts)
    }
    
    logger := slog.New(handler)
    slog.SetDefault(logger)
    
    // Add service metadata
    baseLogger := slog.Default().With("service", "go-api", "version", "1.0.0")
    
    baseLogger.Info("application started", "port", 8080)
    
    // Example business logic logging
    requestLogger := baseLogger.With("request_id", "req-123", "user_id", 456)
    requestLogger.Info("processing order", "order_id", "ord-789", "amount", 99.99)
    requestLogger.Warn("inventory low", "product_id", "prod-123", "remaining", 5)
}
```

### Grafana + Loki setup

**Docker Compose for Grafana stack**:
```yaml
version: '3.8'
services:
  loki:
    image: grafana/loki:2.9.0
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    
  promtail:
    image: grafana/promtail:2.9.0
    volumes:
      - /var/log:/var/log:ro
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    
  grafana:
    image: grafana/grafana:10.2.0
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana

volumes:
  grafana-storage:
```

**Promtail configuration** (`promtail-config.yml`):
```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: go-app-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: go-app
          service: api
          __path__: /var/log/go-app/*.log
    
    pipeline_stages:
      - json:
          expressions:
            time: time
            level: level
            msg: msg
            request_id: request_id
            user_id: user_id
      - labels:
          level:
          request_id:
      - timestamp:
          source: time
          format: RFC3339
```

**Go app configured for Loki**:
```go
package main

import (
    "log/slog"
    "os"
)

func setupLogger() *slog.Logger {
    opts := &slog.HandlerOptions{
        Level: slog.LevelInfo,
        ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
            // Add environment and service labels
            return a
        },
    }
    
    // Write to file for Promtail to collect
    if logFile := os.Getenv("LOG_FILE"); logFile != "" {
        file, err := os.OpenFile(logFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
        if err == nil {
            return slog.New(slog.NewJSONHandler(file, opts))
        }
    }
    
    return slog.New(slog.NewJSONHandler(os.Stdout, opts))
}

func main() {
    logger := setupLogger().With(
        "service", "go-api",
        "version", "1.0.0",
        "environment", os.Getenv("ENV"),
    )
    slog.SetDefault(logger)
    
    slog.Info("service started", "config", "loaded")
    
    // Example with trace correlation
    traceLogger := logger.With("trace_id", "trace-abc123", "span_id", "span-456")
    traceLogger.Info("database query", "table", "users", "duration_ms", 45)
    traceLogger.Error("connection failed", "error", "timeout", "retry_count", 3)
}
```

### Grafana Dashboard queries

**LogQL queries for common patterns**:
```logql
# All errors in the last hour
{service="go-api"} |= "ERROR" | json

# Request latency by endpoint  
{service="go-api"} | json | __error__ = "" | unwrap duration_ms | rate(5m)

# Error rate by request_id
rate(({service="go-api"} |= "ERROR" | json)[5m])

# Top users by request volume
topk(10, count by (user_id) (rate({service="go-api"} | json | __error__ = "" [5m])))
```

**Key benefits of structured logging with observability**:
- **Correlation**: Link logs, metrics, and traces with `request_id`
- **Alerting**: Set up alerts on error rates or specific patterns
- **Debugging**: Filter by user, endpoint, or time range instantly
- **Analytics**: Aggregate business metrics from log data

Production tip: Always include consistent field names (`request_id`, `user_id`, `trace_id`) across your microservices for easier correlation in your observability stack.

Migration notes (zap/logrus → slog)
-----------------------------------
- Message + fields map directly to `slog.Info("msg", "key", val, ...)`.
- Replace global usage with dependency injection or a single `slog.SetDefault` during bootstrap.
- If you relied on sampling or custom encoders, keep using your old logger behind an adapter until equivalent features are available or needed.

Common pitfalls and tips
------------------------
- Be consistent with key names (`request_id`, not `requestId`).
- Avoid logging entire structs or raw bodies in production.
- Use `WithGroup` for domains like `http`, `db`, `queue`.
- Keep error logs actionable; include IDs, not entire payloads.
- Prefer stdout in containers; let your platform ship logs.

Putting it together (mini example)
----------------------------------
```go
package main

import (
    "log/slog"
    "net/http"
    "os"
    "time"
)

func main() {
    env := os.Getenv("ENV")
    opts := &slog.HandlerOptions{Level: slog.LevelInfo}
    if env != "prod" { opts.AddSource = true }
    var h slog.Handler
    if env == "prod" { h = slog.NewJSONHandler(os.Stdout, opts) } else { h = slog.NewTextHandler(os.Stdout, opts) }
    slog.SetDefault(slog.New(h))

    mux := http.NewServeMux()
    mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
        slog.Default().WithGroup("http").Info("health check", "status", "ok", "time", time.Now().Format(time.RFC3339))
        w.WriteHeader(http.StatusOK)
        _, _ = w.Write([]byte("ok"))
    })

    addr := ":8080"
    slog.Info("server listening", "addr", addr)
    _ = http.ListenAndServe(addr, mux)
}
```

Where to go next
----------------
- Build a small REST API and add the middleware above: [How to Build a REST API in Go using net/http]({{< relref "blog/go/how-to-build-a-rest-api-in-go-using-net-http.md" >}})
- Learn how to pass cancellation and deadlines with `context`: [Using Context in Go: Cancellation, Timeout, and Deadlines Explained]({{< relref "blog/go/using-context-in-go-cancellation-timeout-and-deadlines-explained.md" >}})
- Organize your project for growth: [Structuring Go Projects: Clean Project Structure and Best Practices]({{< relref "blog/go/structuring-go-projects-clean-project-structure-and-best-practices.md" >}})
- Review JSON handling patterns in Go: [Working with JSON in Go: Encode, Decode, and Tag Structs]({{< relref "blog/go/working-with-json-in-go-encode-decode-and-tag-structs.md" >}})
- Add automated tests, including log checks: [Testing in Go: Writing Unit Tests with the Testing Package]({{< relref "blog/go/testing-in-go-writing-unit-tests-with-the-testing-package.md" >}})

With `slog`, you get a batteries‑included, standard way to emit clean, consistent logs. Start with text locally, JSON in production, add just enough context, and keep sensitive data out. Your future self—and your on‑call teammates—will thank you.
