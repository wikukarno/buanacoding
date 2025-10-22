---
title: 'How to Implement Laravel Socialite for OAuth Login (Google, Facebook, GitHub)'
date: 2025-10-24T09:00:00+07:00
draft: false
url: /2025/10/how-to-implement-laravel-socialite-oauth-login-google-facebook-github.html
tags:
- Laravel
- OAuth
- Socialite
- Authentication
- Google
- Facebook
- GitHub
description: 'Complete guide to implementing OAuth social login in Laravel using Socialite. Learn Google, Facebook, and GitHub authentication, callback handling, account linking, token management, and security best practices.'
keywords: ['laravel socialite','oauth login laravel','google login laravel','facebook authentication','github oauth','social login','laravel social authentication','oauth callback','account linking','socialite tutorial']
featured: false
faq:
  - question: "What is OAuth and why use it instead of traditional email/password login?"
    answer: "OAuth lets users log in with existing accounts from Google, Facebook, or GitHub instead of creating new passwords. Users click 'Login with Google', authenticate on Google's site, and your app receives their profile data. This improves conversion because users don't fill out registration forms, reduces password fatigue, and shifts security responsibility to OAuth providers who have better security infrastructure. OAuth also gives you verified email addresses automatically. Use OAuth as an option alongside email/password, not as a replacement, so users have choices."
  - question: "How does Laravel Socialite handle user data from different OAuth providers?"
    answer: "Socialite normalizes data from different providers into a consistent format. All providers return a User object with methods like getName(), getEmail(), getId(), and getAvatar(). Behind the scenes, Socialite maps provider-specific fields (Google's 'email', Facebook's 'email', GitHub's 'email') to standard methods. Some data is provider-specific - GitHub doesn't always provide email addresses, Facebook requires permissions for phone numbers. Always check if data exists before using it and have fallback strategies when optional fields are missing."
  - question: "Should I create separate users table for social logins or merge with existing users?"
    answer: "Merge into your existing users table but add a social_accounts table for OAuth data. Your users table keeps email, name, password (nullable for social-only users). The social_accounts table stores provider (google, facebook), provider_id, access_token per connection. This lets users link multiple social accounts to one user, supports adding email/password later, and allows both login methods. Use User::updateOrCreate() to find existing users by email or create new ones, then create/update the social account record. Don't duplicate user data across tables."
  - question: "How do I handle users who sign up with email then later login with Google using the same email?"
    answer: "Check if a user with that email already exists when processing the OAuth callback. If yes, link the social account to the existing user instead of creating a duplicate. Use User::where('email', $socialUser->getEmail())->first() to find existing users. Create the social_accounts record linking provider data to the found user. Log the user in with the existing account. Show a message like 'We found your account and linked it with Google'. If the user has a password set, consider requiring password confirmation before linking for security. This prevents account takeover if someone gets access to the email."
  - question: "What should I store from OAuth providers and what should I skip?"
    answer: "Store: provider name (google, facebook, github), provider_id (the user's ID at that provider), access_token (for API calls), refresh_token (if available), token_expires_at, user's name, email, and avatar URL. Don't store: full JSON responses (too much data), tokens in plain text (encrypt them), unnecessary permissions (only request what you need). Refresh tokens when needed, not on every login. Update name and avatar on each login to keep data fresh. Store the minimum you need - usually just provider, provider_id, and tokens are enough. Everything else can be fetched from the provider's API when needed."
  - question: "How do I handle OAuth token expiration and refresh?"
    answer: "Most OAuth providers issue access tokens that expire after 1 hour. Google and Facebook provide refresh tokens that never expire. Store both access_token and refresh_token in your database. When an API call fails with 401, use the refresh token to get a new access token. Socialite's refresh() method handles this: $newAccessToken = $provider->refreshToken($user->social_account->refresh_token). Update the stored access_token and token_expires_at. GitHub tokens don't expire by default. Check provider docs for expiration policies. Only refresh when needed, not on every request. Cache the access token and refresh 5 minutes before expiration to avoid API failures."
---

