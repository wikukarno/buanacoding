---
title: 'Avoiding Fatal Mistakes'
date: 2025-09-15T10:00:00+07:00
draft: false
url: /2025/09/laravel-database-migration-best-practices.html
tags: 
- Laravel
- Database
- Migration
- Best Practices
description: 'Practical rules for safe Laravel database migrations: versioning, zero‑downtime patterns, backfilling large tables, indexes and foreign keys, renames, transactions, rollbacks, and production deployment checklists.'
keywords: ['laravel migration best practices','laravel zero downtime migration','laravel rename column doctrine dbal','laravel create index concurrently','laravel backfill data chunks','laravel foreign keys on delete','laravel migrate --force','laravel schema dump','blue green deploy laravel']
featured: false
---

Migrations let you evolve your schema alongside the code. Done well, they are repeatable and safe. Done poorly, they lock tables, drop data, and take your site down. This guide focuses on practical patterns that reduce risk in production and make rollouts predictable.

<!--readmore-->

Ground rules
------------
- Treat migrations as immutable once deployed. If a mistake gets to production, add a new migration to correct it instead of editing history.
- Keep schema and data changes separate. Data backfills belong in their own migration or a job/command so you can control runtime and retries.
- Don’t rely on application models inside migrations. Models can drift as your app evolves. Prefer `DB::table()` or raw SQL that doesn’t depend on future code.
- Test locally and in staging with the same DB engine and major version you run in production.
- Always run with `php artisan migrate --force` in CI/production. Check status with `php artisan migrate:status`.

Naming and versioning
---------------------
Use descriptive names that read like a change log: `2025_09_15_100001_add_status_to_orders_table.php`. One concern per migration. If a change requires several steps (add column → backfill → enforce NOT NULL), use separate migrations in the right order.

Zero‑downtime mindset
---------------------
Your new code must work before, during, and after the migration. The safest pattern is a two‑step rollout:
1) Deploy backward‑compatible code that does not depend on the new schema yet.
2) Run the migration.
3) Flip the code to use the new column/constraint.

For larger changes, consider feature flags and a staged rollout. For server setup and permissions that avoid 403/500 during deploys, see: [Deploy Laravel to VPS with Nginx — Complete Guide]({{< relref "blog/laravel/deploy-laravel-to-vps-with-nginx-complete-guide.md" >}}) and [Fix Laravel Permission Issues]({{< relref "blog/laravel/fix-laravel-permission-issues-production.md" >}}).

Adding columns safely
---------------------
Adding a `NOT NULL` column with a default can lock a big table or backfill every row inside a single statement. Safer pattern:
- Step 1: add the column as nullable without default.
- Step 2: backfill in batches.
- Step 3: add the default and the `NOT NULL` constraint.

Example:
```php
Schema::table('orders', function (Blueprint $table) {
    $table->unsignedTinyInteger('status')->nullable();
});

DB::table('orders')->whereNull('status')
  ->orderBy('id')
  ->chunkById(10_000, function ($rows) {
      foreach ($rows as $row) {
          DB::table('orders')->where('id', $row->id)->update(['status' => 0]);
      }
  });

Schema::table('orders', function (Blueprint $table) {
    $table->unsignedTinyInteger('status')->default(0)->nullable(false)->change();
});
```

Backfilling large tables
------------------------
Avoid long transactions and table scans. Use `chunkById`, update by primary key ranges, and run during off‑peak hours. If the backfill can take minutes, make it a queued job/command so it can resume on failure. For environment consistency and config caching pitfalls during deploys, review: [Laravel Environment Configuration]({{< relref "blog/laravel/laravel-environment-configuration-env-issues.md" >}}).

Indexes without blocking traffic
--------------------------------
Indexes speed reads but can block writes if created the wrong way.
- PostgreSQL: use `CREATE INDEX CONCURRENTLY` (cannot run inside a transaction). In Laravel, set `public $withinTransaction = false;` on the migration class and run a raw statement.
- MySQL 8 / InnoDB: many operations are online; prefer `ALGORITHM=INPLACE`/`INSTANT` where possible. Avoid operations that copy the table.

