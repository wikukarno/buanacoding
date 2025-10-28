---
title: "Using Context in Go - Cancellation"
date: 2025-04-27T10:00:00.004+07:00
draft: false
url: /2025/04/using-context-in-go-cancellation.html
aliases:
  - /2025/04/cancellation-timeout-and-deadlines-explained.html
  - /2025/04/using-context-in-go-cancellation-timeout-and-deadlines-explained.html
tags:
  - Go
description: "Learn how to use Go’s context for cancellation: propagate cancel signals across goroutines, avoid leaks with defer cancel, and write resilient handlers."
keywords: ["Go", "context", "cancellation", "timeout", "deadlines", "goroutines"]
faq:
  - question: "When should I use context for cancellation vs using channels or sync primitives?"
    answer: "Use context for cancellation propagation across function calls and goroutines--standardized, composable. Use channels for data flow with cancellation as side effect. Context (cancellation signal): func Process(ctx context.Context, items []Item) error { for _, item := range items { select { case <-ctx.Done(): return ctx.Err(); default: process(item) } } }--stops on cancel. Use when: (1) Request-scoped cancellation: HTTP request canceled, stop all workers. (2) Timeout enforcement: database query, API call--hard deadline. (3) Cascading cancellation: parent goroutine canceled, children stop. (4) Standard library integration: http.NewRequestWithContext, sql.QueryContext. Channels (data + cancellation): done := make(chan struct{}); go func() { for { select { case <-done: return; case item := <-workCh: process(item) } } }(); close(done)--stops and signals completion. Use when: (1) Producer-consumer: channel carries work items, close signals no more. (2) Fan-out pattern: distribute to workers, close to stop. (3) Need to distinguish completion from cancellation: done vs canceled. Comparison: context standardized (first param convention), works with stdlib, timeout/deadline built-in. Channels custom, more flexibility, can carry data. Don't mix: passing both context and done channel--redundant, confusing. Best practice: context for cancellation signal, channels for work distribution. Pattern: accept context in function, check ctx.Done() in loops: for { select { case <-ctx.Done(): return; default: work() } }. HTTP handlers: r.Context() provides request context--canceled when client disconnects. Background jobs: use context.Background() as root, derive timeouts: ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)."
  - question: "When is it appropriate to use context.Value, and what are its limitations?"
    answer: "Use context.Value sparingly for request-scoped data crossing API boundaries (request ID, auth token)--not for optional parameters. Avoid for business logic or configuration. Valid use: ctx = context.WithValue(ctx, requestIDKey, uuid.New()); later: id := ctx.Value(requestIDKey).(uuid.UUID). Examples: (1) Request ID for logging: tracing distributed requests. (2) Auth token: JWT extracted from header, passed to services. (3) User identity: authenticated user, used in audit logs. (4) Correlation data: tracing spans, baggage. Invalid use: (1) Optional function parameters: passing timeout via context.Value instead of parameter--wrong, use context.WithTimeout. (2) Configuration: passing DB connection, logger via context--wrong, inject as dependencies. (3) Business data: passing orderID via context--wrong, make it function parameter. Why limitations: (1) Type-unsafe: ctx.Value returns any, need type assertion--runtime panic if wrong. (2) Implicit: hidden dependencies, hard to see what function needs. (3) Not discoverable: can't tell from signature what's in context. (4) Testing harder: must populate context with all values tests need. Best practice: define typed keys: type contextKey string; const requestIDKey contextKey = \"requestID\". Avoid string keys: collisions between packages. Helpers: func RequestIDFromContext(ctx context.Context) (uuid.UUID, bool) { id, ok := ctx.Value(requestIDKey).(uuid.UUID); return id, ok }--type-safe extraction. Go proverb: 'context.Value should inform, not control'--use for observability (logging, tracing), not business logic. Anti-pattern: ctx.Value(\"timeout\")--use context.WithTimeout. ctx.Value(\"db\")--inject DB as struct field. If data is required for function to work: make it parameter, not context value. Production: limit context.Value to cross-cutting concerns: request ID, trace ID, user ID--data that flows through every layer but isn't core to any."
  - question: "Why is context always the first parameter, and what happens if I don't follow this convention?"
    answer: "Convention: func DoWork(ctx context.Context, arg1 Type1, arg2 Type2) error--context first, before other parameters. Consistency aids readability and tooling. Why first: (1) Consistency--every function looks same: db.QueryContext(ctx, query), http.NewRequestWithContext(ctx, method, url, body). (2) Visibility--context handling is important, first position emphasizes it. (3) Tooling--linters check first param is context: revive, staticcheck. (4) Standard library--all stdlib context-aware functions use this convention. What if you don't: (1) Code reviewers confused--not idiomatic. (2) Linters warn--golangci-lint flags non-standard position. (3) Harder refactoring--automated tools expect first param. (4) Team inconsistency--some functions ctx first, others ctx last. Exceptions: methods on types: func (s *Service) Process(id int, ctx context.Context)--still not recommended, prefer func (s *Service) Process(ctx context.Context, id int). Variadic functions: func (s *Service) Process(ctx context.Context, ids ...int)--ctx before variadic. Optional context: func Process(arg string, ctx ...context.Context)--anti-pattern, always require context or don't use it. Migration: adding context to existing function: change func Process(id int) error to func Process(ctx context.Context, id int) error--breaking change, version bump or new function ProcessWithContext. Best practice: always ctx as first param, use context.Background() if no cancellation needed initially--easier to add timeout later. Production: enforce with linter: revive with context-as-argument rule."
  - question: "What causes context leaks and why must I always call cancel() even if context expires naturally?"
    answer: "Context leak: goroutine/timer not cleaned up when context no longer needed--causes memory leak. Always defer cancel() immediately after creating context. Problem: ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second); doWork(ctx)--if doWork returns in 1 second, timer runs for 4 more seconds unnecessarily. Multiply by 1000 requests/sec = thousands of leaked timers. Fix: ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second); defer cancel(); doWork(ctx)--cancel() stops timer immediately when function returns. Why cancel() even if timeout expires: (1) WithTimeout creates goroutine + timer--need cleanup even after expiry. (2) WithCancel allocates resources--must release. (3) Multiple calls safe--cancel() idempotent, calling after expiry is no-op. Memory leak example: func handler(w http.ResponseWriter, r *http.Request) { ctx, _ := context.WithTimeout(r.Context(), 1*time.Second); query(ctx) }--never calls cancel(), timer leaks every request. 1M requests = 1M leaked timers. Correct: func handler(w http.ResponseWriter, r *http.Request) { ctx, cancel := context.WithTimeout(r.Context(), 1*time.Second); defer cancel(); query(ctx) }. Detection: go tool pprof -http=:6060 http://localhost:6060/debug/pprof/heap--shows leaked allocations. Monitor goroutine count: runtime.NumGoroutine()--grows unbounded if leaking. Pattern: always defer cancel() on same line: ctx, cancel := context.WithCancel(ctx); defer cancel()--hard to forget. Exception: none--always call cancel(). Even: ctx, cancel := context.WithCancel(context.Background()); go worker(ctx); shutdown := func() { cancel() }--shutdown calls cancel later, not leaked. Linters: govet warns 'cancel not called' but not always--manual review needed. Best practice: defer cancel() immediately, treat as invariant like defer file.Close()."
  - question: "How do I properly propagate context through application layers (handler -> service -> repository)?"
    answer: "Pass context as first parameter through every layer--don't create new root contexts mid-stack, derive from incoming context. HTTP handler (entry point): func handler(w http.ResponseWriter, r *http.Request) { ctx := r.Context(); user, err := userService.GetUser(ctx, id); ... }. r.Context() provides request context--canceled when client disconnects, has request-scoped values. Service layer: func (s *UserService) GetUser(ctx context.Context, id int) (*User, error) { user, err := s.repo.FindByID(ctx, id); if err != nil { return nil, err }; return user, nil }--passes context down. Repository layer: func (r *UserRepository) FindByID(ctx context.Context, id int) (*User, error) { return r.db.QueryRowContext(ctx, 'SELECT * FROM users WHERE id=$1', id).Scan(&user) }--uses context for query cancellation. Adding timeout at service layer: func (s *UserService) GetUser(ctx context.Context, id int) (*User, error) { ctx, cancel := context.WithTimeout(ctx, 2*time.Second); defer cancel(); return s.repo.FindByID(ctx, id) }--derives from incoming ctx, adds 2s timeout. Why derive: inherits parent cancellation--if handler ctx canceled (client disconnected), service/repo operations also canceled. Don't: create new root: func (s *UserService) GetUser(ctx context.Context, id int) (*User, error) { newCtx := context.Background(); return s.repo.FindByID(newCtx, id) }--breaks cancellation chain, query continues even if client gone. Background workers: use context.Background() as root since no incoming request: go func() { ctx := context.Background(); for { processJob(ctx) } }(). With shutdown: ctx, cancel := context.WithCancel(context.Background()); go worker(ctx); on shutdown: cancel()--stops worker. Testing: pass context.Background() in tests, or context.WithTimeout for timeout tests: ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond); defer cancel(); err := svc.SlowOperation(ctx); assert.Equal(context.DeadlineExceeded, err). Best practice: never create new root context in middle of call stack (except background jobs), always derive from incoming context--preserves cancellation and values."
  - question: "How do I test functions that use context for timeouts and cancellation?"
    answer: "Use context.WithTimeout with short duration for timeout tests, context.WithCancel with manual cancel for cancellation tests--verify function respects context. Test timeout: func TestProcessTimeout(t *testing.T) { ctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond); defer cancel(); err := Process(ctx); assert.Equal(t, context.DeadlineExceeded, err) }--Process should return within 10ms with DeadlineExceeded error. Test cancellation: func TestProcessCancellation(t *testing.T) { ctx, cancel := context.WithCancel(context.Background()); go func() { time.Sleep(10 * time.Millisecond); cancel() }(); err := Process(ctx); assert.Equal(t, context.Canceled, err) }--Process should stop when cancel() called. Test context propagation: func TestContextPropagation(t *testing.T) { ctx := context.WithValue(context.Background(), requestIDKey, \"test-123\"); result := ProcessWithContext(ctx); assert.Equal(t, \"test-123\", result.RequestID) }--verify context values passed through. Mock timeouts for external calls: type mockClient struct { delay time.Duration }; func (m *mockClient) Fetch(ctx context.Context) error { select { case <-time.After(m.delay): return nil; case <-ctx.Done(): return ctx.Err() } }--simulates slow operation, respects context. Table-driven timeout tests: tests := []struct { name string; timeout time.Duration; expectErr error }{{\"fast\", 1*time.Second, nil}, {\"timeout\", 10*time.Millisecond, context.DeadlineExceeded}}; for _, tt := range tests { t.Run(tt.name, func(t *testing.T) { ctx, cancel := context.WithTimeout(context.Background(), tt.timeout); defer cancel(); err := SlowFunc(ctx); assert.Equal(t, tt.expectErr, err) }) }. Testing cleanup: verify cancel() called: called := false; cancel := func() { called = true }; defer func() { assert.True(t, called, \"cancel not called\") }()--ensures no leak. Integration tests: use real context with reasonable timeout: ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second); defer cancel(); err := RealAPICall(ctx); assert.NoError(t, err)--tests actual behavior. Best practice: separate unit tests (mock timeouts, fast) from integration tests (real context, slower). Always test that long-running functions respect ctx.Done()--critical for production responsiveness."
