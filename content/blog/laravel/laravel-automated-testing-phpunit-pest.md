---
title: 'How to Set Up Automated Testing in Laravel with PHPUnit and Pest'
date: 2025-10-23T14:00:00+07:00
draft: false
url: /2025/10/how-to-set-up-automated-testing-laravel-phpunit-pest.html
tags:
- Laravel
- Testing
- PHPUnit
- Pest
- TDD
- Quality
description: 'Complete guide to automated testing in Laravel using PHPUnit and Pest. Learn feature tests, unit tests, database testing, factories, mocking, API testing, and CI/CD integration for reliable Laravel applications.'
keywords: ['laravel testing','phpunit laravel','pest php','laravel feature tests','laravel unit tests','database testing','laravel factories','test driven development','laravel mocking','ci cd testing']
featured: false
faq:
  - question: "What is the difference between feature tests and unit tests in Laravel?"
    answer: "Unit tests focus on small, isolated pieces of code like a single method or class without dependencies. They test logic in isolation, often with mocked dependencies. Feature tests test larger flows like complete HTTP requests, database interactions, and multiple components working together. For example, a unit test checks if a calculateTotal() method returns the right number. A feature test submits a form, checks the database was updated, and verifies the HTTP response. Use unit tests for business logic and helper functions. Use feature tests for user-facing flows and API endpoints. Most Laravel apps need more feature tests than unit tests."
  - question: "Should I use PHPUnit or Pest for Laravel testing?"
    answer: "Both work great. PHPUnit is the standard, well-documented, and has more resources available. Pest is built on PHPUnit but offers cleaner, more readable syntax inspired by Jest and RSpec. Pest code is shorter and feels more natural. You can mix both in the same project - Pest can run PHPUnit tests. For new projects, try Pest. It has better built-in features like parallel testing, architecture tests, and snapshots. For existing projects with PHPUnit tests, you can keep them or gradually migrate. The test logic is the same, only syntax differs."
  - question: "How do I test database interactions without affecting my production database?"
    answer: "Laravel uses a separate test database. Set DB_DATABASE to a test database in phpunit.xml or .env.testing. Use the RefreshDatabase trait in your tests - it migrates a fresh database before each test and rolls back after. This ensures tests don't interfere with each other. Alternatively, use DatabaseTransactions trait which wraps each test in a transaction and rolls it back, which is faster but doesn't catch migration issues. Never point tests at your production database. Always use factories to create test data instead of seeders to keep tests independent and fast."
  - question: "What should I test and what should I skip in Laravel applications?"
    answer: "Test your business logic, controllers, API endpoints, authentication flows, authorization rules, form validation, database queries, and any critical user flows. Skip testing framework code (Laravel's validation, routing, ORM), simple getters/setters, private methods (test through public methods), config files, and views without logic. Focus on code that can break or has happened to break before. Aim for 70-80% code coverage of important code, not 100% of everything. Write tests for bugs before fixing them to prevent regressions. Test what provides value, not just to hit coverage numbers."
  - question: "How do I mock external API calls in Laravel tests?"
    answer: "Use Laravel's Http::fake() to mock HTTP requests. Call Http::fake() before your test code, then assert requests were made with Http::assertSent(). For other services, use mockery or Laravel's mock() helper. Mock in the service container: $this->mock(PaymentService::class, function ($mock) { $mock->shouldReceive('charge')->andReturn(true); }). Only mock external dependencies you don't control (APIs, payment gateways). Don't mock your own code - use real instances and test the actual logic. Mocking too much makes tests brittle and less valuable."
  - question: "How do I run tests automatically on every commit with CI/CD?"
    answer: "Set up GitHub Actions, GitLab CI, or your CI tool to run tests on push. Create .github/workflows/tests.yml in your repo. Install dependencies with composer install, copy .env.testing, generate app key, run migrations, and execute php artisan test or vendor/bin/pest. Cache Composer dependencies to speed up builds. Run tests in parallel with --parallel flag. Fail the build if tests fail, blocking merges to main. Add test coverage reporting with --coverage flag. Run tests on pull requests before review. This catches bugs before they reach production."
---

