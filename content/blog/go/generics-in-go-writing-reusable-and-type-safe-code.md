---
title: 'Writing Reusable and Type-Safe Code'
date: 2025-04-25T10:00:00.002+07:00
draft: false
url: /2025/04/generics-in-go-writing-reusable-and-type-safe-code.html
tags: 
- Go
description: "Learn how to use generics in Go to write reusable and type-safe code."
keywords: ["Go", "generics", "type-safe", "reusable", "code", "functions", "types"]
faq:
  - question: "When should I prefer generics over interfaces?"
    answer: "Use generics when you need type-safe operations over multiple concrete types without runtime type assertions. Prefer interfaces when behavior abstraction matters more than data shape, or when you only consume methods."
  - question: "What are type constraints and why are they important?"
    answer: "Constraints define which types are permitted for a type parameter. Use built-in constraints like comparable or define your own interfaces (e.g., type Number interface{ ~int | ~float64 }) to enable operators and restrict usage."
  - question: "Do generics have a runtime performance cost in Go?"
    answer: "In most cases, generic code compiles down efficiently with no significant overhead compared to hand-written versions. Measure with benchmarks to confirm for your workload."
  - question: "How do I create reusable generic utilities?"
    answer: "Put generic helpers in small packages (e.g., slices, maps) with clear constraints. Provide focused operations (Map, Filter, Reduce, Set) and avoid over-generalizing."
  - question: "Can generics lead to over-engineering?"
    answer: "Yes. Start with simple, concrete code. Introduce generics when duplication or unsafe type assertions become a problem, and keep APIs minimal and clear."
  - question: "How do I migrate pre-1.18 code to generics safely?"
    answer: "Refactor incrementally: extract common patterns into generic helpers, add tests before changes, and avoid large rewrites. Ensure API compatibility where external consumers depend on your package."
---

Generics were introduced in Go 1.18, marking a significant evolution of the language. They allow you to write flexible, reusable code without sacrificing type safety. With generics, you can define functions, types, and data structures that work with different types, all while maintaining strong compile-time checks.

In this article, you’ll learn:

*   What generics are and why they matter
*   How to define generic functions and types
*   Type parameters and constraints
*   Real-world examples of generics
*   Best practices when using generics in Go

What Are Generics?
------------------

Generics let you write code that works with different data types while keeping the benefits of static typing. Before generics, developers often used `interface{}` and type assertions to achieve flexibility, but that meant losing compile-time type safety.

Defining a Generic Function
---------------------------

A generic function introduces a type parameter list using square brackets `[]` before the function parameters.

```go
func Print[T any](value T) {
    fmt.Println(value)
} 
```

Here, `T` is a type parameter, and `any` is a constraint (alias for `interface{}`). This function works with any type, like:

```go
Print(10)
Print("Hello")
Print(true) 
```

Using Type Constraints
----------------------

You can limit what types can be passed by using constraints:

```go
type Number interface {
    ~int | ~float64
}

func Sum[T Number](a, b T) T {
    return a + b
} 
```

Now `Sum` can only be called with numeric types.

Generic Types
-------------

You can also define structs or custom types with generics:

```go
type Pair[T any] struct {
    First  T
    Second T
}

func main() {
    p := Pair[string]{"Go", "Lang"}
    fmt.Println(p.First, p.Second)
} 
```

Multiple Type Parameters
------------------------

You can define more than one type parameter:

```go
type Map[K comparable, V any] struct {
    data map[K]V
} 
```

The `comparable` constraint is required for keys in a map (they must support `==`).

Real-World Example: Generic Filter Function
-------------------------------------------

```go
func Filter[T any](items []T, predicate func(T) bool) []T {
    var result []T
    for _, item := range items {
        if predicate(item) {
            result = append(result, item)
        }
    }
    return result
} 
```

Usage:

```go
evens := Filter([]int{1, 2, 3, 4}, func(n int) bool {
    return n%2 == 0
}) 
```

Generics vs Interface{}
-----------------------

Before generics, we often used `interface{}` and did type assertion:

```go
func PrintAny(val interface{}) {
    fmt.Println(val)
} 
```

This works, but doesn’t give compile-time safety or clarity. With generics, you avoid runtime type errors.

Best Practices
--------------

*   Use generics when you write reusable logic (e.g. map, reduce, filter)
*   Don’t overuse -- avoid generics when concrete types are simpler
*   Name type parameters clearly (T, K, V, etc.)
*   Use type constraints to enforce correctness

Conclusion
----------

Generics are a powerful addition to Go that let you write cleaner, more reusable code without giving up type safety. Whether you're building data structures, utility functions, or abstractions, generics help reduce duplication and improve flexibility.

Now that you understand generics, you're ready to explore Go's concurrency model and build high-performance programs using [goroutines]({{< relref "blog/go/concurrency-in-go-goroutines-and-channels-explained.md" >}}) and channels.

Happy coding!
