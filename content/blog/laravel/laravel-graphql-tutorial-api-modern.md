---
title: 'Modern API Tutorial for Complex Applications'
date: 2025-09-18T07:00:00+07:00
draft: false
url: /2025/09/laravel-graphql-tutorial-api-modern.html
tags:
- Laravel
- GraphQL
- API
- Modern Development
description: 'Build a robust GraphQL API in Laravel with Lighthouse: schema-first design, queries, mutations, pagination, filtering, auth with Sanctum, policies, N+1 fixes with DataLoader, complexity limits, and production hardening.'
keywords: ['laravel graphql','lighthouse laravel','graphql schema first','graphql pagination laravel','graphql authorization policies','graphql sanctum laravel','graphql dataloader laravel','graphql query complexity depth','graphql file upload laravel']
featured: false
faq:
  - question: "When should I use GraphQL instead of REST API in Laravel?"
    answer: "Use GraphQL when: (1) Clients need flexible data shapes—mobile app needs minimal fields, web dashboard needs full details. (2) You have complex nested relationships—fetching user with posts, comments, and authors in one request. (3) Multiple clients consume the API—iOS, Android, web each need different fields. (4) You want to avoid API versioning—add new fields without breaking existing queries. (5) You need strongly-typed contracts with schema validation. Use REST when: (1) Simple CRUD operations with predictable responses. (2) Heavy caching needs—REST URLs are easier to cache. (3) Team lacks GraphQL experience. (4) Public APIs benefit from standard REST conventions. GraphQL adds complexity—only use when flexibility justifies the overhead."
  - question: "What is schema-first design and why is it better than code-first in GraphQL?"
    answer: "Schema-first writes the GraphQL schema (types, queries, mutations) in SDL files (schema.graphql) before writing resolvers. Code-first generates schema from PHP classes/annotations. Schema-first benefits: (1) Schema is the source of truth—frontend and backend teams agree on contracts before implementation. (2) Language-agnostic—schema.graphql can be shared with mobile teams using Swift/Kotlin clients. (3) Easier to review—schema changes visible in pull requests without reading resolver code. (4) Tools work better—GraphQL Playground, introspection, and codegen rely on schema. (5) Lighthouse is optimized for schema-first with directives like @paginate, @guard. Code-first ties schema to PHP—harder to share and review. Industry standard is schema-first for API contracts."
  - question: "How do I prevent N+1 queries in Laravel GraphQL with Lighthouse?"
    answer: "Use three strategies: (1) Relationship directives—@hasMany, @belongsTo, @morphMany automatically eager-load relationships: type User { orders: [Order!]! @hasMany } batches queries. (2) DataLoader with @batch—for custom resolvers, collect keys and batch-load: detail: Sku @batch(key: 'sku', resolver: 'SkuLoader@load') runs one query for all SKUs requested. (3) Explicit eager loading—in custom resolvers, use Model::with(['user', 'items'])->get() before returning. Avoid: writing resolvers that call $order->user inside loops. Test with Laravel Debugbar: if query count scales with result count (50 orders = 51 queries), you have N+1. Lighthouse makes this easier than REST—directives handle most cases automatically. Always use @paginate to limit result sets."
  - question: "What's the difference between @guard, @auth, and @can directives in Lighthouse?"
    answer: "@guard checks authentication—fails if user not logged in: me: User @guard(with: ['sanctum']) @auth requires authentication AND sets user context for field. @can checks authorization policies—fails if user can't perform ability: user: User @can(ability: 'view', find: 'id') calls UserPolicy::view($user, $targetUser). Chain them: myOrders: [Order!]! @guard(with: ['sanctum']) @whereAuth(relation: 'user') ensures user is logged in AND only sees their orders. @guard is authentication (who are you?), @can is authorization (can you do this?). Use @guard on root queries, @can on nested fields with policies. For complex rules, write policies: php artisan make:policy OrderPolicy and use @can(ability: 'update') on fields. Sanctum issues tokens, @guard verifies them, @can enforces permissions."
  - question: "How do I prevent expensive or malicious queries from abusing my GraphQL API?"
    answer: "Implement five defenses: (1) Query complexity limits—set max_query_complexity: 200 in config/lighthouse.php. Lighthouse calculates cost based on nesting and pagination. (2) Query depth limits—set max_query_depth: 15 to prevent deeply nested queries that recurse relationships. (3) Pagination caps—set pagination.max_count: 100 so clients can't request 10,000 records. (4) Rate limiting—apply throttle:api middleware to /graphql route. (5) Timeout limits—set max_execution_time in php.ini or PHP-FPM config. Monitor with APM tools (New Relic, Datadog) for slow queries. Disable introspection in production if API is private: disable_introspection: true. Test with worst-case queries during load testing. These limits prevent clients from writing queries that fetch entire database or cause OOM errors."
  - question: "Is GraphQL harder to cache than REST APIs?"
    answer: "Yes, GraphQL is harder to cache because: (1) All requests hit single endpoint (/graphql) with POST—HTTP caches can't differentiate by URL. (2) Query variations are infinite—same data requested with different fields can't share cache. (3) Mutations invalidate caches unpredictably. Solutions: (1) Persisted queries—hash queries and cache by hash at CDN/gateway level. (2) Application-level caching—cache expensive resolvers by key (args + user ID): Cache::remember('user-orders:' . $userId, 300, fn() => $user->orders). (3) Response caching—use Lighthouse response cache directive for public data. (4) HTTP GET for queries with query hash. (5) DataLoader batches requests within single query execution. REST is easier: GET /users/1 caches cleanly. GraphQL requires smarter caching—use Redis/Memcached for resolver results, not full responses. Trade flexibility for caching complexity."
