---
title: 'How to Implement Role-Based Access Control (RBAC) in Laravel with Spatie Permission'
date: 2025-10-23T09:00:00+07:00
draft: false
url: /2025/10/how-to-implement-rbac-laravel-spatie-permission.html
tags:
- Laravel
- RBAC
- Authorization
- Spatie
- Permissions
- Security
description: 'Learn how to implement Role-Based Access Control (RBAC) in Laravel using Spatie Permission package. Complete guide covering roles, permissions, middleware, Blade directives, API protection, and database seeding.'
keywords: ['laravel rbac','spatie permission','laravel authorization','laravel roles','laravel permissions','role based access control','spatie laravel permission','laravel middleware','laravel gates','laravel policies']
featured: false
faq:
  - question: "What is the difference between roles and permissions in Laravel RBAC?"
    answer: "Permissions are specific actions users can perform like create-post, edit-user, or delete-comment. Roles are groups of permissions assigned to users like admin, editor, or moderator. One role can have multiple permissions, and one user can have multiple roles. For example, an editor role might have create-post, edit-post, and publish-post permissions, while a moderator role has delete-comment and ban-user permissions. This separation lets you manage access control flexibly without assigning individual permissions to every user."
  - question: "Should I use Spatie Permission or build custom RBAC with Gates and Policies?"
    answer: "Use Spatie Permission for database-driven roles and permissions where non-developers need to manage access through an admin panel. It handles role assignment, permission checking, and database storage automatically. Use Gates and Policies for code-based authorization logic that rarely changes, like checking if a user owns a resource. For most applications, combine both: Spatie for role management and Policies for resource-specific checks like authorizing post updates only by the author. Spatie saves development time but adds database overhead."
  - question: "How do I protect API routes with roles and permissions?"
    answer: "Use Spatie's middleware on API routes: Route::middleware(['auth:sanctum', 'role:admin'])->get('/admin/users', ...). For permissions, use Route::middleware(['auth:sanctum', 'permission:edit-user'])->put('/users/{id}', ...). In controllers, check permissions programmatically with $user->hasPermissionTo('create-post') or authorize with if (!auth()->user()->can('delete-comment')) abort(403). For token-based APIs with Sanctum, assign permissions to tokens using abilities. Combine Sanctum token abilities with Spatie permissions for fine-grained API access control."
  - question: "Can I assign permissions directly to users or only through roles?"
    answer: "Spatie Permission supports both. You can assign permissions directly to users with $user->givePermissionTo('edit-post') or through roles with $role->givePermissionTo('edit-post') then $user->assignRole('editor'). Direct permissions are useful for special cases where one user needs extra access without creating a new role. However, managing permissions through roles is cleaner for most cases because you can update role permissions once and affect all users with that role. Use direct permissions sparingly for exceptions, and roles for standard access patterns."
  - question: "How do I handle super admin users who should bypass all permission checks?"
    answer: "Register a Gate::before callback in AuthServiceProvider that grants super admins all permissions: Gate::before(function ($user, $ability) { return $user->hasRole('super-admin') ? true : null; }). Return true to grant access, null to continue normal checks. This runs before every authorization check. Alternatively, create a super-admin role and assign all permissions to it, then use a seeder to keep it updated. The Gate::before approach is cleaner because you don't need to maintain permission lists. Always protect super admin assignment - only allow it through seeders or secure admin interfaces."
  - question: "What's the performance impact of using Spatie Permission on every request?"
    answer: "Spatie Permission caches permissions and roles in memory after the first query, so the impact is minimal for subsequent checks on the same request. For high-traffic apps, enable Laravel's cache driver (Redis recommended) - Spatie automatically caches roles and permissions there. Each hasPermissionTo() or hasRole() call hits cache, not the database. Reset cache when roles/permissions change using php artisan permission:cache-reset or call $user->forgetCachedPermissions(). Avoid checking permissions in loops - cache the result before the loop. For APIs, cache user permissions when generating tokens to avoid lookups on every request."
