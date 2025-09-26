---
title: "Building GraphQL Server with gqlgen in Golang"
description: "Step-by-step guide to building production-ready GraphQL servers using gqlgen in Go. Learn schema design, resolver implementation, and best practices for scalable GraphQL APIs."
date: 2025-09-26T03:00:00+07:00
tags: ["Go", "GraphQL", "gqlgen", "API"]
draft: false
author: "Wiku Karno"
keywords: ["Go", "Golang", "GraphQL", "gqlgen", "API Development", "Schema", "Resolvers"]
url: /2025/09/building-graphql-server-gqlgen-golang.html
---

Modern web applications require APIs that can efficiently serve data to various clients with different needs. While traditional REST APIs have served this purpose for years, GraphQL has emerged as a powerful alternative that solves many common API development challenges. When building GraphQL servers in Go, gqlgen stands out as the most mature and feature-rich library available.

This comprehensive guide will walk you through building a complete GraphQL server using gqlgen, from initial setup to production deployment. We'll cover schema design, resolver implementation, database integration, and performance optimization techniques that will help you build robust, scalable GraphQL APIs.

## Understanding gqlgen and Its Advantages

The gqlgen library takes a schema-first approach to GraphQL development, which means you define your GraphQL schema first, and the library generates the corresponding Go code. This approach offers several significant advantages over schema-last libraries where you define resolvers first and generate schemas from code.

Schema-first development ensures your API contract is explicitly defined and serves as the single source of truth for both frontend and backend teams. The generated code is type-safe, eliminating runtime errors that commonly occur with manual type casting. Additionally, gqlgen generates efficient resolver interfaces that guide your implementation and ensure consistency across your codebase.

The library also provides excellent tooling for development, including automatic code generation, built-in validation, and comprehensive error handling. These features significantly reduce boilerplate code and allow you to focus on business logic rather than GraphQL implementation details.

## Project Setup and Initial Configuration

Before diving into code, let's establish a proper project structure that will scale as your GraphQL API grows. Start by creating a new Go module and organizing directories for different components of your application.

```bash
mkdir graphql-server
cd graphql-server
go mod init github.com/yourusername/graphql-server

mkdir -p {graph,models,database,middleware}
```

Install the necessary dependencies for our GraphQL server:

```bash
go get github.com/99designs/gqlgen
go get github.com/99designs/gqlgen/graphql/handler
go get github.com/99designs/gqlgen/graphql/playground
go get github.com/go-chi/chi/v5
go get github.com/go-chi/chi/v5/middleware
```

Create a configuration file `gqlgen.yml` in your project root to customize gqlgen's behavior:

```yaml
# gqlgen.yml
schema:
  - graph/*.graphql

exec:
  filename: graph/generated.go
  package: graph

model:
  filename: models/models_gen.go
  package: models

resolver:
  filename: graph/resolver.go
  package: graph
  type: Resolver

autobind:
  - "github.com/yourusername/graphql-server/models"

models:
  ID:
    model:
      - github.com/99designs/gqlgen/graphql.ID
      - github.com/99designs/gqlgen/graphql.Int
      - github.com/99designs/gqlgen/graphql.Int64
      - github.com/99designs/gqlgen/graphql.Int32
  DateTime:
    model: time.Time
```

This configuration tells gqlgen where to find schema files, where to generate code, and how to handle custom scalar types like DateTime.

## Designing Your GraphQL Schema

A well-designed schema is the foundation of any successful GraphQL API. Let's create a practical schema for a blog application that demonstrates common GraphQL patterns and best practices.

Create `graph/schema.graphql` with the following content:

```graphql
scalar DateTime

type User {
  id: ID!
  username: String!
  email: String!
  displayName: String!
  bio: String
  avatar: String
  posts: [Post!]!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type Post {
  id: ID!
  title: String!
  content: String!
  excerpt: String
  slug: String!
  status: PostStatus!
  author: User!
  tags: [Tag!]!
  comments: [Comment!]!
  createdAt: DateTime!
  updatedAt: DateTime!
  publishedAt: DateTime
}

type Tag {
  id: ID!
  name: String!
  slug: String!
  description: String
  posts: [Post!]!
}

type Comment {
  id: ID!
  content: String!
  author: User!
  post: Post!
  parent: Comment
  replies: [Comment!]!
  createdAt: DateTime!
  updatedAt: DateTime!
}

enum PostStatus {
  DRAFT
  PUBLISHED
  ARCHIVED
}

type Query {
  # User queries
  user(id: ID!): User
  users(limit: Int, offset: Int): [User!]!

  # Post queries
  post(id: ID, slug: String): Post
  posts(limit: Int, offset: Int, status: PostStatus): [Post!]!
  postsByUser(userId: ID!, limit: Int, offset: Int): [Post!]!

  # Tag queries
  tag(id: ID, slug: String): Tag
  tags: [Tag!]!

  # Comment queries
  commentsByPost(postId: ID!, limit: Int, offset: Int): [Comment!]!
}

type Mutation {
  # User mutations
  createUser(input: CreateUserInput!): User!
  updateUser(id: ID!, input: UpdateUserInput!): User!
  deleteUser(id: ID!): Boolean!

  # Post mutations
  createPost(input: CreatePostInput!): Post!
  updatePost(id: ID!, input: UpdatePostInput!): Post!
  deletePost(id: ID!): Boolean!
  publishPost(id: ID!): Post!

  # Tag mutations
  createTag(input: CreateTagInput!): Tag!
  updateTag(id: ID!, input: UpdateTagInput!): Tag!
  deleteTag(id: ID!): Boolean!

  # Comment mutations
  createComment(input: CreateCommentInput!): Comment!
  updateComment(id: ID!, input: UpdateCommentInput!): Comment!
  deleteComment(id: ID!): Boolean!
}

# Input types for mutations
input CreateUserInput {
  username: String!
  email: String!
  displayName: String!
  bio: String
  avatar: String
}

input UpdateUserInput {
  displayName: String
  bio: String
  avatar: String
}

input CreatePostInput {
  title: String!
  content: String!
  excerpt: String
  slug: String!
  status: PostStatus!
  tagIds: [ID!]
}

input UpdatePostInput {
  title: String
  content: String
  excerpt: String
  slug: String
  status: PostStatus
  tagIds: [ID!]
}

input CreateTagInput {
  name: String!
  slug: String!
  description: String
}

input UpdateTagInput {
  name: String
  description: String
}

input CreateCommentInput {
  content: String!
  postId: ID!
  parentId: ID
}

input UpdateCommentInput {
  content: String!
}
```

This schema demonstrates several GraphQL best practices including proper use of scalar types, enums, input types, and relationship modeling. The schema is designed to be both flexible and efficient, supporting common queries while avoiding over-fetching problems.

## Generating Code and Initial Resolver Setup

With your schema defined, generate the initial code structure using gqlgen:

```bash
go run github.com/99designs/gqlgen generate
```

This command creates several files including generated types, resolver interfaces, and the executable schema. The most important file for your implementation is `graph/resolver.go`, which contains the resolver struct and method stubs for all your schema operations.

Let's examine the generated resolver structure and add some basic setup:

```go
package graph

import (
    "context"
    "database/sql"
    "time"

    "github.com/yourusername/graphql-server/models"
)

// Resolver is the root resolver struct
type Resolver struct {
    db *sql.DB
    // Add other dependencies like cache, logger, etc.
}

// NewResolver creates a new resolver instance
func NewResolver(db *sql.DB) *Resolver {
    return &Resolver{
        db: db,
    }
}
```

Now implement some basic query resolvers to get started:

```go
// Query resolver implementation
func (r *queryResolver) User(ctx context.Context, id string) (*models.User, error) {
    var user models.User
    query := `
        SELECT id, username, email, display_name, bio, avatar, created_at, updated_at
        FROM users WHERE id = $1
    `

    row := r.db.QueryRowContext(ctx, query, id)
    err := row.Scan(
        &user.ID,
        &user.Username,
        &user.Email,
        &user.DisplayName,
        &user.Bio,
        &user.Avatar,
        &user.CreatedAt,
        &user.UpdatedAt,
    )

    if err != nil {
        if err == sql.ErrNoRows {
            return nil, nil
        }
        return nil, err
    }

    return &user, nil
}

func (r *queryResolver) Users(ctx context.Context, limit *int, offset *int) ([]*models.User, error) {
    defaultLimit := 10
    defaultOffset := 0

    if limit == nil {
        limit = &defaultLimit
    }
    if offset == nil {
        offset = &defaultOffset
    }

    query := `
        SELECT id, username, email, display_name, bio, avatar, created_at, updated_at
        FROM users ORDER BY created_at DESC LIMIT $1 OFFSET $2
    `

    rows, err := r.db.QueryContext(ctx, query, *limit, *offset)
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    var users []*models.User
    for rows.Next() {
        var user models.User
        err := rows.Scan(
            &user.ID,
            &user.Username,
            &user.Email,
            &user.DisplayName,
            &user.Bio,
            &user.Avatar,
            &user.CreatedAt,
            &user.UpdatedAt,
        )
        if err != nil {
            return nil, err
        }
        users = append(users, &user)
    }

    return users, nil
}
```