---

As your Go applications become more concurrent and complex, you'll need a way to manage the lifecycle of your goroutines--especially when you want to cancel them, set timeouts, or propagate deadlines. This is where the `context` package comes in. It's the idiomatic way in Go to control concurrent processes gracefully and reliably.

In this article, you’ll learn:

*   What `context` is and why it’s important
*   Using `context.Background()` and `context.TODO()`
*   How to cancel a goroutine with `context.WithCancel()`
*   How to set a timeout or deadline
*   How to check if a context is done
*   Real-world examples and best practices

What Is Context?
----------------

The `context` package provides a way to carry deadlines, cancellation signals, and other request-scoped values across function boundaries and between goroutines.

It helps you:

*   Cancel long-running tasks
*   Set deadlines or timeouts
*   Propagate cancellation across multiple goroutines

Starting Point: Background and TODO
-----------------------------------

```go
ctx := context.Background() // root context, no cancel/timeout
ctx := context.TODO()       // use when unsure (placeholder)
```

Cancelling a Goroutine: WithCancel
----------------------------------

You can use `context.WithCancel` to manually stop a goroutine:

```go
func doWork(ctx context.Context) {
    for {
        select {
        case <-ctx .done="" :="context.WithCancel(context.Background())" cancel="" canceled="" code="" context="" ctx="" default:="" dowork="" fmt.println="" func="" go="" main="" orking...="" oroutine="" return="" the="" time.millisecond="" time.second="" time.sleep="">
```

