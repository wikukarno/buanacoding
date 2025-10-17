---
title: "How to Use Mock Testing in Go with Testify and Mockery - Complete Guide"
description: "Learn how to implement mock testing in Go using Testify and Mockery. Complete tutorial covering dependency injection, mock generation, test assertions, and best practices for testable Go applications."
date: 2025-10-17T09:00:00+07:00
tags: ["Go", "Testing", "Mocking", "Testify", "Mockery", "Unit Testing"]
draft: false
author: "Wiku Karno"
keywords: ["Go mock testing", "Golang testify tutorial", "mockery Go", "unit testing Go", "dependency injection Go", "mock interfaces Go", "testify assert", "Go testing best practices"]
url: /2025/10/how-to-use-mock-testing-in-go-with-testify-and-mockery.html
faq:
  - question: "What is mocking in Go and why is it important for testing?"
    answer: "Mocking replaces real dependencies with fake implementations during testing, allowing you to test code in isolation without external dependencies like databases, APIs, or file systems. This makes tests faster, more reliable, and easier to write since you control the behavior of dependencies. Mocks verify that your code calls dependencies correctly and handles their responses properly, focusing tests on the specific unit being tested."
  - question: "What is the difference between Testify and Mockery in Go testing?"
    answer: "Testify is a testing toolkit that provides assertion functions (Equal, NoError, Contains) and mock capabilities through testify/mock. Mockery is a code generation tool that automatically creates mock implementations from Go interfaces. Testify provides the framework for assertions and manual mocking, while Mockery generates the boilerplate mock code for you. Most projects use both: Mockery to generate mocks and Testify for assertions and mock expectations."
  - question: "How do I structure Go code to make it testable with mocks?"
    answer: "Design code around interfaces instead of concrete types, use dependency injection to pass dependencies through constructors or function parameters, avoid global variables and singletons, and keep interfaces small with focused responsibilities. Define interfaces in the package that uses them, not where they're implemented. This allows easy mock injection during tests while production code uses real implementations."
  - question: "Should I mock everything in my tests or only external dependencies?"
    answer: "Mock only external boundaries like databases, HTTP clients, file systems, and third-party APIs. Don't mock simple value types, standard library types (use real bytes.Buffer instead), or your own business logic. Over-mocking creates brittle tests coupled to implementation details. Use real implementations for internal code and mock at the system boundaries where your application interacts with external services."
  - question: "How do I verify that mocked methods were called correctly?"
    answer: "Use Testify's mock.AssertExpectations(t) to verify all expected method calls occurred, mock.AssertCalled(t, methodName, args...) to check specific calls, and mock.AssertNotCalled(t, methodName) to ensure methods weren't called. Set up expectations with mock.On(methodName, args).Return(values) before calling the code under test. The mock tracks all calls and validates them match your expectations when assertions run."
  - question: "What are the best practices for mock testing in Go?"
    answer: "Keep mocks simple and focused on one behavior per test, avoid over-specifying implementation details, test behavior not implementation, use table-driven tests with different mock scenarios, clean up mocks with t.Cleanup(), prefer interface-based design over concrete types, generate mocks with Mockery instead of writing manually, and balance unit tests with mocks against integration tests with real dependencies for complete coverage."
---

Testing individual units of code in isolation is critical for building reliable software. When your code depends on databases, external APIs, or other services, testing becomes complex and slow. Mock testing solves this by replacing real dependencies with controlled fake implementations, allowing you to test your code quickly without external systems.

This guide demonstrates how to implement effective mock testing in Go using Testify and Mockery. You'll learn to design testable code with interfaces, generate mocks automatically with Mockery, write assertions with Testify, verify method calls and return values, implement table-driven mock tests, and follow best practices that create maintainable test suites without over-mocking.

## Understanding Mock Testing and When to Use It

Mock testing replaces real dependencies with fake objects that simulate behavior during tests. When your UserService needs a database, instead of connecting to PostgreSQL, you provide a mock that returns predefined data. This isolates the test to only the UserService logic, making tests faster and more focused.

