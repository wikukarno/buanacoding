---
title: "How to Perform Database Migrations in Go using golang-migrate"
description: "Complete guide to database migrations in Go using golang-migrate. Learn how to create, run, and manage database schema changes with PostgreSQL, MySQL, and SQLite including rollback strategies and production deployment."
date: 2025-10-05T10:00:00+07:00
draft: false
url: /2025/10/how-to-perform-database-migrations-in-go-using-golang-migrate.html
tags:
    - Go
    - Database
    - Migrations
    - PostgreSQL
    - MySQL
    - SQLite
    - Backend
    - Tutorial
description: "Complete guide to database migrations in Go using golang-migrate. Learn how to create, run, and manage database schema changes with PostgreSQL, MySQL, and SQLite including rollback strategies and production deployment."
keywords: ["golang database migration", "golang-migrate tutorial", "go database schema", "postgresql migration go", "mysql migration golang", "database versioning go", "golang migrate cli", "go migration rollback", "production database migration", "go backend tutorial"]
schema: "Article"
author: "BuanaCoding"
datePublished: "2025-10-05"
dateModified: "2025-10-05"

faq:
  - question: "What is golang-migrate and why should I use it?"
    answer: "golang-migrate is a database migration tool written in Go that helps you manage schema changes across different environments. It supports multiple databases (PostgreSQL, MySQL, SQLite, MongoDB), provides version control for your schema, allows rollbacks when things go wrong, and integrates seamlessly with Go applications. Using migrations instead of manual schema changes prevents inconsistencies between development, staging, and production databases."

  - question: "How do I handle migration failures in production?"
    answer: "Always test migrations in a staging environment first with production-like data. Use transactions when possible (most DDL operations in PostgreSQL support transactions). Keep a database backup before running migrations. Implement a rollback strategy - golang-migrate supports down migrations. Monitor migration execution time and lock durations. For large tables, consider online schema change tools like pt-online-schema-change for MySQL or pg_repack for PostgreSQL."

  - question: "Can I run migrations automatically when my Go application starts?"
    answer: "Yes, you can embed migrations in your Go application and run them at startup using migrate.NewWithSourceInstance with embedded files. However, this approach has risks in production - multiple instances starting simultaneously can cause conflicts, failed migrations block application startup, and you have less control over when migrations run. For production, use a separate migration step in your deployment pipeline before starting the application."

  - question: "What's the difference between up and down migrations?"
    answer: "Up migrations apply schema changes moving forward - creating tables, adding columns, inserting data. Down migrations reverse those changes - dropping tables, removing columns, deleting data. Every migration should have both up and down files so you can rollback if needed. Down migrations are critical for production safety when a deployment needs to be reverted quickly."

  - question: "How do I handle data migrations versus schema migrations?"
    answer: "Schema migrations change database structure (CREATE TABLE, ALTER COLUMN). Data migrations modify existing data (UPDATE statements, INSERT default records). golang-migrate handles both using SQL files. For complex data transformations, you can write Go code that runs as part of the migration. Keep data migrations idempotent so they can be run multiple times safely. Large data migrations should be done in batches to avoid locking tables for extended periods."

  - question: "Should I commit migration files to version control?"
    answer: "Absolutely yes. Migration files should be committed to git alongside your application code. This ensures every team member has the same schema version, makes it easy to track what changed and when, allows code review of schema changes, and ensures deployments include necessary migrations. Never modify existing migrations that have been applied in production - create new migrations instead."

  - question: "How do I test database migrations?"
    answer: "Create a test database and run migrations in your CI/CD pipeline. Write tests that apply migrations and verify the schema is correct. Test rollbacks by running down migrations. Use docker containers to create isolated test databases. Test with realistic data volumes to catch performance issues. Verify foreign key constraints, indexes, and default values are created correctly. Always test migrations in a staging environment before production."
