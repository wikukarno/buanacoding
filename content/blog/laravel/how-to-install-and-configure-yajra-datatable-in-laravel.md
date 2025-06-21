---
title: 'how to install and configure yajra datatable in Laravel '
date: 2023-08-06T00:13:00.001+07:00
draft: false
url: /2023/08/how-to-install-and-configure-yajra.html
tags: 
- Laravel
description: "Panduan lengkap cara menginstal dan mengonfigurasi Yajra DataTables di Laravel. Cocok untuk pemula yang ingin belajar."
keywords: ["laravel", "yajra datatable", "laravel datatable", "laravel tutorial"]
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