---
title: 'Laravel Security Best Practices: Complete Production Security Guide'
date: 2025-09-08T15:15:00+07:00
draft: false
url: /2025/09/laravel-security-best-practices-production.html
tags: 
- Laravel
- Security
- Best Practices
- Production
description: 'Complete Laravel security best practices guide for production. How to secure Laravel applications from various security risks and vulnerabilities.'
featured: false
---

Security is paramount when deploying Laravel applications to production environments. A single vulnerability can compromise user data, damage your reputation, and result in significant financial losses. This comprehensive guide covers essential security practices to protect your Laravel applications from common threats and vulnerabilities.

Laravel provides excellent security features out of the box, but proper implementation and additional security measures are crucial for production deployments. From authentication and authorization to data protection and server hardening, every layer of your application stack requires careful attention to security details.

## 1. Authentication and Authorization Security

Proper authentication and authorization form the foundation of application security. Laravel provides robust tools, but they must be configured correctly for production use.

### Implement Strong Password Policies

Enforce strong password requirements to prevent brute force attacks and improve overall security:

```php
<?php

namespace App\Rules;

use Illuminate\Contracts\Validation\Rule;

class StrongPassword implements Rule
{
    public function passes($attribute, $value): bool
    {
        // At least 12 characters long
        if (strlen($value) < 12) {
            return false;
        }
        
        // Contains uppercase letter
        if (!preg_match('/[A-Z]/', $value)) {
            return false;
        }
        
        // Contains lowercase letter
        if (!preg_match('/[a-z]/', $value)) {
            return false;
        }
        
        // Contains number
        if (!preg_match('/[0-9]/', $value)) {
            return false;
        }
        
        // Contains special character
        if (!preg_match('/[^A-Za-z0-9]/', $value)) {
            return false;
        }
        
        // Check against common passwords
        $commonPasswords = ['password123', '123456789', 'qwerty123'];
        if (in_array(strtolower($value), $commonPasswords)) {
            return false;
        }
        
        return true;
    }
    
    public function message(): string
    {
        return 'Password must be at least 12 characters and contain uppercase, lowercase, number, and special character.';
    }
}

class RegisterRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'email' => 'required|email|unique:users',
            'password' => ['required', 'confirmed', new StrongPassword()],
        ];
    }
}
```

### Implement Rate Limiting for Authentication

Protect against brute force attacks with intelligent rate limiting:

```php
<?php

namespace App\Http\Controllers\Auth;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;

class LoginController extends Controller
{
    public function login(Request $request)
    {
        $throttleKey = $this->throttleKey($request);
        
        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $seconds = RateLimiter::availableIn($throttleKey);
            
            return response()->json([
                'message' => "Too many login attempts. Please try again in {$seconds} seconds."
            ], 429);
        }
        
        $credentials = $request->validate([
            'email' => 'required|email',
            'password' => 'required'
        ]);
        
        if (Auth::attempt($credentials)) {
            RateLimiter::clear($throttleKey);
            
            // Log successful login
            Log::info('User logged in', [
                'user_id' => auth()->id(),
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent()
            ]);
            
            return redirect()->intended('/dashboard');
        }
        
        RateLimiter::hit($throttleKey);
        
        // Log failed login attempt
        Log::warning('Failed login attempt', [
            'email' => $request->email,
            'ip' => $request->ip(),
            'user_agent' => $request->userAgent()
        ]);
        
        return back()->withErrors([
            'email' => 'The provided credentials do not match our records.',
        ]);
    }
    
    private function throttleKey(Request $request): string
    {
        return Str::lower($request->input('email')) . '|' . $request->ip();
    }
}
```

### Multi-Factor Authentication Implementation

Add an extra layer of security with 2FA:

