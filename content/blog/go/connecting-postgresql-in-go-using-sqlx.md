---
title: "Connecting to PostgreSQL in Go using sqlx"
date: 2025-05-25T10:00:00+07:00
draft: false
url: /2025/05/connecting-postgresql-in-go-using-sqlx.html
tags:
    - Go
description: "Learn how to connect to PostgreSQL in Go using the sqlx library. This guide covers installation, basic queries, and best practices for working with PostgreSQL in Go applications."
keywords: ["Go", "PostgreSQL", "sqlx", "database connection", "Go database library"]
faq:
  - question: "Why use sqlx instead of database/sql or GORM for PostgreSQL in Go?"
    answer: "sqlx is middle ground between raw database/sql (verbose) and GORM (magic)—adds convenience without abstraction overhead. database/sql drawbacks: (1) Manual scanning: rows.Scan(&id, &name, &age)—tedious for many columns. (2) No struct mapping. (3) Repetitive error handling. sqlx advantages over database/sql: (1) Struct scanning: db.Select(&users, query)—auto-maps columns to struct fields via db tags. (2) Named parameters: NamedExec('INSERT INTO users (name) VALUES (:name)', user)—no positional $1 $2. (3) Get/Select helpers: db.Get(&user, 'SELECT * FROM users WHERE id=$1', id)—one-liner for single row. (4) Still uses database/sql underneath—same performance, connection pooling. GORM advantages: (1) Migrations built-in. (2) Associations (has-many, belongs-to). (3) Hooks (BeforeCreate, AfterUpdate). (4) Query builder. sqlx advantages over GORM: (1) No query generation overhead—write raw SQL, full control. (2) Predictable—see exact SQL executed. (3) Easier debugging—no magic. (4) Lighter—GORM adds dependencies, complexity. When to use: sqlx for APIs, microservices where performance and control matter; GORM for CRUD apps, admin panels where dev speed > performance. Migration path: start sqlx, add GORM if business logic gets complex. Don't: mix both in same codebase—pick one."
  - question: "How do I configure connection pooling to prevent 'pq: sorry, too many clients already' errors?"
    answer: "PostgreSQL has max_connections limit (default 100), Go creates pools per db.Open()—misconfigured pool exhausts connections. Error means: app opened ≥100 connections to Postgres, none released. Root causes: (1) Multiple db.Open() calls—each creates new pool. (2) SetMaxOpenConns too high. (3) Long-running transactions. (4) Connection leaks (forgot rows.Close()). Fix: (1) Single global *sqlx.DB: var DB *sqlx.DB; func init() { DB = sqlx.MustConnect(...) }—reuse across app. (2) Configure pool limits: db.SetMaxOpenConns(25)—limits concurrent connections (default unlimited!). (3) SetMaxIdleConns(5)—reuses idle connections, reduces open/close overhead. (4) SetConnMaxLifetime(5 * time.Minute)—recycles connections, prevents stale connections. Production config: db.SetMaxOpenConns(25); db.SetMaxIdleConns(5); db.SetConnMaxLifetime(5 * time.Minute); db.SetConnMaxIdleTime(10 * time.Minute). Formula: max_open = max_connections / num_app_instances—if 100 max connections, 4 instances → 25 per instance. Debug: SELECT count(*) FROM pg_stat_activity WHERE datname='mydb'; shows active connections. Leaks: always defer rows.Close() after Query(), defer tx.Rollback() after Begin(). Cloud databases: AWS RDS, GCP CloudSQL have lower limits (20-100), tune accordingly. Consider: PgBouncer connection pooler if many instances—reduces direct Postgres connections."
  - question: "What's the difference between Get, Select, QueryRow, and Query in sqlx?"
    answer: "Different methods for different result cardinalities—Get for single row, Select for multiple, Query/QueryRow for advanced cases. Get (single row → struct): var user User; db.Get(&user, 'SELECT * FROM users WHERE id=$1', 123)—expects exactly one row, errors if zero or multiple. Use when: fetching by primary key, enforcing uniqueness. Errors: sql.ErrNoRows if not found. Select (multiple rows → slice): var users []User; db.Select(&users, 'SELECT * FROM users WHERE age > $1', 18)—scans all rows into slice. Use when: listing, filtering. Returns empty slice if no rows (not error). QueryRow (single row, manual scan): var name string; db.QueryRow('SELECT name FROM users WHERE id=$1', 1).Scan(&name)—standard library method, manual field mapping. Use when: selecting subset of columns, non-struct types. Query (multiple rows, manual iteration): rows, _ := db.Query('SELECT * FROM users'); defer rows.Close(); for rows.Next() { rows.Scan(&id, &name) }—full control, stream processing. Use when: large result sets (don't load all in memory), custom scanning logic. Performance: Get/Select use Query underneath but add convenience—negligible overhead. Don't: use Query for simple cases, repetitive Scan code. Best practice: Get for ID lookups, Select for lists, Query for streaming/large datasets. Error handling: always check sql.ErrNoRows for Get: if err == sql.ErrNoRows { return nil, ErrNotFound }—don't treat as fatal error."
  - question: "How do I handle NULL values from PostgreSQL columns in Go structs with sqlx?"
    answer: "Go primitives (int, string, bool) can't represent NULL—causes scan error. Use database/sql null types or pointers. Problem: user.age is NULL in database, scanning into int fails: 'Scan error on column age: converting NULL to int is unsupported'. Solutions: (1) sql.NullString, sql.NullInt64, sql.NullBool: type User struct { Name string `db:\"name\"`; Age sql.NullInt64 `db:\"age\"` }. Access: if user.Age.Valid { fmt.Println(user.Age.Int64) } else { fmt.Println(\"NULL\") }. (2) Pointers: type User struct { Age *int `db:\"age\"` }—nil if NULL, *age if present. Simpler but verbose to check. (3) Custom types: type NullableInt int; func (n *NullableInt) Scan(value interface{}) error { if value == nil { *n = 0; return nil }; *n = NullableInt(value.(int64)); return nil }—scan NULL as 0 or custom default. When to use: (1) sql.Null* for explicit NULL handling (API responses distinguish null vs empty). (2) Pointers for optional fields (user.MiddleName). (3) Default values for business logic (NULL age = 0). Don't: use empty string \"\" or 0 to represent NULL—ambiguous (is age 0 really zero or NULL?). JSON marshaling: sql.NullString marshals as null or \"value\", pointers as null or value—both work for APIs. Best practice: avoid NULL in schema if possible (use NOT NULL with defaults), makes Go code simpler. If nullable: pointers for simplicity, sql.Null* for explicitness."
  - question: "When should I use prepared statements vs regular queries in sqlx?"
    answer: "Prepared statements optimize repeated queries with different parameters—single parse, multiple executions. But sqlx/database/sql auto-prepares in many cases, manual prep rarely needed. How prepared statements work: (1) Database parses SQL once, caches execution plan. (2) Multiple executions with different params—skip parse step, faster. (3) Prevents SQL injection via parameterization. Manual preparation: stmt, _ := db.Preparex('SELECT * FROM users WHERE age > $1'); defer stmt.Close(); stmt.Select(&users, 18); stmt.Select(&users, 25)—explicit prep. Auto-preparation: db.Select(&users, 'SELECT * FROM users WHERE age > $1', 18)—sqlx/pq driver auto-prepares behind scenes for parameterized queries. When to manually prepare: (1) Execute same query >100 times in loop—manual prep saves parse overhead. (2) Long-running service with hot queries—prep on startup. (3) Batch operations with varying params. When NOT to prepare: (1) One-off queries—prep overhead > savings. (2) Dynamic WHERE clauses—can't reuse prepared statement if SQL changes. (3) Migrations, admin scripts—simplicity > performance. Performance gain: ~10-30% for simple queries, more for complex joins. Caveat: prepared statements hold server resources—close with stmt.Close() when done. PostgreSQL: max_prepared_transactions limit (default 0, unlimited prepared statements). Anti-pattern: prepare inside loop: for { stmt := db.Preparex(...); stmt.Query() }—leaks statements. Best practice: rely on auto-prep for normal CRUD, manually prep only hot paths identified via profiling. Modern drivers (lib/pq) smart about reusing plans."
  - question: "How do I handle transactions with sqlx to ensure data consistency?"
    answer: "Use sqlx.Tx for multi-statement atomicity—all succeed or all rollback. Critical for operations spanning multiple tables (transfer money, create user + profile). Basic pattern: tx, err := db.Beginx(); if err != nil { return err }; defer tx.Rollback(); _, err = tx.Exec('INSERT INTO accounts (balance) VALUES (100)'); if err != nil { return err }; _, err = tx.Exec('UPDATE users SET account_id=$1', id); if err != nil { return err }; return tx.Commit()—defer Rollback() safe if Commit() called (no-op). Why defer Rollback: if any step errors, tx.Rollback() executes, undoing changes. If Commit() succeeds, Rollback() is no-op. Nested transactions: PostgreSQL supports savepoints: tx.Exec('SAVEPOINT sp1'); tx.Exec('ROLLBACK TO sp1')—but complexity high, avoid. Common mistakes: (1) Forgot Rollback on error—leaves transaction open, locks rows, blocks other queries. (2) Long transactions—hold locks, block concurrent writes. (3) Query outside tx: db.Exec() instead of tx.Exec()—change not in transaction. Isolation levels: tx, _ := db.BeginTxx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})—controls visibility of concurrent changes (ReadCommitted, RepeatableRead, Serializable). Default: ReadCommitted (enough for most apps). Best practices: (1) Keep transactions short—acquire lock, modify, commit quickly. (2) Read-only queries outside transactions—no locks needed. (3) Retry on serialization errors: if pqErr.Code == '40001' { retry }—concurrent update conflicts. (4) Use context with timeout: ctx, cancel := context.WithTimeout(...); tx, _ := db.BeginTxx(ctx, nil)—prevents eternal locks. Production: monitor transaction duration—long txns (>1s) indicate locking issues. Tools: SELECT * FROM pg_stat_activity WHERE state='idle in transaction'; shows hanging transactions."
