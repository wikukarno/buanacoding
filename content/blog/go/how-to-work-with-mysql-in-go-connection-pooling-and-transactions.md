---
title: "How to Work with MySQL in Go - Connection Pooling and Transactions Guide"
description: "Learn how to work with MySQL in Go using database/sql and connection pooling. Complete tutorial covering MySQL setup, CRUD operations, connection management, transactions, prepared statements, and production best practices."
date: 2025-10-17T10:00:00+07:00
tags: ["Go", "MySQL", "Database", "Connection Pooling", "Transactions", "SQL"]
draft: false
author: "Wiku Karno"
keywords: ["Go MySQL tutorial", "Golang MySQL connection", "MySQL connection pooling Go", "database transactions Go", "Go database/sql", "MySQL prepared statements", "Go CRUD MySQL", "production MySQL Go"]
url: /2025/10/how-to-work-with-mysql-in-go-connection-pooling-and-transactions.html
faq:
  - question: "Why use database/sql instead of an ORM like GORM for MySQL in Go?"
    answer: "database/sql provides direct SQL control with minimal overhead, making it ideal for performance-critical applications and teams comfortable with SQL. You write explicit queries, see exactly what executes, and maintain full control over optimization. ORMs like GORM add convenience through code generation and relationships but introduce query generation overhead and potential N+1 problems. Use database/sql when performance matters, queries are complex, or you want predictable database behavior. Use ORMs for rapid development and when developer productivity outweighs raw performance."
  - question: "How do I configure MySQL connection pooling correctly in Go?"
    answer: "Configure connection pooling with SetMaxOpenConns, SetMaxIdleConns, and SetConnMaxLifetime to control pool behavior. SetMaxOpenConns limits total connections (default unlimited, can exhaust MySQL), SetMaxIdleConns keeps connections ready for reuse (reduces connection overhead), and SetConnMaxLifetime recycles old connections (prevents stale connections). Recommended production settings: SetMaxOpenConns(25), SetMaxIdleConns(5), SetConnMaxLifetime(5 minutes), SetConnMaxIdleTime(10 minutes). Formula: max_open = MySQL max_connections / number_of_instances. Monitor with db.Stats() to track pool usage and tune based on actual load."
  - question: "What is the difference between Query, QueryRow, Exec, and Prepare in Go MySQL?"
    answer: "Query returns multiple rows for SELECT statements requiring iteration, QueryRow returns single row for queries expecting one result, Exec executes statements that don't return rows (INSERT, UPDATE, DELETE) and returns affected row count, and Prepare creates reusable prepared statements for repeated execution. Use Query for lists and multiple results, QueryRow for single record lookups, Exec for data modifications, and Prepare for queries executed many times in loops. Always call rows.Close() after Query, and stmt.Close() after Prepare to prevent connection leaks."
  - question: "How do I handle NULL values from MySQL columns in Go?"
    answer: "Go primitive types can't represent NULL, causing scan errors. Use sql.Null types (sql.NullString, sql.NullInt64, sql.NullBool, sql.NullFloat64, sql.NullTime) which have Valid and Value fields, or use pointers where nil represents NULL. sql.Null types provide explicit NULL handling: check Valid field before accessing Value. Pointers are simpler but require nil checks. For JSON APIs, both marshal correctly: sql.NullString as null or string value, pointers as null or value. Choose sql.Null types for explicit NULL semantics or pointers for simplicity."
  - question: "How do I implement transactions in Go to ensure data consistency?"
    answer: "Use db.Begin() to start transaction, execute queries with tx.Exec/Query methods, and call tx.Commit() on success or tx.Rollback() on error. Always defer tx.Rollback() after Begin() - it's safe to call after Commit (becomes no-op) and ensures rollback on panic or early return. Transactions provide ACID guarantees: all operations succeed together or all fail. Keep transactions short to avoid holding locks, use context with timeout to prevent hanging transactions, and handle deadlock errors (MySQL error 1213) by retrying. Monitor transaction duration in production to identify lock contention issues."
  - question: "What are the best practices for MySQL connection management in production Go applications?"
    answer: "Use single global db instance shared across application (db connections are thread-safe), configure appropriate pool limits based on load and MySQL max_connections, always close rows and statements to prevent leaks, use context with timeout for all database operations, implement health checks with db.Ping(), and monitor connection pool stats with db.Stats(). Enable connection timeouts in DSN, use prepared statements for repeated queries, handle connection errors with retry logic, and log slow queries for optimization. Scale horizontally by adjusting pool size per instance rather than increasing single instance limits."
