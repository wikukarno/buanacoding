---
title: "How to Profile and Optimize Go Applications with pprof"
description: "Complete guide to profiling and optimizing Go applications using pprof. Learn CPU profiling, memory profiling, goroutine analysis, and performance optimization techniques for production Go applications."
date: 2025-10-06T10:00:00+07:00
draft: false
url: /2025/10/how-to-profile-and-optimize-go-applications-with-pprof.html
tags:
    - Go
    - Performance
    - Profiling
    - Optimization
    - pprof
    - Backend
    - Tutorial
keywords: ["go profiling", "pprof tutorial", "golang performance optimization", "cpu profiling go", "memory profiling golang", "goroutine leak detection", "go performance tuning", "pprof analysis", "golang optimization", "go memory leak"]
schema: "Article"
author: "BuanaCoding"
datePublished: "2025-10-06"
dateModified: "2025-10-06"

faq:
  - question: "What is pprof and why should I use it for Go applications?"
    answer: "pprof is Go's built-in profiling tool that helps you identify performance bottlenecks in your applications. It analyzes CPU usage, memory allocations, goroutine behavior, and blocking operations. Using pprof is essential because it gives you data-driven insights into what's actually slowing down your application, rather than guessing. It shows exactly which functions consume the most CPU time, which allocations cause memory issues, and where goroutine leaks occur."

  - question: "How do I enable pprof in my Go application?"
    answer: "For HTTP servers, import net/http/pprof and it automatically registers handlers at /debug/pprof/. For standalone programs, use runtime/pprof to create profile files programmatically. In production, you can expose pprof on a separate port for security. The setup is just a few lines of code - import the package and optionally start an HTTP server on a different port dedicated to profiling endpoints."

  - question: "What's the difference between CPU profiling and memory profiling?"
    answer: "CPU profiling shows where your program spends execution time - which functions are slow and consume CPU cycles. Memory profiling shows allocation patterns - which code allocates the most memory and potential memory leaks. CPU profiles help optimize computation speed, while memory profiles help reduce allocation overhead and fix memory leaks. You often need both to get a complete performance picture."

  - question: "How do I fix goroutine leaks detected by pprof?"
    answer: "First, use the goroutine profile to identify where goroutines are stuck. Look for goroutines waiting on channels, waiting for locks, or sleeping indefinitely. Common fixes include: adding timeouts to channel operations, ensuring all spawned goroutines have proper exit conditions, using context for cancellation, and cleaning up goroutines when they're no longer needed. Always ensure channels are closed properly and goroutines aren't blocked forever on channel sends or receives."

  - question: "Can I use pprof in production safely?"
    answer: "Yes, but with precautions. Enable pprof on a separate port that's not publicly accessible, use authentication middleware if needed, and be aware that profiling adds overhead. CPU profiling typically adds 5-10% overhead, memory profiling less. Don't run profiles continuously - only when investigating issues. Consider using tools like continuous profiling platforms that sample periodically with minimal impact. Never expose pprof endpoints to the public internet without authentication."

  - question: "What is alloc_space vs inuse_space in memory profiles?"
    answer: "alloc_space shows total memory allocated over the program's lifetime, including memory that's been freed. inuse_space shows memory currently in use. Use alloc_space to find functions that allocate frequently (even if they free memory), which can cause GC pressure. Use inuse_space to find memory leaks where allocations aren't being freed. High alloc_space but low inuse_space means lots of temporary allocations - optimize by reusing objects or using sync.Pool."

  - question: "How do I interpret flame graphs from pprof?"
    answer: "Flame graphs visualize where your program spends time. Width represents the proportion of time spent in that function and its children. The bottom shows the call stack, top shows leaf functions. Look for wide bars at the top - these are hot spots consuming significant CPU. Follow the stack down to understand the call path. Compare flame graphs before and after optimization to verify improvements. Red/warm colors often indicate hot paths, though this depends on the visualization tool."
---


Your Go application is slow. Requests take too long, memory usage keeps climbing, or CPU maxes out under load. You need answers, not guesses. That's where pprof comes in.

pprof is Go's built-in profiler that shows you exactly what's happening inside your running application. It tells you which functions eat CPU cycles, which code paths allocate tons of memory, where goroutines get stuck, and what's blocking your program. With this data, you stop guessing and start fixing real bottlenecks.

This guide covers everything about profiling Go applications - from basic CPU and memory profiling to advanced techniques like detecting goroutine leaks, analyzing mutex contention, and optimizing production systems. You'll learn how to collect profiles, interpret the data, and actually make your Go code faster.

## Why Profiling Matters

Performance optimization without profiling is like trying to fix a car engine while blindfolded. You might get lucky, but probably you'll waste time on things that don't matter.

I've seen developers spend days optimizing algorithms that account for 0.1% of runtime while the real bottleneck was a goroutine leak causing memory to balloon. Profiling would've shown this in 5 minutes.

