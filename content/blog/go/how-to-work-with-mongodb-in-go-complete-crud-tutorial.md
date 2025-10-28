---
title: "How to Work with MongoDB in Go - Complete CRUD Tutorial"
description: "A practical, production-ready guide to using MongoDB with Go. Learn how to connect, model data, create indexes, and implement complete CRUD operations with the official MongoDB Go driver, including pagination, projections, and best practices."
date: 2025-10-13T10:00:00+07:00
tags: ["Go", "Database", "MongoDB", "CRUD"]
draft: false
author: "Wiku Karno"
keywords: ["MongoDB Go CRUD", "Golang MongoDB tutorial", "MongoDB official driver Go", "Go database examples", "MongoDB indexes Go", "Go pagination MongoDB", "MongoDB update examples Go"]
url: /2025/10/how-to-work-with-mongodb-in-go-complete-crud-tutorial.html
faq:
  - question: "Which MongoDB driver should I use for Go?"
    answer: "Use the official driver at go.mongodb.org/mongo-driver. It is actively maintained by MongoDB Inc., supports context-based timeouts, connection pooling, transactions, and exposes the full MongoDB feature set."
  - question: "How do I manage timeouts and context in Go with MongoDB?"
    answer: "Always pass a context with deadlines to driver calls using context.WithTimeout. This prevents hanging operations and allows you to cancel slow queries cleanly in production."
  - question: "Should I create indexes from code or manually?"
    answer: "Both are valid. For consistency across environments, many teams programmatically ensure indexes at startup. For large datasets, create indexes offline or during maintenance windows to avoid performance impact."
  - question: "How can I avoid BSON/JSON field mismatches?"
    answer: "Define explicit bson tags on your Go structs (e.g., bson:\"user_id\"). Keep API JSON tags separate (json tags) if field names differ between your database schema and HTTP payloads."
  - question: "What’s the recommended way to structure repositories/services?"
    answer: "Keep data-access logic behind a repository interface (e.g., UserRepository) and let services depend on that interface. This makes your code more testable and decoupled from the database."
  - question: "How do I implement pagination efficiently?"
    answer: "Use find with limit/skip and a stable sort (e.g., by _id or created_at). For large collections, consider cursor-based pagination using the last seen _id for better performance."
---

Working with MongoDB in Go is straightforward once you understand the official driver’s patterns: always use [contexts](/2025/04/using-context-in-go-cancellation.html), define strong models with `bson` tags (and clean [JSON handling](/2025/04/working-with-json-in-go-encode-decode.html)), ensure indexes, and wrap database calls behind a repository (see [project structure best practices](/2025/05/structuring-go-projects-clean-project-structure-and-best-practices.html)). In this tutorial, you’ll build a complete CRUD flow using idiomatic Go and production-friendly practices.

What you’ll learn:
- Install and initialize the official driver
- Connect to MongoDB with timeouts and pooling
- Design models with `bson` and `json` tags
- Create necessary indexes programmatically
- Implement Create, Read, Update, Delete operations
- Add projections, filtering, pagination, and error handling
- Structure your code for maintainability

Prerequisites:
- Go 1.21+
- A running MongoDB instance (local Docker or Atlas URI)

If you plan to expose a REST API on top of this repository, consider our [production-ready Gin guide](/2025/09/building-rest-api-gin-framework-golang-production-ready.html) or the standard library approach in [net/http REST tutorial](/2025/05/how-to-build-a-rest-api-in-go-using-net-http.html).

Install the driver:

```bash
go get go.mongodb.org/mongo-driver/mongo@latest
go get go.mongodb.org/mongo-driver/bson@latest
```

Project layout (minimal example):

```
internal/
  db/
    mongo.go        # client init and helpers
  user/
    model.go        # User model
    repo.go         # CRUD repository
cmd/
  server/
    main.go        # wire everything together
```

Connect with context and pooling (`internal/db/mongo.go`):

```go
package db

import (
    "context"
    "time"

    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

type MongoConfig struct {
    URI        string
    Database   string
    Timeout    time.Duration
    MaxPool    uint64
}

func NewClient(cfg MongoConfig) (*mongo.Client, error) {
    ctx, cancel := context.WithTimeout(context.Background(), cfg.Timeout)
    defer cancel()

    clientOpts := options.Client().ApplyURI(cfg.URI)
    if cfg.MaxPool > 0 {
        clientOpts.SetMaxPoolSize(cfg.MaxPool)
    }

    client, err := mongo.Connect(ctx, clientOpts)
    if err != nil {
        return nil, err
    }

    // Verify connection
    if err := client.Ping(ctx, nil); err != nil {
        _ = client.Disconnect(context.Background())
        return nil, err
    }
    return client, nil
}
```

Model with `bson` and `json` tags (`internal/user/model.go`):

```go
package user

import "time"

type User struct {
    ID        string    `bson:"_id,omitempty" json:"id"`
    Email     string    `bson:"email" json:"email"`
    Name      string    `bson:"name" json:"name"`
    CreatedAt time.Time `bson:"created_at" json:"created_at"`
    UpdatedAt time.Time `bson:"updated_at" json:"updated_at"`
}

type CreateUserInput struct {
    Email string `json:"email"`
    Name  string `json:"name"`
}

type UpdateUserInput struct {
    Name string `json:"name"`
}
```

