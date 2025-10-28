---
title: 'Easy Background Processing Tutorial'
date: 2025-09-24T10:00:00+07:00
draft: false
url: /2025/09/laravel-queue-jobs-background-processing-tutorial.html
tags:
- Laravel
- Queue
- Background Jobs
- Performance
description: 'Laravel queue jobs tutorial for background processing. Complete guide to queue concepts and worker setup made simple.'
featured: false
faq:
  - question: "Should I use database, Redis, or SQS for Laravel queues?"
    answer: "Start with database driver for development and small apps--it requires no extra services and is simple to debug. Switch to Redis for production when you need better performance (10x+ faster than database), advanced features like delayed jobs, or horizontal scaling across multiple servers. Choose Amazon SQS when you need automatic scaling, managed infrastructure, or when already on AWS. Most production apps use Redis (via Laravel Horizon) for the best balance of performance, features, and ease of management. Avoid sync driver in production--it processes jobs immediately, defeating the purpose."
  - question: "What's the difference between dispatch() and dispatchSync() for queue jobs?"
    answer: "dispatch() queues the job to run in the background via queue workers, allowing your application to respond immediately while the job processes later. dispatchSync() runs the job immediately in the same request, blocking the response until complete--use only for testing or when you absolutely need immediate execution with rollback support. dispatchAfterResponse() queues the job but waits until after the HTTP response is sent, good for logging or cleanup that doesn't need full background processing. For async processing, always use dispatch(), not dispatchSync()."
  - question: "How do I prevent memory leaks in long-running queue workers?"
    answer: "Use --max-jobs=1000 to restart workers after processing 1000 jobs, --max-time=3600 to restart after 1 hour, and --memory=512 to stop when memory exceeds 512MB. In jobs, process large datasets with chunk(1000) instead of get()->each(), call unsetRelations() after processing models, and use gc_collect_cycles() for very large operations. Use Supervisor to automatically restart crashed workers. Horizon (for Redis) handles this automatically. Monitor with php artisan queue:monitor. Memory leaks occur when workers hold references to old models or data--restarting periodically prevents issues."
  - question: "Why are my queued jobs not processing?"
    answer: "Check: (1) Queue workers running? Run php artisan queue:work to start workers, use Supervisor in production for auto-restart. (2) Correct queue connection? Verify QUEUE_CONNECTION in .env matches your queue:work connection parameter. (3) Wrong queue name? Jobs on 'emails' queue won't process if worker listens to 'default'. (4) Failed migrations? Run php artisan migrate for jobs/failed_jobs tables. (5) Redis/SQS configured properly? Check connection details. Use php artisan queue:monitor and check storage/logs/laravel.log. Run php artisan queue:failed to see failed jobs."
  - question: "Should I pass Eloquent models or IDs to queue jobs?"
    answer: "Pass IDs and reload models inside the job's handle() method. SerializesModels trait serializes only the model ID, but the model's state (attributes, relationships) at queue time can become stale by execution time. Inside handle(), call User::find($this->userId) to get fresh data and check if (!$user) return; in case it was deleted. This prevents working with outdated data or missing records. Only pass entire models when you need specific snapshot data that shouldn't change, but this is rare. For most cases: pass IDs, load fresh in handle()."
  - question: "How do I handle failed queue jobs in production?"
    answer: "Implement a failed() method in your job to handle final failure after all retries exhausted--update status, notify users, alert admins. Set reasonable retry counts (public $tries = 3) and backoff delays (public $backoff = [10, 30, 60]). Monitor with php artisan queue:failed | grep 'Last 24h' in cron jobs. Use php artisan queue:retry all cautiously--understand why jobs failed first. Log failures with context: Log::error('Job failed', ['id' => $this->id, 'error' => $e->getMessage()]). Consider implementing a dashboard to review and retry failed jobs manually. Set up alerts when failed job count exceeds threshold."
---

