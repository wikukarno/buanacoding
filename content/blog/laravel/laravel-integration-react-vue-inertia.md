---
title: 'Laravel Integration with React/Vue: Complete Inertia.js Guide for Modern SPA'
date: 2025-09-19T07:00:00+07:00
draft: false
url: /2025/09/laravel-integration-react-vue-inertia.html
tags: 
- Laravel
- React
- Vue
- Inertia
- SPA
description: 'Build a modern SPA on Laravel without a separate API using Inertia.js. This guide covers setup with React/Vue, routing, forms and validation, shared props, SSR, auth with Sanctum, asset builds with Vite, deployment, and troubleshooting.'
keywords: ['laravel inertia','inertia react laravel','inertia vue laravel','laravel spa without api','inertia forms validation','inertia shared props','inertia ssr laravel','laravel vite inertia','sanctum inertia']
featured: false
---

Inertia.js lets you build a single‑page app on top of Laravel without maintaining a separate API. You keep server‑side routing, controllers, middleware, and validation, while rendering pages with React or Vue. The result feels like an SPA—fast navigation, preserved state, and partial reloads—without the overhead of duplicating server logic.

This guide walks through installation, page structure, forms, validation, shared data, server‑side rendering (optional), authentication with Sanctum, building assets with Vite, deployment, and fixes for the most common issues.

<!--readmore-->

Why Inertia.js
--------------
- No separate API layer: controllers return Inertia responses instead of JSON.
- Keep Laravel features: policies, validation, flash messages, session auth.
- Modern client: React/Vue components for pages and layouts, fast navigation.

Install and scaffold
--------------------
The fastest path is Laravel Breeze with the Inertia stack. Choose React or Vue.

```bash
composer require laravel/breeze --dev
php artisan breeze:install react   # or: php artisan breeze:install vue
npm install
npm run dev
php artisan migrate
```

If you prefer a manual setup, install the server and client packages:

```bash
composer require inertiajs/inertia-laravel
npm install @inertiajs/core @inertiajs/react   # or @inertiajs/vue3
```

Basic page flow
---------------
Routes hit controllers. Controllers return `Inertia::render()` with a component name and props. The client bootstraps and renders the matching React/Vue component.

```php
// routes/web.php
use Inertia\Inertia;
use App\Models\Post;

Route::get('/posts', function () {
    return Inertia::render('Posts/Index', [
        'filters' => request()->only('search'),
        'posts'   => Post::query()
                        ->when(request('search'), fn($q,$s)=>$q->where('title','like',"%$s%"))
                        ->latest()->paginate(10)
                        ->withQueryString(),
    ]);
});
```

Example React component:
```jsx
// resources/js/Pages/Posts/Index.jsx
import { Link, useForm } from '@inertiajs/react'

export default function Index({ filters, posts }) {
  const { data, setData, get } = useForm({ search: filters?.search || '' })
  return (
    <div>
      <form onSubmit={e=>{e.preventDefault(); get('/posts')}}>
        <input value={data.search} onChange={e=>setData('search', e.target.value)} />
        <button type="submit">Search</button>
      </form>
      <ul>
        {posts.data.map(p => (
          <li key={p.id}><Link href={`/posts/${p.id}`}>{p.title}</Link></li>
        ))}
      </ul>
      <div>
        {posts.links.map(l => (
          <Link key={l.label} href={l.url || '#'} dangerouslySetInnerHTML={{__html: l.label}} preserveScroll/>
        ))}
      </div>
    </div>
  )
}
```

Layouts, shared props, and meta
-------------------------------
Define a main layout once and reuse it. Pass global data (auth user, flash) via middleware.

```php
// app/Http/Middleware/HandleInertiaRequests.php
use Inertia\Middleware;

class HandleInertiaRequests extends Middleware
{
    protected $rootView = 'app';

    public function share($request)
    {
        return array_merge(parent::share($request), [
            'auth' => [
                'user' => fn() => optional($request->user())->only('id','name','email'),
            ],
            'flash' => [
                'success' => fn() => $request->session()->get('success'),
            ],
        ]);
    }
}
```

On the client, use a top‑level layout and `@inertiajs/react` or `@inertiajs/vue3` `Head` component to manage titles and meta tags.

Forms and validation
--------------------
Leverage Laravel validation in controllers and show errors in the page component.