```php
<?php

namespace App\Services;

use App\Models\User;
use PragmaRX\Google2FA\Google2FA;
use SimpleSoftwareIO\QrCode\Facades\QrCode;

class TwoFactorAuthService
{
    private Google2FA $google2fa;
    
    public function __construct()
    {
        $this->google2fa = new Google2FA();
    }
    
    public function generateSecretKey(): string
    {
        return $this->google2fa->generateSecretKey();
    }
    
    public function getQRCodeUrl(User $user, string $secret): string
    {
        return $this->google2fa->getQRCodeUrl(
            config('app.name'),
            $user->email,
            $secret
        );
    }
    
    public function verifyCode(string $secret, string $code): bool
    {
        return $this->google2fa->verifyKey($secret, $code);
    }
    
    public function enable2FA(User $user, string $code): bool
    {
        if (!$this->verifyCode($user->two_factor_secret, $code)) {
            return false;
        }
        
        $user->update([
            'two_factor_enabled' => true,
            'two_factor_confirmed_at' => now()
        ]);
        
        return true;
    }
}

class TwoFactorMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        $user = auth()->user();
        
        if ($user && $user->two_factor_enabled && !session('2fa_verified')) {
            return redirect()->route('2fa.verify');
        }
        
        return $next($request);
    }
}
```

## 2. Input Validation and Sanitization

Proper input validation prevents many security vulnerabilities including SQL injection, XSS, and data corruption.

### Comprehensive Request Validation

Create robust validation rules for all user inputs:

```php
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreatePostRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'title' => [
                'required',
                'string',
                'max:255',
                'regex:/^[a-zA-Z0-9\s\-_.,!?]+$/' // Only allow safe characters
            ],
            'content' => [
                'required',
                'string',
                'max:50000'
            ],
            'category_id' => 'required|exists:categories,id',
            'tags' => 'array|max:10',
            'tags.*' => 'string|max:50|regex:/^[a-zA-Z0-9\-_]+$/',
            'featured_image' => 'nullable|image|max:2048|mimes:jpeg,png,webp',
            'publish_at' => 'nullable|date|after:now'
        ];
    }
    
    public function sanitizeInput(): array
    {
        $input = $this->validated();
        
        // Sanitize HTML content
        $input['content'] = $this->sanitizeHtml($input['content']);
        
        // Sanitize title
        $input['title'] = strip_tags(trim($input['title']));
        
        return $input;
    }
    
    private function sanitizeHtml(string $content): string
    {
        $allowedTags = '<p><br><strong><em><ul><ol><li><a><h2><h3><h4><blockquote>';
        
        $content = strip_tags($content, $allowedTags);
        
        // Remove potentially dangerous attributes
        $content = preg_replace('/(<[^>]*) on\w+="[^"]*"/i', '$1', $content);
        $content = preg_replace('/(<[^>]*) style="[^"]*"/i', '$1', $content);
        
        return $content;
    }
    
    public function messages(): array
    {
        return [
            'title.regex' => 'Title contains invalid characters.',
            'tags.*.regex' => 'Tags can only contain letters, numbers, hyphens, and underscores.',
        ];
    }
}
```

### SQL Injection Prevention

Always use parameterized queries and Eloquent ORM properly:

```php
<?php

namespace App\Services;

use App\Models\Post;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class PostSearchService
{
    public function search(string $query, array $filters = []): Collection
    {
        // Good: Using Eloquent query builder (parameterized)
        $posts = Post::query()
            ->when($query, function ($q) use ($query) {
                $q->where('title', 'LIKE', '%' . $query . '%')
                  ->orWhere('content', 'LIKE', '%' . $query . '%');
            })
            ->when($filters['category'] ?? null, function ($q, $category) {
                $q->where('category_id', $category);
            })
            ->when($filters['author'] ?? null, function ($q, $author) {
                $q->where('user_id', $author);
            })
            ->published()
            ->orderBy('created_at', 'desc')
            ->get();
            
        return $posts;
    }
    
    public function complexSearch(array $criteria): array
    {
        // Good: Using parameterized raw queries when needed
        $results = DB::select("
            SELECT p.*, u.name as author_name, c.name as category_name
            FROM posts p
            JOIN users u ON p.user_id = u.id
            JOIN categories c ON p.category_id = c.id
            WHERE p.status = 'published'
            AND p.created_at >= ?
            AND (p.title LIKE ? OR p.content LIKE ?)
            ORDER BY p.created_at DESC
            LIMIT ?
        ", [
            $criteria['date_from'],
            '%' . $criteria['search'] . '%',
            '%' . $criteria['search'] . '%',
            $criteria['limit'] ?? 20
        ]);
        
        return collect($results)->toArray();
    }
    
    // Bad example - NEVER do this
    private function badSearchExample(string $query): Collection
    {
        // This is vulnerable to SQL injection
        return DB::select("SELECT * FROM posts WHERE title LIKE '%{$query}%'");
    }
}
```

