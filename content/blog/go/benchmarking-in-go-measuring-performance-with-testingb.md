---
title: 'Measuring Performance with testing.B'
date: 2025-04-24T10:00:00.001+07:00
draft: false
url: /2025/04/benchmarking-in-go-measuring.html
tags: 
- Go
description: "Learn how to benchmark Go code using the testing package: writing benchmarks, interpreting results, controlling timers, and best practices."
keywords: ["Go", "benchmark", "testing.B", "performance", "go test", "optimization"]
---

Benchmarking is the process of measuring the performance of code. In Go, benchmarking is built into the standard `testing` package, making it easy to test how fast your functions run. Whether you're comparing two algorithms, optimizing critical sections of code, or experimenting with concurrency, benchmarking helps you make informed decisions.

This article will walk you through:

*   What is benchmarking and why it matters
*   How to write benchmark functions in Go
*   Interpreting benchmark results
*   Using `b.ResetTimer()`, `b.StopTimer()`, and `b.StartTimer()`
*   Common use cases for benchmarking
*   Best practices for writing meaningful benchmarks

Why Benchmarking is Important
-----------------------------

Benchmarking allows you to evaluate performance based on data, not assumptions. You can compare the execution time of different code versions, measure improvements, and catch performance regressions early. This is crucial for optimizing critical parts of applications such as sorting, searching, or processing large datasets.

Writing Your First Benchmark
----------------------------

Just like test functions in Go, benchmark functions are placed in a file ending with `_test.go`. Benchmark functions must start with `Benchmark` and have this signature:

```go
func BenchmarkXxx(b *testing.B)
```

Example:

```go
func BenchmarkAdd(b *testing.B) {
    for i := 0; i < b.N; i++ {
        _ = 1 + 2
    }
}
```

Go runs this loop repeatedly to get a stable measurement. The `b.N` is automatically adjusted to get an accurate average runtime.

Running Benchmarks
------------------

To run all benchmarks in a package, use:

```go
go test -bench=.
```

To run a specific benchmark:

```go
go test -bench=BenchmarkAdd
```

You’ll see output like this:

```go
BenchmarkAdd-8   1000000000   0.25 ns/op
```

*   `-8` means 8 logical CPUs used
*   `1000000000` is how many times it ran
*   `0.25 ns/op` is time per operation

Controlling Timers
------------------

You can use `b.StopTimer()` and `b.StartTimer()` to exclude setup code:

```go
func BenchmarkWithSetup(b *testing.B) {
    data := make([]int, 1000)
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _ = process(data)
    }
} 
```

Comparing Implementations
-------------------------

Let’s say you want to compare two ways to concatenate strings:

```go
func BenchmarkConcatPlus(b *testing.B) {
    for i := 0; i < b.N; i++ {
        _ = "hello" + " " + "world"
    }
}

func BenchmarkConcatSprintf(b *testing.B) {
    for i := 0; i < b.N; i++ {
        _ = fmt.Sprintf("%s %s", "hello", "world")
    }
} 
```

This helps you choose the faster approach in performance-critical sections.

Best Practices
--------------

*   Keep benchmarks small and focused on a single operation
*   Avoid external dependencies (e.g., file I/O, network)
*   Isolate logic you're testing to avoid side effects
*   Use `go test -bench` with `-count` for averaging over multiple runs

Conclusion
----------

Benchmarking in Go is simple but powerful. It helps you write better-performing programs by providing real measurements instead of guesses. Combined with testing, it becomes a critical part of writing production-ready software.

Happy benchmarking!