Mocks serve two purposes: they provide controlled responses to method calls, and they verify that your code calls dependencies correctly. A mock database can return specific test data and confirm that your code executed the right query with correct parameters. This dual nature makes mocks effective for testing both behavior and interactions.

Use mocks for external boundaries where your application interacts with systems you don't control. Database connections, HTTP clients, cloud service SDKs, and file system operations should be mocked in unit tests. These dependencies are slow, require setup, and introduce non-determinism that makes tests flaky.

Don't mock everything. Use real implementations for simple types, your own business logic, and internal functions. Over-mocking creates tests coupled to implementation details that break during refactoring. The goal is testing behavior, not implementation, so mock at system boundaries and use real code internally.

## Installing Testify and Mockery

Install the Testify testing toolkit which provides assertions, mocking capabilities, and test utilities.

```bash
go get github.com/stretchr/testify
```

Testify includes several useful packages:
- `testify/assert`: Assertion functions for tests
- `testify/require`: Assertions that stop test on failure
- `testify/mock`: Manual mocking framework
- `testify/suite`: Test suite support

Install Mockery to automatically generate mock implementations from interfaces.

```bash
go install github.com/vektra/mockery/v2@latest
```

Verify Mockery installed correctly:

```bash
mockery --version
```

Create a `.mockery.yaml` configuration file in your project root to configure mock generation behavior.

```yaml
with-expecter: true
dir: "mocks"
outpkg: mocks
filename: "mock_{{.InterfaceName}}.go"
all: true
keeptree: false
```

This configuration generates mocks with expecter pattern (type-safe expectations), places them in a `mocks` directory, and processes all interfaces in the project.

## Designing Testable Code with Interfaces

Design code around interfaces to enable dependency injection and mocking. Define what your code needs, not how it's implemented.

```go
// internal/repository/user.go
package repository

import (
	"context"
	"time"
)

type User struct {
	ID        int       `json:"id"`
	Email     string    `json:"email"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}

type UserRepository interface {
	FindByID(ctx context.Context, id int) (*User, error)
	FindByEmail(ctx context.Context, email string) (*User, error)
	Create(ctx context.Context, user *User) error
	Update(ctx context.Context, user *User) error
	Delete(ctx context.Context, id int) error
}
```

The interface defines the contract without specifying implementation. This allows testing code that depends on UserRepository without a real database.

Implement the interface with a real database adapter for production use.

```go
// internal/repository/postgres_user_repository.go
package repository

import (
	"context"
	"database/sql"
	"fmt"
)

type PostgresUserRepository struct {
	db *sql.DB
}

func NewPostgresUserRepository(db *sql.DB) *PostgresUserRepository {
	return &PostgresUserRepository{db: db}
}

func (r *PostgresUserRepository) FindByID(ctx context.Context, id int) (*User, error) {
	query := "SELECT id, email, name, created_at FROM users WHERE id = $1"

	var user User
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&user.ID, &user.Email, &user.Name, &user.CreatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found")
	}

	if err != nil {
		return nil, fmt.Errorf("failed to find user: %w", err)
	}

	return &user, nil
}

func (r *PostgresUserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	query := "SELECT id, email, name, created_at FROM users WHERE email = $1"

	var user User
	err := r.db.QueryRowContext(ctx, query, email).Scan(
		&user.ID, &user.Email, &user.Name, &user.CreatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found")
	}

	if err != nil {
		return nil, fmt.Errorf("failed to find user: %w", err)
	}

	return &user, nil
}

func (r *PostgresUserRepository) Create(ctx context.Context, user *User) error {
	query := "INSERT INTO users (email, name, created_at) VALUES ($1, $2, $3) RETURNING id"

	err := r.db.QueryRowContext(ctx, query, user.Email, user.Name, time.Now()).Scan(&user.ID)
	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}

	return nil
}

func (r *PostgresUserRepository) Update(ctx context.Context, user *User) error {
	query := "UPDATE users SET email = $1, name = $2 WHERE id = $3"

	_, err := r.db.ExecContext(ctx, query, user.Email, user.Name, user.ID)
	if err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}

	return nil
}

