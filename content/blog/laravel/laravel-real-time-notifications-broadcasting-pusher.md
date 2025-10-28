---
title: 'How to Build Real-Time Notifications with Laravel Broadcasting and Pusher'
date: 2025-10-22T11:00:00+07:00
draft: false
url: /2025/10/how-to-build-real-time-notifications-laravel-broadcasting-pusher.html
tags:
- Laravel
- Real-time
- Broadcasting
- Pusher
- WebSocket
- Notifications
description: 'Learn how to build real-time notifications in Laravel using Broadcasting and Pusher. Step-by-step guide covering events, channels, Laravel Echo, private channels, presence channels, and production deployment.'
keywords: ['laravel broadcasting','laravel pusher','laravel websocket','real-time notifications laravel','laravel echo','pusher channels','laravel events','private channels laravel','presence channels','laravel real-time']
featured: false
faq:
  - question: "What is the difference between Laravel Broadcasting with Pusher and polling?"
    answer: "Polling requires your frontend to repeatedly request the server for updates (e.g., every 5 seconds), which creates unnecessary load and delays. Broadcasting with Pusher uses WebSockets to push updates instantly from server to client when events occur. WebSockets maintain a persistent connection, so updates arrive in milliseconds instead of seconds. Polling wastes bandwidth and server resources checking for updates that might not exist. Use broadcasting for real-time features like notifications, chat, live dashboards, or collaborative editing. Use polling only when WebSockets aren't available or for non-critical updates."
  - question: "Do I need Pusher or can I use free alternatives for Laravel Broadcasting?"
    answer: "Pusher has a free tier (100 connections, 200k messages/day) suitable for small apps. Free alternatives include Laravel Reverb (official WebSocket server in Laravel 11+, self-hosted), Soketi (open-source Pusher replacement, self-hosted), Ably (similar pricing to Pusher), and Laravel WebSockets package (deprecated but still works). For production with many users, Reverb is the best free option if you can self-host. Pusher is easiest for beginners because it's fully managed. For learning and small projects, Pusher's free tier is fine. For scaling, evaluate cost vs infrastructure complexity."
  - question: "How do private channels work and when should I use them?"
    answer: "Private channels require authentication before users can listen. When a client tries to subscribe to a private channel, Laravel Echo makes a POST request to /broadcasting/auth. Your routes/channels.php defines authorization logic that returns true/false. Use private channels for user-specific data like personal notifications, private messages, or account updates. Public channels are for data everyone can see like public announcements or live scores. Presence channels are private channels that also track who's currently subscribed, useful for online user lists or collaborative features. Always use private/presence channels for sensitive data."
  - question: "Can I send real-time notifications to specific users or groups?"
    answer: "Yes. Use private channels with dynamic names like private-user.{userId} to target specific users. In your event, implement broadcastOn() to return new PrivateChannel('user.'.$this->userId). In channels.php, authorize based on the user ID. For groups, use private-team.{teamId} and authorize if the user belongs to that team. You can also broadcast to multiple channels by returning an array from broadcastOn(). For presence channels, use presence-chat.{roomId} to show who's online in specific rooms. Laravel handles the channel subscription and authorization automatically."
  - question: "How do I handle connection failures and reconnection in Laravel Echo?"
    answer: "Laravel Echo with Pusher automatically reconnects when connections drop. To handle reconnection events, listen to pusher:subscription_succeeded after reconnects. Implement a connection state indicator in your UI using Echo.connector.pusher.connection.bind() to listen for states: connected, connecting, disconnected, unavailable. Store notification IDs in localStorage to avoid duplicates after reconnection. Implement exponential backoff if custom reconnection logic is needed. For critical updates, combine broadcasting with database polling as a fallback. Always test reconnection behavior by toggling network connectivity during development."
  - question: "What are the performance implications of using Broadcasting in production?"
    answer: "Broadcasting itself is lightweight because Laravel queues events by default. The queue worker handles the actual Pusher API call asynchronously, so your application response time isn't affected. Monitor Pusher message limits (free tier: 200k/day, grows with paid plans). Avoid broadcasting on every database update--batch notifications or use throttling. Presence channels increase Pusher usage because they track joins/leaves. For thousands of concurrent users, consider Laravel Reverb (self-hosted, no message limits) or optimize by broadcasting only critical events. Always queue broadcasts: implement ShouldBroadcast, not ShouldBroadcastNow."
---