---

MySQL remains one of the most popular relational databases for web applications. Go provides excellent MySQL support through the database/sql package and MySQL driver. Understanding connection pooling and transactions is critical for building production-ready applications that handle concurrent users efficiently while maintaining data consistency.

This guide demonstrates how to work with MySQL in Go effectively. You'll learn to connect to MySQL with proper driver configuration, implement CRUD operations with prepared statements, configure connection pooling for optimal performance, handle transactions correctly to maintain data integrity, manage NULL values and error conditions, and apply production best practices that scale.

## Understanding Go's database/sql Package

Go's database/sql package provides a generic interface for working with SQL databases. It handles connection pooling automatically, supports prepared statements, and provides transaction management. The package defines the interface while specific drivers implement MySQL protocol details.

The database/sql design separates interface from implementation. Your code imports database/sql for types and methods, while the MySQL driver registers itself during initialization. This separation allows switching databases by changing the driver import and connection string without modifying query code.

Connection pooling happens transparently. When you call db.Query(), the pool provides an available connection, executes the query, and returns the connection to the pool. You don't manually manage connections - the pool handles creation, reuse, and cleanup based on configuration.

The package is safe for concurrent use. Multiple goroutines can execute queries simultaneously using the same db instance. The pool manages connection distribution across goroutines, making it suitable for web servers handling many concurrent requests.

## Installing MySQL Driver and Dependencies

Install the Go MySQL driver that implements database/sql interfaces.

```bash
go get -u github.com/go-sql-driver/mysql
```

The go-sql-driver/mysql package is the most widely used MySQL driver for Go, supporting MySQL 5.5+, MariaDB, and Amazon Aurora. It implements the database/sql/driver interface and handles MySQL wire protocol details.

Create a new Go module if starting a fresh project:

```bash
mkdir mysql-example
cd mysql-example
go mod init mysql-example
go get github.com/go-sql-driver/mysql
```

The driver registers itself with database/sql through an init function. Import it with a blank identifier to execute initialization:

```go
import (
    "database/sql"
    _ "github.com/go-sql-driver/mysql"
)
```

The underscore import runs the driver's init function which registers "mysql" with database/sql without directly using exported identifiers from the driver package.

## Connecting to MySQL with Connection Pooling

Create a database connection with the MySQL driver using a Data Source Name (DSN) connection string.

```go
// main.go
package main

import (
    "database/sql"
    "fmt"
    "log"
    "time"

    _ "github.com/go-sql-driver/mysql"
)

type Config struct {
    Host     string
    Port     string
    User     string
    Password string
    Database string
}

func NewDB(cfg Config) (*sql.DB, error) {
    dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&timeout=10s",
        cfg.User,
        cfg.Password,
        cfg.Host,
        cfg.Port,
        cfg.Database,
    )

    db, err := sql.Open("mysql", dsn)
    if err != nil {
        return nil, fmt.Errorf("failed to open database: %w", err)
    }

    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(5 * time.Minute)
    db.SetConnMaxIdleTime(10 * time.Minute)

    if err := db.Ping(); err != nil {
        return nil, fmt.Errorf("failed to ping database: %w", err)
    }

    return db, nil
}

func main() {
    config := Config{
        Host:     "localhost",
        Port:     "3306",
        User:     "root",
        Password: "password",
        Database: "testdb",
    }

    db, err := NewDB(config)
    if err != nil {
        log.Fatalf("Database connection failed: %v", err)
    }
    defer db.Close()

    fmt.Println("Successfully connected to MySQL!")
}
```

