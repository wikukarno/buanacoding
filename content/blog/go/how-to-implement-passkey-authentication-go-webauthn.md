---
title: "How to Implement Passkey Authentication with Go - WebAuthn Tutorial"
description: "Learn how to implement passwordless passkey authentication in Go using WebAuthn. Complete guide covering registration, authentication, credential storage, and security best practices for modern applications."
date: 2025-11-09T12:18:32+07:00
tags: ["Go", "Authentication", "Security", "WebAuthn", "Passkeys"]
draft: false
author: "Wiku Karno"
keywords: ["Go passkey authentication", "WebAuthn Go tutorial", "passwordless authentication Go", "Go WebAuthn implementation", "passkey security Go", "FIDO2 Go", "biometric authentication Go", "Go authentication tutorial"]
url: /2025/11/how-to-implement-passkey-authentication-go-webauthn.html
faq:
  - question: "What are passkeys and why use them in Go applications?"
    answer: "Passkeys are FIDO2 credentials that enable passwordless authentication using biometrics, PINs, or security keys. In Go applications, passkeys eliminate password-related vulnerabilities like phishing and credential stuffing, work smoothly across all your devices, and meet modern security compliance requirements while reducing authentication-related support costs."
  - question: "How do passkeys differ from traditional JWT or OAuth2 authentication?"
    answer: "Unlike JWT or OAuth2 which rely on shared secrets, passkeys use public-key cryptography where private keys never leave the user's device. This makes passkeys immune to server breaches and phishing attacks. While JWT and OAuth2 are excellent for API authentication, passkeys focus on user authentication with better security and smoother user experience."
  - question: "What Go libraries are needed for WebAuthn implementation?"
    answer: "The primary library is github.com/go-webauthn/webauthn which provides complete WebAuthn protocol implementation. You'll also need a database driver (like pgx for PostgreSQL), session management library, and a web framework like Gin or Echo. The go-webauthn library handles all cryptographic operations and protocol compliance."
  - question: "Can passkeys work alongside existing password authentication?"
    answer: "Yes, passkeys can be implemented alongside traditional authentication methods. Many production applications offer passkeys as an optional upgrade while maintaining password fallback. This hybrid approach allows gradual user migration and provides flexibility for users who aren't ready for passwordless authentication."
  - question: "How do you handle credential storage for passkeys in Go?"
    answer: "Passkey credentials are stored in your database with user association. Store the credential ID, public key, sign count, and authenticator metadata. Never store private keys as they remain on the user's device. Use proper database indexing on credential IDs for fast lookup during authentication, and implement soft deletion for credential revocation."
  - question: "What are the production considerations for passkey authentication?"
    answer: "Production passkey implementations require HTTPS, proper CORS configuration, reliable session management, and multi-device credential syncing support. Implement solid error handling for various authenticator types, provide clear user guidance for credential setup, maintain audit logs for security compliance, and plan for credential recovery flows when users lose access to their authenticators."
---

Passwords are broken. I spent three months building a user authentication system with email verification, password reset flows, and security best practices. Within the first month, we dealt with credential stuffing attacks, phishing complaints, and a flood of "forgot password" support tickets. Then I implemented passkey authentication and everything changed.

Passkeys are changing how we think about web authentication. Built on the WebAuthn standard and FIDO2 protocol, they eliminate passwords entirely by using public-key cryptography. Users authenticate with biometrics, device PINs, or security keys instead of remembering passwords. Google, Apple, Microsoft, and major platforms have adopted passkeys, and more users are switching every day.

This tutorial walks you through implementing passkey authentication in Go from scratch. You'll learn how to handle credential registration, authenticate users with WebAuthn, manage credentials in a database, implement proper security practices, and integrate passkeys into production applications. By the end, you'll have a working passwordless authentication system ready for real-world deployment.

## Understanding Passkey Authentication and WebAuthn

Passkeys solve fundamental problems that plague password-based authentication. Traditional passwords are vulnerable to phishing, credential stuffing, and brute force attacks. Users reuse weak passwords across sites, and database breaches expose millions of credentials annually. Even with proper hashing, passwords remain the weakest link in application security.

WebAuthn flips this model on its head. When a user registers a passkey, their device generates a unique cryptographic key pair. The private key stays on the device and never leaves it. Your server only receives and stores the public key. During authentication, the device signs a challenge with the private key, and your server verifies the signature using the stored public key. This makes phishing impossible because the private key cannot be stolen or transmitted.