Real-time notifications let you push updates to users instantly without page refreshes. Laravel Broadcasting with Pusher makes this easy using WebSockets. When something happens on your server like a new message, order update, or system alert, your frontend gets notified immediately.

This guide shows you how to set up Laravel Broadcasting from scratch. We'll install Pusher, create events, configure channels for public and private notifications, set up Laravel Echo on the frontend, and test everything. You'll also learn about presence channels for tracking online users and production deployment tips.

<!--readmore-->

## When to use real-time notifications

You need real-time notifications when users should see updates immediately without refreshing the page.

Common use cases:
- Chat applications and messaging systems
- Notification bells showing new alerts, mentions, or messages
- Live dashboards with updating metrics or analytics
- Collaborative tools where multiple users edit the same data
- Order status updates in e-commerce
- Social media feeds with new posts or likes
- Admin panels monitoring system events

If updates can wait 30 seconds or a minute, polling might be simpler. If updates must arrive instantly (chat, live auctions, stock tickers), use broadcasting.

## Broadcasting architecture overview

Laravel Broadcasting works like this:

1. Something happens in your app (new order, message sent, user registered)
2. You fire an event that implements `ShouldBroadcast`
3. Laravel queues a job to send the event to Pusher via HTTP API
4. Pusher pushes the event through WebSocket to all connected clients
5. Laravel Echo (JavaScript) receives the event and triggers your callback
6. Your frontend updates the UI

The key parts: Events (server-side), Channels (authorization), Pusher (WebSocket infrastructure), and Echo (client library).

## Install and configure Pusher

Sign up for a free account at pusher.com. Create a new app and choose your cluster (closest to your users).

Copy your credentials from the app dashboard. You'll need:
- App ID
- Key
- Secret
- Cluster

Install the Pusher PHP SDK:

```bash
composer require pusher/pusher-php-server
```

Add your Pusher credentials to `.env`:

```env
BROADCAST_CONNECTION=pusher

PUSHER_APP_ID=your-app-id
PUSHER_APP_KEY=your-key
PUSHER_APP_SECRET=your-secret
PUSHER_APP_CLUSTER=mt1
PUSHER_SCHEME=https
```

Open `config/broadcasting.php` and verify the Pusher config uses your env variables:

```php
'pusher' => [
    'driver' => 'pusher',
    'key' => env('PUSHER_APP_KEY'),
    'secret' => env('PUSHER_APP_SECRET'),
    'app_id' => env('PUSHER_APP_ID'),
    'options' => [
        'cluster' => env('PUSHER_APP_CLUSTER'),
        'host' => env('PUSHER_HOST') ?: 'api-'.env('PUSHER_APP_CLUSTER', 'mt1').'.pusher.com',
        'port' => env('PUSHER_PORT', 443),
        'scheme' => env('PUSHER_SCHEME', 'https'),
        'encrypted' => true,
        'useTLS' => env('PUSHER_SCHEME', 'https') === 'https',
    ],
],
```

Uncomment `App\Providers\BroadcastServiceProvider::class` in `config/app.php` (Laravel 10 and below) or it auto-registers in Laravel 11+.

## Create a broadcastable event

Generate an event:

```bash
php artisan make:event OrderShipped
```

Edit `app/Events/OrderShipped.php` to implement `ShouldBroadcast`:

```php
<?php

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class OrderShipped implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public Order $order)
    {
    }

    public function broadcastOn()
    {
        return new Channel('orders');
    }

    public function broadcastWith()
    {
        return [
            'id' => $this->order->id,
            'status' => $this->order->status,
            'user_id' => $this->order->user_id,
        ];
    }
}
```

`broadcastOn()` returns the channel(s) to broadcast on. `broadcastWith()` defines the data sent to clients. Only include data the frontend needs.

Trigger the event anywhere in your app:

```php
use App\Events\OrderShipped;

$order = Order::find(1);
event(new OrderShipped($order));
```

Laravel queues this event automatically if you have `ShouldBroadcast`. Make sure your queue worker is running:

```bash
php artisan queue:work
```

## Set up Laravel Echo on the frontend

Install Laravel Echo and Pusher JavaScript SDK:

```bash
npm install --save-dev laravel-echo pusher-js
```

Configure Echo in `resources/js/bootstrap.js` or `app.js`:

```javascript
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

window.Pusher = Pusher;

window.Echo = new Echo({
    broadcaster: 'pusher',
    key: import.meta.env.VITE_PUSHER_APP_KEY,
    cluster: import.meta.env.VITE_PUSHER_APP_CLUSTER,
    forceTLS: true
});
```