**What profiling gives you:**

Real data on where time is spent - not assumptions but actual measurements of CPU usage per function.

Memory allocation patterns - see which code creates garbage that the GC has to clean up constantly.

Concurrency issues - find goroutine leaks, deadlocks, and excessive context switching.

Production insights - understand how your app behaves with real traffic, not just synthetic benchmarks.

Go makes profiling easy. The tools are built-in, the overhead is manageable, and the insights are actionable. If your Go app has performance issues, profiling is always the first step.

## Understanding pprof Basics

pprof is Go's profiling tool. It collects runtime data about your program and presents it in various formats for analysis.

### Types of Profiles

**CPU Profile** - Shows where your program spends CPU time. Samples the call stack periodically (default 100 times per second) to build a picture of hot code paths.

**Heap Profile** - Shows memory allocations. Two views: allocations over time (alloc_space) and currently allocated memory (inuse_space).

**Goroutine Profile** - Lists all goroutines and their current state. Essential for finding goroutine leaks and understanding concurrency behavior.

**Block Profile** - Shows where goroutines block on synchronization primitives like channels and mutexes.

**Mutex Profile** - Shows contention on mutexes. Helps identify lock contention issues in concurrent code.

**Thread Create Profile** - Shows where the runtime creates OS threads. Useful for diagnosing excessive thread creation.

Each profile type reveals different performance aspects. CPU and heap profiling are most common, but goroutine profiling is crucial for concurrent Go programs.

### How pprof Works

pprof uses sampling, not instrumentation. It periodically checks what your program is doing rather than tracking every operation. This keeps overhead low - typically 5-10% for CPU profiling.

For CPU profiling, the Go runtime interrupts your program 100 times per second and records the call stack. After collecting thousands of samples, you get a statistical picture of where time is spent.

Memory profiling tracks allocations but samples them (by default, one sample per 512KB allocated). This means you see the big allocators, not every tiny allocation.

The sampling approach makes pprof suitable for production use, unlike some profilers that add 50-100% overhead.

## Setting Up pprof in Your Application

Getting pprof running is straightforward. Go provides two main ways: automatic HTTP endpoints for servers, and programmatic profiling for any application.

### HTTP Server Setup

For web applications or services with HTTP endpoints, pprof integration is one import away.

```go
package main

import (
    "log"
    "net/http"
    _ "net/http/pprof"
)

func main() {
    // Your HTTP handlers
    http.HandleFunc("/", homeHandler)
    http.HandleFunc("/api/data", dataHandler)

    // pprof automatically registers at /debug/pprof/
    log.Println("Server starting on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
    w.Write([]byte("Hello World"))
}

func dataHandler(w http.ResponseWriter, r *http.Request) {
    // Some API logic
    w.Write([]byte("Data response"))
}
```

The blank import `_ "net/http/pprof"` registers handlers automatically. Now you can access:

- `http://localhost:8080/debug/pprof/` - Index page with all profiles
- `http://localhost:8080/debug/pprof/profile` - 30-second CPU profile
- `http://localhost:8080/debug/pprof/heap` - Heap profile
- `http://localhost:8080/debug/pprof/goroutine` - Goroutine dump

### Separate pprof Port (Production Pattern)

In production, don't expose pprof on your main service port. Use a separate port restricted to internal access.

```go
package main

import (
    "log"
    "net/http"
    _ "net/http/pprof"
)

func main() {
    // Main application server
    go func() {
        mux := http.NewServeMux()
        mux.HandleFunc("/", homeHandler)
        mux.HandleFunc("/api/data", dataHandler)

        log.Println("Application server on :8080")
        log.Fatal(http.ListenAndServe(":8080", mux))
    }()

    // Separate pprof server on different port
    go func() {
        log.Println("pprof server on :6060")
        log.Fatal(http.ListenAndServe(":6060", nil))
    }()

    // Block forever
    select {}
}
```

Now pprof runs on port 6060. Configure your firewall to only allow internal access to this port. Your application on port 8080 has no profiling endpoints exposed.

### Programmatic Profiling

For non-HTTP applications or when you want control over when profiling happens, use the `runtime/pprof` package directly.

```go
package main

import (
    "log"
    "os"
    "runtime"
    "runtime/pprof"
    "time"
)

func main() {
    // CPU profiling
    f, err := os.Create("cpu.prof")
    if err != nil {
        log.Fatal(err)
    }
    defer f.Close()

    if err := pprof.StartCPUProfile(f); err != nil {
        log.Fatal(err)
    }
    defer pprof.StopCPUProfile()

    // Your application logic
    doWork()

    // Memory profiling
    mf, err := os.Create("mem.prof")
    if err != nil {
        log.Fatal(err)
    }
    defer mf.Close()

    runtime.GC() // Get up-to-date statistics
    if err := pprof.WriteHeapProfile(mf); err != nil {
        log.Fatal(err)
    }
}

func doWork() {
    // Simulate work
    for i := 0; i < 1000000; i++ {
        _ = make([]byte, 1024)
        time.Sleep(time.Microsecond)
    }
}
```