func (r *PostgresUserRepository) Delete(ctx context.Context, id int) error {
	query := "DELETE FROM users WHERE id = $1"

	_, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	return nil
}
```

Create a service that depends on the interface, not the concrete implementation. This enables injecting mocks during testing.

```go
// internal/service/user_service.go
package service

import (
	"context"
	"fmt"
	"strings"

	"yourapp/internal/repository"
)

type UserService struct {
	repo repository.UserRepository
}

func NewUserService(repo repository.UserRepository) *UserService {
	return &UserService{repo: repo}
}

func (s *UserService) GetUser(ctx context.Context, id int) (*repository.User, error) {
	if id <= 0 {
		return nil, fmt.Errorf("invalid user ID")
	}

	user, err := s.repo.FindByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return user, nil
}

func (s *UserService) RegisterUser(ctx context.Context, email, name string) (*repository.User, error) {
	email = strings.TrimSpace(strings.ToLower(email))
	name = strings.TrimSpace(name)

	if email == "" || name == "" {
		return nil, fmt.Errorf("email and name are required")
	}

	if !strings.Contains(email, "@") {
		return nil, fmt.Errorf("invalid email format")
	}

	existingUser, err := s.repo.FindByEmail(ctx, email)
	if err == nil && existingUser != nil {
		return nil, fmt.Errorf("email already exists")
	}

	user := &repository.User{
		Email: email,
		Name:  name,
	}

	if err := s.repo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	return user, nil
}

func (s *UserService) UpdateUserEmail(ctx context.Context, userID int, newEmail string) error {
	newEmail = strings.TrimSpace(strings.ToLower(newEmail))

	if !strings.Contains(newEmail, "@") {
		return fmt.Errorf("invalid email format")
	}

	user, err := s.repo.FindByID(ctx, userID)
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}

	existingUser, err := s.repo.FindByEmail(ctx, newEmail)
	if err == nil && existingUser != nil && existingUser.ID != userID {
		return fmt.Errorf("email already in use")
	}

	user.Email = newEmail

	if err := s.repo.Update(ctx, user); err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}

	return nil
}

func (s *UserService) DeleteUser(ctx context.Context, userID int) error {
	if userID <= 0 {
		return fmt.Errorf("invalid user ID")
	}

	if err := s.repo.Delete(ctx, userID); err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	return nil
}
```

UserService depends on the UserRepository interface, not PostgresUserRepository. Production code injects the real implementation, while tests inject mocks.

## Generating Mocks with Mockery

Run Mockery to generate mock implementations for all interfaces in your project.

```bash
mockery
```

Mockery scans your code for interfaces and generates mock implementations in the `mocks` directory. For the UserRepository interface, it creates `mock_UserRepository.go`.

```go
// mocks/mock_UserRepository.go
package mocks

import (
	"context"
	"yourapp/internal/repository"

	"github.com/stretchr/testify/mock"
)

type MockUserRepository struct {
	mock.Mock
}

func (m *MockUserRepository) FindByID(ctx context.Context, id int) (*repository.User, error) {
	args := m.Called(ctx, id)

	if args.Get(0) == nil {
		return nil, args.Error(1)
	}

	return args.Get(0).(*repository.User), args.Error(1)
}

func (m *MockUserRepository) FindByEmail(ctx context.Context, email string) (*repository.User, error) {
	args := m.Called(ctx, email)

	if args.Get(0) == nil {
		return nil, args.Error(1)
	}

	return args.Get(0).(*repository.User), args.Error(1)
}

func (m *MockUserRepository) Create(ctx context.Context, user *repository.User) error {
	args := m.Called(ctx, user)
	return args.Error(0)
}

func (m *MockUserRepository) Update(ctx context.Context, user *repository.User) error {
	args := m.Called(ctx, user)
	return args.Error(0)
}

