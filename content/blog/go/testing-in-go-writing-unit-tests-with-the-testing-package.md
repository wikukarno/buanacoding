---
title: 'Writing Unit Tests with the Testing Package'
date: 2025-04-23T10:00:00.003+07:00
draft: false
url: /2025/04/testing-in-go-writing-unit-tests-with.html
tags:
- Go
description: "Learn how to write unit tests in Go using the built-in testing package."
keywords: ["Go", "testing", "unit tests", "testing package", "best practices"]
faq:
  - question: "What are the naming conventions for test files and functions, and how do I run specific tests?"
    answer: "Test files must end with _test.go, test functions must start with Test and take *testing.T—strict conventions enable go test to discover tests automatically. File naming: math.go → math_test.go. Same package: package math (white-box testing, access unexported). Different package: package math_test (black-box testing, only exported). Function naming: func TestAdd(t *testing.T)—Test prefix + capitalized name. Invalid: testAdd (lowercase t), AddTest (wrong order), Test_Add (underscore discouraged). Run all tests: go test ./... (all packages recursively). Run specific test: go test -run TestAdd (regex matching). Run multiple: go test -run 'TestAdd|TestSubtract'. Run by pattern: go test -run TestUser/valid_email (matches subtests). Verbose: go test -v (shows each test name and result). Parallel: go test -p 4 (run 4 packages concurrently). Coverage: go test -cover (shows percentage). Short mode: go test -short (skips long tests marked with if testing.Short() { t.Skip() }). Timeout: go test -timeout 30s (fail if takes >30s). Caching: go test uses cache, go test -count=1 disables cache (force re-run). Examples: func ExampleAdd()—documentation examples, run as tests, checked against // Output: comment. Benchmarks: func BenchmarkAdd(b *testing.B)—performance tests, run with go test -bench=. Setup: func TestMain(m *testing.M)—custom setup/teardown for entire package. Best practice: descriptive test names: TestUserRepository_FindByEmail_ReturnsErrorWhenNotFound—clear what's tested and expected behavior. Subtests: t.Run(\"valid email\", func(t *testing.T) { ... })—grouping, isolated failures."
  - question: "How do I use t.Run for subtests, and what are the benefits of parallel testing?"
    answer: "t.Run creates subtests—isolated, named, individually runnable. t.Parallel() marks test for parallel execution—faster test suites. Subtests: func TestUser(t *testing.T) { t.Run(\"valid email\", func(t *testing.T) { ... }); t.Run(\"invalid email\", func(t *testing.T) { ... }) }—groups related tests. Benefits: (1) Organization: nested structure, clear hierarchy. (2) Selective running: go test -run TestUser/valid (only valid subtest). (3) Setup/teardown: shared setup before subtests: user := createUser(); t.Run(\"test1\", func(t *testing.T) { ... user ... }). (4) Isolation: one subtest fails, others continue. Parallel tests: func TestExpensiveOperation(t *testing.T) { t.Parallel(); ... }—runs concurrently with other parallel tests. How it works: (1) Sequential tests run first. (2) Parallel tests run concurrently after sequential finish. (3) Max parallelism: GOMAXPROCS (default = CPU cores), override with -parallel flag: go test -parallel 8. When to parallelize: (1) Independent tests—no shared state. (2) I/O bound—database queries, API calls. (3) Slow tests—long-running computations. When NOT to parallelize: (1) Shared state—global variables, file system. (2) Order-dependent—test B depends on test A. (3) Resource contention—parallel tests overwhelm database. Example with subtests: func TestDatabase(t *testing.T) { tests := []struct { name string; query string }{{\"simple\", \"SELECT 1\"}, {\"complex\", \"JOIN ...\"}}; for _, tt := range tests { tt := tt; t.Run(tt.name, func(t *testing.T) { t.Parallel(); result := db.Query(tt.query); assert(result) }) } }—each subtest runs in parallel. Caveat: t.Parallel() with table tests requires tt := tt (copy loop variable)—otherwise all subtests use last value. Detection: race detector finds issues: go test -race. Best practice: default to parallel for unit tests (fast), sequential for integration tests (shared resources). Mark long tests: if testing.Short() { t.Skip(\"skip in -short mode\") }—skip in CI quick checks."
  - question: "What's the best way to handle test setup and teardown (fixtures) in Go?"
    answer: "Use t.Cleanup() for test-scoped cleanup, TestMain for package-level setup—prefer explicit over implicit. Per-test setup (recommended): func TestUser(t *testing.T) { db := setupTestDB(t); t.Cleanup(func() { db.Close() }); user, _ := db.Create(&User{Name: \"Alice\"}); assert.Equal(t, \"Alice\", user.Name) }. setupTestDB: func setupTestDB(t *testing.T) *DB { db := openDB(\"test.db\"); t.Cleanup(func() { os.Remove(\"test.db\") }); return db }—registers cleanup, runs after test (even if test fails). Benefits: (1) Automatic: no defer needed, cleanup registered anywhere. (2) Ordered: LIFO order (last registered runs first). (3) Subtests: cleanup runs after each subtest. Shared setup (use sparingly): var testDB *DB; func TestMain(m *testing.M) { testDB = openDB(\"test.db\"); code := m.Run(); testDB.Close(); os.Remove(\"test.db\"); os.Exit(code) }—runs once for package, all tests share testDB. When to use TestMain: (1) Expensive setup: Docker container, test database. (2) External resources: start/stop server, mock service. (3) Integration tests: setup environment once. Caveat: shared state between tests—flaky tests if not careful. Ensure tests don't modify shared data or clean between tests. Helper functions: func setupUser(t *testing.T) *User { t.Helper(); return &User{Name: \"Alice\"} }—t.Helper() marks as helper, failure points to caller line not helper line. Best practice: prefer t.Cleanup() over defer—cleanup runs even if t.FailNow() called. Pattern: func createTempFile(t *testing.T) string { f, _ := os.CreateTemp(\"\", \"test\"); t.Cleanup(func() { os.Remove(f.Name()) }); return f.Name() }—returns resource, cleanup automatic. Anti-pattern: global var shared across tests without reset—test order affects results, flaky. Testing setup itself: ensure setup/teardown code itself is correct—common source of test flakiness."
  - question: "How do I test unexported (private) functions in Go, and should I?"
    answer: "Two approaches: (1) Test through exported functions (preferred)—tests public API. (2) Use _test.go in same package (white-box)—direct access to unexported. Exported testing (black-box): package math_test; import \"myapp/math\"—only access exported functions. Test internal by testing exported: func TestCalculate(t *testing.T) { result := math.Calculate(10); assert.Equal(t, 20, result) }—Calculate calls internal add(), multiply()—tested indirectly. Philosophy: if internal function matters, it's tested through public API. If not tested, maybe not important. When this works: (1) Internal functions are implementation details. (2) Public API sufficient for coverage. (3) Refactoring internal code often—don't want brittle tests. Same-package testing (white-box): package math; func TestAdd(t *testing.T) { result := add(2, 3); assert.Equal(t, 5, result) }—direct access to unexported add(). When to use: (1) Complex internal logic—need thorough edge case testing. (2) Performance-critical path—benchmark internal function. (3) Shared helpers across package—test utility functions. (4) Table-driven tests for internal states. Export for testing (anti-pattern but pragmatic): func add(a, b int) int—unexported. var Add = add—exported alias for testing. Discouraged: pollutes API, indicates poor design (extract to separate package?). Should you test unexported? Depends: (1) Simple functions—no, covered by integration tests. (2) Complex logic—yes, test directly for clarity. (3) Stateful code—yes, test internal state changes. Best practice: start with black-box tests, add white-box only when needed. Coverage: high coverage via exported tests = good design. Need white-box for coverage = maybe refactor. Extract to package: internal complex code → separate internal package, export there, test normally. Go testing philosophy: test behavior not implementation—means prefer exported testing. Caveat: 100% coverage via exported tests might require convoluted test cases—pragmatically test unexported when simpler."
  - question: "How do I mock dependencies for testing, and what are the best practices for testable code?"
    answer: "Use interfaces for dependencies, inject mocks in tests—Go's implicit interfaces make mocking natural without frameworks. Dependency injection pattern: type UserService struct { repo UserRepository }; type UserRepository interface { FindByID(id int) (*User, error) }. Production: repo := &PostgresUserRepository{db: db}; svc := &UserService{repo: repo}. Test: mock := &MockUserRepository{users: map[int]*User{1: testUser}}; svc := &UserService{repo: mock}—inject mock. Mock implementation: type MockUserRepository struct { users map[int]*User; findByIDCalled bool }; func (m *MockUserRepository) FindByID(id int) (*User, error) { m.findByIDCalled = true; if user, ok := m.users[id]; ok { return user, nil }; return nil, ErrNotFound }—manual mock, simple. Testing: func TestGetUser(t *testing.T) { mock := &MockUserRepository{users: map[int]*User{1: {Name: \"Alice\"}}}; svc := &UserService{repo: mock}; user, err := svc.GetUser(1); assert.NoError(t, err); assert.Equal(t, \"Alice\", user.Name); assert.True(t, mock.findByIDCalled) }. Mock libraries: (1) testify/mock: type MockRepo struct { mock.Mock }; func (m *MockRepo) FindByID(id int) (*User, error) { args := m.Called(id); return args.Get(0).(*User), args.Error(1) }. Setup: mock.On(\"FindByID\", 1).Return(testUser, nil). Verify: mock.AssertExpectations(t). (2) gomock (Google): mockgen generates mocks from interface, strong typing, compile-time safety. When to mock: (1) External dependencies: database, HTTP API, S3. (2) Slow operations: network calls, file I/O. (3) Non-deterministic: time.Now(), random. What NOT to mock: (1) Simple types (string, int)—pass real values. (2) Standard library (io.Reader)—use bytes.Buffer, strings.Reader. (3) Value objects—create real instances. Testable code principles: (1) Depend on interfaces, not concrete types. (2) Constructor injection: NewUserService(repo UserRepository)—explicit dependencies. (3) Avoid global state: global DB connection—hard to mock. (4) Small interfaces: 1-2 methods each—easy to mock. Anti-pattern: mocking everything—fragile tests coupled to implementation. Best practice: mock boundaries (external I/O), use real objects internally (business logic). Integration tests: use real dependencies (test database), fewer mocks—test realistic scenarios."
  - question: "What does code coverage mean, what's a good target, and can I have too much coverage?"
    answer: "Coverage = percentage of code executed during tests. High coverage ≠ good tests, low coverage = gaps. Target: 70-80% for most projects, focus on quality over percentage. Measure coverage: go test -cover—shows overall percentage. Detailed: go test -coverprofile=coverage.out; go tool cover -html=coverage.out—HTML report highlights uncovered lines (red). What coverage measures: (1) Statement coverage: how many lines executed. (2) NOT branch coverage: doesn't check if/else both paths tested. (3) NOT condition coverage: a && b might execute but not test a=true,b=false. Example: func Abs(x int) int { if x < 0 { return -x }; return x }. Test: Abs(5)—50% coverage (only return x). Abs(-5)—other 50%. Both: 100%. Good coverage target: (1) Critical paths: 90-100%—payment, security, data loss prevention. (2) Business logic: 80-90%—core features. (3) Utils/helpers: 70-80%. (4) UI code: 50-60%—harder to test, less critical. (5) Main/cmd: 0-30%—integration tested. When coverage is low: (1) Error handling—happy path tested, errors ignored. (2) Edge cases—null, empty, max values. (3) Branches—only one side of if. When high coverage misleading: (1) Assertion-free tests: func TestProcess(t *testing.T) { Process() }—executes code but no assertions, useless. (2) Trivial coverage: testing getters/setters—100% coverage, 0 value. (3) False security: 95% coverage but missing critical bug in 5%. Can you have too much coverage: Yes! (1) Diminishing returns: 95% → 100% costs weeks, tests brittle code (error messages, logging). (2) Over-specification: testing implementation not behavior—refactoring breaks tests. (3) Maintenance burden: 1000 brittle tests slow development. Best practice: (1) Cover critical business logic thoroughly. (2) Test edge cases and errors. (3) Skip trivial code (getters, constructors). (4) Focus on test quality: good assertions, clear intent. (5) Use coverage to find gaps, not as goal. Red flags: (1) Coverage drops after refactoring—tests too coupled to implementation. (2) 100% coverage but bug in production—missing edge case. (3) Adding test to hit coverage target without value—waste. Tools: go test -coverprofile, gocov, coveralls—track over time in CI. Production: enforce minimum (e.g., 70%) in CI, fail PR if drops. Don't worship metric—measure test quality: mutation testing, how many bugs caught in code review."