Passkeys sync across devices through platform authenticators built into modern operating systems. Apple's iCloud Keychain, Google Password Manager, and Microsoft's Windows Hello sync passkeys across a user's devices automatically. Users can also use cross-platform authenticators like Yubikeys for portable authentication. The experience is faster than typing passwords and much more secure.

## Setting Up the Project

Create a new Go project with the necessary dependencies. We'll use the go-webauthn library which gives us a complete WebAuthn implementation, along with Gin for the web framework and PostgreSQL for credential storage.

```bash
mkdir passkey-auth-go
cd passkey-auth-go
go mod init passkey-auth-go

go get github.com/go-webauthn/webauthn/webauthn
go get github.com/go-webauthn/webauthn/protocol
go get github.com/gin-gonic/gin
go get github.com/jackc/pgx/v5
go get github.com/jackc/pgx/v5/stdlib
go get github.com/jmoiron/sqlx
go get github.com/google/uuid
```

Create the project structure to organize our code cleanly. We'll separate concerns into models, handlers, and configuration to maintain clarity as the application grows.

```bash
mkdir -p internal/{models,handlers,config,database}
mkdir -p cmd/server
```

The project structure follows Go best practices with internal packages for implementation details and a cmd directory for the application entry point. This organization makes the code maintainable and testable.

## Creating Database Schema and Models

Passkey credentials need persistent storage with user associations. Here's the database schema that stores user information and their associated WebAuthn credentials.

```sql
-- migrations/001_create_tables.sql
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS credentials (
    id BYTEA PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    public_key BYTEA NOT NULL,
    attestation_type VARCHAR(50) NOT NULL,
    aaguid BYTEA NOT NULL,
    sign_count INTEGER NOT NULL DEFAULT 0,
    clone_warning BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_credentials_user_id ON credentials(user_id);
CREATE INDEX idx_credentials_last_used ON credentials(last_used_at);
```

The schema stores the WebAuthn data you need. The credential ID serves as the primary key for fast lookups during authentication. The public key enables signature verification. Sign count tracking detects cloned authenticators which indicate security breaches. The clone warning flag triggers when sign counts decrease, suggesting an authenticator was duplicated.

Here are the Go models that represent this data structure.

```go
// internal/models/user.go
package models

import (
    "time"
    "github.com/google/uuid"
    "github.com/go-webauthn/webauthn/webauthn"
)

type User struct {
    ID          uuid.UUID `db:"id" json:"id"`
    Username    string    `db:"username" json:"username"`
    DisplayName string    `db:"display_name" json:"display_name"`
    CreatedAt   time.Time `db:"created_at" json:"created_at"`
    UpdatedAt   time.Time `db:"updated_at" json:"updated_at"`

    Credentials []Credential `db:"-" json:"-"`
}

// WebAuthnID returns the user's ID as bytes
func (u *User) WebAuthnID() []byte {
    return []byte(u.ID.String())
}

// WebAuthnName returns the username for display
func (u *User) WebAuthnName() string {
    return u.Username
}

// WebAuthnDisplayName returns the display name
func (u *User) WebAuthnDisplayName() string {
    return u.DisplayName
}

// WebAuthnIcon returns the user icon URL (optional)
func (u *User) WebAuthnIcon() string {
    return ""
}

// WebAuthnCredentials returns the list of credentials
func (u *User) WebAuthnCredentials() []webauthn.Credential {
    credentials := make([]webauthn.Credential, len(u.Credentials))
    for i, cred := range u.Credentials {
        credentials[i] = webauthn.Credential{
            ID:              cred.ID,
            PublicKey:       cred.PublicKey,
            AttestationType: cred.AttestationType,
            Authenticator: webauthn.Authenticator{
                AAGUID:       cred.AAGUID,
                SignCount:    uint32(cred.SignCount),
                CloneWarning: cred.CloneWarning,
            },
        }
    }
    return credentials
}

type Credential struct {
    ID              []byte    `db:"id" json:"id"`
    UserID          uuid.UUID `db:"user_id" json:"user_id"`
    PublicKey       []byte    `db:"public_key" json:"-"`
    AttestationType string    `db:"attestation_type" json:"attestation_type"`
    AAGUID          []byte    `db:"aaguid" json:"aaguid"`
    SignCount       int       `db:"sign_count" json:"sign_count"`
    CloneWarning    bool      `db:"clone_warning" json:"clone_warning"`
    CreatedAt       time.Time `db:"created_at" json:"created_at"`
    LastUsedAt      *time.Time `db:"last_used_at" json:"last_used_at,omitempty"`
}
```

