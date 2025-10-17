---
title: "How to Handle File Uploads in Go - Validation, Storage, and Security"
description: "Complete guide to handling file uploads in Go with validation, secure storage, and best practices. Learn multipart form handling, file type validation, size limits, sanitization, and production security patterns."
date: 2025-10-17T12:00:00+07:00
tags: ["Go", "File Upload", "Security", "Validation", "Web Development", "HTTP"]
draft: false
author: "Wiku Karno"
keywords: ["Go file upload", "Golang multipart form", "file validation Go", "secure file upload", "Go file storage", "image upload Go", "file type validation", "Go security best practices"]
url: /2025/10/how-to-handle-file-uploads-in-go-validation-storage-and-security.html
faq:
  - question: "How do I handle file uploads in Go web applications?"
    answer: "Use http.Request.FormFile() or http.Request.MultipartReader() to receive uploaded files from multipart/form-data requests. FormFile() works for single files, while MultipartReader() handles multiple files efficiently. Always validate file size before reading entire file content, check file type using mime type detection, sanitize filenames to prevent directory traversal attacks, and store files with unique names to avoid collisions."
  - question: "What file validation should I implement for secure uploads?"
    answer: "Implement multiple validation layers: limit file size (check Content-Length header first, then validate actual bytes read), validate MIME types by reading file magic numbers not just extensions, whitelist allowed file types instead of blacklisting dangerous ones, sanitize filenames by removing path separators and special characters, and scan for malware if handling user-generated content. Never trust client-provided Content-Type header alone."
  - question: "How do I prevent directory traversal attacks in file uploads?"
    answer: "Sanitize filenames by removing or replacing path separators (/, \\), rejecting files with .. in names, using filepath.Base() to extract only filename, generating random filenames instead of using user-provided names, and storing files in dedicated upload directory outside web root. Never concatenate user input directly into file paths without validation."
  - question: "What is the best way to store uploaded files in Go?"
    answer: "For production applications, store files with unique identifiers (UUID or hash), keep original filename in database metadata, store files outside web server document root, implement proper access controls, use object storage (S3, GCS, Azure Blob) for scalability, and implement cleanup for abandoned uploads. For local storage, organize files in subdirectories (date-based or hash-based) to avoid too many files in single directory."
  - question: "How do I handle large file uploads efficiently in Go?"
    answer: "Stream files to disk using io.Copy() instead of loading into memory, set MaxBytesReader limit to prevent resource exhaustion, implement chunked uploads for very large files, use multipart.Reader for streaming multiple files, configure appropriate timeouts for upload requests, and consider implementing resumable uploads using Range headers. Monitor memory usage and implement cleanup for incomplete uploads."
  - question: "How do I validate image files and prevent malicious uploads?"
    answer: "Decode image using image.Decode() to verify valid image format, check image dimensions to prevent decompression bombs, re-encode images to strip metadata and potential exploits, validate file magic numbers match expected image types, limit image dimensions and file sizes, and consider using imaging libraries that handle format validation. Never serve uploaded files directly without validation and sanitization."
---

File uploads seem simple until you deploy to production. Users upload 500MB videos that crash your server. Someone uploads a PHP file disguised as an image and compromises your system. Filenames with path traversal characters like `../../etc/passwd` expose sensitive data. What started as a basic feature becomes a security nightmare.

This guide demonstrates how to handle file uploads securely in Go applications. You'll learn to parse multipart form data correctly, validate file types using magic number detection, enforce size limits that protect server resources, sanitize filenames to prevent attacks, store files securely with proper permissions, and implement production-ready patterns that scale.

## Understanding Multipart Form Data

HTTP file uploads use `multipart/form-data` encoding. This format splits the request body into parts, each containing a file or form field. The browser sets the `Content-Type` header to `multipart/form-data; boundary=----WebKitFormBoundary...` where the boundary separates parts.

Go's `net/http` package provides methods to parse multipart forms automatically. The `ParseMultipartForm` method reads the request body, splits it by boundaries, and makes files accessible through `FormFile` or `MultipartForm`.

Understanding limits is critical. `ParseMultipartForm` accepts a maxMemory parameter. Files smaller than this stay in memory. Larger files spill to temporary disk storage. Set this based on expected file sizes and available memory.

Request timeouts prevent slow uploads from tying up resources. Configure `http.Server` with appropriate `ReadTimeout` and `WriteTimeout` values. For large files, use longer timeouts but implement progress tracking to detect stalled uploads.

## Basic File Upload Handler

Create a simple file upload endpoint that receives and saves files.