Ever had a user complain that your app takes forever to send an email or process an image upload? Or maybe you've watched your response times crawl to a halt because you're trying to do too much work during a single request? Laravel queues are the solution you've been looking for, and they're easier to set up than you might think.

Think of Laravel queues as your app's personal assistant. Instead of making users wait while you send emails, resize images, or generate reports, you hand these tasks off to the background and let users continue with their day. The work still gets done, but it doesn't block the user experience.

Queue jobs are perfect for any task that doesn't need to happen immediately - and honestly, that's most tasks. Whether you're sending welcome emails, processing file uploads, generating PDFs, or hitting external APIs, queues can make your app feel snappy and responsive while handling the heavy lifting behind the scenes.

## Understanding Laravel Queues

Before we dive into the code, let's understand what's actually happening when you use Laravel queues. When a user triggers an action that normally takes time (like sending an email), instead of processing it immediately, Laravel puts that task into a queue - basically a to-do list.

Meanwhile, queue workers (separate processes) are constantly checking this to-do list and processing tasks one by one. The user gets an immediate response, and the work happens in the background without them having to wait.

Here's a simple example to illustrate the difference:

**Without Queues:**
1. User submits a form
2. App sends email (takes 3 seconds)
3. App resizes uploaded image (takes 2 seconds)
4. App saves data to database
5. User finally sees success message (after 5+ seconds)

**With Queues:**
1. User submits a form
2. App queues email job
3. App queues image resize job
4. App saves data to database
5. User sees success message (under 1 second)
6. Background workers handle email and image tasks

The difference in user experience is night and day.

## Queue Drivers and Configuration

Laravel supports several queue drivers, each with different strengths depending on your needs.

### Database Driver (Perfect for Starting Out)

The database driver stores jobs in your database - it's simple, requires no additional services, and perfect for getting started:

```php
// config/queue.php
'default' => env('QUEUE_CONNECTION', 'database'),

'connections' => [
    'database' => [
        'driver' => 'database',
        'table' => 'jobs',
        'queue' => 'default',
        'retry_after' => 90,
        'after_commit' => false,
    ],
],
```

Set up the database tables:

```bash
php artisan queue:table
php artisan queue:failed-table
php artisan migrate
```

### Redis Driver (Great for Production)

Redis is faster and more feature-rich, perfect for high-traffic applications:

```bash
# Install Redis PHP extension
composer require predis/predis
```

```php
// config/queue.php
'redis' => [
    'driver' => 'redis',
    'connection' => 'default',
    'queue' => env('REDIS_QUEUE', 'default'),
    'retry_after' => 90,
    'block_for' => null,
    'after_commit' => false,
],
```

### Amazon SQS Driver (Scalable Cloud Solution)

For applications that need to scale automatically:

```bash
composer require aws/aws-sdk-php
```

```php
// config/queue.php
'sqs' => [
    'driver' => 'sqs',
    'key' => env('AWS_ACCESS_KEY_ID'),
    'secret' => env('AWS_SECRET_ACCESS_KEY'),
    'prefix' => env('SQS_PREFIX', 'https://sqs.us-east-1.amazonaws.com/your-account-id'),
    'queue' => env('SQS_QUEUE', 'default'),
    'suffix' => env('SQS_SUFFIX'),
    'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    'after_commit' => false,
],
```

## Creating Your First Job

Let's create a job that sends a welcome email to new users. This is a perfect example because emails can be slow and users shouldn't have to wait for them.

Generate a new job:

```bash
php artisan make:job SendWelcomeEmail
```

This creates a job class in `app/Jobs/SendWelcomeEmail.php`:

```php
<?php

namespace App\Jobs;

use App\Models\User;
use App\Mail\WelcomeEmail;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Mail;

class SendWelcomeEmail implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $user;

    public function __construct(User $user)
    {
        $this->user = $user;
    }

    public function handle()
    {
        // Send the welcome email
        Mail::to($this->user->email)->send(new WelcomeEmail($this->user));
    }
}
```

Now, instead of sending the email directly in your controller, dispatch the job:

```php
// In your controller
public function register(Request $request)
{
    $user = User::create($request->validated());

    // Instead of: Mail::to($user->email)->send(new WelcomeEmail($user));
    SendWelcomeEmail::dispatch($user);

    return redirect()->route('dashboard')->with('success', 'Account created successfully!');
}
```

The user sees the success message immediately, and the email gets sent in the background.

## Job Properties and Configuration

Laravel jobs are highly configurable. Here are the most important properties you should know about:

### Queue Assignment

You can organize jobs into different queues based on priority or type:

```php
class SendWelcomeEmail implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    // Specify which queue this job should go to
    public $queue = 'emails';

    // Or set it when dispatching
    // SendWelcomeEmail::dispatch($user)->onQueue('high-priority');
}
```

### Retry Configuration

Control how many times a job should be retried if it fails:

```php
class ProcessPayment implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    // Retry up to 3 times
    public $tries = 3;

    // Wait 30 seconds between retries
    public $backoff = 30;

    // Or use exponential backoff
    public function backoff()
    {
        return [1, 5, 10, 30]; // Seconds between retries
    }
}
```

### Timeout Configuration

Prevent jobs from running too long:

```php
class GenerateReport implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    // Job will be killed if it runs longer than 120 seconds
    public $timeout = 120;

    // Handle timeout gracefully
    public function timeoutAt()
    {
        return now()->addMinutes(5);
    }
}
```

## Advanced Job Types and Patterns

### Job Batching

Sometimes you need to process many related jobs and know when they're all done:

```php
use Illuminate\Bus\Batch;
use Illuminate\Support\Facades\Bus;

// Process 1000 emails in batches
$jobs = [];
foreach ($users as $user) {
    $jobs[] = new SendNewsletterEmail($user);
}

$batch = Bus::batch($jobs)
    ->then(function (Batch $batch) {
        // All jobs completed successfully
        Log::info('Newsletter batch completed', ['batch_id' => $batch->id]);
    })
    ->catch(function (Batch $batch, Throwable $e) {
        // First batch job failure
        Log::error('Newsletter batch failed', ['batch_id' => $batch->id, 'error' => $e->getMessage()]);
    })
    ->finally(function (Batch $batch) {
        // Batch has finished executing (success or failure)
        NotificationService::notifyAdmins('Newsletter batch finished');
    })
    ->dispatch();

return response()->json(['batch_id' => $batch->id]);
```

### Job Chains

When jobs need to run in a specific order:

```php
use Illuminate\Support\Facades\Bus;

// Process an order: charge payment -> update inventory -> send confirmation
Bus::chain([
    new ProcessPayment($order),
    new UpdateInventory($order),
    new SendOrderConfirmation($order),
])->dispatch();
```

If any job in the chain fails, the remaining jobs won't run.

### Conditional Job Dispatching

Only queue jobs when certain conditions are met:

```php
class SendPromotionalEmail implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $user;

    public function __construct(User $user)
    {
        $this->user = $user;
    }

    // Don't queue if user has unsubscribed
    public function shouldQueue()
    {
        return $this->user->email_notifications_enabled;
    }

    public function handle()
    {
        if (!$this->user->email_notifications_enabled) {
            return; // Exit early if user has unsubscribed since queuing
        }

        Mail::to($this->user->email)->send(new PromotionalEmail($this->user));
    }
}
```

## Queue Workers and Processing

Queue workers are the engines that actually process your jobs. Understanding how they work helps you optimize performance and avoid common pitfalls.

### Starting Workers

Start a worker to process jobs:

```bash
# Process jobs from the default queue
php artisan queue:work

# Process specific queues in order of priority
php artisan queue:work --queue=high-priority,emails,default

# Process jobs with memory and timeout limits
php artisan queue:work --memory=512 --timeout=60
```

### Worker Configuration

Configure workers for your specific needs:

```bash
# Process only 10 jobs before restarting (prevents memory leaks)
php artisan queue:work --max-jobs=10

# Process jobs for 1 hour before restarting
php artisan queue:work --max-time=3600

# Sleep for 5 seconds when no jobs are available
php artisan queue:work --sleep=5

# Restart workers gracefully when they finish current job
php artisan queue:restart
```

### Production Worker Setup

In production, use a process manager like Supervisor to keep workers running:

```ini
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /path/to/your/app/artisan queue:work redis --sleep=3 --tries=3 --max-time=3600
directory=/path/to/your/app
user=www-data
numprocs=8
redirect_stderr=true
stdout_logfile=/var/log/laravel-worker.log
stopwaitsecs=3600
```

This configuration runs 8 worker processes, automatically restarts them if they crash, and logs their output.

## Error Handling and Failed Jobs

Not all jobs succeed on the first try. Laravel provides robust error handling to deal with failures gracefully.

### Handling Job Failures

Add a `failed` method to handle job failures:

```php
class ProcessPayment implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $order;
    public $tries = 3;

    public function __construct(Order $order)
    {
        $this->order = $order;
    }

    public function handle()
    {
        $paymentService = new PaymentService();

        try {
            $paymentService->charge($this->order);
            $this->order->update(['status' => 'paid']);
        } catch (PaymentException $e) {
            // Log the error with context
            Log::error('Payment processing failed', [
                'order_id' => $this->order->id,
                'error' => $e->getMessage(),
                'attempt' => $this->attempts(),
            ]);

            // Re-throw to trigger retry mechanism
            throw $e;
        }
    }

    public function failed(Throwable $exception)
    {
        // Handle job failure after all retries are exhausted
        $this->order->update(['status' => 'payment_failed']);

        // Notify the user
        Mail::to($this->order->user->email)->send(new PaymentFailedEmail($this->order));

        // Alert administrators
        Log::alert('Payment processing failed permanently', [
            'order_id' => $this->order->id,
            'user_id' => $this->order->user_id,
            'error' => $exception->getMessage(),
        ]);
    }
}
```

### Managing Failed Jobs

Laravel tracks failed jobs automatically. You can view and manage them:

```bash
# List all failed jobs
php artisan queue:failed

# Retry a specific failed job
php artisan queue:retry 1

# Retry all failed jobs
php artisan queue:retry all

# Delete a failed job
php artisan queue:forget 1

# Clear all failed jobs
php artisan queue:flush
```

### Custom Failed Job Handling

Create custom logic for handling failed jobs:

```php
// In a controller or command
public function retryFailedJobs()
{
    $failedJobs = DB::table('failed_jobs')
        ->where('failed_at', '>', now()->subDay()) // Only recent failures
        ->get();

    foreach ($failedJobs as $failedJob) {
        $payload = json_decode($failedJob->payload, true);

        // Only retry certain types of jobs
        if (str_contains($payload['displayName'], 'SendEmail')) {
            Artisan::call('queue:retry', ['id' => $failedJob->id]);
        }
    }
}
```

## Real-World Job Examples

Let's look at some practical job examples you'll likely need in real applications.

### Image Processing Job

```php
class ProcessImageUpload implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $imagePath;
    protected $userId;
    public $timeout = 300; // 5 minutes for large images

    public function __construct($imagePath, $userId)
    {
        $this->imagePath = $imagePath;
        $this->userId = $userId;
    }

    public function handle()
    {
        $image = Image::make(storage_path('app/' . $this->imagePath));

        // Create different sizes
        $sizes = [
            'thumbnail' => [150, 150],
            'medium' => [500, 500],
            'large' => [1200, 1200],
        ];

        foreach ($sizes as $name => $dimensions) {
            $resized = $image->fit($dimensions[0], $dimensions[1]);
            $filename = $name . '_' . basename($this->imagePath);
            $resized->save(storage_path('app/images/' . $filename));
        }

        // Update user's profile with processed images
        User::find($this->userId)->update([
            'avatar_processed' => true,
            'processing_completed_at' => now(),
        ]);
    }

    public function failed(Throwable $exception)
    {
        User::find($this->userId)->update([
            'avatar_processing_failed' => true,
        ]);

        Log::error('Image processing failed', [
            'user_id' => $this->userId,
            'image_path' => $this->imagePath,
            'error' => $exception->getMessage(),
        ]);
    }
}
```

