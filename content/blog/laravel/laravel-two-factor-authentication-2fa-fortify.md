---
title: 'How to Implement Multi-Factor Authentication (2FA) in Laravel with Laravel Fortify'
date: 2025-10-22T10:00:00+07:00
draft: false
url: /2025/10/laravel-two-factor-authentication-2fa-fortify.html
tags:
- Laravel
- Security
- Authentication
- Fortify
- 2FA
description: 'Complete guide to implementing Two-Factor Authentication (2FA) in Laravel using Laravel Fortify. Learn TOTP setup with Google Authenticator, QR code generation, recovery codes, security best practices, and production deployment.'
keywords: ['laravel 2fa','laravel fortify','two factor authentication laravel','laravel totp','google authenticator laravel','laravel fortify 2fa','laravel security','laravel authentication','2fa implementation','laravel recovery codes']
featured: false
faq:
  - question: "What is the difference between Laravel Fortify and Laravel Breeze/Jetstream for 2FA?"
    answer: "Laravel Fortify is a headless authentication backend that provides the logic for 2FA, password confirmation, email verification, and more without any UI. Laravel Breeze and Jetstream are full authentication starter kits that use Fortify under the hood and include pre-built views. Use Fortify directly when building custom frontends (SPAs, APIs) or when you need fine-grained control. Use Breeze/Jetstream for rapid development with pre-built Blade, React, or Vue views that include 2FA UI out of the box."
  - question: "How does TOTP (Time-based One-Time Password) work in Laravel Fortify?"
    answer: "TOTP generates a 6-digit code based on the current time and a shared secret key. When enabling 2FA, Fortify creates a secret stored encrypted in the database. This secret is shown as a QR code that users scan with Google Authenticator or Authy. The app and server both use the same algorithm (RFC 6238) with the secret and current time to generate matching codes. Codes change every 30 seconds. During login, Fortify validates the user-provided code against codes generated for the current time window plus a small grace period to account for clock drift."
  - question: "What are recovery codes and why are they important?"
    answer: "Recovery codes are one-time-use backup codes generated when enabling 2FA. If users lose access to their authenticator app (lost phone, uninstalled app), they can use a recovery code instead of the TOTP code to regain access. Fortify generates 8 random recovery codes by default, stored hashed in the database. Each code can only be used once. Without recovery codes, users who lose their authenticator device would be permanently locked out. Always enforce showing and storing recovery codes during 2FA setup, and provide a way to regenerate them after authentication."
  - question: "How can I prevent users from locking themselves out when enabling 2FA?"
    answer: "Implement a two-step enable process: 1) Generate the secret and show the QR code. 2) Require the user to enter a valid TOTP code before fully enabling 2FA. This confirms they successfully scanned the QR code. Additionally, always generate and display recovery codes immediately after enabling 2FA, and require users to acknowledge saving them (use a confirmation checkbox). Consider sending an email notification when 2FA is enabled. For extra safety, implement a grace period where 2FA can be disabled without a code for 10-15 minutes after enabling, or allow support staff to manually disable 2FA after identity verification."
  - question: "Can I customize the 2FA secret length or code expiration time?"
    answer: "Yes. Fortify uses the pragmarx/google2fa package under the hood. You can customize secret length, code window, and QR code parameters. To change secret length from the default 32 characters, publish the Fortify config and modify the two_factor_authentication array. For code validation window, you can extend Fortify's TwoFactorAuthenticationProvider and override the verify method to use Google2FA's setWindow() method. The default window is ±1 interval (90 seconds total: 30s past, 30s current, 30s future). Increasing the window improves usability but slightly reduces security."
  - question: "How do I implement 2FA for API authentication with Sanctum tokens?"
    answer: "Fortify's 2FA is designed for session-based authentication. For API/token auth with Sanctum, you need a custom flow: 1) User logs in with credentials and receives a temporary token (or session). 2) Check if user has 2FA enabled ($user->two_factor_secret). 3) If yes, mark the session/token as pending-2fa and require a second request with the TOTP code. 4) Validate the code using Google2FA's verifyKey(). 5) Only after code validation, issue the full-access Sanctum token. Store a 2fa_verified flag in the session or token abilities. Protect sensitive routes by checking this flag. This separates the authentication step (password) from the authorization step (2FA code)."