```go
// main.go
package main

import (
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
    "path/filepath"
)

func uploadHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    const maxUploadSize = 10 << 20 // 10 MB
    r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)

    if err := r.ParseMultipartForm(maxUploadSize); err != nil {
        http.Error(w, "File too large", http.StatusBadRequest)
        return
    }

    file, header, err := r.FormFile("file")
    if err != nil {
        http.Error(w, "Error retrieving file", http.StatusBadRequest)
        return
    }
    defer file.Close()

    uploadDir := "./uploads"
    if err := os.MkdirAll(uploadDir, 0755); err != nil {
        http.Error(w, "Failed to create upload directory", http.StatusInternalServerError)
        return
    }

    dst, err := os.Create(filepath.Join(uploadDir, header.Filename))
    if err != nil {
        http.Error(w, "Failed to create file", http.StatusInternalServerError)
        return
    }
    defer dst.Close()

    if _, err := io.Copy(dst, file); err != nil {
        http.Error(w, "Failed to save file", http.StatusInternalServerError)
        return
    }

    fmt.Fprintf(w, "File uploaded successfully: %s\n", header.Filename)
}

func main() {
    http.HandleFunc("/upload", uploadHandler)

    log.Println("Server starting on :8080")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatal(err)
    }
}
```

This basic handler uses `MaxBytesReader` to enforce size limits before parsing, creates the uploads directory if missing, and streams the file to disk using `io.Copy`.

Test with curl:

```bash
curl -F "file=@image.jpg" http://localhost:8080/upload
```

## Implementing File Type Validation

Never trust the `Content-Type` header or file extension. Attackers easily manipulate these. Validate file types by reading magic numbers (file signatures).

```go
package main

import (
    "bytes"
    "fmt"
    "net/http"
)

var allowedMimeTypes = map[string]bool{
    "image/jpeg":      true,
    "image/png":       true,
    "image/gif":       true,
    "image/webp":      true,
    "application/pdf": true,
}

func detectContentType(file []byte) string {
    return http.DetectContentType(file)
}

func validateFileType(file []byte) error {
    contentType := detectContentType(file)

    if !allowedMimeTypes[contentType] {
        return fmt.Errorf("file type not allowed: %s", contentType)
    }

    return nil
}

func uploadHandlerWithValidation(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    const maxUploadSize = 10 << 20
    r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)

    if err := r.ParseMultipartForm(maxUploadSize); err != nil {
        http.Error(w, "File too large", http.StatusBadRequest)
        return
    }

    file, header, err := r.FormFile("file")
    if err != nil {
        http.Error(w, "Error retrieving file", http.StatusBadRequest)
        return
    }
    defer file.Close()

    buffer := make([]byte, 512)
    _, err = file.Read(buffer)
    if err != nil {
        http.Error(w, "Error reading file", http.StatusBadRequest)
        return
    }

    if err := validateFileType(buffer); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    file.Seek(0, 0)

    uploadDir := "./uploads"
    os.MkdirAll(uploadDir, 0755)

    dst, err := os.Create(filepath.Join(uploadDir, header.Filename))
    if err != nil {
        http.Error(w, "Failed to create file", http.StatusInternalServerError)
        return
    }
    defer dst.Close()

    if _, err := io.Copy(dst, file); err != nil {
        http.Error(w, "Failed to save file", http.StatusInternalServerError)
        return
    }

    fmt.Fprintf(w, "File uploaded successfully: %s\n", header.Filename)
}
```

The code reads the first 512 bytes to detect content type using `http.DetectContentType`, validates against whitelist, then seeks back to position 0 to copy the full file.

## Sanitizing Filenames

User-provided filenames can contain path traversal attempts or special characters that cause issues.

```go
package main

import (
    "path/filepath"
    "regexp"
    "strings"
)

var filenameRegex = regexp.MustCompile(`[^a-zA-Z0-9._-]`)

func sanitizeFilename(filename string) string {
    filename = filepath.Base(filename)

    filename = filenameRegex.ReplaceAllString(filename, "_")

    filename = strings.Trim(filename, "._-")

    if filename == "" {
        filename = "unnamed"
    }

    return filename
}
```

`filepath.Base` removes directory components, the regex replaces unsafe characters, and trimming removes leading/trailing special chars.

Use sanitized filenames:

```go
safeFilename := sanitizeFilename(header.Filename)
dst, err := os.Create(filepath.Join(uploadDir, safeFilename))
```

## Generating Unique Filenames

Using original filenames causes collisions. Generate unique names while preserving extensions.