This creates `cpu.prof` and `mem.prof` files you can analyze with the pprof tool.

## CPU Profiling: Finding Performance Bottlenecks

CPU profiling reveals where your program spends execution time. This is usually your first step when optimizing performance.

### Collecting a CPU Profile

From an HTTP endpoint:

```bash
# Collect 30-second CPU profile
curl http://localhost:6060/debug/pprof/profile?seconds=30 > cpu.prof
```

The `seconds` parameter controls profile duration. 30 seconds is typical - long enough to capture representative behavior but not too long if you're in a hurry.

From code:

```go
import (
    "os"
    "runtime/pprof"
)

f, _ := os.Create("cpu.prof")
pprof.StartCPUProfile(f)
defer pprof.StopCPUProfile()

// Run code you want to profile
doExpensiveOperation()
```

### Analyzing CPU Profiles

Basic analysis with `go tool pprof`:

```bash
go tool pprof cpu.prof
```

This opens an interactive shell. Common commands:

**top** - Show top functions by CPU usage:

```
(pprof) top
Showing nodes accounting for 2840ms, 94.67% of 3000ms total
Dropped 45 nodes (cum <= 15ms)
      flat  flat%   sum%        cum   cum%
    1200ms 40.00% 40.00%     1200ms 40.00%  runtime.mallocgc
     800ms 26.67% 66.67%      800ms 26.67%  main.processData
     400ms 13.33% 80.00%      600ms 20.00%  main.calculateHash
     240ms  8.00% 88.00%      240ms  8.00%  runtime.memmove
     200ms  6.67% 94.67%      200ms  6.67%  crypto/sha256.block
```

**flat** - Time spent in the function itself
**cum** - Cumulative time (function + everything it calls)

**list <function>** - Show source code with time attribution:

```
(pprof) list main.processData
Total: 3s
ROUTINE ======================== main.processData
     800ms      800ms (flat, cum) 26.67% of Total
         .          .     15:func processData(data []byte) {
         .          .     16:    for i := 0; i < len(data); i++ {
     200ms      200ms     17:        result := data[i] * 2
     400ms      400ms     18:        hash := calculateHash(result)
     200ms      200ms     19:        store(hash)
         .          .     20:    }
         .          .     21:}
```

**web** - Generate a call graph visualization (requires Graphviz):

```bash
go tool pprof -http=:8081 cpu.prof
```

Opens a browser with an interactive flame graph and call graph.

### Interpreting CPU Profile Data

High `flat` time means the function itself is slow - look for inefficient algorithms or unnecessary work.

High `cum` but low `flat` time means the function calls other slow functions - drill down into the call tree.

`runtime.mallocgc` appearing at the top often indicates excessive allocations - switch to a heap profile to see what's allocating.

### Real Example: Optimizing a Slow Function

Found this in a profile:

```
2400ms  80.00%  main.findUser
```

Listing the function:

```go
func findUser(users []User, id int) *User {
    for _, u := range users {
        if u.ID == id {
            return &u  // Problem: returns address of loop variable
        }
    }
    return nil
}
```

The issue isn't obvious from profiling alone, but profiling showed this function was the bottleneck. Investigation revealed it was called millions of times. The fix:

```go
// Build a map once
var userMap = make(map[int]*User)

func init() {
    for i := range users {
        userMap[users[i].ID] = &users[i]
    }
}

func findUser(id int) *User {
    return userMap[id]  // O(1) instead of O(n)
}
```

Profile after optimization showed `findUser` dropped from 80% to <1% of CPU time.

## Memory Profiling: Hunting Allocations and Leaks

Memory issues come in two flavors: too many allocations causing GC pressure, and memory leaks where allocations never get freed. pprof's heap profiling catches both.

### Collecting Heap Profiles

From HTTP:

```bash
# Current heap (inuse_space)
curl http://localhost:6060/debug/pprof/heap > heap.prof

# All allocations (alloc_space)
curl http://localhost:6060/debug/pprof/heap?alloc_space=1 > alloc.prof
```

From code:

```go
import (
    "os"
    "runtime"
    "runtime/pprof"
)

runtime.GC() // Get current statistics
f, _ := os.Create("heap.prof")
pprof.WriteHeapProfile(f)
f.Close()
```

### Analyzing Heap Profiles

```bash
go tool pprof heap.prof
```

By default, you see `inuse_space` - memory currently allocated:

```
(pprof) top
Showing nodes accounting for 512MB, 98.46% of 520MB total
      flat  flat%   sum%        cum   cum%
     256MB 49.23% 49.23%      256MB 49.23%  main.loadConfig
     128MB 24.62% 73.85%      128MB 24.62%  main.cacheData
      64MB 12.31% 86.15%       64MB 12.31%  encoding/json.Unmarshal
      32MB  6.15% 92.31%       32MB  6.15%  io/ioutil.ReadAll
```

