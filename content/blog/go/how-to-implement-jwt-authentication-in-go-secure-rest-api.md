---
title: "How to Implement JWT Authentication in Go - Secure REST API Tutorial"
description: "Learn how to implement JWT authentication in Go from scratch. Complete guide covering token generation, validation, refresh tokens, middleware, and security best practices for production REST APIs."
date: 2025-09-30T09:00:00+07:00
tags: ["Go", "Authentication", "JWT", "Security", "REST API"]
draft: false
author: "Wiku Karno"
keywords: ["Go JWT authentication", "Golang JWT tutorial", "JWT refresh token Go", "secure REST API Go", "JWT middleware Golang", "golang-jwt implementation", "Go authentication tutorial"]
url: /2025/09/how-to-implement-jwt-authentication-in-go-secure-rest-api.html
faq:
  - question: "What is JWT and why use it in Go applications?"
    answer: "JWT (JSON Web Token) is a compact, self-contained token format for securely transmitting information between parties. In Go applications, JWT is preferred for stateless authentication because it eliminates the need for server-side session storage, scales horizontally across multiple servers, and integrates seamlessly with microservices architectures."
  - question: "Which JWT library should I use in Go?"
    answer: "The golang-jwt/jwt package is the most widely used and recommended library for JWT implementation in Go. It's production-ready, actively maintained, imported by over 12,500 packages, and provides comprehensive functions for token creation, validation, and claims management."
  - question: "How do I secure JWT tokens in Go?"
    answer: "Secure JWT tokens by using strong signing algorithms (RS256 or HS256 with secure secrets), setting short expiration times (15 minutes for access tokens), storing tokens in HttpOnly cookies to prevent XSS attacks, implementing refresh token rotation, and validating all token claims on the server side."
  - question: "What is the difference between access tokens and refresh tokens?"
    answer: "Access tokens are short-lived (typically 15 minutes) and used to authenticate API requests. Refresh tokens are long-lived (days or weeks) and used solely to obtain new access tokens when they expire. This pattern balances security and user experience by minimizing the impact of token compromise while avoiding frequent re-authentication."
  - question: "How do I revoke JWT tokens in Go?"
    answer: "Since JWTs are stateless and cannot be revoked once issued, implement token revocation by maintaining a blocklist in Redis or a database. Store revoked token identifiers with their expiration times, and check against this blocklist in your authentication middleware before processing requests."
  - question: "Should I store JWT tokens in localStorage or cookies?"
    answer: "Store JWT tokens in HttpOnly cookies for production applications. HttpOnly cookies prevent JavaScript access, protecting against XSS attacks. While localStorage is easier to implement, it exposes tokens to client-side scripts and increases security vulnerabilities in web applications."
---

Authentication sits at the foundation of any secure application. Whether you're building a REST API, microservice, or full-stack web application, you need a reliable way to verify user identity and protect sensitive endpoints. JWT (JSON Web Token) has become the de facto standard for stateless authentication in modern applications, and Go provides excellent tools for implementing it correctly.

This guide walks through implementing JWT authentication in Go from the ground up. You'll learn how to generate tokens, validate them, handle refresh tokens, create authentication middleware, and follow security best practices that work in production environments. By the end, you'll have a complete authentication system ready to integrate into your Go applications.

## Understanding JWT Authentication

JWT authentication works by issuing cryptographically signed tokens to authenticated users. Each token contains claims about the user (like their ID, email, or permissions) encoded in JSON format. The server signs these claims using a secret key, creating a tamper-proof token that clients include with subsequent requests.

When a client makes an authenticated request, they send the JWT in the Authorization header. The server validates the signature, checks the expiration time, and extracts the user information from the claims. This stateless approach means the server doesn't need to store session data, making it ideal for distributed systems and microservices.

The process involves three main components: the header (algorithm and token type), the payload (claims about the user), and the signature (cryptographic hash verifying authenticity). The server combines these components with base64 encoding and separates them with dots, creating the familiar JWT format you see in authentication headers.