---

Testing is one of the most important parts of software development, yet often overlooked. In Go, testing is not an afterthought — it's built into the language itself through the powerful and easy-to-use `testing` package. Whether you're building a web app, API, or CLI tool, writing tests will help you catch bugs early, document your code, and refactor safely.

This article will help you understand:

*   Why testing matters in software development
*   The basics of writing tests in Go
*   Using `t.Error`, `t.Fail`, and `t.Fatal`
*   Table-driven tests
*   Running and understanding test results
*   Measuring code coverage
*   Best practices for writing useful tests

Why Testing is Important
------------------------

Testing helps you ensure that your code works as expected — not just today, but as it evolves. Without tests, it's risky to make changes because you can't be confident you haven't broken something.

Benefits of testing include:

*   Preventing bugs before reaching production
*   Providing documentation for your code's behavior
*   Making code easier to refactor
*   Enabling safe collaboration within teams

Getting Started: Writing Your First Test
----------------------------------------

In Go, a test file must end with `_test.go` and be in the same package as the code you want to test.

Let’s say you have a simple math function:

```go
package calculator

func Add(a, b int) int {
    return a + b
} 
```

Your test file could look like this:

```go
package calculator

import "testing"

func TestAdd(t *testing.T) {
    result := Add(2, 3)
    expected := 5

    if result != expected {
        t.Errorf("Add(2, 3) = %d; want %d", result, expected)
    }
} 
```

