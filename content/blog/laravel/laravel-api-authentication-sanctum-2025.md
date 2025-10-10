---
title: 'Laravel API Authentication with Sanctum Complete Tutorial 2025'
date: 2025-09-14T10:00:00+07:00
draft: false
url: /2025/09/laravel-api-authentication-sanctum-2025.html
tags: 
- Laravel
- API
- Authentication
- Sanctum
- Tutorial
description: 'A practical, end-to-end guide to Laravel Sanctum for SPA and mobile APIs: install, configure cookies and CORS, issue and revoke personal access tokens, protect routes, test flows, and harden production settings.'
keywords: ['laravel sanctum','laravel api authentication','sanctum spa auth','sanctum csrf','sanctum personal access tokens','sanctum abilities','laravel auth:sanctum','laravel cors','stateful domains','sanctum production']
featured: false
faq:
  - question: "What is the difference between Laravel Sanctum and Passport?"
    answer: "Sanctum is lightweight and designed for first-party SPAs and simple token authentication with optional abilities. It uses Laravel's session system for SPAs and personal access tokens for APIs. Passport is a full OAuth2 server implementation for third-party API access, supporting authorization codes, refresh tokens, and complex OAuth flows. Choose Sanctum for mobile apps and your own SPA; choose Passport only when you need full OAuth2 compliance for third-party integrations."
  - question: "When should I use cookie-based authentication vs personal access tokens in Sanctum?"
    answer: "Use cookie-based authentication for single-page applications (SPAs) that share the same top-level domain as your API (e.g., app.example.com and api.example.com). This provides session-like authentication with CSRF protection. Use personal access tokens for mobile applications, third-party API clients, or server-to-server communication where cookies aren't practical. Tokens can have specific abilities/scopes and are sent via the Authorization: Bearer header."
  - question: "Why do I get 419 CSRF token mismatch errors with Sanctum?"
    answer: "This typically happens when your SPA doesn't request /sanctum/csrf-cookie before making authenticated requests, or CORS is misconfigured. Ensure supports_credentials is true in config/cors.php, your SPA origin is in allowed_origins, SESSION_DOMAIN matches your setup (e.g., .example.com), and your frontend sends the X-XSRF-TOKEN header on state-changing requests (POST, PUT, DELETE). The SPA must call /sanctum/csrf-cookie first to initialize the CSRF token."
  - question: "Do Sanctum personal access tokens expire automatically?"
    answer: "No, Sanctum tokens do not expire by default. You must implement token expiration yourself using scheduled jobs to prune old tokens based on last_used_at timestamps, or implement token rotation where you issue new tokens and revoke old ones. For security, implement a pruning strategy via Laravel's scheduler to delete tokens unused for 30+ days, or require periodic re-authentication in your application logic."
  - question: "How do I handle multiple devices or sessions with Sanctum tokens?"
    answer: "Each device should receive its own named token using createToken('device-name', ['abilities']). This allows users to manage and revoke individual device tokens. Track tokens by their name and last_used_at to show users their active sessions. To revoke a specific token, call $token->delete(). To revoke all tokens except current, use $user->tokens()->where('id', '!=', $currentToken->id)->delete(). This provides per-device token management similar to OAuth refresh tokens."
  - question: "What are token abilities in Sanctum and how should I use them?"
    answer: "Token abilities are like scopes or permissions attached to individual tokens. When creating tokens, specify abilities like createToken('mobile', ['orders:create', 'orders:read']). In controllers, check abilities with $request->user()->tokenCan('orders:create'). Use abilities to limit what each token can do, following the principle of least privilege. For example, a read-only reporting token should only have read abilities, while an admin token gets full abilities. This prevents token compromise from granting full API access."
---

Laravel Sanctum offers two simple authentication modes that cover most applications:
- Cookie-based auth for SPAs that live on the same top-level domain as your backend.
- Personal access tokens for mobile apps, third‑party clients, or server‑to‑server use.

