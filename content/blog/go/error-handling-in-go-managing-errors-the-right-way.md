---
title: 'Error Handling in Go: Managing Errors the Right Way'
date: 2025-04-22T10:00:00.004+07:00
draft: false
url: /2025/04/error-handling-in-go-managing-errors.html
tags: 
- Go
description: "Learn how to handle errors in Go, create custom errors, and understand best practices for error management."
keywords: ["Go", "error", "handling", "custom", "errors", "panic", "recover", "best practices"]
---

Error handling is a core part of Go programming. Unlike many languages that use exceptions, Go takes a more straightforward and explicit approach. In Go, functions often return an error as the last return value, and it's the developer’s job to check and handle it. This method may seem verbose at first, but it leads to more robust and predictable code.

In this article, you'll learn:

*   What an error is in Go
*   How to handle errors using `if err != nil`
*   Creating custom errors
*   Error wrapping with Go 1.13+
*   Custom error types
*   Using `panic` and `recover` (when and why)
*   Best practices for error handling

What is an Error in Go?
-----------------------

In Go, the `error` type is a built-in interface:

```go
type error interface {
    Error() string
} 
```

Any type that implements the `Error()` method satisfies the error interface. Most standard functions return an error as a way to indicate that something went wrong.

Basic Error Handling
--------------------

The standard way to handle errors in Go is with `if err != nil` blocks:

```go
package main

import (
    "errors"
    "fmt"
)

func divide(a, b int) (int, error) {
    if b == 0 {
        return 0, errors.New("cannot divide by zero")
    }
    return a / b, nil
}

func main() {
    result, err := divide(10, 0)
    if err != nil {
        fmt.Println("Error:", err)
        return
    }
    fmt.Println("Result:", result)
} 
```

Creating Custom Errors
----------------------

You can create custom errors using the `errors.New` or `fmt.Errorf` functions:

```go
err := errors.New("something went wrong")
err := fmt.Errorf("error occurred: %v", err) 
```

Error Wrapping (Go 1.13+)
-------------------------

Go 1.13 introduced error wrapping, which lets you keep the original error while adding context:

```go
original := errors.New("file not found")
wrapped := fmt.Errorf("cannot load config: %w", original) 
```

You can later use `errors.Is` and `errors.As` to inspect wrapped errors:

```go
if errors.Is(wrapped, original) {
    fmt.Println("Original error matched")
} 
```

Custom Error Types
------------------

To add more detail or behavior, you can define your own error types:

```go
type MyError struct {
    Code int
    Msg  string
}

func (e MyError) Error() string {
    return fmt.Sprintf("Code %d: %s", e.Code, e.Msg)
} 
```

Now you can return `MyError` from functions and check its fields with type assertions.

Panic and Recover
-----------------

`panic` is used when your program cannot continue. It's similar to throwing an exception but should be avoided for expected errors.

```go
func risky() {
    panic("something went really wrong")
} 
```

To handle panic safely, use `recover` inside a deferred function:

```go
func safe() {
    defer func() {
        if r := recover(); r != nil {
            fmt.Println("Recovered from panic:", r)
        }
    }()
    risky()
} 
```

Best Practices
--------------

*   Always check and handle errors returned from functions
*   Wrap errors with context using `fmt.Errorf` and `%w`
*   Use custom error types for more control
*   Avoid `panic` unless absolutely necessary (e.g., for programming errors)
*   Log errors with enough context to debug later

Conclusion
----------

Go’s error handling may be explicit and repetitive, but it leads to clear and predictable code. By following best practices and understanding how to create, return, and wrap errors, you’ll build programs that are easier to maintain and debug.

In the next topic, we'll explore how to write tests in Go to verify the correctness of your code using go [test]({{< relref "blog/go/testing-in-go-writing-unit-tests-with-the-testing-package.md" >}}) and the `testing` package.

Happy coding!