---

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "How to Perform Database Migrations in Go using golang-migrate",
  "description": "Complete guide to database migrations in Go using golang-migrate. Learn how to create, run, and manage database schema changes with PostgreSQL, MySQL, and SQLite including rollback strategies and production deployment.",
  "author": {
    "@type": "Person",
    "name": "BuanaCoding",
    "url": "https://buanacoding.com/about/"
  },
  "publisher": {
    "@type": "Organization",
    "name": "BuanaCoding",
    "logo": {
      "@type": "ImageObject",
      "url": "https://buanacoding.com/logo.png"
    }
  },
  "datePublished": "2025-10-05",
  "dateModified": "2025-10-05",
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://buanacoding.com/2025/10/how-to-perform-database-migrations-in-go-using-golang-migrate.html"
  },
  "articleSection": "Programming",
  "keywords": ["golang database migration", "golang-migrate tutorial", "go database schema", "postgresql migration go", "mysql migration golang"],
  "about": [
    {
      "@type": "Thing",
      "name": "Database Migrations"
    },
    {
      "@type": "Thing",
      "name": "Go Programming"
    },
    {
      "@type": "Thing",
      "name": "Backend Development"
    }
  ]
}
</script>

Managing database schema changes is one of those tasks that seems simple until you're dealing with multiple environments, team members making conflicting changes, or trying to rollback a production deployment at 2 AM. If you've ever manually run SQL scripts on production hoping you didn't miss anything, you know exactly what I'm talking about.

golang-migrate solves this problem by giving you version control for your database schema. Just like git tracks code changes, migrations track schema changes. You can move forward, rollback, and know exactly what state your database is in at any time.

This guide covers everything you need to know about database migrations in Go - from basic setup to production deployment strategies. We'll use PostgreSQL for examples, but the concepts apply to MySQL, SQLite, and other databases that golang-migrate supports.

## Why You Need Database Migrations

When you're building a [Go backend application](/tags/go/), your database schema changes constantly during development. You add tables, modify columns, create indexes, insert seed data. Without migrations, you're stuck with a few bad options:

**Manual SQL scripts** - You write SQL and run it by hand. This works until someone forgets to run a script, runs scripts in the wrong order, or applies the same script twice. Ask me how I know.

**Schema dumps** - Export the entire schema and import it elsewhere. This destroys existing data and doesn't work for incremental changes. Not an option for production.

**ORM auto-migrations** - Some ORMs detect schema changes and apply them automatically. Sounds nice but gives you zero control over how changes are applied, makes rollbacks nearly impossible, and can cause data loss with column renames.

Migrations give you a better way. Each schema change is a versioned file that can be applied or reverted. Your database schema becomes reproducible and trackable.

## What is golang-migrate?

golang-migrate is a CLI tool and Go library for running database migrations. It's database-agnostic, supports multiple database drivers, handles migration versioning automatically, provides both CLI and programmatic interfaces, and has excellent PostgreSQL, MySQL, and SQLite support.

The tool uses pairs of SQL files - one for applying changes (up) and one for reverting them (down). Migration files are numbered sequentially, so golang-migrate knows which changes have been applied and which haven't.

Unlike some migration tools that try to be too clever, golang-migrate is straightforward. It runs your SQL files in order. That's it. This simplicity is actually a feature because you have complete control over your schema changes.

## Installing golang-migrate

You need two things: the CLI tool for running migrations from the terminal, and the Go library for running migrations from your application code.

Install the CLI tool:

```bash
# macOS
brew install golang-migrate

# Linux
curl -L https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.linux-amd64.tar.gz | tar xvz
sudo mv migrate /usr/local/bin/migrate

# Windows
scoop install migrate

# Or build from source
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
```

Verify installation:

```bash
migrate -version
# v4.17.0
```

Install the Go library in your project:

```bash
go get -u github.com/golang-migrate/migrate/v4
go get -u github.com/golang-migrate/migrate/v4/database/postgres
go get -u github.com/golang-migrate/migrate/v4/source/file
```

The database driver package depends on which database you're using. For PostgreSQL it's `database/postgres`, for MySQL it's `database/mysql`, for SQLite it's `database/sqlite3`.

## Project Structure for Migrations

Here's how I organize migrations in Go projects:

```
myapp/
├── cmd/
│   └── api/
│       └── main.go
├── migrations/
│   ├── 000001_create_users_table.up.sql
│   ├── 000001_create_users_table.down.sql
│   ├── 000002_create_posts_table.up.sql
│   ├── 000002_create_posts_table.down.sql
│   ├── 000003_add_email_to_users.up.sql
│   └── 000003_add_email_to_users.down.sql
├── internal/
│   ├── database/
│   │   └── migrate.go
│   └── models/
├── go.mod
└── go.sum
```

