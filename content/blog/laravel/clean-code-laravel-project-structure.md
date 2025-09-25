---
title: 'Project Structure and Design Patterns Guide'
date: 2025-09-08T09:00:00+07:00
draft: false
url: /2025/09/clean-code-laravel-project-structure.html
tags: 
- Laravel
- Clean Code
- Design Pattern
- Best Practices
description: 'Laravel clean code guide with proper project structure and design patterns. How to create maintainable and scalable Laravel code.'
featured: false
---

Writing clean, maintainable code in Laravel applications requires more than just understanding the framework's features. It demands a systematic approach to organizing your project structure, implementing proven design patterns, and following established best practices that make your codebase scalable and readable.

Laravel provides excellent flexibility, but this freedom can sometimes lead to messy codebases if developers don't establish clear conventions early on. This comprehensive guide will walk you through proven strategies for creating professional Laravel applications that are easy to maintain, test, and scale.

## Understanding Clean Code Principles in Laravel

Clean code isn't just about making your code look pretty. It's about creating applications that other developers can easily understand, modify, and extend. In the Laravel ecosystem, this means leveraging the framework's conventions while adding your own organizational patterns.

The foundation of clean Laravel code rests on several key principles: single responsibility, proper naming conventions, consistent file organization, and strategic use of Laravel's built-in features. These principles become especially important as your application grows beyond a simple CRUD interface.

## Essential Laravel Project Structure

A well-organized Laravel project goes beyond the default directory structure. While Laravel's default organization works well for small applications, larger projects benefit from additional layers of organization that separate concerns more clearly.

### Service Layer Architecture

Implementing a service layer helps separate business logic from your controllers, making your code more testable and maintainable. Here's how to structure this approach:

```php
<?php

namespace App\Services;

use App\Models\User;
use App\Models\Order;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class OrderService
{
    public function createOrder(User $user, array $orderData): Order
    {
        return DB::transaction(function () use ($user, $orderData) {
            $order = new Order();
            $order->user_id = $user->id;
            $order->total_amount = $this->calculateTotal($orderData['items']);
            $order->status = 'pending';
            $order->save();
            
            $this->attachOrderItems($order, $orderData['items']);
            $this->sendOrderConfirmation($order);
            
            Log::info('Order created successfully', ['order_id' => $order->id]);
            
            return $order;
        });
    }
    
    private function calculateTotal(array $items): float
    {
        return collect($items)->sum(function ($item) {
            return $item['price'] * $item['quantity'];
        });
    }
    
    private function attachOrderItems(Order $order, array $items): void
    {
        foreach ($items as $item) {
            $order->items()->create([
                'product_id' => $item['product_id'],
                'quantity' => $item['quantity'],
                'price' => $item['price']
            ]);
        }
    }
    
    private function sendOrderConfirmation(Order $order): void
    {
        // Implementation for sending order confirmation
    }
}
```

This service class encapsulates all order-related business logic, making it reusable across different parts of your application. Your controller becomes much simpler:

```php
<?php

namespace App\Http\Controllers;

use App\Services\OrderService;
use App\Http\Requests\CreateOrderRequest;
use Illuminate\Http\JsonResponse;

class OrderController extends Controller
{
    private OrderService $orderService;
    
    public function __construct(OrderService $orderService)
    {
        $this->orderService = $orderService;
    }
    
    public function store(CreateOrderRequest $request): JsonResponse
    {
        $order = $this->orderService->createOrder(
            auth()->user(),
            $request->validated()
        );
        
        return response()->json([
            'message' => 'Order created successfully',
            'order' => $order
        ], 201);
    }
}
```

### Repository Pattern Implementation

The Repository pattern provides an abstraction layer between your business logic and data access logic. This pattern becomes invaluable when you need to switch data sources or implement complex querying logic.

```php
<?php

namespace App\Repositories;

use App\Models\Product;
use Illuminate\Database\Eloquent\Collection;

interface ProductRepositoryInterface
{
    public function findById(int $id): ?Product;
    public function findByCategory(string $category): Collection;
    public function findFeaturedProducts(int $limit = 10): Collection;
    public function searchByName(string $name): Collection;
}

class ProductRepository implements ProductRepositoryInterface
{
    public function findById(int $id): ?Product
    {
        return Product::with(['category', 'images'])->find($id);
    }
    
    public function findByCategory(string $category): Collection
    {
        return Product::whereHas('category', function ($query) use ($category) {
            $query->where('slug', $category);
        })->with(['category', 'images'])->get();
    }
    
    public function findFeaturedProducts(int $limit = 10): Collection
    {
        return Product::where('is_featured', true)
                     ->with(['category', 'images'])
                     ->limit($limit)
                     ->get();
    }
    
    public function searchByName(string $name): Collection
    {
        return Product::where('name', 'LIKE', "%{$name}%")
                     ->with(['category', 'images'])
                     ->get();
    }
}
```