---

Two-factor authentication (2FA) adds an extra layer of security to your Laravel application. Users need both their password and a time-based code from an authenticator app to log in. Laravel Fortify handles all the backend logic, and you build the frontend however you want.

This guide walks through the complete setup: installing Fortify, enabling 2FA, generating QR codes for Google Authenticator, managing recovery codes, confirming codes before activation to prevent lockouts, and testing everything. We'll also cover security practices and common problems you might run into.

<!--readmore-->

## When to use 2FA

You should use 2FA for applications that handle sensitive data like financial systems, healthcare records, admin panels, or HR systems. If someone breaking into an account would cause real damage, you need 2FA.

It's required for applications with privileged access, multi-tenant SaaS platforms, or when compliance standards like PCI-DSS, HIPAA, or SOC 2 demand it.

For low-risk applications it's optional, but offering 2FA to users who want extra security is always good practice.

Laravel Fortify provides TOTP-based 2FA that works with Google Authenticator, Authy, 1Password, and any other app that follows RFC 6238.

## Install Laravel Fortify

Laravel Fortify is a headless authentication backend. Install it via Composer:

```bash
composer require laravel/fortify
```

Publish Fortify's resources and run migrations:

```bash
php artisan vendor:publish --provider="Laravel\Fortify\FortifyServiceProvider"
php artisan migrate
```

This creates the `config/fortify.php` configuration file, `app/Actions/Fortify` action classes, `app/Providers/FortifyServiceProvider.php`, and adds columns to the `users` table for 2FA (two_factor_secret, two_factor_recovery_codes, two_factor_confirmed_at).

Register the service provider in `config/app.php` (Laravel 10 and below) or it will auto-register in Laravel 11+:

```php
'providers' => [
    // ...
    App\Providers\FortifyServiceProvider::class,
],
```

## Enable 2FA in Fortify configuration

Open `config/fortify.php` and enable the two-factor authentication feature:

```php
'features' => [
    Features::registration(),
    Features::resetPasswords(),
    Features::emailVerification(),
    Features::updateProfileInformation(),
    Features::updatePasswords(),
    Features::twoFactorAuthentication([
        'confirm' => true,
        'confirmPassword' => true,
    ]),
],
```

Key options:
- `'confirm' => true`: Users must enter a valid TOTP code before 2FA is fully enabled. This prevents lockouts if they scan the QR code wrong.
- `'confirmPassword' => true`: Users must confirm their password before enabling or disabling 2FA.

## Add the TwoFactorAuthenticatable trait to User model

Update your `app/Models/User.php` to use the `TwoFactorAuthenticatable` trait:

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Fortify\TwoFactorAuthenticatable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable, TwoFactorAuthenticatable;

    // ...
}
```

This trait adds methods like `twoFactorQrCodeSvg()`, `recoveryCodes()`, and database columns for the 2FA secret and recovery codes.

## Fortify routes overview

Fortify automatically registers these routes when 2FA is enabled:

- `POST /user/two-factor-authentication` -- Enable 2FA (generates secret and recovery codes)
- `DELETE /user/two-factor-authentication` -- Disable 2FA
- `GET /user/two-factor-qr-code` -- Get QR code SVG for scanning
- `GET /user/two-factor-recovery-codes` -- Get recovery codes as JSON
- `POST /user/two-factor-recovery-codes` -- Regenerate recovery codes
- `POST /user/confirmed-two-factor-authentication` -- Confirm 2FA by validating a code

All routes require authentication and are under the `web` middleware group. Password confirmation may be required based on your config.

## Enable 2FA: Generate secret and QR code

When a user wants to enable 2FA, make a POST request to `/user/two-factor-authentication`. Fortify generates a secret and recovery codes and stores them encrypted in the database.

**Frontend flow (example with Axios):**

```javascript
// Enable 2FA
await axios.post('/user/two-factor-authentication');

// Fetch the QR code SVG
const qrResponse = await axios.get('/user/two-factor-qr-code');
document.getElementById('qr-code').innerHTML = qrResponse.data.svg;