The DSN includes critical parameters: `parseTime=true` converts MySQL DATETIME and TIMESTAMP to Go time.Time, while `timeout=10s` sets connection timeout preventing indefinite hangs.

Connection pool configuration controls resource usage:
- `SetMaxOpenConns(25)`: Maximum connections to MySQL (prevents exhausting server connections)
- `SetMaxIdleConns(5)`: Idle connections kept ready (reduces connection overhead)
- `SetConnMaxLifetime(5min)`: Recycles connections periodically (prevents stale connections)
- `SetConnMaxIdleTime(10min)`: Closes idle connections after inactivity (frees resources)

The `db.Ping()` call verifies connectivity immediately. Without this, `sql.Open()` defers connection until first query, delaying error detection.

## Creating Tables and Defining Models

Define database schema and corresponding Go structs for type-safe operations.

```go
// models.go
package main

import (
    "database/sql"
    "time"
)

type User struct {
    ID        int64     `json:"id"`
    Email     string    `json:"email"`
    Name      string    `json:"name"`
    Age       int       `json:"age"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt sql.NullTime `json:"updated_at"`
}

type Product struct {
    ID          int64          `json:"id"`
    Name        string         `json:"name"`
    Description sql.NullString `json:"description"`
    Price       float64        `json:"price"`
    Stock       int            `json:"stock"`
    CreatedAt   time.Time      `json:"created_at"`
}
```

Create tables in MySQL:

```sql
CREATE TABLE users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    age INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE products (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_name (name)
);

CREATE TABLE orders (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INT NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
```

The `sql.NullTime` and `sql.NullString` types handle nullable columns. NULL values can't map to regular Go types, requiring special handling.

## Implementing CRUD Operations

Create a repository pattern for database operations with proper error handling.

```go
// repository.go
package main

import (
    "context"
    "database/sql"
    "fmt"
    "time"
)

type UserRepository struct {
    db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
    return &UserRepository{db: db}
}

func (r *UserRepository) Create(ctx context.Context, user *User) error {
    query := `
        INSERT INTO users (email, name, age, created_at)
        VALUES (?, ?, ?, ?)
    `

    result, err := r.db.ExecContext(ctx, query, user.Email, user.Name, user.Age, time.Now())
    if err != nil {
        return fmt.Errorf("failed to create user: %w", err)
    }

    id, err := result.LastInsertId()
    if err != nil {
        return fmt.Errorf("failed to get last insert id: %w", err)
    }

    user.ID = id
    return nil
}

func (r *UserRepository) FindByID(ctx context.Context, id int64) (*User, error) {
    query := `
        SELECT id, email, name, age, created_at, updated_at
        FROM users
        WHERE id = ?
    `

    var user User
    err := r.db.QueryRowContext(ctx, query, id).Scan(
        &user.ID,
        &user.Email,
        &user.Name,
        &user.Age,
        &user.CreatedAt,
        &user.UpdatedAt,
    )

    if err == sql.ErrNoRows {
        return nil, fmt.Errorf("user not found")
    }

    if err != nil {
        return nil, fmt.Errorf("failed to find user: %w", err)
    }

    return &user, nil
}

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
    query := `
        SELECT id, email, name, age, created_at, updated_at
        FROM users
        WHERE email = ?
    `

    var user User
    err := r.db.QueryRowContext(ctx, query, email).Scan(
        &user.ID,
        &user.Email,
        &user.Name,
        &user.Age,
        &user.CreatedAt,
        &user.UpdatedAt,
    )

    if err == sql.ErrNoRows {
        return nil, fmt.Errorf("user not found")
    }

    if err != nil {
        return nil, fmt.Errorf("failed to find user: %w", err)
    }

    return &user, nil
}

