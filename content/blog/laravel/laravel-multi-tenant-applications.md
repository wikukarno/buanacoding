---
title: 'How to Build Multi-Tenant Applications in Laravel'
date: 2025-10-24T14:00:00+07:00
draft: false
url: /2025/10/how-to-build-multi-tenant-applications-laravel.html
tags:
- Laravel
- Multi-Tenancy
- SaaS
- Architecture
- Database
- Tenancy
description: 'Complete guide to building multi-tenant Laravel applications. Learn tenant isolation strategies, database per tenant, subdomain routing, Stancl tenancy package, data security, and scaling multi-tenant SaaS apps.'
keywords: ['laravel multi-tenant','saas laravel','tenant isolation','database per tenant','laravel tenancy','subdomain routing','multi-tenancy architecture','stancl tenancy','tenant database','laravel saas']
featured: false
faq:
  - question: "What is the difference between single-tenant and multi-tenant architecture?"
    answer: "Single-tenant means each customer gets their own separate application instance and database. Multi-tenant means one application serves multiple customers with shared infrastructure. Single-tenant offers maximum isolation and customization but costs more to maintain (multiple servers, databases, deployments). Multi-tenant is cost-effective and easier to update (one codebase, one deployment) but requires careful data isolation to prevent data leaks between tenants. Use single-tenant for enterprise clients with strict compliance needs. Use multi-tenant for SaaS products serving many smaller customers."
  - question: "Should I use database-per-tenant or shared database with tenant_id column?"
    answer: "Database-per-tenant gives stronger isolation - if one tenant's database is compromised, others stay safe. Backups are simpler, you can restore one tenant without affecting others. Migrations are easier, and you can give big clients dedicated servers. The tradeoff: more databases to manage. Shared database with tenant_id is simpler and cheaper but one SQL injection or missing WHERE tenant_id clause exposes all data. For SaaS with paying customers, use database-per-tenant. For internal tools or low-security apps, shared database works. Security should win over convenience."
  - question: "How do I identify which tenant is making a request?"
    answer: "Use subdomains (acme.yoursaas.com), custom domains (app.acmecorp.com), or path prefixes (/acme/dashboard). Subdomain is most common for SaaS. Install Stancl/Tenancy package and it automatically detects the tenant from the subdomain, switches the database connection, and runs your app in tenant context. For APIs, use a tenant identifier in headers (X-Tenant-ID) or JWT token claims. Store the current tenant in middleware and scope all queries automatically with global scopes. Never rely on client-sent tenant IDs without verification against the authenticated user."
  - question: "How do I handle tenant onboarding and database creation?"
    answer: "When a new tenant signs up, create a tenant record in your central database, generate a unique subdomain or slug, create a new database for that tenant, run migrations on the new database, seed initial data if needed, and redirect them to their subdomain. Stancl/Tenancy automates this: Tenant::create(['id' => 'acme']) creates the database, runs migrations, and sets up everything. Use queued jobs for database creation to avoid timeouts during signup. Store connection details encrypted. For scaling, create databases on separate servers and load balance based on tenant activity."
  - question: "Can I share some data between all tenants like global settings or templates?"
    answer: "Yes, use a central database for data shared across all tenants and tenant databases for customer-specific data. Your app connects to the central DB for authentication, billing, global settings, and connects to tenant DBs for customer data like posts, orders, users. Stancl/Tenancy handles this with dual connections - use the central connection explicitly when needed: DB::connection('central')->table('plans')->get(). Store templates, email layouts, and system settings in the central database. Store customer content in tenant databases. This separation keeps tenant data isolated while sharing common resources."
  - question: "What are the performance implications of multi-tenancy and how do I scale?"
    answer: "Database-per-tenant adds connection overhead - opening a new DB connection for each request is slow. Solve this with connection pooling and caching the tenant's connection details. For large tenants, move them to dedicated database servers. Use read replicas for heavy readers. Cache tenant-specific data aggressively with Redis, keyed by tenant ID. Monitor slow queries per tenant - one tenant's inefficient code shouldn't slow others. For massive scale, consider database sharding (tenant 1-1000 on server A, 1001-2000 on server B). Queue heavy operations per tenant. The main bottleneck is database connections - plan for this from the start."
---

Multi-tenant applications let you serve multiple customers (tenants) with one codebase. Each tenant gets their own data, subdomain, and isolated environment, but you maintain just one application. This is how most SaaS products work - Slack, Shopify, and Basecamp all use multi-tenancy.