Automated testing catches bugs before users see them. Laravel makes testing easy with built-in support for PHPUnit and Pest. You write tests that run your code and check the results match what you expect. When you change something, run the tests to make sure nothing broke.

This guide shows you how to set up testing in Laravel, write feature tests for HTTP endpoints, write unit tests for business logic, test databases with factories, mock external services, test APIs, and integrate tests into your deployment pipeline.

<!--readmore-->

## Why automated testing matters

Manual testing is slow and error-prone. You can't manually test every feature after every change. Automated tests run in seconds and catch regressions.

Benefits:
- Catch bugs before deployment
- Refactor with confidence - tests tell you if you broke something
- Document how your code should work
- Speed up development - tests are faster than manual clicking
- Enable continuous deployment - deploy automatically when tests pass

Write tests for code that matters. Don't aim for 100% coverage. Focus on business logic, critical user flows, and anything that's broken before.

## Laravel's test structure

Laravel includes two test directories:
- `tests/Feature` - test complete features like HTTP requests, database operations, full flows
- `tests/Unit` - test individual methods and classes in isolation

Feature tests are more valuable. They test real user scenarios. Unit tests are for complex business logic that needs isolation.

Laravel uses PHPUnit by default. The `phpunit.xml` file in your project root configures how tests run.

## Install Pest (optional but recommended)

Pest offers cleaner syntax than PHPUnit. Install it:

```bash
composer require pestphp/pest --dev --with-all-dependencies
composer require pestphp/pest-plugin-laravel --dev
php artisan pest:install
```

This adds Pest configuration to your project. You can use Pest and PHPUnit tests in the same project.

## Write your first feature test

Generate a test:

```bash
php artisan make:test PostTest
```

This creates `tests/Feature/PostTest.php`. With PHPUnit:

```php
<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\Post;
use Illuminate\Foundation\Testing\RefreshDatabase;

class PostTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_create_post()
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)->post('/posts', [
            'title' => 'My First Post',
            'body' => 'This is the post content.',
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('posts', [
            'title' => 'My First Post',
            'user_id' => $user->id,
        ]);
    }
}
```

With Pest:

```php
<?php

use App\Models\User;
use App\Models\Post;

use function Pest\Laravel\actingAs;
use function Pest\Laravel\post;
use function Pest\Laravel\assertDatabaseHas;

it('allows authenticated users to create posts', function () {
    $user = User::factory()->create();

    $response = actingAs($user)->post('/posts', [
        'title' => 'My First Post',
        'body' => 'This is the post content.',
    ]);

    $response->assertStatus(201);
    assertDatabaseHas('posts', [
        'title' => 'My First Post',
        'user_id' => $user->id,
    ]);
});
```

Run tests:

```bash
php artisan test
# or
./vendor/bin/pest
```

## Understanding RefreshDatabase

The `RefreshDatabase` trait (PHPUnit) or `uses(RefreshDatabase::class)` (Pest) runs migrations before tests and rolls back after each test.

This gives you a clean database for every test. Tests don't interfere with each other.

For Pest, add to `tests/Pest.php`:

```php
uses(Tests\TestCase::class, Illuminate\Foundation\Testing\RefreshDatabase::class)
    ->in('Feature');
```

Now all feature tests automatically use RefreshDatabase.

For faster tests, use `DatabaseTransactions` instead. It wraps tests in transactions and rolls them back instead of migrating. The tradeoff: it doesn't catch migration bugs.

## Create test data with factories

Don't create test records manually. Use factories:

```bash
php artisan make:factory PostFactory
```

Define the factory in `database/factories/PostFactory.php`:

```php
<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;

class PostFactory extends Factory
{
    public function definition()
    {
        return [
            'title' => fake()->sentence(),
            'body' => fake()->paragraphs(3, true),
            'published_at' => fake()->dateTimeBetween('-1 month', 'now'),
        ];
    }

    public function draft()
    {
        return $this->state(fn (array $attributes) => [
            'published_at' => null,
        ]);
    }
}
```

Use in tests:

```php
// Create one post
$post = Post::factory()->create();

// Create multiple posts
$posts = Post::factory()->count(10)->create();

// Create draft post using state
$draft = Post::factory()->draft()->create();

// Create with specific attributes
$post = Post::factory()->create([
    'title' => 'Custom Title',
]);

// Create with relationships
$post = Post::factory()
    ->for(User::factory())
    ->has(Comment::factory()->count(3))
    ->create();
```

Factories keep tests fast and readable. Change factory definitions once and all tests update.

## Write unit tests

Unit tests check small pieces of logic in isolation.

```bash
php artisan make:test --unit CalculatorTest
```

PHPUnit example:

```php
<?php

namespace Tests\Unit;

use PHPUnit\Framework\TestCase;
use App\Services\Calculator;

class CalculatorTest extends TestCase
{
    public function test_it_calculates_total_with_tax()
    {
        $calculator = new Calculator();
        $total = $calculator->calculateWithTax(100, 0.15);

        $this->assertEquals(115, $total);
    }
}
```

Pest example:

```php
<?php

use App\Services\Calculator;

it('calculates total with tax', function () {
    $calculator = new Calculator();
    $total = $calculator->calculateWithTax(100, 0.15);

    expect($total)->toBe(115.0);
});
```

Unit tests use plain PHPUnit TestCase, not Laravel's TestCase. They don't boot Laravel or touch the database. This makes them fast.

## Test HTTP responses

Laravel provides assertions for HTTP responses:

```php
$response = $this->get('/posts');

$response->assertOk(); // 200
$response->assertStatus(201); // specific status
$response->assertRedirect('/posts/1'); // redirect
$response->assertJson(['title' => 'My Post']); // JSON response
$response->assertJsonStructure(['data' => ['id', 'title']]); // JSON structure
$response->assertJsonCount(10, 'data'); // array count
$response->assertSee('My Post'); // HTML content
$response->assertDontSee('Secret'); // not in response
```

Test validation errors:

```php
$response = $this->post('/posts', [
    'title' => '', // empty title
    'body' => 'Content',
]);

$response->assertStatus(422);
$response->assertJsonValidationErrors(['title']);
```

## Test authentication and authorization

Test login:

```php
it('allows users to log in with valid credentials', function () {
    $user = User::factory()->create([
        'password' => bcrypt('password123'),
    ]);

    $response = post('/login', [
        'email' => $user->email,
        'password' => 'password123',
    ]);

    $response->assertRedirect('/dashboard');
    expect(auth()->check())->toBeTrue();
});
```

Test protected routes:

```php
it('blocks guests from accessing dashboard', function () {
    $response = get('/dashboard');

    $response->assertRedirect('/login');
});

it('allows authenticated users to access dashboard', function () {
    $user = User::factory()->create();

    $response = actingAs($user)->get('/dashboard');

    $response->assertOk();
});
```

Test authorization with roles:

```php
it('prevents non-admins from deleting posts', function () {
    $user = User::factory()->create();
    $post = Post::factory()->create();

    $response = actingAs($user)->delete("/posts/{$post->id}");

    $response->assertForbidden();
});
```

## Mock external services

Don't hit real APIs in tests. Mock them:

```php
use Illuminate\Support\Facades\Http;

it('fetches weather data from API', function () {
    Http::fake([
        'api.weather.com/*' => Http::response([
            'temperature' => 72,
            'condition' => 'sunny',
        ], 200),
    ]);

    $service = new WeatherService();
    $weather = $service->getCurrentWeather('New York');

    expect($weather['temperature'])->toBe(72);

    Http::assertSent(function ($request) {
        return $request->url() === 'https://api.weather.com/current?city=New+York';
    });
});
```

Mock your own classes with Laravel's mock helper:

```php
it('charges user via payment service', function () {
    $this->mock(PaymentService::class, function ($mock) {
        $mock->shouldReceive('charge')
            ->once()
            ->with(100)
            ->andReturn(true);
    });

    $service = app(OrderService::class);
    $result = $service->createOrder(['total' => 100]);

    expect($result)->toBeTrue();
});
```

Only mock external dependencies you don't control. Test your own code with real instances.

## Test databases with assertions

Check records exist:

```php
use function Pest\Laravel\assertDatabaseHas;
use function Pest\Laravel\assertDatabaseMissing;

it('stores post in database', function () {
    $user = User::factory()->create();

    actingAs($user)->post('/posts', [
        'title' => 'My Post',
        'body' => 'Content',
    ]);

    assertDatabaseHas('posts', [
        'title' => 'My Post',
        'user_id' => $user->id,
    ]);
});

it('deletes post from database', function () {
    $post = Post::factory()->create();

    delete("/posts/{$post->id}");

    assertDatabaseMissing('posts', ['id' => $post->id]);
});
```

Count records:

```php
assertDatabaseCount('posts', 5);
```

Test soft deletes:

```php
use function Pest\Laravel\assertSoftDeleted;

it('soft deletes posts', function () {
    $post = Post::factory()->create();

    delete("/posts/{$post->id}");

    assertSoftDeleted('posts', ['id' => $post->id]);
});
```

## Test JSON APIs

For API endpoints:

```php
it('returns paginated posts as JSON', function () {
    Post::factory()->count(15)->create();

    $response = get('/api/posts?page=1&per_page=10');

    $response->assertOk()
        ->assertJsonStructure([
            'data' => [
                '*' => ['id', 'title', 'body', 'created_at']
            ],
            'links',
            'meta' => ['current_page', 'total'],
        ])
        ->assertJsonCount(10, 'data');
});
```

Test API authentication with Sanctum:

```php
it('requires authentication for protected endpoints', function () {
    $response = get('/api/user/profile');

    $response->assertUnauthorized();
});

it('returns user profile with valid token', function () {
    $user = User::factory()->create();
    $token = $user->createToken('test')->plainTextToken;

    $response = withHeader('Authorization', "Bearer {$token}")
        ->get('/api/user/profile');

    $response->assertOk()
        ->assertJson(['email' => $user->email]);
});
```

See: [Laravel API Pagination and Filtering]({{< relref "blog/laravel/laravel-api-pagination-filtering-sorting.md" >}}) for testing pagination.

## Organize tests with datasets

Pest datasets let you run the same test with different inputs:

```php
it('validates email format', function ($email, $isValid) {
    $response = post('/register', ['email' => $email]);

    if ($isValid) {
        $response->assertSessionHasNoErrors('email');
    } else {
        $response->assertSessionHasErrors('email');
    }
})->with([
    ['user@example.com', true],
    ['invalid-email', false],
    ['@example.com', false],
    ['user@', false],
]);
```

This runs the test four times with different emails.

## Run tests in parallel

Speed up test runs by running tests in parallel:

```bash
php artisan test --parallel
# or
./vendor/bin/pest --parallel
```

Install the paratest package first:

```bash
composer require brianium/paratest --dev
```

This runs tests across multiple processes. A 2-minute test suite might run in 30 seconds.

For Pest, parallelization works out of the box. For PHPUnit, use `--parallel=4` to set process count.

## Test coverage

Check which code your tests cover:

```bash
php artisan test --coverage
```

This shows percentage of code covered by tests. Aim for 70-80% coverage of important code, not 100% of everything.

Add minimum coverage threshold to `phpunit.xml`:

```xml
<coverage>
    <report>
        <html outputDirectory="coverage"/>
    </report>
</coverage>
```

Generate an HTML coverage report:

```bash
php artisan test --coverage-html coverage
```

Open `coverage/index.html` to see detailed line-by-line coverage.

## Set up continuous integration

Run tests automatically on every commit. Example GitHub Actions workflow:

Create `.github/workflows/tests.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  tests:
    runs-on: ubuntu-latest

    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: password
          MYSQL_DATABASE: test
        ports:
          - 3306:3306
        options: --health-cmd="mysqladmin ping" --health-interval=10s --health-timeout=5s --health-retries=3

    steps:
      - uses: actions/checkout@v3

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: 8.2
          extensions: mbstring, pdo_mysql

      - name: Install dependencies
        run: composer install --no-interaction --prefer-dist

      - name: Copy .env
        run: php -r "file_exists('.env') || copy('.env.example', '.env');"

      - name: Generate key
        run: php artisan key:generate

      - name: Run migrations
        run: php artisan migrate --env=testing

      - name: Run tests
        run: php artisan test --parallel
```

