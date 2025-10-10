---
title: 'Managing Errors the Right Way'
date: 2025-04-22T10:00:00.004+07:00
draft: false
url: /2025/04/error-handling-in-go-managing-errors.html
tags:
- Go
description: "Learn how to handle errors in Go, create custom errors, and understand best practices for error management."
keywords: ["Go", "error", "handling", "custom", "errors", "panic", "recover", "best practices"]
faq:
  - question: "Is it okay to ignore errors by assigning to _ in Go, or should I check every error?"
    answer: "Check every error unless you have explicit reason to ignore and document why. Ignoring errors causes silent failures—data corruption, security holes, crashes. When checking is mandatory: (1) File operations: os.Open(), file.Write()—ignoring means writing to closed file, data loss. (2) Network operations: http.Get(), conn.Write()—silent failures, user sees blank page. (3) Database: db.Exec(), tx.Commit()—data inconsistency, lost writes. (4) Parsing: json.Unmarshal(), strconv.Atoi()—use zero value silently, wrong behavior. When ignoring is acceptable: (1) Close in defer: defer file.Close()—already handled error from operations, close failure non-critical. (2) Best-effort cleanup: os.Remove(tmpFile)—temp file deletion fails, not catastrophic. (3) Formatting: fmt.Fprintf(w, ...)—Writer interface doesn't fail in practice (buffers), but check in production. Document ignoring: // Ignoring error: close is best-effort, data already written. Good pattern: if err := file.Close(); err != nil { log.Printf(\"close failed: %v\", err) }—at least log. Linters: errcheck tool catches unchecked errors: go install github.com/kisielk/errcheck@latest; errcheck ./.... Production: enable in CI to enforce. Anti-pattern: _, _ = fmt.Fprintf(w, ...)—double ignore shows sloppiness. Best practice: return errors up stack until actionable layer (HTTP handler logs, CLI exits), don't swallow."
  - question: "When should I use errors.Is vs errors.As vs type assertion for error checking?"
    answer: "Use errors.Is for sentinel errors (specific error instances), errors.As for error types (extracting custom fields), type assertion rarely (legacy code). errors.Is: compares error to target, unwraps chain: if errors.Is(err, sql.ErrNoRows) { return ErrNotFound }. Use when: checking against known sentinel like io.EOF, os.ErrNotExist, context.Canceled. Works through wrapping: err := fmt.Errorf('query failed: %w', sql.ErrNoRows); errors.Is(err, sql.ErrNoRows) → true. errors.As: extracts specific error type from chain: var e *MyError; if errors.As(err, &e) { fmt.Println(e.Code) }. Use when: need custom error fields (status code, retryable flag, validation errors). Example: type ValidationError struct { Field string }; if errors.As(err, &valErr) { return 400, valErr.Field }. Type assertion (legacy): if e, ok := err.(*MyError); ok { ... }—doesn't unwrap, breaks with wrapping. Only use: pre-Go-1.13 code, performance-critical path (errors.As has overhead). Decision tree: (1) Known sentinel → errors.Is. (2) Custom struct with fields → errors.As. (3) Simple type check without unwrap → type assertion (rare). Common mistakes: (1) errors.Is(&err, target)—pass err not &err. (2) errors.As(err, e)—pass &e not e (pointer to pointer). (3) Using == for comparison: if err == io.EOF—works only if not wrapped, fragile. Best practice: define sentinel errors: var ErrNotFound = errors.New(\"not found\"), return wrapped: fmt.Errorf(\"user lookup: %w\", ErrNotFound), check with Is. Custom types: return MyError{Code: 404}, extract with As."
  - question: "How do I return or collect multiple errors in Go, like validation errors from multiple fields?"
    answer: "Use error aggregation: multierr package, custom error type with slice, or errors.Join (Go 1.20+). Problem: validating struct with 5 fields, want all errors not just first. Naive: return on first error—user fixes one, submits again, sees next error (bad UX). Solution 1 (errors.Join, Go 1.20+): var errs []error; if user.Name == \"\" { errs = append(errs, errors.New(\"name required\")) }; if user.Age < 0 { errs = append(errs, errors.New(\"age invalid\")) }; return errors.Join(errs...)—combines into single error, each extractable with errors.Is/As. Iterate: for _, err := range allErrors { ... } (need unwrap loop). Solution 2 (hashicorp/go-multierr): import \"go.uber.org/multierr\"; err := multierr.Append(err, validateName()); err = multierr.Append(err, validateAge()); return err. Errors() method returns slice. Solution 3 (custom type): type ValidationErrors []error; func (ve ValidationErrors) Error() string { return fmt.Sprintf(\"%d errors: %v\", len(ve), ve) }. Append as you validate, return. Solution 4 (map for field errors): type FieldErrors map[string]error; return FieldErrors{\"name\": ErrRequired, \"age\": ErrInvalid}—API-friendly. When to use: (1) Validation → FieldErrors map or custom type (JSON response). (2) Concurrent operations → multierr (append from goroutines). (3) Sequential checks → errors.Join. Don't: ignore subsequent errors after first—user frustration. Production: return structured errors: {\"errors\": [{\"field\": \"name\", \"message\": \"required\"}]} for APIs. Tools: github.com/go-playground/validator for struct validation with tags."
  - question: "When is it acceptable to use panic instead of returning an error in Go?"
    answer: "Use panic only for programmer errors (bugs) that should never happen in production, not for expected failures. Panic cases: (1) Unrecoverable initialization: db, err := sqlx.Connect(...); if err != nil { panic(err) }—app can't start without DB. (2) Impossible conditions: switch val { case A: ...; case B: ...; default: panic(\"unreachable\") }—logic bug if reached. (3) Nil pointer bugs: if obj == nil { panic(\"obj must not be nil\") }—caller violated contract. (4) Index out of bounds: slice[100] panics if len < 100—programming error. Don't panic for: (1) File not found—return error, caller decides (log, retry, fallback). (2) Network timeout—expected, handle gracefully. (3) Invalid user input—validate, return error. (4) Database constraint violation—business logic error, not crash. Recover from panic: use in servers/APIs to prevent crash: defer func() { if r := recover(); r != nil { log.Errorf(\"panic: %v\", r); http.Error(w, \"Internal Error\", 500) } }()—recover in handler, log, return error response. Libraries: never panic—return errors, let caller decide. Binaries: panic in main() for init failures ok—fast fail. Go standard library panics: (1) slice bounds. (2) nil pointer dereference. (3) concurrent map writes. (4) close closed channel—all programmer errors. Best practice: panic = bug, error = expected failure. If you're unsure → return error. Production: monitor panic rate—should be zero, any panic is bug to fix. Anti-pattern: panic(\"user not found\")—this is expected, return error."
  - question: "Should I log errors and return them, or just one? What's the best practice?"
    answer: "Return errors up the stack, log only at boundaries (HTTP handlers, main, workers)—avoid duplicate logs. Problem: logging at every layer creates noise: service logs, repository logs, handler logs—same error 3+ times in logs, hard to trace. Anti-pattern: func getUser(id int) (*User, error) { user, err := db.Query(...); if err != nil { log.Printf(\"query failed: %v\", err); return nil, err }; return user, nil }—caller also logs, duplicate. Best practice: return with context, log once at boundary: func getUser(id int) (*User, error) { user, err := db.Query(...); if err != nil { return nil, fmt.Errorf(\"get user %d: %w\", id, err) }; return user, nil }—wrap with context. Handler logs: func handler(w http.ResponseWriter, r *http.Request) { user, err := svc.GetUser(42); if err != nil { log.Printf(\"handler error: %v\", err); http.Error(w, \"Not Found\", 404); return } }—logs once with full context chain. Exceptions to return-only: (1) Background workers: log before retry—no caller to handle. (2) Graceful degradation: log error, use fallback: if err != nil { log.Warnf(\"cache miss: %v\", err); return db.Load() }. (3) Metrics: log.WithFields for structured logging, count error types. When to log: (1) Unexpected errors (500s). (2) Security events (auth failures). (3) Rate limiting triggered. When NOT to log: (1) Expected errors (404 user not found)—clutter. (2) Validation failures—return to user. (3) Context.Canceled—user canceled, not error. Structured logging: log.WithError(err).WithField(\"user_id\", id).Error(\"lookup failed\")—enables filtering in log aggregators. Best practice: wrap errors with context as they bubble (fmt.Errorf with %w), log once at top with all context, return clean error to user."
  - question: "Should I use sentinel errors (var ErrNotFound = errors.New()) or custom error types (type NotFoundError struct{})?"
    answer: "Use sentinel errors for simple cases, custom types when you need to attach data (ID, fields, codes). Sentinel errors: var ErrNotFound = errors.New(\"not found\"); var ErrInvalidInput = errors.New(\"invalid input\"). Benefits: (1) Simple—one-liner definition. (2) Comparable with errors.Is: if errors.Is(err, ErrNotFound) { ... }. (3) Wrapped errors maintain identity: fmt.Errorf(\"user: %w\", ErrNotFound)—still matchable. Use when: error is boolean (happened or not), no extra context needed. Examples: io.EOF, sql.ErrNoRows, context.Canceled. Custom types: type NotFoundError struct { Resource string; ID int }; func (e NotFoundError) Error() string { return fmt.Sprintf(\"%s %d not found\", e.Resource, e.ID) }. Benefits: (1) Attach data—extract with errors.As: var nfe NotFoundError; if errors.As(err, &nfe) { log.Printf(\"missing: %s/%d\", nfe.Resource, nfe.ID) }. (2) Implement Is/As methods for custom matching. (3) Type-specific behavior: retryable, temporary, timeout interfaces. Use when: need structured error info (API responses with codes, validation with field names). Comparison: sentinel for control flow (retry on ErrTimeout), custom for rich errors (return JSON: {\"error\": \"validation\", \"fields\": [...]}). Anti-pattern: sentinel with formatted messages: errors.New(fmt.Sprintf(\"user %d not found\", id))—can't compare, every instance unique. Best practice: define domain sentinels (var ErrUserNotFound), wrap with context: fmt.Errorf(\"load user %d: %w\", id, ErrUserNotFound). API errors: custom type with Code int, HTTPStatus int. Internal errors: sentinels. Production: sentinel errors in public API (exported), custom types for internal rich errors."
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