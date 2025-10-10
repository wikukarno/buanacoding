---
title: 'Measuring Performance with testing.B'
date: 2025-04-24T10:00:00.001+07:00
draft: false
url: /2025/04/benchmarking-in-go-measuring.html
tags:
- Go
description: "Learn how to benchmark Go code using the testing package: writing benchmarks, interpreting results, controlling timers, and best practices."
keywords: ["Go", "benchmark", "testing.B", "performance", "go test", "optimization"]
faq:
  - question: "Why does my benchmark show 0.00 ns/op or unrealistic results?"
    answer: "Compiler optimized away your benchmark code because result isn't used. Go compiler is smart—if computation has no observable effect, it gets eliminated. Fix: assign to package-level variable to prevent optimization: var result int; func BenchmarkAdd(b *testing.B) { var r int; for i := 0; i < b.N; i++ { r = 1 + 2 }; result = r }. Or use testing.B methods that consume result internally. Common mistake: _ = computation() looks like it prevents optimization, but compiler still removes it if result truly unused. Also check: (1) b.N might be too small—run longer with -benchtime=10s. (2) Code is inlined and optimized—use //go:noinline directive to force function call. (3) Warmup needed—first iteration slower, add b.ResetTimer() after setup. Verify benchmark runs actual code: add print statement temporarily, ensure it executes b.N times."
  - question: "When should I use b.ResetTimer() vs b.StopTimer() and b.StartTimer()?"
    answer: "Use b.ResetTimer() to exclude one-time setup that happens before loop. Use b.StopTimer()/b.StartTimer() to exclude per-iteration setup/cleanup. b.ResetTimer(): Call once before loop to zero elapsed time—excludes expensive initialization: data := loadLargeFile(); b.ResetTimer(); for i := 0; i < b.N; i++ { process(data) }. File loading not counted. b.StopTimer()/b.StartTimer(): Pause timer during per-iteration work you want excluded: for i := 0; i < b.N; i++ { b.StopTimer(); setup := createTestData(); b.StartTimer(); actualWork(setup) }. Use sparingly—timer overhead adds noise. Don't: call in tight loops (every nanosecond), timer operations themselves take ~50-100ns. Best practice: prefer b.ResetTimer() when possible, minimize StopTimer/StartTimer calls. If setup is fast (<1% of benchmark time), include it—timer overhead worse than setup cost. Use benchstat tool to compare results and verify timer placement doesn't skew measurements."
  - question: "How do I compare two implementations to see which is faster?"
    answer: "Run both benchmarks and use benchstat for statistical comparison. Simple comparison: go test -bench='BenchmarkV1|BenchmarkV2' -count=10 > old.txt; benchstat old.txt shows which is faster. Better: separate runs to compare versions: (1) Benchmark version 1: go test -bench=. -count=10 > v1.txt. (2) Switch implementation. (3) Benchmark version 2: go test -bench=. -count=10 > v2.txt. (4) Compare: benchstat v1.txt v2.txt shows diff: 'BenchmarkProcess: 150ns → 120ns (−20%)'. Install benchstat: go install golang.org/x/perf/cmd/benchstat@latest. Important: (1) Run -count=10 or more for statistical significance—single run unreliable due to variance. (2) Disable CPU frequency scaling: use performance governor or disable turbo boost. (3) Run on idle machine—other processes skew results. (4) Use -benchmem to compare memory allocations: might be faster but allocates more. (5) Check variance in benchstat output—high variance means unstable benchmark. Pitfall: comparing ns/op directly without statistics gives false positives—differences <5% often just noise."
  - question: "Why do my benchmark results vary so much between runs?"
    answer: "System noise, CPU frequency scaling, garbage collection, or thermal throttling cause variance. Sources: (1) Background processes—OS, browser, other services consume CPU. (2) CPU frequency scaling—CPU runs slower when cool, faster when hot, then throttles. (3) GC pauses—garbage collector runs randomly, adds latency spikes. (4) Memory allocations—different NUMA nodes, cache misses. (5) Kernel scheduler—process moved between cores, cache invalidated. Reduce variance: (1) Run on idle system: close browser, stop services, disable indexing. (2) Disable CPU frequency scaling: Linux: echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor. (3) Fix CPU frequency: disable turbo boost in BIOS. (4) Disable GC during benchmark: runtime.GC(); b.ResetTimer() before loop forces GC first. (5) Pin process to CPU: taskset -c 0 go test -bench=. runs on single core. (6) Run longer: -benchtime=10s gets more samples. (7) Use -count=10: average over multiple runs. Acceptable variance: <5% good, >10% investigate. Use benchstat to see variance in output. Production: measure in production environment, not laptop—server variance different from desktop."
  - question: "How do I benchmark memory allocations and why does it matter?"
    answer: "Use -benchmem flag to show allocations per operation. Memory matters because: (1) Allocations slow code—malloc is expensive. (2) GC pressure—more allocations trigger GC more often, causing pauses. (3) Cache efficiency—fewer allocations mean better CPU cache usage. Run: go test -bench=. -benchmem shows: BenchmarkProcess-8 1000000 1500 ns/op 240 B/op 3 allocs/op. Means: 240 bytes allocated, 3 allocations per operation. Optimize allocations: (1) Preallocate slices: make([]int, 0, 1000) instead of append repeatedly. (2) Reuse objects: sync.Pool for temporary objects. (3) Use stack allocation: pass values not pointers for small structs. (4) Reduce string concatenation: strings.Builder instead of +=. Compare: before: 240 B/op 3 allocs/op, after: 0 B/op 0 allocs/op = perfect (no heap allocations). Escape analysis: go build -gcflags='-m' shows what escapes to heap. Goal: 0 allocs/op for hot paths—allocation-free is fastest. Trade-off: sometimes allocating is clearer than complex pooling, profile first before optimizing."
  - question: "What's the difference between -benchtime=10s and -count=10?"
    answer: "-benchtime controls how long each benchmark runs, -count controls how many times entire benchmark repeats. -benchtime=10s: Run single benchmark for 10 seconds total, Go adjusts b.N to fill time—if operation is fast, b.N might be billions. Result: single measurement from long run, good for stable measurement but masks variance. -count=10: Run benchmark 10 times from scratch, each run determines own b.N—might run different number of iterations. Result: 10 separate measurements, shows variance across runs, required for benchstat statistical comparison. Use both: go test -bench=. -benchtime=3s -count=10 runs each benchmark for 3 seconds, 10 times—balances run length and variance detection. When to use: (1) Quick check: -benchtime=1s (default) is fine. (2) Stable measurement: -benchtime=10s for single authoritative result. (3) Statistical comparison: -count=10 minimum for benchstat. (4) Variance analysis: -count=20 for high-variance benchmarks. (5) Quick iteration: -benchtime=100ms -count=3 during development. Production: -benchtime=5s -count=10 good default for CI/CD. Don't: -benchtime=100ms -count=1 (unreliable), or -benchtime=60s -count=50 (wastes time). Tip: use -benchtime=1000000x to run exactly 1 million iterations regardless of time."
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