```go
package main

import (
    "fmt"
    "path/filepath"
    "time"

    "github.com/google/uuid"
)

func generateUniqueFilename(originalFilename string) string {
    ext := filepath.Ext(originalFilename)
    uniqueID := uuid.New().String()
    timestamp := time.Now().Unix()

    return fmt.Sprintf("%d_%s%s", timestamp, uniqueID, ext)
}

func uploadHandlerWithUniqueNames(w http.ResponseWriter, r *http.Request) {
    // ... previous validation code ...

    originalFilename := sanitizeFilename(header.Filename)
    uniqueFilename := generateUniqueFilename(originalFilename)

    dst, err := os.Create(filepath.Join(uploadDir, uniqueFilename))
    if err != nil {
        http.Error(w, "Failed to create file", http.StatusInternalServerError)
        return
    }
    defer dst.Close()

    if _, err := io.Copy(dst, file); err != nil {
        http.Error(w, "Failed to save file", http.StatusInternalServerError)
        return
    }

    fmt.Fprintf(w, "File uploaded: %s (saved as: %s)\n", originalFilename, uniqueFilename)
}
```

Install UUID library:

```bash
go get github.com/google/uuid
```

## Handling Multiple File Uploads

Accept multiple files in a single request.

```go
func multipleUploadHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    const maxUploadSize = 50 << 20 // 50 MB total
    r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)

    if err := r.ParseMultipartForm(maxUploadSize); err != nil {
        http.Error(w, "Request too large", http.StatusBadRequest)
        return
    }

    files := r.MultipartForm.File["files"]
    if len(files) == 0 {
        http.Error(w, "No files uploaded", http.StatusBadRequest)
        return
    }

    uploadDir := "./uploads"
    os.MkdirAll(uploadDir, 0755)

    uploadedFiles := []string{}

    for _, fileHeader := range files {
        file, err := fileHeader.Open()
        if err != nil {
            http.Error(w, "Error opening file", http.StatusBadRequest)
            return
        }
        defer file.Close()

        buffer := make([]byte, 512)
        if _, err := file.Read(buffer); err != nil {
            http.Error(w, "Error reading file", http.StatusBadRequest)
            return
        }

        if err := validateFileType(buffer); err != nil {
            http.Error(w, fmt.Sprintf("Invalid file type: %s", err), http.StatusBadRequest)
            return
        }

        file.Seek(0, 0)

        uniqueFilename := generateUniqueFilename(fileHeader.Filename)
        dst, err := os.Create(filepath.Join(uploadDir, uniqueFilename))
        if err != nil {
            http.Error(w, "Failed to create file", http.StatusInternalServerError)
            return
        }
        defer dst.Close()

        if _, err := io.Copy(dst, file); err != nil {
            http.Error(w, "Failed to save file", http.StatusInternalServerError)
            return
        }

        uploadedFiles = append(uploadedFiles, uniqueFilename)
    }

    fmt.Fprintf(w, "Uploaded %d files: %v\n", len(uploadedFiles), uploadedFiles)
}
```

Test with multiple files:

```bash
curl -F "files=@image1.jpg" -F "files=@image2.png" http://localhost:8080/upload-multiple
```

## Validating Image Dimensions

Prevent decompression bombs and enforce size limits for images.

```go
package main

import (
    "fmt"
    "image"
    _ "image/gif"
    _ "image/jpeg"
    _ "image/png"
    "io"
)

const (
    maxImageWidth  = 4096
    maxImageHeight = 4096
)

func validateImageDimensions(file io.Reader) error {
    config, _, err := image.DecodeConfig(file)
    if err != nil {
        return fmt.Errorf("invalid image: %w", err)
    }

    if config.Width > maxImageWidth || config.Height > maxImageHeight {
        return fmt.Errorf("image dimensions too large: %dx%d (max: %dx%d)",
            config.Width, config.Height, maxImageWidth, maxImageHeight)
    }

    if config.Width < 1 || config.Height < 1 {
        return fmt.Errorf("invalid image dimensions")
    }

    return nil
}

func imageUploadHandler(w http.ResponseWriter, r *http.Request) {
    // ... previous validation code ...

    if err := validateFileType(buffer); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    file.Seek(0, 0)

    if err := validateImageDimensions(file); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    file.Seek(0, 0)

    // ... save file ...
}
```

## Implementing File Upload Service

Create a reusable service for file uploads with proper structure.

