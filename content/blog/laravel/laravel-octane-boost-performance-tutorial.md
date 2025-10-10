---
title: 'Boost Performance with High-Speed Application Server'
date: 2025-09-22T10:00:00+07:00
draft: false
url: /2025/09/laravel-octane-boost-performance-tutorial.html
tags:
- Laravel
- Octane
- Performance
- High-Speed Server
description: 'Laravel Octane tutorial to boost application performance. Setup and configuration guide for high-speed application server with significant improvements.'
featured: false
faq:
  - question: "Should I use Swoole or RoadRunner with Laravel Octane?"
    answer: "Swoole is easier to get started with as it's a PHP extension installed via PECL, offering excellent performance and mature stability. RoadRunner is a Go-based binary that's easier to install without system-level access and offers unique features like HTTP/2 push. For most developers, Swoole is recommended for production due to better community support and integration. Choose RoadRunner if you prefer standalone binaries, need specific RoadRunner features, or have restrictions on installing PHP extensions."
  - question: "Can I use Laravel Octane with my existing Laravel application?"
    answer: "Yes, but you need to review your code for potential issues. Octane requires Laravel 8+, and you must ensure your code doesn't rely on static properties for request-specific data, properly handles session state, avoids memory leaks from accumulating data, and cleans up resources between requests. Most well-structured Laravel applications work with minimal changes. Test thoroughly in staging, especially session handling, file uploads, and any code using static variables or singletons."
  - question: "How many workers should I configure for my Octane server?"
    answer: "Set workers to match your CPU cores (check with `nproc`). For example, a 4-core server should use `--workers=4`. Task workers can be set higher (typically 1.5-2x the worker count) since they handle background tasks. Too few workers underutilize CPU; too many workers cause memory pressure and context switching overhead. Monitor memory usage per worker (typically 50-150MB) and adjust based on your application's memory footprint and available RAM."
  - question: "Will Laravel Octane cause memory leaks in my application?"
    answer: "Octane itself doesn't cause leaks, but long-lived processes expose existing memory management issues. Avoid static arrays that accumulate data, don't cache objects in static properties, use proper cache drivers instead of in-memory storage, and set `max_request` to recycle workers periodically (default 1000). Octane's cleanup listeners handle most issues automatically. Monitor memory with `php artisan octane:status` and adjust `max_request` lower if workers grow too large over time."
  - question: "How do I safely deploy code changes to an Octane-powered Laravel app?"
    answer: "Use `php artisan octane:reload` to gracefully restart workers without downtime. For zero-downtime deployments, run multiple Octane instances on different ports behind a load balancer, deploy and reload one instance at a time, or use blue-green deployment with health checks. Always test in staging first, ensure your deployment script includes `composer install --optimize-autoloader`, clear and rebuild caches, and verify worker restart completes successfully before marking deployment complete."
  - question: "Can I run Laravel Octane in a shared hosting environment?"
    answer: "Unlikely. Shared hosting typically doesn't allow long-running processes or installing PHP extensions like Swoole. Octane requires CLI access to start the server, ability to bind to network ports, sufficient memory for multiple workers (typically 512MB-2GB), and process management tools like Supervisor. You need VPS, dedicated server, or containerized hosting (Docker, Kubernetes). For shared hosting, stick with traditional PHP-FPM. Consider upgrading to a $5-10/month VPS for Octane's benefits."
---

If you're tired of waiting for your Laravel app to respond and want to see some serious speed improvements, Laravel Octane might be exactly what you're looking for. Think of it as giving your application a turbo boost - we're talking about performance gains that can make your app 3x to 10x faster in many scenarios.

Laravel Octane takes your regular Laravel application and runs it on high-performance application servers like Swoole or RoadRunner. Instead of booting up your entire application for every single request (which is what traditional PHP does), Octane keeps your app loaded in memory and reuses it for multiple requests. The result? Lightning-fast response times that will make your users happy.

## What Makes Laravel Octane So Fast?

Traditional PHP applications follow a simple but inefficient pattern: for every request, the server boots up PHP, loads your entire application, processes the request, sends a response, and then throws everything away. It's like starting your car from scratch every time you want to drive somewhere.

Octane changes this game completely. It boots your Laravel application once and keeps it running in memory. When requests come in, they're handled by the already-loaded application instance. No more constant bootstrapping, no more loading the same files over and over again.