The User model implements the webauthn.User interface required by the go-webauthn library. These methods provide the library with necessary user information during registration and authentication ceremonies. The WebAuthnCredentials method converts our database credentials into the format expected by the library, making the integration seamless.

## Configuring WebAuthn

WebAuthn requires specific configuration that defines your application's identity and security requirements. This configuration determines how the browser interacts with authenticators and what types of credentials are accepted.

```go
// internal/config/webauthn.go
package config

import (
    "github.com/go-webauthn/webauthn/webauthn"
)

type WebAuthnConfig struct {
    RPDisplayName string
    RPID          string
    RPOrigins     []string
}

func NewWebAuthn(cfg WebAuthnConfig) (*webauthn.WebAuthn, error) {
    wconfig := &webauthn.Config{
        RPDisplayName: cfg.RPDisplayName,
        RPID:          cfg.RPID,
        RPOrigins:     cfg.RPOrigins,

        AuthenticatorSelection: webauthn.AuthenticatorSelection{
            RequireResidentKey: protocol.ResidentKeyNotRequired(),
            ResidentKey:        protocol.ResidentKeyRequirementPreferred,
            UserVerification:   protocol.VerificationPreferred,
        },

        AttestationPreference: protocol.PreferNoAttestation,

        Timeouts: webauthn.TimeoutsConfig{
            Login: webauthn.TimeoutConfig{
                Enforce:    true,
                Timeout:    60000,
            },
            Registration: webauthn.TimeoutConfig{
                Enforce:    true,
                Timeout:    60000,
            },
        },
    }

    return webauthn.New(wconfig)
}
```

The Relying Party ID (RPID) must match your domain name for security. Set this to your actual domain in production like "example.com". The RPOrigins list defines which URLs can initiate WebAuthn ceremonies. The configuration prefers resident keys which enable discoverable credentials that work without usernames, though it doesn't require them for compatibility with older authenticators.

User verification preference balances security with user experience. Setting it to "preferred" requests biometric or PIN verification when available but doesn't fail if the authenticator doesn't support it. For high-security applications, consider requiring user verification. The 60-second timeout gives users enough time to interact with their authenticator without leaving the ceremony open indefinitely.

## Implementing Database Operations

Credential management requires efficient database operations for storing and retrieving user credentials. Let's implement the database layer with proper error handling and transaction support.

```go
// internal/database/store.go
package database

import (
    "context"
    "database/sql"
    "errors"
    "passkey-auth-go/internal/models"

    "github.com/google/uuid"
    "github.com/jmoiron/sqlx"
)

type Store struct {
    db *sqlx.DB
}

func NewStore(db *sqlx.DB) *Store {
    return &Store{db: db}
}

func (s *Store) CreateUser(ctx context.Context, username, displayName string) (*models.User, error) {
    user := &models.User{
        ID:          uuid.New(),
        Username:    username,
        DisplayName: displayName,
    }

    query := `
        INSERT INTO users (id, username, display_name)
        VALUES ($1, $2, $3)
        RETURNING created_at, updated_at
    `

    err := s.db.QueryRowContext(ctx, query, user.ID, user.Username, user.DisplayName).
        Scan(&user.CreatedAt, &user.UpdatedAt)
    if err != nil {
        return nil, err
    }

    return user, nil
}

func (s *Store) GetUserByUsername(ctx context.Context, username string) (*models.User, error) {
    var user models.User
    query := `SELECT id, username, display_name, created_at, updated_at FROM users WHERE username = $1`

    err := s.db.GetContext(ctx, &user, query, username)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, nil
        }
        return nil, err
    }

    return &user, nil
}

func (s *Store) GetUserByID(ctx context.Context, userID uuid.UUID) (*models.User, error) {
    var user models.User
    query := `SELECT id, username, display_name, created_at, updated_at FROM users WHERE id = $1`

    err := s.db.GetContext(ctx, &user, query, userID)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, nil
        }
        return nil, err
    }

    return &user, nil
}

func (s *Store) GetUserCredentials(ctx context.Context, userID uuid.UUID) ([]models.Credential, error) {
    var credentials []models.Credential
    query := `
        SELECT id, user_id, public_key, attestation_type, aaguid, sign_count, clone_warning, created_at, last_used_at
        FROM credentials
        WHERE user_id = $1
        ORDER BY created_at DESC
    `

    err := s.db.SelectContext(ctx, &credentials, query, userID)
    if err != nil {
        return nil, err
    }

    return credentials, nil
}

func (s *Store) AddCredential(ctx context.Context, cred *models.Credential) error {
    query := `
        INSERT INTO credentials (id, user_id, public_key, attestation_type, aaguid, sign_count, clone_warning)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
    `

    _, err := s.db.ExecContext(ctx, query,
        cred.ID,
        cred.UserID,
        cred.PublicKey,
        cred.AttestationType,
        cred.AAGUID,
        cred.SignCount,
        cred.CloneWarning,
    )

    return err
}

func (s *Store) UpdateCredential(ctx context.Context, credID []byte, signCount int, cloneWarning bool) error {
    query := `
        UPDATE credentials
        SET sign_count = $2, clone_warning = $3, last_used_at = CURRENT_TIMESTAMP
        WHERE id = $1
    `

    _, err := s.db.ExecContext(ctx, query, credID, signCount, cloneWarning)
    return err
}

func (s *Store) GetCredentialByID(ctx context.Context, credID []byte) (*models.Credential, error) {
    var cred models.Credential
    query := `
        SELECT id, user_id, public_key, attestation_type, aaguid, sign_count, clone_warning, created_at, last_used_at
        FROM credentials
        WHERE id = $1
    `

    err := s.db.GetContext(ctx, &cred, query, credID)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, nil
        }
        return nil, err
    }

    return &cred, nil
}
```