---

Role-Based Access Control (RBAC) lets you manage what users can do in your application by assigning them roles and permissions. Instead of checking if a specific user can edit posts, you check if they have the editor role or the edit-posts permission. This makes access control flexible and maintainable.

Laravel's Spatie Permission package handles all the database tables, relationships, and helper methods you need for RBAC. This guide walks through installing Spatie Permission, creating roles and permissions, assigning them to users, protecting routes and controllers, using Blade directives, and testing everything.

<!--readmore-->

## When to use RBAC

Use RBAC when different user types need different access levels. Common scenarios:

- Admin panels where admins manage everything but editors only manage content
- Multi-tenant apps where users have different permissions per organization
- SaaS applications with tiered feature access (free, pro, enterprise)
- Content management systems with writers, editors, and publishers
- Any app where you need an admin UI to manage who can do what

Skip RBAC if your app only has two user types (admin and regular user) with simple checks. A simple is_admin boolean might be enough. Use RBAC when you need three or more roles or when non-developers need to manage permissions.

## Install Spatie Permission package

Install via Composer:

```bash
composer require spatie/laravel-permission
```

Publish the migration and config:

```bash
php artisan vendor:publish --provider="Spatie\Permission\PermissionServiceProvider"
```

This creates:
- Migration file for roles and permissions tables
- Config file at `config/permission.php`

Run migrations:

```bash
php artisan migrate
```

This adds four tables:
- `roles` - stores role names
- `permissions` - stores permission names
- `model_has_roles` - assigns roles to users
- `model_has_permissions` - assigns permissions directly to users
- `role_has_permissions` - assigns permissions to roles

## Add the HasRoles trait to User model

Open `app/Models/User.php` and add the trait:

```php
<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Spatie\Permission\Traits\HasRoles;

class User extends Authenticatable
{
    use HasRoles;

    // ... rest of your model
}
```

This adds methods like `assignRole()`, `hasPermissionTo()`, `can()`, etc. to your User model.

## Create roles and permissions

Create roles and permissions in a seeder, migration, or admin panel. Here's a seeder approach:

```bash
php artisan make:seeder RolePermissionSeeder
```

Edit `database/seeders/RolePermissionSeeder.php`:

```php
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

class RolePermissionSeeder extends Seeder
{
    public function run()
    {
        // Reset cached roles and permissions
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        // Create permissions
        Permission::create(['name' => 'create-post']);
        Permission::create(['name' => 'edit-post']);
        Permission::create(['name' => 'delete-post']);
        Permission::create(['name' => 'publish-post']);
        Permission::create(['name' => 'manage-users']);
        Permission::create(['name' => 'manage-roles']);

        // Create roles and assign permissions
        $writerRole = Role::create(['name' => 'writer']);
        $writerRole->givePermissionTo(['create-post', 'edit-post']);

        $editorRole = Role::create(['name' => 'editor']);
        $editorRole->givePermissionTo(['create-post', 'edit-post', 'delete-post', 'publish-post']);

        $adminRole = Role::create(['name' => 'admin']);
        $adminRole->givePermissionTo(Permission::all());

        // Assign super admin to first user
        $superAdmin = \App\Models\User::find(1);
        if ($superAdmin) {
            $superAdmin->assignRole('admin');
        }
    }
}
```

Run the seeder:

```bash
php artisan db:seed --class=RolePermissionSeeder
```

## Assign roles to users

Assign roles when creating users or through an admin interface:

```php
use App\Models\User;

$user = User::find(1);

// Assign a single role
$user->assignRole('writer');

// Assign multiple roles
$user->assignRole(['writer', 'editor']);

// Or using role model
$user->assignRole(Role::findByName('admin'));

// Remove roles
$user->removeRole('writer');

// Sync roles (removes old roles, adds new ones)
$user->syncRoles(['editor']);
```

Check if a user has a role:

```php
if ($user->hasRole('admin')) {
    // User is admin
}

// Check for any of these roles
if ($user->hasAnyRole(['admin', 'editor'])) {
    // User is admin OR editor
}

// Check for all roles
if ($user->hasAllRoles(['writer', 'editor'])) {
    // User is both writer AND editor
}

// Get all roles
$roles = $user->getRoleNames(); // Returns collection of role names
```

## Assign permissions to users

You can assign permissions directly to users (bypassing roles):

```php
// Give permission directly
$user->givePermissionTo('edit-post');

// Give multiple permissions
$user->givePermissionTo(['edit-post', 'delete-post']);

// Revoke permission
$user->revokePermissionTo('delete-post');

// Sync permissions
$user->syncPermissions(['edit-post', 'publish-post']);
```

Check permissions:

```php
if ($user->hasPermissionTo('edit-post')) {
    // User can edit posts
}

// Check for any permission
if ($user->hasAnyPermission(['edit-post', 'delete-post'])) {
    // User has at least one of these permissions
}

// Using Laravel's can() method (works with Spatie)
if ($user->can('edit-post')) {
    // User can edit posts
}
```

Direct permissions are useful for one-off access. For example, giving a specific user temporary admin access without making them an admin.

## Protect routes with middleware

Spatie provides middleware to protect routes by role or permission.

Register middleware aliases in `bootstrap/app.php` (Laravel 11) or `app/Http/Kernel.php` (Laravel 10):

For Laravel 11:

```php
->withMiddleware(function (Middleware $middleware) {
    $middleware->alias([
        'role' => \Spatie\Permission\Middleware\RoleMiddleware::class,
        'permission' => \Spatie\Permission\Middleware\PermissionMiddleware::class,
        'role_or_permission' => \Spatie\Permission\Middleware\RoleOrPermissionMiddleware::class,
    ]);
})
```

For Laravel 10 and below, add to `$middlewareAliases` in `app/Http/Kernel.php`:

```php
protected $middlewareAliases = [
    // ...
    'role' => \Spatie\Permission\Middleware\RoleMiddleware::class,
    'permission' => \Spatie\Permission\Middleware\PermissionMiddleware::class,
    'role_or_permission' => \Spatie\Permission\Middleware\RoleOrPermissionMiddleware::class,
];
```

Protect routes:

```php
// Only admins can access
Route::middleware(['auth', 'role:admin'])->group(function () {
    Route::get('/admin/users', [UserController::class, 'index']);
    Route::post('/admin/users', [UserController::class, 'store']);
});

// Multiple roles (user needs ANY of these roles)
Route::middleware(['auth', 'role:admin|editor'])->group(function () {
    Route::get('/posts/pending', [PostController::class, 'pending']);
});

// Require permission
Route::middleware(['auth', 'permission:edit-post'])->group(function () {
    Route::put('/posts/{post}', [PostController::class, 'update']);
});

// Multiple permissions (user needs ALL of these)
Route::middleware(['auth', 'permission:edit-post,publish-post'])->group(function () {
    Route::post('/posts/{post}/publish', [PostController::class, 'publish']);
});

// Role OR permission
Route::middleware(['auth', 'role_or_permission:admin|edit-post'])->group(function () {
    Route::get('/posts/{post}/edit', [PostController::class, 'edit']);
});
```

If a user doesn't have the required role or permission, they get a 403 Forbidden error.

## Check permissions in controllers

Check permissions programmatically in controller methods:

```php
public function update(Request $request, Post $post)
{
    // Throw 403 if user doesn't have permission
    abort_unless(auth()->user()->can('edit-post'), 403);

    // Or use authorize helper
    $this->authorize('edit-post');

    // Or check manually
    if (!auth()->user()->hasPermissionTo('edit-post')) {
        return response()->json(['error' => 'Unauthorized'], 403);
    }

    $post->update($request->validated());

    return response()->json($post);
}
```

Using `authorize()` is cleaner and works with Laravel's authorization system.

## Use Blade directives in views