The `migrations/` folder contains all migration files. Each migration has two files - `up` for applying changes and `down` for reverting them. Files are numbered sequentially so they run in order.

## Creating Your First Migration

Let's create a migration for a users table. The naming convention is `{version}_{description}.{direction}.sql`.

Create the migration files:

```bash
migrate create -ext sql -dir migrations -seq create_users_table
```

This creates two files:
- `000001_create_users_table.up.sql`
- `000001_create_users_table.down.sql`

Edit the up migration (`000001_create_users_table.up.sql`):

```sql
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
```

Edit the down migration (`000001_create_users_table.down.sql`):

```sql
DROP TABLE IF EXISTS users CASCADE;
```

The up migration creates the table with indexes. The down migration drops it. Always include `CASCADE` when dropping tables that might have foreign keys pointing to them.

## Running Migrations from CLI

The simplest way to run migrations is using the CLI tool. You need a database URL in the format:

```
postgres://username:password@localhost:5432/database_name?sslmode=disable
```

Run all pending migrations:

```bash
migrate -database "postgres://user:password@localhost:5432/myapp?sslmode=disable" \
        -path migrations \
        up
```

This applies all migrations that haven't been run yet. golang-migrate tracks which migrations have been applied using a `schema_migrations` table.

Run a specific number of migrations:

```bash
# Apply next 2 migrations
migrate -database "postgres://..." -path migrations up 2
```

Rollback migrations:

```bash
# Rollback last migration
migrate -database "postgres://..." -path migrations down 1

# Rollback all migrations
migrate -database "postgres://..." -path migrations down -all
```

Check current migration version:

```bash
migrate -database "postgres://..." -path migrations version
```

Force a specific version (use carefully):

```bash
migrate -database "postgres://..." -path migrations force 1
```

The `force` command is useful when a migration partially failed and you need to reset the version before retrying.

## Running Migrations from Go Code

For production applications, you typically run migrations programmatically when the application starts or as a separate deployment step. Here's how to do it in Go.

Create `internal/database/migrate.go`:

```go
package database

import (
    "database/sql"
    "fmt"
    "log"

    "github.com/golang-migrate/migrate/v4"
    "github.com/golang-migrate/migrate/v4/database/postgres"
    _ "github.com/golang-migrate/migrate/v4/source/file"
)

func RunMigrations(db *sql.DB, migrationsPath string) error {
    driver, err := postgres.WithInstance(db, &postgres.Config{})
    if err != nil {
        return fmt.Errorf("could not create database driver: %w", err)
    }

    m, err := migrate.NewWithDatabaseInstance(
        fmt.Sprintf("file://%s", migrationsPath),
        "postgres",
        driver,
    )
    if err != nil {
        return fmt.Errorf("could not create migrate instance: %w", err)
    }

    if err := m.Up(); err != nil && err != migrate.ErrNoChange {
        return fmt.Errorf("could not run migrations: %w", err)
    }

    log.Println("Migrations completed successfully")
    return nil
}

func RollbackMigrations(db *sql.DB, migrationsPath string, steps int) error {
    driver, err := postgres.WithInstance(db, &postgres.Config{})
    if err != nil {
        return fmt.Errorf("could not create database driver: %w", err)
    }

    m, err := migrate.NewWithDatabaseInstance(
        fmt.Sprintf("file://%s", migrationsPath),
        "postgres",
        driver,
    )
    if err != nil {
        return fmt.Errorf("could not create migrate instance: %w", err)
    }

    if err := m.Steps(-steps); err != nil {
        return fmt.Errorf("could not rollback migrations: %w", err)
    }

    log.Printf("Rolled back %d migrations\n", steps)
    return nil
}
```

Use it in your main application (`cmd/api/main.go`):