### PDF Generation Job

```php
class GenerateInvoicePDF implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $invoice;
    public $queue = 'reports'; // Use a dedicated queue for reports

    public function __construct(Invoice $invoice)
    {
        $this->invoice = $invoice;
    }

    public function handle()
    {
        $pdf = PDF::loadView('invoices.pdf', [
            'invoice' => $this->invoice,
            'company' => $this->invoice->company,
            'items' => $this->invoice->items,
        ]);

        $filename = "invoice-{$this->invoice->number}.pdf";
        $path = "invoices/{$filename}";

        // Save PDF to storage
        Storage::put($path, $pdf->output());

        // Update invoice with PDF path
        $this->invoice->update([
            'pdf_path' => $path,
            'pdf_generated_at' => now(),
        ]);

        // Email PDF to customer
        Mail::to($this->invoice->customer->email)
            ->send(new InvoicePDFReady($this->invoice, $path));
    }
}
```

### Data Export Job

```php
class ExportUsersToCSV implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $filters;
    protected $requestedBy;
    public $timeout = 600; // 10 minutes for large exports

    public function __construct(array $filters, User $requestedBy)
    {
        $this->filters = $filters;
        $this->requestedBy = $requestedBy;
    }

    public function handle()
    {
        $filename = 'users_export_' . now()->format('Y_m_d_H_i_s') . '.csv';
        $path = "exports/{$filename}";

        $query = User::query();

        // Apply filters
        if (!empty($this->filters['created_after'])) {
            $query->where('created_at', '>=', $this->filters['created_after']);
        }

        if (!empty($this->filters['role'])) {
            $query->where('role', $this->filters['role']);
        }

        // Stream large datasets to avoid memory issues
        $file = fopen(storage_path('app/' . $path), 'w');
        fputcsv($file, ['ID', 'Name', 'Email', 'Created At', 'Role']);

        $query->chunk(1000, function ($users) use ($file) {
            foreach ($users as $user) {
                fputcsv($file, [
                    $user->id,
                    $user->name,
                    $user->email,
                    $user->created_at->format('Y-m-d H:i:s'),
                    $user->role,
                ]);
            }
        });

        fclose($file);

        // Notify user that export is ready
        Mail::to($this->requestedBy->email)
            ->send(new ExportReady($filename, $path));
    }
}
```

For comprehensive performance optimization when working with large datasets, check out our [Laravel performance optimization guide](/2025/09/laravel-performance-optimization-15-techniques.html).

## Queue Monitoring and Debugging

Monitoring your queues is crucial for maintaining a healthy application. Here are the tools and techniques you need.

### Basic Queue Monitoring

Check queue status and job counts:

```bash
# Check queue status
php artisan queue:monitor

# View queue statistics
php artisan queue:work --verbose

# Check specific queue
php artisan queue:size redis:high-priority
```

### Custom Queue Monitoring

Create your own monitoring dashboard:

```php
class QueueMonitoringController extends Controller
{
    public function dashboard()
    {
        $queueStats = [
            'pending_jobs' => $this->getPendingJobsCount(),
            'failed_jobs' => $this->getFailedJobsCount(),
            'processed_today' => $this->getProcessedJobsToday(),
            'average_processing_time' => $this->getAverageProcessingTime(),
            'queue_sizes' => $this->getQueueSizes(),
        ];

        return view('admin.queue-dashboard', compact('queueStats'));
    }

    protected function getPendingJobsCount()
    {
        return DB::table('jobs')->count();
    }

    protected function getFailedJobsCount()
    {
        return DB::table('failed_jobs')
            ->where('failed_at', '>', now()->subDay())
            ->count();
    }

    protected function getQueueSizes()
    {
        $queues = ['default', 'emails', 'high-priority', 'reports'];
        $sizes = [];

        foreach ($queues as $queue) {
            $sizes[$queue] = DB::table('jobs')
                ->where('queue', $queue)
                ->count();
        }

        return $sizes;
    }
}
```