---

In modern web applications, storing and retrieving data from a database is a fundamental requirement. Go provides a low-level database/sql package, but using it directly can be verbose and repetitive. Thankfully, sqlx extends database/sql by adding useful features like struct scanning and named queries, making database operations in Go much easier.

In this article, we’ll walk through how to connect a Go application to a PostgreSQL database using sqlx, and how to perform basic CRUD operations.

## What is sqlx?
sqlx is a Go library that enhances the standard database/sql by making it easier to work with structs and common query patterns. It's widely used for developers who want more control and performance without jumping into full ORMs.

Install sqlx with:
```bash
go get github.com/jmoiron/sqlx
```

You also need the PostgreSQL driver:
```bash
go get github.com/lib/pq
```

## Connect to PostgreSQL
To connect to a PostgreSQL database, you need to provide a connection string that includes the database name, user, password, host, and port. Here’s how to set up a basic connection using sqlx:

```go
package main

import (
    "fmt"
    "log"
    "github.com/jmoiron/sqlx"
    _ "github.com/lib/pq"
)

var db *sqlx.DB

func main() {
    dsn := "user=postgres password=yourpassword dbname=mydb sslmode=disable"
    var err error
    db, err = sqlx.Connect("postgres", dsn)
    if err != nil {
        log.Fatalln(err)
    }
    fmt.Println("Connected to PostgreSQL!")
}
```

