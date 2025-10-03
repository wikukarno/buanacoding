---
title: "How to Upload Files to AWS S3 in Go Complete Guide with SDK v2"
description: "Learn how to upload files to AWS S3 using Go and AWS SDK v2. Complete tutorial covering single file upload, multipart upload, presigned URLs, and production best practices."
date: 2025-10-03T10:00:00+07:00
tags: ["Go", "AWS", "Cloud", "Tutorial", "Backend"]
draft: false
author: "Wiku Karno"
keywords: ["golang aws s3 upload", "go sdk v2 s3", "file upload golang aws", "s3 multipart upload go", "aws s3 golang tutorial", "presigned url golang", "aws go sdk v2"]
url: /2025/10/how-to-upload-files-to-aws-s3-in-go-with-sdk-v2.html

faq:
  - question: "What's the difference between AWS SDK v1 and v2 for Go?"
    answer: "SDK v2 is a complete rewrite with better performance and cleaner APIs. It uses proper Go modules, has context-aware operations throughout, improved error handling with wrapped errors, and more consistent API patterns. If you're starting a new project, always use v2."

  - question: "Do I need to use multipart upload for all files in S3?"
    answer: "No, only for files larger than 100MB or when you want to optimize upload performance. For files under 100MB, simple `PutObject` works perfectly. The SDK's `manager.Uploader` automatically handles multipart uploads when needed."

  - question: "How do presigned URLs work for S3 uploads?"
    answer: "Presigned URLs let clients upload directly to S3 without going through your server. Your server generates a temporary URL with upload permissions (valid for 15 minutes typically), and the client POSTs directly to S3. This reduces server load and improves upload speeds."

  - question: "What's the best way to handle large file uploads in Go with S3?"
    answer: "Use the `manager.Uploader` from SDK v2 with custom part size (10MB recommended) and concurrency settings (5 concurrent parts). Add progress tracking with a custom reader wrapper to show upload status to users. Always implement retry logic for network failures."

  - question: "How do I secure S3 uploads in my Go application?"
    answer: "Enable server-side encryption with `ServerSideEncryption: types.ServerSideEncryptionAes256`, validate file types before upload, set file size limits, use private ACLs by default, validate content with MIME type detection, and never expose AWS credentials in code - use IAM roles instead."

  - question: "What are the common errors when uploading to S3 from Go?"
    answer: "Most common: Access Denied (check IAM permissions), NoSuchBucket (verify bucket name and region), slow uploads (use multipart for large files), presigned URL failures (check system clock sync), and invalid content types (set ContentType explicitly in PutObjectInput)."

  - question: "How much does S3 storage cost and how can I optimize it?"
    answer: "S3 Standard costs about $0.023/GB/month. Optimize costs by using Intelligent-Tiering storage class, implementing lifecycle policies to delete old files, using multipart uploads to avoid re-uploading on failures, and setting appropriate file retention periods."
---

If you've built any real application, you know file storage becomes a problem fast. User avatars, document uploads, video files - they pile up quickly, and you need somewhere reliable to put them. That's where AWS S3 comes in. It's like having unlimited storage that you only pay for what you use, and it integrates beautifully with Go.

AWS recently rewrote their entire Go SDK with v2, and honestly, it's a massive improvement. Cleaner APIs, better error handling, proper context support - everything you'd want in a modern Go library. If you're starting fresh or thinking about upgrading from v1, this guide has you covered.

I'll walk you through building a complete S3 upload system - from basic file uploads to handling massive files with multipart uploads, plus presigned URLs so users can upload directly without hitting your server. We'll cover all the production stuff too: error handling, retries, security, and the gotchas I learned the hard way.

## Understanding AWS S3 and SDK v2

Think of S3 as Amazon's version of Dropbox for your applications. Instead of traditional folders and files, S3 uses buckets (containers) and objects (your files plus their metadata). You create a bucket once, then throw as many files into it as you want. Each file gets a unique key - basically its path within the bucket.

The v2 SDK is a total rewrite from the ground up. AWS learned from v1's mistakes and built something that actually feels like modern Go. Proper module support, errors that make sense, context everywhere it should be, and APIs that don't make you scratch your head.

Here's what you need to know before we start coding:

**Buckets** are like folders, but globally unique across all of AWS. Pick a good name because you can't change it later. Each bucket lives in a specific AWS region - choose one close to your users for better performance.

**Objects** are your actual files. S3 stores the file content, lets you attach custom metadata (think tags or additional info), and identifies each object by its key. Keys look like file paths: `users/avatars/user123.jpg`.

**Regions** matter for speed and compliance. Store data in `us-east-1` if your users are in New York, `eu-west-1` for London. Wrong region choice means slower uploads and higher latency.

**Access Control** is how you decide who can do what. Use IAM roles for your app, bucket policies for broad rules, and presigned URLs when you want to give temporary access to specific files.

## Prerequisites and Setup

Before writing code, you need an AWS account and proper credentials. If you don't have an AWS account yet, create one at aws.amazon.com. The free tier includes 5GB of S3 storage which is plenty for development and testing.

