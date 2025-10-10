---
title: 'Goroutines and Channels Explained'
date: 2025-04-26T10:00:00.003+07:00
draft: false
url: /2025/04/concurrency-in-go-goroutines-and.html
tags:
- Go
description: 'Learn how to use goroutines and channels in Go for concurrent programming. Understand the differences between concurrency and parallelism, and explore real-world examples.'
keywords: [
    "Go", "concurrency", "goroutines", "channels", "programming", "sync", "parallelism", "best practices"]
faq:
  - question: "Why does my program exit before goroutines finish executing?"
    answer: "Main function exits immediately, killing all goroutines—Go doesn't wait for them automatically. Problem: go sayHello(); fmt.Println(\"done\")—main exits before goroutine runs, output may not print. Goroutines run in background, main terminating kills entire process. Solutions: (1) sync.WaitGroup (best): var wg sync.WaitGroup; wg.Add(1); go func() { defer wg.Done(); work() }(); wg.Wait()—blocks until goroutine signals completion. (2) Channel synchronization: done := make(chan bool); go func() { work(); done <- true }(); <-done—blocks on receive. (3) time.Sleep (bad): time.Sleep(1 * time.Second)—race condition, may exit early or wait too long. Use WaitGroup for known goroutines, channels for producer-consumer. Don't: assume goroutines finish—they're preemptively scheduled, no guarantee. Production pattern: context with timeout: ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second); defer cancel(); go worker(ctx); <-ctx.Done()—prevents indefinite hanging. Always coordinate goroutine lifecycle—orphaned goroutines leak resources."
  - question: "When should I use buffered vs unbuffered channels?"
    answer: "Use unbuffered for synchronization (handshake), buffered for decoupling producers/consumers and avoiding blocking. Unbuffered (make(chan T)): send blocks until receive happens—tight synchronization: ch <- val blocks until another goroutine does <-ch. Use when: (1) Must ensure receiver got value. (2) Producer-consumer same speed. (3) Signaling events (done channel). Buffered (make(chan T, N)): send blocks only when buffer full—decouples timing: ch := make(chan int, 10); ch <- 1 doesn't block if <10 items. Use when: (1) Burst traffic—producer faster temporarily. (2) Worker pools—jobs queue up. (3) Avoiding goroutine blocking in select. Trade-offs: unbuffered = simpler reasoning but more blocking, buffered = higher throughput but complexity (what size?). Buffer sizing: (1) Worker pool: buffer = number of workers (jobs queue matches capacity). (2) Batching: buffer = batch size. (3) Event bus: buffer = burst capacity (e.g., 100 for metrics). Don't: huge buffers (>10000) without reason—hides backpressure, memory leak. Anti-pattern: buffered channel to \"fix\" deadlock—usually masks real issue (missing goroutine). Rule: start unbuffered, add buffer only when profiling shows blocking, keep buffer small (1-100)."
  - question: "What causes 'fatal error: all goroutines are asleep - deadlock!' and how to fix it?"
    answer: "Deadlock occurs when all goroutines wait for each other, none can proceed—Go runtime detects and panics. Common causes: (1) Send without receive: ch := make(chan int); ch <- 1 blocks forever (no receiver). Fix: run sender/receiver in goroutine: go func() { ch <- 1 }(); val := <-ch. (2) Receive without send: <-ch blocks forever if no sender. Fix: ensure sender exists. (3) WaitGroup mismatch: wg.Add(2) but only wg.Done() once—wg.Wait() hangs forever. Fix: match Add/Done count. (4) Circular wait: goroutine A waits for B, B waits for A. Fix: eliminate cycle, use select with timeout. (5) Closed channel misuse: reading from never-closed channel in for range. Fix: close channel when done: close(ch). Debug: (1) Check channel directions: <-chan T (receive-only), chan<- T (send-only). (2) Trace goroutines: GODEBUG=schedtrace=1000 go run main.go shows stuck goroutines. (3) Add timeouts: select { case <-ch: ...; case <-time.After(5*time.Second): panic(\"timeout\") }. Prevention: (1) Close channels from sender: defer close(ch). (2) Use buffered channels cautiously. (3) Test with go test -race. Production: use context with timeout to prevent silent hangs: ctx, cancel := context.WithTimeout(...); defer cancel(); select { case <-work: ...; case <-ctx.Done(): return ctx.Err() }."
  - question: "How do I detect and fix race conditions in my concurrent Go code?"
    answer: "Use go run -race or go test -race to detect races—runtime instruments code to track concurrent access, panics on unsafe access. Race condition: two goroutines access same variable concurrently, one writes—unpredictable behavior. Example: counter := 0; go func() { counter++ }(); go func() { counter++ }(); time.Sleep(...)—final value may be 1 or 2 (lost update). Race detector: go run -race main.go outputs: WARNING: DATA RACE; Write at 0x... by goroutine 6; Previous read at 0x... by main goroutine—shows exact lines. Fixes: (1) Mutex: var mu sync.Mutex; mu.Lock(); counter++; mu.Unlock()—only one goroutine modifies at a time. (2) Channel: updates := make(chan int); go func() { for delta := range updates { counter += delta } }()—serialize writes. (3) Atomic: atomic.AddInt64(&counter, 1)—lock-free for simple types. When to use: mutex for complex state, channel for message passing, atomic for counters/flags. Don't: ignore race warnings—they're non-deterministic, may not manifest in testing but fail in production. Common mistakes: (1) Shared slice append: not safe, use mutex or copy. (2) Shared map access: crashes, must use sync.Map or mutex. (3) Closure variable: for i := 0; i < 10; i++ { go func() { fmt.Println(i) }() }—all print 10, fix: pass i as arg. Production: always run tests with -race in CI, use sync.RWMutex for read-heavy workloads."
  - question: "When should I use channels vs sync.Mutex for sharing data between goroutines?"
    answer: "Use channels for passing ownership and communication, mutex for protecting shared state accessed by multiple goroutines. Channels (communication): (1) Passing data: job queue, results collection. (2) Signaling events: done, cancel. (3) Ownership transfer: send data to another goroutine, sender doesn't access after. Example: jobs := make(chan Work); go worker(jobs); jobs <- work—worker owns work now. Go proverb: 'Share memory by communicating'. Benefits: clear ownership, prevents races by design. Mutex (shared state): (1) Multiple goroutines read/write same struct. (2) Short critical sections (update counter, modify cache). (3) No ownership transfer. Example: type Cache struct { mu sync.RWMutex; data map[string]string }; func (c *Cache) Get(k string) string { c.mu.RLock(); defer c.mu.RUnlock(); return c.data[k] }. Benefits: lower overhead, simpler for local state. Decision matrix: (1) Ownership transfer → channel. (2) Shared state with quick access → mutex. (3) Producer-consumer → channel. (4) Protecting data structure → mutex. (5) Fan-out/fan-in pattern → channel. Performance: mutex is faster for low contention (<5 goroutines), channels better for coordination. Don't: use channel as mutex replacement (anti-pattern: ch := make(chan bool, 1) as lock). Best practice: prefer channels for architecture (components communicate), mutex for implementation (protect struct internals). Start with channels, optimize to mutex if profiling shows bottleneck."
  - question: "How many goroutines is too many, and how do I limit concurrency?"
    answer: "Each goroutine uses ~2KB stack initially (grows to 1GB max)—10k goroutines = ~20MB, 1M goroutines = ~2GB. Limit based on workload: CPU-bound (limit to GOMAXPROCS), I/O-bound (100s-1000s ok), unbounded (memory leak risk). Problems with too many: (1) Memory exhaustion—1M goroutines crashes on 8GB RAM. (2) Scheduler overhead—context switching thrashes. (3) Resource exhaustion—file descriptors, connections. (4) Difficult debugging—stack traces overwhelming. Limiting patterns: (1) Worker pool: jobs := make(chan Work, 100); for i := 0; i < numWorkers; i++ { go worker(jobs) }—fixed goroutines, unbounded jobs. (2) Semaphore: sem := make(chan struct{}, maxConcurrency); before work: sem <- struct{}{}; defer func() { <-sem }()—blocks when limit reached. (3) errgroup with SetLimit: g.SetLimit(10); for _, item := range items { g.Go(func() { process(item) }) }—manages lifecycle. (4) Rate limiting: limiter := rate.NewLimiter(10, 100); limiter.Wait(ctx)—controls starts/sec. Sizing: (1) CPU-bound work: runtime.NumCPU() goroutines. (2) I/O-bound: start with 100, benchmark, tune. (3) External API calls: respect rate limits (e.g., 10 concurrent). Monitor: runtime.NumGoroutine() for live count—if growing unbounded, leak exists. Production: always bound concurrency—for range items: goroutine() is dangerous without limit. Tool: go tool pprof http://localhost:6060/debug/pprof/goroutine shows goroutine count and stacks."