Here's what happens under the hood:

- Your application starts once and stays in memory
- Database connections are pooled and reused
- Compiled views stay cached between requests
- Service container bindings remain intact
- Framework overhead is dramatically reduced

The performance improvements are often dramatic. While traditional Laravel apps might handle 50-100 requests per second, Octane-powered applications can easily handle 500-2000 requests per second on the same hardware.

## Installing Laravel Octane

Getting started with Octane is surprisingly straightforward. You'll need Laravel 8 or higher, and you can choose between two application servers: Swoole (PHP extension) or RoadRunner (Go-based server).

Let's start with the basic installation:

```bash
composer require laravel/octane
```

After installing the package, publish the configuration:

```bash
php artisan octane:install
```

This command will ask you to choose between Swoole and RoadRunner. For most developers, Swoole is the easier choice since it's a PHP extension, while RoadRunner requires downloading a separate binary but offers some unique features.

### Installing with Swoole

If you choose Swoole, you'll need to install the PHP extension:

```bash
# On Ubuntu/Debian
sudo pecl install swoole

# Using Docker (recommended for development)
docker run --rm -v $(pwd):/var/www/html -w /var/www/html laravelsail/php81-composer:latest composer require laravel/octane
```

### Installing with RoadRunner

For RoadRunner, the installation process downloads the binary for you:

```bash
php artisan octane:install --server=roadrunner
```

This will download the RoadRunner binary and set up the necessary configuration files.

## Basic Configuration and Setup

Once installed, you'll find a new configuration file at `config/octane.php`. This file controls how Octane behaves, and understanding its options is crucial for getting the best performance.

The most important settings include:

```php
return [
    'server' => env('OCTANE_SERVER', 'swoole'),

    'https' => env('OCTANE_HTTPS', false),

    'listeners' => [
        WorkerStarting::class => [
            EnsureUploadedFilesAreValid::class,
            EnsureUploadedFilesCanBeMoved::class,
        ],

        RequestReceived::class => [
            ...Octane::prepareApplicationForNextOperation(),
            ...Octane::prepareApplicationForNextRequest(),
        ],

        RequestHandled::class => [
            FlushTemporaryState::class,
        ],
    ],
];
```

These listeners are crucial because they handle the cleanup between requests. Since your application stays in memory, you need to make sure that state from one request doesn't leak into the next one.

## Running Your First Octane Server

Starting your Octane server is as simple as running:

```bash
php artisan octane:start
```

By default, this starts the server on `http://localhost:8000`. You can customize the host and port:

```bash
php artisan octane:start --host=0.0.0.0 --port=9000
```

For production use, you'll want to specify the number of workers:

```bash
php artisan octane:start --workers=4 --task-workers=6
```

The number of workers should generally match your CPU cores, while task workers handle background tasks and can be set higher.

## Memory Management and State Isolation

Here's where things get interesting - and where you need to be careful. Since your application stays in memory, you need to think about memory leaks and state isolation between requests.

### Avoiding Memory Leaks

Octane automatically handles most cleanup, but you should be aware of common pitfalls:

```php
// Bad - this will accumulate data between requests
class UserController extends Controller
{
    protected static $cache = [];

    public function show(User $user)
    {
        self::$cache[] = $user; // This grows forever!
        return view('user.show', compact('user'));
    }
}

// Good - use proper caching mechanisms
class UserController extends Controller
{
    public function show(User $user)
    {
        $userData = Cache::remember("user.{$user->id}", 3600, function () use ($user) {
            return $user->toArray();
        });

        return view('user.show', compact('userData'));
    }
}
```

### Managing Shared State

Be extra careful with static variables and singletons:

```php
// Problematic - state persists between requests
class OrderService
{
    protected static $currentOrder;

    public function processOrder($orderData)
    {
        self::$currentOrder = $orderData; // Dangerous!
        // Process order...
    }
}

// Better approach
class OrderService
{
    public function processOrder($orderData)
    {
        // Use request-specific data, not static properties
        $order = new Order($orderData);
        // Process order...
        return $order;
    }
}
```

For proper memory management and performance optimization strategies, check out our detailed guide on [Laravel performance optimization techniques](/2025/09/laravel-performance-optimization-15-techniques.html).

## Advanced Configuration Options

Octane offers several advanced configuration options that can significantly impact performance.