func (m *MockUserRepository) Delete(ctx context.Context, id int) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}
```

The generated mock implements UserRepository and tracks method calls. The `Called` method records invocations and returns configured values.

Generate mocks for specific interfaces instead of all:

```bash
mockery --name UserRepository
```

Regenerate mocks when interfaces change:

```bash
mockery --all
```

Add mock generation to your Makefile for convenient updates:

```makefile
.PHONY: mocks
mocks:
	mockery --all
```

## Writing Tests with Testify Assertions

Create tests that inject mocks and verify behavior using Testify assertions.

```go
// internal/service/user_service_test.go
package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"yourapp/internal/repository"
	"yourapp/mocks"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestUserService_GetUser_Success(t *testing.T) {
	mockRepo := new(mocks.MockUserRepository)
	service := NewUserService(mockRepo)

	ctx := context.Background()
	expectedUser := &repository.User{
		ID:        1,
		Email:     "test@example.com",
		Name:      "Test User",
		CreatedAt: time.Now(),
	}

	mockRepo.On("FindByID", ctx, 1).Return(expectedUser, nil)

	user, err := service.GetUser(ctx, 1)

	assert.NoError(t, err)
	assert.NotNil(t, user)
	assert.Equal(t, expectedUser.ID, user.ID)
	assert.Equal(t, expectedUser.Email, user.Email)
	assert.Equal(t, expectedUser.Name, user.Name)

	mockRepo.AssertExpectations(t)
}

func TestUserService_GetUser_NotFound(t *testing.T) {
	mockRepo := new(mocks.MockUserRepository)
	service := NewUserService(mockRepo)

	ctx := context.Background()

	mockRepo.On("FindByID", ctx, 999).Return(nil, errors.New("user not found"))

	user, err := service.GetUser(ctx, 999)

	assert.Error(t, err)
	assert.Nil(t, user)
	assert.Contains(t, err.Error(), "failed to get user")

	mockRepo.AssertExpectations(t)
}