### Creating IAM Credentials

For security, never use your root AWS account credentials in applications. Instead, create an IAM user with specific S3 permissions:

1. Navigate to IAM in the AWS Console
2. Create a new user with programmatic access
3. Attach the `AmazonS3FullAccess` policy (or create a custom policy with specific permissions)
4. Save the Access Key ID and Secret Access Key

For production, use more restrictive policies that grant only the permissions your application actually needs.

### Configuring AWS Credentials

The AWS SDK for Go v2 supports multiple credential sources. The recommended approach for development is using the AWS credentials file:

Create `~/.aws/credentials`:

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
```

Create `~/.aws/config`:

```ini
[default]
region = us-east-1
```

For production environments, use IAM roles attached to EC2 instances, ECS tasks, or Lambda functions instead of hardcoded credentials. The SDK automatically discovers and uses these roles.

### Installing Dependencies

Create a new Go project and install the required AWS SDK v2 packages:

```bash
mkdir s3-upload-tutorial
cd s3-upload-tutorial
go mod init github.com/yourusername/s3-upload-tutorial
```

Install the AWS SDK v2 packages:

```bash
go get github.com/aws/aws-sdk-go-v2/config
go get github.com/aws/aws-sdk-go-v2/service/s3
go get github.com/aws/aws-sdk-go-v2/feature/s3/manager
go get github.com/aws/aws-sdk-go-v2/aws
```

The SDK v2 is modular, so you only import the packages you actually need. This reduces binary size and dependency bloat compared to v1.

## Creating an S3 Client

The first step in any S3 operation is creating a properly configured client. The AWS SDK v2 uses a configuration-first approach where you load configuration once and use it to create service clients.

Create the basic S3 client:

```go
// main.go
package main

import (
    "context"
    "fmt"
    "log"

    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/s3"
)

func main() {
    // Load AWS configuration
    cfg, err := config.LoadDefaultConfig(context.TODO(),
        config.WithRegion("us-east-1"),
    )
    if err != nil {
        log.Fatalf("unable to load SDK config, %v", err)
    }

    // Create S3 client
    client := s3.NewFromConfig(cfg)

    fmt.Println("S3 client created successfully")
}
```

The `LoadDefaultConfig` function automatically discovers credentials from the environment, credentials file, IAM roles, or other sources. You can override the region or provide custom configuration options as needed.

For production applications, you typically want more control over timeouts and retries:

```go
package main

import (
    "context"
    "fmt"
    "log"
    "time"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/aws/retry"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/s3"
)

func createS3Client(ctx context.Context, region string) (*s3.Client, error) {
    cfg, err := config.LoadDefaultConfig(ctx,
        config.WithRegion(region),
        config.WithRetryMaxAttempts(3),
        config.WithRetryMode(aws.RetryModeAdaptive),
    )
    if err != nil {
        return nil, fmt.Errorf("failed to load config: %w", err)
    }

    // Create S3 client with custom options
    client := s3.NewFromConfig(cfg, func(o *s3.Options) {
        o.UsePathStyle = false // Use virtual-hosted-style URLs
    })

    return client, nil
}

func main() {
    ctx := context.Background()

    client, err := createS3Client(ctx, "us-east-1")
    if err != nil {
        log.Fatalf("Failed to create S3 client: %v", err)
    }

    fmt.Println("S3 client created successfully")
    _ = client // Use the client for operations
}
```

This production-ready configuration includes retry logic and proper error wrapping. The adaptive retry mode automatically adjusts retry behavior based on error types and server responses.

## Simple File Upload

Time to actually upload something. We'll start simple - grabbing a file from your disk and pushing it to S3. This approach works perfectly for files under 5GB, which covers most use cases.

### Basic Upload Implementation

```go
package main

import (
    "context"
    "fmt"
    "log"
    "os"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/s3"
)

func uploadFile(ctx context.Context, client *s3.Client, bucketName, objectKey, filePath string) error {
    // Open the file
    file, err := os.Open(filePath)
    if err != nil {
        return fmt.Errorf("failed to open file %s: %w", filePath, err)
    }
    defer file.Close()

    // Upload the file to S3
    _, err = client.PutObject(ctx, &s3.PutObjectInput{
        Bucket: aws.String(bucketName),
        Key:    aws.String(objectKey),
        Body:   file,
    })
    if err != nil {
        return fmt.Errorf("failed to upload file: %w", err)
    }

    fmt.Printf("Successfully uploaded %s to %s/%s\n", filePath, bucketName, objectKey)
    return nil
}

func main() {
    ctx := context.Background()

    // Load config and create client
    cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion("us-east-1"))
    if err != nil {
        log.Fatalf("unable to load SDK config: %v", err)
    }
    client := s3.NewFromConfig(cfg)

    // Upload a file
    err = uploadFile(ctx, client, "my-bucket", "uploads/example.txt", "./example.txt")
    if err != nil {
        log.Fatalf("upload failed: %v", err)
    }
}
```

This basic implementation uploads a file in a single PutObject operation. The SDK handles reading the file content and streaming it to S3.

### Adding Metadata and Content Type

In production, you'll want to set appropriate metadata and content types for your objects:

```go
package main