This guide shows you how to build multi-tenant Laravel apps. You'll learn the different tenancy models, why database-per-tenant wins for security, how to set up tenant isolation with Stancl/Tenancy package, handle subdomain routing, manage tenant databases, and scale your multi-tenant SaaS.

<!--readmore-->

## Understanding multi-tenancy models

There are three ways to isolate tenant data:

### Database per tenant (recommended)

Each tenant gets their own database. `acme_db`, `beta_db`, `charlie_db`, etc. Strongest isolation - a security breach in one tenant's database doesn't expose others. Easy backups and restores per tenant. Simple to migrate big tenants to dedicated servers.

Cons: More databases to manage. Requires connection pooling.

### Schema per tenant

One database, multiple schemas. PostgreSQL supports this well. MySQL uses separate databases anyway.

Pros: Better than shared tables. Cons: Not as isolated as separate databases.

### Shared database with tenant_id

All tenants share the same tables. Every query needs `WHERE tenant_id = ?`. One missing WHERE clause leaks all tenant data.

Pros: Simple, cheap. Cons: Dangerous. Don't use this for anything with real customer data.

For production SaaS, use database-per-tenant.

## Install Stancl Tenancy package

Stancl/Tenancy automates multi-tenancy in Laravel. It handles database switching, tenant detection, and migrations.

Install:

```bash
composer require stancl/tenancy
```

Run the installer:

```bash
php artisan tenancy:install
```

This publishes config, migrations, and routes. Run migrations:

```bash
php artisan migrate
```

This creates `tenants` and `domains` tables in your central database.

## Configure tenancy

Open `config/tenancy.php`. Key settings:

```php
return [
    'tenant_model' => \App\Models\Tenant::class,
    'id_generator' => Stancl\Tenancy\UUIDGenerator::class,

    'database' => [
        'prefix' => 'tenant',
        'suffix' => '',
        'manager' => Stancl\Tenancy\Database\DatabaseManager::class,
    ],

    'features' => [
        Stancl\Tenancy\Features\TenantConfig::class,
        Stancl\Tenancy\Features\TenantsTable::class,
        Stancl\Tenancy\Features\UserImpersonation::class,
    ],
];
```

By default, tenant databases are named `tenant{id}`. Example: `tenant123`, `tenantacme`.

## Create tenant model

The package includes a base Tenant model. Extend it:

```bash
php artisan make:model Tenant
```

```php
<?php

namespace App\Models;

use Stancl\Tenancy\Database\Models\Tenant as BaseTenant;
use Stancl\Tenancy\Contracts\TenantWithDatabase;
use Stancl\Tenancy\Database\Concerns\HasDatabase;
use Stancl\Tenancy\Database\Concerns\HasDomains;

class Tenant extends BaseTenant implements TenantWithDatabase
{
    use HasDatabase, HasDomains;

    protected $fillable = [
        'id',
        'name',
        'email',
    ];

    public static function getCustomColumns(): array
    {
        return [
            'id',
            'name',
            'email',
        ];
    }
}
```

## Set up subdomain routing

Tenants access your app via subdomains: `acme.yoursaas.com`, `beta.yoursaas.com`.

Configure domains in `.env`:

```env
CENTRAL_DOMAINS=yoursaas.com,www.yoursaas.com
```

Add tenant routes in `routes/tenant.php` (created by installer):

```php
<?php

use Illuminate\Support\Facades\Route;
use Stancl\Tenancy\Middleware\InitializeTenancyByDomain;
use Stancl\Tenancy\Middleware\PreventAccessFromCentralDomains;

Route::middleware([
    'web',
    InitializeTenancyByDomain::class,
    PreventAccessFromCentralDomains::class,
])->group(function () {
    Route::get('/', function () {
        return 'This is your tenant area: ' . tenant('id');
    });

    Route::get('/dashboard', function () {
        return view('dashboard');
    })->middleware(['auth']);
});
```

Central routes (login, signup, landing page) stay in `routes/web.php`. They work on `yoursaas.com`.

Tenant routes work on `*.yoursaas.com` subdomains.

## Create a tenant

When a customer signs up, create a tenant:

```php
use App\Models\Tenant;

$tenant = Tenant::create([
    'id' => 'acme',
    'name' => 'Acme Corporation',
    'email' => 'admin@acme.com',
]);

$tenant->domains()->create([
    'domain' => 'acme.yoursaas.com',
]);
```

This creates:
- A record in the `tenants` table
- A new database named `tenantacme`
- Runs all tenant migrations on the new database
- Creates a domain record linking `acme.yoursaas.com` to this tenant

