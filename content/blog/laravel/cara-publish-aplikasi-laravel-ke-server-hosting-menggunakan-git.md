---
title: 'Cara publish aplikasi laravel ke server hosting menggunakan git'
date: 2023-04-23T14:19:00.001+07:00
draft: true
url: /2023/04/cara-publish-aplikasi-laravel-ke-server.html
tags:
  - Laravel
description: "Panduan langkah demi langkah mem-publish aplikasi Laravel ke server hosting menggunakan Git: clone, install dependencies, konfigurasi .env, dan deploy."
keywords: ["laravel", "deploy laravel", "publish laravel", "git deploy", "hosting laravel"]
---

Setelah kita membuat sebuah aplikasi tentunya kita ingin aplikasi yang kita buat bisa di lihat oleh orang lain.

Tentunya kita harus memiliki server untuk menyimpan file aplikasi kita supaya bisa di lihat oleh orang lain.

Pada artikel sebelumnya kita telah mengetahui bagaimana cara menjalankan project laravel clone dari git untuk lebih jelas nya bisa di lihat [disini](https://www.buanacoding.com/blog/cara-menjalankan-project-laravel-clone.html).

Sekarang kita akan belajar cara publish aplikasi laravel keserver menggunakan git, sebenernya ada beberapa cara untuk upload aplikasi ke server, tapi kali ini saya akan menggunakan git terlebih dahulu.

1. Siapkan Domain atau subdomain

Siapkan terlebih dahulu domain atau subdomain untuk menyimpan file aplikasi, pada artikel ini saya menggunakan subdomain, namun jangan takut cara dan kegunaannya sama saja.

2. Clone project

Clone project dari git pada direktori domain atau subdomain yang sudah kamu buat sebelumnya, tambah sepasi titik agar file aplikasi diletakan pada folder domain atau subdomain, jika bingung silahkan lihat gambar di bawah ini.

Jika proses cloning sudah selesai, langkah selanjutnya adalah menginstal dependensi yang dibutuhkan menggunakan cara [ini](https://www.buanacoding.com/blog/cara-menjalankan-project-laravel-clone.html), atau bisa menggunakan cara dibawah ini.

```bash
composer install
```

composer install ini digunakan untuk menginstall semua package yang digunakan di dalam aplikasi, biasanya dependesi ini tercatat di file composer.json dan semua dependensi yang ada akan di install menggunakan perintah diatas.  
      
```bash
cp .env.example .env
```

Perintah diatas digunakan untuk copy file .env.axample menjadi file .env dimana file ini nantinya di gunakan untuk setup key, nama database dan konfigurasi lainnya.  

```bash  
php artisan key:generate
```

Perintah diatas digunakan untuk generate app key pada file .env.  
      
```bash
php artisan config:cache
```

Perintah diatas digunakan untuk clear config ata cache yang ada pada aplikasi laravel, perintah ini tambahan dari saya boleh dilakukan dan boleh juga tidak, karena hanya opsional.  
      
Namun biasanya pada saat clone project biasanya ada beberapa fitur yang belum berjalan semua karena masih ada cache dari aplikasi yang ita clone, dan ini pernah saya alami, jadi saya tambahkan perintah di atas.
  

Jika sudah selesai menjalankan dan menginstall semua dependensi yang dibutuhkan sekarang coba akses domain atau subdomain yang kamu buat maka aplikasi sekarang sudah bisa di akses semua orang yeeayyy.

Gimana mudahkan publish aplikasi ke server hosting, oiya kamu juga tinggal git pull dan git push saja kalau ada perubahan di komputer lokal.

Kamu juga bisa langsung sinkronkan tanpa perlu ngoding di dalam hosting dengan cara git pull pada terminal hosting atau bisa menggunakan ssh.

Silahkan share artikel ini keteman kamu yang membutuhkan, semoga bermanfaat...