Add Pusher credentials to `.env` for Vite:

```env
VITE_PUSHER_APP_KEY="${PUSHER_APP_KEY}"
VITE_PUSHER_APP_CLUSTER="${PUSHER_APP_CLUSTER}"
```

Restart Vite:

```bash
npm run dev
```

## Listen for events on the frontend

In your JavaScript (Vue, React, or vanilla JS):

```javascript
Echo.channel('orders')
    .listen('OrderShipped', (e) => {
        console.log('Order shipped:', e);
        // Update UI: show notification, update order status, etc.
        showNotification(`Order #${e.id} shipped!`);
    });
```

The first parameter to `.listen()` is the event class name without the namespace. Laravel uses the class name by default. To customize, add `broadcastAs()` to your event:

```php
public function broadcastAs()
{
    return 'order.shipped';
}
```

Then listen for it:

```javascript
Echo.channel('orders').listen('.order.shipped', (e) => {
    // Note the dot prefix for custom event names
});
```

## Private channels for user-specific notifications

Public channels let anyone subscribe. Private channels require authentication.

Create a notification event for a specific user:

```bash
php artisan make:event NewMessage
```

```php
<?php

namespace App\Events;

use App\Models\Message;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class NewMessage implements ShouldBroadcast
{
    use Dispatchable, SerializesModels;

    public function __construct(public Message $message)
    {
    }

    public function broadcastOn()
    {
        return new PrivateChannel('user.' . $this->message->recipient_id);
    }

    public function broadcastWith()
    {
        return [
            'id' => $this->message->id,
            'from' => $this->message->sender->name,
            'text' => $this->message->text,
        ];
    }
}
```

Define authorization in `routes/channels.php`:

```php
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('user.{userId}', function ($user, $userId) {
    return (int) $user->id === (int) $userId;
});
```

This ensures users can only listen to their own private channel.

Make sure authentication routes are enabled in `routes/web.php`:

```php
Broadcast::routes(['middleware' => ['web', 'auth']]);
```

On the frontend, listen to the private channel:

```javascript
Echo.private(`user.${userId}`)
    .listen('NewMessage', (e) => {
        console.log('New message:', e);
        displayMessage(e.from, e.text);
    });
```

Laravel Echo automatically calls `/broadcasting/auth` to authorize the subscription. If the user isn't authenticated or authorized, the subscription fails.

## Presence channels for online users

Presence channels are private channels that track who's subscribed. Use them for online user lists, typing indicators, or collaborative features.

Create a chat room event:

```php
<?php

namespace App\Events;

use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;

class MessageSent implements ShouldBroadcast
{
    public function __construct(public string $roomId, public string $message)
    {
    }

    public function broadcastOn()
    {
        return new PresenceChannel('chat.' . $this->roomId);
    }

    public function broadcastWith()
    {
        return ['message' => $this->message];
    }
}
```

Authorize in `routes/channels.php`:

```php
Broadcast::channel('chat.{roomId}', function ($user, $roomId) {
    // Check if user can access this room
    if ($user->canAccessRoom($roomId)) {
        return ['id' => $user->id, 'name' => $user->name];
    }
});
```

The returned array is user info shared with all subscribers.

On the frontend:

```javascript
Echo.join(`chat.${roomId}`)
    .here((users) => {
        // users is an array of everyone currently in the channel
        console.log('Currently online:', users);
        updateOnlineList(users);
    })
    .joining((user) => {
        // Someone new joined
        console.log(user.name + ' joined');
        addUserToList(user);
    })
    .leaving((user) => {
        // Someone left
        console.log(user.name + ' left');
        removeUserFromList(user);
    })
    .listen('MessageSent', (e) => {
        console.log('New message:', e.message);
    });