## Setting Up the Project

Start by creating a new Go project and installing the necessary dependencies. You'll need the golang-jwt library for token operations and a router like Gin for handling HTTP requests.

```bash
mkdir jwt-auth-example
cd jwt-auth-example
go mod init jwt-auth-example

go get github.com/golang-jwt/jwt/v5
go get github.com/gin-gonic/gin
```

Create the basic project structure to organize your code logically. Separate concerns into different packages for handlers, middleware, models, and utilities.

```bash
mkdir -p cmd/server
mkdir -p internal/{handlers,middleware,models,auth}
mkdir -p pkg/utils
```

Set up environment variables for sensitive configuration like JWT secrets. Create a .env file in your project root to store these values securely.

```bash
JWT_SECRET=your-secret-key-change-this-in-production
JWT_EXPIRATION=15m
REFRESH_TOKEN_EXPIRATION=168h
```

## Creating User Models and Database Setup

Define the user model that represents authenticated users in your system. Include fields for storing user credentials and metadata that you'll need for token generation.

```go
// internal/models/user.go
package models

import (
    "time"
)

type User struct {
    ID        uint      `json:"id" gorm:"primaryKey"`
    Email     string    `json:"email" gorm:"unique;not null"`
    Password  string    `json:"-" gorm:"not null"`
    Name      string    `json:"name"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

type LoginRequest struct {
    Email    string `json:"email" binding:"required,email"`
    Password string `json:"password" binding:"required,min=6"`
}

type RegisterRequest struct {
    Email    string `json:"email" binding:"required,email"`
    Password string `json:"password" binding:"required,min=6"`
    Name     string `json:"name" binding:"required"`
}

type TokenResponse struct {
    AccessToken  string `json:"access_token"`
    RefreshToken string `json:"refresh_token"`
    ExpiresIn    int64  `json:"expires_in"`
}
```

For this tutorial, we'll use an in-memory user store to keep things simple. In production, you'd connect to a real database using GORM or sqlx as shown in our [PostgreSQL connection guide](/2025/05/connecting-postgresql-in-go-using-sqlx.html).

```go
// internal/models/store.go
package models

import (
    "errors"
    "sync"
    "golang.org/x/crypto/bcrypt"
)

var (
    ErrUserNotFound      = errors.New("user not found")
    ErrInvalidCredentials = errors.New("invalid credentials")
    ErrUserExists        = errors.New("user already exists")
)

type UserStore struct {
    users map[string]*User
    mu    sync.RWMutex
    nextID uint
}

func NewUserStore() *UserStore {
    return &UserStore{
        users: make(map[string]*User),
        nextID: 1,
    }
}

func (s *UserStore) CreateUser(email, password, name string) (*User, error) {
    s.mu.Lock()
    defer s.mu.Unlock()

    if _, exists := s.users[email]; exists {
        return nil, ErrUserExists
    }

    hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
    if err != nil {
        return nil, err
    }

    user := &User{
        ID:       s.nextID,
        Email:    email,
        Password: string(hashedPassword),
        Name:     name,
    }

    s.users[email] = user
    s.nextID++

    return user, nil
}

func (s *UserStore) GetUserByEmail(email string) (*User, error) {
    s.mu.RLock()
    defer s.mu.RUnlock()

    user, exists := s.users[email]
    if !exists {
        return nil, ErrUserNotFound
    }

    return user, nil
}

func (s *UserStore) ValidateCredentials(email, password string) (*User, error) {
    user, err := s.GetUserByEmail(email)
    if err != nil {
        return nil, ErrInvalidCredentials
    }

    err = bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password))
    if err != nil {
        return nil, ErrInvalidCredentials
    }

    return user, nil
}
```

## Implementing JWT Token Generation

Create a service that handles all JWT operations including token generation, validation, and claims extraction. This centralizes your authentication logic and makes it easier to maintain.

```go
// internal/auth/jwt.go
package auth

