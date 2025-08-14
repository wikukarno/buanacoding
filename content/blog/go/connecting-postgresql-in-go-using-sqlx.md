---
title: "Connecting to PostgreSQL in Go using sqlx"
date: 2025-05-25T10:00:00+07:00
draft: false
url: /2025/05/connecting-postgresql-in-go-using-sqlx.html
tags:
    - Go
description: "Learn how to connect to PostgreSQL in Go using the sqlx library. This guide covers installation, basic queries, and best practices for working with PostgreSQL in Go applications."
keywords: ["Go", "PostgreSQL", "sqlx", "database connection", "Go database library"]
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