---

One of the most powerful features of Go is its built-in support for concurrency. Go makes it easy to write programs that perform multiple tasks at the same time, thanks to goroutines and channels. Unlike traditional multithreading, Go provides a lightweight and clean way to build concurrent systems with minimal overhead and boilerplate.

In this article, you’ll learn:

*   The difference between concurrency and parallelism
*   What goroutines are and how to use them
*   How channels allow communication between goroutines
*   Buffered vs unbuffered channels
*   The `select` statement
*   Common concurrency problems and how to avoid them
*   Real-world examples and best practices

Concurrency vs Parallelism
--------------------------

Concurrency means doing multiple things at once (interleaved), while parallelism means running them simultaneously on different processors. Go’s concurrency model allows you to write code that is concurrent, and Go’s runtime handles whether it is executed in parallel depending on available CPU cores.

Introducing Goroutines
----------------------

A goroutine is a function that runs concurrently with other functions. You start one by using the `go` keyword:

```go
func sayHello() {
    fmt.Println("Hello from goroutine!")
}

func main() {
    go sayHello()
    fmt.Println("Main function")
} 
```

Goroutines are lightweight and managed by the Go runtime, not the OS. You can spawn thousands of them without major performance issues.

Why You Need to Wait
--------------------

The above example might not print the goroutine output if `main()` exits first. You can fix this using `time.Sleep` or better, `sync.WaitGroup`:

```go
var wg sync.WaitGroup

func sayHi() {
    defer wg.Done()
    fmt.Println("Hi!")
}

func main() {
    wg.Add(1)
    go sayHi()
    wg.Wait()
} 
```

Using Channels
--------------

Channels are used to send and receive values between goroutines. They are typed and provide safe communication.

```go
func main() {
    ch := make(chan string)

    go func() {
        ch <- :="<-ch" code="" essage="" fmt.println="" from="" goroutine="" msg="">
```

Buffered Channels
-----------------

A buffered channel allows sending without blocking, up to its capacity:

```go
ch := make(chan int, 2)
ch <- 1="" 2="" 3="" block="" buffer="" ch="" code="" fmt.println="" full="" if="" is="" this="" will="">
```

Select Statement
----------------

`select` lets you wait on multiple channel operations:

```go
func main() {
    ch1 := make(chan string)
    ch2 := make(chan string)

    go func() {
        time.Sleep(1 * time.Second)
        ch1 <- :="<-ch2:" case="" ch1="" ch2="" code="" fmt.println="" from="" func="" go="" msg1="" msg2="" select="" time.second="" time.sleep="">
```

Common Problems
---------------

*   **Deadlocks**: when goroutines wait forever
*   **Race conditions**: two goroutines access the same variable concurrently

Use `go run -race` to detect race conditions.

Real-World Example: Worker Pool
-------------------------------

```go
func worker(id int, jobs <-chan 2="" 3="" 5="" :="1;" chan="" close="" code="" d="" finished="" fmt.printf="" fmt.println="" for="" func="" go="" id="" int="" j="" job="" jobs="" main="" n="" orker="" r="" results="" started="" time.second="" time.sleep="" w="" worker="">
```

Best Practices
--------------

*   Close channels only when you’re done sending
*   Use `sync.WaitGroup` to wait for goroutines
*   Don’t create unbounded goroutines — may cause memory leaks
*   Use buffered channels to avoid blocking when needed

Conclusion
----------

Goroutines and channels are the foundation of concurrency in Go. With them, you can build scalable and efficient programs without the complexity of traditional multithreading. Start small, experiment with simple patterns, and scale your knowledge step by step.

Next, we'll explore advanced concurrency control using `sync.Mutex`, `sync.Once`, and [context]({{< relref "blog/go/using-context-in-go-cancellation-timeout-and-deadlines-explained.md" >}}) for cancellation and timeouts.

Happy coding!