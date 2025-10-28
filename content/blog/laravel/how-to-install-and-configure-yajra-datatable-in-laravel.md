---
title: 'how to install and configure yajra datatable in Laravel '
date: 2023-08-06T00:13:00.001+07:00
draft: false
url: /2023/08/how-to-install-and-configure-yajra.html
tags:
- Laravel
description: "Panduan lengkap cara menginstal dan mengonfigurasi Yajra DataTables di Laravel. Cocok untuk pemula yang ingin belajar."
keywords: ["laravel", "yajra datatable", "laravel datatable", "laravel tutorial"]
faq:
  - question: "What's the difference between server-side and client-side DataTables?"
    answer: "Client-side loads ALL data at once, DataTables processes filtering/sorting in browser JavaScript--fast for <10k rows, but slow/crashes for large datasets. Server-side sends only current page data, Laravel processes filtering/sorting via AJAX--handles millions of rows, but adds server load. Yajra DataTables default is server-side: 'serverSide: true' in JS, controller returns datatables()->of($query). When to use: (1) Client-side: <5000 rows, no database queries on sort/filter, faster UX (no loading spinner). (2) Server-side: >5000 rows, complex queries, relationships, authorization. Server-side benefits: (1) Memory efficient--browser only holds 10-50 rows. (2) Scales to millions of rows. (3) Can apply policies per row. (4) Reduces data transfer. Client-side benefits: instant filtering/sorting (no AJAX delay). Trade-off: server-side requires proper indexing on database columns used for sorting/filtering or queries will be slow."
  - question: "Why does Yajra DataTables show 'No data available in table' even though data exists?"
    answer: "Common causes: (1) AJAX URL wrong--check 'url' in ajax config matches controller route. (2) Controller not returning correct format--must return datatables()->make() or make(true), not view or array. (3) Columns mismatch--JS 'columns' array must match controller data keys: JS has 'columns: [{data: 'name'}]' but controller doesn't return 'name' field. (4) CSRF token missing--add {{csrf_token()}} or use Laravel Mix. (5) Request not AJAX--controller checks request()->ajax() but request isn't AJAX (check Network tab in DevTools). (6) Authorization middleware blocks request--check for 401/403 response. (7) Exception in controller--check browser Console and Network tab for 500 errors. Debug: (1) Open DevTools Network tab -> see AJAX request response. (2) Check if response has 'data' array with records. (3) Verify columns match response keys. (4) Add console.log() in JS success callback to see data. Fix: ensure controller returns: datatables()->of($query)->addIndexColumn()->make(true)."
  - question: "How do I add custom buttons (edit, delete) in Yajra DataTables?"
    answer: "Use ->addColumn() or ->editColumn() in controller for action column: datatables()->of($query)->addColumn('action', function($row) { return '<a href=\"'.route('users.edit', $row->id).'\" class=\"btn btn-sm btn-primary\">Edit</a> <form action=\"'.route('users.destroy', $row->id).'\" method=\"POST\" style=\"display:inline\">'.csrf_field().method_field('DELETE').'<button class=\"btn btn-sm btn-danger\" onclick=\"return confirm()\">Delete</button></form>'; })->rawColumns(['action'])->make(); Important: (1) Use rawColumns(['action']) so HTML isn't escaped. (2) Add CSRF token with csrf_field() helper. (3) Add method spoofing for DELETE: method_field('DELETE'). (4) Add confirmation: onclick=\"return confirm('Delete?')\". (5) Define 'action' in JS columns: {data: 'action', orderable: false, searchable: false}. Better approach: use Blade component in controller: ->addColumn('action', fn($row) => view('partials.datatable-actions', compact('row'))->render()). Security: authorize actions before rendering buttons: if(auth()->user()->can('edit', $row)) { /* show edit button */ }."
  - question: "How do I optimize Yajra DataTables performance for large datasets?"
    answer: "Optimization strategies: (1) Database indexes--add indexes on columns used for sorting/filtering: $table->index(['created_at', 'status']). Without indexes, queries on 100k+ rows are slow. (2) Select only needed columns--avoid select(*): $query = User::select('id', 'name', 'email'). (3) Eager load relationships--prevent N+1: User::with('role', 'department'). (4) Use DB::raw for computed columns--avoid model accessors: DB::raw('CONCAT(first_name, \" \", last_name) as full_name'). (5) Disable ordering on action columns--{data: 'action', orderable: false, searchable: false}. (6) Implement smart search--only search when query length > 2: $query->when(request('search.value'), fn($q, $search) => strlen($search) > 2 ? $q->where('name', 'like', \"%$search%\") : $q). (7) Cache query results--use Redis for filters that don't change often. (8) Limit page length options--don't allow 'All': 'lengthMenu': [[10, 25, 50], [10, 25, 50]]. Performance impact: properly indexed table with 1M rows loads in <500ms, unindexed takes 5-10s."
  - question: "Do I need to register DataTablesServiceProvider in Laravel 11+?"
    answer: "No, Laravel 11+ uses auto-discovery--packages register automatically via composer.json 'extra.laravel.providers'. Laravel 10 and below require manual registration in config/app.php 'providers' array. Check if needed: (1) Laravel 11+: skip provider registration, just composer require yajra/laravel-datatables-oracle. (2) Laravel 5.5-10: add Yajra\\DataTables\\DataTablesServiceProvider::class to config/app.php providers. (3) Laravel 5.4 and below: also add facade in 'aliases': 'DataTables' => Yajra\\DataTables\\Facades\\DataTables::class. Verify installation: php artisan vendor:publish --tag=datatables should work without errors. If 'Class not found' error after composer require: (1) Run composer dump-autoload. (2) Clear cache: php artisan config:clear. (3) Check vendor/yajra/laravel-datatables-oracle/composer.json has 'extra.laravel' key. Modern Laravel: auto-discovery handles this automatically."
  - question: "What's the difference between make() and make(true) in Yajra DataTables?"
    answer: "make(true) is shorthand for make(TRUE) which sets 'mDataProp' mode--required for server-side processing with DataTables. make() without argument uses legacy format. Always use make(true) for consistency. Difference: (1) make(true)--returns JSON in format DataTables expects for server-side: {draw: 1, recordsTotal: 100, recordsFiltered: 50, data: [...]}. (2) make()--returns plain JSON array, might not work with serverSide: true. (3) toJson()--returns JSON but not DataTables format (don't use). Best practice: always use return datatables()->of($query)->make(true); in controller. Alternative: use DataTables facade: use DataTables; return DataTables::of($query)->make(true); Both are equivalent. Common mistake: forgetting make(true) causes DataTables to show 'Processing...' indefinitely or 'Invalid JSON response'. If you see 'Cannot read property 'length' of undefined': you forgot make(true) or controller returns wrong format."
