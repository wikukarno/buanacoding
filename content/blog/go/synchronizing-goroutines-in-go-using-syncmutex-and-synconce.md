---
title: 'Using sync.Mutex and sync.Once'
date: 2025-04-28T10:00:00.002+07:00
draft: false
url: /2025/04/synchronizing-goroutines-in-go-using.html
tags: 
- Go
description: "Learn how to synchronize goroutines in Go using sync.Mutex, sync.RWMutex, and sync.Once."
keywords: ["Go", "synchronization", "goroutines", "sync.Mutex", "sync.RWMutex", "sync.Once", "concurrency"]
faq:
  - question: "When should I use sync.Mutex vs channels?"
    answer: "Use Mutex/RWMutex to protect shared memory where operations are simpler with direct locking. Use channels to communicate ownership or to pipeline work. Prefer the simplest approach that keeps code readable and safe."
  - question: "What are common ways to avoid deadlocks?"
    answer: "Lock in a consistent order, hold locks for the shortest time, avoid calling into code that may try to acquire the same lock, and consider try-lock patterns or redesign to reduce lock contention."
  - question: "When is sync.RWMutex appropriate?"
    answer: "When reads vastly outnumber writes and you need concurrent readers. Measure before switching; RWMutex can be slower than Mutex under contention."
  - question: "What are typical use cases for sync.Once?"
    answer: "One-time initialization (e.g., loading config, setting up singletons) in concurrent contexts. It guarantees the function runs exactly once across goroutines."
  - question: "How do I protect maps across goroutines?"
    answer: "Use a Mutex/RWMutex around all accesses, use sync.Map for specific patterns (rare writes, frequent reads), or encapsulate the map behind methods that handle synchronization."
  - question: "How do I test for data races?"
    answer: "Run tests with the -race flag: go test -race ./... This detects unsynchronized access patterns at runtime and helps validate your locking strategy."
---

When you write concurrent programs in Go, multiple goroutines may try to access and modify the same data at the same time. Without proper synchronization, this leads to race conditions, bugs, or crashes. Go provides tools like `sync.Mutex`, `sync.RWMutex`, and `sync.Once` to safely share data across goroutines.

In this article, you’ll learn:

*   What race conditions are and how to avoid them
*   How to use `sync.Mutex` to protect data
*   Using `sync.RWMutex` for read-write access
*   How `sync.Once` ensures code runs only once
*   Real-world examples and best practices

What Is a Race Condition?
-------------------------

A race condition happens when two or more goroutines access the same variable at the same time, and at least one of them is modifying it. This can cause unexpected behavior or corrupted data.

You can detect race conditions using:

```go
go run -race main.go
```

Using sync.Mutex
----------------

`sync.Mutex` is a mutual exclusion lock. Only one goroutine can hold the lock at a time. Use `Lock()` before accessing shared data, and `Unlock()` after.

```go
type Counter struct {
    mu    sync.Mutex
    value int
}

func (c *Counter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.value++
}

func (c *Counter) Value() int {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.value
} 
```

Using sync.RWMutex
------------------

`sync.RWMutex` allows multiple readers or one writer. It's useful when reads are frequent but writes are rare.

```go
type SafeMap struct {
    mu  sync.RWMutex
    m   map[string]string
}

func (s *SafeMap) Get(key string) string {
    s.mu.RLock()
    defer s.mu.RUnlock()
    return s.m[key]
}

func (s *SafeMap) Set(key, value string) {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.m[key] = value
} 
```

Using sync.Once
---------------

`sync.Once` guarantees that a piece of code is only executed once, even if called from multiple goroutines. This is commonly used to initialize shared resources.

```go
var once sync.Once

func initialize() {
    fmt.Println("Initialization done")
}

func main() {
    for i := 0; i < 5; i++ {
        go func() {
            once.Do(initialize)
        }()
    }
    time.Sleep(time.Second)
} 
```

Real-World Example: Safe Counter
--------------------------------

```go
type SafeCounter struct {
    mu sync.Mutex
    val int
}

func (sc *SafeCounter) Add() {
    sc.mu.Lock()
    sc.val++
    sc.mu.Unlock()
}

func main() {
    var sc SafeCounter
    var wg sync.WaitGroup

    for i := 0; i < 1000; i++ {
        wg.Add(1)
        go func() {
            sc.Add()
            wg.Done()
        }()
    }

    wg.Wait()
    fmt.Println("Final count:", sc.val)
} 
```

Best Practices
--------------

*   Always use `defer Unlock()` right after `Lock()`
*   Keep the locked section as short as possible
*   Use `RWMutex` when many goroutines only need to read
*   Use `sync.Once` to initialize global/shared data
*   Test with `go run -race` to catch race conditions

Conclusion
----------

Synchronization is key to building correct concurrent programs. By using `sync.Mutex`, `sync.RWMutex`, and `sync.Once`, you can ensure that your goroutines work together safely without corrupting shared data.

Happy coding!
