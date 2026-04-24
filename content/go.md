---
title: "Learn Go Programming — Complete Tutorial Index (2025)"
date: 2026-04-24
lastmod: 2026-04-24
description: "The complete index of Go (Golang) tutorials on BuanaCoding — 55+ guides covering fundamentals, concurrency, web APIs, databases, authentication, testing, microservices, and production deployment."
url: /go/
disable_comments: true
---

Go (Golang) is a compiled, statically-typed language from Google built for simplicity, fast compilation, and first-class concurrency. It powers Kubernetes, Docker, Terraform, CockroachDB, and a huge slice of modern backend infrastructure.

This page is a curated index of **every Go tutorial on BuanaCoding**, organized by topic so you can follow a clear path — from installing the toolchain to shipping production microservices. Bookmark it; new posts land here first.

New to Go? Start with **Getting Started**, then work through the **Fundamentals**. Already shipping Go? Jump straight to **Web APIs**, **Databases**, or **Microservices**.

---

## 🚀 Getting Started

If you have never written a line of Go, begin here. You will install the toolchain, understand the module system, and structure your first project.

- [Easiest Way to Install Go on Linux (Snap or Manual)](/2024/04/easiest-way-to-install-golang-on-linux.html)
- [Structuring Go Projects — Clean Layout & Best Practices](/2025/05/structuring-go-projects-clean-project-structure-and-best-practices.html)
- [Private Repos, Semantic Import v2+, and `go.work`](/2025/09/advanced-go-modules-private-repos-semantic-import-v2-go-work.html)

## 📦 Go Fundamentals

The core language: data types, variables, operators, and control flow. Every Go developer needs these cold before touching concurrency or web code.