Don't forget to bind your repository in a service provider:

```php
<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use App\Repositories\ProductRepositoryInterface;
use App\Repositories\ProductRepository;

class RepositoryServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(
            ProductRepositoryInterface::class,
            ProductRepository::class
        );
    }
}
```

## Advanced Directory Organization

As your Laravel application grows, the default directory structure might not be sufficient. Consider creating additional directories that reflect your application's domain:

```
app/
├── Actions/
│   ├── Orders/
│   │   ├── CreateOrderAction.php
│   │   └── UpdateOrderStatusAction.php
│   └── Users/
│       ├── RegisterUserAction.php
│       └── UpdateUserProfileAction.php
├── DataTransferObjects/
│   ├── OrderDTO.php
│   └── UserDTO.php
├── Repositories/
│   ├── Contracts/
│   │   ├── OrderRepositoryInterface.php
│   │   └── UserRepositoryInterface.php
│   ├── OrderRepository.php
│   └── UserRepository.php
├── Services/
│   ├── OrderService.php
│   ├── PaymentService.php
│   └── NotificationService.php
└── ValueObjects/
    ├── Money.php
    └── Email.php
```

### Data Transfer Objects (DTOs)

DTOs help you maintain clean interfaces between different layers of your application:

```php
<?php

namespace App\DataTransferObjects;

class OrderDTO
{
    public function __construct(
        public readonly int $userId,
        public readonly array $items,
        public readonly string $shippingAddress,
        public readonly ?string $notes = null
    ) {}
    
    public static function fromRequest(array $data): self
    {
        return new self(
            userId: $data['user_id'],
            items: $data['items'],
            shippingAddress: $data['shipping_address'],
            notes: $data['notes'] ?? null
        );
    }
    
    public function toArray(): array
    {
        return [
            'user_id' => $this->userId,
            'items' => $this->items,
            'shipping_address' => $this->shippingAddress,
            'notes' => $this->notes,
        ];
    }
}
```

### Action Classes for Single Responsibility

Action classes encapsulate single business operations, making your code more focused and testable:

```php
<?php

namespace App\Actions\Orders;

use App\Models\Order;
use App\DataTransferObjects\OrderDTO;
use App\Services\PaymentService;
use App\Services\InventoryService;
use App\Services\NotificationService;

class CreateOrderAction
{
    public function __construct(
        private PaymentService $paymentService,
        private InventoryService $inventoryService,
        private NotificationService $notificationService
    ) {}
    
    public function execute(OrderDTO $orderDTO): Order
    {
        // Check inventory availability
        $this->inventoryService->checkAvailability($orderDTO->items);
        
        // Create the order
        $order = Order::create($orderDTO->toArray());
        
        // Process payment
        $payment = $this->paymentService->processPayment($order);
        
        // Update inventory
        $this->inventoryService->reserveItems($orderDTO->items);
        
        // Send notifications
        $this->notificationService->sendOrderConfirmation($order);
        
        return $order->fresh();
    }
}
```

## Model Organization and Relationships

Proper model organization extends beyond just defining relationships. Consider implementing model concerns, observers, and custom collections to keep your models clean and focused.

### Using Model Concerns

Organize common model behavior into reusable concerns:

```php
<?php

namespace App\Models\Concerns;

use Illuminate\Database\Eloquent\Builder;

trait HasActiveScope
{
    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }
    
    public function scopeInactive(Builder $query): Builder
    {
        return $query->where('is_active', false);
    }
    
    public function activate(): bool
    {
        return $this->update(['is_active' => true]);
    }
    
    public function deactivate(): bool
    {
        return $this->update(['is_active' => false]);
    }
}
```

### Custom Collections for Enhanced Functionality

Create custom collections to add domain-specific methods:

```php
<?php

namespace App\Collections;

use Illuminate\Database\Eloquent\Collection;
use App\Models\Order;

class OrderCollection extends Collection
{
    public function pending(): self
    {
        return $this->filter(fn(Order $order) => $order->status === 'pending');
    }
    
    public function completed(): self
    {
        return $this->filter(fn(Order $order) => $order->status === 'completed');
    }
    
    public function totalRevenue(): float
    {
        return $this->sum('total_amount');
    }
    
    public function averageOrderValue(): float
    {
        return $this->avg('total_amount');
    }
}
```

Then use it in your model:

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Collections\OrderCollection;

class Order extends Model
{
    public function newCollection(array $models = []): OrderCollection
    {
        return new OrderCollection($models);
    }
}
```

## Testing Clean Code Architecture

Clean architecture makes testing easier. Here's how to test your service layer:

```php
<?php

namespace Tests\Unit\Services;

use Tests\TestCase;
use App\Services\OrderService;
use App\Models\User;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;

class OrderServiceTest extends TestCase
{
    use RefreshDatabase;
    
    private OrderService $orderService;
    
    protected function setUp(): void
    {
        parent::setUp();
        $this->orderService = app(OrderService::class);
    }
    
    public function test_creates_order_successfully(): void
    {
        $user = User::factory()->create();
        $product = Product::factory()->create(['price' => 100]);
        
        $orderData = [
            'items' => [
                [
                    'product_id' => $product->id,
                    'quantity' => 2,
                    'price' => $product->price
                ]
            ]
        ];
        
        $order = $this->orderService->createOrder($user, $orderData);
        
        $this->assertEquals($user->id, $order->user_id);
        $this->assertEquals(200, $order->total_amount);
        $this->assertEquals('pending', $order->status);
        $this->assertCount(1, $order->items);
    }
}
```

## Performance Considerations in Clean Architecture

While clean architecture provides many benefits, it's important to consider performance implications. Use Laravel's query optimization features strategically:

```php
<?php

namespace App\Services;

use App\Models\Order;
use Illuminate\Database\Eloquent\Collection;

class OrderReportService
{
    public function getMonthlyReport(int $year, int $month): array
    {
        $orders = Order::with(['items.product', 'user'])
                      ->whereYear('created_at', $year)
                      ->whereMonth('created_at', $month)
                      ->get();
        
        return [
            'total_orders' => $orders->count(),
            'total_revenue' => $orders->sum('total_amount'),
            'average_order_value' => $orders->avg('total_amount'),
            'top_products' => $this->getTopProducts($orders),
        ];
    }
    
    private function getTopProducts(Collection $orders): array
    {
        return $orders->flatMap->items
                     ->groupBy('product_id')
                     ->map(fn($items) => [
                         'product' => $items->first()->product,
                         'quantity_sold' => $items->sum('quantity'),
                         'revenue' => $items->sum(fn($item) => $item->price * $item->quantity)
                     ])
                     ->sortByDesc('quantity_sold')
                     ->take(10)
                     ->values()
                     ->toArray();
    }
}
```

## Configuration and Environment Management

Proper configuration management is crucial for clean code. Create custom configuration files for complex settings:

```php
<?php

// config/business.php
return [
    'order' => [
        'max_items_per_order' => env('MAX_ITEMS_PER_ORDER', 50),
        'auto_cancel_hours' => env('AUTO_CANCEL_HOURS', 24),
        'minimum_order_amount' => env('MINIMUM_ORDER_AMOUNT', 10.00),
    ],
    
    'payment' => [
        'default_gateway' => env('PAYMENT_GATEWAY', 'stripe'),
        'timeout_seconds' => env('PAYMENT_TIMEOUT', 30),
        'retry_attempts' => env('PAYMENT_RETRY_ATTEMPTS', 3),
    ],
];
```

## Conclusion

Implementing clean code practices in Laravel requires discipline and planning, but the benefits are substantial. A well-structured Laravel application with proper separation of concerns, consistent naming conventions, and strategic use of design patterns becomes easier to maintain, test, and scale.

The key to success lies in starting with good practices from the beginning rather than trying to refactor a messy codebase later. Use Laravel's built-in features as your foundation, but don't hesitate to add your own organizational layers when they serve your application's specific needs.

Remember that clean code isn't about following every pattern perfectly, but about creating code that serves your team and your project's long-term goals. Start with the basics covered in this guide, and gradually introduce more advanced patterns as your application grows in complexity.

Looking to optimize your Laravel application further? Learn about [15 Essential Performance Optimization Techniques](/2025/09/laravel-performance-optimization-15-techniques.html) or explore comprehensive [Security Best Practices for Production](/2025/09/laravel-security-best-practices-production.html) environments.