New to JSON encoding/decoding and tags in Go? See: [Working with JSON in Go](/2025/04/working-with-json-in-go-encode-decode.html).

Repository interface and implementation (`internal/user/repo.go`):

```go
package user

import (
    "context"
    "errors"
    "time"

    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/bson/primitive"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

var ErrNotFound = errors.New("user not found")

type Repository interface {
    Create(ctx context.Context, in CreateUserInput) (User, error)
    GetByID(ctx context.Context, id string) (User, error)
    List(ctx context.Context, limit, skip int64) ([]User, error)
    UpdateName(ctx context.Context, id string, name string) (User, error)
    Delete(ctx context.Context, id string) error
    EnsureIndexes(ctx context.Context) error
}

type MongoRepo struct {
    c *mongo.Collection
}

func NewMongoRepo(db *mongo.Database) *MongoRepo {
    return &MongoRepo{c: db.Collection("users")}
}

func (r *MongoRepo) EnsureIndexes(ctx context.Context) error {
    // Unique index on email and a TTL-friendly created_at sorter
    idxs := []mongo.IndexModel{
        {
            Keys: bson.D{{Key: "email", Value: 1}},
            Options: options.Index().SetUnique(true).SetName("uniq_email"),
        },
        {
            Keys: bson.D{{Key: "created_at", Value: -1}},
            Options: options.Index().SetName("created_at_desc"),
        },
    }
    _, err := r.c.Indexes().CreateMany(ctx, idxs)
    return err
}

func (r *MongoRepo) Create(ctx context.Context, in CreateUserInput) (User, error) {
    now := time.Now().UTC()
    doc := User{
        Email:     in.Email,
        Name:      in.Name,
        CreatedAt: now,
        UpdatedAt: now,
    }
    res, err := r.c.InsertOne(ctx, doc)
    if err != nil {
        return User{}, err
    }
    if oid, ok := res.InsertedID.(primitive.ObjectID); ok {
        doc.ID = oid.Hex()
    }
    return doc, nil
}

func (r *MongoRepo) GetByID(ctx context.Context, id string) (User, error) {
    oid, err := primitive.ObjectIDFromHex(id)
    if err != nil { return User{}, ErrNotFound }

    var out User
    if err := r.c.FindOne(ctx, bson.M{"_id": oid}).Decode(&out); err != nil {
        if errors.Is(err, mongo.ErrNoDocuments) { return User{}, ErrNotFound }
        return User{}, err
    }
    return out, nil
}

func (r *MongoRepo) List(ctx context.Context, limit, skip int64) ([]User, error) {
    opts := options.Find().SetLimit(limit).SetSkip(skip).SetSort(bson.D{{Key: "created_at", Value: -1}})
    cur, err := r.c.Find(ctx, bson.M{}, opts)
    if err != nil { return nil, err }
    defer cur.Close(ctx)

    var users []User
    for cur.Next(ctx) {
        var u User
        if err := cur.Decode(&u); err != nil { return nil, err }
        users = append(users, u)
    }
    return users, cur.Err()
}

func (r *MongoRepo) UpdateName(ctx context.Context, id string, name string) (User, error) {
    oid, err := primitive.ObjectIDFromHex(id)
    if err != nil { return User{}, ErrNotFound }
    upd := bson.M{"$set": bson.M{"name": name, "updated_at": time.Now().UTC()}}
    opts := options.FindOneAndUpdate().SetReturnDocument(options.After)

    var out User
    if err := r.c.FindOneAndUpdate(ctx, bson.M{"_id": oid}, upd, opts).Decode(&out); err != nil {
        if errors.Is(err, mongo.ErrNoDocuments) { return User{}, ErrNotFound }
        return User{}, err
    }
    return out, nil
}

func (r *MongoRepo) Delete(ctx context.Context, id string) error {
    oid, err := primitive.ObjectIDFromHex(id)
    if err != nil { return ErrNotFound }
    res, err := r.c.DeleteOne(ctx, bson.M{"_id": oid})
    if err != nil { return err }
    if res.DeletedCount == 0 { return ErrNotFound }
    return nil
}
```

Wire up in `main.go` with contexts and timeouts:

```go
package main

import (
    "context"
    "fmt"
    "log"
    "time"

    "yourapp/internal/db"
    "yourapp/internal/user"
    "go.mongodb.org/mongo-driver/mongo"
)

func main() {
    cfg := db.MongoConfig{
        URI:      getEnv("MONGODB_URI", "mongodb://localhost:27017"),
        Database: getEnv("MONGODB_DB", "appdb"),
        Timeout:  10 * time.Second,
        MaxPool:  50,
    }

    client, err := db.NewClient(cfg)
    if err != nil { log.Fatalf("mongo: %v", err) }
    defer func() { _ = client.Disconnect(context.Background()) }()

    database := client.Database(cfg.Database)
    repo := user.NewMongoRepo(database)

    // Ensure indexes at startup
    if err := repo.EnsureIndexes(context.Background()); err != nil {
        log.Fatalf("ensure indexes: %v", err)
    }

    // Demo workflow with context timeouts
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    u, err := repo.Create(ctx, user.CreateUserInput{Email: "jane@site.com", Name: "Jane"})
    if err != nil { log.Fatal(err) }
    fmt.Println("created:", u.ID)

    got, _ := repo.GetByID(ctx, u.ID)
    fmt.Println("fetched:", got.Email, got.Name)

    updated, _ := repo.UpdateName(ctx, u.ID, "Jane Doe")
    fmt.Println("updated:", updated.Name)

    list, _ := repo.List(ctx, 10, 0)
    fmt.Println("total in page:", len(list))

    _ = repo.Delete(ctx, u.ID)
    fmt.Println("deleted:", u.ID)
}

func getEnv(k, def string) string { if v := getenv(k); v != "" { return v }; return def }

// replace with os.Getenv in real code
func getenv(k string) string { return "" }
```

To containerize and deploy this service, follow: [How to Containerize and Deploy Go Apps with Docker](/2025/10/how-to-containerize-and-deploy-go-apps-with-docker.html).

Reading documents with projections and filters

```go
// Find users created in the last 7 days, only return email and name
sevenDays := time.Now().UTC().Add(-7 * 24 * time.Hour)
filter := bson.M{"created_at": bson.M{"$gte": sevenDays}}
opts := options.Find().SetProjection(bson.M{"email": 1, "name": 1})
cur, err := repo.c.Find(ctx, filter, opts)
```

Updating multiple documents

```go
// Add a prefix to all names that are empty
filter := bson.M{"name": bson.M{"$eq": ""}}
update := bson.M{"$set": bson.M{"name": "User"}}
res, err := repo.c.UpdateMany(ctx, filter, update)
```

Deleting by filter

```go
// Delete accounts with a specific domain (be careful!)
filter := bson.M{"email": bson.M{"$regex": "@example.com$"}}
res, err := repo.c.DeleteMany(ctx, filter)
```

Transactions and sessions (brief)

MongoDB supports multi-document ACID transactions on replica sets and sharded clusters. With the Go driver, you run code inside a session callback. Keep transactions short, avoid long-running operations, and set timeouts.

```go
// Example outline; ensure your deployment supports transactions
func runInTxn(client *mongo.Client, cb func(mongo.SessionContext) error) error {
    sess, err := client.StartSession()
    if err != nil { return err }
    defer sess.EndSession(context.Background())
    return mongo.WithSession(context.Background(), sess, func(sc mongo.SessionContext) error {
        return sc.StartTransaction();
    })
}
```

Error handling and common pitfalls
- Always check `mongo.ErrNoDocuments` to distinguish “not found” from real errors.
- Use `context.WithTimeout` for every operation; surface deadline exceeded errors to callers.
- Unique constraints belong to indexes, not only application logic.
- Validate inputs at boundaries and sanitize regex filters from user input.
- Avoid unbounded `Find` calls; always use `limit` and prefer stable sorts.

For a deeper dive into idiomatic error patterns, read: [Error Handling in Go](/2025/04/error-handling-in-go-managing-errors.html).

Pagination strategies
- Offset-based: use `Find` with `limit` and `skip` plus a sort field (e.g., `created_at` desc). Simple and good for small pages.
- Cursor-based: store the last seen `_id` and query `{"_id": {"$lt": lastID}}` with the same sort. This scales better for large collections.

Need to investigate query performance and memory usage? Try our profiling guide: [Profile and Optimize Go Apps with pprof](/2025/10/how-to-profile-and-optimize-go-applications-with-pprof.html).

Testing tips
- Use a dedicated test database and clean up with `DeleteMany` after each test.
- For fast unit tests, abstract the repository and mock it; reserve integration tests for verifying real behavior.

Learn the testing fundamentals and patterns here: [Testing in Go with the testing package](/2025/04/testing-in-go-writing-unit-tests-with.html).

Folder structure recommendations
- Keep driver-specific logic in the repository package; expose an interface.
- Pass contexts from the HTTP layer down to repositories; the caller owns timeouts.
- Centralize client initialization and ensure indexes at startup.

Security and configuration
- Keep the connection string in environment variables (e.g., `MONGODB_URI`).
- Use different databases for dev/test/prod.
- Restrict network access and credentials; prefer least-privilege users.

Wrap-up

You implemented a complete CRUD workflow in Go with the official MongoDB driver, added indexes, and covered pagination, projections, and robust error handling. From here, you can extend the repository with compound indexes, unique constraints on multiple fields, soft deletes, or aggregation pipelines for analytics. Keep contexts and timeouts at the top of your mind--those two practices alone go a long way toward reliable production services.

Building an API that needs authentication and rate control? Continue with [JWT authentication in Go](/2025/09/how-to-implement-jwt-authentication-in-go-secure-rest-api.html) and [API rate limiting in Go](/2025/10/how-to-implement-rate-limiting-in-go-protect-api-from-abuse.html).