func (r *UserRepository) FindAll(ctx context.Context, limit, offset int) ([]*User, error) {
    query := `
        SELECT id, email, name, age, created_at, updated_at
        FROM users
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    `

    rows, err := r.db.QueryContext(ctx, query, limit, offset)
    if err != nil {
        return nil, fmt.Errorf("failed to query users: %w", err)
    }
    defer rows.Close()

    var users []*User
    for rows.Next() {
        var user User
        err := rows.Scan(
            &user.ID,
            &user.Email,
            &user.Name,
            &user.Age,
            &user.CreatedAt,
            &user.UpdatedAt,
        )
        if err != nil {
            return nil, fmt.Errorf("failed to scan user: %w", err)
        }
        users = append(users, &user)
    }

    if err := rows.Err(); err != nil {
        return nil, fmt.Errorf("row iteration error: %w", err)
    }

    return users, nil
}

func (r *UserRepository) Update(ctx context.Context, user *User) error {
    query := `
        UPDATE users
        SET email = ?, name = ?, age = ?, updated_at = ?
        WHERE id = ?
    `

    result, err := r.db.ExecContext(ctx, query, user.Email, user.Name, user.Age, time.Now(), user.ID)
    if err != nil {
        return fmt.Errorf("failed to update user: %w", err)
    }

    rowsAffected, err := result.RowsAffected()
    if err != nil {
        return fmt.Errorf("failed to get rows affected: %w", err)
    }

    if rowsAffected == 0 {
        return fmt.Errorf("user not found")
    }

    return nil
}

func (r *UserRepository) Delete(ctx context.Context, id int64) error {
    query := `DELETE FROM users WHERE id = ?`

    result, err := r.db.ExecContext(ctx, query, id)
    if err != nil {
        return fmt.Errorf("failed to delete user: %w", err)
    }

    rowsAffected, err := result.RowsAffected()
    if err != nil {
        return fmt.Errorf("failed to get rows affected: %w", err)
    }

    if rowsAffected == 0 {
        return fmt.Errorf("user not found")
    }

    return nil
}
```

The `ExecContext` method executes queries that modify data, returning `sql.Result` with LastInsertId() and RowsAffected(). `QueryRowContext` retrieves single rows, while `QueryContext` handles multiple rows requiring iteration.

Always defer `rows.Close()` after `Query()` to release the connection back to the pool. Forgetting this causes connection leaks that exhaust the pool.

Check `sql.ErrNoRows` explicitly when expecting results. This error indicates no matching rows, distinct from connection or syntax errors.

## Using Prepared Statements for Better Performance

Prepared statements optimize repeated queries by parsing SQL once and executing with different parameters multiple times.

```go
func (r *UserRepository) BatchCreate(ctx context.Context, users []*User) error {
    stmt, err := r.db.PrepareContext(ctx, `
        INSERT INTO users (email, name, age, created_at)
        VALUES (?, ?, ?, ?)
    `)
    if err != nil {
        return fmt.Errorf("failed to prepare statement: %w", err)
    }
    defer stmt.Close()

    for _, user := range users {
        result, err := stmt.ExecContext(ctx, user.Email, user.Name, user.Age, time.Now())
        if err != nil {
            return fmt.Errorf("failed to insert user %s: %w", user.Email, err)
        }

        id, err := result.LastInsertId()
        if err != nil {
            return fmt.Errorf("failed to get last insert id: %w", err)
        }

        user.ID = id
    }

    return nil
}