Understanding t.Error, t.Fail, and t.Fatal
------------------------------------------

*   `t.Error`: reports an error but continues running the test
*   `t.Fatal`: reports an error and immediately stops the test
*   `t.Fail`: marks the test as failed but doesn’t log a message

Table-Driven Tests
------------------

This is a common Go pattern for testing multiple cases in a clean way:

```go
func TestAddMultipleCases(t *testing.T) {
    tests := []struct {
        a, b     int
        expected int
    }{
        {1, 2, 3},
        {0, 0, 0},
        {-1, -1, -2},
    }

    for _, tt := range tests {
        result := Add(tt.a, tt.b)
        if result != tt.expected {
            t.Errorf("Add(%d, %d) = %d; want %d", tt.a, tt.b, result, tt.expected)
        }
    }
} 
```

Running Tests
-------------

To run all tests in a package, use:

```bash
go test
```

To see detailed output:

```bash
go test -v
```

Code Coverage
-------------

Want to know how much of your code is tested?

```bash
go test -cover
```

You can even generate an HTML report:

```bash
go test -coverprofile=coverage.out
go tool cover -html=coverage.out
```

Where to Put Tests
------------------

It’s a good practice to place tests right next to the code they are testing. This makes them easy to find and maintain. Use the same package name unless you’re doing black-box testing.

Best Practices
--------------

*   Write tests as you write code, not after
*   Use table-driven tests to cover edge cases
*   Make your test failures readable (clear messages)
*   Group related logic into subtests using `t.Run`
*   Keep test functions short and focused

Conclusion
----------

Testing is not just a formality — it’s a mindset. Go makes it easy to write fast, reliable tests without third-party tools. By integrating testing into your daily development flow, you’ll gain confidence, spot bugs earlier, and create better software.

In the next topic, we'll explore how to [benchmark]({{< relref "blog/go/benchmarking-in-go-measuring-performance-with-testingb.md" >}}) Go code and write performance tests.

Keep testing and happy coding!