## 3. Cross-Site Request Forgery (CSRF) Protection

Laravel's CSRF protection is enabled by default, but proper implementation is crucial:

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class VerifyCsrfToken extends \Illuminate\Foundation\Http\Middleware\VerifyCsrfToken
{
    protected $except = [
        // Only add routes that absolutely need to be excluded
        'api/webhooks/*', // External webhook endpoints
    ];
    
    public function handle($request, Closure $next)
    {
        // Add additional CSRF checks for sensitive operations
        if ($this->isSensitiveOperation($request)) {
            $this->validateCsrfToken($request);
        }
        
        return parent::handle($request, $next);
    }
    
    private function isSensitiveOperation(Request $request): bool
    {
        $sensitiveRoutes = [
            'user/delete',
            'admin/*',
            'payment/process'
        ];
        
        foreach ($sensitiveRoutes as $route) {
            if ($request->is($route)) {
                return true;
            }
        }
        
        return false;
    }
}

// API CSRF protection for SPA applications
class ApiCsrfMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        // For API routes, use double submit cookies
        if ($request->isMethod('post') || $request->isMethod('put') || $request->isMethod('delete')) {
            $headerToken = $request->header('X-CSRF-TOKEN');
            $cookieToken = $request->cookie('XSRF-TOKEN');
            
            if (!$headerToken || !$cookieToken || $headerToken !== $cookieToken) {
                return response()->json(['message' => 'CSRF token mismatch'], 419);
            }
        }
        
        return $next($request);
    }
}
```

## 4. Cross-Site Scripting (XSS) Protection

Prevent XSS attacks through proper output encoding and Content Security Policy:

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class ContentSecurityPolicy
{
    public function handle(Request $request, Closure $next)
    {
        $response = $next($request);
        
        $csp = [
            "default-src 'self'",
            "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://unpkg.com",
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdn.jsdelivr.net",
            "font-src 'self' https://fonts.gstatic.com",
            "img-src 'self' data: https:",
            "connect-src 'self'",
            "frame-ancestors 'none'",
            "base-uri 'self'",
            "form-action 'self'"
        ];
        
        $response->headers->set('Content-Security-Policy', implode('; ', $csp));
        
        // Additional security headers
        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('X-Frame-Options', 'DENY');
        $response->headers->set('X-XSS-Protection', '1; mode=block');
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        
        return $response;
    }
}

// Helper for safe output in Blade templates
class SecurityHelper
{
    public static function sanitizeOutput(string $content, bool $allowHtml = false): string
    {
        if (!$allowHtml) {
            return htmlspecialchars($content, ENT_QUOTES, 'UTF-8');
        }
        
        // For HTML content, use a whitelist approach
        $allowedTags = '<p><br><strong><em><ul><ol><li><a><h2><h3><h4>';
        $cleaned = strip_tags($content, $allowedTags);
        
        // Remove dangerous attributes
        $cleaned = preg_replace('/(<[^>]*) on\w+="[^"]*"/i', '$1', $cleaned);
        $cleaned = preg_replace('/(<[^>]*) style="[^"]*"/i', '$1', $cleaned);
        $cleaned = preg_replace('/javascript:/i', '', $cleaned);
        
        return $cleaned;
    }
}
```

## 5. File Upload Security

Secure file upload handling prevents malicious file execution and server compromise:

```php
<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class SecureFileUploadService
{
    private array $allowedMimeTypes = [
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf',
        'text/plain'
    ];
    
    private array $allowedExtensions = [
        'jpg', 'jpeg', 'png', 'webp', 'pdf', 'txt'
    ];
    
    private int $maxFileSize = 5 * 1024 * 1024; // 5MB
    
    public function uploadFile(UploadedFile $file, string $directory = 'uploads'): array
    {
        $this->validateFile($file);
        
        $filename = $this->generateSecureFilename($file);
        $path = $directory . '/' . $filename;
        
        // Store file outside web root
        $disk = config('app.env') === 'production' ? 'private' : 'public';
        
        // Scan file for malware (if antivirus service available)
        $this->scanFile($file);
        
        $storedPath = $file->storeAs($directory, $filename, $disk);
        
        // Log file upload
        Log::info('File uploaded', [
            'filename' => $filename,
            'size' => $file->getSize(),
            'mime_type' => $file->getMimeType(),
            'user_id' => auth()->id(),
            'ip' => request()->ip()
        ]);
        
        return [
            'filename' => $filename,
            'path' => $storedPath,
            'size' => $file->getSize(),
            'mime_type' => $file->getMimeType()
        ];
    }
    
    private function validateFile(UploadedFile $file): void
    {
        // Check file size
        if ($file->getSize() > $this->maxFileSize) {
            throw new \InvalidArgumentException('File size exceeds maximum allowed size.');
        }
        
        // Verify MIME type
        $mimeType = $file->getMimeType();
        if (!in_array($mimeType, $this->allowedMimeTypes)) {
            throw new \InvalidArgumentException('File type not allowed.');
        }
        
        // Verify file extension
        $extension = strtolower($file->getClientOriginalExtension());
        if (!in_array($extension, $this->allowedExtensions)) {
            throw new \InvalidArgumentException('File extension not allowed.');
        }
        
        // Additional checks for image files
        if (str_starts_with($mimeType, 'image/')) {
            $this->validateImageFile($file);
        }
    }
    
    private function validateImageFile(UploadedFile $file): void
    {
        // Verify it's actually an image
        $imageInfo = getimagesize($file->getRealPath());
        if (!$imageInfo) {
            throw new \InvalidArgumentException('Invalid image file.');
        }
        
        // Check image dimensions
        [$width, $height] = $imageInfo;
        if ($width > 4000 || $height > 4000) {
            throw new \InvalidArgumentException('Image dimensions too large.');
        }
    }
    
    private function generateSecureFilename(UploadedFile $file): string
    {
        $extension = $file->getClientOriginalExtension();
        $hash = hash('sha256', $file->getClientOriginalName() . time() . Str::random(10));
        
        return substr($hash, 0, 32) . '.' . $extension;
    }
    
    private function scanFile(UploadedFile $file): void
    {
        // Implement virus scanning if available
        // This could integrate with ClamAV or similar service
        $content = file_get_contents($file->getRealPath());
        
        // Basic malicious pattern detection
        $maliciousPatterns = [
            '/<\?php/i',
            '/<script/i',
            '/eval\(/i',
            '/exec\(/i',
            '/system\(/i'
        ];
        
        foreach ($maliciousPatterns as $pattern) {
            if (preg_match($pattern, $content)) {
                throw new \InvalidArgumentException('File contains potentially malicious content.');
            }
        }
    }
}
```

## 6. Session Security

Configure sessions securely to prevent session hijacking and fixation:

```php
<?php

// config/session.php
return [
    'driver' => env('SESSION_DRIVER', 'redis'),
    'lifetime' => env('SESSION_LIFETIME', 120),
    'expire_on_close' => true,
    'encrypt' => true,
    'files' => storage_path('framework/sessions'),
    'connection' => env('SESSION_CONNECTION'),
    'table' => 'sessions',
    'store' => env('SESSION_STORE'),
    'lottery' => [2, 100],
    'cookie' => env(
        'SESSION_COOKIE',
        Str::slug(env('APP_NAME', 'laravel'), '_').'_session'
    ),
    'path' => '/',
    'domain' => env('SESSION_DOMAIN'),
    'secure' => env('SESSION_SECURE_COOKIE', true),
    'http_only' => true,
    'same_site' => 'strict',
];

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class SecureSession
{
    public function handle(Request $request, Closure $next)
    {
        // Regenerate session ID on login
        if ($request->user() && !session('session_regenerated')) {
            $request->session()->regenerate();
            session(['session_regenerated' => true]);
        }
        
        // Check for session hijacking
        $this->checkSessionSecurity($request);
        
        return $next($request);
    }
    
    private function checkSessionSecurity(Request $request): void
    {
        // Check if user agent changed
        $currentUserAgent = $request->userAgent();
        $sessionUserAgent = session('user_agent');
        
        if ($sessionUserAgent && $sessionUserAgent !== $currentUserAgent) {
            Auth::logout();
            session()->invalidate();
            throw new \Exception('Session security violation detected.');
        }
        
        if (!$sessionUserAgent) {
            session(['user_agent' => $currentUserAgent]);
        }
        
        // Check IP address changes (optional, can be problematic with mobile users)
        if (config('security.check_ip_changes')) {
            $currentIp = $request->ip();
            $sessionIp = session('ip_address');
            
            if ($sessionIp && $sessionIp !== $currentIp) {
                Auth::logout();
                session()->invalidate();
                throw new \Exception('IP address changed during session.');
            }
            
            if (!$sessionIp) {
                session(['ip_address' => $currentIp]);
            }
        }
    }
}
```