import (
    "errors"
    "time"
    "jwt-auth-example/internal/models"

    "github.com/golang-jwt/jwt/v5"
)

var (
    ErrInvalidToken = errors.New("invalid token")
    ErrExpiredToken = errors.New("token has expired")
)

type JWTClaims struct {
    UserID uint   `json:"user_id"`
    Email  string `json:"email"`
    jwt.RegisteredClaims
}

type JWTService struct {
    secretKey     []byte
    accessExpiry  time.Duration
    refreshExpiry time.Duration
}

func NewJWTService(secret string, accessExpiry, refreshExpiry time.Duration) *JWTService {
    return &JWTService{
        secretKey:     []byte(secret),
        accessExpiry:  accessExpiry,
        refreshExpiry: refreshExpiry,
    }
}

func (s *JWTService) GenerateAccessToken(user *models.User) (string, error) {
    claims := JWTClaims{
        UserID: user.ID,
        Email:  user.Email,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(s.accessExpiry)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
            NotBefore: jwt.NewNumericDate(time.Now()),
            Issuer:    "jwt-auth-example",
            Subject:   string(rune(user.ID)),
        },
    }

    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString(s.secretKey)
}

func (s *JWTService) GenerateRefreshToken(user *models.User) (string, error) {
    claims := JWTClaims{
        UserID: user.ID,
        Email:  user.Email,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(s.refreshExpiry)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
            NotBefore: jwt.NewNumericDate(time.Now()),
            Issuer:    "jwt-auth-example",
        },
    }

    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString(s.secretKey)
}

func (s *JWTService) ValidateToken(tokenString string) (*JWTClaims, error) {
    token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
        if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, ErrInvalidToken
        }
        return s.secretKey, nil
    })

    if err != nil {
        if errors.Is(err, jwt.ErrTokenExpired) {
            return nil, ErrExpiredToken
        }
        return nil, ErrInvalidToken
    }

    claims, ok := token.Claims.(*JWTClaims)
    if !ok || !token.Valid {
        return nil, ErrInvalidToken
    }

    return claims, nil
}

func (s *JWTService) GenerateTokenPair(user *models.User) (*models.TokenResponse, error) {
    accessToken, err := s.GenerateAccessToken(user)
    if err != nil {
        return nil, err
    }

    refreshToken, err := s.GenerateRefreshToken(user)
    if err != nil {
        return nil, err
    }

    return &models.TokenResponse{
        AccessToken:  accessToken,
        RefreshToken: refreshToken,
        ExpiresIn:    int64(s.accessExpiry.Seconds()),
    }, nil
}
```

The token generation process creates a JWT with specific claims about the user. The access token expires quickly (typically 15 minutes) to limit the window of opportunity if compromised. The refresh token lasts much longer but serves only to obtain new access tokens.

## Building Authentication Handlers

Create HTTP handlers for registration, login, and token refresh endpoints. These handlers validate input, interact with the user store, and return appropriate responses.

```go
// internal/handlers/auth.go
package handlers

import (
    "net/http"
    "jwt-auth-example/internal/auth"
    "jwt-auth-example/internal/models"

    "github.com/gin-gonic/gin"
)

type AuthHandler struct {
    userStore  *models.UserStore
    jwtService *auth.JWTService
}

func NewAuthHandler(userStore *models.UserStore, jwtService *auth.JWTService) *AuthHandler {
    return &AuthHandler{
        userStore:  userStore,
        jwtService: jwtService,
    }
}

func (h *AuthHandler) Register(c *gin.Context) {
    var req models.RegisterRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    user, err := h.userStore.CreateUser(req.Email, req.Password, req.Name)
    if err != nil {
        if err == models.ErrUserExists {
            c.JSON(http.StatusConflict, gin.H{"error": "user already exists"})
            return
        }
        c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create user"})
        return
    }

    tokens, err := h.jwtService.GenerateTokenPair(user)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to generate tokens"})
        return
    }

    c.JSON(http.StatusCreated, gin.H{
        "user":   user,
        "tokens": tokens,
    })
}

