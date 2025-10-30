---
title: "How to Send Emails in Go - SMTP, SendGrid, and Mailgun Integration"
description: "Complete guide to sending emails in Go using SMTP, SendGrid, and Mailgun. Learn email templates, attachments, HTML emails, error handling, and production best practices for transactional emails."
date: 2025-10-06T18:00:00+07:00
draft: false
url: /2025/10/how-to-send-emails-in-go-smtp-sendgrid-mailgun.html
tags:
    - Go
    - Email
    - SMTP
    - SendGrid
    - Mailgun
    - Backend
    - Tutorial
keywords: ["go send email", "golang smtp", "sendgrid go tutorial", "mailgun golang", "email golang", "smtp server go", "transactional emails go", "html email golang", "email templates go", "go email library"]
schema: "Article"
author: "BuanaCoding"
datePublished: "2025-10-06"
dateModified: "2025-10-06"

faq:
  - question: "What is the best way to send emails in Go?"
    answer: "The best way to send emails in Go depends on your needs. For simple applications, use Go's built-in net/smtp package with your SMTP server. For production applications with high deliverability requirements, use email service APIs like SendGrid or Mailgun. They handle deliverability, bounce management, and analytics better than raw SMTP. SendGrid is easier to start with, while Mailgun offers better pricing for high volumes."

  - question: "Can you send emails using Gmail SMTP in Go?"
    answer: "Yes, you can send emails using Gmail SMTP in Go, but it's not recommended for production. Gmail has strict rate limits (500 emails per day), requires app-specific passwords, and may block your account for suspicious activity. Use Gmail SMTP only for development and testing. For production, use dedicated email service providers like SendGrid, Mailgun, or AWS SES that are designed for transactional emails."

  - question: "How do you send HTML emails with attachments in Go?"
    answer: "To send HTML emails with attachments in Go, create a multipart MIME message. Set the Content-Type to multipart/mixed for the outer message, then add a multipart/alternative section containing plain text and HTML versions. For attachments, encode files in base64 and add them as additional MIME parts with appropriate Content-Type and Content-Disposition headers. Libraries like gomail make this easier by handling MIME encoding automatically."

  - question: "What's the difference between SendGrid and Mailgun for Go applications?"
    answer: "SendGrid and Mailgun are both excellent for Go applications but have different strengths. SendGrid offers simpler pricing, better documentation, and easier setup - good for getting started quickly. Mailgun provides better deliverability features, powerful routing rules, and more cost-effective pricing at higher volumes. SendGrid has a more generous free tier (100 emails/day), while Mailgun offers 5,000 free emails for three months."

  - question: "How do you handle email sending errors in production?"
    answer: "Handle email errors in production by implementing retry logic with exponential backoff, using background job queues to avoid blocking HTTP requests, logging all failures with context for debugging, monitoring delivery rates and bounce metrics, and implementing fallback mechanisms to alternative providers if the primary service fails. Never expose API keys in error messages and always validate email addresses before attempting to send."

  - question: "Do you need to verify email addresses before sending in Go?"
    answer: "Yes, you should verify email addresses before sending. Use regex validation for basic format checking, DNS MX record lookup to verify the domain accepts emails, and consider using email verification services for critical flows. However, the only way to truly verify an email works is to send a confirmation email. Implement double opt-in for newsletter subscriptions and verify email ownership for critical operations like password resets."

  - question: "How do you send bulk emails without getting marked as spam?"
    answer: "To avoid spam filters when sending bulk emails, authenticate your domain with SPF, DKIM, and DMARC records. Use a reputable email service provider like SendGrid or Mailgun. Include unsubscribe links in every email. Avoid spam trigger words in subject lines. Send emails from a consistent sender address. Warm up new sending domains gradually. Monitor bounce rates and remove invalid addresses. Never buy email lists - only send to users who opted in."

---


Your application needs to send emails. Welcome messages after signup, password reset links, order confirmations, notification alerts. Email is still the most reliable way to reach users, but sending emails programmatically is harder than it looks.

**What is email sending in Go?** Email sending in Go refers to programmatically delivering emails from your application using either SMTP protocol directly or third-party email service APIs like SendGrid and Mailgun. Instead of manually composing and sending emails, your Go code automatically sends transactional emails triggered by user actions.

You could use SMTP directly, but deliverability is a nightmare. ISPs block mail from unknown servers. Your emails land in spam. Bounce handling becomes your problem. That's why production applications use email service providers.

This guide covers everything - from basic SMTP to production-ready SendGrid and Mailgun integration. You'll learn HTML emails, templates, attachments, error handling, and avoiding spam filters. We'll build real examples that you can deploy to production.

## Why Email Services Matter

Sending email sounds simple. Connect to an SMTP server, send message, done. Reality is different.

I once built an app that sent password resets using a basic SMTP server. Worked fine in testing. In production, 60% of emails never arrived. Gmail marked them as spam. Outlook blocked them entirely. Users complained they couldn't reset passwords.

The problem: deliverability. Major email providers don't trust random SMTP servers. Your emails need proper authentication (SPF, DKIM, DMARC), good sender reputation, and correct headers. Setting this up yourself takes weeks and ongoing maintenance.

**What email services handle for you:**

Deliverability infrastructure - Established relationships with ISPs, authenticated domains, good sender reputation.

Bounce management - Automatic handling of bounced emails, maintaining clean sender lists.

Analytics - Track opens, clicks, bounces, spam complaints.

Templates - Store and manage email templates without code deploys.

Scale - Handle millions of emails without worrying about server capacity.

Compliance - GDPR compliance, unsubscribe handling, spam regulations.

Using an email service costs money but saves time and ensures emails actually get delivered. For production applications, it's not optional.

## Understanding Email Delivery Methods

Go offers several ways to send emails, each with tradeoffs.

**Net/smtp package** - Go's standard library for SMTP. Simple for basic emails but requires managing SMTP servers, authentication, and deliverability yourself. Good for development, risky for production.

**Third-party SMTP services** - Use Gmail, Amazon SES, or other SMTP providers. Better deliverability than your own server but still SMTP limitations. You handle connection pooling, retries, and errors.

**Email service APIs** - SendGrid, Mailgun, Postmark use HTTP APIs instead of SMTP. Better error handling, richer features, detailed analytics. Most production apps use these.

**When to use each:**

Development - net/smtp with Gmail or Mailtrap for testing.

Small projects - SendGrid free tier (100 emails/day).

Production apps - SendGrid or Mailgun APIs with proper error handling.

High volume - Mailgun or AWS SES for cost efficiency.