### Worker Configuration

The number of workers is crucial for performance. Too few workers and you'll bottleneck on CPU. Too many and you'll run out of memory:

```php
// config/octane.php
'swoole' => [
    'options' => [
        'worker_num' => env('OCTANE_WORKERS', 4),
        'task_worker_num' => env('OCTANE_TASK_WORKERS', 6),
        'max_request' => env('OCTANE_MAX_REQUESTS', 1000),
        'package_max_length' => 10 * 1024 * 1024, // 10MB
    ],
],
```

The `max_request` setting is particularly important. It determines how many requests a worker handles before being recycled. This helps prevent memory leaks from accumulating over time.

### Database Connection Pooling

One of Octane's biggest advantages is connection pooling. Instead of creating new database connections for each request, Octane maintains a pool of reusable connections:

```php
'swoole' => [
    'options' => [
        'db_pool' => [
            'min_connections' => 1,
            'max_connections' => 10,
            'connect_timeout' => 10.0,
            'wait_timeout' => 3.0,
        ],
    ],
],
```

This dramatically reduces the overhead of establishing database connections, which can be one of the biggest performance bottlenecks in traditional PHP applications.

## Production Deployment Strategies

Running Octane in production requires some additional considerations compared to traditional Laravel deployments.

### Process Management

In production, you'll want to use a process manager like Supervisor to ensure your Octane workers stay running:

```ini
[program:octane]
process_name=%(program_name)s_%(process_num)02d
command=php /path/to/your/app/artisan octane:start --server=swoole --host=0.0.0.0 --port=8000 --workers=4
directory=/path/to/your/app
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/octane.log
```

### Load Balancing

For high-traffic applications, you can run multiple Octane instances behind a load balancer:

```nginx
upstream octane {
    server 127.0.0.1:8000;
    server 127.0.0.1:8001;
    server 127.0.0.1:8002;
    server 127.0.0.1:8003;
}

server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://octane;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Deployment and Hot Reloading

When deploying updates, you'll need to restart your Octane workers to pick up the changes:

```bash
php artisan octane:reload
```

For zero-downtime deployments, you can use a blue-green deployment strategy or gradually restart workers.

## Performance Testing and Monitoring

Before and after implementing Octane, you should measure the performance impact. Here's how to do proper performance testing:

### Benchmarking Tools

Use tools like Apache Bench or wrk to measure performance:

```bash
# Test traditional Laravel
ab -n 1000 -c 10 http://your-app.com/

# Test with Octane
ab -n 1000 -c 10 http://your-app.com:8000/
```

### Application Performance Monitoring

Implement monitoring to track key metrics:

```php
// Add to a middleware or service provider
use Illuminate\Support\Facades\Log;

class PerformanceMonitoring
{
    public function handle($request, Closure $next)
    {
        $start = microtime(true);

        $response = $next($request);

        $duration = microtime(true) - $start;

        if ($duration > 0.5) { // Log slow requests
            Log::warning('Slow request detected', [
                'url' => $request->url(),
                'duration' => $duration,
                'memory' => memory_get_peak_usage(true),
            ]);
        }

        return $response;
    }
}
```

For comprehensive monitoring strategies, explore our guide on [Laravel production monitoring and error tracking](/2025/09/laravel-production-monitoring-error-tracking.html).

## Common Pitfalls and How to Avoid Them

Octane introduces some new challenges that traditional Laravel developers might not be familiar with.

### Session and Cache Gotchas

Since workers are persistent, be careful with session and cache usage:

```php
// Problematic - sessions might not work as expected
class HomeController extends Controller
{
    public function index()
    {
        session(['last_visit' => now()]);
        // In Octane, this might not persist as expected
    }
}

// Better - be explicit about session handling
class HomeController extends Controller
{
    public function index()
    {
        session()->put('last_visit', now());
        session()->save(); // Explicitly save

        return view('home');
    }
}
```

### File Upload Handling

File uploads need special attention in Octane:

```php
public function uploadFile(Request $request)
{
    $file = $request->file('upload');

    // Make sure to move uploaded files properly
    $path = $file->store('uploads');

    // Clean up temporary files if needed
    if (file_exists($file->getPathname())) {
        unlink($file->getPathname());
    }

    return response()->json(['path' => $path]);
}
```

### Database Connection Issues

While connection pooling is great, be aware of potential issues:

```php
// Watch out for long-running queries that might timeout
DB::statement('SET SESSION wait_timeout = 300');