Switch to `alloc_space` to see all allocations:

```bash
go tool pprof -alloc_space heap.prof
```

Or:

```
(pprof) sample_index = alloc_space
(pprof) top
```

### inuse_space vs alloc_space

**inuse_space** - Memory currently in use. High values indicate memory leaks or objects that should be freed but aren't.

**alloc_space** - Total memory allocated (including freed memory). High values with low inuse_space indicate excessive temporary allocations causing GC overhead.

**inuse_objects** and **alloc_objects** - Same but counting objects instead of bytes.

### Finding Memory Leaks

Memory leak symptoms: inuse_space grows over time without bound.

Collect multiple heap profiles over time:

```bash
# Profile 1
curl http://localhost:6060/debug/pprof/heap > heap1.prof

# Wait 10 minutes, let app run
sleep 600

# Profile 2
curl http://localhost:6060/debug/pprof/heap > heap2.prof
```

Compare:

```bash
go tool pprof -base heap1.prof heap2.prof
```

This shows allocations that happened between the two profiles. If certain allocations keep growing, that's your leak.

### Example: Fixing a Memory Leak

Profile showed:

```
(pprof) top
     2GB  main.(*Cache).Get
```

The source:

```go
type Cache struct {
    data map[string][]byte
}

func (c *Cache) Get(key string) []byte {
    if val, ok := c.data[key]; ok {
        return val
    }

    // Fetch from database
    val := db.Query(key)
    c.data[key] = val  // Leak: never removed
    return val
}
```

The cache grows forever. Fix with expiration:

```go
type CacheEntry struct {
    data      []byte
    expiresAt time.Time
}

type Cache struct {
    data map[string]CacheEntry
    mu   sync.RWMutex
}

func (c *Cache) Get(key string) []byte {
    c.mu.RLock()
    if entry, ok := c.data[key]; ok && time.Now().Before(entry.expiresAt) {
        c.mu.RUnlock()
        return entry.data
    }
    c.mu.RUnlock()

    val := db.Query(key)

    c.mu.Lock()
    c.data[key] = CacheEntry{
        data:      val,
        expiresAt: time.Now().Add(5 * time.Minute),
    }
    c.mu.Unlock()

    return val
}

func (c *Cache) CleanupExpired() {
    c.mu.Lock()
    defer c.mu.Unlock()

    now := time.Now()
    for k, entry := range c.data {
        if now.After(entry.expiresAt) {
            delete(c.data, k)
        }
    }
}
```

Add periodic cleanup:

```go
go func() {
    ticker := time.NewTicker(1 * time.Minute)
    for range ticker.C {
        cache.CleanupExpired()
    }
}()
```

Memory usage stabilized after the fix.

### Reducing Allocations

High `alloc_space` but manageable `inuse_space` means lots of temporary allocations. The GC constantly cleans up garbage, which burns CPU.

Common fixes:

**Reuse buffers** - Instead of allocating new slices/buffers each time, reuse them:

```go
// Before: allocates every call
func processData(data []byte) []byte {
    buf := make([]byte, len(data)*2)
    // process...
    return buf
}

// After: reuse buffer pool
var bufPool = sync.Pool{
    New: func() interface{} {
        return make([]byte, 4096)
    },
}

func processData(data []byte) []byte {
    buf := bufPool.Get().([]byte)
    defer bufPool.Put(buf)

    if cap(buf) < len(data)*2 {
        buf = make([]byte, len(data)*2)
    }
    buf = buf[:len(data)*2]

    // process...
    return buf
}
```

**Preallocate slices** - If you know the size, preallocate:

```go
// Before
var results []Result
for _, item := range items {
    results = append(results, process(item))
}

// After
results := make([]Result, 0, len(items))
for _, item := range items {
    results = append(results, process(item))
}
```

**Avoid string concatenation in loops**:

```go
// Before: allocates new string each iteration
var s string
for i := 0; i < 1000; i++ {
    s += fmt.Sprintf("%d,", i)
}

// After: use strings.Builder
var b strings.Builder
for i := 0; i < 1000; i++ {
    fmt.Fprintf(&b, "%d,", i)
}
s := b.String()
```

## Goroutine Profiling: Finding Leaks and Deadlocks

Goroutines are cheap, so developers spawn them freely. But goroutine leaks - where goroutines never exit - cause memory and CPU waste.

### Collecting Goroutine Profiles

From HTTP:

```bash
curl http://localhost:6060/debug/pprof/goroutine > goroutine.prof
```

From code:

```go
import (
    "os"
    "runtime/pprof"
)

f, _ := os.Create("goroutine.prof")
pprof.Lookup("goroutine").WriteTo(f, 0)
f.Close()
```

### Analyzing Goroutines

```bash
go tool pprof goroutine.prof
```