import (
    "context"
    "fmt"
    "mime"
    "os"
    "path/filepath"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/service/s3"
    "github.com/aws/aws-sdk-go-v2/service/s3/types"
)

func uploadFileWithMetadata(ctx context.Context, client *s3.Client, bucketName, objectKey, filePath string, metadata map[string]string) error {
    file, err := os.Open(filePath)
    if err != nil {
        return fmt.Errorf("failed to open file: %w", err)
    }
    defer file.Close()

    // Detect content type based on file extension
    contentType := mime.TypeByExtension(filepath.Ext(filePath))
    if contentType == "" {
        contentType = "application/octet-stream"
    }

    // Get file info for content length
    fileInfo, err := file.Stat()
    if err != nil {
        return fmt.Errorf("failed to stat file: %w", err)
    }

    _, err = client.PutObject(ctx, &s3.PutObjectInput{
        Bucket:        aws.String(bucketName),
        Key:           aws.String(objectKey),
        Body:          file,
        ContentType:   aws.String(contentType),
        ContentLength: aws.Int64(fileInfo.Size()),
        Metadata:      metadata,
        ACL:           types.ObjectCannedACLPrivate,
    })
    if err != nil {
        return fmt.Errorf("failed to upload: %w", err)
    }

    fmt.Printf("Uploaded %s (%d bytes, type: %s)\n", objectKey, fileInfo.Size(), contentType)
    return nil
}

func main() {
    // Usage example
    ctx := context.Background()

    // Assume client is already created
    var client *s3.Client // Created as shown earlier

    metadata := map[string]string{
        "uploaded-by": "tutorial-app",
        "version":     "1.0",
    }

    err := uploadFileWithMetadata(ctx, client, "my-bucket", "documents/report.pdf", "./report.pdf", metadata)
    if err != nil {
        fmt.Printf("Upload failed: %v\n", err)
    }
}
```

Setting the correct `ContentType` matters more than you think. Browsers use this to decide whether to display an image inline or force a download. Get it wrong and your PDFs might try to render as text. Custom metadata is your chance to attach extra info - user IDs, upload timestamps, whatever your app needs to track.

### Upload from Memory (Byte Slice)

Sometimes you generate content in memory rather than reading from disk. For example, image processing, PDF generation, or API responses:

```go
package main

import (
    "bytes"
    "context"
    "fmt"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/service/s3"
)

func uploadFromMemory(ctx context.Context, client *s3.Client, bucketName, objectKey string, data []byte, contentType string) error {
    _, err := client.PutObject(ctx, &s3.PutObjectInput{
        Bucket:      aws.String(bucketName),
        Key:         aws.String(objectKey),
        Body:        bytes.NewReader(data),
        ContentType: aws.String(contentType),
    })
    if err != nil {
        return fmt.Errorf("failed to upload: %w", err)
    }

    fmt.Printf("Uploaded %d bytes to %s/%s\n", len(data), bucketName, objectKey)
    return nil
}

func main() {
    ctx := context.Background()

    // Example: Upload generated JSON data
    jsonData := []byte(`{"status": "success", "message": "Hello from S3"}`)

    var client *s3.Client // Created as shown earlier

    err := uploadFromMemory(ctx, client, "my-bucket", "api/response.json", jsonData, "application/json")
    if err != nil {
        fmt.Printf("Upload failed: %v\n", err)
    }
}
```

The `bytes.NewReader` creates an `io.Reader` from a byte slice, which is exactly what the S3 API expects.

## Multipart Upload for Large Files

Got a big video file or database backup? Regular uploads will time out and make you sad. Multipart upload is your answer - it chops your file into chunks (5MB to 5GB each), uploads them simultaneously, and S3 stitches them back together. Way faster and more reliable than trying to upload a 2GB file in one go.

The SDK v2's `manager.Uploader` does all the heavy lifting automatically:

```go
package main

import (
    "context"
    "fmt"
    "os"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/feature/s3/manager"
    "github.com/aws/aws-sdk-go-v2/service/s3"
)

func uploadLargeFile(ctx context.Context, client *s3.Client, bucketName, objectKey, filePath string) error {
    // Open the file
    file, err := os.Open(filePath)
    if err != nil {
        return fmt.Errorf("failed to open file: %w", err)
    }
    defer file.Close()

    // Create an uploader with custom options
    uploader := manager.NewUploader(client, func(u *manager.Uploader) {
        u.PartSize = 10 * 1024 * 1024 // 10MB per part
        u.Concurrency = 5               // Upload 5 parts concurrently
    })

    // Upload the file
    result, err := uploader.Upload(ctx, &s3.PutObjectInput{
        Bucket: aws.String(bucketName),
        Key:    aws.String(objectKey),
        Body:   file,
    })
    if err != nil {
        return fmt.Errorf("failed to upload large file: %w", err)
    }

    fmt.Printf("Successfully uploaded to %s\n", result.Location)
    return nil
}