The database layer provides clean abstractions for credential management. The CreateUser function generates a new UUID and returns the complete user record with database-generated timestamps. GetUserCredentials loads all credentials for a user in a single query, ordered by creation date to show newest credentials first.

UpdateCredential handles the important sign count tracking that detects cloned authenticators. Every time a credential is used, the sign count increments. If an authenticator is cloned, the counts diverge and one will be lower than the stored value. This triggers the clone warning flag, alerting you to potential security issues that require credential revocation.

## Building Registration Flow

Registration creates new passkey credentials for users. The flow involves two round trips between client and server. First, the server generates a challenge and credential options. Then the client creates the credential and returns it for verification and storage.

```go
// internal/handlers/registration.go
package handlers

import (
    "context"
    "encoding/json"
    "net/http"
    "passkey-auth-go/internal/database"
    "passkey-auth-go/internal/models"

    "github.com/gin-gonic/gin"
    "github.com/go-webauthn/webauthn/protocol"
    "github.com/go-webauthn/webauthn/webauthn"
    "github.com/google/uuid"
)

type RegistrationHandler struct {
    webAuthn *webauthn.WebAuthn
    store    *database.Store
    sessions map[string]*webauthn.SessionData
}

func NewRegistrationHandler(wa *webauthn.WebAuthn, store *database.Store) *RegistrationHandler {
    return &RegistrationHandler{
        webAuthn: wa,
        store:    store,
        sessions: make(map[string]*webauthn.SessionData),
    }
}

func (h *RegistrationHandler) BeginRegistration(c *gin.Context) {
    var req struct {
        Username    string `json:"username" binding:"required"`
        DisplayName string `json:"display_name" binding:"required"`
    }

    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
        return
    }

    existingUser, err := h.store.GetUserByUsername(c.Request.Context(), req.Username)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
        return
    }

    if existingUser != nil {
        c.JSON(http.StatusConflict, gin.H{"error": "Username already exists"})
        return
    }

    user, err := h.store.CreateUser(c.Request.Context(), req.Username, req.DisplayName)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
        return
    }

    options, sessionData, err := h.webAuthn.BeginRegistration(user)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to begin registration"})
        return
    }

    sessionID := uuid.New().String()
    h.sessions[sessionID] = sessionData

    c.SetCookie("registration_session", sessionID, 300, "/", "", true, true)
    c.JSON(http.StatusOK, options)
}

func (h *RegistrationHandler) FinishRegistration(c *gin.Context) {
    sessionID, err := c.Cookie("registration_session")
    if err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "No registration session"})
        return
    }

    sessionData, exists := h.sessions[sessionID]
    if !exists {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid session"})
        return
    }
    defer delete(h.sessions, sessionID)

    userID, err := uuid.Parse(string(sessionData.UserID))
    if err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
        return
    }

    user, err := h.store.GetUserByID(c.Request.Context(), userID)
    if err != nil || user == nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
        return
    }

    credential, err := h.webAuthn.FinishRegistration(user, *sessionData, c.Request)
    if err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to verify credential"})
        return
    }

    dbCredential := &models.Credential{
        ID:              credential.ID,
        UserID:          user.ID,
        PublicKey:       credential.PublicKey,
        AttestationType: credential.AttestationType,
        AAGUID:          credential.Authenticator.AAGUID,
        SignCount:       int(credential.Authenticator.SignCount),
        CloneWarning:    false,
    }

    if err := h.store.AddCredential(c.Request.Context(), dbCredential); err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to store credential"})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "success": true,
        "user_id": user.ID,
    })
}
```