```

`.here()` fires when you first join and shows who's already there. `.joining()` fires when someone new joins. `.leaving()` fires when someone disconnects.

## Customize event data with broadcastWith

By default, Laravel broadcasts all public properties of your event. To control exactly what gets sent:

```php
public function broadcastWith()
{
    return [
        'order_id' => $this->order->id,
        'total' => $this->order->total,
        'items_count' => $this->order->items->count(),
        'customer_name' => $this->order->user->name,
    ];
}
```

Only send data the frontend needs. Don't expose sensitive fields like internal IDs, API keys, or raw model data.

## Queue broadcasts for performance

Always use `ShouldBroadcast`, not `ShouldBroadcastNow`. Broadcasting synchronously adds 100-300ms to your response time because it waits for the Pusher HTTP API call.

With `ShouldBroadcast`, Laravel queues the broadcast job. Make sure you have a queue worker running:

```bash
php artisan queue:work --tries=3
```

In production, use Supervisor to keep the queue worker running. See: [Laravel Queue Jobs and Background Processing]({{< relref "blog/laravel/laravel-queue-jobs-background-processing-tutorial.md" >}}).

## Test broadcasts with Pusher Debug Console

Open your Pusher dashboard and go to the Debug Console tab. Fire an event in your Laravel app:

```php
event(new OrderShipped($order));
```

You should see the event appear in the Debug Console in real-time. If not:
- Check your queue worker is running
- Verify `.env` credentials match your Pusher app
- Check `BROADCAST_CONNECTION=pusher` in `.env`
- Look for errors in `storage/logs/laravel.log`

You can also trigger test events from the Pusher console to verify your frontend is listening correctly.

## Handle authentication for Echo

Laravel Echo needs to authenticate before subscribing to private or presence channels.

Echo sends a POST request to `/broadcasting/auth` with the channel name. Laravel checks your `channels.php` authorization logic and returns the auth signature if authorized.

Make sure your frontend has a valid session cookie. For SPAs on different domains, configure CORS and credentials:

In `config/cors.php`:

```php
'paths' => ['api/*', 'broadcasting/auth'],
'supports_credentials' => true,
```

In your Echo config:

```javascript
window.Echo = new Echo({
    broadcaster: 'pusher',
    key: import.meta.env.VITE_PUSHER_APP_KEY,
    cluster: import.meta.env.VITE_PUSHER_APP_CLUSTER,
    forceTLS: true,
    authEndpoint: 'https://your-api.com/broadcasting/auth',
    auth: {
        headers: {
            Authorization: 'Bearer ' + token, // if using Sanctum tokens
        }
    }
});
```

For Sanctum token auth in SPAs, see: [Laravel API Authentication with Sanctum]({{< relref "blog/laravel/laravel-api-authentication-sanctum-2025.md" >}}).

## Broadcast to multiple channels

Return an array of channels from `broadcastOn()`:

```php
public function broadcastOn()
{
    return [
        new Channel('orders'),
        new PrivateChannel('user.' . $this->order->user_id),
        new PrivateChannel('admin-dashboard'),
    ];
}
```

This event goes to all three channels. Useful when the same event affects multiple audiences (public feed, private user notification, admin log).

## Conditionally broadcast events

Only broadcast when certain conditions are met:

```php
public function broadcastWhen()
{
    return $this->order->status === 'shipped';
}
```

If `broadcastWhen()` returns false, Laravel skips broadcasting. Use this to avoid sending unnecessary events.

## Client-side event broadcasting

Pusher lets clients trigger events directly without hitting your server. This is useful for typing indicators or cursor positions.

Enable client events in your Pusher app settings (under App Settings > Enable client events).

Authorize the channel in `channels.php`:

```php
Broadcast::channel('chat.{roomId}', function ($user, $roomId) {
    return ['id' => $user->id, 'name' => $user->name];
});
```

On the frontend, trigger client events with a `client-` prefix:

```javascript
Echo.private(`chat.${roomId}`)
    .listenForWhisper('typing', (e) => {
        console.log(e.name + ' is typing...');
    });

// Trigger a whisper event
Echo.private(`chat.${roomId}`)
    .whisper('typing', {
        name: userName
    });
```

Whispers (client events) only work on private and presence channels for security. They bypass your server entirely, so they're very fast but you can't validate or log them server-side.

## Production deployment checklist

Use HTTPS in production. Pusher requires `forceTLS: true` for security.

Set up a queue worker with Supervisor to process broadcast jobs reliably:

```ini
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /path/to/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
numprocs=2
```

Monitor your Pusher usage in the dashboard. The free tier allows 100 concurrent connections and 200k messages per day. If you exceed this, either upgrade or switch to Laravel Reverb (self-hosted, no limits).

Cache your config in production to avoid reading `.env` on every request:

```bash
php artisan config:cache
```

Test reconnection behavior. Disable network for 10 seconds then re-enable. Echo should reconnect automatically. If not, check your connection state handling.

Rate limit broadcasting in your controllers to prevent abuse. If a user can trigger events (like sending messages), throttle the endpoint:

```php
Route::post('/messages', [MessageController::class, 'store'])
    ->middleware('throttle:20,1'); // 20 messages per minute