---

In the realm of modern web development, providing a seamless user experience and enhancing the overall performance of your web applications is paramount. One essential aspect that plays a pivotal role in achieving these goals is efficient data presentation and manipulation. This is where Yajra DataTables comes into the picture.

  

Yajra DataTables is a powerful and versatile jQuery-based plugin for Laravel, designed to simplify the process of displaying data in tabular form with advanced features such as filtering, sorting, pagination, and more. It empowers developers to create interactive and dynamic data tables effortlessly, significantly improving how data is showcased to end users.

  

This article will delve into the step-by-step process of installing and configuring Yajra DataTables in Laravel. Whether you are a seasoned Laravel developer or just starting with the framework, this guide will walk you through the necessary setup, providing you with the knowledge to harness the full potential of Yajra DataTables in your Laravel projects.

  

So, if you're ready to elevate your data presentation game and unlock a world of possibilities in your Laravel applications, let's dive in and get started with Yajra DataTables!

  

So let's get started on how to install and configure Yajra Datatable in Laravel.

  

The first step you must be to visit the official website of [Yajra Datatable](https://yajrabox.com/docs/laravel-datatables/10.0), if you want to follow my way please follow the guide below.

```bash
`composer require yajra/laravel-datatables-oracle:"^10.3.1"`

```

If you want to change the version of Yajra Datatable you must change the value "^10.3.1" to an old version or if you want to get the new version you can use the script below.

```bash
composer require yajra/laravel-datatables-oracle
```

By default, you will download the latest version from Yajra Datatable.

  

So, in the next step, we will configure the provider in Laravel so that you go to the file in the path folder, Config/app.php, and then add the script below to your code.

  

```php


providers'  \=> \[

  // ...

 Yajra\\DataTables\\DataTablesServiceProvider::class,

\],


```  

If you have put your code into the file app.php, now you can follow this step to publish assets and vendors from Yajra Datatable so that you can use Yajra Datatable on your project.

```bash
php artisan vendor:publish --tag=datatables
```

Now you can use Datatable on your projects yeah, now if you want to call the Datatable in your blade or view you must add style and script from Datatable because Datatable is a package from jquery.

  

```css
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.4/css/dataTables.jqueryui.min.css" />
``````
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.0/jquery.min.js"
    integrity="sha512-3gJwYpMe3QewGELv8k/BX9vcqhryRdzRMxVfq6ngyWXwo03GFEzjsUm8Q7RZcHPHksttq7/GFoxjCVUjkjvPdw=="
    crossorigin="anonymous" referrerpolicy="no-referrer"></script>

<script src="https://cdn.datatables.net/1.13.4/js/jquery.dataTables.min.js"></script>
```

  

If you have been adding the following script on the top now you add the script below to call the data table from javascript below.

  

```js
@push('after-script')
<script>
    $('#tb_user').DataTable({
        processing: true,
        serverSide: true,
        ajax: {
            url: "{!! url()->current() !!}",
        },
        columns: [
            { data: 'DT_RowIndex', name: 'id' },
            { data: 'photo', name: 'photo' },
            { data: 'email', name: 'email' },
            { data: 'username', name: 'username' },
            { data: 'action', name: 'action', orderable: false, searchable: false },
        ],
    });
</script>
@endpush
```

And then, you must be sent data from the controller to view with script below.

  

```php


if (request()->ajax()) {
    $query = Layanan::where('users\_id', Auth::user()->id)->get();

    return datatables()->of($query)
        ->addIndexColumn()
        ->editColumn('photo', function ($item) {
            return $item->photo ? '<img src="' . url('storage/' . $item->photo) . '" style="max-height: 50px;" />' : '-';
        })
        ->editColumn('action', function ($item) {
            return '
                <a href="' . route('user.edit', $item->id) . '" class="btn btn-sm btn-primary">
                    <i class="fa fa-pencil-alt"></i>
                </a>
                <form action="' . route('user.destroy', $item->id) . '" method="POST" style="display: inline-block;">
                    ' . method\_field('delete') . csrf\_field() . '
                    <button type="submit" class="btn btn-sm btn-danger">
                        <i class="fa fa-trash"></i>
                    </button>
                </form>
            ';
        })
        ->rawColumns(\['photo', 'action'\])
        ->make(true);
}
return view('user.index');


```

Okay, the data table installation and configuration are complete, now you can use and display data using the data table on Laravel, if you have any stuck or questions, you can contact me or add your comment below, Thank you.