```go
package main

import (
    "database/sql"
    "log"
    "os"

    _ "github.com/lib/pq"
    "myapp/internal/database"
)

func main() {
    dbURL := os.Getenv("DATABASE_URL")
    if dbURL == "" {
        log.Fatal("DATABASE_URL environment variable is required")
    }

    db, err := sql.Open("postgres", dbURL)
    if err != nil {
        log.Fatalf("Failed to connect to database: %v", err)
    }
    defer db.Close()

    if err := db.Ping(); err != nil {
        log.Fatalf("Failed to ping database: %v", err)
    }

    // Run migrations
    if err := database.RunMigrations(db, "./migrations"); err != nil {
        log.Fatalf("Failed to run migrations: %v", err)
    }

    log.Println("Database connection and migrations successful")

    // Start your application...
}
```

This approach runs migrations automatically when your application starts. For production, you might want a separate migration command instead of running migrations on every startup.

## Creating a Migration CLI Tool

Instead of running migrations at application startup, create a dedicated CLI tool for managing migrations. This gives you more control in production.

Create `cmd/migrate/main.go`:

```go
package main

import (
    "database/sql"
    "flag"
    "fmt"
    "log"
    "os"

    _ "github.com/lib/pq"
    "myapp/internal/database"
)

func main() {
    var action string
    var steps int

    flag.StringVar(&action, "action", "up", "Migration action: up, down, or version")
    flag.IntVar(&steps, "steps", 0, "Number of migration steps (for down action)")
    flag.Parse()

    dbURL := os.Getenv("DATABASE_URL")
    if dbURL == "" {
        log.Fatal("DATABASE_URL environment variable is required")
    }

    db, err := sql.Open("postgres", dbURL)
    if err != nil {
        log.Fatalf("Failed to connect to database: %v", err)
    }
    defer db.Close()

    migrationsPath := "./migrations"

    switch action {
    case "up":
        if err := database.RunMigrations(db, migrationsPath); err != nil {
            log.Fatalf("Migration failed: %v", err)
        }
        fmt.Println("Migrations applied successfully")

    case "down":
        if steps == 0 {
            log.Fatal("Please specify -steps for down migrations")
        }
        if err := database.RollbackMigrations(db, migrationsPath, steps); err != nil {
            log.Fatalf("Rollback failed: %v", err)
        }
        fmt.Printf("Rolled back %d migrations\n", steps)

    case "version":
        version, dirty, err := database.GetMigrationVersion(db, migrationsPath)
        if err != nil {
            log.Fatalf("Failed to get version: %v", err)
        }
        fmt.Printf("Current version: %d (dirty: %v)\n", version, dirty)

    default:
        log.Fatalf("Unknown action: %s", action)
    }
}
```

Add the version function to `internal/database/migrate.go`:

```go
func GetMigrationVersion(db *sql.DB, migrationsPath string) (uint, bool, error) {
    driver, err := postgres.WithInstance(db, &postgres.Config{})
    if err != nil {
        return 0, false, fmt.Errorf("could not create database driver: %w", err)
    }

    m, err := migrate.NewWithDatabaseInstance(
        fmt.Sprintf("file://%s", migrationsPath),
        "postgres",
        driver,
    )
    if err != nil {
        return 0, false, fmt.Errorf("could not create migrate instance: %w", err)
    }

    version, dirty, err := m.Version()
    if err != nil && err != migrate.ErrNilVersion {
        return 0, false, fmt.Errorf("could not get version: %w", err)
    }

    return version, dirty, nil
}
```

Build and use the migration tool:

```bash
go build -o bin/migrate cmd/migrate/main.go

# Run migrations
DATABASE_URL="postgres://user:pass@localhost/myapp?sslmode=disable" ./bin/migrate -action up

# Rollback 1 migration
DATABASE_URL="postgres://user:pass@localhost/myapp?sslmode=disable" ./bin/migrate -action down -steps 1

# Check version
DATABASE_URL="postgres://user:pass@localhost/myapp?sslmode=disable" ./bin/migrate -action version
```

This approach separates migration execution from application startup, which is safer for production deployments.

## Real-World Migration Examples

Let's look at common migration scenarios you'll encounter.

### Adding a Column

Create migration:

```bash
migrate create -ext sql -dir migrations -seq add_bio_to_users
```

Up migration (`000002_add_bio_to_users.up.sql`):

```sql
ALTER TABLE users ADD COLUMN bio TEXT;
ALTER TABLE users ADD COLUMN avatar_url VARCHAR(500);
```