func (h *AuthHandler) Login(c *gin.Context) {
    var req models.LoginRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    user, err := h.userStore.ValidateCredentials(req.Email, req.Password)
    if err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
        return
    }

    tokens, err := h.jwtService.GenerateTokenPair(user)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to generate tokens"})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "user":   user,
        "tokens": tokens,
    })
}

func (h *AuthHandler) RefreshToken(c *gin.Context) {
    var req struct {
        RefreshToken string `json:"refresh_token" binding:"required"`
    }

    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    claims, err := h.jwtService.ValidateToken(req.RefreshToken)
    if err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid refresh token"})
        return
    }

    user, err := h.userStore.GetUserByEmail(claims.Email)
    if err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "user not found"})
        return
    }

    tokens, err := h.jwtService.GenerateTokenPair(user)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to generate tokens"})
        return
    }

    c.JSON(http.StatusOK, tokens)
}
```

## Creating Authentication Middleware

Middleware intercepts requests to protected endpoints and validates the JWT before allowing the request to proceed. This keeps authentication logic separate from your business logic.

```go
// internal/middleware/auth.go
package middleware

import (
    "net/http"
    "strings"
    "jwt-auth-example/internal/auth"

    "github.com/gin-gonic/gin"
)

func AuthMiddleware(jwtService *auth.JWTService) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "authorization header required"})
            c.Abort()
            return
        }

        parts := strings.SplitN(authHeader, " ", 2)
        if len(parts) != 2 || parts[0] != "Bearer" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization header format"})
            c.Abort()
            return
        }

        claims, err := jwtService.ValidateToken(parts[1])
        if err != nil {
            c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
            c.Abort()
            return
        }

        c.Set("user_id", claims.UserID)
        c.Set("email", claims.Email)
        c.Next()
    }
}
```

The middleware extracts the token from the Authorization header, validates it using the JWT service, and stores user information in the context for downstream handlers to access. Similar middleware patterns appear in our [Gin framework tutorial](/2025/09/building-rest-api-gin-framework-golang-production-ready.html).

## Setting Up the Server and Routes

Bring everything together by creating the main server that wires up routes, handlers, and middleware.

```go
// cmd/server/main.go
package main

import (
    "log"
    "time"
    "jwt-auth-example/internal/auth"
    "jwt-auth-example/internal/handlers"
    "jwt-auth-example/internal/middleware"
    "jwt-auth-example/internal/models"

    "github.com/gin-gonic/gin"
)

func main() {
    router := gin.Default()

    userStore := models.NewUserStore()
    jwtService := auth.NewJWTService(
        "your-secret-key-change-this-in-production",
        15*time.Minute,
        7*24*time.Hour,
    )

    authHandler := handlers.NewAuthHandler(userStore, jwtService)

    router.POST("/api/auth/register", authHandler.Register)
    router.POST("/api/auth/login", authHandler.Login)
    router.POST("/api/auth/refresh", authHandler.RefreshToken)

    protected := router.Group("/api")
    protected.Use(middleware.AuthMiddleware(jwtService))
    {
        protected.GET("/profile", func(c *gin.Context) {
            userID := c.GetUint("user_id")
            email := c.GetString("email")

            c.JSON(200, gin.H{
                "user_id": userID,
                "email":   email,
                "message": "This is a protected endpoint",
            })
        })
    }

    log.Println("Server starting on :8080")
    if err := router.Run(":8080"); err != nil {
        log.Fatal("Failed to start server:", err)
    }
}
```

## Testing the Authentication Flow

Test your authentication system by making requests to each endpoint. Start with registration to create a user account.

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securepass123",
    "name": "John Doe"
  }'
```

The server responds with user information and a token pair. Save the access token for subsequent requests.