---

GraphQL shines when clients need flexible data shapes, fewer round trips, and typed contracts. For dashboards, mobile apps, or complex relationships, it can reduce API sprawl and speed up development. This tutorial uses Lighthouse, a mature GraphQL package for Laravel, and covers everything you need to go from a blank project to a production-ready API.

<!--readmore-->

Why GraphQL (and when not to use it)
------------------------------------
- Use GraphQL when clients need to query exactly the fields they need, combine multiple resources in one request, or evolve contracts without versioning endpoints.
- Prefer REST for simple, cacheable resources or when infrastructure, team skills, and tools already fit REST neatly.

Install Lighthouse
------------------
```bash
composer require nuwave/lighthouse
php artisan vendor:publish --provider="Nuwave\Lighthouse\LighthouseServiceProvider"
```

The publish step creates `graphql/schema.graphql` and a config file. By default, the HTTP endpoint is `/graphql` and the playground is enabled in non‑production environments.

Model and seed example data
---------------------------
Assume a basic order system: `User`, `Order`, and `OrderItem`.

```bash
php artisan make:model Order -m
php artisan make:model OrderItem -m
```

Define relationships in Eloquent:
```php
// app/Models/Order.php
class Order extends Model {
    public function user() { return $this->belongsTo(User::class); }
    public function items() { return $this->hasMany(OrderItem::class); }
}
```

Schema‑first design
-------------------
Lighthouse lets you write your schema in SDL and map it to Eloquent models and resolvers.

```graphql
# graphql/schema.graphql
type User {
  id: ID!
  name: String!
  email: String!
  orders: [Order!]! @hasMany
}

type Order {
  id: ID!
  number: String!
  status: String!
  total: Float!
  user: User! @belongsTo
  items: [OrderItem!]! @hasMany
  created_at: DateTime!
}

type OrderItem {
  id: ID!
  order: Order! @belongsTo
  sku: String!
  qty: Int!
  price: Float!
}

type Query {
  me: User @guard(with: ["sanctum"]) @auth
  orders(
    status: String @eq
    orderBy: [OrderOrderBy!]
  ): [Order!]! @paginate(defaultCount: 20) @orderBy
  order(id: ID! @eq): Order @find
}

input OrderOrderBy {
  column: OrderOrderByColumn!
  order: SortOrder! = ASC
}

enum OrderOrderByColumn { id created_at total }

type Mutation {
  createOrder(number: String!, items: [NewOrderItem!]!): Order @field(resolver: "App\\GraphQL\\Mutations\\CreateOrder@handle") @guard
}

input NewOrderItem { sku: String!, qty: Int!, price: Float! }
```