Down migration (`000002_add_bio_to_users.down.sql`):

```sql
ALTER TABLE users DROP COLUMN bio;
ALTER TABLE users DROP COLUMN avatar_url;
```

### Creating a Related Table

Create migration:

```bash
migrate create -ext sql -dir migrations -seq create_posts_table
```

Up migration (`000003_create_posts_table.up.sql`):

```sql
CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    published BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_published ON posts(published);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
```

Down migration (`000003_create_posts_table.down.sql`):

```sql
DROP TABLE IF EXISTS posts CASCADE;
```

### Modifying Column Type

This one's tricky because you might lose data. Always backup first.

Create migration:

```bash
migrate create -ext sql -dir migrations -seq change_username_length
```

Up migration (`000004_change_username_length.up.sql`):

```sql
ALTER TABLE users ALTER COLUMN username TYPE VARCHAR(100);
```

Down migration (`000004_change_username_length.down.sql`):

```sql
ALTER TABLE users ALTER COLUMN username TYPE VARCHAR(50);
```

The down migration might fail if data exceeds 50 characters. For production, you'd add a CHECK constraint first to ensure no data violates the limit.

### Adding Constraints

Create migration:

```bash
migrate create -ext sql -dir migrations -seq add_user_constraints
```

Up migration (`000005_add_user_constraints.up.sql`):

```sql
ALTER TABLE users ADD CONSTRAINT username_min_length CHECK (LENGTH(username) >= 3);
ALTER TABLE users ADD CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$');
```

Down migration (`000005_add_user_constraints.down.sql`):

```sql
ALTER TABLE users DROP CONSTRAINT IF EXISTS username_min_length;
ALTER TABLE users DROP CONSTRAINT IF EXISTS email_format;
```

### Data Migrations

Sometimes you need to migrate data, not just schema. Here's an example of adding a default role to existing users.

Create migration:

```bash
migrate create -ext sql -dir migrations -seq add_role_to_users
```

Up migration (`000006_add_role_to_users.up.sql`):

```sql
-- Add column
ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'user';

-- Update existing users
UPDATE users SET role = 'user' WHERE role IS NULL;

-- Make it non-nullable after setting defaults
ALTER TABLE users ALTER COLUMN role SET NOT NULL;
```

Down migration (`000006_add_role_to_users.down.sql`):

```sql
ALTER TABLE users DROP COLUMN role;
```

The up migration adds the column with a default, updates existing rows, then makes it non-nullable. This prevents errors with existing data.

## Working with Multiple Databases

golang-migrate supports PostgreSQL, MySQL, SQLite, MongoDB, and more. The API is the same, only the driver changes.

### MySQL Example

```go
import (
    "github.com/golang-migrate/migrate/v4"
    "github.com/golang-migrate/migrate/v4/database/mysql"
    _ "github.com/golang-migrate/migrate/v4/source/file"
    _ "github.com/go-sql-driver/mysql"
)

func RunMySQLMigrations(db *sql.DB, migrationsPath string) error {
    driver, err := mysql.WithInstance(db, &mysql.Config{})
    if err != nil {
        return err
    }

    m, err := migrate.NewWithDatabaseInstance(
        fmt.Sprintf("file://%s", migrationsPath),
        "mysql",
        driver,
    )
    if err != nil {
        return err
    }

    return m.Up()
}
```

MySQL migrations use MySQL-specific SQL:

```sql
-- MySQL up migration
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### SQLite Example

```go
import (
    "github.com/golang-migrate/migrate/v4"
    "github.com/golang-migrate/migrate/v4/database/sqlite3"
    _ "github.com/golang-migrate/migrate/v4/source/file"
    _ "github.com/mattn/go-sqlite3"
)

func RunSQLiteMigrations(db *sql.DB, migrationsPath string) error {
    driver, err := sqlite3.WithInstance(db, &sqlite3.Config{})
    if err != nil {
        return err
    }

    m, err := migrate.NewWithDatabaseInstance(
        fmt.Sprintf("file://%s", migrationsPath),
        "sqlite3",
        driver,
    )
    if err != nil {
        return err
    }

    return m.Up()
}
```

SQLite has different syntax for some operations:

```sql
-- SQLite doesn't support ALTER COLUMN
-- You have to recreate the table
CREATE TABLE users_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users_new SELECT * FROM users;
DROP TABLE users;
ALTER TABLE users_new RENAME TO users;
```

## Embedding Migrations in Your Binary

For simpler deployments, you can embed migration files directly in your Go binary using Go 1.16+ embed feature.

Update `internal/database/migrate.go`:

```go
package database