// Always use transactions properly
DB::transaction(function () {
    // Your database operations
});
```

## Real-World Performance Examples

Let's look at some real performance improvements you might see with Octane:

### API Endpoints

A typical API endpoint that fetches user data:

```php
// Before Octane: ~50ms response time
// After Octane: ~5ms response time

class UserApiController extends Controller
{
    public function show(User $user)
    {
        return response()->json([
            'user' => $user->load(['posts', 'profile']),
            'stats' => $user->calculateStats(),
        ]);
    }
}
```

### Database-Heavy Operations

Operations involving multiple database queries see dramatic improvements:

```php
// Before Octane: ~200ms for 100 records
// After Octane: ~20ms for 100 records

public function dashboard()
{
    $recentPosts = Post::with('author')->latest()->take(10)->get();
    $userStats = User::selectRaw('count(*) as total, avg(age) as avg_age')->first();
    $topCategories = Category::withCount('posts')->orderBy('posts_count', 'desc')->take(5)->get();

    return view('dashboard', compact('recentPosts', 'userStats', 'topCategories'));
}
```

To further optimize database operations, make sure you're avoiding [N+1 query problems](/2025/09/laravel-n-plus-one-query-problem-solution.html) which can still impact performance even with Octane.

## Security Considerations

Running long-lived processes introduces some security considerations that don't exist in traditional PHP applications.

### Memory Exposure

Since processes are long-lived, sensitive data might stay in memory longer:

```php
// Bad - sensitive data might persist
class AuthController extends Controller
{
    protected static $credentials = [];

    public function login(Request $request)
    {
        self::$credentials = $request->only(['email', 'password']);
        // This data stays in memory!
    }
}

// Good - don't store sensitive data in static properties
class AuthController extends Controller
{
    public function login(Request $request)
    {
        $credentials = $request->only(['email', 'password']);

        if (Auth::attempt($credentials)) {
            // Clear sensitive data immediately
            $credentials = null;
            return redirect()->intended();
        }

        return back()->withErrors(['email' => 'Invalid credentials']);
    }
}
```

### Process Isolation

Make sure your application handles process isolation properly, especially if you're processing user-uploaded content or executing dynamic code.

For comprehensive security practices when running high-performance Laravel applications, review our [Laravel security best practices guide](/2025/09/laravel-security-best-practices-production.html).

## When NOT to Use Octane

While Octane offers impressive performance improvements, it's not always the right choice:

### Applications with Heavy File I/O

If your application does a lot of file processing or manipulation, the benefits might be limited:

```php
// This type of operation won't see much improvement with Octane
public function processLargeFile(Request $request)
{
    $file = $request->file('data');
    $data = file_get_contents($file->path());

    // Heavy processing...
    $processed = $this->processData($data);

    return response()->download($this->generateReport($processed));
}
```

### Applications with Lots of External API Calls

If your app spends most of its time waiting for external APIs, Octane won't help much:

```php
// Octane can't speed up external API calls
public function fetchUserData($userId)
{
    $userData = Http::get("https://api.example.com/users/{$userId}");
    $profileData = Http::get("https://api.example.com/profiles/{$userId}");
    $settingsData = Http::get("https://api.example.com/settings/{$userId}");

    return view('user', compact('userData', 'profileData', 'settingsData'));
}
```

### Development Environments

For local development, traditional Laravel is often more convenient because you don't need to restart the server every time you make code changes.

## Conclusion

Laravel Octane represents a significant leap forward in PHP application performance. By keeping your application loaded in memory and reusing resources across requests, it can deliver performance improvements that were previously only possible with compiled languages or complex caching strategies.

The key to success with Octane is understanding how it changes the application lifecycle and adapting your coding practices accordingly. Pay attention to memory management, state isolation, and proper cleanup between requests.

While there's a learning curve and some additional complexity, the performance benefits are often worth it, especially for high-traffic applications or APIs. Start with a simple setup, measure your performance improvements, and gradually optimize based on your specific needs.

Remember that Octane is just one part of a comprehensive performance strategy. Combine it with proper database optimization, caching strategies, and code optimization for the best results. The combination of these techniques can transform a slow Laravel application into a high-performance powerhouse that can handle thousands of requests per second.