func main() {
    ctx := context.Background()

    cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion("us-east-1"))
    if err != nil {
        panic(err)
    }
    client := s3.NewFromConfig(cfg)

    // Upload a large file
    err = uploadLargeFile(ctx, client, "my-bucket", "videos/large-video.mp4", "./large-video.mp4")
    if err != nil {
        fmt.Printf("Upload failed: %v\n", err)
    }
}
```

The `manager.Uploader` automatically determines when to use multipart upload based on file size. You can customize the part size and concurrency to optimize for your network conditions and file sizes.

### Progress Tracking for Large Uploads

Nobody likes staring at a blank screen wondering if their upload is actually working. Let's add a progress bar:

```go
package main

import (
    "context"
    "fmt"
    "os"
    "sync/atomic"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/feature/s3/manager"
    "github.com/aws/aws-sdk-go-v2/service/s3"
)

type ProgressReader struct {
    file       *os.File
    totalBytes int64
    readBytes  *atomic.Int64
    onProgress func(uploaded, total int64)
}

func (pr *ProgressReader) Read(p []byte) (int, error) {
    n, err := pr.file.Read(p)

    if n > 0 {
        uploaded := pr.readBytes.Add(int64(n))
        if pr.onProgress != nil {
            pr.onProgress(uploaded, pr.totalBytes)
        }
    }

    return n, err
}

func uploadWithProgress(ctx context.Context, client *s3.Client, bucketName, objectKey, filePath string) error {
    file, err := os.Open(filePath)
    if err != nil {
        return fmt.Errorf("failed to open file: %w", err)
    }
    defer file.Close()

    // Get file size
    fileInfo, err := file.Stat()
    if err != nil {
        return fmt.Errorf("failed to stat file: %w", err)
    }
    totalBytes := fileInfo.Size()

    // Create progress reader
    var readBytes atomic.Int64
    progressReader := &ProgressReader{
        file:       file,
        totalBytes: totalBytes,
        readBytes:  &readBytes,
        onProgress: func(uploaded, total int64) {
            percentage := float64(uploaded) / float64(total) * 100
            fmt.Printf("\rProgress: %.2f%% (%d/%d bytes)", percentage, uploaded, total)
        },
    }

    // Create uploader
    uploader := manager.NewUploader(client, func(u *manager.Uploader) {
        u.PartSize = 10 * 1024 * 1024
        u.Concurrency = 5
    })

    // Upload with progress tracking
    _, err = uploader.Upload(ctx, &s3.PutObjectInput{
        Bucket: aws.String(bucketName),
        Key:    aws.String(objectKey),
        Body:   progressReader,
    })
    if err != nil {
        return fmt.Errorf("upload failed: %w", err)
    }

    fmt.Println("\nUpload completed successfully!")
    return nil
}
```

The progress tracking wraps the file reader and reports bytes uploaded. This is perfect for building upload progress bars in web applications or CLI tools.

## Presigned URLs for Direct Uploads

Want users to upload straight to S3 without hitting your server? Presigned URLs are magic. Your server creates a temporary URL with upload permissions built in, hands it to the client, and the client uploads directly to S3. Your server never sees the file - less bandwidth, less processing, happier servers.

### Generating Presigned Upload URLs

```go
package main

import (
    "context"
    "fmt"
    "time"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/service/s3"
)

func generatePresignedUploadURL(ctx context.Context, client *s3.Client, bucketName, objectKey string, duration time.Duration) (string, error) {
    // Create presign client
    presignClient := s3.NewPresignClient(client)

    // Generate presigned PUT request
    request, err := presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
        Bucket: aws.String(bucketName),
        Key:    aws.String(objectKey),
    }, func(opts *s3.PresignOptions) {
        opts.Expires = duration
    })
    if err != nil {
        return "", fmt.Errorf("failed to presign request: %w", err)
    }

    return request.URL, nil
}

func main() {
    ctx := context.Background()

    var client *s3.Client // Created as shown earlier

    // Generate URL valid for 15 minutes
    url, err := generatePresignedUploadURL(ctx, client, "my-bucket", "user-uploads/photo.jpg", 15*time.Minute)
    if err != nil {
        fmt.Printf("Failed to generate URL: %v\n", err)
        return
    }

    fmt.Printf("Upload your file to: %s\n", url)
    fmt.Println("Use PUT method with the file content in the request body")
}
```

The presigned URL contains authentication information in the query parameters, allowing unauthenticated requests to upload for a limited time.

### Client-Side Upload with Presigned URL

Here's how a client would use the presigned URL to upload a file:

```go
package main

import (
    "bytes"
    "fmt"
    "io"
    "net/http"
    "os"
)

