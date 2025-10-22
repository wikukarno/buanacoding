---
title: 'How to Create RESTful API Pagination and Filtering in Laravel'
date: 2025-10-22T12:00:00+07:00
draft: false
url: /2025/10/how-to-create-restful-api-pagination-filtering-sorting-laravel.html
tags:
- Laravel
- API
- REST
- Pagination
- Filtering
- Backend
description: 'Complete guide to building RESTful API pagination, filtering, and sorting in Laravel. Learn query parameters, cursor pagination, dynamic filters, search, performance optimization, and API resource formatting.'
keywords: ['laravel api pagination','laravel filtering','laravel sorting','restful api laravel','query parameters','cursor pagination','laravel api resources','spatie query builder','laravel eloquent filter','api best practices']
featured: false
faq:
  - question: "What is the difference between paginate() and simplePaginate() in Laravel?"
    answer: "paginate() generates full pagination with page numbers, total count, and navigation links (first, last, prev, next). It runs a COUNT query to get the total records, which can be slow on large tables. simplePaginate() only provides prev/next buttons without total count or page numbers, skipping the COUNT query. Use paginate() for traditional pagination with page numbers. Use simplePaginate() for infinite scroll or when total count isn't needed, especially on large datasets where counting millions of rows is expensive."
  - question: "Should I use offset-based pagination or cursor-based pagination for my API?"
    answer: "Use offset-based pagination (page/per_page) for small to medium datasets and when users need to jump to specific pages. It's simple and works with Laravel's paginate() out of the box. Use cursor-based pagination for large datasets, real-time feeds, or when deep pagination is slow. Cursor pagination uses WHERE clauses instead of OFFSET, which performs better on millions of records. The tradeoff: cursors don't allow jumping to arbitrary pages. For most APIs, start with offset pagination. Switch to cursors if you notice slow queries on deep pages or have time-series data."
  - question: "How do I prevent users from requesting too many items per page?"
    answer: "Set a maximum limit in your controller and cap user input. For example: $perPage = min($request->input('per_page', 15), 100). This defaults to 15 items but allows users to request up to 100 max. Document the limit in your API docs. Some APIs use 10-50 as the default and 100-200 as the maximum depending on data size. Validate the per_page parameter and return a 422 error if it exceeds the limit. For expensive resources (with many relations or calculations), use a lower maximum like 50 to protect server resources."
  - question: "What's the best way to implement search across multiple columns in Laravel API?"
    answer: "For simple search, use orWhere clauses: $query->where('name', 'LIKE', \"%$search%\")->orWhere('email', 'LIKE', \"%$search%\"). For better UX, use whereAny (Laravel 11+): $query->whereAny(['name', 'email', 'phone'], 'LIKE', \"%$search%\"). For full-text search on large datasets, use MySQL FULLTEXT indexes with whereRaw(\"MATCH(name,description) AGAINST(? IN BOOLEAN MODE)\", [$search]). For advanced search, use Laravel Scout with Algolia, Meilisearch, or Typesense. Always sanitize search input and add indexes on searched columns for performance."
  - question: "How do I maintain filter and sort parameters across pagination links?"
    answer: "Use appends() on the paginator to preserve query parameters: $users->appends($request->query()). This includes all query parameters (filters, sort, search) in pagination URLs. Alternatively, specify exact parameters: $users->appends(['search' => $request->search, 'sort' => $request->sort]). Laravel API Resources automatically include query parameters in pagination links. For custom pagination responses, use $paginator->appends() before transforming to array or JSON. This ensures clicking next/prev pages maintains the current filters and sorting."
  - question: "Should I filter in the database query or in API resources?"
    answer: "Always filter in the database query, never after fetching data. Filtering after fetching (in resources or collections) loads all records into memory, which is slow and wastes resources. Use WHERE clauses, scopes, or query builder methods to filter at the database level. Only use resources for data transformation and formatting, not filtering. For complex filters, create query scopes in your model or use Spatie Query Builder. Database-level filtering uses indexes and only loads the data you need. Filtering in PHP after fetching defeats the purpose of pagination and kills performance."
---