func TestUserService_GetUser_InvalidID(t *testing.T) {
	mockRepo := new(mocks.MockUserRepository)
	service := NewUserService(mockRepo)

	ctx := context.Background()

	user, err := service.GetUser(ctx, 0)

	assert.Error(t, err)
	assert.Nil(t, user)
	assert.Contains(t, err.Error(), "invalid user ID")

	mockRepo.AssertNotCalled(t, "FindByID")
}
```

The test creates a mock repository, configures expected method calls with `On`, executes the service method, and verifies results with assertions. `AssertExpectations` confirms all expected calls occurred.

Testify provides many assertion functions:
- `assert.Equal(t, expected, actual)`: Values must be equal
- `assert.NotEqual(t, unexpected, actual)`: Values must differ
- `assert.NoError(t, err)`: No error occurred
- `assert.Error(t, err)`: Error occurred
- `assert.Nil(t, value)`: Value is nil
- `assert.NotNil(t, value)`: Value is not nil
- `assert.True(t, condition)`: Condition is true
- `assert.False(t, condition)`: Condition is false
- `assert.Contains(t, haystack, needle)`: String/slice contains value
- `assert.Len(t, list, length)`: Collection has specific length

Use `require` instead of `assert` when subsequent code depends on the assertion. Require stops the test immediately on failure, preventing panics from nil dereferences.

```go
func TestUserService_GetUser_WithRequire(t *testing.T) {
	mockRepo := new(mocks.MockUserRepository)
	service := NewUserService(mockRepo)

	ctx := context.Background()
	expectedUser := &repository.User{ID: 1, Email: "test@example.com", Name: "Test User"}

	mockRepo.On("FindByID", ctx, 1).Return(expectedUser, nil)

	user, err := service.GetUser(ctx, 1)

	require.NoError(t, err)
	require.NotNil(t, user)

	assert.Equal(t, expectedUser.Email, user.Email)

	mockRepo.AssertExpectations(t)
}
```

## Implementing Table-Driven Mock Tests

Table-driven tests handle multiple scenarios with different mock behaviors efficiently.

```go
func TestUserService_RegisterUser(t *testing.T) {
	tests := []struct {
		name          string
		email         string
		userName      string
		setupMock     func(*mocks.MockUserRepository)
		expectError   bool
		errorContains string
	}{
		{
			name:     "successful registration",
			email:    "new@example.com",
			userName: "New User",
			setupMock: func(m *mocks.MockUserRepository) {
				m.On("FindByEmail", mock.Anything, "new@example.com").Return(nil, errors.New("not found"))
				m.On("Create", mock.Anything, mock.AnythingOfType("*repository.User")).Return(nil)
			},
			expectError: false,
		},
		{
			name:     "email already exists",
			email:    "existing@example.com",
			userName: "Existing User",
			setupMock: func(m *mocks.MockUserRepository) {
				existingUser := &repository.User{ID: 1, Email: "existing@example.com"}
				m.On("FindByEmail", mock.Anything, "existing@example.com").Return(existingUser, nil)
			},
			expectError:   true,
			errorContains: "email already exists",
		},
		{
			name:          "empty email",
			email:         "",
			userName:      "User",
			setupMock:     func(m *mocks.MockUserRepository) {},
			expectError:   true,
			errorContains: "email and name are required",
		},
		{
			name:          "invalid email format",
			email:         "invalid-email",
			userName:      "User",
			setupMock:     func(m *mocks.MockUserRepository) {},
			expectError:   true,
			errorContains: "invalid email format",
		},
		{
			name:     "database error on create",
			email:    "test@example.com",
			userName: "Test User",
			setupMock: func(m *mocks.MockUserRepository) {
				m.On("FindByEmail", mock.Anything, "test@example.com").Return(nil, errors.New("not found"))
				m.On("Create", mock.Anything, mock.AnythingOfType("*repository.User")).Return(errors.New("database error"))
			},
			expectError:   true,
			errorContains: "failed to create user",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockRepo := new(mocks.MockUserRepository)
			service := NewUserService(mockRepo)

			tt.setupMock(mockRepo)

			user, err := service.RegisterUser(context.Background(), tt.email, tt.userName)

			if tt.expectError {
				assert.Error(t, err)
				assert.Nil(t, user)
				if tt.errorContains != "" {
					assert.Contains(t, err.Error(), tt.errorContains)
				}
			} else {
				assert.NoError(t, err)
				assert.NotNil(t, user)
				assert.Equal(t, tt.email, user.Email)
				assert.Equal(t, tt.userName, user.Name)
			}

			mockRepo.AssertExpectations(t)
		})
	}
}
```

Each test case defines a scenario with specific inputs and mock behavior. The `setupMock` function configures the mock for that scenario, isolating test setup from execution.

## Verifying Method Call Arguments

Use argument matchers to verify methods receive correct parameters without specifying exact values.

```go
func TestUserService_UpdateUserEmail(t *testing.T) {
	mockRepo := new(mocks.MockUserRepository)
	service := NewUserService(mockRepo)

	ctx := context.Background()
	existingUser := &repository.User{
		ID:    1,
		Email: "old@example.com",
		Name:  "Test User",
	}

	mockRepo.On("FindByID", ctx, 1).Return(existingUser, nil)
	mockRepo.On("FindByEmail", ctx, "new@example.com").Return(nil, errors.New("not found"))
	mockRepo.On("Update", ctx, mock.MatchedBy(func(u *repository.User) bool {
		return u.ID == 1 && u.Email == "new@example.com"
	})).Return(nil)

	err := service.UpdateUserEmail(ctx, 1, "new@example.com")

	assert.NoError(t, err)
	mockRepo.AssertExpectations(t)
}
```

`mock.MatchedBy` takes a function that validates argument properties. This verifies the service passes a user with correct ID and updated email without requiring exact object matching.

Common argument matchers:
- `mock.Anything`: Accepts any value
- `mock.AnythingOfType("string")`: Accepts any value of specific type
- `mock.MatchedBy(func(x Type) bool { ... })`: Custom validation function

Verify specific method calls occurred:

```go
func TestUserService_DeleteUser(t *testing.T) {
	mockRepo := new(mocks.MockUserRepository)
	service := NewUserService(mockRepo)

	ctx := context.Background()

	mockRepo.On("Delete", ctx, 1).Return(nil)

	err := service.DeleteUser(ctx, 1)

	assert.NoError(t, err)
	mockRepo.AssertCalled(t, "Delete", ctx, 1)
}
```

`AssertCalled` verifies the method was called with specific arguments, useful when you want to confirm interactions without setting up expectations.

## Handling Multiple Return Values and Errors

Configure mocks to return different values based on arguments or call count.

```go
func TestUserService_RetryLogic(t *testing.T) {
	mockRepo := new(mocks.MockUserRepository)
	service := NewUserService(mockRepo)

	ctx := context.Background()

	mockRepo.On("FindByID", ctx, 1).Return(nil, errors.New("temporary error")).Once()
	mockRepo.On("FindByID", ctx, 1).Return(&repository.User{ID: 1, Email: "test@example.com"}, nil).Once()

	_, err := service.GetUser(ctx, 1)
	assert.Error(t, err)

	user, err := service.GetUser(ctx, 1)
	assert.NoError(t, err)
	assert.NotNil(t, user)

	mockRepo.AssertExpectations(t)
}
```

The first call returns an error, the second succeeds. `Once()` specifies the expectation applies to one call, allowing different behaviors for subsequent calls.

Return values based on input:

```go
func TestUserService_DynamicMockBehavior(t *testing.T) {
	mockRepo := new(mocks.MockUserRepository)
	service := NewUserService(mockRepo)

	ctx := context.Background()

	mockRepo.On("FindByID", ctx, mock.AnythingOfType("int")).Return(
		func(ctx context.Context, id int) *repository.User {
			if id == 1 {
				return &repository.User{ID: 1, Email: "user1@example.com"}
			}
			return nil
		},
		func(ctx context.Context, id int) error {
			if id == 1 {
				return nil
			}
			return errors.New("not found")
		},
	)

	user1, err := service.GetUser(ctx, 1)
	assert.NoError(t, err)
	assert.Equal(t, "user1@example.com", user1.Email)

	user2, err := service.GetUser(ctx, 2)
	assert.Error(t, err)
	assert.Nil(t, user2)
}
```

Functions as return values enable dynamic behavior based on arguments, useful for testing edge cases without creating multiple expectations.

## Testing with Multiple Dependencies

Services often depend on multiple interfaces. Mock each dependency independently.

```go
type NotificationService interface {
	SendEmail(ctx context.Context, to, subject, body string) error
}