func uploadToPresignedURL(presignedURL, filePath string) error {
    // Read file
    file, err := os.Open(filePath)
    if err != nil {
        return fmt.Errorf("failed to open file: %w", err)
    }
    defer file.Close()

    // Read file content
    fileContent, err := io.ReadAll(file)
    if err != nil {
        return fmt.Errorf("failed to read file: %w", err)
    }

    // Create PUT request
    req, err := http.NewRequest(http.MethodPut, presignedURL, bytes.NewReader(fileContent))
    if err != nil {
        return fmt.Errorf("failed to create request: %w", err)
    }

    // Set content type (important!)
    req.Header.Set("Content-Type", "image/jpeg")

    // Execute request
    client := &http.Client{}
    resp, err := client.Do(req)
    if err != nil {
        return fmt.Errorf("failed to upload: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        body, _ := io.ReadAll(resp.Body)
        return fmt.Errorf("upload failed with status %d: %s", resp.StatusCode, string(body))
    }

    fmt.Println("File uploaded successfully via presigned URL")
    return nil
}

func main() {
    presignedURL := "https://my-bucket.s3.amazonaws.com/..." // From server

    err := uploadToPresignedURL(presignedURL, "./photo.jpg")
    if err != nil {
        fmt.Printf("Upload failed: %v\n", err)
    }
}
```

This approach is perfect for web applications where users upload files directly from their browsers, mobile apps, or any HTTP client.

### Presigned URLs with Custom Metadata

You can also enforce specific metadata and content type in presigned URLs:

```go
package main

import (
    "context"
    "fmt"
    "time"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/service/s3"
)

func generatePresignedUploadWithMetadata(ctx context.Context, client *s3.Client, bucketName, objectKey, contentType string, metadata map[string]string) (string, error) {
    presignClient := s3.NewPresignClient(client)

    request, err := presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
        Bucket:      aws.String(bucketName),
        Key:         aws.String(objectKey),
        ContentType: aws.String(contentType),
        Metadata:    metadata,
    }, func(opts *s3.PresignOptions) {
        opts.Expires = 15 * time.Minute
    })
    if err != nil {
        return "", fmt.Errorf("failed to presign: %w", err)
    }

    return request.URL, nil
}

func main() {
    ctx := context.Background()

    var client *s3.Client // Created as shown earlier

    metadata := map[string]string{
        "user-id":      "12345",
        "upload-date":  time.Now().Format(time.RFC3339),
    }

    url, err := generatePresignedUploadWithMetadata(
        ctx,
        client,
        "my-bucket",
        "user-uploads/document.pdf",
        "application/pdf",
        metadata,
    )
    if err != nil {
        fmt.Printf("Failed: %v\n", err)
        return
    }

    fmt.Printf("Presigned URL: %s\n", url)
}
```

When using presigned URLs with specific headers, the client must include those exact headers in the upload request, or the request will fail. This provides an additional layer of validation.

## Production Best Practices

Development code that works on your laptop will crash in production. Trust me, I've been there. Here's what you need to actually ship this to real users.

### Error Handling and Retries

The SDK v2 includes automatic retry logic, but you should handle specific error cases:

```go
package main

import (
    "context"
    "errors"
    "fmt"
    "os"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/service/s3"
    "github.com/aws/aws-sdk-go-v2/service/s3/types"
)

func uploadWithErrorHandling(ctx context.Context, client *s3.Client, bucketName, objectKey, filePath string) error {
    file, err := os.Open(filePath)
    if err != nil {
        return fmt.Errorf("failed to open file: %w", err)
    }
    defer file.Close()

    _, err = client.PutObject(ctx, &s3.PutObjectInput{
        Bucket: aws.String(bucketName),
        Key:    aws.String(objectKey),
        Body:   file,
    })

    if err != nil {
        // Check for specific error types
        var noBucket *types.NoSuchBucket
        if errors.As(err, &noBucket) {
            return fmt.Errorf("bucket %s does not exist: %w", bucketName, err)
        }

        var notFound *types.NotFound
        if errors.As(err, &notFound) {
            return fmt.Errorf("resource not found: %w", err)
        }

        // Generic error
        return fmt.Errorf("upload failed: %w", err)
    }

    return nil
}
```

The SDK v2 uses typed errors that you can check with `errors.As()`. This allows you to handle different error scenarios appropriately.

### Concurrent Upload Limits

When uploading multiple files concurrently, control the number of simultaneous operations to avoid overwhelming your network or hitting AWS rate limits:

```go
package main

import (
    "context"
    "fmt"
    "os"
    "path/filepath"
    "sync"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/service/s3"
)

type UploadJob struct {
    FilePath  string
    ObjectKey string
}

type UploadResult struct {
    ObjectKey string
    Error     error
}

func uploadConcurrent(ctx context.Context, client *s3.Client, bucketName string, jobs []UploadJob, maxConcurrency int) []UploadResult {
    jobChan := make(chan UploadJob, len(jobs))
    resultChan := make(chan UploadResult, len(jobs))

    // Worker pool
    var wg sync.WaitGroup
    for i := 0; i < maxConcurrency; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for job := range jobChan {
                err := uploadSingleFile(ctx, client, bucketName, job.ObjectKey, job.FilePath)
                resultChan <- UploadResult{
                    ObjectKey: job.ObjectKey,
                    Error:     err,
                }
            }
        }()
    }

    // Send jobs
    for _, job := range jobs {
        jobChan <- job
    }
    close(jobChan)

    // Wait for completion
    go func() {
        wg.Wait()
        close(resultChan)
    }()

    // Collect results
    var results []UploadResult
    for result := range resultChan {
        results = append(results, result)
    }

    return results
}

