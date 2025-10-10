---
title: 'Defining and Using Custom Types'
date: 2025-04-19T10:00:00.000+07:00
draft: false
url: /2025/04/structs-and-methods-in-go-defining-and.html
tags:
- Go
description: "Learn how to define and use structs and methods in Go for better code organization and reusability."
keywords: ["Go", "structs", "methods", "custom types", "value receiver", "pointer receiver", "embedding", "anonymous structs"]
faq:
  - question: "What's the difference between named field initialization and positional initialization for structs?"
    answer: "Named initialization (recommended) specifies fields explicitly, positional (discouraged) uses order—named is safer, clearer, resilient to struct changes. Named: user := User{Name: \"Alice\", Age: 30}—explicit field names, can skip fields (defaults to zero value), order doesn't matter. Positional: user := User{\"Alice\", \"alice@example.com\", 30}—no field names, must match exact order and include all fields. Problems with positional: (1) Fragile—adding field breaks: type User struct { Name, Email, Phone string }—existing User{\"Alice\", \"alice@example.com\"} now errors (Phone missing). (2) Unclear—User{\"Alice\", 30, true} what fields? Named: User{Name: \"Alice\", Age: 30, Active: true}—obvious. (3) Can't skip—must provide all or none, even if defaults acceptable. When positional ok: very small, stable structs (Point{x, y}, Color{r, g, b})—2-3 fields, never change. Best practice: always use named initialization for maintainability. Partial init: user := User{Name: \"Alice\"}—Email and Age get zero values (\"\", 0). Zero values: string=\"\", int=0, bool=false, pointer=nil, slice=nil—must be safe defaults or validate after init. Constructors: provide New function for complex init: func NewUser(name, email string) *User { return &User{Name: name, Email: email, CreatedAt: time.Now()} }—enforces required fields, sets defaults. Anti-pattern: mixing positional and named: User{\"Alice\", Age: 30}—compiler error, must use one style."
  - question: "When should I use a value receiver vs pointer receiver for struct methods?"
    answer: "Use pointer receiver by default—allows mutation, avoids copying, more flexible. Use value receiver only for small immutable types. Pointer receiver (*T): func (u *User) UpdateEmail(email string) { u.Email = email }. Use when: (1) Method modifies struct: u.Balance += amount. (2) Large struct (>10 fields, >100 bytes)—avoids copying overhead. (3) Consistency—if any method needs pointer, use pointer for all. (4) Mutable types: Database connections, caches, stateful services. Value receiver (T): func (p Point) Distance() float64 { return math.Sqrt(p.X*p.X + p.Y*p.Y) }. Use when: (1) Small immutable types: Point{X, Y}, Color{R, G, B}, Time (stdlib uses value). (2) Primitive wrappers: type UserID int. (3) No mutation needed—pure functions. Effects: value receiver copies struct on call—modifications don't affect original: func (u User) SetName(n string) { u.Name = n }; user.SetName(\"Bob\"); fmt.Println(user.Name)—still original, not \"Bob\". Pointer receiver modifies original. Calling: both work transparently—compiler inserts & or * as needed: var u User; u.UpdateEmail(\"new@email\")—compiler calls (&u).UpdateEmail automatically. var p *User; p.GetName()—compiler calls (*p).GetName. Performance: value receiver copies—100 byte struct copied every call. Pointer: 8 bytes (pointer size). Benchmark shows 10-100x difference for large structs. Interface satisfaction: value receiver methods available on both T and *T, pointer receiver only on *T. Mistake: type Database struct { conn *sql.DB }; func (db Database) Query()—copies pointer, ok. But confusing—use pointer receiver for consistency. Rule: pointer receiver = default, value receiver = exception for tiny immutable types."
  - question: "What are struct tags and how do I use them for JSON, validation, and database mapping?"
    answer: "Struct tags are metadata strings attached to fields—used by reflection for encoding, validation, ORM mapping. Syntax: Field Type `key:\"value\"` or `key:\"value\" key2:\"value2\"`. JSON tags (encoding/json): type User struct { Name string `json:\"name\"`; Email string `json:\"email,omitempty\"`; Password string `json:\"-\"` }. (1) json:\"name\"—marshal to {\"name\": \"Alice\"} (lowercase). (2) omitempty—exclude if zero value: {\"email\": \"\"} omitted. (3) \"-\"—never marshal Password field (security). (4) json:\"age,string\"—marshal int as string: \"age\": \"30\". Validation tags (go-playground/validator): type User struct { Name string `validate:\"required,min=3,max=50\"`; Email string `validate:\"required,email\"`; Age int `validate:\"gte=0,lte=120\"` }. Validate: validate := validator.New(); err := validate.Struct(user)—checks constraints. Database tags (gorm, sqlx): type User struct { ID int `db:\"id\" gorm:\"primaryKey\"`; Name string `db:\"name\" gorm:\"type:varchar(100);not null\"`; CreatedAt time.Time `db:\"created_at\" gorm:\"autoCreateTime\"` }. sqlx: maps field to column via db tag. GORM: defines schema via gorm tags. Custom tags: define your own: Field string `csv:\"column_1\" validate:\"required\"`—parsed by your code using reflect. Reading tags: field, _ := reflect.TypeOf(User{}).FieldByName(\"Name\"); tag := field.Tag.Get(\"json\")—returns \"name\". Multiple tags: `json:\"name\" validate:\"required\" db:\"user_name\"`—space-separated, each package reads own key. Best practice: (1) Use tags for declarative metadata, not business logic. (2) Document custom tags. (3) Don't overuse—simple types don't need tags. Common mistake: typo in tag: `josn:\"name\"`—silently ignored, field exported with default name. Use linters (golangci-lint) to catch."
  - question: "What's the difference between struct embedding and composition, and when to use each?"
    answer: "Embedding promotes embedded type's fields/methods to parent—syntactic sugar for 'has-a' with convenience. Composition uses named field—explicit, clearer ownership. Embedding: type Employee struct { User; Department string }—User fields/methods accessible directly: emp.Name, emp.Greet(). Promotes: emp.User.Name → emp.Name (shorthand). Use when: (1) Extending functionality: BaseHandler embedded in APIHandler—inherit common methods. (2) Interface satisfaction: embed interface to forward methods: type ReaderWrapper struct { io.Reader }—satisfies io.Reader automatically. (3) Mixins: Logger embedded in multiple types—all get logging methods. Composition (named field): type Employee struct { user User; department string }—access via emp.user.Name. Use when: (1) Multiple instances: type Company struct { CEO User; CTO User }—can't embed User twice. (2) Clear ownership: emp.user.Name—explicit relationship. (3) Avoiding conflicts: two embedded types with same method name—ambiguous. Problems with embedding: (1) Namespace pollution: embedded struct with 50 methods—all promoted, clutters API. (2) Tight coupling: changes to embedded type affect parent. (3) JSON marshaling: embedded fields merge: User embedded → \"name\": \"Alice\" at top level, not nested. Fix: composition or custom MarshalJSON. When to embed: (1) Implementing interface via forwarding. (2) Extending base type with additional methods. (3) Domain objects with clear hierarchy. When composition: (1) Multiple instances of same type. (2) Explicit relationships preferred. (3) Large embedded types (avoid pollution). Best practice: prefer composition for clarity, use embedding sparingly for convenience. Go philosophy: composition over inheritance—both embedding and composition are composition (no inheritance). Example: http.Server embeds http.Handler—satisfies interface while adding lifecycle methods. Anti-pattern: deep embedding hierarchies—A embeds B embeds C—hard to reason about."
  - question: "How do I handle struct initialization with required fields and default values properly?"
    answer: "Use constructor function (New*) to enforce required fields, validate, and set defaults—safer than direct struct initialization. Problem: direct init allows invalid state: user := User{Name: \"\"}—empty name might be invalid. Constructor pattern: func NewUser(name, email string) (*User, error) { if name == \"\" { return nil, errors.New(\"name required\") }; if !isValidEmail(email) { return nil, errors.New(\"invalid email\") }; return &User{Name: name, Email: email, CreatedAt: time.Now()}, nil }. Benefits: (1) Validation—reject invalid data at creation. (2) Defaults—CreatedAt set automatically. (3) Encapsulation—can change internal struct without breaking callers. (4) Documentation—function signature shows required fields. Required fields: make constructor parameters, validate non-empty. Optional fields: use functional options or builder pattern. Functional options: func NewUser(name string, opts ...UserOption) *User { u := &User{Name: name}; for _, opt := range opts { opt(u) }; return u }. type UserOption func(*User); func WithEmail(email string) UserOption { return func(u *User) { u.Email = email } }. Usage: user := NewUser(\"Alice\", WithEmail(\"alice@example.com\"), WithAge(30))—flexible, readable. Builder pattern: type UserBuilder struct { user User }; func (b *UserBuilder) WithName(n string) *UserBuilder { b.user.Name = n; return b }; func (b *UserBuilder) Build() (*User, error) { if b.user.Name == \"\" { return nil, errors.New(\"name required\") }; return &b.user, nil }. Usage: user, err := NewUserBuilder().WithName(\"Alice\").WithEmail(\"alice@example.com\").Build(). Default values: use constructor: func NewConfig() *Config { return &Config{Timeout: 30 * time.Second, MaxRetries: 3} }. Partial init: support updates: func (u *User) SetEmail(email string) error { if !isValidEmail(email) { return errors.New(\"invalid\") }; u.Email = email; return nil }—validate on update too. Best practice: required fields in constructor params, optional via options or builder, always validate. Export rule: if struct exported, provide constructor—don't force callers to guess valid state."
  - question: "Does struct field order matter, and how does memory alignment affect struct size?"
    answer: "Field order affects struct size due to memory alignment—poor ordering wastes memory via padding. Compiler aligns fields to natural boundaries for performance. Alignment: each type has alignment requirement: int8=1 byte, int16=2, int32=4, int64=8, pointer=8 (64-bit). Compiler pads fields to meet alignment. Bad order: type BadStruct struct { A bool; B int64; C bool; D int64 }—size 32 bytes. Layout: A(1) + padding(7) + B(8) + C(1) + padding(7) + D(8) = 32. Good order: type GoodStruct struct { B int64; D int64; A bool; C bool }—size 24 bytes. Layout: B(8) + D(8) + A(1) + C(1) + padding(6) = 24. Savings: 25% smaller! Rule: order fields largest to smallest (int64, pointers, int32, int16, bool)—minimizes padding. Check size: unsafe.Sizeof(BadStruct{})—returns 32. Alignment: unsafe.Alignof(s.B)—returns 8 for int64. Tool: golang.org/x/tools/go/analysis/passes/fieldalignment—linter suggests optimal order: fieldalignment -fix ./...—automatically reorders. When it matters: (1) Large slices of structs: []User—1M users, 8 bytes saved each = 8MB total. (2) Memory-constrained systems: embedded, IoT. (3) Cache performance: smaller structs fit more per cache line. When it doesn't: (1) Single instances—nanosecond allocation difference. (2) Logical grouping preferred: type Config struct { Host string; Port int }—don't reorder for 4 bytes if hurts readability. Trade-off: reordering for alignment vs logical field grouping—profile first, optimize hot paths only. Struct tags don't affect layout—purely metadata. Empty struct: struct{}—size 0, used for signaling: chan struct{}, map[string]struct{}—no memory. Best practice: order by size for frequently allocated structs (events, protocol messages), group logically for config/domain structs. Don't: premature optimization—measure first."