Social login lets users sign in with Google, Facebook, or GitHub instead of creating another password. Laravel Socialite makes OAuth integration simple with just a few lines of code. Users click 'Login with Google', authenticate on Google's site, and return to your app with their profile data.

This guide walks through setting up Socialite, configuring OAuth apps with Google, Facebook, and GitHub, handling callbacks, creating or linking user accounts, storing tokens securely, and managing edge cases like duplicate emails.

<!--readmore-->

## Why use social login

Users hate creating new accounts. Social login removes friction:
- No registration forms to fill out
- No passwords to remember
- Verified email addresses automatically
- Faster conversion from visitor to user
- Users trust Google/Facebook/GitHub security

Offer social login as an option, not the only option. Some users prefer email/password. Give them both choices.

## Install Laravel Socialite

Install via Composer:

```bash
composer require laravel/socialite
```

Socialite works out of the box. No service provider registration needed in Laravel 11+.

## Create OAuth applications

Before coding, create OAuth apps with each provider to get client IDs and secrets.

### Google OAuth setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Navigate to APIs & Services > Credentials
4. Click Create Credentials > OAuth client ID
5. Select Web application
6. Add authorized redirect URI: `https://yourdomain.com/login/google/callback`
7. Copy Client ID and Client secret

### Facebook OAuth setup

1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Create an app or select existing one
3. Add Facebook Login product
4. Go to Settings > Basic
5. Copy App ID and App Secret
6. In Facebook Login > Settings, add redirect URI: `https://yourdomain.com/login/facebook/callback`

### GitHub OAuth setup

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Click New OAuth App
3. Fill in application name and homepage URL
4. Set Authorization callback URL: `https://yourdomain.com/login/github/callback`
5. Copy Client ID and generate Client Secret

## Configure OAuth credentials

Add credentials to `config/services.php`:

```php
return [
    // ... other services

    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID'),
        'client_secret' => env('GOOGLE_CLIENT_SECRET'),
        'redirect' => env('GOOGLE_REDIRECT_URI'),
    ],

    'facebook' => [
        'client_id' => env('FACEBOOK_CLIENT_ID'),
        'client_secret' => env('FACEBOOK_CLIENT_SECRET'),
        'redirect' => env('FACEBOOK_REDIRECT_URI'),
    ],

    'github' => [
        'client_id' => env('GITHUB_CLIENT_ID'),
        'client_secret' => env('GITHUB_CLIENT_SECRET'),
        'redirect' => env('GITHUB_REDIRECT_URI'),
    ],
];
```

Add to `.env`:

```env
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=https://yourdomain.com/login/google/callback

FACEBOOK_CLIENT_ID=your-facebook-app-id
FACEBOOK_CLIENT_SECRET=your-facebook-app-secret
FACEBOOK_REDIRECT_URI=https://yourdomain.com/login/facebook/callback

GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret
GITHUB_REDIRECT_URI=https://yourdomain.com/login/github/callback
```

Never commit these secrets to Git. Keep `.env` in `.gitignore`.

## Create database tables

Create a `social_accounts` table to store OAuth data:

```bash
php artisan make:migration create_social_accounts_table
```

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('social_accounts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('provider'); // google, facebook, github
            $table->string('provider_id'); // user ID from provider
            $table->text('access_token')->nullable();
            $table->text('refresh_token')->nullable();
            $table->timestamp('token_expires_at')->nullable();
            $table->timestamps();

            $table->unique(['provider', 'provider_id']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('social_accounts');
    }
};
```

Run migration:

```bash
php artisan migrate
```

Make `password` nullable in users table since social users might not have passwords:

```php
Schema::table('users', function (Blueprint $table) {
    $table->string('password')->nullable()->change();
});
```

## Create SocialAccount model

```bash
php artisan make:model SocialAccount
```

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SocialAccount extends Model
{
    protected $fillable = [
        'user_id',
        'provider',
        'provider_id',
        'access_token',
        'refresh_token',
        'token_expires_at',
    ];

    protected $casts = [
        'token_expires_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
```

Add relationship to User model:

```php
use Illuminate\Database\Eloquent\Relations\HasMany;

public function socialAccounts(): HasMany
{
    return $this->hasMany(SocialAccount::class);
}
```