```go
// internal/upload/service.go
package upload

import (
    "fmt"
    "io"
    "mime/multipart"
    "net/http"
    "os"
    "path/filepath"
    "time"

    "github.com/google/uuid"
)

type UploadConfig struct {
    MaxFileSize      int64
    AllowedMimeTypes map[string]bool
    UploadDir        string
    MaxImageWidth    int
    MaxImageHeight   int
}

type FileInfo struct {
    OriginalName string
    SavedName    string
    Size         int64
    ContentType  string
    UploadedAt   time.Time
}

type UploadService struct {
    config UploadConfig
}

func NewUploadService(config UploadConfig) *UploadService {
    return &UploadService{config: config}
}

func (s *UploadService) ValidateAndSaveFile(fileHeader *multipart.FileHeader) (*FileInfo, error) {
    file, err := fileHeader.Open()
    if err != nil {
        return nil, fmt.Errorf("failed to open file: %w", err)
    }
    defer file.Close()

    if fileHeader.Size > s.config.MaxFileSize {
        return nil, fmt.Errorf("file size exceeds limit")
    }

    buffer := make([]byte, 512)
    if _, err := file.Read(buffer); err != nil {
        return nil, fmt.Errorf("failed to read file: %w", err)
    }

    contentType := http.DetectContentType(buffer)
    if !s.config.AllowedMimeTypes[contentType] {
        return nil, fmt.Errorf("file type not allowed: %s", contentType)
    }

    file.Seek(0, 0)

    if err := os.MkdirAll(s.config.UploadDir, 0755); err != nil {
        return nil, fmt.Errorf("failed to create upload directory: %w", err)
    }

    ext := filepath.Ext(fileHeader.Filename)
    savedName := fmt.Sprintf("%d_%s%s", time.Now().Unix(), uuid.New().String(), ext)
    filePath := filepath.Join(s.config.UploadDir, savedName)

    dst, err := os.Create(filePath)
    if err != nil {
        return nil, fmt.Errorf("failed to create file: %w", err)
    }
    defer dst.Close()

    size, err := io.Copy(dst, file)
    if err != nil {
        os.Remove(filePath)
        return nil, fmt.Errorf("failed to save file: %w", err)
    }

    return &FileInfo{
        OriginalName: fileHeader.Filename,
        SavedName:    savedName,
        Size:         size,
        ContentType:  contentType,
        UploadedAt:   time.Now(),
    }, nil
}

func (s *UploadService) DeleteFile(filename string) error {
    filePath := filepath.Join(s.config.UploadDir, filename)

    if !filepath.HasPrefix(filePath, s.config.UploadDir) {
        return fmt.Errorf("invalid file path")
    }

    return os.Remove(filePath)
}
```

Use the service in handlers:

```go
// main.go
package main

import (
    "encoding/json"
    "log"
    "net/http"
    "yourapp/internal/upload"
)

func main() {
    uploadService := upload.NewUploadService(upload.UploadConfig{
        MaxFileSize: 10 << 20,
        AllowedMimeTypes: map[string]bool{
            "image/jpeg": true,
            "image/png":  true,
            "image/gif":  true,
        },
        UploadDir:      "./uploads",
        MaxImageWidth:  4096,
        MaxImageHeight: 4096,
    })

    http.HandleFunc("/upload", func(w http.ResponseWriter, r *http.Request) {
        if r.Method != http.MethodPost {
            http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
            return
        }

        r.Body = http.MaxBytesReader(w, r.Body, uploadService.config.MaxFileSize)

        if err := r.ParseMultipartForm(uploadService.config.MaxFileSize); err != nil {
            http.Error(w, "File too large", http.StatusBadRequest)
            return
        }

        file, header, err := r.FormFile("file")
        if err != nil {
            http.Error(w, "Error retrieving file", http.StatusBadRequest)
            return
        }
        file.Close()

        fileInfo, err := uploadService.ValidateAndSaveFile(header)
        if err != nil {
            http.Error(w, err.Error(), http.StatusBadRequest)
            return
        }

        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(fileInfo)
    })

    log.Println("Server starting on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

## Storing File Metadata in Database

Track uploaded files in a database for management and access control.

```go
// internal/models/file.go
package models

import (
    "time"
)

type UploadedFile struct {
    ID           int64     `json:"id"`
    UserID       int64     `json:"user_id"`
    OriginalName string    `json:"original_name"`
    SavedName    string    `json:"saved_name"`
    FilePath     string    `json:"file_path"`
    FileSize     int64     `json:"file_size"`
    ContentType  string    `json:"content_type"`
    UploadedAt   time.Time `json:"uploaded_at"`
}