func (r *UserRepository) FindMultipleByIDs(ctx context.Context, ids []int64) ([]*User, error) {
    if len(ids) == 0 {
        return []*User{}, nil
    }

    placeholders := ""
    args := make([]interface{}, len(ids))
    for i, id := range ids {
        if i > 0 {
            placeholders += ", "
        }
        placeholders += "?"
        args[i] = id
    }

    query := fmt.Sprintf(`
        SELECT id, email, name, age, created_at, updated_at
        FROM users
        WHERE id IN (%s)
    `, placeholders)

    rows, err := r.db.QueryContext(ctx, query, args...)
    if err != nil {
        return nil, fmt.Errorf("failed to query users: %w", err)
    }
    defer rows.Close()

    var users []*User
    for rows.Next() {
        var user User
        err := rows.Scan(&user.ID, &user.Email, &user.Name, &user.Age, &user.CreatedAt, &user.UpdatedAt)
        if err != nil {
            return nil, fmt.Errorf("failed to scan user: %w", err)
        }
        users = append(users, &user)
    }

    return users, rows.Err()
}
```

Prepared statements reduce parsing overhead for queries executed repeatedly. The database parses SQL once, caches the execution plan, and reuses it for subsequent executions with different parameters.

Always close prepared statements with `defer stmt.Close()` to free server resources. Unclosed statements accumulate and can exhaust server limits.

## Implementing Transactions for Data Consistency

Transactions ensure multiple operations succeed together or fail together, maintaining data integrity across related operations.

```go
type OrderRepository struct {
    db *sql.DB
}

func NewOrderRepository(db *sql.DB) *OrderRepository {
    return &OrderRepository{db: db}
}

func (r *OrderRepository) CreateOrder(ctx context.Context, userID, productID int64, quantity int) (*Order, error) {
    tx, err := r.db.BeginTx(ctx, nil)
    if err != nil {
        return nil, fmt.Errorf("failed to begin transaction: %w", err)
    }
    defer tx.Rollback()

    var product Product
    query := `SELECT id, name, price, stock FROM products WHERE id = ? FOR UPDATE`
    err = tx.QueryRowContext(ctx, query, productID).Scan(
        &product.ID, &product.Name, &product.Price, &product.Stock,
    )
    if err == sql.ErrNoRows {
        return nil, fmt.Errorf("product not found")
    }
    if err != nil {
        return nil, fmt.Errorf("failed to query product: %w", err)
    }

    if product.Stock < quantity {
        return nil, fmt.Errorf("insufficient stock: have %d, need %d", product.Stock, quantity)
    }

    updateStock := `UPDATE products SET stock = stock - ? WHERE id = ?`
    _, err = tx.ExecContext(ctx, updateStock, quantity, productID)
    if err != nil {
        return nil, fmt.Errorf("failed to update stock: %w", err)
    }

    totalPrice := product.Price * float64(quantity)
    insertOrder := `
        INSERT INTO orders (user_id, product_id, quantity, total_price, created_at)
        VALUES (?, ?, ?, ?, ?)
    `
    result, err := tx.ExecContext(ctx, insertOrder, userID, productID, quantity, totalPrice, time.Now())
    if err != nil {
        return nil, fmt.Errorf("failed to create order: %w", err)
    }

    orderID, err := result.LastInsertId()
    if err != nil {
        return nil, fmt.Errorf("failed to get order id: %w", err)
    }

    if err := tx.Commit(); err != nil {
        return nil, fmt.Errorf("failed to commit transaction: %w", err)
    }

    order := &Order{
        ID:         orderID,
        UserID:     userID,
        ProductID:  productID,
        Quantity:   quantity,
        TotalPrice: totalPrice,
        CreatedAt:  time.Now(),
    }

    return order, nil
}

type Order struct {
    ID         int64     `json:"id"`
    UserID     int64     `json:"user_id"`
    ProductID  int64     `json:"product_id"`
    Quantity   int       `json:"quantity"`
    TotalPrice float64   `json:"total_price"`
    CreatedAt  time.Time `json:"created_at"`
}
```

The `defer tx.Rollback()` pattern ensures rollback on error or panic. After successful `tx.Commit()`, Rollback becomes a no-op, making this pattern safe.

The `FOR UPDATE` clause locks selected rows, preventing concurrent modifications during the transaction. This prevents race conditions where multiple orders could deplete stock below zero.

Keep transactions short. Long-running transactions hold locks that block other queries, degrading application performance. Execute only necessary operations within transactions, performing independent queries outside.

## Handling Errors and NULL Values

Handle MySQL-specific errors and NULL values correctly for reliable applications.

```go
import (
    "github.com/go-sql-driver/mysql"
)