## Create routes

Add routes in `routes/web.php`:

```php
use App\Http\Controllers\SocialAuthController;

Route::prefix('login')->group(function () {
    Route::get('{provider}', [SocialAuthController::class, 'redirect'])
        ->where('provider', 'google|facebook|github')
        ->name('social.redirect');

    Route::get('{provider}/callback', [SocialAuthController::class, 'callback'])
        ->where('provider', 'google|facebook|github')
        ->name('social.callback');
});
```

This creates:
- `/login/google` - redirects to Google
- `/login/google/callback` - handles Google response
- Same for facebook and github

## Create controller

```bash
php artisan make:controller SocialAuthController
```

```php
<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\SocialAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Laravel\Socialite\Facades\Socialite;

class SocialAuthController extends Controller
{
    public function redirect(string $provider)
    {
        return Socialite::driver($provider)->redirect();
    }

    public function callback(string $provider)
    {
        try {
            $socialUser = Socialite::driver($provider)->user();
        } catch (\Exception $e) {
            return redirect('/login')->withErrors('Authentication failed. Please try again.');
        }

        // Find or create user
        $user = $this->findOrCreateUser($socialUser, $provider);

        // Log the user in
        auth()->login($user, true);

        return redirect()->intended('/dashboard');
    }

    protected function findOrCreateUser($socialUser, $provider)
    {
        // Check if user already has this social account
        $socialAccount = SocialAccount::where('provider', $provider)
            ->where('provider_id', $socialUser->getId())
            ->first();

        if ($socialAccount) {
            // Update tokens
            $socialAccount->update([
                'access_token' => $socialUser->token,
                'refresh_token' => $socialUser->refreshToken,
                'token_expires_at' => $socialUser->expiresIn
                    ? now()->addSeconds($socialUser->expiresIn)
                    : null,
            ]);

            return $socialAccount->user;
        }

        // Check if user exists with this email
        $user = User::where('email', $socialUser->getEmail())->first();

        if (!$user) {
            // Create new user
            $user = User::create([
                'name' => $socialUser->getName(),
                'email' => $socialUser->getEmail(),
                'email_verified_at' => now(),
                'password' => null,
            ]);
        }

        // Create social account
        $user->socialAccounts()->create([
            'provider' => $provider,
            'provider_id' => $socialUser->getId(),
            'access_token' => $socialUser->token,
            'refresh_token' => $socialUser->refreshToken,
            'token_expires_at' => $socialUser->expiresIn
                ? now()->addSeconds($socialUser->expiresIn)
                : null,
        ]);

        return $user;
    }
}
```

This handles the full OAuth flow:
1. User clicks 'Login with Google'
2. `redirect()` sends them to Google
3. User authenticates on Google
4. Google redirects to `/login/google/callback`
5. `callback()` receives user data
6. Find or create user and social account
7. Log user in

## Add social login buttons to login page

```blade
<!-- resources/views/auth/login.blade.php -->

<div class="social-login">
    <a href="{{ route('social.redirect', 'google') }}" class="btn btn-google">
        Login with Google
    </a>

    <a href="{{ route('social.redirect', 'facebook') }}" class="btn btn-facebook">
        Login with Facebook
    </a>

    <a href="{{ route('social.redirect', 'github') }}" class="btn btn-github">
        Login with GitHub
    </a>
</div>
```

Style the buttons to match provider branding. Google, Facebook, and GitHub have brand guidelines for button design.

## Handle missing emails

Some providers don't always provide emails. GitHub users can hide their email. Handle this:

```php
protected function findOrCreateUser($socialUser, $provider)
{
    $email = $socialUser->getEmail();

    if (!$email) {
        // Generate a temporary email or ask user for email
        return redirect('/register/complete')
            ->with('social_data', [
                'provider' => $provider,
                'provider_id' => $socialUser->getId(),
                'name' => $socialUser->getName(),
            ]);
    }

    // ... rest of the logic
}
```

For GitHub, request the `user:email` scope:

```php
public function redirect(string $provider)
{
    $scopes = [];

    if ($provider === 'github') {
        $scopes = ['user:email'];
    }

    return Socialite::driver($provider)
        ->scopes($scopes)
        ->redirect();
}
```