---

In Go, a struct is a powerful way to group related data together. It allows you to define your own custom types by combining variables (also called fields). Structs are often used to model real-world entities like users, products, or messages. When combined with methods, structs become the foundation for writing clean and reusable code in Go.

In this article, you'll learn:

*   How to define and use structs in Go
*   How to attach methods to a struct
*   The difference between value and pointer receivers
*   Best practices for using structs and methods effectively

Defining a Struct
-----------------

To define a struct, you use the `type` keyword followed by the name of the struct and the `struct` keyword:

```go
type User struct {
    Name  string
    Email string
    Age   int
} 
```

This defines a struct called `User` with three fields. To create a value of that struct, you can do the following:

```go
func main() {
    user := User{
        Name:  "Alice",
        Email: "alice@example.com",
        Age:   30,
    }
    fmt.Println(user)
} 
```

You can also declare an empty struct and assign fields later:

```go
var u User
u.Name = "Bob"
u.Email = "bob@example.com"
u.Age = 25 
```

Accessing and Updating Struct Fields
------------------------------------

To access a field, use the dot `.` operator:

```go
fmt.Println(user.Name)
```

To update a field:

```go
user.Age = 31
```

Structs with Functions
----------------------

You can write a function that accepts a struct as an argument:

```go
func printUser(u User) {
    fmt.Println("Name:", u.Name)
    fmt.Println("Email:", u.Email)
    fmt.Println("Age:", u.Age)
} 
```