The registration flow starts by checking if the username is available. Creating the user before generating credential options gives us a valid user ID to embed in the credential. The WebAuthn library's BeginRegistration method generates a cryptographically random challenge and builds the credential creation options according to the WebAuthn specification.

Session data must be preserved between the begin and finish requests because it contains the challenge that validates the client's response. In production, store session data in Redis or a session store rather than in-memory maps. The finish handler verifies the attestation response, checks the signature, and validates the challenge matches what we sent. Only after all verification passes do we store the credential in the database.

## Building Authentication Flow

Authentication verifies users by challenging them to prove possession of their private key. The flow mirrors registration with begin and finish endpoints, but instead of creating credentials, we verify signatures against stored public keys.

```go
// internal/handlers/authentication.go
package handlers

import (
    "net/http"
    "passkey-auth-go/internal/database"

    "github.com/gin-gonic/gin"
    "github.com/go-webauthn/webauthn/webauthn"
    "github.com/google/uuid"
)

type AuthenticationHandler struct {
    webAuthn *webauthn.WebAuthn
    store    *database.Store
    sessions map[string]*webauthn.SessionData
}

func NewAuthenticationHandler(wa *webauthn.WebAuthn, store *database.Store) *AuthenticationHandler {
    return &AuthenticationHandler{
        webAuthn: wa,
        store:    store,
        sessions: make(map[string]*webauthn.SessionData),
    }
}

func (h *AuthenticationHandler) BeginAuthentication(c *gin.Context) {
    var req struct {
        Username string `json:"username" binding:"required"`
    }

    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
        return
    }

    user, err := h.store.GetUserByUsername(c.Request.Context(), req.Username)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
        return
    }

    if user == nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
        return
    }

    credentials, err := h.store.GetUserCredentials(c.Request.Context(), user.ID)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load credentials"})
        return
    }

    user.Credentials = credentials

    options, sessionData, err := h.webAuthn.BeginLogin(user)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to begin authentication"})
        return
    }

    sessionID := uuid.New().String()
    h.sessions[sessionID] = sessionData

    c.SetCookie("auth_session", sessionID, 300, "/", "", true, true)
    c.JSON(http.StatusOK, options)
}

func (h *AuthenticationHandler) FinishAuthentication(c *gin.Context) {
    sessionID, err := c.Cookie("auth_session")
    if err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "No authentication session"})
        return
    }

    sessionData, exists := h.sessions[sessionID]
    if !exists {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid session"})
        return
    }
    defer delete(h.sessions, sessionID)

    userID, err := uuid.Parse(string(sessionData.UserID))
    if err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
        return
    }

    user, err := h.store.GetUserByID(c.Request.Context(), userID)
    if err != nil || user == nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
        return
    }

    credentials, err := h.store.GetUserCredentials(c.Request.Context(), user.ID)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load credentials"})
        return
    }

    user.Credentials = credentials

    credential, err := h.webAuthn.FinishLogin(user, *sessionData, c.Request)
    if err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "Authentication failed"})
        return
    }

    if credential.Authenticator.CloneWarning {
        c.JSON(http.StatusUnauthorized, gin.H{
            "error": "Credential may be cloned",
            "action": "contact_support",
        })
        return
    }

    err = h.store.UpdateCredential(
        c.Request.Context(),
        credential.ID,
        int(credential.Authenticator.SignCount),
        credential.Authenticator.CloneWarning,
    )
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update credential"})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "success": true,
        "user_id": user.ID,
        "username": user.Username,
    })
}
```

BeginAuthentication loads the user's credentials from the database before generating the challenge. The WebAuthn library needs to know which credentials are valid for this user so it can include their IDs in the authentication options. The browser uses these IDs to prompt the user with the appropriate authenticator.