## Request additional scopes

Request more permissions if you need extra data:

```php
// Google - request profile and email (default)
Socialite::driver('google')
    ->scopes(['profile', 'email'])
    ->redirect();

// Facebook - request email and public profile
Socialite::driver('facebook')
    ->scopes(['email', 'public_profile'])
    ->redirect();

// GitHub - request user email
Socialite::driver('github')
    ->scopes(['user:email'])
    ->redirect();
```

Only request what you need. More scopes mean more permission prompts, which reduces conversion.

## Retrieve additional user data

Access extra fields from the provider:

```php
$socialUser = Socialite::driver($provider)->user();

// Common fields (all providers)
$name = $socialUser->getName();
$email = $socialUser->getEmail();
$avatar = $socialUser->getAvatar();
$id = $socialUser->getId();
$token = $socialUser->token;

// Provider-specific fields
$raw = $socialUser->getRaw(); // All data from provider

// Example: Get phone from Facebook
if ($provider === 'facebook' && isset($raw['phone'])) {
    $phone = $raw['phone'];
}
```

Check provider documentation for available fields.

## Encrypt access tokens

OAuth tokens are sensitive. Encrypt them before storing:

Add cast to SocialAccount model:

```php
protected $casts = [
    'access_token' => 'encrypted',
    'refresh_token' => 'encrypted',
    'token_expires_at' => 'datetime',
];
```

Laravel automatically encrypts these fields when saving and decrypts when reading.

## Link social accounts to existing users

Let logged-in users link social accounts:

```php
// Add to routes
Route::middleware('auth')->group(function () {
    Route::get('account/link/{provider}', [SocialAuthController::class, 'linkRedirect'])
        ->name('social.link');

    Route::get('account/link/{provider}/callback', [SocialAuthController::class, 'linkCallback'])
        ->name('social.link.callback');
});
```

Controller methods:

```php
public function linkRedirect(string $provider)
{
    return Socialite::driver($provider)->redirect();
}

public function linkCallback(string $provider)
{
    $socialUser = Socialite::driver($provider)->user();

    $user = auth()->user();

    // Check if this social account is already linked to another user
    $existing = SocialAccount::where('provider', $provider)
        ->where('provider_id', $socialUser->getId())
        ->first();

    if ($existing && $existing->user_id !== $user->id) {
        return redirect('/account/settings')
            ->withErrors('This social account is already linked to another user.');
    }

    // Link or update social account
    $user->socialAccounts()->updateOrCreate(
        [
            'provider' => $provider,
            'provider_id' => $socialUser->getId(),
        ],
        [
            'access_token' => $socialUser->token,
            'refresh_token' => $socialUser->refreshToken,
            'token_expires_at' => $socialUser->expiresIn
                ? now()->addSeconds($socialUser->expiresIn)
                : null,
        ]
    );

    return redirect('/account/settings')
        ->with('success', ucfirst($provider) . ' account linked successfully.');
}
```

This lets users add Google to an existing account created with email/password.

## Unlink social accounts

Let users remove linked accounts:

```php
Route::delete('account/unlink/{provider}', function (string $provider) {
    $user = auth()->user();

    // Don't unlink if it's the only login method
    if ($user->socialAccounts()->count() === 1 && !$user->password) {
        return back()->withErrors('Cannot unlink your only login method. Set a password first.');
    }

    $user->socialAccounts()->where('provider', $provider)->delete();

    return back()->with('success', ucfirst($provider) . ' account unlinked.');
})->name('social.unlink');
```

Always check users have another way to log in before unlinking.

## Refresh expired tokens

OAuth tokens expire. Refresh them when needed:

```php
use Laravel\Socialite\Facades\Socialite;

public function refreshToken(SocialAccount $socialAccount)
{
    if (!$socialAccount->refresh_token) {
        throw new \Exception('No refresh token available');
    }

    try {
        $provider = Socialite::driver($socialAccount->provider);

        $newToken = $provider->refreshToken($socialAccount->refresh_token);

        $socialAccount->update([
            'access_token' => $newToken->token,
            'token_expires_at' => now()->addSeconds($newToken->expiresIn),
        ]);

        return $socialAccount;
    } catch (\Exception $e) {
        // Token refresh failed - user needs to re-authenticate
        throw $e;
    }
}
```