```
(pprof) top
Showing nodes accounting for 10450, 100% of 10450 total
      flat  flat%   sum%        cum   cum%
     10000 95.69% 95.69%      10000 95.69%  runtime.gopark
       200  1.91% 97.61%        200  1.91%  runtime.goparkunlock
       150  1.44% 99.04%        150  1.44%  time.Sleep
       100  0.96%   100%        100  0.96%  chan receive
```

10,000 goroutines stuck in `runtime.gopark` - that's a problem.

Use `traces` to see what these goroutines are doing:

```
(pprof) traces
File: goroutine.prof
Type: goroutine
Time: Jan 6, 2025 at 3:04pm (WIB)
-----------+-------------------------------------------------------
     10000   runtime.gopark
             runtime.chanrecv
             runtime.chanrecv1
             main.worker
             runtime.goexit
-----------+-------------------------------------------------------
```

All 10,000 goroutines are in `main.worker`, waiting on a channel receive.

### Example: Goroutine Leak

The leaking code:

```go
func processJobs(jobs []Job) {
    for _, job := range jobs {
        go worker(job)  // Spawns goroutine but never waits
    }
}

func worker(job Job) {
    result := make(chan Result)

    go func() {
        r := process(job)
        result <- r  // Blocks forever if nothing receives
    }()

    // Bug: timeout but goroutine still blocked on channel send
    select {
    case r := <-result:
        store(r)
    case <-time.After(5 * time.Second):
        log.Println("timeout")
        return  // Goroutine still blocked on result <- r
    }
}
```

Every timeout leaks a goroutine. With thousands of jobs, goroutines pile up.

Fix with buffered channel:

```go
func worker(job Job) {
    result := make(chan Result, 1)  // Buffered: send won't block

    go func() {
        r := process(job)
        result <- r  // Won't block even if nobody receives
    }()

    select {
    case r := <-result:
        store(r)
    case <-time.After(5 * time.Second):
        log.Println("timeout")
        return
    }
}
```

Or use context for cancellation:

```go
func worker(ctx context.Context, job Job) {
    result := make(chan Result)

    go func() {
        r := process(job)
        select {
        case result <- r:
        case <-ctx.Done():
            return  // Exit if context cancelled
        }
    }()

    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    select {
    case r := <-result:
        store(r)
    case <-ctx.Done():
        log.Println("timeout")
        return
    }
}
```

After fixing, goroutine count stayed stable instead of growing.

### Detecting Goroutine Growth

Monitor goroutine count over time:

```go
import (
    "log"
    "runtime"
    "time"
)

func monitorGoroutines() {
    ticker := time.NewTicker(10 * time.Second)
    for range ticker.C {
        count := runtime.NumGoroutine()
        log.Printf("Current goroutines: %d", count)
    }
}

go monitorGoroutines()
```

If the count keeps climbing, you have a leak. Use goroutine profiling to find where they're stuck.

## Block and Mutex Profiling: Finding Contention

When goroutines fight over shared resources, performance suffers. Block and mutex profiling reveal these bottlenecks.

### Enabling Block Profiling

Block profiling is off by default. Enable it:

```go
import "runtime"

func init() {
    runtime.SetBlockProfileRate(1)  // Record every blocking event
}
```

Or set a sampling rate (record 1 in N events):

```go
runtime.SetBlockProfileRate(1000)  // Sample 1 in 1000 blocks
```

Collect:

```bash
curl http://localhost:6060/debug/pprof/block > block.prof
```

### Enabling Mutex Profiling

```go
import "runtime"

func init() {
    runtime.SetMutexProfileFraction(1)  // Record every mutex contention
}
```

Collect:

```bash
curl http://localhost:6060/debug/pprof/mutex > mutex.prof
```

### Analyzing Contention

```bash
go tool pprof block.prof
```

```
(pprof) top
Showing nodes accounting for 45.5s, 91.00% of 50s total
      flat  flat%   sum%        cum   cum%
      25s 50.00% 50.00%       25s 50.00%  sync.(*Mutex).Lock
      15s 30.00% 80.00%       15s 30.00%  chan send
      5.5s 11.00% 91.00%      5.5s 11.00%  sync.(*WaitGroup).Wait
```

25 seconds blocked on mutex locks - serious contention.

Look at the source:

```
(pprof) list main.updateCounter
Total: 50s
ROUTINE ======================== main.updateCounter
      25s       25s (flat, cum) 50.00% of Total
         .          .     10:var mu sync.Mutex
         .          .     11:var counter int
         .          .     12:
         .          .     13:func updateCounter() {
      25s       25s     14:    mu.Lock()
         .          .     15:    counter++
         .          .     16:    time.Sleep(100 * time.Millisecond)  // Simulate work
         .          .     17:    mu.Unlock()
         .          .     18:}
```

The lock is held for 100ms while doing work. Goroutines queue up waiting.

