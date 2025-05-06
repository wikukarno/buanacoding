---
title: 'Concurrency in Go: Goroutines and Channels Explained'
date: 2025-04-26T10:00:00.003+07:00
draft: false
url: /2025/04/concurrency-in-go-goroutines-and.html
tags: 
- Go
description: 'Learn how to use goroutines and channels in Go for concurrent programming. Understand the differences between concurrency and parallelism, and explore real-world examples.'
keywords: [
    "Go", "concurrency", "goroutines", "channels", "programming", "sync", "parallelism", "best practices"]
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

Next, we'll explore advanced concurrency control using `sync.Mutex`, `sync.Once`, and [context](https://www.buanacoding.com/blog/using-context-in-go-cancellation.html) for cancellation and timeouts.

Happy coding!