// internal/repository/file_repository.go
package repository

import (
    "context"
    "database/sql"
    "yourapp/internal/models"
)

type FileRepository struct {
    db *sql.DB
}

func NewFileRepository(db *sql.DB) *FileRepository {
    return &FileRepository{db: db}
}

func (r *FileRepository) Create(ctx context.Context, file *models.UploadedFile) error {
    query := `
        INSERT INTO uploaded_files
        (user_id, original_name, saved_name, file_path, file_size, content_type, uploaded_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `

    result, err := r.db.ExecContext(ctx, query,
        file.UserID,
        file.OriginalName,
        file.SavedName,
        file.FilePath,
        file.FileSize,
        file.ContentType,
        file.UploadedAt,
    )

    if err != nil {
        return err
    }

    id, err := result.LastInsertId()
    if err != nil {
        return err
    }

    file.ID = id
    return nil
}

func (r *FileRepository) FindByUserID(ctx context.Context, userID int64) ([]*models.UploadedFile, error) {
    query := `
        SELECT id, user_id, original_name, saved_name, file_path, file_size, content_type, uploaded_at
        FROM uploaded_files
        WHERE user_id = ?
        ORDER BY uploaded_at DESC
    `

    rows, err := r.db.QueryContext(ctx, query, userID)
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    var files []*models.UploadedFile
    for rows.Next() {
        var file models.UploadedFile
        err := rows.Scan(
            &file.ID,
            &file.UserID,
            &file.OriginalName,
            &file.SavedName,
            &file.FilePath,
            &file.FileSize,
            &file.ContentType,
            &file.UploadedAt,
        )
        if err != nil {
            return nil, err
        }
        files = append(files, &file)
    }

    return files, rows.Err()
}

func (r *FileRepository) Delete(ctx context.Context, id, userID int64) error {
    query := `DELETE FROM uploaded_files WHERE id = ? AND user_id = ?`
    _, err := r.db.ExecContext(ctx, query, id, userID)
    return err
}
```

Database schema:

```sql
CREATE TABLE uploaded_files (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    saved_name VARCHAR(255) NOT NULL UNIQUE,
    file_path VARCHAR(512) NOT NULL,
    file_size BIGINT NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_uploaded_at (uploaded_at)
);
```

## Serving Uploaded Files Securely

Never serve files directly from the upload directory. Implement access control and content disposition headers.

```go
func downloadHandler(w http.ResponseWriter, r *http.Request) {
    fileID := r.URL.Query().Get("id")
    userID := getUserIDFromSession(r) // Implement based on your auth

    fileRepo := repository.NewFileRepository(db)
    file, err := fileRepo.FindByID(r.Context(), fileID)
    if err != nil {
        http.Error(w, "File not found", http.StatusNotFound)
        return
    }

    if file.UserID != userID {
        http.Error(w, "Unauthorized", http.StatusForbidden)
        return
    }

    filePath := filepath.Join(uploadDir, file.SavedName)

    f, err := os.Open(filePath)
    if err != nil {
        http.Error(w, "File not found", http.StatusNotFound)
        return
    }
    defer f.Close()

    w.Header().Set("Content-Type", file.ContentType)
    w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", file.OriginalName))

    http.ServeContent(w, r, file.OriginalName, file.UploadedAt, f)
}
```

## Production Best Practices

Store files outside the web root to prevent direct access. Configure your upload directory with restricted permissions (0700 or 0755).

Implement file cleanup for abandoned uploads. Track upload sessions and delete files not confirmed within a timeframe.

Use object storage (S3, Google Cloud Storage) for production scalability instead of local filesystem.

Monitor disk usage and implement quotas per user to prevent abuse.

Log upload attempts including rejected files for security monitoring.

Implement virus scanning for user-generated content using ClamAV or similar tools.

Use CDN for serving files to reduce server load and improve performance.

## Conclusion

File uploads introduce security risks that require careful handling. Validate file types using magic numbers, not extensions. Enforce size limits at multiple levels. Sanitize filenames to prevent path traversal. Generate unique filenames to avoid collisions.

The patterns demonstrated here - multipart form parsing, type validation, secure storage, and database tracking - create production-ready upload systems that protect against common attacks while providing good user experience.

Remember that file uploads are a primary attack vector. Apply defense in depth by implementing multiple validation layers. Monitor upload activity for suspicious patterns. Keep upload functionality isolated with proper access controls.

Start with basic validation and gradually add features like image processing, virus scanning, and CDN integration as needs grow. Each security layer added makes the system more resistant to attacks while maintaining usability.