Now when a user visits `acme.yoursaas.com`, Stancl automatically switches to the `tenantacme` database.

## Separate central and tenant migrations

Central migrations (users, billing, tenants table) run on your main database.
Tenant migrations (posts, products, orders) run on each tenant's database.

Move tenant migrations to `database/migrations/tenant`:

```bash
mkdir database/migrations/tenant
mv database/migrations/*_create_posts_table.php database/migrations/tenant/
```

Migrations in `database/migrations/tenant` run automatically when you create a tenant or manually with:

```bash
php artisan tenants:migrate
```

This runs migrations on all tenant databases.

Roll back tenant migrations:

```bash
php artisan tenants:migrate:rollback
```

## Run code for all tenants

Execute commands or code for every tenant:

```bash
php artisan tenants:run 'cache:clear'
```

Or in code:

```php
use Stancl\Tenancy\Facades\Tenancy;

Tenancy::all()->each(function ($tenant) {
    $tenant->run(function () {
        // Code runs in this tenant's context
        Post::where('published', false)->delete();
    });
});
```

Useful for:
- Seeding data in all tenant databases
- Running maintenance tasks
- Generating reports per tenant
- Cleaning up old data

## Handle tenant signup

Create a signup flow that provisions a new tenant:

```php
use App\Models\Tenant;
use Illuminate\Support\Str;

public function store(Request $request)
{
    $validated = $request->validate([
        'name' => 'required|string',
        'email' => 'required|email',
        'subdomain' => 'required|alpha_dash|unique:domains,domain',
    ]);

    $subdomain = Str::slug($validated['subdomain']);

    $tenant = Tenant::create([
        'id' => $subdomain,
        'name' => $validated['name'],
        'email' => $validated['email'],
    ]);

    $tenant->domains()->create([
        'domain' => $subdomain . '.yoursaas.com',
    ]);

    // Create admin user in tenant database
    $tenant->run(function () use ($validated) {
        \App\Models\User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => bcrypt('temporary-password'),
        ]);
    });

    return redirect('https://' . $subdomain . '.yoursaas.com/login');
}
```

Queue database creation for large setups:

```php
dispatch(new CreateTenantDatabase($tenant));
```

## Access tenant context

Get current tenant anywhere in tenant routes:

```php
$tenant = tenant(); // Returns current Tenant model
$tenantId = tenant('id');
$tenantName = tenant('name');
```

Check if running in tenant context:

```php
if (tenancy()->initialized) {
    // We're in a tenant
}
```

Switch to tenant context manually:

```php
$tenant = Tenant::find('acme');

$tenant->run(function () {
    // Code here runs in acme's context
    $posts = Post::all(); // Queries acme's database
});
```

## Share data between central and tenant databases

Some data lives in the central database (plans, global settings) and tenant databases (customer posts, orders).

Use explicit connections:

```php
// Query central database
$plans = DB::connection('central')->table('plans')->get();

// Query tenant database (automatic in tenant routes)
$posts = Post::all();

// Or explicit tenant connection
$posts = DB::connection('tenant')->table('posts')->get();
```

Store billing, subscriptions, and tenant metadata in central. Store customer data in tenant databases.

## Handle custom domains

Let tenants use custom domains like `app.acmecorp.com` instead of `acme.yoursaas.com`:

```php
$tenant = Tenant::find('acme');

$tenant->domains()->create([
    'domain' => 'app.acmecorp.com',
]);
```

Now both `acme.yoursaas.com` and `app.acmecorp.com` route to the same tenant.

For DNS, create a CNAME record:
```
app.acmecorp.com CNAME yoursaas.com
```

Configure your web server to accept any domain. With Laravel Sail or Valet, this works automatically.

For production, use a wildcard SSL certificate or Let's Encrypt to provision SSL per custom domain.

## Seed tenant databases

Create seeders for tenant data:

```bash
php artisan make:seeder TenantDatabaseSeeder
```

```php
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Post;
use App\Models\Category;

class TenantDatabaseSeeder extends Seeder
{
    public function run()
    {
        Category::create(['name' => 'General']);
        Category::create(['name' => 'Announcements']);

        Post::factory()->count(10)->create();
    }
}
```

Run for all tenants:

```bash
php artisan tenants:seed --class=TenantDatabaseSeeder
```

Or for one tenant:

```php
$tenant = Tenant::find('acme');

$tenant->run(function () {
    $this->call(TenantDatabaseSeeder::class);
});
```

## Test multi-tenancy

Test tenant isolation:

```php
use App\Models\Tenant;
use App\Models\Post;

it('isolates data between tenants', function () {
    $tenant1 = Tenant::create(['id' => 'tenant1']);
    $tenant2 = Tenant::create(['id' => 'tenant2']);

    $tenant1->run(function () {
        Post::create(['title' => 'Tenant 1 Post']);
    });

    $tenant2->run(function () {
        $posts = Post::all();
        expect($posts)->toHaveCount(0); // Tenant 2 can't see Tenant 1's data
    });
});
```

Test subdomain routing:

```php
it('serves tenant routes on subdomains', function () {
    $tenant = Tenant::create(['id' => 'acme']);
    $tenant->domains()->create(['domain' => 'acme.localhost']);

    $response = $this->get('http://acme.localhost/dashboard');

    $response->assertOk();
    expect(tenant('id'))->toBe('acme');
});
```

## Implement tenant impersonation

Let super admins log into any tenant for support:

```php
use Stancl\Tenancy\Features\UserImpersonation;

// In your central admin panel
$tenant = Tenant::find('acme');
$impersonationUrl = UserImpersonation::makeUrl($tenant, 1); // 1 = user ID in tenant DB

return redirect($impersonationUrl);
```

This logs you into the tenant as that user. Add the feature to `config/tenancy.php`:

```php
'features' => [
    Stancl\Tenancy\Features\UserImpersonation::class,
],
```

## Handle tenant deletion

Delete a tenant and all their data:

```php
$tenant = Tenant::find('acme');

// This deletes the tenant database and all records
$tenant->delete();
```

To soft delete (keep data but mark inactive):

```php
$tenant->update(['status' => 'inactive']);
```

Archive data before deleting:

```php
// Export tenant database
$tenant->run(function () {
    $data = [
        'users' => User::all(),
        'posts' => Post::all(),
    ];

    Storage::put("archives/{$tenant->id}.json", json_encode($data));
});

$tenant->delete();
```

## Scale multi-tenant applications

Connection pooling is critical. Don't create new database connections on every request. Use Laravel's connection pool or PgBouncer for PostgreSQL.

Cache tenant data:

```php
$tenant = Cache::remember("tenant:{$domain}", 3600, function () use ($domain) {
    return Tenant::whereDomain($domain)->first();
});
```

Move large tenants to dedicated servers:

```php
// In tenants table, add server column
$tenant->update(['server' => 'tenant-db-2.yoursaas.com']);

// Override database connection
config(['database.connections.tenant.host' => $tenant->server]);
```

Queue tenant operations:

```php
dispatch(new ProcessTenantReport($tenant));
```

Monitor per-tenant usage and throttle heavy users.

## Security considerations

Never trust tenant IDs from user input. Always get the current tenant from the authenticated context:

```php
// Bad - user can send any tenant_id
$posts = Post::where('tenant_id', $request->tenant_id)->get();

// Good - Stancl automatically scopes queries
$posts = Post::all(); // Only returns current tenant's posts
```

Validate subdomain inputs to prevent creating tenants with reserved names:

```php
$reserved = ['www', 'admin', 'api', 'mail', 'ftp'];

if (in_array($request->subdomain, $reserved)) {
    return back()->withErrors(['subdomain' => 'This subdomain is reserved.']);
}
```

Encrypt sensitive tenant data with Laravel's encrypted casts.

Log tenant switches for audit trails:

```php
event(new TenantSwitched($oldTenant, $newTenant));
```

Don't share sessions across tenants. Each tenant should have isolated sessions.

## Compare Stancl vs Spatie multi-tenancy

Stancl Tenancy:
- Database-per-tenant by default
- Automatic migrations, seeders, queues
- Subdomain and domain routing built-in
- More features, more automation

Spatie Multitenancy:
- Simpler, more lightweight
- Database or shared DB with scopes
- More manual control
- Better for custom setups

For most SaaS apps, use Stancl. For advanced custom requirements, Spatie gives more flexibility.

## Summary

Multi-tenancy lets you serve multiple customers with one application. Use database-per-tenant for strong isolation, subdomain routing for easy tenant identification, and Stancl/Tenancy package to automate database creation and switching.

Separate central data (billing, plans) from tenant data (customer content). Create tenants on signup with automatic database provisioning. Test tenant isolation to ensure no data leaks.

Scale with connection pooling, caching, and dedicated servers for large tenants. Monitor usage and queue heavy operations.

For more on Laravel architecture, see [Laravel Performance Optimization]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}}) and [Laravel Security Best Practices]({{< relref "blog/laravel/laravel-security-best-practices-production.md" >}}).