// Fetch recovery codes
const recoveryResponse = await axios.get('/user/two-factor-recovery-codes');
displayRecoveryCodes(recoveryResponse.data);
```

**Controller example (custom UI):**

```php
use Illuminate\Http\Request;
use Laravel\Fortify\Actions\EnableTwoFactorAuthentication;

public function enable(Request $request, EnableTwoFactorAuthentication $enable)
{
    $enable($request->user());

    return response()->json([
        'qr_code' => $request->user()->twoFactorQrCodeSvg(),
        'recovery_codes' => json_decode(decrypt($request->user()->two_factor_recovery_codes), true),
    ]);
}
```

Show the QR code and recovery codes to the user. The QR code is an SVG you can embed directly in your HTML. Display the recovery codes clearly and tell users to save them somewhere safe.

## Confirm 2FA before fully enabling

With `'confirm' => true`, users must enter a valid TOTP code from their authenticator app before 2FA is fully active. This ensures the QR code was scanned correctly.

**Confirmation request:**

```javascript
await axios.post('/user/confirmed-two-factor-authentication', {
    code: '123456' // 6-digit code from authenticator app
});
```

If the code is valid, Fortify sets the `two_factor_confirmed_at` timestamp, and 2FA is now active. If invalid, the endpoint returns a 422 error.

**Custom controller example:**

```php
use Laravel\Fortify\Actions\ConfirmTwoFactorAuthentication;

public function confirm(Request $request, ConfirmTwoFactorAuthentication $confirm)
{
    $confirmed = $confirm($request->user(), $request->code);

    if (! $confirmed) {
        return response()->json(['message' => 'Invalid code'], 422);
    }

    return response()->json(['message' => '2FA enabled successfully']);
}
```

Only show the "2FA enabled" success message after confirmation. Until then, keep showing the QR code and the input field for the code.

## Login flow with 2FA enabled

Once 2FA is enabled, the login process changes:

1. User submits email and password to `/login`.
2. If credentials are valid and 2FA is enabled, Laravel redirects to `/two-factor-challenge` (or returns a JSON response indicating 2FA is required).
3. User submits a 6-digit TOTP code or a recovery code to `/two-factor-challenge`.
4. If code is valid, user is authenticated and session starts.

**Two-factor challenge endpoint:**

```php
POST /two-factor-challenge
{
    "code": "123456"           // TOTP code from authenticator app
    // OR
    "recovery_code": "abcd-efgh-ijkl"  // One-time recovery code
}
```

**Customize the challenge view:**

Fortify looks for a `two-factor-challenge` view. Create `resources/views/auth/two-factor-challenge.blade.php`:

```blade
<form method="POST" action="/two-factor-challenge">
    @csrf
    <label>Enter authentication code</label>
    <input type="text" name="code" placeholder="123456" autofocus>
    <p>Or enter a recovery code:</p>
    <input type="text" name="recovery_code" placeholder="abcd-efgh-ijkl">
    <button type="submit">Verify</button>
</form>
```

Register the view in `FortifyServiceProvider`:

```php
use Laravel\Fortify\Fortify;

public function boot()
{
    Fortify::twoFactorChallengeView(fn() => view('auth.two-factor-challenge'));
}
```

## Recovery codes: Backup access

Recovery codes are one-time-use codes that allow users to log in if they lose access to their authenticator app. Fortify generates 8 recovery codes by default when 2FA is enabled.

**Show recovery codes after enabling 2FA:**

```javascript
const codes = await axios.get('/user/two-factor-recovery-codes');
codes.data.forEach(code => console.log(code));
```

**Regenerate recovery codes** (invalidates old codes):

```javascript
await axios.post('/user/two-factor-recovery-codes');
const newCodes = await axios.get('/user/two-factor-recovery-codes');
```

Best practices:
- Make users confirm they've saved the codes before closing the setup dialog. Use a checkbox or an "I've saved these" button.
- Show recovery codes only once during setup, unless the user regenerates them later.
- Recovery codes are stored hashed in the database. Fortify does this automatically.
- Log when recovery codes are used so you can monitor for suspicious activity.

## Disable 2FA

Users can disable 2FA by making a DELETE request:

```javascript
await axios.delete('/user/two-factor-authentication');
```

This clears the `two_factor_secret`, `two_factor_recovery_codes`, and `two_factor_confirmed_at` columns.

You should require password confirmation before disabling 2FA. Fortify does this automatically if you set `'confirmPassword' => true` in the config.

## Customize 2FA secret length and algorithm

Fortify uses the `pragmarx/google2fa` package. Default secret length is 32 characters (160 bits of entropy). You can customize this by binding a custom Google2FA instance:

```php
use PragmaRX\Google2FA\Google2FA;

