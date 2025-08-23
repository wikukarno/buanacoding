---
title: 'Using Context in Go: Cancellation, Timeout, and Deadlines Explained'
date: 2025-04-27T10:00:00.004+07:00
draft: false
url: /2025/04/using-context-in-go-cancellation.html
tags: 
- Go
description: "Learn how to use the context package in Go for cancellation, timeouts, and deadlines."
keywords: ["Go", "context", "cancellation", "timeout", "deadlines", "goroutines"]
---

As your Go applications become more concurrent and complex, you'll need a way to manage the lifecycle of your goroutines—especially when you want to cancel them, set timeouts, or propagate deadlines. This is where the `context` package comes in. It's the idiomatic way in Go to control concurrent processes gracefully and reliably.

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

*   Not deferring `cancel()` → memory leak
*   Ignoring `ctx.Err()` → silent failure
*   Passing nil context or using `context.TODO()` in production

Conclusion
----------

Understanding `context` is essential for writing responsive, well-behaved concurrent programs in Go. Whether you're managing goroutines, dealing with timeouts, or handling request chains in a web server, context gives you the tools to do it cleanly and safely.

Next, we'll cover `sync.Mutex` and other tools for [synchronizing]({{< relref "blog/go/synchronizing-goroutines-in-go-using-syncmutex-and-synconce.md" >}}) data between goroutines.

Happy coding!