## 7. Environment Configuration Security

Secure your environment configuration and sensitive data:

```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

class SecurityAuditCommand extends Command
{
    protected $signature = 'security:audit';
    protected $description = 'Run security audit on the application';
    
    public function handle(): void
    {
        $this->info('Running security audit...');
        
        $checks = [
            'checkEnvironmentVariables',
            'checkFilePermissions',
            'checkDatabaseSecurity',
            'checkCacheConfiguration',
            'checkLoggingConfiguration'
        ];
        
        $passed = 0;
        $failed = 0;
        
        foreach ($checks as $check) {
            if ($this->$check()) {
                $passed++;
                $this->line("✓ {$check}", 'fg=green');
            } else {
                $failed++;
                $this->line("✗ {$check}", 'fg=red');
            }
        }
        
        $this->info("\nSecurity Audit Complete");
        $this->line("Passed: {$passed}");
        $this->line("Failed: {$failed}");
    }
    
    private function checkEnvironmentVariables(): bool
    {
        $required = [
            'APP_KEY',
            'DB_PASSWORD',
            'REDIS_PASSWORD'
        ];
        
        $issues = [];
        
        foreach ($required as $var) {
            if (!env($var)) {
                $issues[] = "Missing {$var}";
            }
        }
        
        // Check for default/weak values
        if (env('APP_KEY') === 'base64:your-secret-key-here') {
            $issues[] = 'APP_KEY is using default value';
        }
        
        if (env('DB_PASSWORD') === 'password' || env('DB_PASSWORD') === '') {
            $issues[] = 'Weak database password';
        }
        
        if (!empty($issues)) {
            $this->warn(implode(', ', $issues));
            return false;
        }
        
        return true;
    }
    
    private function checkFilePermissions(): bool
    {
        $files = [
            '.env' => '600',
            'storage' => '755',
            'bootstrap/cache' => '755'
        ];
        
        $issues = [];
        
        foreach ($files as $file => $expectedPerm) {
            $path = base_path($file);
            if (file_exists($path)) {
                $currentPerm = substr(sprintf('%o', fileperms($path)), -3);
                if ($currentPerm !== $expectedPerm) {
                    $issues[] = "{$file}: {$currentPerm} (expected {$expectedPerm})";
                }
            }
        }
        
        if (!empty($issues)) {
            $this->warn('File permission issues: ' . implode(', ', $issues));
            return false;
        }
        
        return true;
    }
    
    private function checkDatabaseSecurity(): bool
    {
        // Check database connection encryption
        try {
            $pdo = DB::getPdo();
            $stmt = $pdo->query("SHOW STATUS LIKE 'Ssl_cipher'");
            $result = $stmt->fetch();
            
            if (!$result || empty($result[1])) {
                $this->warn('Database connection is not encrypted');
                return false;
            }
        } catch (\Exception $e) {
            $this->warn('Could not verify database encryption');
            return false;
        }
        
        return true;
    }
    
    private function checkCacheConfiguration(): bool
    {
        $driver = config('cache.default');
        
        if ($driver === 'file' && app()->environment('production')) {
            $this->warn('Using file cache driver in production');
            return false;
        }
        
        return true;
    }
    
    private function checkLoggingConfiguration(): bool
    {
        $logLevel = config('logging.level');
        
        if ($logLevel === 'debug' && app()->environment('production')) {
            $this->warn('Debug logging enabled in production');
            return false;
        }
        
        return true;
    }
}
```