func (r *UserRepository) CreateWithErrorHandling(ctx context.Context, user *User) error {
    query := `INSERT INTO users (email, name, age, created_at) VALUES (?, ?, ?, ?)`

    result, err := r.db.ExecContext(ctx, query, user.Email, user.Name, user.Age, time.Now())
    if err != nil {
        if mysqlErr, ok := err.(*mysql.MySQLError); ok {
            switch mysqlErr.Number {
            case 1062:
                return fmt.Errorf("email already exists: %s", user.Email)
            case 1452:
                return fmt.Errorf("foreign key constraint failed")
            default:
                return fmt.Errorf("mysql error %d: %w", mysqlErr.Number, err)
            }
        }
        return fmt.Errorf("failed to create user: %w", err)
    }

    id, err := result.LastInsertId()
    if err != nil {
        return fmt.Errorf("failed to get last insert id: %w", err)
    }

    user.ID = id
    return nil
}

func (r *UserRepository) FindWithNullHandling(ctx context.Context, id int64) (*User, error) {
    query := `SELECT id, email, name, age, created_at, updated_at FROM users WHERE id = ?`

    var user User
    var updatedAt sql.NullTime

    err := r.db.QueryRowContext(ctx, query, id).Scan(
        &user.ID,
        &user.Email,
        &user.Name,
        &user.Age,
        &user.CreatedAt,
        &updatedAt,
    )

    if err == sql.ErrNoRows {
        return nil, fmt.Errorf("user not found")
    }
    if err != nil {
        return nil, fmt.Errorf("failed to find user: %w", err)
    }

    user.UpdatedAt = updatedAt

    return &user, nil
}
```

MySQL error 1062 indicates duplicate key violations, while 1452 signals foreign key constraint failures. Type-assert errors to `*mysql.MySQLError` for specific error codes.

Use `sql.Null*` types for nullable columns: `sql.NullString`, `sql.NullInt64`, `sql.NullBool`, `sql.NullFloat64`, `sql.NullTime`. These types have `Valid` and `Value` fields. Check `Valid` before accessing `Value` to determine if the database value was NULL.

## Monitoring Connection Pool Statistics

Monitor pool health to identify configuration issues and optimize resource usage.

```go
func MonitorConnectionPool(db *sql.DB) {
    stats := db.Stats()

    fmt.Printf("Open Connections: %d\n", stats.OpenConnections)
    fmt.Printf("In Use: %d\n", stats.InUse)
    fmt.Printf("Idle: %d\n", stats.Idle)
    fmt.Printf("Wait Count: %d\n", stats.WaitCount)
    fmt.Printf("Wait Duration: %s\n", stats.WaitDuration)
    fmt.Printf("Max Idle Closed: %d\n", stats.MaxIdleClosed)
    fmt.Printf("Max Idle Time Closed: %d\n", stats.MaxIdleTimeClosed)
    fmt.Printf("Max Lifetime Closed: %d\n", stats.MaxLifetimeClosed)
}

func HealthCheck(db *sql.DB) error {
    ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
    defer cancel()

    if err := db.PingContext(ctx); err != nil {
        return fmt.Errorf("database health check failed: %w", err)
    }

    stats := db.Stats()
    if stats.OpenConnections >= 20 {
        return fmt.Errorf("connection pool nearly exhausted: %d connections", stats.OpenConnections)
    }

    return nil
}
```

Key metrics:
- `OpenConnections`: Current open connections
- `InUse`: Connections actively executing queries
- `Idle`: Available connections in pool
- `WaitCount`: Times queries waited for available connection
- `WaitDuration`: Total time spent waiting for connections

High `WaitCount` and `WaitDuration` indicate insufficient pool size. Increase `MaxOpenConns` to provide more connections.

## Production Best Practices

Apply these patterns for reliable production MySQL applications.

```go
type Database struct {
    *sql.DB
}

