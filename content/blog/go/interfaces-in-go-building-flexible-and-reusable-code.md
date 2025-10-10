---
title: 'Building Flexible and Reusable Code'
date: 2025-04-21T10:30:00.000+07:00
draft: false
url: /2025/04/interfaces-in-go-building-flexible-and.html
tags:
- Go
description: "Learn how to use interfaces in Go to create flexible, reusable, and testable code."
keywords: ["Go", "interfaces", "polymorphism", "abstraction", "empty interface", "type assertion", "best practices"]
faq:
  - question: "When should I define an interface instead of using concrete types?"
    answer: "Define interfaces when you need abstraction for testing, multiple implementations, or decoupling—avoid over-engineering with unnecessary interfaces. Go proverb: 'Accept interfaces, return structs'. When to use interfaces: (1) Multiple implementations exist: Logger with ConsoleLogger, FileLogger, CloudLogger—function accepts Logger interface, caller chooses implementation. (2) Testing/mocking: type UserRepository interface { GetUser(id int) (*User, error) }—test with mock, production uses PostgreSQL. (3) Standard library patterns: io.Reader, io.Writer—composable, many implementations (files, buffers, network). (4) Plugin architecture: type Plugin interface { Run() error }—load implementations at runtime. When NOT to use: (1) Single implementation—no abstraction needed: type UserService struct { repo *PostgresRepo }—concrete types simpler, fewer indirections. (2) Early abstraction—don't define interface 'just in case': write concrete code first, extract interface when second implementation appears. (3) Over-engineering—interface with 10 methods: violates interface segregation, hard to mock. Go philosophy: small interfaces (1-3 methods), defined by consumer not producer. Anti-pattern: define interface in same package as implementation—consumer should define needed interface (dependency inversion). Best practice: start concrete, refactor to interface when testing or multiple implementations needed. Example: httpClient := &http.Client{} works fine until you need to mock for tests, then define type HTTPClient interface { Do(*http.Request) (*http.Response, error) }."
  - question: "What's the difference between interface{} and any in Go, and when to use them?"
    answer: "any is type alias for interface{} added in Go 1.18—identical behavior, use any for readability (clearer intent). Pre-1.18: func Print(v interface{}) { fmt.Println(v) }—empty interface accepts any type. Go 1.18+: func Print(v any) { fmt.Println(v) }—same functionality, more readable. No difference: type alias defined as type any = interface{}—compiler treats identically. When to use any: (1) Generic containers before generics: map[string]any for JSON decoding. (2) Truly dynamic types: reflection, plugin systems. (3) Legacy APIs: json.Unmarshal(data, &result any). Prefer generics (Go 1.18+): func Max[T constraints.Ordered](a, b T) T—type-safe, no casts. any disadvantages: (1) Loses type safety—runtime panics on wrong cast: val := x.(int)—panics if not int. (2) Performance—boxing/unboxing allocations. (3) Harder debugging—interface{} in stack trace unclear. Migration: replace interface{} with any in new code for clarity—purely stylistic. Type assertions: use safe form: if val, ok := x.(int); ok { ... } else { handle }—prevents panic. Type switches: switch v := x.(type) { case int: ...; case string: ...; default: ... }. Best practice: avoid any when possible—use concrete types or generics. If needed: document expected types: // ProcessData accepts map[string]any with keys: 'id' (int), 'name' (string). Don't: func DoSomething(a any, b any, c any)—too generic, no type safety. Better: use generics or specific types."
  - question: "Why does my interface variable show as nil even though it contains a nil pointer?"
    answer: "Interface is nil only when both type and value are nil—interface holding nil pointer is non-nil interface. Confusing case: var p *MyStruct; var i MyInterface = p; i == nil → false!—interface holds (*MyStruct, nil), not (nil, nil). Problem: func NewService() Service { var s *ServiceImpl; if err != nil { return nil }; return s }—returns non-nil interface containing nil pointer. Caller: svc := NewService(); if svc == nil { ... }—never true, svc has type even with nil value. Consequences: calling methods panics: svc.DoSomething()—nil pointer dereference. Solution 1 (explicit nil check): if s == nil { return nil }—returns true nil interface. Solution 2 (return early): func NewService() Service { if err != nil { return nil }; return &ServiceImpl{} }—always return valid pointer or nil. Solution 3 (check both): if svc == nil || reflect.ValueOf(svc).IsNil()—works but ugly, avoid. Best practice: never return nil concrete type as interface. Pattern: func NewService() (*ServiceImpl, error)—return concrete type, nil works as expected. If must return interface: ensure pointer is valid or return explicit nil. Debug: fmt.Printf('%T %v', i, i)—shows <*MyStruct> <nil> for nil-pointer-in-interface. Why: interface is (type, value) pair—(nil, nil) = nil interface, (*T, nil) = non-nil interface with nil value. Comparison: i == nil checks both, but i.(*T) == nil only checks value. Avoid: var i Interface; if someCondition { i = &Impl{} }—i non-nil even if condition false. Fix: explicitly set i = nil in else."
  - question: "Should I use pointer or value receiver for methods that satisfy an interface?"
    answer: "Use pointer receiver if method modifies state or type is large, value receiver if method is read-only and type is small—but pointer receiver is more common and flexible. Pointer receiver: func (s *Service) Process() { s.count++ }—modifies struct state. When to use: (1) Method mutates struct: Counter, Cache, Connection. (2) Large struct (>100 bytes)—avoid copying: Image, Document. (3) Consistency—if one method needs pointer, use pointer for all methods. (4) Nullable semantics: var svc *Service; if svc != nil { svc.Process() }. Value receiver: func (p Point) Distance() float64 { return math.Sqrt(p.X*p.X + p.Y*p.Y) }—pure computation, no mutation. When to use: (1) Small immutable types: Point, Color, Time. (2) Primitive-like types: UserId(int), Email(string). (3) Performance critical with small types—no pointer indirection. Interface satisfaction: pointer receiver methods work on pointers only, value receiver methods work on both. Example: type Stringer interface { String() string }; func (p Point) String() string—both Point and *Point satisfy. But func (p *Point) String() string—only *Point satisfies, Point doesn't. Problem: var p Point; var s Stringer = p; p.SetX(10)—compiler error if SetX has pointer receiver, p is value. Solution: use pointer: var s Stringer = &p. Best practice: (1) Start with pointer receiver (most flexible, consistent). (2) Use value receiver only for small immutable types. (3) Never mix pointer and value receivers on same type (confusing). (4) Collection types (slices, maps) as value receiver ok—they're references. Rule of thumb: pointer receiver = default, value receiver = exception for tiny types."
  - question: "How do I write testable code using interfaces for mocking dependencies?"
    answer: "Define interface in consumer package for dependencies, inject real implementation in production, mock in tests. Pattern: (1) Define interface: type UserRepository interface { GetUser(id int) (*User, error); SaveUser(*User) error }. (2) Accept interface in service: type UserService struct { repo UserRepository }; func NewUserService(repo UserRepository) *UserService { return &UserService{repo: repo} }. (3) Production: real := &PostgresUserRepository{db: db}; svc := NewUserService(real). (4) Test: mock := &MockUserRepository{users: map[int]*User{1: testUser}}; svc := NewUserService(mock); test with mock. Mock implementation: type MockUserRepository struct { users map[int]*User; getUserCalled bool }; func (m *MockUserRepository) GetUser(id int) (*User, error) { m.getUserCalled = true; return m.users[id], nil }—track calls, return test data. Libraries: (1) testify/mock: auto-generate mocks with expectations: mock.On('GetUser', 1).Return(testUser, nil). (2) gomock (Google): generate from interface: mockgen -source=repo.go -destination=mock_repo.go. (3) Manual mocks: simple for small interfaces, no dependencies. What to mock: (1) External dependencies: databases, HTTP clients, S3. (2) Slow operations: network calls, file I/O. (3) Non-deterministic: time.Now(), rand.Int(). What NOT to mock: (1) Standard library (io.Reader, http.ResponseWriter)—use real implementations or helpers. (2) Simple types (string, int)—no need. (3) Over-mocking: mocking everything makes tests brittle, test behavior not implementation. Best practice: define interface in service package (consumer), not repository package (producer)—dependency inversion. Table-driven tests with mocks: tests := []struct { name string; repo UserRepository; wantErr bool }{{name: 'success', repo: &SuccessMock{}}, {name: 'error', repo: &ErrorMock{}}}—test multiple scenarios."
  - question: "What are best practices for composing interfaces and avoiding interface pollution?"
    answer: "Keep interfaces small (1-3 methods), compose larger interfaces from smaller ones, define interfaces where used (not with implementation). Small interfaces (Go philosophy): type Reader interface { Read([]byte) (int, error) }—single method, highly reusable. Why small: (1) Easy to implement—satisfy with minimal code. (2) Composable—combine into larger interfaces. (3) Focused—single responsibility. (4) Testable—mock is trivial. Large interfaces (anti-pattern): type Repository interface { Get(); List(); Create(); Update(); Delete(); BulkInsert(); Transaction(); Rollback() }—hard to implement, hard to mock. Fix: split: type Getter interface { Get() }; type Lister interface { List() }; function accepts specific interface needed. Composition: type ReadWriter interface { Reader; Writer }; type ReadWriteCloser interface { ReadWriter; Closer }—build complex from simple. Standard library: io.Reader + io.Writer + io.Closer—composable building blocks. Interface pollution: defining interfaces 'just in case'—YAGNI (you aren't gonna need it). Signs: (1) Interface with single implementation—unnecessary. (2) Interface never used as parameter—over-abstraction. (3) Interface in same package as struct—should be in consumer. Where to define: consumer defines interface for its needs—producer returns concrete type. Example: http package returns *http.Client (concrete), test code defines type HTTPDoer interface { Do(*Request) (*Response, error) }—only methods test needs. Granularity: interface per function, not per package—func Process(r io.Reader) accepts minimal needed interface. Avoid: type Processor interface { Process() }—too generic, meaningless. Naming: suffix with -er for single-method: Reader, Writer, Closer, Stringer. Multiple methods: descriptive name: UserRepository, PaymentGateway. Best practices: (1) Accept interfaces (flexible), return structs (concrete). (2) Interface defined by consumer, not producer. (3) Keep interfaces small and focused. (4) Compose complex from simple. (5) Don't define interface until you have 2+ implementations. Production pattern: define minimal interface in function signature: func Upload(r io.Reader, size int64) error—accepts anything readable, not specific type."