FinishAuthentication performs important security checks. The signature verification confirms only the legitimate private key holder could have created the response. The clone warning check protects against authenticator duplication attacks. If detected, reject the authentication and alert your security team. Updating the sign count after successful authentication maintains the security chain for future logins.

## Creating the Server and Routes

Now let's wire everything together into a working web server with proper routes and middleware. The server needs HTTPS in production for WebAuthn to function because browsers require secure contexts for credential operations.

```go
// cmd/server/main.go
package main

import (
    "log"
    "passkey-auth-go/internal/config"
    "passkey-auth-go/internal/database"
    "passkey-auth-go/internal/handlers"

    "github.com/gin-gonic/gin"
    "github.com/jmoiron/sqlx"
    _ "github.com/jackc/pgx/v5/stdlib"
)

func main() {
    db, err := sqlx.Connect("pgx", "postgres://user:pass@localhost/passkeydb?sslmode=disable")
    if err != nil {
        log.Fatal("Failed to connect to database:", err)
    }
    defer db.Close()

    store := database.NewStore(db)

    webAuthnConfig := config.WebAuthnConfig{
        RPDisplayName: "Passkey Auth Demo",
        RPID:          "localhost",
        RPOrigins:     []string{"https://localhost:8080"},
    }

    wa, err := config.NewWebAuthn(webAuthnConfig)
    if err != nil {
        log.Fatal("Failed to create WebAuthn:", err)
    }

    registrationHandler := handlers.NewRegistrationHandler(wa, store)
    authenticationHandler := handlers.NewAuthenticationHandler(wa, store)

    r := gin.Default()

    r.Use(func(c *gin.Context) {
        c.Writer.Header().Set("Access-Control-Allow-Origin", "https://localhost:8080")
        c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
        c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
        c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

        if c.Request.Method == "OPTIONS" {
            c.AbortWithStatus(204)
            return
        }

        c.Next()
    })

    api := r.Group("/api")
    {
        api.POST("/register/begin", registrationHandler.BeginRegistration)
        api.POST("/register/finish", registrationHandler.FinishRegistration)
        api.POST("/login/begin", authenticationHandler.BeginAuthentication)
        api.POST("/login/finish", authenticationHandler.FinishAuthentication)
    }

    if err := r.RunTLS(":8080", "cert.pem", "key.pem"); err != nil {
        log.Fatal("Failed to start server:", err)
    }
}
```

The server configuration sets up CORS headers to allow credentials and appropriate origins. WebAuthn requires the origin to match exactly between the JavaScript making requests and the server configuration. In development, you can use self-signed certificates generated with openssl. Production deployments should use proper certificates from Let's Encrypt or your certificate authority.

The route structure groups registration and authentication endpoints logically. The begin endpoints are safe to call without authentication, but in production you might want rate limiting to prevent abuse. Consider implementing session management middleware similar to our [JWT authentication guide](/2025/09/how-to-implement-jwt-authentication-in-go-secure-rest-api.html) to maintain user sessions after successful passkey authentication.

## Building the Frontend Client

The client-side JavaScript handles the WebAuthn ceremony interaction with the browser. The browser's WebAuthn API manages communication with authenticators and returns credentials to your code.

```html
<!-- static/index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Passkey Authentication Demo</title>
</head>
<body>
    <h1>Passkey Authentication</h1>

    <div id="registration">
        <h2>Register</h2>
        <input type="text" id="reg-username" placeholder="Username">
        <input type="text" id="reg-displayname" placeholder="Display Name">
        <button onclick="register()">Register Passkey</button>
    </div>

    <div id="authentication">
        <h2>Login</h2>
        <input type="text" id="auth-username" placeholder="Username">
        <button onclick="authenticate()">Login with Passkey</button>
    </div>

    <div id="result"></div>

    <script src="passkey.js"></script>
</body>
</html>
```