func uploadSingleFile(ctx context.Context, client *s3.Client, bucketName, objectKey, filePath string) error {
    file, err := os.Open(filePath)
    if err != nil {
        return err
    }
    defer file.Close()

    _, err = client.PutObject(ctx, &s3.PutObjectInput{
        Bucket: aws.String(bucketName),
        Key:    aws.String(objectKey),
        Body:   file,
    })
    return err
}

func main() {
    ctx := context.Background()

    var client *s3.Client // Created as shown earlier

    // Prepare upload jobs
    jobs := []UploadJob{
        {FilePath: "./file1.txt", ObjectKey: "uploads/file1.txt"},
        {FilePath: "./file2.txt", ObjectKey: "uploads/file2.txt"},
        {FilePath: "./file3.txt", ObjectKey: "uploads/file3.txt"},
    }

    // Upload with max 3 concurrent uploads
    results := uploadConcurrent(ctx, client, "my-bucket", jobs, 3)

    // Check results
    for _, result := range results {
        if result.Error != nil {
            fmt.Printf("Failed to upload %s: %v\n", result.ObjectKey, result.Error)
        } else {
            fmt.Printf("Successfully uploaded %s\n", result.ObjectKey)
        }
    }
}
```

This worker pool pattern prevents resource exhaustion while maximizing throughput. Adjust `maxConcurrency` based on your network bandwidth and AWS account limits.

### Security Considerations

Security should be a priority from day one:

**1. Use Server-Side Encryption:**

```go
_, err = client.PutObject(ctx, &s3.PutObjectInput{
    Bucket:               aws.String(bucketName),
    Key:                  aws.String(objectKey),
    Body:                 file,
    ServerSideEncryption: types.ServerSideEncryptionAes256,
})
```

**2. Validate File Types:**

```go
package main

import (
    "fmt"
    "net/http"
    "os"
)

var allowedMimeTypes = map[string]bool{
    "image/jpeg": true,
    "image/png":  true,
    "image/gif":  true,
    "application/pdf": true,
}

func validateFileType(filePath string) error {
    file, err := os.Open(filePath)
    if err != nil {
        return err
    }
    defer file.Close()

    // Read first 512 bytes for MIME detection
    buffer := make([]byte, 512)
    _, err = file.Read(buffer)
    if err != nil {
        return err
    }

    contentType := http.DetectContentType(buffer)
    if !allowedMimeTypes[contentType] {
        return fmt.Errorf("file type %s not allowed", contentType)
    }

    return nil
}
```

**3. Set Appropriate ACLs:**

Never use public-read ACLs unless absolutely necessary. Use bucket policies and IAM roles for access control:

```go
_, err = client.PutObject(ctx, &s3.PutObjectInput{
    Bucket: aws.String(bucketName),
    Key:    aws.String(objectKey),
    Body:   file,
    ACL:    types.ObjectCannedACLPrivate, // Default: private
})
```

**4. Implement File Size Limits:**

```go
func checkFileSize(filePath string, maxSize int64) error {
    info, err := os.Stat(filePath)
    if err != nil {
        return err
    }

    if info.Size() > maxSize {
        return fmt.Errorf("file size %d exceeds limit %d", info.Size(), maxSize)
    }

    return nil
}
```

### Cost Optimization

S3 costs can add up quickly if you're not careful:

**1. Use Lifecycle Policies** to automatically transition old files to cheaper storage classes or delete them:

You configure this in the AWS Console or via CloudFormation, but your application should design with this in mind.

**2. Set Proper Storage Classes:**

```go
_, err = client.PutObject(ctx, &s3.PutObjectInput{
    Bucket:       aws.String(bucketName),
    Key:          aws.String(objectKey),
    Body:         file,
    StorageClass: types.StorageClassIntelligentTiering, // Auto-optimize costs
})
```

**3. Use Multipart Upload for Large Files** to avoid re-uploading the entire file on failure.

## Complete Production Example

Let's put everything together into a production-ready upload service:

```go
package main

import (
    "context"
    "fmt"
    "io"
    "mime"
    "net/http"
    "os"
    "path/filepath"
    "time"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/feature/s3/manager"
    "github.com/aws/aws-sdk-go-v2/service/s3"
    "github.com/aws/aws-sdk-go-v2/service/s3/types"
)

// S3Uploader handles file uploads to S3
type S3Uploader struct {
    client     *s3.Client
    uploader   *manager.Uploader
    bucketName string
    region     string
}

// Config holds uploader configuration
type Config struct {
    BucketName     string
    Region         string
    MaxFileSize    int64
    AllowedTypes   map[string]bool
    PartSize       int64
    Concurrency    int
}