Resolvers and mutations
-----------------------
You can implement resolvers as invokable classes.

```bash
php artisan lighthouse:mutation CreateOrder
```

```php
// app/GraphQL/Mutations/CreateOrder.php
namespace App\GraphQL\Mutations;

use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Support\Facades\DB;

class CreateOrder
{
    public function handle($_, array $args)
    {
        return DB::transaction(function () use ($args) {
            $order = Order::create([
                'number' => $args['number'],
                'status' => 'pending',
                'total'  => collect($args['items'])->sum(fn($i) => $i['qty'] * $i['price']),
                'user_id'=> auth()->id(),
            ]);
            foreach ($args['items'] as $i) {
                OrderItem::create([
                    'order_id' => $order->id,
                    'sku' => $i['sku'],
                    'qty' => $i['qty'],
                    'price' => $i['price'],
                ]);
            }
            return $order->fresh();
        });
    }
}
```

Authentication and authorization
--------------------------------
For first‑party SPAs, pair GraphQL with [Laravel Sanctum]({{< relref "blog/laravel/laravel-api-authentication-sanctum-2025.md" >}}). Add `@guard(with: ["sanctum"])` to protected fields and use `@can` or policies to enforce access.

```graphql
type Query {
  me: User @guard(with: ["sanctum"]) @auth
  myOrders: [Order!]!
    @paginate(defaultCount: 20)
    @guard(with: ["sanctum"]) 
    @whereAuth(relation: "user")
}
```

For fine‑grained rules, Lighthouse can call policies:
```graphql
type Order {
  id: ID!
  number: String!
  total: Float!
  user: User! @belongsTo @can(ability: "view", find: "id")
}
```

Avoiding N+1 queries
--------------------
GraphQL encourages nested selections, which can cause N+1 queries if resolvers call the database per row. Lighthouse integrates with Eloquent eager loading and DataLoader.

- Prefer relationship directives like `@hasMany` and `@belongsTo` so Lighthouse can eager load.
- Use `@paginate` for collections to keep results bounded.
- If you write custom resolvers, batch queries with `->with()` and use loaders.

Filtering and pagination
------------------------
Lighthouse offers `@paginate`, `@orderBy`, and helpers for simple filters (`@eq`, `@where`, `@in`). For complex filters, define input types and map them to query scopes.

File uploads over GraphQL
-------------------------
Follow the GraphQL multipart request spec. Lighthouse supports it out of the box when you accept `Upload` in your schema and handle it in a resolver. Apply the same validation and storage practices as in: [Laravel File Upload Best Practices]({{< relref "blog/laravel/laravel-file-upload-validation-security.md" >}}).

Query complexity and depth limits
---------------------------------
Unbounded queries can be expensive. Set a max query depth/complexity in `config/lighthouse.php`. Keep introspection enabled unless you have a strong reason to disable it; rely on limits and auth for protection.

Error handling and logging
-------------------------
GraphQL returns partial results with an `errors` array. Map exceptions to user‑friendly messages and log server errors with context. Improve logs using the patterns in: [Advanced Laravel Debugging with Logs]({{< relref "blog/laravel/advanced-laravel-debugging-with-logs.md" >}}).

Caching and performance
-----------------------
- Cache expensive resolvers with application cache and sensible keys (args + user id).
- Use ETag/HTTP caching at the gateway if your GraphQL layer sits behind Nginx/CloudFront.
- Persisted queries reduce payload size and help gateways cache by hash.
- For wider performance tips, see: [Laravel Performance Optimization]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}}).

Sample queries and mutations
---------------------------
Query with filtering, ordering, and pagination:

```graphql
query Orders($status: String, $orderBy: [OrderOrderBy!]) {
  orders(status: $status, orderBy: $orderBy) {
    paginatorInfo { currentPage lastPage total }
    data { id number status total created_at user { id name } }
  }
}
```

Variables
```json
{ "status": "paid", "orderBy": [{"column":"created_at","order":"DESC"}] }
```