```php
// app/Http/Controllers/PostController.php
public function store(Request $r)
{
    $validated = $r->validate([
        'title' => ['required','max:120'],
        'body'  => ['required'],
    ]);
    Post::create($validated);
    return back()->with('success', 'Post created');
}
```

React page snippet with `useForm`:
```jsx
const { data, setData, post, processing, errors } = useForm({ title:'', body:'' })
<form onSubmit={e=>{e.preventDefault(); post('/posts')}}>
  <input value={data.title} onChange={e=>setData('title', e.target.value)} />
  {errors.title && <div className="error">{errors.title}</div>}
  <textarea value={data.body} onChange={e=>setData('body', e.target.value)} />
  {errors.body && <div className="error">{errors.body}</div>}
  <button disabled={processing}>Save</button>
</form>
```

Partial reloads and performance
-------------------------------
Inertia only refreshes data you ask for. Use `only` to fetch specific props on visits and `preserveState`/`preserveScroll` for smooth UX. Split large components and lazy‑load where sensible. For broader tips, see: [Laravel Performance Optimization]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}}).

Authentication with Sanctum
---------------------------
Most Inertia apps use session‑based auth. Pair with [Laravel Sanctum]({{< relref "blog/laravel/laravel-api-authentication-sanctum-2025.md" >}}) for cookie authentication. Ensure:

- Correct cookie flags in `config/session.php` (domain, secure, same_site).
- CSRF cookie route `/sanctum/csrf-cookie` is accessible (for traditional form posts).
- Login/logout route handlers regenerate/invalidate sessions.

If you encounter CSRF or cookie issues behind a proxy or different subdomains, refer to: [Fixing Laravel Session and Cache Issues]({{< relref "blog/laravel/fixing-laravel-session-cache-issues.md" >}}) and [Laravel Environment Configuration]({{< relref "blog/laravel/laravel-environment-configuration-env-issues.md" >}}).

SSR (optional)
---------------
Server‑side rendering improves first paint and SEO for public pages. Breeze provides an SSR preset. Enable SSR in your Vite setup and run the SSR server process in production. Only render publicly visible routes; most dashboards are fine without SSR.

Assets with Vite
----------------
Vite handles builds. Typical commands:

```bash
npm run dev   # HMR during development
npm run build # production assets
```

Keep the Vite manifest in sync and ensure your deployment copies built assets.

File uploads in Inertia pages
-----------------------------
Use regular multipart forms or `FormData` and apply the same validation and storage patterns described in: [File Upload Best Practices]({{< relref "laravel-file-upload-validation-security.md" >}}).

Deployment and caching
----------------------
Production checklist:
- Serve from `public/` and verify Nginx `try_files` points to `index.php`. See: [Deploy Laravel to VPS with Nginx — Complete Guide]({{< relref "blog/laravel/deploy-laravel-to-vps-with-nginx-complete-guide.md" >}}).
- Clear and rebuild caches after deploy; reload PHP‑FPM; restart workers if you use queues. See: [Laravel Environment Configuration]({{< relref "blog/laravel/laravel-environment-configuration-env-issues.md" >}}).
- Ensure ownership and permissions on `storage/` and `bootstrap/cache/` are correct: [Fix Laravel Permission Issues]({{< relref "blog/laravel/fix-laravel-permission-issues-production.md" >}}).

Troubleshooting
---------------
- “Back/forward shows stale data”: use `only` on visits and provide keys for lists to avoid stale renders.
- “Flash not showing”: share flash data in `HandleInertiaRequests` middleware.
- “Validation not appearing”: ensure controller returns back with errors (default behavior on `validate` failure) and page renders `errors` from Inertia props.
- "Build works locally, fails on server": confirm Node/Vite run in CI and assets are deployed; avoid mixing old manifest files.
- “Slow initial load”: consider SSR for public pages, enable HTTP caching for static assets, and keep bundle sizes in check.
- For production diagnostics and clearer logs, see: [Advanced Laravel Debugging with Logs]({{< relref "advanced-laravel-debugging-with-logs.md" >}}).

Summary
-------
Inertia lets Laravel own routing, validation, and policies while React/Vue own the view layer. Return `Inertia::render()` from controllers, use layouts and shared props for global state, handle forms with `useForm`, and improve UX with partial reloads and preserved state. Tie in Sanctum for auth, Vite for builds, and add SSR where it helps. With the deployment and troubleshooting patterns above, you get an SPA experience without running a separate API.