```javascript
// static/passkey.js
async function register() {
    const username = document.getElementById('reg-username').value;
    const displayName = document.getElementById('reg-displayname').value;

    try {
        const beginResp = await fetch('https://localhost:8080/api/register/begin', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({ username, display_name: displayName })
        });

        const options = await beginResp.json();

        options.publicKey.challenge = base64urlDecode(options.publicKey.challenge);
        options.publicKey.user.id = base64urlDecode(options.publicKey.user.id);

        const credential = await navigator.credentials.create(options);

        const attestationResponse = {
            id: credential.id,
            rawId: base64urlEncode(credential.rawId),
            type: credential.type,
            response: {
                attestationObject: base64urlEncode(credential.response.attestationObject),
                clientDataJSON: base64urlEncode(credential.response.clientDataJSON),
            },
        };

        const finishResp = await fetch('https://localhost:8080/api/register/finish', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify(attestationResponse)
        });

        const result = await finishResp.json();
        document.getElementById('result').textContent = 'Registration successful!';
        console.log(result);
    } catch (error) {
        document.getElementById('result').textContent = 'Registration failed: ' + error.message;
        console.error(error);
    }
}

async function authenticate() {
    const username = document.getElementById('auth-username').value;

    try {
        const beginResp = await fetch('https://localhost:8080/api/login/begin', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({ username })
        });

        const options = await beginResp.json();

        options.publicKey.challenge = base64urlDecode(options.publicKey.challenge);
        options.publicKey.allowCredentials = options.publicKey.allowCredentials.map(cred => ({
            ...cred,
            id: base64urlDecode(cred.id)
        }));

        const assertion = await navigator.credentials.get(options);

        const assertionResponse = {
            id: assertion.id,
            rawId: base64urlEncode(assertion.rawId),
            type: assertion.type,
            response: {
                authenticatorData: base64urlEncode(assertion.response.authenticatorData),
                clientDataJSON: base64urlEncode(assertion.response.clientDataJSON),
                signature: base64urlEncode(assertion.response.signature),
                userHandle: base64urlEncode(assertion.response.userHandle),
            },
        };

        const finishResp = await fetch('https://localhost:8080/api/login/finish', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify(assertionResponse)
        });

        const result = await finishResp.json();
        document.getElementById('result').textContent = 'Login successful!';
        console.log(result);
    } catch (error) {
        document.getElementById('result').textContent = 'Login failed: ' + error.message;
        console.error(error);
    }
}

function base64urlDecode(base64url) {
    const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/');
    const padLen = (4 - (base64.length % 4)) % 4;
    const padded = base64 + '='.repeat(padLen);
    const binary = atob(padded);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
}

function base64urlEncode(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) {
        binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}
```

The client code handles the base64url encoding conversions required by WebAuthn. The protocol uses base64url encoding for binary data transmitted over JSON, but the browser's credential API expects ArrayBuffers. The decode function converts server responses before passing them to the credential API, and the encode function converts credential responses before sending them back to the server.

Error handling in the client should guide users through different failure scenarios. Common issues include the authenticator being unavailable, the user canceling the prompt, or timeout errors. Provide clear error messages and recovery paths. For example, if registration fails because credentials already exist, direct users to the login flow instead.

## Security Best Practices

Passkey authentication eliminates many traditional security concerns but introduces new considerations. Here are the important security practices that protect your implementation and users.

Always validate the origin and RP ID match your expectations. The WebAuthn protocol includes these values in the signed data, so tampering attempts will fail verification. However, configuration mistakes can create vulnerabilities. Double-check that your RPID matches your domain exactly, and make sure RPOrigins includes only your legitimate URLs with the correct protocol and port.

Implement proper session management after authentication. Passkeys authenticate users but don't maintain sessions. After successful login, create a secure session using techniques similar to those in our [session management guide](/2025/10/how-to-implement-session-management-in-go-cookies-and-redis.html) with Redis. Issue session tokens with appropriate expiration and secure cookie flags.

Monitor sign counts diligently for clone detection. When a credential's sign count decreases or remains static across multiple authentications, the authenticator may have been cloned. Immediately revoke the credential and notify the user through out-of-band channels like email. Consider requiring re-registration with a new credential. Log these events for security analysis because they indicate potential compromise.

Store credentials securely in your database with appropriate access controls. While public keys are less sensitive than passwords, they still deserve protection. Use database encryption for credential tables and implement audit logging for credential operations. Monitor for unusual patterns like mass credential deletion or rapid credential creation that might indicate account takeover attempts.

Rate limit registration and authentication endpoints to prevent abuse. Attackers can use registration endpoints to fill your database with junk accounts or attempt to enumerate valid usernames through authentication endpoints. Implement exponential backoff for failed authentication attempts and CAPTCHA challenges after multiple failures.

## Handling Common Challenges

Production passkey implementations encounter several common challenges that require thoughtful solutions. Understanding these issues ahead of time prevents surprises during deployment.