```

Log broadcast errors. If Pusher is down or credentials are wrong, your queue jobs will fail. Monitor `storage/logs/laravel.log` or use error tracking: [Laravel Production Monitoring and Error Tracking]({{< relref "blog/laravel/laravel-production-monitoring-error-tracking.md" >}}).

## Alternative: Laravel Reverb (self-hosted)

Laravel 11 introduced Reverb, a first-party WebSocket server you can self-host. It's free, fast, and eliminates per-message costs.

Install Reverb:

```bash
composer require laravel/reverb
php artisan reverb:install
```

Start the Reverb server:

```bash
php artisan reverb:start
```

Change `.env`:

```env
BROADCAST_CONNECTION=reverb
REVERB_HOST=0.0.0.0
REVERB_PORT=8080
```

Update Echo config:

```javascript
window.Echo = new Echo({
    broadcaster: 'reverb',
    key: import.meta.env.VITE_REVERB_APP_KEY,
    wsHost: import.meta.env.VITE_REVERB_HOST,
    wsPort: import.meta.env.VITE_REVERB_PORT,
    forceTLS: false,
    enabledTransports: ['ws', 'wss'],
});
```

Reverb works identically to Pusher from your application code. Only the infrastructure changes. Use Reverb if you want full control and no usage limits. Use Pusher if you prefer managed infrastructure.

For production Reverb, run it behind a reverse proxy (Nginx) with SSL. See the official docs for deployment details.

## Troubleshooting common issues

Events not appearing in Pusher Debug Console:
- Check queue worker is running: `php artisan queue:work`
- Verify `.env` credentials match Pusher dashboard
- Check `BROADCAST_CONNECTION=pusher` in `.env`
- Look for failed jobs in `failed_jobs` table: `php artisan queue:failed`
- Clear config cache: `php artisan config:clear`

Frontend not receiving events:
- Check browser console for Echo connection errors
- Verify Echo is connecting to the right cluster (check Pusher dashboard Connection tab for active connections)
- Make sure channel name matches exactly (case-sensitive)
- For private channels, ensure `/broadcasting/auth` returns 200 (check Network tab)
- Check if the event class name matches what you're listening for

Private channel authorization fails:
- User must be authenticated before subscribing
- Check `Broadcast::routes()` is called with `auth` middleware
- For SPAs, verify CORS is configured and `supports_credentials` is true
- Check the channel authorization callback in `channels.php` returns truthy value
- Look at `/broadcasting/auth` response in Network tab for error messages

Connection drops frequently:
- Pusher free tier has connection time limits (1 day)
- Check if network conditions are unstable
- Implement reconnection handling and state management
- Consider using Laravel Reverb for self-hosted stability

High Pusher message count:
- You're broadcasting too often. Throttle events or batch updates.
- Avoid broadcasting on every model update. Use observers carefully.
- Check if you're broadcasting to too many channels in `broadcastOn()`
- Switch to Reverb or upgrade Pusher plan

## Security considerations

Never broadcast sensitive data like passwords, API keys, or personal information. Use `broadcastWith()` to whitelist exposed fields.

Always use private channels for user-specific data. Public channels are visible to anyone who knows the channel name.

Validate all data before broadcasting. If users trigger events (chat messages), sanitize input to prevent XSS.

Rate limit endpoints that trigger broadcasts. A malicious user could spam events to exhaust your Pusher quota.

Use HTTPS and `forceTLS: true` in production. Pusher doesn't allow insecure connections on production clusters anyway.

Don't trust client events (whispers) for critical actions. They bypass server validation. Only use them for non-critical UI updates like typing indicators.

Rotate your Pusher secret if it's exposed. Generate a new app key in Pusher dashboard and update `.env`.

## Summary

Laravel Broadcasting with Pusher gives you real-time notifications with minimal code. Install Pusher, create events that implement `ShouldBroadcast`, define channels and authorization, and set up Laravel Echo on the frontend.

Use public channels for general updates, private channels for user-specific data, and presence channels to track who's online. Queue all broadcasts for performance and test with Pusher's Debug Console.

For production, monitor usage, set up queue workers with Supervisor, use HTTPS, and consider Laravel Reverb for self-hosted infrastructure. Always validate authorization for private channels and never broadcast sensitive data.

With these practices, you can build real-time features like notifications, chat, live dashboards, or collaborative tools that update instantly without polling. For more on securing Laravel applications, see [Laravel Security Best Practices for Production]({{< relref "blog/laravel/laravel-security-best-practices-production.md" >}}).