A good API lets clients filter, sort, and paginate through data. Nobody wants to download 10,000 records just to find a few items. This guide shows you how to add pagination, filtering, sorting, and search to your Laravel REST API.

You'll learn Laravel's built-in pagination methods, how to add query parameters for filters and sorting, search across multiple columns, cursor pagination for large datasets, and API resources for formatting responses. We'll also cover performance tips and common mistakes.

<!--readmore-->

## Why pagination and filtering matter for APIs

Without pagination, your API returns all records at once. This wastes bandwidth, slows response times, and crashes clients when datasets grow large.

Your API should let clients:
- Request specific page sizes (`?per_page=20`)
- Navigate through pages (`?page=2`)
- Filter by fields (`?status=active&category=books`)
- Sort results (`?sort=-created_at` for descending)
- Search across columns (`?search=laravel`)

This keeps responses fast and gives clients control over the data they receive.

## Basic pagination with paginate()

Laravel's `paginate()` method handles pagination automatically:

```php
use App\Models\Product;
use Illuminate\Http\Request;

public function index(Request $request)
{
    $perPage = $request->input('per_page', 15);

    $products = Product::paginate($perPage);

    return response()->json($products);
}
```

Clients call: `GET /products?page=2&per_page=20`

The response includes pagination metadata:

```json
{
  "data": [...],
  "links": {
    "first": "http://api.example.com/products?page=1",
    "last": "http://api.example.com/products?page=10",
    "prev": "http://api.example.com/products?page=1",
    "next": "http://api.example.com/products?page=3"
  },
  "meta": {
    "current_page": 2,
    "from": 16,
    "last_page": 10,
    "per_page": 15,
    "to": 30,
    "total": 150
  }
}
```

Always set a reasonable default (10-20) and a maximum limit to prevent abuse:

```php
$perPage = min($request->input('per_page', 15), 100);
```

## Simple pagination for infinite scroll

If you don't need page numbers or total count, use `simplePaginate()`:

```php
$products = Product::simplePaginate($perPage);
```

This skips the COUNT query, which speeds up responses on large tables. The response only includes `prev` and `next` links, no total count.

Use this for mobile apps with infinite scroll or feeds where users rarely jump to specific pages.

## Cursor pagination for large datasets

Cursor pagination uses WHERE clauses instead of OFFSET, which performs better on millions of records:

```php
$products = Product::orderBy('id')->cursorPaginate($perPage);
```

Request: `GET /products?cursor=eyJpZCI6MTAwfQ`

Cursors encode the position in the dataset. Clients can't jump to arbitrary pages, only move forward/backward. This is perfect for:
- Time-series data (feeds, logs, events)
- Real-time data where new items appear
- Tables with millions of rows where OFFSET is slow

The tradeoff: users can't jump to page 50 directly.

## Add filtering with query parameters

Let clients filter by specific fields:

```php
public function index(Request $request)
{
    $query = Product::query();

    if ($request->has('status')) {
        $query->where('status', $request->status);
    }

    if ($request->has('category')) {
        $query->where('category', $request->category);
    }

    if ($request->has('min_price')) {
        $query->where('price', '>=', $request->min_price);
    }

    if ($request->has('max_price')) {
        $query->where('price', '<=', $request->max_price);
    }

    $products = $query->paginate($request->input('per_page', 15));

    return response()->json($products);
}
```

Request: `GET /products?status=active&category=electronics&min_price=100&page=1`

This builds the WHERE clauses dynamically based on query parameters.

## Validate filter parameters

Users might send invalid data. Validate before querying:

```php
$validated = $request->validate([
    'status' => 'sometimes|in:active,inactive,draft',
    'category' => 'sometimes|string|max:50',
    'min_price' => 'sometimes|numeric|min:0',
    'max_price' => 'sometimes|numeric|min:0',
    'per_page' => 'sometimes|integer|min:1|max:100',
    'page' => 'sometimes|integer|min:1',
]);

$query = Product::query();

if (isset($validated['status'])) {
    $query->where('status', $validated['status']);
}

// ... rest of filters
```

This prevents SQL errors and ensures clean data.

## Implement sorting

Let clients sort by any column:

```php
$sortBy = $request->input('sort', 'created_at');
$sortDirection = 'asc';

// Support descending sort with minus prefix: ?sort=-price
if (str_starts_with($sortBy, '-')) {
    $sortDirection = 'desc';
    $sortBy = substr($sortBy, 1);
}

// Whitelist sortable columns
$allowedSorts = ['name', 'price', 'created_at', 'updated_at'];

if (in_array($sortBy, $allowedSorts)) {
    $query->orderBy($sortBy, $sortDirection);
}
```

Request: `GET /products?sort=-price` (descending by price)

Always whitelist sortable columns to prevent sorting by sensitive fields or SQL injection.

## Add search across multiple columns

Simple search with OR conditions:

```php
if ($request->has('search')) {
    $search = $request->search;

    $query->where(function($q) use ($search) {
        $q->where('name', 'LIKE', "%{$search}%")
          ->orWhere('description', 'LIKE', "%{$search}%")
          ->orWhere('sku', 'LIKE', "%{$search}%");
    });
}
```

Laravel 11 adds `whereAny()` for cleaner syntax:

```php
if ($request->has('search')) {
    $query->whereAny(
        ['name', 'description', 'sku'],
        'LIKE',
        "%{$request->search}%"
    );
}
```

For large datasets, use full-text search indexes:

```sql
ALTER TABLE products ADD FULLTEXT(name, description);
```

```php
if ($request->has('search')) {
    $query->whereRaw(
        "MATCH(name, description) AGAINST(? IN BOOLEAN MODE)",
        [$request->search]
    );
}
```

Full-text search is much faster than LIKE on large tables.

## Preserve filters across pagination

When users click "next page," filters and sorting should persist. Use `appends()`:

```php
$products = $query->paginate($perPage);

$products->appends($request->query());

return response()->json($products);
```

This includes all query parameters in pagination links:

```json
"next": "http://api.example.com/products?status=active&sort=-price&page=3"
```

Clients maintain their filters when navigating pages.

## Use API resources for clean responses

Laravel API Resources format your data:

```bash
php artisan make:resource ProductResource
```

```php
<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    public function toArray($request)
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'price' => number_format($this->price, 2),
            'status' => $this->status,
            'category' => $this->category,
            'created_at' => $this->created_at->toISOString(),
        ];
    }
}
```

Use it in your controller:

```php
use App\Http\Resources\ProductResource;

$products = $query->paginate($perPage);

return ProductResource::collection($products);
```

Resources automatically handle pagination meta and preserve query parameters.

## Create a resource collection for custom meta

For custom pagination metadata:

```bash
php artisan make:resource ProductCollection --collection
```

```php
<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\ResourceCollection;

class ProductCollection extends ResourceCollection
{
    public function toArray($request)
    {
        return [
            'data' => $this->collection,
            'meta' => [
                'total' => $this->total(),
                'count' => $this->count(),
                'per_page' => $this->perPage(),
                'current_page' => $this->currentPage(),
                'total_pages' => $this->lastPage(),
            ],
            'links' => [
                'self' => $request->url(),
                'first' => $this->url(1),
                'last' => $this->url($this->lastPage()),
                'prev' => $this->previousPageUrl(),
                'next' => $this->nextPageUrl(),
            ],
        ];
    }
}
```

Use it:

```php
return new ProductCollection($products);
```

## Build a flexible filter class

For complex filtering logic, create a dedicated filter class:

```php
<?php

namespace App\Filters;

use Illuminate\Http\Request;

class ProductFilter
{
    protected $request;
    protected $query;

    protected $filters = ['status', 'category', 'minPrice', 'maxPrice', 'search'];

    public function __construct(Request $request)
    {
        $this->request = $request;
    }

    public function apply($query)
    {
        $this->query = $query;

        foreach ($this->filters as $filter) {
            if ($this->request->has($this->getFilterKey($filter))) {
                $this->$filter($this->request->input($this->getFilterKey($filter)));
            }
        }

        return $this->query;
    }

    protected function status($value)
    {
        $this->query->where('status', $value);
    }

    protected function category($value)
    {
        $this->query->where('category', $value);
    }

    protected function minPrice($value)
    {
        $this->query->where('price', '>=', $value);
    }

    protected function maxPrice($value)
    {
        $this->query->where('price', '<=', $value);
    }

    protected function search($value)
    {
        $this->query->whereAny(['name', 'description', 'sku'], 'LIKE', "%{$value}%");
    }

    protected function getFilterKey($name)
    {
        return strtolower(preg_replace('/(?<!^)[A-Z]/', '_$0', $name));
    }
}
```