This tutorial walks through both flows end‑to‑end, including the necessary configuration (CORS, cookies, stateful domains), how to issue and revoke tokens, how to protect routes, and how to test the result. You’ll also find production notes to avoid common pitfalls.

<!--readmore-->

When to use Sanctum (and when not)
----------------------------------
- Use Sanctum if you need a lightweight, first‑party SPA login or simple tokens with optional abilities. It integrates cleanly with Laravel’s session and guard system.
- Use Passport or OAuth 2.0 only if you must support third‑party OAuth clients, authorization codes, refresh tokens, and full OAuth flows.

Install and prepare
-------------------
Sanctum ships with Laravel, but ensure the package and provider are present:

```bash
composer require laravel/sanctum
php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider"
php artisan migrate
```

Add the middleware to `app/Http/Kernel.php` so Sanctum can manage cookies for SPAs:

```php
// app/Http/Kernel.php
protected $middlewareGroups = [
    'web' => [
        // ...
        \Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class,
    ],
    'api' => [
        // ...
        \Illuminate\Routing\Middleware\SubstituteBindings::class,
    ],
];
```

Configuration for SPA cookie auth
---------------------------------
Cookie mode gives you simple, session‑style auth for a first‑party SPA (for example, `app.example.com` and `api.example.com`). Configure the following:

1) CORS (config/cors.php)
```php
return [
    'paths' => ['api/*', 'sanctum/csrf-cookie', 'login', 'logout'],
    'allowed_methods' => ['*'],
    'allowed_origins' => ['https://app.example.com'],
    'allowed_headers' => ['*'],
    'supports_credentials' => true,
];
```

2) Session and cookies (config/session.php)
```php
'domain' => '.example.com',
'secure' => env('SESSION_SECURE_COOKIE', true),
'same_site' => 'lax',
```

3) Sanctum stateful domains (config/sanctum.php)
```php
'stateful' => [
    'app.example.com', // SPA origin(s)
],
```

4) .env highlights
```env
SESSION_DOMAIN=.example.com
SESSION_SECURE_COOKIE=true
APP_URL=https://api.example.com
SANCTUM_STATEFUL_DOMAINS=app.example.com
```

Login and logout endpoints (SPA)
--------------------------------
Flow overview:
1) SPA requests `/sanctum/csrf-cookie` to prime the CSRF cookie.
2) SPA posts credentials to `/login` (the default Laravel endpoint) with `X-XSRF-TOKEN` header.
3) Server sets the session cookie; subsequent requests to `/api/*` include it automatically.

Example controller for login/logout using Fortify or the default auth scaffolding works out of the box. If you roll your own:

```php
// routes/api.php (or routes/web.php for auth endpoints)
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

Route::post('/login', function (Request $request) {
    $request->validate([
        'email' => 'required|email',
        'password' => 'required',
    ]);
    if (! Auth::attempt($request->only('email','password'), true)) {
        return response()->json(['message' => 'Invalid credentials'], 422);
    }
    $request->session()->regenerate();
    return response()->noContent();
});

Route::post('/logout', function (Request $request) {
    Auth::guard('web')->logout();
    $request->session()->invalidate();
    $request->session()->regenerateToken();
    return response()->noContent();
});
```

Protect routes with auth:sanctum
--------------------------------
Use the Sanctum guard to protect API routes:

```php
// routes/api.php
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/profile', fn(Request $r) => $r->user());
    Route::post('/orders', [OrderController::class, 'store']);
});
```

Personal access tokens (mobile and third‑party)
-----------------------------------------------
For mobile apps or server‑to‑server calls, use personal access tokens. Users can have multiple tokens with abilities (scopes).

Issue a token:
```php
$token = $user->createToken('mobile', ['orders:create','orders:read']);
return ['token' => $token->plainTextToken];
```

Send the token with API requests:
```
Authorization: Bearer <token>
```