// NewS3Uploader creates a new uploader instance
func NewS3Uploader(ctx context.Context, cfg Config) (*S3Uploader, error) {
    awsCfg, err := config.LoadDefaultConfig(ctx,
        config.WithRegion(cfg.Region),
    )
    if err != nil {
        return nil, fmt.Errorf("failed to load AWS config: %w", err)
    }

    client := s3.NewFromConfig(awsCfg)
    uploader := manager.NewUploader(client, func(u *manager.Uploader) {
        if cfg.PartSize > 0 {
            u.PartSize = cfg.PartSize
        }
        if cfg.Concurrency > 0 {
            u.Concurrency = cfg.Concurrency
        }
    })

    return &S3Uploader{
        client:     client,
        uploader:   uploader,
        bucketName: cfg.BucketName,
        region:     cfg.Region,
    }, nil
}

// UploadFile uploads a file with validation and metadata
func (u *S3Uploader) UploadFile(ctx context.Context, filePath, objectKey string, metadata map[string]string) (string, error) {
    // Validate file exists
    info, err := os.Stat(filePath)
    if err != nil {
        return "", fmt.Errorf("file not found: %w", err)
    }

    // Open file
    file, err := os.Open(filePath)
    if err != nil {
        return "", fmt.Errorf("failed to open file: %w", err)
    }
    defer file.Close()

    // Detect content type
    contentType := mime.TypeByExtension(filepath.Ext(filePath))
    if contentType == "" {
        contentType = "application/octet-stream"
    }

    // Upload
    result, err := u.uploader.Upload(ctx, &s3.PutObjectInput{
        Bucket:               aws.String(u.bucketName),
        Key:                  aws.String(objectKey),
        Body:                 file,
        ContentType:          aws.String(contentType),
        Metadata:             metadata,
        ServerSideEncryption: types.ServerSideEncryptionAes256,
    })
    if err != nil {
        return "", fmt.Errorf("upload failed: %w", err)
    }

    fmt.Printf("Uploaded %s (%d bytes) to %s\n", objectKey, info.Size(), result.Location)
    return result.Location, nil
}

// GeneratePresignedURL creates a presigned upload URL
func (u *S3Uploader) GeneratePresignedURL(ctx context.Context, objectKey, contentType string, duration time.Duration) (string, error) {
    presignClient := s3.NewPresignClient(u.client)

    request, err := presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
        Bucket:      aws.String(u.bucketName),
        Key:         aws.String(objectKey),
        ContentType: aws.String(contentType),
    }, func(opts *s3.PresignOptions) {
        opts.Expires = duration
    })
    if err != nil {
        return "", fmt.Errorf("failed to presign: %w", err)
    }

    return request.URL, nil
}

// ValidateFile checks file type and size
func ValidateFile(filePath string, maxSize int64, allowedTypes map[string]bool) error {
    info, err := os.Stat(filePath)
    if err != nil {
        return fmt.Errorf("file not found: %w", err)
    }

    // Check size
    if info.Size() > maxSize {
        return fmt.Errorf("file size %d exceeds limit %d", info.Size(), maxSize)
    }

    // Check type
    file, err := os.Open(filePath)
    if err != nil {
        return err
    }
    defer file.Close()

    buffer := make([]byte, 512)
    _, err = file.Read(buffer)
    if err != nil && err != io.EOF {
        return err
    }

    contentType := http.DetectContentType(buffer)
    if !allowedTypes[contentType] {
        return fmt.Errorf("file type %s not allowed", contentType)
    }

    return nil
}

func main() {
    ctx := context.Background()

    // Configure uploader
    config := Config{
        BucketName:  "my-production-bucket",
        Region:      "us-east-1",
        MaxFileSize: 100 * 1024 * 1024, // 100MB
        AllowedTypes: map[string]bool{
            "image/jpeg":      true,
            "image/png":       true,
            "application/pdf": true,
        },
        PartSize:    10 * 1024 * 1024, // 10MB
        Concurrency: 5,
    }

    // Create uploader
    uploader, err := NewS3Uploader(ctx, config)
    if err != nil {
        panic(err)
    }

    // Example 1: Direct upload
    filePath := "./document.pdf"

    err = ValidateFile(filePath, config.MaxFileSize, config.AllowedTypes)
    if err != nil {
        fmt.Printf("Validation failed: %v\n", err)
        return
    }

    metadata := map[string]string{
        "uploaded-at": time.Now().Format(time.RFC3339),
        "user-id":     "user123",
    }

    location, err := uploader.UploadFile(ctx, filePath, "documents/report.pdf", metadata)
    if err != nil {
        fmt.Printf("Upload failed: %v\n", err)
        return
    }
    fmt.Printf("File available at: %s\n", location)

    // Example 2: Generate presigned URL
    presignedURL, err := uploader.GeneratePresignedURL(ctx, "uploads/photo.jpg", "image/jpeg", 15*time.Minute)
    if err != nil {
        fmt.Printf("Failed to generate presigned URL: %v\n", err)
        return
    }
    fmt.Printf("Upload to: %s\n", presignedURL)
}
```

This production-ready implementation includes:
- Proper configuration management
- File validation (type and size)
- Automatic content type detection
- Server-side encryption
- Custom metadata
- Error handling
- Both direct upload and presigned URL support

## Testing Your Implementation

Testing S3 operations can be tricky since they interact with external services. Here's how to approach testing:

### Unit Testing with Mocks

For unit tests, mock the S3 client interface:

```go
package main