import (
    "database/sql"
    "embed"
    "fmt"

    "github.com/golang-migrate/migrate/v4"
    "github.com/golang-migrate/migrate/v4/database/postgres"
    "github.com/golang-migrate/migrate/v4/source/iofs"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

func RunEmbeddedMigrations(db *sql.DB) error {
    driver, err := postgres.WithInstance(db, &postgres.Config{})
    if err != nil {
        return fmt.Errorf("could not create database driver: %w", err)
    }

    sourceDriver, err := iofs.New(migrationsFS, "migrations")
    if err != nil {
        return fmt.Errorf("could not create source driver: %w", err)
    }

    m, err := migrate.NewWithInstance("iofs", sourceDriver, "postgres", driver)
    if err != nil {
        return fmt.Errorf("could not create migrate instance: %w", err)
    }

    if err := m.Up(); err != nil && err != migrate.ErrNoChange {
        return fmt.Errorf("could not run migrations: %w", err)
    }

    return nil
}
```

Move migrations to `internal/database/migrations/`:

```
internal/
└── database/
    ├── migrate.go
    └── migrations/
        ├── 000001_create_users_table.up.sql
        ├── 000001_create_users_table.down.sql
        └── ...
```

Now your binary includes migrations - no need to deploy migration files separately.

## Testing Migrations

Always test migrations before running them in production. Here's how to set up automated migration testing.

Create `internal/database/migrate_test.go`:

```go
package database

import (
    "database/sql"
    "testing"

    _ "github.com/lib/pq"
)

func TestMigrations(t *testing.T) {
    // Use a test database
    dbURL := "postgres://testuser:testpass@localhost:5432/testdb?sslmode=disable"

    db, err := sql.Open("postgres", dbURL)
    if err != nil {
        t.Fatalf("Failed to connect to test database: %v", err)
    }
    defer db.Close()

    // Clean database before test
    if _, err := db.Exec("DROP SCHEMA public CASCADE; CREATE SCHEMA public;"); err != nil {
        t.Fatalf("Failed to clean database: %v", err)
    }

    // Run migrations
    if err := RunMigrations(db, "../../migrations"); err != nil {
        t.Fatalf("Failed to run migrations: %v", err)
    }

    // Verify schema
    var count int
    err = db.QueryRow("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users'").Scan(&count)
    if err != nil {
        t.Fatalf("Failed to query tables: %v", err)
    }

    if count != 1 {
        t.Errorf("Expected users table to exist, but it doesn't")
    }

    // Test rollback
    if err := RollbackMigrations(db, "../../migrations", 1); err != nil {
        t.Fatalf("Failed to rollback migrations: %v", err)
    }

    // Verify table was dropped
    err = db.QueryRow("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users'").Scan(&count)
    if err != nil {
        t.Fatalf("Failed to query tables after rollback: %v", err)
    }

    if count != 0 {
        t.Errorf("Expected users table to be dropped, but it still exists")
    }
}
```

Run with docker for isolated testing:

```bash
docker run -d --name test-postgres \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=testdb \
  -p 5432:5432 \
  postgres:15

go test ./internal/database/...

docker stop test-postgres
docker rm test-postgres
```

## Production Deployment Strategies

Running migrations in production requires careful planning. Here are proven strategies.

### Separate Migration Step

Run migrations as a separate step before deploying your application:

```yaml
# .github/workflows/deploy.yml
- name: Run database migrations
  run: |
    ./bin/migrate -action up
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}

- name: Deploy application
  run: |
    ./deploy.sh