Check abilities inside controllers/policies:
```php
if ($request->user()->tokenCan('orders:create')) {
    // proceed
}
```

Revoke and rotate tokens
------------------------
Revoke the current access token:
```php
$request->user()->currentAccessToken()->delete();
```

Revoke all tokens for a user:
```php
$request->user()->tokens()->delete();
```

Token expiry and pruning
------------------------
Sanctum does not expire tokens by default. You can implement rotation or periodic pruning via a scheduled job. With Laravel 11+ you can prune with built‑in commands or write a custom command to delete old tokens based on `last_used_at`.

Testing the flow
----------------
Write basic feature tests to lock in behavior:

```php
public function test_spa_login_and_profile()
{
    $user = User::factory()->create(['password' => bcrypt('secret')]);

    $this->get('/sanctum/csrf-cookie');
    $this->post('/login', ['email' => $user->email, 'password' => 'secret'])
         ->assertNoContent();

    $this->getJson('/api/profile')->assertOk()->assertJson(['id' => $user->id]);
}

public function test_pat_flow()
{
    $user = User::factory()->create();
    $token = $user->createToken('test', ['orders:read'])->plainTextToken;

    $this->withHeader('Authorization', 'Bearer '.$token)
         ->getJson('/api/orders')
         ->assertOk();
}
```

Troubleshooting
---------------
- 419 or CSRF mismatch: your SPA likely missed the `/sanctum/csrf-cookie` call, or CORS/credentials are off. Ensure `supports_credentials=true`, allow your SPA origin, and send `X-XSRF-TOKEN` on state‑changing requests.
- Unauthenticated on protected routes with cookies: check `SESSION_DOMAIN`, `SESSION_SECURE_COOKIE`, and `SANCTUM_STATEFUL_DOMAINS`. Cookies must be sent back to the API domain. See: [Fixing Laravel Session and Cache Issues]({{< relref "blog/laravel/fixing-laravel-session-cache-issues.md" >}}).
- Bearer token rejected: confirm the `Authorization: Bearer` header is present and not stripped by proxies. If using Nginx behind another proxy, validate forwarded headers. When debugging, add structured logs: [Advanced Laravel Debugging with Logs]({{< relref "blog/laravel/advanced-laravel-debugging-with-logs.md" >}}).
- Works locally, fails in production: compare environments and cached config. Clear caches, rebuild, and reload PHP‑FPM. Background: [Laravel Environment Configuration]({{< relref "blog/laravel/laravel-environment-configuration-env-issues.md" >}}).
- 403 from server: verify DocumentRoot points to `public/` and writable paths are correct: [Fix Laravel Permission Issues]({{< relref "blog/laravel/fix-laravel-permission-issues-production.md" >}}).

Production notes
----------------
- Always serve over HTTPS. Set `SESSION_SECURE_COOKIE=true` and pick a proper `same_site` value. Avoid exposing tokens in URLs.
- Limit token abilities to the minimum required and rotate when appropriate.
- Log authentication events and token usage. Use structured logs to identify misuse.
- Keep your deployment routine predictable and clear caches after environment changes. See: [Deploy Laravel to VPS with Nginx — Complete Guide]({{< relref "blog/laravel/deploy-laravel-to-vps-with-nginx-complete-guide.md" >}}) and [Laravel Security Best Practices for Production]({{< relref "blog/laravel/laravel-security-best-practices-production.md" >}}).
- If you need performance tuning (for example, lots of token checks), review cache strategy and DB indexes: [Laravel Performance Optimization: 15 Techniques]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}}).

Summary
-------
Use cookie‑based Sanctum auth for first‑party SPAs and personal access tokens for mobile or server‑to‑server calls. Configure CORS and cookies correctly, declare stateful domains, protect API routes with `auth:sanctum`, and keep tokens tight with abilities, rotation, and revocation. Test the end‑to‑end flow, monitor logs, and follow production hardening guidelines. With these in place, you get a secure, maintainable authentication system without the weight of full OAuth.