Methods in Go
-------------

In Go, you can define a function that is associated with a struct. This is called a method.

```go
func (u User) Greet() {
    fmt.Println("Hi, my name is", u.Name)
} 
```

Here, `(u User)` means this function is a method that can be called on a User value.

Pointer Receivers vs Value Receivers
------------------------------------

You can define methods using either a value receiver or a pointer receiver:

```go
// Value receiver
func (u User) Info() {
    fmt.Println("User info:", u.Name, u.Email)
}

// Pointer receiver
func (u *User) UpdateEmail(newEmail string) {
    u.Email = newEmail
} 
```

Use a pointer receiver if the method needs to modify the original struct or if copying the struct would be expensive.

Embedding Structs
-----------------

Go allows embedding one struct into another. This can be used to extend functionality:

```go
type Address struct {
    City  string
    State string
}

type Employee struct {
    User
    Address
    Position string
} 
```

You can now access fields from both `User` and `Address` in an `Employee` instance directly.

Anonymous Structs
-----------------

Go also supports defining structs without giving them a name. These are used for quick data grouping:

```go
person := struct {
    Name string
    Age  int
}{
    Name: "Charlie",
    Age:  22,
} 
```

Best Practices
--------------

*   Group related data using structs for better organization
*   Use methods to define behavior related to a struct
*   Use pointer receivers when modifying struct data
*   Use struct embedding to promote code reuse

Conclusion
----------

Structs and methods are a core part of writing structured and maintainable code in Go. By learning how to define and work with them, you'll be better equipped to build complex systems that are easy to manage. Practice creating your own structs and adding behavior with methods to solidify your understanding.

Happy coding!