## 8. API Security Best Practices

Secure your APIs with proper authentication and rate limiting:

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class ApiSecurityMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        // Validate API key if required
        if (!$this->validateApiKey($request)) {
            return response()->json(['message' => 'Invalid API key'], 401);
        }
        
        // Add security headers for APIs
        $response = $next($request);
        
        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('X-Frame-Options', 'DENY');
        $response->headers->set('Cache-Control', 'no-store, no-cache, must-revalidate');
        
        return $response;
    }
    
    private function validateApiKey(Request $request): bool
    {
        $apiKey = $request->header('X-API-Key');
        
        if (!$apiKey) {
            return false;
        }
        
        // Validate against stored API keys
        return Hash::check($apiKey, config('api.key_hash'));
    }
}

// JWT Token Security
namespace App\Services;

use App\Models\User;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class JwtTokenService
{
    private string $secretKey;
    private string $algorithm = 'HS256';
    private int $expirationTime = 3600; // 1 hour
    
    public function __construct()
    {
        $this->secretKey = config('jwt.secret');
    }
    
    public function generateToken(User $user): string
    {
        $payload = [
            'sub' => $user->id,
            'email' => $user->email,
            'iat' => time(),
            'exp' => time() + $this->expirationTime,
            'jti' => Str::uuid()->toString(), // JWT ID for tracking
            'aud' => config('app.url'),
            'iss' => config('app.name')
        ];
        
        return JWT::encode($payload, $this->secretKey, $this->algorithm);
    }
    
    public function validateToken(string $token): ?array
    {
        try {
            $decoded = JWT::decode($token, new Key($this->secretKey, $this->algorithm));
            return (array) $decoded;
        } catch (\Exception $e) {
            Log::warning('Invalid JWT token', [
                'token' => substr($token, 0, 20) . '...',
                'error' => $e->getMessage(),
                'ip' => request()->ip()
            ]);
            return null;
        }
    }
    
    public function refreshToken(string $token): ?string
    {
        $payload = $this->validateToken($token);
        
        if (!$payload) {
            return null;
        }
        
        $user = User::find($payload['sub']);
        if (!$user) {
            return null;
        }
        
        return $this->generateToken($user);
    }
}
```

## 9. Security Monitoring and Logging

Implement comprehensive security monitoring:

```php
<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class SecurityMonitoringService
{
    public function logSecurityEvent(string $event, array $context = []): void
    {
        $securityLog = [
            'event' => $event,
            'timestamp' => now(),
            'ip' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'user_id' => auth()->id(),
            'session_id' => session()->getId(),
            'context' => $context
        ];
        
        Log::channel('security')->warning($event, $securityLog);
        
        // Alert on critical events
        if ($this->isCriticalEvent($event)) {
            $this->sendSecurityAlert($securityLog);
        }
    }
    
    public function detectSuspiciousActivity(Request $request): bool
    {
        $suspicious = false;
        
        // Check for rapid requests from same IP
        if ($this->isRapidRequests($request->ip())) {
            $this->logSecurityEvent('Rapid requests detected', ['ip' => $request->ip()]);
            $suspicious = true;
        }
        
        // Check for suspicious user agents
        if ($this->isSuspiciousUserAgent($request->userAgent())) {
            $this->logSecurityEvent('Suspicious user agent', ['user_agent' => $request->userAgent()]);
            $suspicious = true;
        }
        
        // Check for common attack patterns in URLs
        if ($this->containsAttackPatterns($request->fullUrl())) {
            $this->logSecurityEvent('Attack pattern in URL', ['url' => $request->fullUrl()]);
            $suspicious = true;
        }
        
        return $suspicious;
    }
    
    private function isCriticalEvent(string $event): bool
    {
        $criticalEvents = [
            'Multiple failed login attempts',
            'Admin account accessed',
            'Database query error',
            'File upload violation',
            'Potential SQL injection'
        ];
        
        return in_array($event, $criticalEvents);
    }
    
    private function sendSecurityAlert(array $logData): void
    {
        // Send notification to security team
        // This could be email, Slack, or external security service
        
        if (config('security.alerts.email')) {
            Mail::to(config('security.alerts.email'))
                ->send(new SecurityAlertMail($logData));
        }
        
        // Note: You need to create SecurityAlertMail class:
        // php artisan make:mail SecurityAlertMail
    }
    
    private function isRapidRequests(string $ip): bool
    {
        $key = "rapid_requests:{$ip}";
        $requests = Cache::get($key, 0);
        
        Cache::put($key, $requests + 1, 60); // Track for 1 minute
        
        return $requests > 100; // More than 100 requests per minute
    }
    
    private function isSuspiciousUserAgent(string $userAgent): bool
    {
        $suspiciousPatterns = [
            '/sqlmap/i',
            '/nmap/i',
            '/nikto/i',
            '/curl/i',
            '/wget/i',
            '/python/i'
        ];
        
        foreach ($suspiciousPatterns as $pattern) {
            if (preg_match($pattern, $userAgent)) {
                return true;
            }
        }
        
        return false;
    }
    
    private function containsAttackPatterns(string $url): bool
    {
        $attackPatterns = [
            '/\.\./i', // Directory traversal
            '/union\s+select/i', // SQL injection
            '/<script/i', // XSS
            '/eval\(/i', // Code injection
            '/base64_decode/i' // Potential malicious code
        ];
        
        foreach ($attackPatterns as $pattern) {
            if (preg_match($pattern, $url)) {
                return true;
            }
        }
        
        return false;
    }
}
```

## 10. Production Deployment Security Checklist

Final security checklist for production deployment:

```bash
# 1. Environment Configuration
php artisan config:cache
php artisan route:cache
php artisan view:cache