Make sure to replace `yourpassword` and `mydb` with your actual PostgreSQL credentials and database name.

## Create a Struct and Table
Create a table in PostgreSQL:
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    age INT NOT NULL
);
```

Next, define a Go struct that matches the table schema:

```go
type User struct {
    ID   int    `db:"id"`
    Name string `db:"name"`
    Age  int    `db:"age"`
}
```

## Insert Data
To insert data into the `users` table, you can use the `NamedExec` method provided by sqlx, which allows you to use named parameters in your SQL queries:

```go
func createUser(name string, age int) error {
    user := User{Name: name, Age: age}
    query := `INSERT INTO users (name, age) VALUES (:name, :age)`
    _, err := db.NamedExec(query, user)
    return err
}
```

## Query Data
To retrieve data from the `users` table, you can use the `Select` method, which scans the results into a slice of structs:

```go
func getUsers() ([]User, error) {
    var users []User
    query := `SELECT * FROM users`
    err := db.Select(&users, query)
    return users, err
}
```

## Update Data
To update a user's information, you can use the `NamedExec` method again:

```go
func updateUser(id int, name string, age int) error {
    user := User{ID: id, Name: name, Age: age}
    query := `UPDATE users SET name = :name, age = :age WHERE id = :id`
    _, err := db.NamedExec(query, user)
    return err
}
```
## Delete Data
To delete a user from the `users` table, you can use the `Exec` method:

```go
func deleteUser(id int) error {
    query := `DELETE FROM users WHERE id = $1`
    _, err := db.Exec(query, id)
    return err
}
```
## Putting It All Together
Here’s a complete example that includes connecting to the database, creating a user, retrieving users, updating a user, and deleting a user:

```go
package main
import (
    "fmt"
    "log"

    "github.com/jmoiron/sqlx"
    _ "github.com/lib/pq"
)
type User struct {
    ID   int    `db:"id"`
    Name string `db:"name"`
    Age  int    `db:"age"`
}
var db *sqlx.DB
func main() {
    dsn := "user=postgres password=yourpassword dbname=mydb sslmode=disable"
    var err error
    db, err = sqlx.Connect("postgres", dsn)
    if err != nil {
        log.Fatalln(err)
    }
    fmt.Println("Connected to PostgreSQL!")

    // Create a user
    if err := createUser("Alice", 30); err != nil {
        log.Println("Error creating user:", err)
    }

    // Get users
    users, err := getUsers()
    if err != nil {
        log.Println("Error getting users:", err)
    } else {
        fmt.Println("Users:", users)
    }

    // Update a user
    if err := updateUser(1, "Alice Smith", 31); err != nil {
        log.Println("Error updating user:", err)
    }

    // Delete a user
    if err := deleteUser(1); err != nil {
        log.Println("Error deleting user:", err)
    }
}
```
## Best Practices
- **Use Named Parameters**: Named parameters make your queries more readable and maintainable.
- **Error Handling**: Always check for errors after executing queries to handle any issues gracefully.
- **Connection Pooling**: sqlx uses the database/sql package under the hood, which supports connection pooling. Make sure to configure the pool size according to your application's needs.
- **Migrations**: Use a migration tool like `golang-migrate` to manage your database schema changes.
- **Environment Variables**: Store sensitive information like database credentials in environment variables or a configuration file, not hard-coded in your source code.
- **Close the Database Connection Gracefully**: Ensure you close the database connection when your application exits to avoid resource leaks.

## Conclusion
sqlx is a powerful tool for interacting with PostgreSQL in Go. It keeps your code clean while avoiding the overhead of a full ORM. You’ve now seen how to connect to PostgreSQL, run basic CRUD operations, and structure your DB code using sqlx.

In the next article, we’ll go further by integrating this into a REST API and later explore GORM for higher-level abstraction.

Happy coding!