## Implementing Complex Resolvers and Relationships

GraphQL's power lies in its ability to efficiently resolve complex data relationships. Let's implement resolvers that handle nested data loading while avoiding the N+1 query problem.

For the User type's posts field, we need a resolver that fetches posts belonging to a specific user:

```go
// User resolver for the posts field
func (r *userResolver) Posts(ctx context.Context, obj *models.User) ([]*models.Post, error) {
    query := `
        SELECT id, title, content, excerpt, slug, status, author_id, created_at, updated_at, published_at
        FROM posts WHERE author_id = $1 ORDER BY created_at DESC
    `

    rows, err := r.db.QueryContext(ctx, query, obj.ID)
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    var posts []*models.Post
    for rows.Next() {
        var post models.Post
        err := rows.Scan(
            &post.ID,
            &post.Title,
            &post.Content,
            &post.Excerpt,
            &post.Slug,
            &post.Status,
            &post.AuthorID,
            &post.CreatedAt,
            &post.UpdatedAt,
            &post.PublishedAt,
        )
        if err != nil {
            return nil, err
        }
        posts = append(posts, &post)
    }

    return posts, nil
}

// Post resolver for the author field
func (r *postResolver) Author(ctx context.Context, obj *models.Post) (*models.User, error) {
    // Reuse the existing User query resolver
    return r.Query().User(ctx, obj.AuthorID)
}

// Post resolver for tags (many-to-many relationship)
func (r *postResolver) Tags(ctx context.Context, obj *models.Post) ([]*models.Tag, error) {
    query := `
        SELECT t.id, t.name, t.slug, t.description
        FROM tags t
        INNER JOIN post_tags pt ON t.id = pt.tag_id
        WHERE pt.post_id = $1
    `

    rows, err := r.db.QueryContext(ctx, query, obj.ID)
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    var tags []*models.Tag
    for rows.Next() {
        var tag models.Tag
        err := rows.Scan(&tag.ID, &tag.Name, &tag.Slug, &tag.Description)
        if err != nil {
            return nil, err
        }
        tags = append(tags, &tag)
    }

    return tags, nil
}
```

## Mutation Implementation and Data Validation

Mutations require careful implementation to ensure data integrity and provide meaningful error messages. Let's implement user and post creation mutations with proper validation:

```go
func (r *mutationResolver) CreateUser(ctx context.Context, input models.CreateUserInput) (*models.User, error) {
    // Validate input
    if len(input.Username) < 3 {
        return nil, fmt.Errorf("username must be at least 3 characters long")
    }

    if !isValidEmail(input.Email) {
        return nil, fmt.Errorf("invalid email format")
    }

    // Check if username or email already exists
    var exists bool
    checkQuery := `SELECT EXISTS(SELECT 1 FROM users WHERE username = $1 OR email = $2)`
    err := r.db.QueryRowContext(ctx, checkQuery, input.Username, input.Email).Scan(&exists)
    if err != nil {
        return nil, fmt.Errorf("failed to check user existence: %w", err)
    }

    if exists {
        return nil, fmt.Errorf("username or email already exists")
    }

    // Create user
    user := &models.User{
        Username:    input.Username,
        Email:       input.Email,
        DisplayName: input.DisplayName,
        Bio:         input.Bio,
        Avatar:      input.Avatar,
        CreatedAt:   time.Now(),
        UpdatedAt:   time.Now(),
    }

    insertQuery := `
        INSERT INTO users (username, email, display_name, bio, avatar, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING id
    `

    err = r.db.QueryRowContext(
        ctx,
        insertQuery,
        user.Username,
        user.Email,
        user.DisplayName,
        user.Bio,
        user.Avatar,
        user.CreatedAt,
        user.UpdatedAt,
    ).Scan(&user.ID)

    if err != nil {
        return nil, fmt.Errorf("failed to create user: %w", err)
    }

    return user, nil
}

func (r *mutationResolver) CreatePost(ctx context.Context, input models.CreatePostInput) (*models.Post, error) {
    // Get user ID from context (assuming authentication middleware sets this)
    userID := getUserIDFromContext(ctx)
    if userID == "" {
        return nil, fmt.Errorf("authentication required")
    }

    // Validate slug uniqueness
    var exists bool
    checkQuery := `SELECT EXISTS(SELECT 1 FROM posts WHERE slug = $1)`
    err := r.db.QueryRowContext(ctx, checkQuery, input.Slug).Scan(&exists)
    if err != nil {
        return nil, fmt.Errorf("failed to check slug uniqueness: %w", err)
    }

    if exists {
        return nil, fmt.Errorf("slug already exists")
    }

    // Begin transaction for post creation and tag associations
    tx, err := r.db.BeginTx(ctx, nil)
    if err != nil {
        return nil, fmt.Errorf("failed to begin transaction: %w", err)
    }
    defer tx.Rollback()

    // Create post
    post := &models.Post{
        Title:     input.Title,
        Content:   input.Content,
        Excerpt:   input.Excerpt,
        Slug:      input.Slug,
        Status:    input.Status,
        AuthorID:  userID,
        CreatedAt: time.Now(),
        UpdatedAt: time.Now(),
    }

    if input.Status == models.PostStatusPublished {
        now := time.Now()
        post.PublishedAt = &now
    }

    insertQuery := `
        INSERT INTO posts (title, content, excerpt, slug, status, author_id, created_at, updated_at, published_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING id
    `

    err = tx.QueryRowContext(
        ctx,
        insertQuery,
        post.Title,
        post.Content,
        post.Excerpt,
        post.Slug,
        post.Status,
        post.AuthorID,
        post.CreatedAt,
        post.UpdatedAt,
        post.PublishedAt,
    ).Scan(&post.ID)

    if err != nil {
        return nil, fmt.Errorf("failed to create post: %w", err)
    }

    // Associate tags if provided
    if len(input.TagIds) > 0 {
        for _, tagID := range input.TagIds {
            _, err = tx.ExecContext(ctx,
                `INSERT INTO post_tags (post_id, tag_id) VALUES ($1, $2)`,
                post.ID, tagID)
            if err != nil {
                return nil, fmt.Errorf("failed to associate tag: %w", err)
            }
        }
    }

    // Commit transaction
    err = tx.Commit()
    if err != nil {
        return nil, fmt.Errorf("failed to commit transaction: %w", err)
    }

    return post, nil
}

// Helper function for email validation
func isValidEmail(email string) bool {
    // Simple email validation - use a proper library in production
    return strings.Contains(email, "@") && strings.Contains(email, ".")
}

// Helper function to extract user ID from context
func getUserIDFromContext(ctx context.Context) string {
    if userID, ok := ctx.Value("userID").(string); ok {
        return userID
    }
    return ""
}
```

## Server Setup and Middleware Integration

Now let's create the main server file that brings everything together. We'll use chi router for its middleware ecosystem and performance characteristics:

```go
// main.go
package main

import (
    "database/sql"
    "log"
    "net/http"
    "os"

    "github.com/99designs/gqlgen/graphql/handler"
    "github.com/99designs/gqlgen/graphql/playground"
    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    _ "github.com/lib/pq" // PostgreSQL driver

    "github.com/yourusername/graphql-server/graph"
)

const defaultPort = "8080"

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = defaultPort
    }

    // Database connection
    db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        log.Fatal("Failed to connect to database:", err)
    }
    defer db.Close()

    // Create resolver with dependencies
    resolver := graph.NewResolver(db)

    // Create GraphQL server
    srv := handler.NewDefaultServer(graph.NewExecutableSchema(graph.Config{Resolvers: resolver}))

    // Setup router
    router := chi.NewRouter()

    // Middleware
    router.Use(middleware.Logger)
    router.Use(middleware.Recoverer)
    router.Use(middleware.RequestID)
    router.Use(middleware.RealIP)
    router.Use(corsMiddleware)

    // Routes
    router.Handle("/", playground.Handler("GraphQL playground", "/query"))
    router.Handle("/query", authMiddleware(srv))

    log.Printf("Connect to http://localhost:%s/ for GraphQL playground", port)
    log.Fatal(http.ListenAndServe(":"+port, router))
}

// CORS middleware for frontend integration
func corsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, Authorization")

        if r.Method == "OPTIONS" {
            return
        }

        next.ServeHTTP(w, r)
    })
}

// Authentication middleware
func authMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        token := r.Header.Get("Authorization")

        if token != "" {
            // Validate token and extract user ID
            // This is a simplified example - implement proper JWT validation
            userID := validateAndExtractUserID(token)
            if userID != "" {
                ctx := context.WithValue(r.Context(), "userID", userID)
                r = r.WithContext(ctx)
            }
        }

        next.ServeHTTP(w, r)
    })
}

func validateAndExtractUserID(token string) string {
    // Implement proper JWT validation here
    // Return user ID if token is valid, empty string otherwise
    return ""
}
```

## Performance Optimization and Caching Strategies

GraphQL servers can face unique performance challenges, particularly around the N+1 query problem. Let's implement dataloader pattern to efficiently batch database queries:

```go
// dataloader/user_loader.go
package dataloader

import (
    "context"
    "database/sql"
    "time"

    "github.com/graph-gophers/dataloader/v6"
    "github.com/yourusername/graphql-server/models"
)

type UserLoader struct {
    loader *dataloader.Loader[string, *models.User]
}

func NewUserLoader(db *sql.DB) *UserLoader {
    batchFn := func(ctx context.Context, keys []string) []*dataloader.Result[*models.User] {
        return batchGetUsers(ctx, db, keys)
    }

    return &UserLoader{
        loader: dataloader.NewBatchedLoader(
            batchFn,
            dataloader.WithWait[string, *models.User](10*time.Millisecond),
            dataloader.WithMaxBatch[string, *models.User](100),
        ),
    }
}

func (ul *UserLoader) Load(ctx context.Context, userID string) (*models.User, error) {
    return ul.loader.Load(ctx, userID)()
}

func batchGetUsers(ctx context.Context, db *sql.DB, userIDs []string) []*dataloader.Result[*models.User] {
    // Create placeholders for the IN clause
    placeholders := make([]string, len(userIDs))
    args := make([]interface{}, len(userIDs))

    for i, id := range userIDs {
        placeholders[i] = fmt.Sprintf("$%d", i+1)
        args[i] = id
    }

    query := fmt.Sprintf(`
        SELECT id, username, email, display_name, bio, avatar, created_at, updated_at
        FROM users WHERE id IN (%s)
    `, strings.Join(placeholders, ","))

    rows, err := db.QueryContext(ctx, query, args...)
    if err != nil {
        // Return error for all requested keys
        results := make([]*dataloader.Result[*models.User], len(userIDs))
        for i := range results {
            results[i] = &dataloader.Result[*models.User]{Error: err}
        }
        return results
    }
    defer rows.Close()

    // Create a map to store results by ID
    userMap := make(map[string]*models.User)

    for rows.Next() {
        var user models.User
        err := rows.Scan(
            &user.ID,
            &user.Username,
            &user.Email,
            &user.DisplayName,
            &user.Bio,
            &user.Avatar,
            &user.CreatedAt,
            &user.UpdatedAt,
        )
        if err != nil {
            continue
        }
        userMap[user.ID] = &user
    }

    // Create results in the same order as requested keys
    results := make([]*dataloader.Result[*models.User], len(userIDs))
    for i, userID := range userIDs {
        if user, found := userMap[userID]; found {
            results[i] = &dataloader.Result[*models.User]{Data: user}
        } else {
            results[i] = &dataloader.Result[*models.User]{Data: nil}
        }
    }

    return results
}
```

Integrate the dataloader into your resolver:

```go
// Update your resolver to use dataloader
func (r *Resolver) AddDataLoaders(db *sql.DB) {
    r.userLoader = dataloader.NewUserLoader(db)
}

// Update post resolver to use dataloader
func (r *postResolver) Author(ctx context.Context, obj *models.Post) (*models.User, error) {
    return r.userLoader.Load(ctx, obj.AuthorID)
}
```

## Testing Your GraphQL Server

Comprehensive testing is crucial for GraphQL APIs. Here's how to implement both unit and integration tests:

```go
// graph/resolver_test.go
package graph_test

import (
    "context"
    "database/sql"
    "testing"
    "time"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"

    "github.com/yourusername/graphql-server/graph"
    "github.com/yourusername/graphql-server/models"
)

func TestCreateUser(t *testing.T) {
    db := setupTestDB(t)
    defer db.Close()

    resolver := graph.NewResolver(db)
    ctx := context.Background()

    input := models.CreateUserInput{
        Username:    "testuser",
        Email:       "test@example.com",
        DisplayName: "Test User",
    }

    user, err := resolver.Mutation().CreateUser(ctx, input)

    require.NoError(t, err)
    assert.Equal(t, input.Username, user.Username)
    assert.Equal(t, input.Email, user.Email)
    assert.Equal(t, input.DisplayName, user.DisplayName)
    assert.NotEmpty(t, user.ID)
    assert.WithinDuration(t, time.Now(), user.CreatedAt, time.Second)
}

func TestUserPosts(t *testing.T) {
    db := setupTestDB(t)
    defer db.Close()

    // Setup test data
    user := createTestUser(t, db)
    createTestPost(t, db, user.ID)

    resolver := graph.NewResolver(db)
    ctx := context.Background()

    posts, err := resolver.User().Posts(ctx, user)

    require.NoError(t, err)
    assert.Len(t, posts, 1)
    assert.Equal(t, user.ID, posts[0].AuthorID)
}

func setupTestDB(t *testing.T) *sql.DB {
    // Setup test database connection
    // This could use testcontainers for a real PostgreSQL instance
    // or an in-memory database for faster tests

    db, err := sql.Open("postgres", "postgres://test:test@localhost/test?sslmode=disable")
    require.NoError(t, err)

    // Run migrations
    runTestMigrations(t, db)

    return db
}

func createTestUser(t *testing.T, db *sql.DB) *models.User {
    user := &models.User{
        Username:    "testuser",
        Email:       "test@example.com",
        DisplayName: "Test User",
        CreatedAt:   time.Now(),
        UpdatedAt:   time.Now(),
    }

    query := `
        INSERT INTO users (username, email, display_name, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5) RETURNING id
    `

    err := db.QueryRow(query, user.Username, user.Email, user.DisplayName, user.CreatedAt, user.UpdatedAt).Scan(&user.ID)
    require.NoError(t, err)

    return user
}
```

## Production Deployment and Security Considerations

When deploying your GraphQL server to production, several security and performance considerations become critical. Similar to [other Go web applications](/2025/04/using-context-in-go-cancellation.html), proper context handling and timeout management are essential for production stability.

Implement query complexity analysis to prevent expensive queries from overwhelming your server:

```go
// Add to your server setup
import "github.com/99designs/gqlgen/graphql/handler/extension"

srv := handler.NewDefaultServer(schema)

// Enable introspection only in development
if os.Getenv("ENVIRONMENT") != "production" {
    srv.Use(extension.Introspection{})
}

// Set query complexity limits
srv.Use(extension.FixedComplexityLimit(300))

// Enable automatic persisted queries for better caching
srv.Use(extension.AutomaticPersistedQuery{
    Cache: lru.New(1000),
})
```

For database integration in production environments, consider patterns similar to those used in [PostgreSQL connections with Go](/2025/05/connecting-postgresql-in-go-using-sqlx.html) for connection pooling and error handling.

## Advanced Features and Best Practices

As your GraphQL API grows, consider implementing subscriptions for real-time features:

```graphql
type Subscription {
    commentAdded(postId: ID!): Comment!
    postPublished: Post!
}
```

```go
func (r *subscriptionResolver) CommentAdded(ctx context.Context, postID string) (<-chan *models.Comment, error) {
    ch := make(chan *models.Comment)

    // Subscribe to comment events for the specific post
    go func() {
        defer close(ch)
        // Implement your real-time logic here
        // This could use Redis pub/sub, WebSocket connections, etc.
    }()

    return ch, nil
}
```

Monitor your GraphQL server's performance and query patterns to identify optimization opportunities. Tools like Apollo Studio or custom metrics collection can provide valuable insights into how clients use your API.

## Conclusion

Building GraphQL servers with gqlgen provides a robust, type-safe foundation for modern API development. The schema-first approach ensures clear contracts between frontend and backend teams while the generated code reduces boilerplate and prevents runtime errors.

This comprehensive guide has covered the essential aspects of GraphQL server development, from initial setup to production deployment. The patterns and practices demonstrated here will help you build scalable, maintainable GraphQL APIs that can grow with your application's needs.

For developers familiar with [building REST APIs in Go](/2025/09/building-rest-api-gin-framework-golang-production-ready.html), GraphQL offers a compelling alternative that can significantly improve client-server communication efficiency. The investment in learning GraphQL and gqlgen pays dividends in reduced over-fetching, better developer experience, and more flexible API evolution.

As you continue developing with GraphQL, remember that the key to success lies in thoughtful schema design, efficient resolver implementation, and careful attention to performance characteristics. The tools and patterns covered in this guide provide a solid foundation for building production-ready GraphQL services that can scale with your application's growth.