---

Interfaces are one of the most important features in Go. They allow you to write flexible, reusable, and loosely coupled code. In Go, an interface defines a set of method signatures, and any type that implements those methods satisfies the interface — without needing to explicitly declare that it does so. This is a powerful concept that supports polymorphism and clean architecture in Go applications.

In this article, you'll learn:

*   What an interface is in Go
*   How to define and implement interfaces
*   Implicit interface implementation
*   Using interface as function parameters
*   The empty interface and type assertions
*   Real-world examples of interfaces
*   Best practices when working with interfaces

What is an Interface?
---------------------

An interface is a type that defines a set of method signatures. Any type that provides implementations for those methods is said to satisfy the interface.

```go
type Speaker interface {
    Speak() string
} 
```

This interface requires a method `Speak` that returns a string.

Implementing an Interface
-------------------------

Unlike other languages, Go uses implicit implementation. You don’t need to explicitly say “this struct implements an interface.” You just define the required methods.

```go
type Dog struct {}

func (d Dog) Speak() string {
    return "Woof!"
}

type Cat struct {}

func (c Cat) Speak() string {
    return "Meow!"
} 
```

Both `Dog` and `Cat` now satisfy the `Speaker` interface because they implement the `Speak` method.

Using Interface as Function Parameter
-------------------------------------