### Queue Health Checks

Monitor queue health automatically:

```php
class QueueHealthCheck extends Command
{
    protected $signature = 'queue:health-check';
    protected $description = 'Check queue health and alert if issues found';

    public function handle()
    {
        $this->checkQueueSize();
        $this->checkFailedJobs();
        $this->checkOldJobs();
        $this->checkWorkerStatus();
    }

    protected function checkQueueSize()
    {
        $pendingJobs = DB::table('jobs')->count();

        if ($pendingJobs > 1000) {
            $this->alert("High queue backlog: {$pendingJobs} pending jobs");

            // Send notification to team
            Notification::route('slack', config('monitoring.slack_webhook'))
                ->notify(new QueueBacklogAlert($pendingJobs));
        }
    }

    protected function checkFailedJobs()
    {
        $recentFailures = DB::table('failed_jobs')
            ->where('failed_at', '>', now()->subHour())
            ->count();

        if ($recentFailures > 10) {
            $this->alert("High failure rate: {$recentFailures} jobs failed in the last hour");
        }
    }

    protected function checkOldJobs()
    {
        $oldJobs = DB::table('jobs')
            ->where('created_at', '<', now()->subHours(6))
            ->count();

        if ($oldJobs > 0) {
            $this->warn("Found {$oldJobs} jobs older than 6 hours - workers may not be running");
        }
    }
}
```

For detailed monitoring and alerting strategies, explore our [Laravel production monitoring guide](/2025/09/laravel-production-monitoring-error-tracking.html).

## Performance Optimization

As your application grows, you'll need to optimize queue performance. Here are proven strategies.

### Queue Prioritization

Process important jobs first:

```php
// In your worker command
php artisan queue:work --queue=critical,high,normal,low

// Or in your job
class UrgentNotification implements ShouldQueue
{
    public $queue = 'critical';

    // This job will be processed before others
}
```

### Memory Management

Prevent memory leaks in long-running workers:

```php
class ProcessLargeDataset implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $datasetId;

    public function handle()
    {
        $dataset = Dataset::find($this->datasetId);

        // Process in chunks to manage memory
        $dataset->records()->chunk(1000, function ($records) {
            foreach ($records as $record) {
                $this->processRecord($record);
            }

            // Force garbage collection for large datasets
            if (memory_get_usage() > 100 * 1024 * 1024) { // 100MB
                gc_collect_cycles();
            }
        });

        // Clear any loaded relationships to free memory
        $dataset->unsetRelations();
    }
}
```

### Database Connection Management

Handle database connections properly in queued jobs:

```php
class DatabaseIntensiveJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function handle()
    {
        try {
            // Your database operations here
            $this->performDatabaseOperations();
        } finally {
            // Disconnect to prevent connection leaks
            DB::disconnect();
        }
    }
}
```

### Horizon for Redis Queues

If you're using Redis, Laravel Horizon provides a beautiful dashboard and auto-scaling:

```bash
composer require laravel/horizon
php artisan horizon:install
php artisan migrate
```

Configure Horizon for auto-scaling:

```php
// config/horizon.php
'environments' => [
    'production' => [
        'supervisor-1' => [
            'connection' => 'redis',
            'queue' => ['default'],
            'balance' => 'auto',
            'autoScalingStrategy' => 'time',
            'minProcesses' => 1,
            'maxProcesses' => 10,
            'balanceMaxShift' => 1,
            'balanceCooldown' => 3,
            'tries' => 3,
        ],
    ],
],
```

## Testing Queue Jobs

Testing queued jobs requires special considerations since they run asynchronously.