// In a service provider
$this->app->singleton(Google2FA::class, function () {
    $google2fa = new Google2FA();
    $google2fa->setSecretLength(64); // Increase to 64 characters
    return $google2fa;
});
```

Most authenticator apps support the default length. Only customize this if you have specific security requirements.

## Testing the 2FA flow

Write feature tests to ensure 2FA works end-to-end:

```php
use App\Models\User;
use Laravel\Fortify\Features;
use PragmaRX\Google2FA\Google2FA;

public function test_user_can_enable_two_factor_authentication()
{
    if (! Features::enabled(Features::twoFactorAuthentication())) {
        $this->markTestSkipped('Two factor authentication is not enabled.');
    }

    $user = User::factory()->create();
    $this->actingAs($user);

    $response = $this->post('/user/two-factor-authentication');
    $response->assertSessionHasNoErrors();

    $user->refresh();
    $this->assertNotNull($user->two_factor_secret);
    $this->assertNotNull($user->two_factor_recovery_codes);
}

public function test_user_must_confirm_two_factor_before_it_is_active()
{
    $user = User::factory()->create();
    $this->actingAs($user);

    $this->post('/user/two-factor-authentication');
    $user->refresh();

    $google2fa = new Google2FA();
    $secret = decrypt($user->two_factor_secret);
    $validCode = $google2fa->getCurrentOtp($secret);

    $response = $this->post('/user/confirmed-two-factor-authentication', [
        'code' => $validCode,
    ]);

    $user->refresh();
    $this->assertNotNull($user->two_factor_confirmed_at);
}

public function test_user_can_login_with_two_factor_code()
{
    $user = User::factory()->create(['password' => bcrypt('password')]);
    $this->actingAs($user);
    $this->post('/user/two-factor-authentication');

    $google2fa = new Google2FA();
    $secret = decrypt($user->two_factor_secret);
    $validCode = $google2fa->getCurrentOtp($secret);

    $this->post('/user/confirmed-two-factor-authentication', ['code' => $validCode]);

    $this->post('/logout');

    $this->post('/login', [
        'email' => $user->email,
        'password' => 'password',
    ]);

    $response = $this->post('/two-factor-challenge', [
        'code' => $google2fa->getCurrentOtp($secret),
    ]);

    $response->assertRedirect('/dashboard'); // or wherever you redirect after login
    $this->assertAuthenticatedAs($user);
}

public function test_user_can_login_with_recovery_code()
{
    $user = User::factory()->create(['password' => bcrypt('password')]);
    $this->actingAs($user);
    $this->post('/user/two-factor-authentication');

    $recoveryCodes = json_decode(decrypt($user->fresh()->two_factor_recovery_codes), true);
    $validRecoveryCode = $recoveryCodes[0];

    $google2fa = new Google2FA();
    $secret = decrypt($user->two_factor_secret);
    $validCode = $google2fa->getCurrentOtp($secret);

    $this->post('/user/confirmed-two-factor-authentication', ['code' => $validCode]);
    $this->post('/logout');

    $this->post('/login', [
        'email' => $user->email,
        'password' => 'password',
    ]);

    $response = $this->post('/two-factor-challenge', [
        'recovery_code' => $validRecoveryCode,
    ]);

    $response->assertRedirect('/dashboard');
    $this->assertAuthenticatedAs($user);

    // Recovery code should be used and no longer valid
    $user->refresh();
    $updatedCodes = json_decode(decrypt($user->two_factor_recovery_codes), true);
    $this->assertNotContains($validRecoveryCode, $updatedCodes);
}
```

## Implementing 2FA for API / Sanctum token authentication

Fortify's 2FA is designed for session-based auth. For API authentication with Sanctum, you need a custom flow:

1. User logs in with credentials via API and receives a temporary session or token.
2. Check if `$user->two_factor_secret` exists.
3. If yes, return a response indicating 2FA is required (e.g., `{ "two_factor_required": true }`).
4. Client prompts for TOTP code and sends it in a second request.
5. Validate the code using `Google2FA::verifyKey()`.
6. If valid, issue a full Sanctum token with appropriate abilities.

**Example controller:**

```php
use PragmaRX\Google2FA\Google2FA;
use Illuminate\Support\Facades\Hash;