import (
    "context"
    "testing"

    "github.com/aws/aws-sdk-go-v2/service/s3"
)

// Mock S3 client for testing
type MockS3Client struct {
    PutObjectFunc func(ctx context.Context, params *s3.PutObjectInput, optFns ...func(*s3.Options)) (*s3.PutObjectOutput, error)
}

func (m *MockS3Client) PutObject(ctx context.Context, params *s3.PutObjectInput, optFns ...func(*s3.Options)) (*s3.PutObjectOutput, error) {
    return m.PutObjectFunc(ctx, params, optFns...)
}

func TestUpload(t *testing.T) {
    // Test implementation here
    // Use the mock client to verify behavior
}
```

### Integration Testing

For integration tests, use a test bucket or LocalStack (local AWS simulator):

```bash
# Install LocalStack
pip install localstack

# Start LocalStack with S3
localstack start

# Set AWS endpoint for testing
export AWS_ENDPOINT_URL=http://localhost:4566
```

Then configure your S3 client to use the local endpoint:

```go
client := s3.NewFromConfig(cfg, func(o *s3.Options) {
    o.BaseEndpoint = aws.String("http://localhost:4566")
    o.UsePathStyle = true
})
```

## Common Issues and Troubleshooting

### Access Denied Errors

**Symptom:** Upload fails with "Access Denied" error

**Solutions:**
1. Verify IAM permissions include `s3:PutObject` for the bucket
2. Check bucket policy doesn't deny uploads
3. Ensure credentials are correctly configured
4. Verify the bucket exists and you have access

### Slow Upload Performance

**Symptom:** Uploads take longer than expected

**Solutions:**
1. Use multipart upload for files over 100MB
2. Increase concurrency in uploader configuration
3. Check network bandwidth and latency to AWS region
4. Consider using Transfer Acceleration for global uploads

### Invalid Content Type

**Symptom:** Files don't display correctly when accessed via browser

**Solution:** Set correct `ContentType` in `PutObjectInput`:

```go
ContentType: aws.String("image/jpeg"), // Set appropriate type
```

### Presigned URL Failures

**Symptom:** Presigned URL uploads fail with signature errors

**Solutions:**
1. Ensure system clock is synchronized (signature includes timestamp)
2. Client must use exact headers specified in presigned request
3. URL must be used before expiration time
4. Check for URL encoding issues

## Next Steps and Advanced Topics

Now that you understand S3 uploads with Go SDK v2, consider exploring these advanced topics:

**Object Lifecycle Management:** Configure automatic transitions to cheaper storage classes or deletion after specific periods. This can significantly reduce storage costs for temporary or archival data.

**Cross-Region Replication:** Automatically replicate objects across AWS regions for disaster recovery or reduced latency for global users.

**Event Notifications:** Trigger Lambda functions or send SNS notifications when objects are uploaded. Perfect for implementing image processing pipelines, virus scanning, or automatic backup systems.

**S3 Select:** Query data directly in S3 without downloading entire objects. Great for large CSV or JSON files where you only need specific records.

**Versioning:** Enable S3 versioning to keep multiple versions of objects, protecting against accidental deletions or overwrites.

For building complete backend systems with Go, check out [how to build REST APIs with Gin framework](/2025/09/building-rest-api-gin-framework-golang-production-ready.html) and [implementing JWT authentication](/2025/08/how-to-implement-jwt-authentication-in-go-secure-rest-api.html) to secure your upload endpoints. You might also want to implement [rate limiting](/2025/08/how-to-implement-rate-limiting-in-go-protect-api.html) to prevent upload abuse, and use [Redis for caching](/2025/08/how-to-use-redis-with-go-caching-session-management.html) metadata or tracking upload progress across multiple servers.

## Conclusion

You've got everything you need now to handle file uploads in Go with S3. The SDK v2 makes it surprisingly pleasant to work with, and once you get the basics down, scaling to millions of files is just a matter of tuning some knobs.

Quick recap of what matters:

Start with simple `PutObject` calls for files under 5GB - no need to overcomplicate things. When you hit larger files or want faster uploads, switch to `manager.Uploader` and let it handle multipart uploads automatically.

Presigned URLs are your best friend for user uploads. Generate them server-side, send to clients, and watch uploads happen without touching your infrastructure. Just remember to set reasonable expiration times.

Security isn't optional. Validate file types and sizes, encrypt everything with server-side encryption, keep ACLs private by default, and never hardcode AWS credentials in your code.

The code examples here aren't toys - they're production patterns I've used in real applications handling millions of files. Adapt them to your needs, add proper error handling, set up monitoring, and you're good to go.

S3 isn't just storage - it's infrastructure that scales from hobby projects to enterprise systems without you changing code. Combined with Go's speed and concurrency, you've got a solid foundation for building file-heavy applications that actually work at scale.