### Testing Job Dispatch

Test that jobs are queued correctly:

```php
class UserRegistrationTest extends TestCase
{
    public function test_welcome_email_is_queued_after_registration()
    {
        Queue::fake();

        $userData = [
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => 'password',
        ];

        $response = $this->post('/register', $userData);

        $response->assertStatus(302);
        Queue::assertPushed(SendWelcomeEmail::class);
    }

    public function test_welcome_email_job_has_correct_user()
    {
        Queue::fake();

        $user = User::factory()->create();
        SendWelcomeEmail::dispatch($user);

        Queue::assertPushed(SendWelcomeEmail::class, function ($job) use ($user) {
            return $job->user->id === $user->id;
        });
    }
}
```

### Testing Job Execution

Test the actual job logic:

```php
class SendWelcomeEmailTest extends TestCase
{
    public function test_welcome_email_is_sent()
    {
        Mail::fake();

        $user = User::factory()->create();
        $job = new SendWelcomeEmail($user);

        $job->handle();

        Mail::assertSent(WelcomeEmail::class, function ($mail) use ($user) {
            return $mail->hasTo($user->email);
        });
    }

    public function test_job_handles_invalid_user()
    {
        $user = User::factory()->create();
        $user->delete(); // Simulate deleted user

        $job = new SendWelcomeEmail($user);

        // Should not throw exception
        $this->assertNull($job->handle());
    }
}
```

### Testing Failed Jobs

Test failure scenarios:

```php
class ProcessPaymentTest extends TestCase
{
    public function test_job_fails_gracefully_with_invalid_payment()
    {
        $order = Order::factory()->create();
        $job = new ProcessPayment($order);

        // Mock payment service to throw exception
        $this->mock(PaymentService::class, function ($mock) {
            $mock->shouldReceive('charge')->andThrow(new PaymentException('Invalid card'));
        });

        $this->expectException(PaymentException::class);
        $job->handle();
    }

    public function test_failed_method_updates_order_status()
    {
        $order = Order::factory()->create();
        $job = new ProcessPayment($order);

        $exception = new PaymentException('Payment failed');
        $job->failed($exception);

        $this->assertEquals('payment_failed', $order->fresh()->status);
    }
}
```

## Security Considerations

Queue jobs can access sensitive data and perform critical operations, so security is important.

### Input Validation

Always validate data in your jobs:

```php
class ProcessUserData implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $userData;

    public function __construct(array $userData)
    {
        $this->userData = $userData;
    }

    public function handle()
    {
        // Validate data even in background jobs
        $validator = Validator::make($this->userData, [
            'email' => 'required|email',
            'name' => 'required|string|max:255',
            'age' => 'integer|min:0|max:150',
        ]);

        if ($validator->fails()) {
            Log::error('Invalid data in job', [
                'data' => $this->userData,
                'errors' => $validator->errors(),
            ]);
            return;
        }

        // Process validated data
        $this->processValidatedData($validator->validated());
    }
}
```

### Authorization Checks

Ensure jobs respect user permissions:

```php
class DeleteUserAccount implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $userId;
    protected $requestedByUserId;

    public function __construct($userId, $requestedByUserId)
    {
        $this->userId = $userId;
        $this->requestedByUserId = $requestedByUserId;
    }

    public function handle()
    {
        $user = User::find($this->userId);
        $requestedBy = User::find($this->requestedByUserId);

        // Check if user still exists and requester has permission
        if (!$user || !$requestedBy) {
            Log::warning('User deletion job failed - user not found', [
                'user_id' => $this->userId,
                'requested_by' => $this->requestedByUserId,
            ]);
            return;
        }

        // Only admins or the user themselves can delete accounts
        if ($requestedBy->id !== $user->id && !$requestedBy->isAdmin()) {
            Log::warning('Unauthorized user deletion attempt', [
                'user_id' => $this->userId,
                'requested_by' => $this->requestedByUserId,
            ]);
            return;
        }

        // Proceed with deletion
        $user->delete();
    }
}
```