# 2. File Permissions
chmod 644 .env
chmod -R 755 storage
chmod -R 755 bootstrap/cache

# 3. Remove Development Tools
composer install --no-dev --optimize-autoloader

# 4. Clear Sensitive Caches
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear

# 5. Set Proper Directory Permissions
find storage -type f -exec chmod 644 {} \;
find storage -type d -exec chmod 755 {} \;
```

Create a deployment security script:

```php
<?php

namespace App\Console\Commands;

class SecurityDeployCommand extends Command
{
    protected $signature = 'security:deploy';
    protected $description = 'Run security checks before deployment';
    
    public function handle(): void
    {
        $this->info('Running pre-deployment security checks...');
        
        $checks = [
            'Environment variables are secure',
            'Debug mode is disabled',
            'APP_KEY is properly set',
            'Database credentials are secure',
            'File permissions are correct',
            'Sensitive files are protected'
        ];
        
        foreach ($checks as $check) {
            if ($this->runSecurityCheck($check)) {
                $this->line("✓ {$check}", 'fg=green');
            } else {
                $this->line("✗ {$check}", 'fg=red');
                $this->error('Security check failed. Deployment aborted.');
                return;
            }
        }
        
        $this->info('All security checks passed. Ready for deployment.');
    }
    
    private function runSecurityCheck(string $check): bool
    {
        switch ($check) {
            case 'Debug mode is disabled':
                return !config('app.debug');
            case 'APP_KEY is properly set':
                return config('app.key') && config('app.key') !== 'base64:your-secret-key-here';
            default:
                return true;
        }
    }
}
```

## Conclusion

Security is not a one-time setup but an ongoing process that requires constant vigilance and updates. These best practices provide a solid foundation for securing your Laravel applications in production environments.

Regular security audits, monitoring, and staying updated with the latest security patches are essential for maintaining a secure application. Remember that security is only as strong as its weakest link, so ensure all team members understand and follow these practices.

The investment in proper security measures pays dividends in protecting your users' data, maintaining trust, and avoiding costly security breaches. Start implementing these practices early in your development process rather than trying to retrofit security into an existing application.

Ready to build better Laravel applications? Master the art of [Clean Code and Project Structure](/2025/09/clean-code-laravel-project-structure.html) or supercharge your apps with our comprehensive [Performance Optimization Guide](/2025/09/laravel-performance-optimization-15-techniques.html).