```

This ensures migrations complete successfully before the new application version starts.

### Blue-Green Deployments

For zero-downtime deployments, make migrations backward-compatible so both old and new code can run against the same schema.

Adding a column:

```sql
-- Safe: old code ignores new column
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
```

Removing a column requires two deployments:

```sql
-- Deployment 1: stop using the column in code
-- Deployment 2: drop the column
ALTER TABLE users DROP COLUMN phone;
```

### Migration Locks

Prevent concurrent migrations using database locks:

```go
func RunMigrationsWithLock(db *sql.DB, migrationsPath string) error {
    // Acquire advisory lock
    var locked bool
    err := db.QueryRow("SELECT pg_try_advisory_lock(123456789)").Scan(&locked)
    if err != nil {
        return fmt.Errorf("failed to acquire lock: %w", err)
    }
    if !locked {
        return fmt.Errorf("another migration is already running")
    }
    defer db.Exec("SELECT pg_advisory_unlock(123456789)")

    // Run migrations
    return RunMigrations(db, migrationsPath)
}
```

This prevents issues when multiple instances try to run migrations simultaneously.

### Database Backups

Always backup before migrations:

```bash
#!/bin/bash
# backup-and-migrate.sh

# Backup database
pg_dump -U user -h localhost dbname > backup_$(date +%Y%m%d_%H%M%S).sql

# Run migrations
./bin/migrate -action up

if [ $? -ne 0 ]; then
  echo "Migration failed! Restore from backup if needed"
  exit 1
fi

echo "Migration successful"
```

## Common Migration Pitfalls

**Editing existing migrations** - Never modify a migration that's been applied in production. Create a new migration instead.

**Missing down migrations** - Always write down migrations. You'll need them when deployments fail.

**Large data migrations** - Updating millions of rows locks tables. Split into batches or use background jobs.

**Not testing rollbacks** - Test your down migrations. Discovering they don't work during a production incident is too late.

**Ignoring migration order** - Migrations run in version order. Don't depend on migrations that come later.

**Dropping columns with data** - Add migrations to move data before dropping columns, or you'll lose information.

## Integrating with ORMs

If you're using an ORM like [GORM](https://gorm.io/) or [sqlx](https://github.com/jmoiron/sqlx), you can still use golang-migrate for schema management while using the ORM for queries.

Example with GORM:

```go
package main

import (
    "log"

    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    "myapp/internal/database"
)

type User struct {
    ID       uint   `gorm:"primaryKey"`
    Username string `gorm:"unique;not null"`
    Email    string `gorm:"unique;not null"`
}

func main() {
    // Connect to database
    db, err := sql.Open("postgres", dbURL)
    if err != nil {
        log.Fatal(err)
    }

    // Run migrations
    if err := database.RunMigrations(db, "./migrations"); err != nil {
        log.Fatal(err)
    }

    // Use GORM for queries
    gormDB, err := gorm.Open(postgres.New(postgres.Config{
        Conn: db,
    }), &gorm.Config{})
    if err != nil {
        log.Fatal(err)
    }

    // Now use GORM
    var users []User
    gormDB.Find(&users)
}
```

This gives you controlled migrations with golang-migrate and convenient queries with GORM. Avoid GORM's `AutoMigrate()` in production - use explicit migration files instead.

## Monitoring and Observability

Track migration execution in production:

```go
func RunMigrationsWithLogging(db *sql.DB, migrationsPath string) error {
    start := time.Now()

    log.Println("Starting database migrations...")

    err := RunMigrations(db, migrationsPath)

    duration := time.Since(start)

    if err != nil {
        log.Printf("Migration failed after %v: %v", duration, err)
        return err
    }

    log.Printf("Migrations completed successfully in %v", duration)
    return nil
}
```

For production systems, integrate with your monitoring stack:

```go
// Send metrics to Prometheus, DataDog, etc.
migrationDuration.Observe(duration.Seconds())
if err != nil {
    migrationErrors.Inc()
}
```

## Advanced: Custom Migration Sources

You can load migrations from sources other than files - databases, HTTP endpoints, or embedded resources.

Example loading from HTTP:

```go
import (
    "github.com/golang-migrate/migrate/v4"
    _ "github.com/golang-migrate/migrate/v4/source/httpfs"
)