### Fixing Contention

**Reduce critical section size**:

```go
// Before: lock held during slow operation
func updateCounter() {
    mu.Lock()
    counter++
    doExpensiveWork()  // Holds lock too long
    mu.Unlock()
}

// After: minimize locked time
func updateCounter() {
    mu.Lock()
    counter++
    mu.Unlock()

    doExpensiveWork()  // Outside lock
}
```

**Use atomic operations for simple counters**:

```go
import "sync/atomic"

var counter int64

func updateCounter() {
    atomic.AddInt64(&counter, 1)  // No lock needed
}
```

**Shard locks for high contention**:

```go
// Before: single lock, high contention
type Cache struct {
    mu   sync.RWMutex
    data map[string]string
}

// After: multiple locks, less contention
type Cache struct {
    shards [256]struct {
        mu   sync.RWMutex
        data map[string]string
    }
}

func (c *Cache) Get(key string) string {
    shard := &c.shards[hash(key)%256]
    shard.mu.RLock()
    defer shard.mu.RUnlock()
    return shard.data[key]
}
```

**Use sync.Map for concurrent maps**:

```go
import "sync"

var cache sync.Map

func get(key string) interface{} {
    val, _ := cache.Load(key)
    return val
}

func set(key string, val interface{}) {
    cache.Store(key, val)
}
```

`sync.Map` is optimized for cases where entries are written once and read many times, reducing lock contention.

## Visualizing Profiles with Flame Graphs

Flame graphs make profiles easier to understand visually.

### Generating Flame Graphs

```bash
# Interactive web UI
go tool pprof -http=:8080 cpu.prof
```

Opens browser at http://localhost:8080 with multiple views:

- Top - Table of hottest functions
- Graph - Call graph visualization
- Flame Graph - Flame graph visualization
- Source - Annotated source code

### Reading Flame Graphs

Flame graphs stack function calls vertically. The width represents time spent.

Bottom shows entry points (like `main` or HTTP handlers). Top shows leaf functions where actual work happens.

**Wide bars at the top** - Hot functions consuming significant CPU.

**Tall stacks** - Deep call chains. Not necessarily bad, but watch for unnecessary intermediate calls.

**Color** - Usually meaningless (random) but some tools color by package or type.

### Comparing Profiles

Compare before and after optimization:

```bash
go tool pprof -http=:8080 -base=before.prof after.prof
```

Shows the difference. Positive values are increases (bad if optimizing), negative are decreases (good).

## Production Profiling Strategies

Profiling in production requires care. You want insights without impacting users.

### Continuous Profiling

Instead of ad-hoc profiling when issues occur, collect profiles continuously at low overhead.

**Sampling-based approach**:

```go
import (
    "log"
    "os"
    "runtime/pprof"
    "time"
)

func continuousProfile() {
    ticker := time.NewTicker(5 * time.Minute)
    for range ticker.C {
        // CPU profile for 30 seconds
        f, err := os.Create(fmt.Sprintf("cpu-%d.prof", time.Now().Unix()))
        if err != nil {
            log.Printf("Failed to create profile: %v", err)
            continue
        }

        pprof.StartCPUProfile(f)
        time.Sleep(30 * time.Second)
        pprof.StopCPUProfile()
        f.Close()

        // Upload to storage or profiling service
        uploadProfile(f.Name())
    }
}

go continuousProfile()
```

Every 5 minutes, collect a 30-second CPU profile. This gives you historical performance data.

### Using Profiling Services

Services like Datadog, New Relic, and Pyroscope offer continuous profiling with minimal overhead.

**Pyroscope example**:

```go
import "github.com/pyroscope-io/client/pyroscope"

func init() {
    pyroscope.Start(pyroscope.Config{
        ApplicationName: "myapp",
        ServerAddress:   "http://pyroscope:4040",

        ProfileTypes: []pyroscope.ProfileType{
            pyroscope.ProfileCPU,
            pyroscope.ProfileAllocObjects,
            pyroscope.ProfileAllocSpace,
            pyroscope.ProfileInuseObjects,
            pyroscope.ProfileInuseSpace,
        },
    })
}
```

The service collects profiles periodically and provides a UI for exploration.

### On-Demand Profiling

For troubleshooting specific issues, enable profiling on demand without redeploying.

**Feature flag approach**:

```go
var enableProfiling atomic.Bool

func main() {
    // API to enable profiling
    http.HandleFunc("/admin/profiling/enable", func(w http.ResponseWriter, r *http.Request) {
        enableProfiling.Store(true)
        w.Write([]byte("Profiling enabled"))
    })

    http.HandleFunc("/admin/profiling/disable", func(w http.ResponseWriter, r *http.Request) {
        enableProfiling.Store(false)
        w.Write([]byte("Profiling disabled"))
    })

    // Rest of app
}
```

Conditionally expose pprof:

```go
if enableProfiling.Load() {
    _ = pprof.StartCPUProfile(w)
    defer pprof.StopCPUProfile()
}
```

### Security Considerations

**Never expose pprof to public internet** - Profiling endpoints can leak sensitive data and add attack surface.

**Use separate port** - Run pprof on a different port accessible only internally.

**Add authentication**:

```go
func pprofAuth(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        user, pass, ok := r.BasicAuth()
        if !ok || user != "admin" || pass != os.Getenv("PPROF_PASSWORD") {
            w.Header().Set("WWW-Authenticate", `Basic realm="pprof"`)
            w.WriteHeader(401)
            w.Write([]byte("Unauthorized"))
            return
        }
        next.ServeHTTP(w, r)
    })
}

http.Handle("/debug/pprof/", pprofAuth(http.DefaultServeMux))
```

**Firewall rules** - Restrict access to pprof port at network level.

## Benchmarking with pprof Integration

Go benchmarks integrate with pprof for detailed performance analysis.

### Writing Benchmarks

```go
func BenchmarkProcessData(b *testing.B) {
    data := generateTestData()

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        processData(data)
    }
}
```

### Running with Profiling

```bash
# CPU profile
go test -bench=. -cpuprofile=cpu.prof

# Memory profile
go test -bench=. -memprofile=mem.prof

# Both
go test -bench=. -cpuprofile=cpu.prof -memprofile=mem.prof
```

Analyze:

```bash
go tool pprof cpu.prof
go tool pprof mem.prof
```

### Benchmark Comparison

Compare performance before and after changes:

```bash
# Before optimization
go test -bench=. -cpuprofile=before-cpu.prof > before.txt

# After optimization
go test -bench=. -cpuprofile=after-cpu.prof > after.txt

# Compare results
benchstat before.txt after.txt
```

`benchstat` shows statistical comparison:

```
name            old time/op    new time/op    delta
ProcessData-8     1.25ms ± 2%    0.45ms ± 1%  -64.00%  (p=0.000 n=10+10)

name            old alloc/op   new alloc/op   delta
ProcessData-8     512kB ± 0%     128kB ± 0%  -75.00%  (p=0.000 n=10+10)
```

64% faster and 75% less memory - clear improvement.

Compare profiles:

```bash
go tool pprof -base=before-cpu.prof after-cpu.prof
```

Shows which functions improved.

## Real-World Optimization Case Studies

### Case 1: JSON Parsing Bottleneck

**Problem**: API endpoint taking 500ms per request.

**CPU Profile showed**:

```
(pprof) top
  2800ms  encoding/json.Unmarshal
  1200ms  encoding/json.(*decodeState).object
```

JSON parsing consumed 56% of request time.

**Investigation**: Logging revealed the same JSON was parsed repeatedly for validation.

**Fix**: Cache parsed result:

```go
// Before
func validateRequest(r *http.Request) error {
    var req Request
    json.NewDecoder(r.Body).Decode(&req)  // Parse

    if req.UserID == 0 {
        return errors.New("invalid user")
    }

    var req2 Request
    r.Body.Seek(0, 0)
    json.NewDecoder(r.Body).Decode(&req2)  // Parse again!

    return businessLogic(req2)
}

// After
func validateRequest(r *http.Request) error {
    var req Request
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        return err
    }

    if req.UserID == 0 {
        return errors.New("invalid user")
    }

    return businessLogic(req)  // Reuse parsed data
}
```

**Result**: Latency dropped from 500ms to 220ms - 56% improvement.

### Case 2: Memory Leak in Cache

**Problem**: Application memory growing from 500MB to 8GB over 24 hours.

**Heap profile comparison**:

```bash
go tool pprof -base=heap-morning.prof heap-evening.prof
```

```
(pprof) top
  7.2GB  main.(*SessionCache).Store
```

**Investigation**: Session cache never evicted old entries.

**Fix**: Implemented LRU eviction with max size:

```go
import "github.com/hashicorp/golang-lru"

type SessionCache struct {
    cache *lru.Cache
}

func NewSessionCache() *SessionCache {
    cache, _ := lru.New(10000)  // Max 10k sessions
    return &SessionCache{cache: cache}
}

func (c *SessionCache) Store(id string, session Session) {
    c.cache.Add(id, session)  // Automatically evicts oldest if full
}
```

**Result**: Memory stabilized at 800MB with no growth.

### Case 3: Goroutine Leak in Worker Pool

**Problem**: Application slowing down over time, goroutine count increasing.

**Goroutine profile**:

```
(pprof) top
  45000  runtime.gopark
  45000  main.worker
```

45,000 goroutines stuck in worker function.

**Investigation**: Workers waited on channel that was never closed.

**Fix**: Properly close channel and use WaitGroup:

```go
// Before
func process(jobs <-chan Job) {
    for job := range jobs {
        go worker(job)  // Goroutine never exits
    }
}

// After
func process(jobs <-chan Job) {
    var wg sync.WaitGroup

    for i := 0; i < runtime.NumCPU(); i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for job := range jobs {
                worker(job)
            }
        }()
    }

    wg.Wait()
}
```