### Sensitive Data Handling

Be careful with sensitive data in jobs:

```php
class ProcessCreditCard implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $encryptedCardData;
    protected $orderId;

    public function __construct($cardData, $orderId)
    {
        // Encrypt sensitive data before queuing
        $this->encryptedCardData = encrypt($cardData);
        $this->orderId = $orderId;
    }

    public function handle()
    {
        try {
            // Decrypt data when processing
            $cardData = decrypt($this->encryptedCardData);

            // Process payment
            $this->processPayment($cardData);

        } finally {
            // Clear sensitive data from memory
            $this->encryptedCardData = null;
            $cardData = null;
        }
    }

    // Don't store sensitive data in failed jobs table
    public function failed(Throwable $exception)
    {
        Log::error('Payment processing failed', [
            'order_id' => $this->orderId,
            'error' => $exception->getMessage(),
            // Don't log card data!
        ]);
    }
}
```

For comprehensive security practices, review our [Laravel security best practices guide](/2025/09/laravel-security-best-practices-production.html).

## Common Pitfalls and Solutions

Here are the most common issues developers face with Laravel queues and how to solve them.

### Memory Leaks in Workers

Long-running workers can accumulate memory. Solution:

```bash
# Restart workers periodically
php artisan queue:work --max-jobs=1000 --max-time=3600

# Monitor memory usage
php artisan queue:work --memory=512
```

### Database Connection Timeouts

Workers that run for hours may lose database connections:

```php
class LongRunningJob implements ShouldQueue
{
    public function handle()
    {
        try {
            // Check connection before database operations
            DB::reconnect();

            // Your database operations
            $this->performDatabaseWork();

        } catch (QueryException $e) {
            // Retry with fresh connection
            DB::reconnect();
            $this->performDatabaseWork();
        }
    }
}
```

### Job Serialization Issues

Be careful with what you pass to jobs:

```php
// Bad - Eloquent models can become stale
class BadJob implements ShouldQueue
{
    protected $user; // This user data can become outdated

    public function __construct(User $user)
    {
        $this->user = $user; // Serializes entire model
    }
}

// Good - Pass IDs and reload fresh data
class GoodJob implements ShouldQueue
{
    protected $userId;

    public function __construct($userId)
    {
        $this->userId = $userId; // Only store ID
    }

    public function handle()
    {
        $user = User::find($this->userId); // Load fresh data
        if (!$user) {
            Log::warning('User not found in job', ['user_id' => $this->userId]);
            return;
        }

        // Work with fresh user data
    }
}
```

### Duplicate Job Prevention

Prevent the same job from being queued multiple times:

```php
class SendDailyReport implements ShouldQueue, ShouldBeUnique
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $date;

    public function __construct($date)
    {
        $this->date = $date;
    }

    // Define uniqueness
    public function uniqueId()
    {
        return 'daily-report-' . $this->date;
    }

    // How long to maintain uniqueness lock
    public function uniqueFor()
    {
        return 3600; // 1 hour
    }
}
```

## Conclusion

Laravel queues are one of those features that seem complex at first but become indispensable once you understand them. They're the key to building responsive applications that can handle heavy workloads without making users wait.

Start simple with the database driver for development and testing. As your needs grow, move to Redis for better performance or SQS for cloud scalability. Focus on these fundamentals:

- Queue time-consuming tasks like emails, file processing, and API calls
- Use proper error handling and retry logic
- Monitor your queues to catch issues early
- Test your jobs thoroughly
- Be mindful of security when handling sensitive data

The difference between a sluggish app and a snappy one often comes down to smart use of background processing. With Laravel's queue system, you have all the tools you need to build applications that feel fast and responsive, no matter how much work they're doing behind the scenes.

Remember, the best queue implementation is one that your users never notice - they just know your app feels fast and reliable. Start implementing queues in your next project, and your users (and your servers) will thank you for it.