type UserService struct {
	repo         repository.UserRepository
	notification NotificationService
}

func NewUserService(repo repository.UserRepository, notification NotificationService) *UserService {
	return &UserService{
		repo:         repo,
		notification: notification,
	}
}

func (s *UserService) RegisterUserWithNotification(ctx context.Context, email, name string) (*repository.User, error) {
	user, err := s.RegisterUser(ctx, email, name)
	if err != nil {
		return nil, err
	}

	err = s.notification.SendEmail(ctx, email, "Welcome!", "Thanks for registering")
	if err != nil {
		return user, fmt.Errorf("user created but notification failed: %w", err)
	}

	return user, nil
}
```

Test with multiple mocks:

```go
func TestUserService_RegisterUserWithNotification(t *testing.T) {
	mockRepo := new(mocks.MockUserRepository)
	mockNotification := new(mocks.MockNotificationService)
	service := NewUserService(mockRepo, mockNotification)

	ctx := context.Background()

	mockRepo.On("FindByEmail", ctx, "test@example.com").Return(nil, errors.New("not found"))
	mockRepo.On("Create", ctx, mock.AnythingOfType("*repository.User")).Return(nil)
	mockNotification.On("SendEmail", ctx, "test@example.com", "Welcome!", "Thanks for registering").Return(nil)

	user, err := service.RegisterUserWithNotification(ctx, "test@example.com", "Test User")

	assert.NoError(t, err)
	assert.NotNil(t, user)

	mockRepo.AssertExpectations(t)
	mockNotification.AssertExpectations(t)
}
```

Each mock tracks its own expectations independently. This tests the integration between service and multiple dependencies while keeping tests isolated.

## Best Practices for Mock Testing

Keep mocks simple and focused. Each test should verify one behavior with minimal mock setup. Complex mocks indicate the code under test does too much.

Don't over-specify implementation details. Mock the interface contract, not internal implementation. Tests should pass after refactoring if behavior stays the same.

Use table-driven tests for multiple scenarios. This reduces duplication and makes adding test cases straightforward.

Clean up mocks properly:

```go
func TestUserService_WithCleanup(t *testing.T) {
	mockRepo := new(mocks.MockUserRepository)
	t.Cleanup(func() {
		mockRepo.AssertExpectations(t)
	})

	service := NewUserService(mockRepo)

	mockRepo.On("FindByID", mock.Anything, 1).Return(&repository.User{ID: 1}, nil)

	user, err := service.GetUser(context.Background(), 1)

	assert.NoError(t, err)
	assert.NotNil(t, user)
}
```

`t.Cleanup` ensures expectations are verified even if the test panics or returns early.

Generate mocks instead of writing manually. Mockery keeps mocks synchronized with interface changes and reduces maintenance burden.

Balance unit tests with mocks against integration tests with real dependencies. Unit tests verify logic quickly, integration tests ensure components work together correctly. Most projects need both for good coverage.

Avoid mocking standard library types. Use real implementations like `bytes.Buffer` for `io.Writer` or `httptest.NewRecorder` for HTTP handlers. These are designed for testing and work better than mocks.

## Common Pitfalls and How to Avoid Them

Forgetting `AssertExpectations` causes tests to pass even when expected calls don't occur. Always call it at the end of tests or in `t.Cleanup`.

Loop variable capture in table-driven tests causes all subtests to use the last value:

```go
for _, tt := range tests {
	tt := tt
	t.Run(tt.name, func(t *testing.T) {
		// Use tt here
	})
}
```

The `tt := tt` line captures the loop variable for each iteration.

Mocking too much creates brittle tests coupled to implementation. Mock external boundaries, use real code internally.

Not using `mock.Anything` for context arguments makes tests verbose:

```go
mockRepo.On("FindByID", mock.Anything, 1).Return(user, nil)
```

Context values rarely matter for business logic tests, so `mock.Anything` simplifies setup.

Parallel tests with shared mocks cause race conditions. Each test needs its own mock instance:

```go
t.Run("test", func(t *testing.T) {
	t.Parallel()
	mockRepo := new(mocks.MockUserRepository)
	// Use mockRepo
})
```

## Integrating Mock Tests into CI/CD

Run tests with coverage reporting in CI pipelines:

```bash
go test ./... -cover -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html
```

Configure GitHub Actions to run tests on every push:

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      - name: Install dependencies
        run: go mod download
      - name: Generate mocks
        run: |
          go install github.com/vektra/mockery/v2@latest
          mockery --all
      - name: Run tests
        run: go test ./... -v -cover
```

This ensures mocks stay current and tests pass before merging code.

## Conclusion

Mock testing enables fast, reliable unit tests by isolating code from external dependencies. Testify provides assertions and mocking capabilities that make tests readable and maintainable, while Mockery generates mock implementations automatically, reducing boilerplate and keeping mocks synchronized with interfaces.

Designing code around interfaces and dependency injection creates testable architecture that separates concerns and enables mock injection during tests. Mock external boundaries like databases and APIs while using real implementations for business logic, balancing isolation with realistic testing.

Remember that mocking is a tool, not a goal. Tests should verify behavior, not implementation details. Combine unit tests with mocks against integration tests with real dependencies for complete coverage. This approach catches logic bugs early through fast unit tests while ensuring components integrate correctly through slower but more realistic integration tests.

The patterns demonstrated here work for any Go application, from web services to CLI tools. Apply these techniques to your projects, generate mocks for your interfaces, write clear assertions, and build test suites that give confidence in your code without slowing development.