**Result**: Goroutine count stayed constant at around 20 (number of CPUs).

## Advanced Profiling Techniques

### Custom Profiles

Create custom profiles for domain-specific metrics:

```go
import "runtime/pprof"

var requestProfile = pprof.NewProfile("requests")

func handleRequest(w http.ResponseWriter, r *http.Request) {
    requestProfile.Add(r, 0)
    defer requestProfile.Remove(r)

    // Handle request
}
```

Dump custom profile:

```go
f, _ := os.Create("requests.prof")
requestProfile.WriteTo(f, 0)
f.Close()
```

### Trace Profiling

Execution traces show detailed timeline of goroutine execution:

```go
import (
    "os"
    "runtime/trace"
)

f, _ := os.Create("trace.out")
trace.Start(f)
defer trace.Stop()

// Run code
```

Analyze:

```bash
go tool trace trace.out
```

Opens browser with interactive timeline showing:

- Goroutine execution
- GC pauses
- Network I/O
- System calls

Useful for understanding concurrency behavior and identifying scheduling issues.

### Differential Profiling

Compare profiles from different versions or configurations:

```bash
go tool pprof -base=v1.prof v2.prof
```

Shows regression or improvement between versions.

## Common Profiling Mistakes

**Profiling debug builds** - Always profile release builds with optimizations enabled. Debug builds have different performance characteristics.

**Too short profiling duration** - 30 seconds minimum for CPU profiles. Shorter durations might miss important behavior.

**Optimizing prematurely** - Profile first, then optimize. Don't assume you know the bottleneck.

**Ignoring the 80/20 rule** - Focus on the top issues. Optimizing functions that take <1% of time won't move the needle.

**Not measuring after changes** - Always profile after optimization to verify improvement. Sometimes "optimizations" make things worse.

**Profiling on laptop** - Production behavior differs from development. Profile in production-like environments.

## Profiling Tools Ecosystem

Beyond pprof, several tools enhance Go profiling:

**benchstat** - Statistical comparison of benchmarks. Essential for validating optimizations.

**Pyroscope** - Continuous profiling platform with UI.

**Datadog Continuous Profiler** - Commercial profiling with APM integration.

**pprof Web UI** - `go tool pprof -http` provides rich visualization.

**Graphviz** - Renders call graphs from pprof.

**Jaeger/Zipkin** - Distributed tracing complements profiling for microservices.

## Integrating Profiling into Development Workflow

Make profiling routine, not reactive:

**1. Benchmark new features** - Write benchmarks for performance-critical code. Run with profiling to catch issues early.

**2. Profile in CI/CD** - Run benchmarks in CI and track metrics over time. Fail builds if performance regresses.

**3. Production monitoring** - Continuous profiling in production catches issues that testing misses.

**4. Performance reviews** - Include performance analysis in code reviews for critical paths.

**5. Document hot paths** - When you optimize code, document why. Future developers will thank you.

## Performance Optimization Principles

Profiling shows where time is spent. Actually fixing issues requires good instincts:

**Algorithm choice matters most** - O(n²) vs O(n log n) beats micro-optimizations.

**Allocations are expensive** - Reducing allocations often gives bigger wins than optimizing CPU-bound code.

**Lock contention kills scalability** - In concurrent programs, contention is usually the bottleneck.

**I/O dominates** - If your app does I/O, optimize I/O first. CPU optimization won't help if you're waiting on network.

**Measure, don't guess** - Your intuition about performance is probably wrong. Let profiling guide you.

## Wrapping Up

pprof gives you x-ray vision into your Go applications. CPU profiles show slow code. Memory profiles reveal leaks and allocation hotspots. Goroutine profiles catch concurrency issues. Block and mutex profiles expose contention.

The process is always the same: collect a profile, analyze the data, identify the bottleneck, fix it, profile again to verify. Repeat until performance is acceptable.

Don't optimize blindly. Profile first. The bottleneck is rarely where you expect. I've seen developers spend weeks optimizing algorithms that accounted for 0.1% of runtime while ignoring goroutine leaks that ate 80% of resources.

Profiling is a skill that improves with practice. The more profiles you analyze, the faster you'll spot patterns. CPU time in `runtime.mallocgc`? Too many allocations. Growing goroutine count? Leak. High block time on mutex? Contention.

Make profiling part of your workflow. Benchmark performance-critical code. Run continuous profiling in production. Include performance in code reviews. Your users will notice the difference.

If you're building [Go microservices](/tags/go/), check out our guides on [building CLI tools](/2025/10/how-to-build-a-cli-tool-in-go-with-cobra-and-viper.html) and [database migrations](/2025/10/how-to-perform-database-migrations-in-go-using-golang-migrate.html) for more Go best practices.