Example (PostgreSQL):
```php
class AddIndexToOrdersOnCreatedAt extends Migration
{
    public $withinTransaction = false; // required for CONCURRENTLY

    public function up(): void
    {
        DB::statement('CREATE INDEX CONCURRENTLY idx_orders_created_at ON orders (created_at)');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX CONCURRENTLY IF EXISTS idx_orders_created_at');
    }
}
```

Foreign keys and data integrity
-------------------------------
Before adding a foreign key, clean the data. A simple `SELECT` for orphaned rows saves a failed deployment. Pick the right action for your lifecycle: `ON DELETE CASCADE` for true dependents (e.g., order items), `RESTRICT` when deletion should be explicit, or `SET NULL` for optional relationships.

Renaming columns and tables
---------------------------
Laravel needs `doctrine/dbal` to rename existing columns. Even then, renames can be disruptive for large tables.
- Safer alternative: add a new column, backfill, update code to read the new column, then drop the old one later.
- If you must rename, schedule a window and ensure your code can handle both names during the transition.

Example rename with DBAL:
```bash
composer require doctrine/dbal --dev
```
```php
Schema::table('users', function (Blueprint $table) {
    $table->renameColumn('fullname', 'name');
});
```

Transactions in migrations
--------------------------
Laravel wraps migrations in a transaction when the driver supports it. Some operations (like Postgres `CONCURRENTLY`) cannot run inside one. Use the `$withinTransaction = false;` property on the migration class for those cases. For MySQL, avoid wrapping very long backfills in a single transaction; commit in batches instead.

Rolling forward vs rolling back
-------------------------------
In production, prefer forward‑only fixes. Rollbacks can fail if data has changed since the migration ran. Keep `down()` accurate for local/staging, but if a production migration goes wrong, ship a new forward migration to correct course.

Avoid logic in migrations
-------------------------
Migrations should change schema, not business rules. Don’t call application services or rely on model events/scopes. If you must move data across tables, use the query builder or raw SQL and keep scope explicit.

Seeders, data fixes, and schema dumps
-------------------------------------
Use seeders for initial content or reference tables. For long‑lived projects, prune ancient migrations with a schema dump so new installs are fast:

```bash
php artisan schema:dump --prune
```

This stores the current schema as a SQL dump and removes old migrations that are already included in the dump. Keep recent migrations that were created after the dump.

Operational checklist (copy/paste)
----------------------------------
```bash
# Pre‑deploy
php artisan test --testsuite=Unit,Feature
php artisan migrate:status

# Deploy
composer install --no-dev --prefer-dist --optimize-autoloader
php artisan migrate --force

# Post‑deploy
php artisan cache:clear && php artisan config:clear && php artisan route:clear && php artisan view:clear
php artisan config:cache && php artisan route:cache && php artisan view:cache
php artisan queue:restart || true
```

Troubleshooting and observability
---------------------------------
If a migration fails on production, read the database error first. Then check application and service logs:

```bash
tail -f storage/logs/laravel.log
sudo journalctl -u php8.2-fpm -f
sudo tail -f /var/log/nginx/error.log
```

Adopt consistent, structured logging so you can see when a deployment slows queries or increases lock wait time. For patterns and examples, see: [Advanced Laravel Debugging with Logs]({{< relref "blog/laravel/advanced-laravel-debugging-with-logs.md" >}}). If migrations affect performance, revisit indexes and caching strategies: [Laravel Performance Optimization: 15 Techniques]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}}).

Summary
-------
Ship schema changes safely by keeping migrations small and explicit, separating schema from data, backfilling in batches, using online index strategies, and choosing foreign‑key actions deliberately. Prefer forward fixes over rollbacks in production, and make deployments repeatable with a clear checklist. With these habits, migrations become dependable instead of risky.