Interfaces allow you to write functions that work with any type that satisfies the interface.

```go
func makeItSpeak(s Speaker) {
    fmt.Println(s.Speak())
}

func main() {
    makeItSpeak(Dog{})
    makeItSpeak(Cat{})
} 
```

This is very powerful for building reusable code, such as in logging, HTTP handling, and I/O.

Interface with Multiple Methods
-------------------------------

```go
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

type ReadWriter interface {
    Reader
    Writer
} 
```

Interfaces can be composed from other interfaces, helping you build powerful abstractions.

The Empty Interface
-------------------

The empty interface `interface{}` can represent any type. It is often used in situations where you don’t know the exact type at compile time (e.g., in JSON decoding, generic containers).

```go
func describe(i interface{}) {
    fmt.Printf("Value: %v, Type: %T
", i, i)
} 
```

Type Assertion
--------------

You can convert an empty interface back to a concrete type using type assertion.

```go
var i interface{} = "hello"

s := i.(string)
fmt.Println(s) 
```

Or safely:

```go
if s, ok := i.(string); ok {
    fmt.Println("String value:", s)
} else {
    fmt.Println("Not a string")
} 
```

Type Switch
-----------

Type switches are like regular switches, but for handling multiple possible types.

```go
func printType(i interface{}) {
    switch v := i.(type) {
    case string:
        fmt.Println("It's a string:", v)
    case int:
        fmt.Println("It's an int:", v)
    default:
        fmt.Println("Unknown type")
    }
} 
```

Real-World Example: Logger Interface
------------------------------------

Let’s create a logger interface and different implementations:

```go
type Logger interface {
    Log(message string)
}

type ConsoleLogger struct {}

func (c ConsoleLogger) Log(message string) {
    fmt.Println("[Console]", message)
}

type FileLogger struct {
    File *os.File
}

func (f FileLogger) Log(message string) {
    fmt.Fprintln(f.File, "[File]", message)
} 
```

This allows you to use either logger with the same code:

```go
func logMessage(logger Logger, message string) {
    logger.Log(message)
} 
```

Best Practices
--------------

*   Name interfaces based on behavior (e.g., Reader, Formatter)
*   Prefer small interfaces with one or two methods
*   Use interface embedding for composition
*   Only expose interfaces when they are needed (don’t over-abstract)

Conclusion
----------

Interfaces are a core feature in Go that allow you to write flexible, reusable, and testable code. They help you define behavior and decouple implementation from abstraction. By understanding how to define and work with interfaces, you'll be ready to create clean and modular Go programs.

Try writing your own interfaces, build functions that accept them, and explore the built-in interfaces in Go’s standard library.

Happy coding!