This guide focuses on production approaches: basic SMTP for understanding, then SendGrid and Mailgun for real applications.

## Sending Email with SMTP in Go

Let's start with SMTP using Go's standard library. This teaches fundamentals even if you'll use services later.

### Basic SMTP Example

```go
package main

import (
    "fmt"
    "net/smtp"
)

func main() {
    // SMTP server configuration
    smtpHost := "smtp.gmail.com"
    smtpPort := "587"

    // Sender credentials
    from := "your-email@gmail.com"
    password := "your-app-password"

    // Recipient
    to := []string{"recipient@example.com"}

    // Message
    subject := "Test Email from Go"
    body := "This is a test email sent from Go using SMTP."
    message := []byte(fmt.Sprintf("Subject: %s\r\n\r\n%s", subject, body))

    // Authentication
    auth := smtp.PlainAuth("", from, password, smtpHost)

    // Send email
    err := smtp.SendMail(smtpHost+":"+smtpPort, auth, from, to, message)
    if err != nil {
        fmt.Println("Failed to send email:", err)
        return
    }

    fmt.Println("Email sent successfully!")
}
```

This works but has problems. The message is plain text only, no proper MIME headers, error handling is basic, and credentials are hardcoded.

### Improved SMTP with Proper Headers

```go
package main

import (
    "fmt"
    "net/smtp"
    "os"
)

type Email struct {
    From    string
    To      []string
    Subject string
    Body    string
}

func (e *Email) BuildMessage() []byte {
    message := fmt.Sprintf("From: %s\r\n", e.From)
    message += fmt.Sprintf("To: %s\r\n", e.To[0])
    message += fmt.Sprintf("Subject: %s\r\n", e.Subject)
    message += "MIME-Version: 1.0\r\n"
    message += "Content-Type: text/plain; charset=UTF-8\r\n"
    message += "\r\n"
    message += e.Body

    return []byte(message)
}

func SendEmail(email *Email) error {
    smtpHost := os.Getenv("SMTP_HOST")
    smtpPort := os.Getenv("SMTP_PORT")
    smtpUser := os.Getenv("SMTP_USER")
    smtpPass := os.Getenv("SMTP_PASS")

    if smtpHost == "" || smtpPort == "" {
        return fmt.Errorf("SMTP configuration missing")
    }

    auth := smtp.PlainAuth("", smtpUser, smtpPass, smtpHost)

    addr := smtpHost + ":" + smtpPort
    message := email.BuildMessage()

    err := smtp.SendMail(addr, auth, email.From, email.To, message)
    if err != nil {
        return fmt.Errorf("failed to send email: %w", err)
    }

    return nil
}

func main() {
    email := &Email{
        From:    "sender@example.com",
        To:      []string{"recipient@example.com"},
        Subject: "Welcome to Our Service",
        Body:    "Thank you for signing up! We're excited to have you.",
    }

    if err := SendEmail(email); err != nil {
        fmt.Println("Error:", err)
        os.Exit(1)
    }

    fmt.Println("Email sent successfully!")
}
```

Better. We added proper headers, environment variables for configuration, and error wrapping. But this is still plain text emails.

### Sending HTML Emails with SMTP