When `cancel()` is called, the goroutine receives a signal via `ctx.Done()`.

Setting a Timeout: WithTimeout
------------------------------

```go
ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
defer cancel()

select {
case <-time .after="" case="" code="" completed="" ctx.done="" ctx.err="" fmt.println="" ontext="" peration="" time.second="" timeout:="">
```

`WithDeadline` works the same way, but with a fixed time:

```go
deadline := time.Now().Add(2 * time.Second)
ctx, cancel := context.WithDeadline(context.Background(), deadline) 
```

How to Use ctx.Done()
---------------------

The `ctx.Done()` channel is closed when the context is canceled or times out. Use it in `select` blocks to exit early.

Real-World Example: HTTP Request Timeout
----------------------------------------

```go
func fetch(ctx context.Context, url string) error {
    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return err
    }

    client := http.Client{}
    resp, err := client.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()

    fmt.Println("Status:", resp.Status)
    return nil
}

func main() {
    ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
    defer cancel()

    err := fetch(ctx, "https://httpbin.org/delay/2")
    if err != nil {
        fmt.Println("Request failed:", err)
    }
} 
```

Best Practices
--------------

*   Always call `cancel()` to release resources
*   Pass `context.Context` as the first argument in your functions
*   Use `context.WithTimeout` for operations with time limits
*   Use `context.WithCancel` for manual control

Common Mistakes
---------------

*   Not deferring `cancel()` -> memory leak
*   Ignoring `ctx.Err()` -> silent failure
*   Passing nil context or using `context.TODO()` in production

Conclusion
----------

Understanding `context` is essential for writing responsive, well-behaved concurrent programs in Go. Whether you're managing goroutines, dealing with timeouts, or handling request chains in a web server, context gives you the tools to do it cleanly and safely.

Next, we'll cover `sync.Mutex` and other tools for [synchronizing]({{< relref "blog/go/synchronizing-goroutines-in-go-using-syncmutex-and-synconce.md" >}}) data between goroutines.

Happy coding!