Mutation with variables:
```graphql
mutation CreateOrder($number: String!, $items: [NewOrderItem!]!) {
  createOrder(number: $number, items: $items) { id number total items { sku qty price } }
}
```

Variables
```json
{
  "number": "SO-2025-0001",
  "items": [
    {"sku":"SKU-1","qty":2,"price":19.9},
    {"sku":"SKU-2","qty":1,"price":49.0}
  ]
}
```

Using DataLoader via @batch
---------------------------
For fields that cannot be covered by relationship directives, batch lookups to avoid N+1. Lighthouse supports `@batch` using a key field and a resolver that returns a map of results.

Schema
```graphql
type Query {
  skuInfo(sku: String!): Sku @field(resolver: "App\\GraphQL\\Queries\\SkuInfo@__invoke")
}

type Sku { sku: String! title: String! price Float! }

type OrderItem {
  id: ID!
  sku: String!
  qty: Int!
  price: Float!
  detail: Sku @batch(key: "sku", resolver: "App\\GraphQL\\Loaders\\SkuByCode@load")
}
```

Batch loader
```php
// app/GraphQL/Loaders/SkuByCode.php
namespace App\GraphQL\Loaders;

class SkuByCode
{
    /**
     * @param array<string> $keys
     * @return array<string, array> Map from sku => Sku payload
     */
    public function load(array $keys): array
    {
        // Replace with a single query to your catalog service or database
        $rows = \DB::table('skus')->whereIn('sku', $keys)->get(['sku','title','price']);
        return $rows->keyBy('sku')->map(fn($r) => ['sku'=>$r->sku,'title'=>$r->title,'price'=>(float)$r->price])->all();
    }
}
```

With `@batch`, Lighthouse collects all requested `detail` fields and calls `load()` once per request, returning results keyed by the batch key. This collapses many small queries into one.

Security limits configuration
----------------------------
Set reasonable defaults in `config/lighthouse.php`:

```php
return [
    'security' => [
        'max_query_complexity' => 200, // keep within your app capacity
        'max_query_depth' => 15,
        'disable_introspection' => env('LIGHTHOUSE_DISABLE_INTROSPECTION', false),
    ],
    'route' => [
        'uri' => '/graphql',
        'middleware' => ['api'],
    ],
    'guard' => 'sanctum',
    'pagination' => [ 'default_count' => 20, 'max_count' => 100 ],
];
```

Testing the API
---------------
Use HTTP tests to send GraphQL queries and assert on JSON. Keep a set of smoke tests for critical fields and mutations.

```php
public function test_orders_query()
{
    $user = User::factory()->create();
    $this->actingAs($user);
    $query = '{ orders { data { id number total } } }';
    $this->postJson('/graphql', ['query' => $query])
         ->assertOk()
         ->assertJsonStructure(['data' => ['orders' => ['data' => [['id','number','total']]]]]);
}
```

Hardening for production
------------------------
- Rate limit the `/graphql` endpoint and protect with WAF rules if exposed publicly.
- Enforce auth on sensitive types and fields. Deny by default; allow explicitly.
- Cap query depth/complexity and set generous timeouts for the PHP‑FPM pool handling GraphQL.
- Keep a repeatable deployment routine and clear/rebuild caches. Background: [Laravel Environment Configuration]({{< relref "blog/laravel/laravel-environment-configuration-env-issues.md" >}}) and [Deploy Laravel to VPS with Nginx]({{< relref "blog/laravel/deploy-laravel-to-vps-with-nginx-complete-guide.md" >}}).
- Ensure file permissions and symlinks are correct after deploys: [Fix Laravel Permission Issues]({{< relref "blog/laravel/fix-laravel-permission-issues-production.md" >}}).

Summary
-------
GraphQL gives clients the control to fetch what they need and nothing more. With Lighthouse, you define types and relationships in a schema, protect access with Sanctum and policies, avoid N+1 issues with eager loading, and keep costs in check with limits and caching. Tie it to your existing logging and deployment practices, and you have a modern API that scales with your application’s needs.