Cross-device authentication presents the first challenge. Users expect to register a passkey on their phone and use it from their laptop. Platform authenticators like iCloud Keychain and Google Password Manager sync credentials across devices automatically, but this requires users to be logged into the same platform account on both devices. Provide clear guidance about which authenticators support syncing and how users can set it up.

Credential recovery gets tricky when users lose their device or change platforms. Unlike passwords which can be reset, losing access to all registered authenticators locks users out permanently. Implement backup authentication methods like email-based recovery or backup codes during registration. Consider allowing multiple passkeys per user so they can register both a phone and a security key for redundancy.

Browser and device compatibility varies across the ecosystem. While modern browsers support WebAuthn, older versions and some mobile browsers have limitations. Implement feature detection to check for WebAuthn support before attempting credential operations. Provide fallback authentication methods for unsupported browsers, ensuring accessibility across your user base.

User experience requires careful attention because passkeys work completely differently from passwords. Many users haven't encountered passkey authentication before and need guidance. Provide clear instructions with screenshots showing what the browser prompt will look like. Explain that they'll use their device's biometric sensor or PIN instead of typing a password. During registration, clearly communicate that they're creating a passkey rather than setting a password.

Multi-account scenarios need consideration because users might have multiple accounts on your platform. The browser shows a list of available credentials during authentication, but the UI is browser-controlled and might confuse users. Consider implementing username-first authentication where users enter their username before the passkey prompt, ensuring the correct credential list is presented.

## Integrating with Production Systems

Moving from a proof of concept to production requires integration with existing systems and infrastructure. Here are the key integration points and production considerations you need to handle.

Session management is important after successful passkey authentication. Rather than storing session data in memory maps, integrate with a session store like Redis. Create session tokens after successful authentication and store user information in the session. This maintains state across requests without requiring authentication on every request, similar to our approach in the [Redis session management tutorial](/2025/10/how-to-implement-session-management-in-go-cookies-and-redis.html).

Database migrations need careful planning when adding passkeys to existing applications. Create migration scripts that add the credentials table without disrupting existing authentication systems. Support hybrid authentication where users can choose between traditional passwords and passkeys during a transition period. Track adoption metrics to understand when you can deprecate password authentication entirely.

Monitoring and observability matter in production. Track metrics like registration success rates, authentication latency, credential clone warnings, and browser compatibility issues. Set up alerts for unusual patterns like spike in failed authentications or credential deletion events. Integrate with your existing logging infrastructure to capture detailed debug information for troubleshooting.

Load balancing requires session affinity if you use in-memory session storage, though Redis-backed sessions eliminate this requirement. WebAuthn ceremonies span multiple requests and need to maintain session state between begin and finish calls. Use sticky sessions or centralized session storage to ensure requests from the same ceremony reach the correct session data.

Certificate management deserves attention because WebAuthn requires HTTPS. Implement automated certificate renewal using Let's Encrypt or your certificate provider's API. Monitor certificate expiration dates and alert before they expire. In development environments, consider using tools like mkcert to generate locally-trusted certificates instead of accepting browser warnings for self-signed certificates.

## Conclusion

Passkey authentication is where user authentication is heading. By eliminating passwords entirely, you remove the most common attack vectors including phishing, credential stuffing, and password reuse. Users benefit from faster, more convenient authentication that works smoothly across their devices. The implementation complexity is manageable with the right libraries and following the patterns demonstrated in this guide.

The WebAuthn protocol gives you strong cryptographic guarantees that make authentication nearly impossible to compromise. Private keys never leave the user's device, making server breaches and man-in-the-middle attacks ineffective against the authentication system itself. Combined with proper sign count monitoring for clone detection, passkeys offer security that passwords simply cannot match.

Start by implementing passkeys alongside existing authentication methods to give users the option to upgrade. Monitor adoption rates and user feedback to identify pain points in your implementation. Provide clear migration paths and support for users transitioning from passwords to passkeys. Over time, you can make passkeys the primary authentication method while maintaining fallbacks for edge cases.

Remember that security extends beyond the authentication mechanism itself. Combine passkeys with other security measures like [rate limiting](/2025/10/how-to-implement-rate-limiting-in-go-protect-api-from-abuse.html) for API protection, proper session management, audit logging, and monitoring. A comprehensive security strategy addresses threats at multiple layers rather than relying on any single control.

The future of authentication is passwordless, and implementing passkeys today positions your application at the forefront of this transition. Users increasingly expect modern authentication options, and platforms that offer passkeys gain competitive advantages in user experience and security. Start building with passkeys now to deliver the authentication experience users deserve.