Use in controller:

```php
use App\Filters\ProductFilter;

public function index(Request $request, ProductFilter $filter)
{
    $query = Product::query();

    $filter->apply($query);

    $products = $query->paginate($request->input('per_page', 15));

    return ProductResource::collection($products);
}
```

This keeps your controller clean and makes filters reusable.

## Use Spatie Query Builder package

For production APIs, use Spatie's Laravel Query Builder package:

```bash
composer require spatie/laravel-query-builder
```

```php
use Spatie\QueryBuilder\QueryBuilder;

public function index(Request $request)
{
    $products = QueryBuilder::for(Product::class)
        ->allowedFilters(['status', 'category', 'name'])
        ->allowedSorts(['name', 'price', 'created_at'])
        ->defaultSort('-created_at')
        ->paginate($request->input('per_page', 15));

    return ProductResource::collection($products);
}
```

Request: `GET /products?filter[status]=active&filter[name]=phone&sort=-price&page=2`

Spatie Query Builder handles:
- Filtering with `filter[field]=value` syntax
- Sorting with `sort=field` or `sort=-field`
- Including relationships with `include=category,tags`
- Selecting fields with `fields[products]=id,name,price`

It validates allowed filters and sorts automatically, preventing unauthorized queries.

## Add relationship filtering

Filter by related models:

```php
QueryBuilder::for(Product::class)
    ->allowedFilters([
        'status',
        AllowedFilter::exact('category_id'),
        AllowedFilter::scope('has_reviews'),
    ])
    ->allowedIncludes(['category', 'reviews'])
    ->paginate($perPage);
```

Define a scope in your model:

```php
public function scopeHasReviews($query)
{
    return $query->has('reviews');
}
```

Request: `GET /products?filter[has_reviews]=true&include=reviews`

## Implement date range filtering

Filter by date ranges:

```php
use Spatie\QueryBuilder\AllowedFilter;
use Carbon\Carbon;

QueryBuilder::for(Product::class)
    ->allowedFilters([
        AllowedFilter::callback('created_from', function ($query, $value) {
            $query->where('created_at', '>=', Carbon::parse($value));
        }),
        AllowedFilter::callback('created_to', function ($query, $value) {
            $query->where('created_at', '<=', Carbon::parse($value)->endOfDay());
        }),
    ])
    ->paginate($perPage);
```

Request: `GET /products?filter[created_from]=2025-01-01&filter[created_to]=2025-01-31`

## Performance tips

Add indexes on filtered and sorted columns:

```php
Schema::table('products', function (Blueprint $table) {
    $table->index(['status', 'created_at']);
    $table->index('category');
    $table->index('price');
});
```

Composite indexes work best when columns match your WHERE + ORDER BY clauses.

Avoid N+1 queries by eager loading relationships:

```php
$products = QueryBuilder::for(Product::class)
    ->with(['category', 'tags'])
    ->allowedFilters(['status'])
    ->paginate($perPage);
```

Use `select()` to fetch only needed columns:

```php
$products = Product::select(['id', 'name', 'price', 'status'])
    ->where('status', 'active')
    ->paginate($perPage);
```

For very large datasets, consider caching:

```php
$cacheKey = 'products_' . md5(json_encode($request->query()));

$products = Cache::remember($cacheKey, 300, function () use ($query, $perPage) {
    return $query->paginate($perPage);
});
```

Cache for 5 minutes. Invalidate when products change.

## Handle empty results gracefully

Return consistent JSON for empty results:

```php
$products = $query->paginate($perPage);

if ($products->isEmpty()) {
    return response()->json([
        'data' => [],
        'message' => 'No products found matching your criteria',
        'meta' => [
            'total' => 0,
            'current_page' => 1,
        ],
    ]);
}

return ProductResource::collection($products);
```