Show or hide UI elements based on roles and permissions:

```blade
@role('admin')
    <a href="/admin">Admin Panel</a>
@endrole

@hasrole('admin|editor')
    <button>Edit Content</button>
@endhasrole

@hasanyrole('admin|editor|writer')
    <a href="/posts/create">Create Post</a>
@endhasanyrole

@permission('delete-post')
    <button>Delete Post</button>
@endpermission

@haspermission('edit-post|delete-post')
    <div class="post-actions">...</div>
@endhaspermission

@unlessrole('admin')
    <p>You need admin access</p>
@endunlessrole
```

You can also use Laravel's built-in `@can` directive (works with Spatie):

```blade
@can('edit-post')
    <button>Edit</button>
@endcan

@cannot('delete-post')
    <p>You cannot delete this post</p>
@endcannot
```

## Combine roles and direct permissions

Users can have both roles and direct permissions. Spatie checks both:

```php
$user->assignRole('writer');
$user->givePermissionTo('manage-users'); // Extra permission not in writer role

// Returns true if user has writer role OR the specific permission
if ($user->hasPermissionTo('manage-users')) {
    // True - user has direct permission
}

if ($user->hasPermissionTo('edit-post')) {
    // True - user has this through writer role
}
```

Get all permissions (from roles AND direct assignments):

```php
$permissions = $user->getAllPermissions(); // Collection of permission models
$permissionNames = $user->getPermissionNames(); // Collection of permission names
```

This is useful when you need to give specific users extra permissions without creating new roles.

## Protect API routes

For APIs protected with Sanctum:

```php
Route::middleware(['auth:sanctum', 'permission:edit-post'])->group(function () {
    Route::put('/api/posts/{post}', [PostController::class, 'update']);
});
```

In API controllers, return JSON errors:

```php
public function destroy(Post $post)
{
    if (!auth()->user()->hasPermissionTo('delete-post')) {
        return response()->json([
            'message' => 'You do not have permission to delete posts'
        ], 403);
    }

    $post->delete();

    return response()->json(['message' => 'Post deleted']);
}
```

Combine Sanctum token abilities with Spatie permissions for double protection. See: [Laravel API Authentication with Sanctum]({{< relref "blog/laravel/laravel-api-authentication-sanctum-2025.md" >}}).

## Super admin bypass

Grant super admins all permissions automatically with a Gate::before callback.

Add to `app/Providers/AuthServiceProvider.php`:

```php
use Illuminate\Support\Facades\Gate;

public function boot()
{
    Gate::before(function ($user, $ability) {
        return $user->hasRole('super-admin') ? true : null;
    });
}
```

Return `true` to grant access, `null` to continue normal permission checks. Now any user with the `super-admin` role passes all permission checks.

Create the super-admin role in your seeder:

```php
$superAdminRole = Role::create(['name' => 'super-admin']);
$superAdminRole->givePermissionTo(Permission::all());
```

## Create a role and permission manager UI

Build an admin interface to manage roles and permissions without touching code:

```php
// routes/web.php
Route::middleware(['auth', 'role:admin'])->prefix('admin')->group(function () {
    Route::resource('roles', RoleController::class);
    Route::resource('permissions', PermissionController::class);
    Route::post('roles/{role}/permissions', [RoleController::class, 'attachPermissions']);
});
```

Example controller:

```php
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

class RoleController extends Controller
{
    public function index()
    {
        $roles = Role::with('permissions')->get();
        return view('admin.roles.index', compact('roles'));
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|unique:roles,name',
        ]);

        Role::create($validated);

        return redirect()->route('roles.index')->with('success', 'Role created');
    }

    public function attachPermissions(Request $request, Role $role)
    {
        $validated = $request->validate([
            'permissions' => 'required|array',
            'permissions.*' => 'exists:permissions,name',
        ]);

        $role->syncPermissions($validated['permissions']);

        return back()->with('success', 'Permissions updated');
    }
}
```

This lets non-developers manage access control through an admin panel.