```go
package main

import (
    "fmt"
    "net/smtp"
    "os"
)

type HTMLEmail struct {
    From    string
    To      []string
    Subject string
    Body    string // HTML content
}

func (e *HTMLEmail) BuildMessage() []byte {
    headers := make(map[string]string)
    headers["From"] = e.From
    headers["To"] = e.To[0]
    headers["Subject"] = e.Subject
    headers["MIME-Version"] = "1.0"
    headers["Content-Type"] = "text/html; charset=UTF-8"

    message := ""
    for k, v := range headers {
        message += fmt.Sprintf("%s: %s\r\n", k, v)
    }
    message += "\r\n" + e.Body

    return []byte(message)
}

func SendHTMLEmail(email *HTMLEmail) error {
    smtpHost := os.Getenv("SMTP_HOST")
    smtpPort := os.Getenv("SMTP_PORT")
    smtpUser := os.Getenv("SMTP_USER")
    smtpPass := os.Getenv("SMTP_PASS")

    auth := smtp.PlainAuth("", smtpUser, smtpPass, smtpHost)

    addr := smtpHost + ":" + smtpPort
    message := email.BuildMessage()

    return smtp.SendMail(addr, auth, email.From, email.To, message)
}

func main() {
    htmlBody := `
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background-color: #f9f9f9; }
        .button { background-color: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; display: inline-block; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Welcome to Our Service!</h1>
        </div>
        <div class="content">
            <p>Hi there,</p>
            <p>Thank you for signing up. We're excited to have you on board!</p>
            <p>Click the button below to get started:</p>
            <a href="https://example.com/get-started" class="button">Get Started</a>
            <p>Best regards,<br>The Team</p>
        </div>
    </div>
</body>
</html>
    `

    email := &HTMLEmail{
        From:    "noreply@example.com",
        To:      []string{"user@example.com"},
        Subject: "Welcome to Our Service",
        Body:    htmlBody,
    }

    if err := SendHTMLEmail(email); err != nil {
        fmt.Println("Error:", err)
        os.Exit(1)
    }

    fmt.Println("HTML email sent successfully!")
}
```

Now we're sending styled HTML emails. But there's a problem - what if the recipient's email client doesn't support HTML? We should send both plain text and HTML.

### Multipart Emails (Plain Text + HTML)

```go
package main

import (
    "bytes"
    "fmt"
    "mime/multipart"
    "net/smtp"
    "net/textproto"
    "os"
)

type MultipartEmail struct {
    From        string
    To          []string
    Subject     string
    TextBody    string
    HTMLBody    string
}

func (e *MultipartEmail) BuildMessage() ([]byte, error) {
    buf := bytes.NewBuffer(nil)

    // Write headers
    fmt.Fprintf(buf, "From: %s\r\n", e.From)
    fmt.Fprintf(buf, "To: %s\r\n", e.To[0])
    fmt.Fprintf(buf, "Subject: %s\r\n", e.Subject)
    fmt.Fprintf(buf, "MIME-Version: 1.0\r\n")

    // Create multipart writer
    writer := multipart.NewWriter(buf)
    boundary := writer.Boundary()

    fmt.Fprintf(buf, "Content-Type: multipart/alternative; boundary=%s\r\n", boundary)
    fmt.Fprintf(buf, "\r\n")

    // Plain text part
    textHeader := textproto.MIMEHeader{}
    textHeader.Set("Content-Type", "text/plain; charset=UTF-8")
    textHeader.Set("Content-Transfer-Encoding", "quoted-printable")

    textPart, err := writer.CreatePart(textHeader)
    if err != nil {
        return nil, err
    }
    textPart.Write([]byte(e.TextBody))

    // HTML part
    htmlHeader := textproto.MIMEHeader{}
    htmlHeader.Set("Content-Type", "text/html; charset=UTF-8")
    htmlHeader.Set("Content-Transfer-Encoding", "quoted-printable")

    htmlPart, err := writer.CreatePart(htmlHeader)
    if err != nil {
        return nil, err
    }
    htmlPart.Write([]byte(e.HTMLBody))

    writer.Close()

    return buf.Bytes(), nil
}

func SendMultipartEmail(email *MultipartEmail) error {
    smtpHost := os.Getenv("SMTP_HOST")
    smtpPort := os.Getenv("SMTP_PORT")
    smtpUser := os.Getenv("SMTP_USER")
    smtpPass := os.Getenv("SMTP_PASS")

    auth := smtp.PlainAuth("", smtpUser, smtpPass, smtpHost)

    message, err := email.BuildMessage()
    if err != nil {
        return fmt.Errorf("failed to build message: %w", err)
    }

    addr := smtpHost + ":" + smtpPort
    return smtp.SendMail(addr, auth, email.From, email.To, message)
}

func main() {
    email := &MultipartEmail{
        From:     "noreply@example.com",
        To:       []string{"user@example.com"},
        Subject:  "Welcome to Our Service",
        TextBody: "Hi there,\n\nThank you for signing up!\n\nBest regards,\nThe Team",
        HTMLBody: `<html><body><h1>Welcome!</h1><p>Thank you for signing up!</p></body></html>`,
    }

    if err := SendMultipartEmail(email); err != nil {
        fmt.Println("Error:", err)
        os.Exit(1)
    }

    fmt.Println("Multipart email sent!")
}
```

This sends both plain text and HTML. Email clients show HTML if supported, otherwise fall back to plain text.

SMTP works, but building MIME messages manually is tedious. Let's look at libraries that make this easier.

## Using Gomail Library for SMTP

Gomail is a popular Go library that simplifies email sending. It handles MIME encoding, attachments, and embedded images.

### Installing Gomail

```bash
go get gopkg.in/gomail.v2
```

### Basic Email with Gomail

```go
package main

import (
    "fmt"
    "os"
    "strconv"

    "gopkg.in/gomail.v2"
)

func main() {
    m := gomail.NewMessage()

    // Set headers
    m.SetHeader("From", "sender@example.com")
    m.SetHeader("To", "recipient@example.com")
    m.SetHeader("Subject", "Hello from Gomail")

    // Set body
    m.SetBody("text/html", "<h1>Hello!</h1><p>This is an HTML email.</p>")

    // Alternative plain text
    m.AddAlternative("text/plain", "Hello! This is a plain text fallback.")

    // SMTP configuration
    port, _ := strconv.Atoi(os.Getenv("SMTP_PORT"))
    d := gomail.NewDialer(
        os.Getenv("SMTP_HOST"),
        port,
        os.Getenv("SMTP_USER"),
        os.Getenv("SMTP_PASS"),
    )

    // Send email
    if err := d.DialAndSend(m); err != nil {
        fmt.Println("Failed to send email:", err)
        return
    }

    fmt.Println("Email sent successfully!")
}
```

Much cleaner than manual MIME construction. Gomail handles all the encoding automatically.

### Sending Email with Attachments

```go
package main

import (
    "fmt"
    "os"
    "strconv"

    "gopkg.in/gomail.v2"
)

func SendEmailWithAttachment(to, subject, body, attachmentPath string) error {
    m := gomail.NewMessage()

    m.SetHeader("From", os.Getenv("SMTP_USER"))
    m.SetHeader("To", to)
    m.SetHeader("Subject", subject)
    m.SetBody("text/html", body)

    // Attach file
    m.Attach(attachmentPath)

    port, _ := strconv.Atoi(os.Getenv("SMTP_PORT"))
    d := gomail.NewDialer(
        os.Getenv("SMTP_HOST"),
        port,
        os.Getenv("SMTP_USER"),
        os.Getenv("SMTP_PASS"),
    )

    return d.DialAndSend(m)
}

func main() {
    htmlBody := `
    <html>
    <body>
        <h2>Invoice Attached</h2>
        <p>Please find your invoice attached to this email.</p>
        <p>Thank you for your business!</p>
    </body>
    </html>
    `

    err := SendEmailWithAttachment(
        "customer@example.com",
        "Your Invoice",
        htmlBody,
        "./invoice.pdf",
    )

    if err != nil {
        fmt.Println("Error:", err)
        os.Exit(1)
    }

    fmt.Println("Email with attachment sent!")
}
```

Gomail makes attachments trivial. Just call `Attach()` with the file path.

### Embedded Images in HTML

```go
package main

import (
    "fmt"
    "os"
    "strconv"

    "gopkg.in/gomail.v2"
)

func SendEmailWithEmbeddedImage() error {
    m := gomail.NewMessage()

    m.SetHeader("From", "noreply@example.com")
    m.SetHeader("To", "user@example.com")
    m.SetHeader("Subject", "Newsletter with Logo")

    // HTML body referencing embedded image
    htmlBody := `
    <html>
    <body>
        <img src="cid:company-logo" alt="Company Logo" width="200">
        <h1>Monthly Newsletter</h1>
        <p>Here's what's new this month...</p>
    </body>
    </html>
    `

    m.SetBody("text/html", htmlBody)

    // Embed image with Content-ID
    m.Embed("./logo.png", gomail.Rename("company-logo"))

    port, _ := strconv.Atoi(os.Getenv("SMTP_PORT"))
    d := gomail.NewDialer(
        os.Getenv("SMTP_HOST"),
        port,
        os.Getenv("SMTP_USER"),
        os.Getenv("SMTP_PASS"),
    )

    return d.DialAndSend(m)
}

func main() {
    if err := SendEmailWithEmbeddedImage(); err != nil {
        fmt.Println("Error:", err)
        os.Exit(1)
    }

    fmt.Println("Email with embedded image sent!")
}
```

The `cid:` reference in HTML links to the embedded image. Email clients display it inline.

Gomail is great for SMTP, but for production we want better deliverability. Let's move to SendGrid.

## Sending Emails with SendGrid

SendGrid is one of the most popular email services. It has excellent deliverability, generous free tier (100 emails/day), and simple API.

### Setting Up SendGrid

1. Sign up at [sendgrid.com](https://sendgrid.com)
2. Verify your sender email or domain
3. Create an API key in Settings > API Keys
4. Install the Go SDK:

```bash
go get github.com/sendgrid/sendgrid-go
```

### Basic SendGrid Email

```go
package main

import (
    "fmt"
    "log"
    "os"

    "github.com/sendgrid/sendgrid-go"
    "github.com/sendgrid/sendgrid-go/helpers/mail"
)

func main() {
    from := mail.NewEmail("Your App", "noreply@yourdomain.com")
    to := mail.NewEmail("User Name", "user@example.com")
    subject := "Welcome to Our Service"

    plainTextContent := "Thank you for signing up!"
    htmlContent := "<strong>Thank you for signing up!</strong>"

    message := mail.NewSingleEmail(from, subject, to, plainTextContent, htmlContent)

    client := sendgrid.NewSendClient(os.Getenv("SENDGRID_API_KEY"))
    response, err := client.Send(message)

    if err != nil {
        log.Println("Error sending email:", err)
        return
    }

    fmt.Printf("Email sent! Status: %d\n", response.StatusCode)
    fmt.Println("Response Body:", response.Body)
}
```

SendGrid returns HTTP status codes. 202 means accepted for delivery.

### SendGrid Email Service Package

Create a reusable email service:

```go
// internal/email/sendgrid.go
package email

import (
    "fmt"

    "github.com/sendgrid/sendgrid-go"
    "github.com/sendgrid/sendgrid-go/helpers/mail"
)

type SendGridService struct {
    apiKey     string
    fromEmail  string
    fromName   string
}

func NewSendGridService(apiKey, fromEmail, fromName string) *SendGridService {
    return &SendGridService{
        apiKey:    apiKey,
        fromEmail: fromEmail,
        fromName:  fromName,
    }
}

func (s *SendGridService) SendWelcomeEmail(toEmail, toName string) error {
    from := mail.NewEmail(s.fromName, s.fromEmail)
    to := mail.NewEmail(toName, toEmail)
    subject := "Welcome to Our Platform"

    plainText := fmt.Sprintf("Hi %s,\n\nWelcome to our platform!\n\nBest regards,\nThe Team", toName)

    html := fmt.Sprintf(`
    <html>
    <body>
        <h1>Welcome, %s!</h1>
        <p>Thank you for joining our platform.</p>
        <p>We're excited to have you on board.</p>
        <a href="https://yourapp.com/get-started" style="background-color: #4CAF50; color: white; padding: 10px 20px; text-decoration: none;">Get Started</a>
    </body>
    </html>
    `, toName)

    message := mail.NewSingleEmail(from, subject, to, plainText, html)

    client := sendgrid.NewSendClient(s.apiKey)
    response, err := client.Send(message)

    if err != nil {
        return fmt.Errorf("sendgrid error: %w", err)
    }

    if response.StatusCode >= 400 {
        return fmt.Errorf("sendgrid returned status %d: %s", response.StatusCode, response.Body)
    }

    return nil
}

func (s *SendGridService) SendPasswordReset(toEmail, resetToken string) error {
    from := mail.NewEmail(s.fromName, s.fromEmail)
    to := mail.NewEmail("", toEmail)
    subject := "Password Reset Request"

    resetURL := fmt.Sprintf("https://yourapp.com/reset-password?token=%s", resetToken)

    plainText := fmt.Sprintf("Click this link to reset your password: %s\n\nIf you didn't request this, ignore this email.", resetURL)

    html := fmt.Sprintf(`
    <html>
    <body>
        <h2>Password Reset Request</h2>
        <p>We received a request to reset your password.</p>
        <p>Click the button below to reset your password:</p>
        <a href="%s" style="background-color: #007bff; color: white; padding: 12px 24px; text-decoration: none; display: inline-block;">Reset Password</a>
        <p>If you didn't request this, you can safely ignore this email.</p>
        <p>This link expires in 1 hour.</p>
    </body>
    </html>
    `, resetURL)

    message := mail.NewSingleEmail(from, subject, to, plainText, html)

    client := sendgrid.NewSendClient(s.apiKey)
    response, err := client.Send(message)

    if err != nil {
        return fmt.Errorf("sendgrid error: %w", err)
    }

    if response.StatusCode >= 400 {
        return fmt.Errorf("sendgrid returned status %d: %s", response.StatusCode, response.Body)
    }

    return nil
}
```

Usage in your application:

```go
package main

import (
    "fmt"
    "log"
    "os"

    "yourapp/internal/email"
)

func main() {
    emailService := email.NewSendGridService(
        os.Getenv("SENDGRID_API_KEY"),
        "noreply@yourdomain.com",
        "Your App Name",
    )

    // Send welcome email
    err := emailService.SendWelcomeEmail("user@example.com", "John Doe")
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println("Welcome email sent!")

    // Send password reset
    err = emailService.SendPasswordReset("user@example.com", "reset-token-123")
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println("Password reset email sent!")
}
```

### SendGrid with Templates

SendGrid has a powerful template system. Create templates in the SendGrid dashboard, then reference them in code:

```go
package email

import (
    "fmt"

    "github.com/sendgrid/sendgrid-go"
    "github.com/sendgrid/sendgrid-go/helpers/mail"
)

func (s *SendGridService) SendTemplatedEmail(toEmail, toName, templateID string, data map[string]interface{}) error {
    from := mail.NewEmail(s.fromName, s.fromEmail)
    to := mail.NewEmail(toName, toEmail)

    message := mail.NewV3Mail()
    message.SetFrom(from)
    message.SetTemplateID(templateID)

    personalization := mail.NewPersonalization()
    personalization.AddTos(to)

    // Add dynamic template data
    for key, value := range data {
        personalization.SetDynamicTemplateData(key, value)
    }

    message.AddPersonalizations(personalization)

    client := sendgrid.NewSendClient(s.apiKey)
    response, err := client.Send(message)

    if err != nil {
        return fmt.Errorf("sendgrid error: %w", err)
    }

    if response.StatusCode >= 400 {
        return fmt.Errorf("sendgrid returned status %d: %s", response.StatusCode, response.Body)
    }

    return nil
}
```

Usage:

```go
// Send using template
templateData := map[string]interface{}{
    "user_name": "John Doe",
    "order_id": "12345",
    "total_amount": "$99.99",
}

err := emailService.SendTemplatedEmail(
    "user@example.com",
    "John Doe",
    "d-template-id-here", // Get from SendGrid dashboard
    templateData,
)
```

Templates separate email design from code. Marketers can update emails without developer involvement.

### SendGrid with Attachments

```go
package email

import (
    "encoding/base64"
    "fmt"
    "os"

    "github.com/sendgrid/sendgrid-go"
    "github.com/sendgrid/sendgrid-go/helpers/mail"
)

func (s *SendGridService) SendEmailWithAttachment(toEmail, subject, body, filePath string) error {
    from := mail.NewEmail(s.fromName, s.fromEmail)
    to := mail.NewEmail("", toEmail)

    message := mail.NewSingleEmail(from, subject, to, body, body)

    // Read file
    fileData, err := os.ReadFile(filePath)
    if err != nil {
        return fmt.Errorf("failed to read file: %w", err)
    }

    // Encode to base64
    encoded := base64.StdEncoding.EncodeToString(fileData)

    // Create attachment
    attachment := mail.NewAttachment()
    attachment.SetContent(encoded)
    attachment.SetType("application/pdf")
    attachment.SetFilename("invoice.pdf")
    attachment.SetDisposition("attachment")

    message.AddAttachment(attachment)

    client := sendgrid.NewSendClient(s.apiKey)
    response, err := client.Send(message)

    if err != nil {
        return fmt.Errorf("sendgrid error: %w", err)
    }

    if response.StatusCode >= 400 {
        return fmt.Errorf("sendgrid returned status %d", response.StatusCode)
    }

    return nil
}
```

SendGrid handles attachments well, but watch file sizes. Keep attachments under 10MB for best deliverability.

## Sending Emails with Mailgun

Mailgun is another excellent email service. It's particularly strong for high-volume sending and has powerful routing features.

### Setting Up Mailgun

1. Sign up at [mailgun.com](https://mailgun.com)
2. Add and verify your domain
3. Get your API key from Settings
4. Install the Go SDK:

```bash
go get github.com/mailgun/mailgun-go/v4
```

### Basic Mailgun Email

```go
package main

import (
    "context"
    "fmt"
    "log"
    "os"
    "time"

    "github.com/mailgun/mailgun-go/v4"
)

func main() {
    mg := mailgun.NewMailgun(
        os.Getenv("MAILGUN_DOMAIN"),
        os.Getenv("MAILGUN_API_KEY"),
    )

    sender := "noreply@yourdomain.com"
    subject := "Welcome to Our Service"
    body := "Thank you for signing up!"
    recipient := "user@example.com"

    message := mg.NewMessage(sender, subject, body, recipient)

    ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
    defer cancel()

    resp, id, err := mg.Send(ctx, message)

    if err != nil {
        log.Fatal(err)
    }

    fmt.Printf("ID: %s Resp: %s\n", id, resp)
}
```

Mailgun returns a message ID you can use for tracking.

### Mailgun Email Service Package

```go
// internal/email/mailgun.go
package email

import (
    "context"
    "fmt"
    "time"

    "github.com/mailgun/mailgun-go/v4"
)

type MailgunService struct {
    mg       *mailgun.MailgunImpl
    domain   string
    fromEmail string
    fromName  string
}

func NewMailgunService(domain, apiKey, fromEmail, fromName string) *MailgunService {
    mg := mailgun.NewMailgun(domain, apiKey)

    return &MailgunService{
        mg:        mg,
        domain:    domain,
        fromEmail: fromEmail,
        fromName:  fromName,
    }
}

func (s *MailgunService) SendWelcomeEmail(toEmail, toName string) error {
    sender := fmt.Sprintf("%s <%s>", s.fromName, s.fromEmail)
    subject := "Welcome to Our Platform"

    text := fmt.Sprintf("Hi %s,\n\nWelcome to our platform!\n\nBest regards,\nThe Team", toName)

    html := fmt.Sprintf(`
    <html>
    <body>
        <h1>Welcome, %s!</h1>
        <p>Thank you for joining our platform.</p>
        <a href="https://yourapp.com/get-started">Get Started</a>
    </body>
    </html>
    `, toName)

    message := s.mg.NewMessage(sender, subject, text, toEmail)
    message.SetHtml(html)

    ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
    defer cancel()

    _, _, err := s.mg.Send(ctx, message)
    if err != nil {
        return fmt.Errorf("mailgun error: %w", err)
    }

    return nil
}

func (s *MailgunService) SendPasswordReset(toEmail, resetToken string) error {
    sender := fmt.Sprintf("%s <%s>", s.fromName, s.fromEmail)
    subject := "Password Reset Request"

    resetURL := fmt.Sprintf("https://yourapp.com/reset-password?token=%s", resetToken)

    text := fmt.Sprintf("Click this link to reset your password: %s", resetURL)

    html := fmt.Sprintf(`
    <html>
    <body>
        <h2>Password Reset Request</h2>
        <p>Click the link below to reset your password:</p>
        <a href="%s">Reset Password</a>
        <p>This link expires in 1 hour.</p>
    </body>
    </html>
    `, resetURL)

    message := s.mg.NewMessage(sender, subject, text, toEmail)
    message.SetHtml(html)

    ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
    defer cancel()

    _, _, err := s.mg.Send(ctx, message)
    if err != nil {
        return fmt.Errorf("mailgun error: %w", err)
    }

    return nil
}
```

### Mailgun with Tags and Tracking

Mailgun lets you tag emails for analytics and add custom variables:

```go
func (s *MailgunService) SendEmailWithTracking(toEmail, subject, body string, tags []string) error {
    sender := fmt.Sprintf("%s <%s>", s.fromName, s.fromEmail)

    message := s.mg.NewMessage(sender, subject, body, toEmail)

    // Add tags for tracking
    for _, tag := range tags {
        message.AddTag(tag)
    }

    // Add custom variables
    message.AddVariable("campaign_id", "summer-2025")
    message.AddVariable("user_type", "premium")

    // Enable click and open tracking
    message.SetTracking(true)
    message.SetTrackingClicks(true)
    message.SetTrackingOpens(true)

    ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
    defer cancel()

    _, _, err := s.mg.Send(ctx, message)
    return err
}
```

Tags help organize emails in Mailgun analytics. Custom variables let you store metadata with each email.

### Mailgun Scheduled Sending

Schedule emails for future delivery:

```go
func (s *MailgunService) SendScheduledEmail(toEmail, subject, body string, deliveryTime time.Time) error {
    sender := fmt.Sprintf("%s <%s>", s.fromName, s.fromEmail)

    message := s.mg.NewMessage(sender, subject, body, toEmail)
    message.SetDeliveryTime(deliveryTime)

    ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
    defer cancel()

    _, id, err := s.mg.Send(ctx, message)
    if err != nil {
        return fmt.Errorf("mailgun error: %w", err)
    }

    fmt.Printf("Scheduled email ID: %s\n", id)
    return nil
}
```

Usage:

```go
// Send email in 24 hours
deliveryTime := time.Now().Add(24 * time.Hour)
emailService.SendScheduledEmail(
    "user@example.com",
    "Don't forget!",
    "Your trial ends tomorrow.",
    deliveryTime,
)
```

Mailgun queues the email and sends it at the specified time.

## Email Templates in Go

Hardcoding HTML in strings is messy. Use Go's `html/template` package for maintainable email templates.

### Creating Email Templates

Create `templates/welcome.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        .container { max-width: 600px; margin: 0 auto; }
        .header { background-color: #4CAF50; color: white; padding: 20px; }
        .content { padding: 20px; }
        .button {
            background-color: #4CAF50;
            color: white;
            padding: 10px 20px;
            text-decoration: none;
            display: inline-block;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Welcome, {{.Name}}!</h1>
        </div>
        <div class="content">
            <p>Thank you for signing up for {{.AppName}}.</p>
            <p>Your account is ready to use.</p>
            <a href="{{.GetStartedURL}}" class="button">Get Started</a>
            <p>Best regards,<br>The {{.AppName}} Team</p>
        </div>
    </div>
</body>
</html>
```

Template service:

```go
// internal/email/templates.go
package email

import (
    "bytes"
    "fmt"
    "html/template"
    "path/filepath"
)

type EmailTemplate struct {
    templatesDir string
}

func NewEmailTemplate(templatesDir string) *EmailTemplate {
    return &EmailTemplate{
        templatesDir: templatesDir,
    }
}

func (et *EmailTemplate) Render(templateName string, data interface{}) (string, error) {
    templatePath := filepath.Join(et.templatesDir, templateName)

    tmpl, err := template.ParseFiles(templatePath)
    if err != nil {
        return "", fmt.Errorf("failed to parse template: %w", err)
    }

    var buf bytes.Buffer
    if err := tmpl.Execute(&buf, data); err != nil {
        return "", fmt.Errorf("failed to execute template: %w", err)
    }

    return buf.String(), nil
}
```

Usage:

```go
package main

import (
    "fmt"
    "log"

    "yourapp/internal/email"
)

func main() {
    templateService := email.NewEmailTemplate("./templates")

    data := map[string]interface{}{
        "Name":          "John Doe",
        "AppName":       "YourApp",
        "GetStartedURL": "https://yourapp.com/dashboard",
    }

    html, err := templateService.Render("welcome.html", data)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println(html)

    // Now send this HTML via SendGrid or Mailgun
}
```

Templates make emails easier to maintain. Designers can edit HTML without touching Go code.

### Template with Partials

For shared components like headers and footers:

```html
<!-- templates/partials/header.html -->
<div class="header" style="background-color: #4CAF50; color: white; padding: 20px;">
    <h1>{{.AppName}}</h1>
</div>

<!-- templates/partials/footer.html -->
<div class="footer" style="padding: 20px; text-align: center; color: #666;">
    <p>&copy; 2025 {{.AppName}}. All rights reserved.</p>
    <p><a href="{{.UnsubscribeURL}}">Unsubscribe</a></p>
</div>

<!-- templates/newsletter.html -->
<!DOCTYPE html>
<html>
<body>
    {{template "header" .}}

    <div class="content">
        <h2>{{.Subject}}</h2>
        <p>{{.Message}}</p>
    </div>

    {{template "footer" .}}
</body>
</html>
```

Parse multiple templates:

```go
func (et *EmailTemplate) RenderWithPartials(templateName string, data interface{}) (string, error) {
    templatePath := filepath.Join(et.templatesDir, templateName)
    headerPath := filepath.Join(et.templatesDir, "partials", "header.html")
    footerPath := filepath.Join(et.templatesDir, "partials", "footer.html")

    tmpl, err := template.ParseFiles(templatePath, headerPath, footerPath)
    if err != nil {
        return "", err
    }

    var buf bytes.Buffer
    if err := tmpl.Execute(&buf, data); err != nil {
        return "", err
    }

    return buf.String(), nil
}
```

Partials let you reuse email components across multiple templates.

## Error Handling and Retries

Email sending can fail. Networks timeout, APIs have outages, rate limits trigger. Production apps need robust error handling.

### Retry Logic

```go
package email

import (
    "fmt"
    "time"
)

type RetryConfig struct {
    MaxAttempts int
    InitialDelay time.Duration
    MaxDelay     time.Duration
    Multiplier   float64
}

func DefaultRetryConfig() *RetryConfig {
    return &RetryConfig{
        MaxAttempts:  3,
        InitialDelay: time.Second,
        MaxDelay:     time.Second * 30,
        Multiplier:   2.0,
    }
}

func (s *SendGridService) SendWithRetry(toEmail, subject, body string, config *RetryConfig) error {
    var lastErr error
    delay := config.InitialDelay

    for attempt := 1; attempt <= config.MaxAttempts; attempt++ {
        err := s.sendEmail(toEmail, subject, body)
        if err == nil {
            return nil
        }

        lastErr = err

        if attempt < config.MaxAttempts {
            time.Sleep(delay)

            // Exponential backoff
            delay = time.Duration(float64(delay) * config.Multiplier)
            if delay > config.MaxDelay {
                delay = config.MaxDelay
            }
        }
    }

    return fmt.Errorf("failed after %d attempts: %w", config.MaxAttempts, lastErr)
}

func (s *SendGridService) sendEmail(toEmail, subject, body string) error {
    // Your SendGrid send logic here
    return nil
}
```

This implements exponential backoff. First retry waits 1 second, second waits 2 seconds, third waits 4 seconds.

### Circuit Breaker Pattern

Prevent cascading failures when email service is down:

```go
package email

import (
    "fmt"
    "sync"
    "time"
)

type CircuitBreaker struct {
    maxFailures int
    timeout     time.Duration

    failures    int
    lastFailure time.Time
    state       string // "closed", "open", "half-open"
    mu          sync.Mutex
}

func NewCircuitBreaker(maxFailures int, timeout time.Duration) *CircuitBreaker {
    return &CircuitBreaker{
        maxFailures: maxFailures,
        timeout:     timeout,
        state:       "closed",
    }
}

func (cb *CircuitBreaker) Call(fn func() error) error {
    cb.mu.Lock()

    if cb.state == "open" {
        if time.Since(cb.lastFailure) > cb.timeout {
            cb.state = "half-open"
            cb.failures = 0
        } else {
            cb.mu.Unlock()
            return fmt.Errorf("circuit breaker is open")
        }
    }

    cb.mu.Unlock()

    err := fn()

    cb.mu.Lock()
    defer cb.mu.Unlock()

    if err != nil {
        cb.failures++
        cb.lastFailure = time.Now()

        if cb.failures >= cb.maxFailures {
            cb.state = "open"
        }

        return err
    }

    if cb.state == "half-open" {
        cb.state = "closed"
    }
    cb.failures = 0

    return nil
}
```

Usage:

```go
breaker := email.NewCircuitBreaker(5, time.Minute*5)

err := breaker.Call(func() error {
    return emailService.SendWelcomeEmail("user@example.com", "John")
})

if err != nil {
    log.Println("Email failed:", err)
}
```

After 5 failures, circuit opens for 5 minutes. This prevents hammering a failed service.

## Email Queue with Background Jobs

Don't send emails in HTTP handlers. Use background jobs for better performance and reliability.

Integration with Asynq (from previous article):

```go
// internal/tasks/email.go
package tasks

import (
    "context"
    "encoding/json"
    "fmt"

    "github.com/hibiken/asynq"
    "yourapp/internal/email"
)

const (
    TypeEmailWelcome       = "email:welcome"
    TypeEmailPasswordReset = "email:password_reset"
)

type EmailWelcomePayload struct {
    Email string `json:"email"`
    Name  string `json:"name"`
}

func NewEmailWelcomeTask(email, name string) (*asynq.Task, error) {
    payload, err := json.Marshal(EmailWelcomePayload{
        Email: email,
        Name:  name,
    })
    if err != nil {
        return nil, err
    }

    return asynq.NewTask(TypeEmailWelcome, payload), nil
}

func HandleEmailWelcomeTask(ctx context.Context, t *asynq.Task) error {
    var p EmailWelcomePayload
    if err := json.Unmarshal(t.Payload(), &p); err != nil {
        return err
    }

    emailService := email.NewSendGridService(
        os.Getenv("SENDGRID_API_KEY"),
        "noreply@yourdomain.com",
        "Your App",
    )

    return emailService.SendWelcomeEmail(p.Email, p.Name)
}
```

In your HTTP handler:

```go
func signupHandler(w http.ResponseWriter, r *http.Request) {
    email := r.FormValue("email")
    name := r.FormValue("name")

    // Create user in database
    user := createUser(email, name)

    // Queue welcome email
    task, _ := tasks.NewEmailWelcomeTask(user.Email, user.Name)
    queueClient.Enqueue(task, asynq.Queue("emails"))

    // Return immediately
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(map[string]string{
        "message": "Account created! Check your email.",
    })
}
```

User gets instant response. Email sends in background. If email fails, Asynq retries automatically.

For more on background jobs, see our guide on [implementing background jobs with Asynq](/2025/10/how-to-implement-background-jobs-in-go-with-asynq-and-redis.html).

## Avoiding Spam Filters

Even with email services, emails can land in spam. Here's how to avoid it.

### Domain Authentication

Set up SPF, DKIM, and DMARC records:

**SPF Record** (DNS TXT):
```
v=spf1 include:sendgrid.net ~all
```

**DKIM** - SendGrid/Mailgun provide keys to add to DNS.

**DMARC Record**:
```
v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com
```

These prove your emails come from authorized servers.

### Email Content Best Practices

Spam filters analyze content. Follow these rules:

**Subject lines:**
- Avoid ALL CAPS
- Don't use excessive punctuation (!!!)
- Skip spam words: "FREE", "WINNER", "CLICK HERE"
- Keep under 50 characters

**Body content:**
- Include unsubscribe link
- Use real sender name and address
- Balance text and images
- Avoid URL shorteners
- Include physical address (legal requirement)

**HTML:**
- Keep HTML simple
- Avoid JavaScript
- Use inline CSS
- Test in multiple clients
- Include plain text version

### Sender Reputation

ISPs track your sending patterns:

**Warm up new domains** - Start with low volumes (100/day), gradually increase over weeks.

**Monitor bounce rates** - Keep under 2%. Remove invalid addresses quickly.

**Watch spam complaints** - Under 0.1% is good. Over 0.5% is bad.

**Consistent sending** - Don't go from 0 to 10,000 emails overnight.

**Engagement matters** - High open rates improve reputation. Low engagement hurts it.

## Comparison: SMTP vs SendGrid vs Mailgun

Here's how the three approaches compare:

| Feature | Raw SMTP | SendGrid | Mailgun |
|---------|----------|----------|---------|
| **Setup Complexity** | High | Low | Low |
| **Deliverability** | Poor (self-managed) | Excellent | Excellent |
| **Cost** | Free (own server) | Free tier: 100/day | Free trial: 5k/month |
| **Pricing (1M emails)** | Infrastructure costs | $14.95/month | $35/month |
| **Analytics** | None | Detailed | Detailed |
| **Templates** | Manual | Built-in | API-based |
| **Bounce Handling** | Manual | Automatic | Automatic |
| **API Quality** | SMTP only | Excellent REST API | Excellent REST API |
| **Webhooks** | No | Yes | Yes |
| **Learning Curve** | Low | Low | Medium |
| **Best For** | Testing | Getting started fast | High volume |

**When to use each:**

**SMTP** - Local development and testing only. Use Mailtrap.io or Gmail for dev environments.

**SendGrid** - Best for:
- Small to medium volume
- Quick setup needed
- Want simple pricing
- Need excellent documentation

**Mailgun** - Best for:
- High volume sending
- Need advanced routing
- Want better pricing at scale
- Prefer more control

For most Go applications, start with SendGrid. Switch to Mailgun when you exceed SendGrid's pricing sweet spot.

## Production Best Practices

### Environment Configuration

```go
// internal/config/email.go
package config

import (
    "fmt"
    "os"
)

type EmailConfig struct {
    Provider    string // "sendgrid" or "mailgun"
    APIKey      string
    Domain      string // For Mailgun
    FromEmail   string
    FromName    string
    ReplyTo     string
}

func LoadEmailConfig() (*EmailConfig, error) {
    provider := os.Getenv("EMAIL_PROVIDER")
    if provider == "" {
        return nil, fmt.Errorf("EMAIL_PROVIDER not set")
    }

    config := &EmailConfig{
        Provider:  provider,
        FromEmail: os.Getenv("EMAIL_FROM"),
        FromName:  os.Getenv("EMAIL_FROM_NAME"),
        ReplyTo:   os.Getenv("EMAIL_REPLY_TO"),
    }

    switch provider {
    case "sendgrid":
        config.APIKey = os.Getenv("SENDGRID_API_KEY")
        if config.APIKey == "" {
            return nil, fmt.Errorf("SENDGRID_API_KEY not set")
        }
    case "mailgun":
        config.APIKey = os.Getenv("MAILGUN_API_KEY")
        config.Domain = os.Getenv("MAILGUN_DOMAIN")
        if config.APIKey == "" || config.Domain == "" {
            return nil, fmt.Errorf("MAILGUN_API_KEY or MAILGUN_DOMAIN not set")
        }
    default:
        return nil, fmt.Errorf("unknown email provider: %s", provider)
    }

    return config, nil
}
```

Environment variables (`.env`):

```bash
EMAIL_PROVIDER=sendgrid
SENDGRID_API_KEY=your-api-key
EMAIL_FROM=noreply@yourdomain.com
EMAIL_FROM_NAME=Your App Name
EMAIL_REPLY_TO=support@yourdomain.com
```

### Email Interface for Flexibility

Abstract email sending behind an interface:

```go
// internal/email/interface.go
package email

type EmailSender interface {
    SendWelcomeEmail(toEmail, toName string) error
    SendPasswordReset(toEmail, resetToken string) error
    SendVerificationEmail(toEmail, verificationToken string) error
}

func NewEmailSender(provider, apiKey, domain, fromEmail, fromName string) (EmailSender, error) {
    switch provider {
    case "sendgrid":
        return NewSendGridService(apiKey, fromEmail, fromName), nil
    case "mailgun":
        return NewMailgunService(domain, apiKey, fromEmail, fromName), nil
    default:
        return nil, fmt.Errorf("unknown provider: %s", provider)
    }
}
```

Your application code depends on the interface, not specific implementations. Switching providers is configuration change, not code change.

### Logging and Monitoring

```go
package email

import (
    "fmt"
    "log"
    "time"
)

type LoggingEmailService struct {
    underlying EmailSender
}

func NewLoggingEmailService(underlying EmailSender) *LoggingEmailService {
    return &LoggingEmailService{underlying: underlying}
}

func (l *LoggingEmailService) SendWelcomeEmail(toEmail, toName string) error {
    start := time.Now()

    log.Printf("Sending welcome email to %s (%s)", toName, toEmail)

    err := l.underlying.SendWelcomeEmail(toEmail, toName)

    duration := time.Since(start)

    if err != nil {
        log.Printf("Failed to send welcome email to %s: %v (took %v)", toEmail, err, duration)
        return err
    }

    log.Printf("Successfully sent welcome email to %s (took %v)", toEmail, duration)
    return nil
}
```

Wrap your email service with logging. Track successes, failures, and latency.

For production monitoring, integrate with your observability stack. Send metrics to Prometheus:

```go
import "github.com/prometheus/client_golang/prometheus"

var (
    emailsSent = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "emails_sent_total",
            Help: "Total number of emails sent",
        },
        []string{"type", "status"},
    )

    emailDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "email_send_duration_seconds",
            Help: "Email sending duration",
        },
        []string{"type"},
    )
)
```

### Testing Email Code

Don't send real emails in tests. Use mock services:

```go
// internal/email/mock.go
package email

type MockEmailService struct {
    SentEmails []SentEmail
}

type SentEmail struct {
    To      string
    Subject string
    Body    string
}

func NewMockEmailService() *MockEmailService {
    return &MockEmailService{
        SentEmails: make([]SentEmail, 0),
    }
}

func (m *MockEmailService) SendWelcomeEmail(toEmail, toName string) error {
    m.SentEmails = append(m.SentEmails, SentEmail{
        To:      toEmail,
        Subject: "Welcome",
        Body:    "Welcome email body",
    })
    return nil
}
```

In tests:

```go
func TestSignupHandler(t *testing.T) {
    mockEmail := email.NewMockEmailService()

    // Your handler uses mockEmail
    handler := NewSignupHandler(mockEmail)

    // Make request
    handler.HandleSignup(email, name)

    // Verify email was sent
    if len(mockEmail.SentEmails) != 1 {
        t.Errorf("Expected 1 email, got %d", len(mockEmail.SentEmails))
    }

    if mockEmail.SentEmails[0].To != "user@example.com" {
        t.Errorf("Wrong recipient")
    }
}
```

For integration testing, use Mailtrap.io or MailHog - they're SMTP servers that catch emails instead of delivering them.

## Troubleshooting Common Issues

**Emails not arriving:**
- Check spam folder first
- Verify API key is correct
- Check sender email is verified
- Look for errors in logs
- Verify email address is valid

**High bounce rate:**
- Validate emails before sending
- Remove invalid addresses
- Check for typos in email addresses
- Verify domain hasn't blocked you

**Marked as spam:**
- Set up SPF/DKIM/DMARC
- Avoid spam trigger words
- Include unsubscribe link
- Send from consistent address
- Warm up sending domain

**API rate limits:**
- Implement exponential backoff
- Spread sends over time
- Use background jobs
- Upgrade to higher tier

**Images not displaying:**
- Use absolute URLs
- Host images on CDN
- Test in multiple email clients
- Consider embedding images

## Wrapping Up

Email sending in Go is straightforward once you understand the options. SMTP works for testing but production needs email services like SendGrid or Mailgun.

SendGrid is easier to start with - great free tier, simple API, excellent docs. Mailgun offers better pricing at scale and more advanced features. Both handle deliverability, bounces, and analytics so you don't have to.

The key patterns: use background jobs to avoid blocking requests, implement retry logic for reliability, abstract behind interfaces for flexibility, monitor failures and delivery rates, and test with mocks to avoid sending real emails.

Start simple with SendGrid's free tier. As your volume grows, evaluate if Mailgun's pricing works better. Both are production-ready and trusted by thousands of applications.

For building complete Go applications, check out our guides on [REST API development with Gin](/2025/09/building-rest-api-gin-framework-golang-production-ready.html), [database migrations](/2025/10/how-to-perform-database-migrations-in-go-using-golang-migrate.html), and [background job processing](/2025/10/how-to-implement-background-jobs-in-go-with-asynq-and-redis.html).

Email is essential infrastructure. Get it right from the start and your users will actually receive the messages you send them.