func NewDatabase(dsn string) (*Database, error) {
    db, err := sql.Open("mysql", dsn)
    if err != nil {
        return nil, err
    }

    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(5 * time.Minute)
    db.SetConnMaxIdleTime(10 * time.Minute)

    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := db.PingContext(ctx); err != nil {
        return nil, fmt.Errorf("failed to ping database: %w", err)
    }

    return &Database{db}, nil
}

func (db *Database) QueryWithRetry(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error) {
    var rows *sql.Rows
    var err error

    for i := 0; i < 3; i++ {
        rows, err = db.QueryContext(ctx, query, args...)
        if err == nil {
            return rows, nil
        }

        if mysqlErr, ok := err.(*mysql.MySQLError); ok {
            if mysqlErr.Number == 1213 {
                time.Sleep(time.Duration(i*100) * time.Millisecond)
                continue
            }
        }

        return nil, err
    }

    return nil, fmt.Errorf("query failed after retries: %w", err)
}

func (db *Database) Close() error {
    return db.DB.Close()
}
```

Use a single global database instance shared across the application. The `sql.DB` type is safe for concurrent use by multiple goroutines.

Always use context with timeout for database operations. This prevents queries from hanging indefinitely and allows graceful cancellation.

Implement retry logic for transient errors like deadlocks (MySQL error 1213). Use exponential backoff between retries to reduce contention.

Log slow queries to identify optimization opportunities. Add middleware that logs queries exceeding a threshold duration.

## Testing Database Code

Write tests that use real MySQL or test doubles for repository testing.

```go
// repository_test.go
package main

import (
    "context"
    "database/sql"
    "testing"
    "time"

    "github.com/DATA-DOG/go-sqlmock"
)

func TestUserRepository_Create(t *testing.T) {
    db, mock, err := sqlmock.New()
    if err != nil {
        t.Fatalf("failed to create mock: %v", err)
    }
    defer db.Close()

    repo := NewUserRepository(db)

    user := &User{
        Email: "test@example.com",
        Name:  "Test User",
        Age:   25,
    }

    mock.ExpectExec("INSERT INTO users").
        WithArgs(user.Email, user.Name, user.Age, sqlmock.AnyArg()).
        WillReturnResult(sqlmock.NewResult(1, 1))

    err = repo.Create(context.Background(), user)

    if err != nil {
        t.Errorf("Create failed: %v", err)
    }

    if user.ID != 1 {
        t.Errorf("expected ID 1, got %d", user.ID)
    }

    if err := mock.ExpectationsWereMet(); err != nil {
        t.Errorf("unmet expectations: %v", err)
    }
}
```

The sqlmock library provides a mock database driver for testing without real MySQL. It verifies queries match expectations and returns configured results.

For integration tests, use a real MySQL instance with test data. Container tools like Docker make this straightforward.

## Conclusion

Working with MySQL in Go through database/sql provides control and performance for production applications. Proper connection pooling configuration prevents resource exhaustion while maintaining efficiency. Transactions ensure data consistency across related operations, critical for business logic integrity.

Understanding the distinction between Query, QueryRow, Exec, and Prepare enables writing correct database code. Handle NULL values explicitly with sql.Null types or pointers. Monitor connection pool statistics to identify configuration issues and optimize resource usage.

The patterns demonstrated here apply to any Go application using MySQL, from REST APIs to background workers. Apply connection pooling best practices, use transactions for multi-step operations, implement proper error handling, and monitor pool health in production. These foundations create reliable database layers that scale with your application.

For PostgreSQL applications, similar patterns apply with driver-specific differences covered in our [PostgreSQL connection guide](/2025/05/connecting-postgresql-in-go-using-sqlx.html). Combine database operations with proper [testing patterns](/2025/10/how-to-use-mock-testing-in-go-with-testify-and-mockery.html) to ensure correctness.