```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe"
  },
  "tokens": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 900
  }
}
```

Test the protected endpoint using the access token in the Authorization header.

```bash
curl -X GET http://localhost:8080/api/profile \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

When the access token expires, use the refresh token to obtain a new token pair without requiring the user to log in again.

```bash
curl -X POST http://localhost:8080/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "YOUR_REFRESH_TOKEN"
  }'
```

## Security Best Practices

Production authentication systems require additional security measures beyond basic token generation and validation. Always use environment variables for JWT secrets and never commit them to version control.

Choose signing algorithms carefully. HMAC-SHA256 (HS256) works well for single-server applications, but consider RSA (RS256) for distributed systems where multiple services need to verify tokens without sharing secrets.

Set appropriate token expiration times based on your security requirements. Access tokens should expire quickly (15 minutes is standard) while refresh tokens can last days or weeks. Balance security against user experience to avoid excessive re-authentication.

Store tokens in HttpOnly cookies when building web applications. This prevents JavaScript access and protects against XSS attacks. For mobile apps or single-page applications, implement secure storage mechanisms appropriate to the platform.

Implement token revocation for logout and security events. While JWTs are stateless, you can maintain a blocklist of revoked tokens in Redis with expiration times matching the token lifetime. Check this blocklist in your authentication middleware.

Validate all token claims on the server side. Check the issuer, expiration time, not-before time, and any custom claims. Never trust client-provided data without verification.

Use HTTPS exclusively in production. JWT tokens transmitted over unencrypted connections can be intercepted and stolen. Configure your server to reject HTTP requests and redirect to HTTPS.

## Handling Common Challenges

Token refresh timing requires careful consideration. Implement automatic token refresh in your client applications before tokens expire to avoid interrupting user sessions. Monitor token expiration times and refresh proactively.

Concurrent requests during token refresh can cause race conditions. Implement request queuing in your client to ensure only one refresh request proceeds at a time. Subsequent requests should wait for the new token before retrying.

Multiple device support requires tracking refresh tokens per device. Store refresh tokens with device identifiers to allow users to log out individual devices without affecting others. This provides better security and user control.

Database queries for user information on every request can impact performance. Consider caching user data in memory with appropriate invalidation strategies, or include necessary user information directly in JWT claims while keeping tokens reasonably sized.

## Integrating with Production Systems

Real applications require database persistence for user accounts and token metadata. Replace the in-memory user store with a database connection as demonstrated in our guide on [connecting to PostgreSQL](/2025/05/connecting-postgresql-in-go-using-sqlx.html).

Add rate limiting to authentication endpoints to prevent brute force attacks. Implement progressive delays after failed login attempts and consider account lockouts after repeated failures.

Log authentication events for security monitoring and debugging. Track successful logins, failed attempts, token refreshes, and unusual patterns that might indicate security issues.

Implement role-based access control by including user roles or permissions in JWT claims. Validate these permissions in your middleware or handlers to restrict access to sensitive functionality.

Consider adding email verification and password reset flows to create a complete authentication system. These features enhance security and provide better user experience.

## Conclusion

JWT authentication provides a robust, scalable solution for securing Go applications. The stateless nature of JWTs eliminates server-side session storage while maintaining security through cryptographic signatures. By following the implementation patterns and security practices covered in this guide, you can build production-ready authentication systems that protect user data and scale with your application.

The token-based approach integrates seamlessly with [microservices architectures](/2025/09/microservices-golang-architecture-implementation-guide.html) and works across different clients including web applications, mobile apps, and API consumers. Proper implementation of token generation, validation, refresh mechanisms, and security measures creates authentication systems that balance security requirements with user experience.

Remember that authentication forms just one part of application security. Combine JWT authentication with other security measures like input validation, [error handling](/2025/04/error-handling-in-go-managing-errors.html), secure database queries, and regular security audits to create truly secure applications. Stay updated on security best practices and adjust your implementation as threats and technologies evolve.