Refresh tokens automatically before making API calls:

```php
public function getAccessToken(SocialAccount $socialAccount)
{
    // Check if token expired or expires in next 5 minutes
    if ($socialAccount->token_expires_at && $socialAccount->token_expires_at->subMinutes(5)->isPast()) {
        $this->refreshToken($socialAccount);
        $socialAccount->refresh();
    }

    return $socialAccount->access_token;
}
```

## Handle OAuth errors

Catch and handle authentication failures:

```php
public function callback(string $provider)
{
    try {
        $socialUser = Socialite::driver($provider)->user();
    } catch (\Laravel\Socialite\Two\InvalidStateException $e) {
        // User clicked "back" or session expired
        return redirect('/login')->withErrors('Authentication session expired. Please try again.');
    } catch (\GuzzleHttp\Exception\ClientException $e) {
        // OAuth provider error
        return redirect('/login')->withErrors('Unable to connect to ' . ucfirst($provider) . '. Please try again later.');
    } catch (\Exception $e) {
        // Generic error
        \Log::error('Social auth error: ' . $e->getMessage());
        return redirect('/login')->withErrors('Authentication failed. Please try again.');
    }

    // ... rest of callback logic
}
```

Log errors for debugging but show user-friendly messages.

## Test social login

Test OAuth flows:

```php
use Laravel\Socialite\Facades\Socialite;
use Laravel\Socialite\Two\User as SocialUser;

it('creates user from Google OAuth', function () {
    $socialUser = Mockery::mock(SocialUser::class);
    $socialUser->shouldReceive('getId')->andReturn('google-id-123');
    $socialUser->shouldReceive('getEmail')->andReturn('user@example.com');
    $socialUser->shouldReceive('getName')->andReturn('John Doe');
    $socialUser->token = 'fake-access-token';
    $socialUser->refreshToken = null;
    $socialUser->expiresIn = 3600;

    Socialite::shouldReceive('driver->user')->andReturn($socialUser);

    $response = get('/login/google/callback');

    $response->assertRedirect('/dashboard');

    assertDatabaseHas('users', [
        'email' => 'user@example.com',
        'name' => 'John Doe',
    ]);

    assertDatabaseHas('social_accounts', [
        'provider' => 'google',
        'provider_id' => 'google-id-123',
    ]);
});
```

Mock Socialite to avoid hitting real OAuth APIs in tests.

## Security best practices

Use HTTPS in production. OAuth tokens are sensitive.

Store tokens encrypted with Laravel's encrypted casts.

Validate redirect URIs match exactly in OAuth app settings. Attackers can exploit misconfigurations.

Regenerate session ID after login to prevent session fixation:

```php
$request->session()->regenerate();
```

Laravel does this automatically in `auth()->login()`, but explicit is better.

Rate limit OAuth endpoints to prevent abuse:

```php
Route::get('login/{provider}/callback', [SocialAuthController::class, 'callback'])
    ->middleware('throttle:10,1');
```

Don't trust user data from providers blindly. Validate and sanitize names and emails.

## Summary

Laravel Socialite makes OAuth integration simple. Install Socialite, create OAuth apps with Google, Facebook, and GitHub, configure credentials in `config/services.php`, and add routes for redirecting to providers and handling callbacks.

Create a social_accounts table to store OAuth data linked to users. Use updateOrCreate to find existing users by email or create new ones. Handle edge cases like missing emails, duplicate accounts, and token expiration.

Encrypt access tokens, refresh them before expiration, and test OAuth flows with mocks. Always use HTTPS and validate redirect URIs in production.

For more on Laravel authentication, see [Laravel 2FA Implementation]({{< relref "blog/laravel/laravel-two-factor-authentication-2fa-fortify.md" >}}) and [Laravel API Authentication with Sanctum]({{< relref "blog/laravel/laravel-api-authentication-sanctum-2025.md" >}}).