Or use resources which handle empty collections automatically:

```php
return ProductResource::collection($products);
// Returns {"data": []} if empty
```

## Document your API filters

Document all available filters, sorts, and pagination parameters in your API documentation:

```
GET /api/products

Query Parameters:
- page (integer): Page number (default: 1)
- per_page (integer): Items per page (default: 15, max: 100)
- status (string): Filter by status (active, inactive, draft)
- category (string): Filter by category
- min_price (number): Minimum price
- max_price (number): Maximum price
- search (string): Search in name, description, SKU
- sort (string): Sort field (name, price, created_at). Prefix with - for descending.

Example:
GET /api/products?status=active&sort=-price&per_page=20&page=2
```

Use tools like OpenAPI/Swagger or API Blueprint to generate interactive docs.

## Testing pagination and filters

Write tests to ensure filters work correctly:

```php
public function test_can_filter_products_by_status()
{
    Product::factory()->create(['status' => 'active']);
    Product::factory()->create(['status' => 'inactive']);

    $response = $this->getJson('/api/products?status=active');

    $response->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.status', 'active');
}

public function test_can_sort_products_by_price()
{
    Product::factory()->create(['price' => 100]);
    Product::factory()->create(['price' => 50]);
    Product::factory()->create(['price' => 200]);

    $response = $this->getJson('/api/products?sort=-price');

    $response->assertOk()
        ->assertJsonPath('data.0.price', '200.00')
        ->assertJsonPath('data.2.price', '50.00');
}

public function test_pagination_respects_per_page_limit()
{
    Product::factory()->count(150)->create();

    $response = $this->getJson('/api/products?per_page=20');

    $response->assertOk()
        ->assertJsonCount(20, 'data')
        ->assertJsonPath('meta.per_page', 20);
}
```

Test edge cases like invalid filters, exceeding max per_page, and empty results.

## Security considerations

Always validate and whitelist filter parameters. Don't let users filter by any column:

```php
$allowedFilters = ['status', 'category', 'price'];

if (!in_array($request->filter_field, $allowedFilters)) {
    return response()->json(['error' => 'Invalid filter field'], 422);
}
```

Sanitize search input to prevent SQL injection:

```php
$search = strip_tags($request->search);
$query->where('name', 'LIKE', "%{$search}%");
```

Better yet, use parameter binding which Laravel does automatically:

```php
$query->where('name', 'LIKE', "%{$request->search}%");
// Laravel binds this safely
```

Rate limit API endpoints to prevent abuse:

```php
Route::middleware('throttle:60,1')->group(function () {
    Route::get('/products', [ProductController::class, 'index']);
});
```

See: [Laravel API Authentication with Sanctum]({{< relref "blog/laravel/laravel-api-authentication-sanctum-2025.md" >}}) for securing your API.

## Common mistakes to avoid

Don't filter after fetching all records:

```php
// Bad - loads all products into memory
$products = Product::all();
$filtered = $products->where('status', 'active');
```

Always filter at the database level:

```php
// Good - database does the filtering
$products = Product::where('status', 'active')->paginate($perPage);
```

Don't forget to set max per_page:

```php
// Bad - user can request 1 million items
$products = Product::paginate($request->per_page);

// Good - cap at 100
$perPage = min($request->input('per_page', 15), 100);
```

Don't expose sensitive columns in filters or sorts. Whitelist allowed fields.

Don't run COUNT queries on every request for simple pagination. Use `simplePaginate()` when total count isn't needed.

## Summary

API pagination and filtering let clients control what data they get. Use `paginate()` for standard pagination, `simplePaginate()` for infinite scroll, and `cursorPaginate()` for large datasets.

Add query parameters for filtering, sorting, and searching. Validate all input and whitelist which filters clients can use. Format responses with API resources.

For production, Spatie Query Builder handles complex filtering with clean syntax. Add indexes on columns you filter and sort by. Document all parameters and test edge cases.

These patterns let you build flexible APIs that scale and give clients exactly what they need. For more, check out [Laravel Security Best Practices for Production]({{< relref "blog/laravel/laravel-security-best-practices-production.md" >}}) and [Laravel Performance Optimization]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}}).