m, err := migrate.New(
    "https://example.com/migrations",
    "postgres://user:pass@localhost/db?sslmode=disable",
)
```

This is useful for centralized migration management across multiple services.

## Schema Migration Best Practices

After managing migrations across dozens of projects, here's what works:

**Keep migrations small** - One logical change per migration makes rollbacks easier and reduces risk.

**Test migrations locally** - Run up and down migrations locally before committing. Catch syntax errors early.

**Use transactions when possible** - PostgreSQL supports transactional DDL. Wrap migrations in BEGIN/COMMIT blocks.

**Document complex migrations** - Add SQL comments explaining why the change is needed, especially for data migrations.

**Version control is mandatory** - Commit migration files with the code that uses them. Deploy together.

**Never skip migrations** - Always run migrations sequentially. Jumping versions causes inconsistent state.

**Plan for rollback** - Write down migrations that actually work. Test them before deploying.

## Wrapping Up

Database migrations are essential for any production [Go application](/tags/go/) that uses a database. golang-migrate gives you the tools to manage schema changes safely across environments, track database versions like you track code, rollback when deployments fail, and collaborate with your team without conflicts.

The key is treating your database schema as code. Version it, review it, test it, and deploy it systematically. Manual schema changes are error-prone and don't scale beyond one developer.

Start simple - create migrations for your tables, run them locally, test rollbacks. As your application grows, add more sophisticated deployment strategies like migration locks, backups, and monitoring.

If you're building APIs in Go, check out our guide on [building REST APIs](/tags/rest-api/) and [OAuth2 authentication in Go](/2025/10/how-to-implement-oauth2-in-go-google-github-facebook-login.html). For DevOps workflows, see our articles on [Docker deployment](/tags/docker/) and [CI/CD pipelines](/tags/deploy/).

Database migrations might seem like extra work upfront, but they save countless hours debugging production issues and coordinating schema changes across teams. Trust me - your future self will thank you.

## Frequently Asked Questions

**What is golang-migrate and why should I use it?**

golang-migrate is a database migration tool written in Go that helps you manage schema changes across different environments. It supports multiple databases (PostgreSQL, MySQL, SQLite, MongoDB), provides version control for your schema, allows rollbacks when things go wrong, and integrates seamlessly with Go applications. Using migrations instead of manual schema changes prevents inconsistencies between development, staging, and production databases.

**How do I handle migration failures in production?**

Always test migrations in a staging environment first with production-like data. Use transactions when possible (most DDL operations in PostgreSQL support transactions). Keep a database backup before running migrations. Implement a rollback strategy - golang-migrate supports down migrations. Monitor migration execution time and lock durations. For large tables, consider online schema change tools like pt-online-schema-change for MySQL or pg_repack for PostgreSQL.

**Can I run migrations automatically when my Go application starts?**

Yes, you can embed migrations in your Go application and run them at startup using migrate.NewWithSourceInstance with embedded files. However, this approach has risks in production - multiple instances starting simultaneously can cause conflicts, failed migrations block application startup, and you have less control over when migrations run. For production, use a separate migration step in your deployment pipeline before starting the application.

**What's the difference between up and down migrations?**

Up migrations apply schema changes moving forward - creating tables, adding columns, inserting data. Down migrations reverse those changes - dropping tables, removing columns, deleting data. Every migration should have both up and down files so you can rollback if needed. Down migrations are critical for production safety when a deployment needs to be reverted quickly.

**How do I handle data migrations versus schema migrations?**

Schema migrations change database structure (CREATE TABLE, ALTER COLUMN). Data migrations modify existing data (UPDATE statements, INSERT default records). golang-migrate handles both using SQL files. For complex data transformations, you can write Go code that runs as part of the migration. Keep data migrations idempotent so they can be run multiple times safely. Large data migrations should be done in batches to avoid locking tables for extended periods.

**Should I commit migration files to version control?**

Absolutely yes. Migration files should be committed to git alongside your application code. This ensures every team member has the same schema version, makes it easy to track what changed and when, allows code review of schema changes, and ensures deployments include necessary migrations. Never modify existing migrations that have been applied in production - create new migrations instead.

**How do I test database migrations?**

Create a test database and run migrations in your CI/CD pipeline. Write tests that apply migrations and verify the schema is correct. Test rollbacks by running down migrations. Use docker containers to create isolated test databases. Test with realistic data volumes to catch performance issues. Verify foreign key constraints, indexes, and default values are created correctly. Always test migrations in a staging environment before production.