public function login(Request $request)
{
    $request->validate([
        'email' => 'required|email',
        'password' => 'required',
    ]);

    $user = User::where('email', $request->email)->first();

    if (! $user || ! Hash::check($request->password, $user->password)) {
        return response()->json(['message' => 'Invalid credentials'], 422);
    }

    if ($user->two_factor_secret) {
        // Store user ID in session or return a temporary token for 2FA step
        session(['2fa_user_id' => $user->id]);
        return response()->json(['two_factor_required' => true]);
    }

    $token = $user->createToken('api-token')->plainTextToken;
    return response()->json(['token' => $token]);
}

public function verifyTwoFactor(Request $request, Google2FA $google2fa)
{
    $request->validate(['code' => 'required|digits:6']);

    $userId = session('2fa_user_id');
    if (! $userId) {
        return response()->json(['message' => 'Unauthorized'], 401);
    }

    $user = User::findOrFail($userId);
    $secret = decrypt($user->two_factor_secret);

    $valid = $google2fa->verifyKey($secret, $request->code);

    if (! $valid) {
        return response()->json(['message' => 'Invalid code'], 422);
    }

    session()->forget('2fa_user_id');
    $token = $user->createToken('api-token')->plainTextToken;
    return response()->json(['token' => $token]);
}
```

This is a basic example. For production, use encrypted temporary tokens instead of sessions, add rate limiting on 2FA attempts, and use token abilities to mark tokens as 2FA-verified.

## Security best practices for production

Always use HTTPS in production. TOTP secrets and recovery codes should never be sent over unencrypted connections.

Fortify encrypts `two_factor_secret` and `two_factor_recovery_codes` automatically using Laravel's encryption. Make sure your `APP_KEY` is secure and never commit it to version control.

Add throttle middleware to `/two-factor-challenge` to prevent brute-force attacks. Limit it to 5 attempts per minute per user:

```php
Route::post('/two-factor-challenge', [...])->middleware('throttle:5,1');
```

Fortify stores recovery codes hashed. When users enter a recovery code, it's checked against the hash and then removed from the list.

Log when 2FA is enabled, disabled, or when recovery codes are used. Set up alerts for suspicious activity like multiple failed 2FA attempts or 2FA being disabled from a new location.

Give users clear instructions on setting up 2FA, saving recovery codes, and what to do if they lose access. A help page with screenshots is useful.

Let users contact support to verify their identity via email or phone if they get locked out. Document your account recovery process.

Keep `laravel/fortify` and `pragmarx/google2fa` updated for security patches.

## Troubleshooting common issues

"Invalid authentication code" during confirmation:
- Check that the user's device time is synced. TOTP depends on accurate time. Even a 30-second drift will break the codes.
- Make sure the secret decrypts correctly. If `APP_KEY` changed after you generated the secret, decryption fails.
- Verify the QR code has the right secret. Print `decrypt($user->two_factor_secret)` and manually generate a code with Google Authenticator to test.

Users locked out after enabling 2FA:
- Test the recovery code flow before you deploy 2FA.
- Make sure the confirmation step works. Don't mark 2FA as enabled until `two_factor_confirmed_at` is set.
- Give administrators a way to disable 2FA via CLI: `php artisan tinker` then `User::find($id)->update(['two_factor_secret' => null]);`

QR code not displaying:
- Check that the `/user/two-factor-qr-code` route works and returns SVG content.
- If your frontend and backend are on different domains, check CORS settings. See: [Laravel API Authentication with Sanctum]({{< relref "blog/laravel/laravel-api-authentication-sanctum-2025.md" >}}).
- Make sure the `twoFactorQrCodeSvg()` method exists on the User model. Check that the `TwoFactorAuthenticatable` trait is used.

2FA works locally but fails in production:
- Check that `APP_KEY` is the same in both environments. Different keys break encryption.
- Clear the config cache: `php artisan config:clear && php artisan config:cache`.
- Make sure these database columns exist: `two_factor_secret`, `two_factor_recovery_codes`, `two_factor_confirmed_at`. Re-run migrations if they're missing.
- Verify session and cookie settings for HTTPS: [Fixing Laravel Session and Cache Issues]({{< relref "blog/laravel/fixing-laravel-session-cache-issues.md" >}}).

High server load during TOTP validation:
- TOTP validation doesn't use much CPU, but if you have millions of requests, cache failed attempts to avoid repeated database lookups.
- Index the `two_factor_secret` column if you query it often, though it's usually only checked once per login.

## Advanced: Custom 2FA challenges and UI

Fortify is headless, so you have full control over the UI. Build a custom React, Vue, or mobile app frontend:

**React example (2FA setup component):**

```jsx
function Enable2FA() {
  const [qrCode, setQrCode] = useState('');
  const [recoveryCodes, setRecoveryCodes] = useState([]);
  const [code, setCode] = useState('');

  const enable = async () => {
    await axios.post('/user/two-factor-authentication');
    const qr = await axios.get('/user/two-factor-qr-code');
    const codes = await axios.get('/user/two-factor-recovery-codes');
    setQrCode(qr.data.svg);
    setRecoveryCodes(codes.data);
  };

  const confirm = async () => {
    try {
      await axios.post('/user/confirmed-two-factor-authentication', { code });
      alert('2FA enabled successfully!');
    } catch (err) {
      alert('Invalid code');
    }
  };

  return (
    <div>
      <button onClick={enable}>Enable 2FA</button>
      {qrCode && (
        <>
          <div dangerouslySetInnerHTML={{ __html: qrCode }} />
          <input value={code} onChange={(e) => setCode(e.target.value)} placeholder="Enter code" />
          <button onClick={confirm}>Confirm</button>
          <h3>Recovery Codes (save these!):</h3>
          <ul>{recoveryCodes.map((c) => <li key={c}>{c}</li>)}</ul>
        </>
      )}
    </div>
  );
}
```

For a full SPA setup with Inertia.js, see: [Laravel Integration with React and Vue]({{< relref "blog/laravel/laravel-integration-react-vue-inertia.md" >}}).

## Alternative packages and approaches

spatie/laravel-one-time-passwords (released May 2025): A newer package with flexible OTP generation for email, SMS, or TOTP. Good if you need custom OTP delivery methods beyond TOTP.

pragmarx/google2fa-laravel: Direct Google2FA integration without Fortify. Use this if you want full control over all 2FA logic and don't need Fortify's other features.

Laravel Jetstream/Breeze: Pre-built 2FA UI using Fortify. Fastest setup for new projects but less flexible than using Fortify alone.

For most projects, Fortify gives you the best balance of flexibility and built-in security.

## Summary

Laravel Fortify makes TOTP-based 2FA simple to set up. Install the package, enable the feature, add the `TwoFactorAuthenticatable` trait to your User model, and build your frontend to work with Fortify's routes.

Always require code confirmation before enabling 2FA to prevent lockouts. Generate and display recovery codes, and enforce password confirmation for 2FA changes.

Add rate limiting on the challenge endpoint, monitor 2FA events, and teach users to save their recovery codes. Test the complete flow including login with TOTP codes and recovery codes. Make sure your production environment uses HTTPS with proper encryption.

Following these practices gives you a secure, user-friendly multi-factor authentication system that reduces account takeover risk. For more security layers, check out [Laravel Security Best Practices for Production]({{< relref "blog/laravel/laravel-security-best-practices-production.md" >}}) and [Laravel Production Monitoring and Error Tracking]({{< relref "blog/laravel/laravel-production-monitoring-error-tracking.md" >}}).