This runs tests on every push. If tests fail, the build fails and you know not to merge.

Cache Composer dependencies to speed up builds:

```yaml
- name: Cache Composer dependencies
  uses: actions/cache@v3
  with:
    path: vendor
    key: composer-${{ hashFiles('composer.lock') }}
```

## Best practices for Laravel testing

Write tests before fixing bugs. This ensures the bug stays fixed.

Keep tests fast. Slow tests don't get run. Use factories instead of seeders. Mock external APIs. Use RefreshDatabase only when needed.

Test behavior, not implementation. If you refactor a method but behavior stays the same, tests should still pass.

Don't test framework code. Laravel's validation, routing, and ORM are already tested. Test your business logic.

Name tests clearly. Use `it('allows users to create posts')` not `test_create_post()`. The test name should describe what happens.

One assertion per test when possible. This makes failures easier to debug.

Avoid testing private methods. Test public methods that call private methods. If you need to test a private method, maybe it should be public or in its own class.

Use database transactions for faster tests when you don't need to test migrations:

```php
use Illuminate\Foundation\Testing\DatabaseTransactions;

uses(DatabaseTransactions::class)->in('Feature');
```

Don't share state between tests. Each test should be independent. Use factories to create data per test.

## Testing common scenarios

Test pagination:

```php
it('paginates posts', function () {
    Post::factory()->count(25)->create();

    $response = get('/posts?page=2&per_page=10');

    $response->assertOk()
        ->assertJsonCount(10, 'data')
        ->assertJsonPath('meta.current_page', 2);
});
```

Test file uploads:

```php
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

it('uploads user avatar', function () {
    Storage::fake('public');

    $file = UploadedFile::fake()->image('avatar.jpg');

    $response = post('/profile/avatar', [
        'avatar' => $file,
    ]);

    $response->assertOk();
    Storage::disk('public')->assertExists('avatars/' . $file->hashName());
});
```

Test emails:

```php
use Illuminate\Support\Facades\Mail;
use App\Mail\WelcomeEmail;

it('sends welcome email to new users', function () {
    Mail::fake();

    post('/register', [
        'email' => 'user@example.com',
        'password' => 'password',
    ]);

    Mail::assertSent(WelcomeEmail::class, function ($mail) {
        return $mail->hasTo('user@example.com');
    });
});
```

Test queued jobs:

```php
use Illuminate\Support\Facades\Queue;
use App\Jobs\ProcessOrder;

it('queues order processing job', function () {
    Queue::fake();

    post('/orders', ['total' => 100]);

    Queue::assertPushed(ProcessOrder::class);
});
```

## Debugging failing tests

When a test fails, Laravel shows the failure message and stack trace.

Add `dump()` or `dd()` in tests to inspect values:

```php
it('calculates total', function () {
    $cart = new Cart();
    $total = $cart->calculateTotal();

    dump($total); // shows value
    expect($total)->toBe(100);
});
```

Use `$this->withoutExceptionHandling()` in PHPUnit or Pest to see full error details instead of HTTP status codes:

```php
it('creates post', function () {
    $this->withoutExceptionHandling();

    $response = post('/posts', ['title' => 'Test']);

    $response->assertOk();
});
```

Check test database after failed tests:

```bash
php artisan tinker --env=testing
```

Then query the database to see what was created.

## Summary

Automated testing catches bugs early and lets you refactor with confidence. Use feature tests for HTTP flows and user scenarios. Use unit tests for isolated business logic.

Set up Pest for cleaner syntax or stick with PHPUnit if you prefer. Use factories to create test data and RefreshDatabase to keep tests isolated. Mock external APIs with Http::fake() and test assertions cover databases, JSON responses, and validation.

Run tests in parallel to keep them fast and integrate tests into CI/CD with GitHub Actions or your preferred tool. Aim for good coverage of critical code, not 100% of everything.

For more on Laravel quality, see [Laravel Security Best Practices]({{< relref "blog/laravel/laravel-security-best-practices-production.md" >}}) and [Laravel Performance Optimization]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}}).