## Handle multiple guards

If you use multiple guards (web and api), specify the guard:

```php
// Create permission for specific guard
Permission::create(['name' => 'edit-post', 'guard_name' => 'api']);

// Assign role with specific guard
$user->assignRole('admin', 'api');

// Check permission with guard
$user->hasPermissionTo('edit-post', 'api');
```

Spatie defaults to the default guard in `config/auth.php`. Only specify guards if you use multiple authentication systems.

## Cache permissions for performance

Spatie caches roles and permissions automatically. When you change them, clear the cache:

```bash
php artisan permission:cache-reset
```

Or in code:

```php
app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();
```

For high-traffic apps, use Redis for caching. Set `CACHE_DRIVER=redis` in `.env`.

To manually cache after changes:

```php
$role->givePermissionTo('edit-post');
app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();
```

This ensures users see permission changes immediately.

## Testing RBAC

Test your authorization logic:

```php
use App\Models\User;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

public function test_admin_can_access_admin_panel()
{
    $admin = User::factory()->create();
    $admin->assignRole('admin');

    $response = $this->actingAs($admin)->get('/admin/users');

    $response->assertOk();
}

public function test_writer_cannot_delete_posts()
{
    $writer = User::factory()->create();
    $writer->assignRole('writer');

    $response = $this->actingAs($writer)->delete('/posts/1');

    $response->assertForbidden();
}

public function test_user_with_permission_can_edit_post()
{
    $user = User::factory()->create();
    $user->givePermissionTo('edit-post');

    $this->assertTrue($user->hasPermissionTo('edit-post'));
}

public function test_super_admin_bypasses_all_checks()
{
    $superAdmin = User::factory()->create();
    $superAdmin->assignRole('super-admin');

    // Should pass even without specific permission
    $this->assertTrue($superAdmin->can('any-random-permission'));
}
```

Test both route protection and permission checks in your logic.

## Common mistakes to avoid

Don't check roles when you should check permissions:

```php
// Bad - checking role
if ($user->hasRole('admin')) {
    $post->delete();
}

// Good - check permission
if ($user->hasPermissionTo('delete-post')) {
    $post->delete();
}
```

Roles can change. Permissions describe what users can actually do.

Don't forget to reset cache after changing permissions in production:

```php
$role->givePermissionTo('new-permission');
app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();
```

Don't assign permissions one by one in loops:

```php
// Bad - runs many queries
foreach ($permissions as $permission) {
    $role->givePermissionTo($permission);
}

// Good - runs one query
$role->givePermissionTo($permissions);
```

Don't create too many granular permissions. `edit-post` is better than `edit-post-title` and `edit-post-content`. Keep permissions at a reasonable level of detail.

## Permissions vs Policies

Use Spatie permissions for role-based access (can this user type do this action). Use Laravel policies for resource-based access (can this user edit this specific post).

Combine both:

```php
// In PostPolicy
public function update(User $user, Post $post)
{
    // Check permission AND ownership
    return $user->hasPermissionTo('edit-post') && $user->id === $post->user_id;
}
```

Spatie handles who can perform an action type. Policies handle who can perform an action on a specific resource.

For resource ownership, see Laravel's policy documentation. For role-based access, use Spatie Permission.

## Summary

Spatie Permission makes RBAC simple in Laravel. Install the package, create roles and permissions in seeders, assign them to users, and protect routes with middleware.

Use role and permission middleware on routes, check permissions in controllers with `hasPermissionTo()`, and show/hide UI with Blade directives. Build an admin panel to let non-developers manage access.

Cache permissions with Redis in production and reset cache when changing permissions. Test your authorization logic to ensure users only access what they should.

For more on securing Laravel apps, see [Laravel Security Best Practices for Production]({{< relref "blog/laravel/laravel-security-best-practices-production.md" >}}) and [Laravel 2FA Implementation]({{< relref "blog/laravel/laravel-two-factor-authentication-2fa-fortify.md" >}}).