- [Numeric Data Types in Go — Basics and Practical Examples](/2024/07/understanding-numeric-data-type-in-go.html)
- [String Data Type in Go — Basics and Practical Examples](/2024/07/understanding-string-data-type-in-go.html)
- [Boolean Data Type in Go — Basics and Practical Examples](/2024/07/understanding-booleans-in-go-basics.html)
- [Conditional Statements in Go — `if`, `switch`, and More](/2025/04/understanding-conditional-statements-in.html)
- [Loops in Go — `for`, `range`, `break`, and `continue` Explained](/2025/04/understanding-loops-in-go-for-range.html)
- [Functions in Go — A Beginner's Guide](/2025/04/understanding-functions-in-go-beginners.html)
- [Error Handling in Go — Managing Errors the Right Way](/2025/04/error-handling-in-go-managing-errors.html)

## 🔗 Structs, Pointers & Interfaces

Go's type system is small but powerful. Master these four building blocks and most code becomes easy to read and easy to change.

- [Pointers in Go — Reference Types and Receivers Explained](/2025/04/understanding-pointers-in-go-reference.html)
- [Structs and Methods in Go — Defining and Using Custom Types](/2025/04/structs-and-methods-in-go-defining-and.html)
- [Interfaces in Go — Building Flexible and Reusable Code](/2025/04/interfaces-in-go-building-flexible-and.html)
- [Generics in Go — Writing Reusable and Type-Safe Code](/2025/04/generics-in-go-writing-reusable-and-type-safe-code.html)

## 📚 Collections, JSON & Files

Working with data: slices, maps, JSON encoding/decoding, and the filesystem. The bread-and-butter of real-world Go programs.

- [Collections in Go — Arrays, Slices, and Maps Explained](/2025/04/working-with-collections-in-go-arrays.html)
- [Working with JSON in Go — Encode, Decode, and Struct Tags](/2025/04/working-with-json-in-go-encode-decode.html)
- [File Handling in Go — Read, Write, and Manage Files](/2025/04/file-handling-in-go-read-write-and.html)
- [How to Handle File Uploads in Go — Validation, Storage, Security](/2025/10/how-to-handle-file-uploads-in-go-validation-storage-and-security.html)

## ⚡ Concurrency & Context

The feature Go is famous for. Goroutines, channels, synchronization primitives, and `context.Context` — covered end to end.

- [Concurrency in Go — Goroutines and Channels Explained](/2025/04/concurrency-in-go-goroutines-and.html)
- [Synchronizing Goroutines — `sync.Mutex` and `sync.Once`](/2025/04/synchronizing-goroutines-in-go-using.html)
- [Using Context in Go — Cancellation, Timeouts, and Deadlines](/2025/04/using-context-in-go-cancellation.html)

## 🧪 Testing & Performance

Ship Go code with confidence: unit tests, mocks, benchmarks, and production profiling with `pprof`.

- [Testing in Go — Writing Unit Tests with the `testing` Package](/2025/04/testing-in-go-writing-unit-tests-with.html)
- [Mock Testing in Go with Testify and Mockery](/2025/10/how-to-use-mock-testing-in-go-with-testify-and-mockery.html)
- [Benchmarking in Go — Measuring Performance with `testing.B`](/2025/04/benchmarking-in-go-measuring.html)
- [Profile and Optimize Go Applications with `pprof`](/2025/10/how-to-profile-and-optimize-go-applications-with-pprof.html)

## 🌐 Web APIs & Frameworks

REST, GraphQL, gRPC, WebSockets — and the frameworks that make them ergonomic in Go.

- [Build a REST API in Go using `net/http`](/2025/05/how-to-build-a-rest-api-in-go-using-net-http.html)
- [Building REST API with Gin — Production-Ready](/2025/09/building-rest-api-gin-framework-golang-production-ready.html)
- [Fiber vs Gin vs Echo — Go Framework Comparison 2025](/2025/09/fiber-vs-gin-vs-echo-golang-framework-comparison-2025.html)
- [GraphQL with Golang — A Modern Alternative to REST](/2025/09/graphql-golang-modern-alternative-rest-api.html)
- [Build a GraphQL Server with `gqlgen`](/2025/09/building-graphql-server-gqlgen-golang.html)
- [gRPC in Go — Complete Guide from Basics to Production](/2025/08/grpc-in-go-complete-guide-from-basics-to-production.html)
- [Build WebSocket Applications in Go — Real-Time Chat Example](/2025/10/how-to-build-websocket-applications-in-go-real-time-chat.html)
- [Build a CLI Tool in Go with Cobra and Viper](/2025/10/how-to-build-a-cli-tool-in-go-with-cobra-and-viper.html)

## 💾 Databases & Caching

Relational, document, and key-value stores — plus the migration tooling to keep schemas sane.

- [PostgreSQL in Go using `sqlx`](/2025/05/connecting-postgresql-in-go-using-sqlx.html)
- [MySQL in Go — Connection Pooling and Transactions](/2025/10/how-to-work-with-mysql-in-go-connection-pooling-and-transactions.html)
- [MongoDB in Go — Complete CRUD Tutorial](/2025/10/how-to-work-with-mongodb-in-go-complete-crud-tutorial.html)
- [Redis with Go — Caching and Session Management](/2025/10/how-to-use-redis-with-go-caching-session-management.html)
- [Database Migrations in Go with `golang-migrate`](/2025/10/how-to-perform-database-migrations-in-go-using-golang-migrate.html)

## 🔐 Authentication & Security

JWT, OAuth2, sessions, passkeys, rate limiting — the full stack of modern auth patterns for Go APIs.

- [JWT Authentication in Go — Secure REST API Tutorial](/2025/09/how-to-implement-jwt-authentication-in-go-secure-rest-api.html)
- [OAuth2 in Go — Google, GitHub, and Facebook Login](/2025/10/how-to-implement-oauth2-in-go-google-github-facebook-login.html)
- [Session Management in Go — Cookies and Redis](/2025/10/how-to-implement-session-management-in-go-cookies-and-redis.html)
- [Passkey Authentication in Go — WebAuthn Tutorial](/2025/11/how-to-implement-passkey-authentication-go-webauthn.html)
- [Rate Limiting in Go — Protect Your API from Abuse](/2025/10/how-to-implement-rate-limiting-in-go-protect-api-from-abuse.html)

## 🚢 Production & DevOps

Everything between `go build` and a live service: containers, CI/CD, logging, background jobs, email, and cloud storage.

- [Containerize and Deploy Go Apps with Docker](/2025/10/how-to-containerize-and-deploy-go-apps-with-docker.html)
- [CI/CD for Go Applications with GitHub Actions](/2025/10/how-to-implement-cicd-for-go-applications-with-github-actions.html)
- [The Complete Guide to `slog` — Structured Logging (Go 1.21+)](/2025/09/complete-guide-slog-go-structured-logging-2025.html)
- [Background Jobs in Go with Asynq and Redis](/2025/10/how-to-implement-background-jobs-in-go-with-asynq-and-redis.html)
- [Send Emails in Go — SMTP, SendGrid, and Mailgun](/2025/10/how-to-send-emails-in-go-smtp-sendgrid-mailgun.html)
- [Upload Files to AWS S3 in Go with SDK v2](/2025/10/how-to-upload-files-to-aws-s3-in-go-with-sdk-v2.html)

## 🏗️ Microservices & Architecture

Splitting Go systems into services: patterns, messaging, discovery, and the API gateway at the edge.

- [Microservices with Golang — Architecture and Implementation Guide](/2025/09/microservices-golang-architecture-implementation-guide.html)
- [Event-Driven Architecture with Golang and Message Queues](/2025/09/event-driven-architecture-golang-message-queues.html)
- [API Gateway with Golang — Load Balancing and Rate Limiting](/2025/09/api-gateway-golang-load-balancing-rate-limiting.html)
- [Service Discovery in Go Microservices — Consul and etcd](/2025/09/service-discovery-microservices-golang-consul-etcd.html)
- [Message Queuing with RabbitMQ in Go](/2025/10/how-to-implement-message-queuing-with-rabbitmq-in-go.html)

## 🤖 AI & Advanced

Pushing Go beyond the usual backend — LLMs, embeddings, and integrating modern AI tooling.

- [Build AI/LLM Applications in Go — OpenAI and Ollama Integration](/2025/10/how-to-build-ai-llm-applications-in-go-openai-and-ollama-integration.html)

---

## Where to Next?

- Browse the full **[Go tag archive](/tags/go/)** for chronological listings.
- Have a suggestion? Visit [Contact](/contact/) and let me know which topic to cover next.
- New here? Start at [About BuanaCoding](/about/).
