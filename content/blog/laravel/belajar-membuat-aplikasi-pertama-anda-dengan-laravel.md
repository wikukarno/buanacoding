---
title: 'Belajar Membuat Aplikasi Pertama Anda dengan Laravel'
date: 2024-04-19T15:58:00.001+07:00
draft: false
url: /2024/04/belajar-membuat-aplikasi-pertama-anda-dengan-laravel.html
tags:
    - Laravel
description: "Panduan langkah demi langkah untuk membuat aplikasi web pertama Anda menggunakan aplikasi Laravel. Cocok untuk pemula yang ingin belajar pengembangan web."
keywords: ["laravel", "aplikasi web", "belajar laravel", "pengembangan web", "tutorial laravel"]
faq:
  - question: "Apakah saya perlu belajar PHP dulu sebelum belajar Laravel?"
    answer: "Ya, sangat disarankan memahami dasar PHP terlebih dahulu. Laravel adalah framework PHP, jadi Anda perlu paham konsep PHP dasar: variabel, array, function, OOP (class, object, inheritance), namespace, dan composer. Minimal kuasai: (1) Sintaks PHP dasar—variable, loop, conditional. (2) Function dan array manipulation. (3) OOP basics—class, method, property, constructor. (4) Autoloading dan namespace. Tidak perlu expert PHP, cukup 2-3 minggu belajar PHP dasar sudah bisa mulai Laravel. Laravel justru akan mengajarkan PHP yang lebih baik dengan structure yang jelas. Alternatif: pelajari PHP sambil belajar Laravel—ketika Laravel pakai fitur PHP yang belum paham, pelajari konsep PHP-nya. Banyak pemula mulai Laravel dengan PHP minimal, lalu belajar PHP lebih dalam sambil praktik."
  - question: "Apa perbedaan php artisan serve dengan XAMPP/MAMP?"
    answer: "php artisan serve adalah development server built-in Laravel—cepat, simple, hanya untuk development. Jalankan: php artisan serve, akses di http://localhost:8000. Kelebihan: tidak perlu konfigurasi virtual host, bisa ganti port mudah (--port=8080), otomatis reload saat code berubah. Kekurangan: single-threaded (lambat untuk multiple request), tidak cocok untuk production, tidak support .htaccess. XAMPP/MAMP adalah full web server stack (Apache/Nginx + MySQL + PHP)—lebih mirip production environment. Kelebihan: support multiple projects dengan virtual host, bisa test .htaccess rules, support concurrent requests. Kekurangan: perlu konfigurasi virtual host, lebih berat. Rekomendasi: gunakan php artisan serve untuk development cepat, gunakan XAMPP/Laragon/Valet untuk testing yang lebih mendekati production atau multiple projects."
  - question: "Kenapa setelah composer create-project Laravel, folder vendor sangat besar?"
    answer: "Folder vendor berisi semua library/package dependencies yang Laravel butuhkan—normal ukurannya 50-150MB. Isi vendor: (1) Symfony components (routing, console, http foundation)—Laravel dibangun di atas Symfony. (2) Laravel framework core code. (3) PHPUnit untuk testing. (4) Development dependencies (debug tools). Ukuran besar karena Laravel modern framework dengan banyak fitur built-in. Cara mengecilkan: (1) Production install: composer install --no-dev menghapus dev dependencies, menghemat 20-30MB. (2) Optimize autoload: composer dump-autoload -o. (3) Jangan commit vendor/ ke git—gunakan .gitignore, tim lain jalankan composer install sendiri. (4) Clear cache composer: composer clear-cache. Normal size: development 100-150MB, production 70-100MB. Jangan hapus vendor/ manual—composer butuh untuk autoloading. Ini trade-off framework modern: ukuran besar tapi development jauh lebih cepat."
  - question: "Apa fungsi file .env dan mengapa tidak boleh di-commit ke Git?"
    answer: ".env menyimpan konfigurasi environment-specific: database credentials, API keys, APP_KEY, email settings. Setiap developer/server punya .env berbeda—local pakai MySQL localhost, production pakai RDS. Format: KEY=value, dibaca oleh Laravel via config(). Kenapa tidak boleh di-commit: (1) Security—APP_KEY, DB_PASSWORD, API secret keys tidak boleh di-share public. Jika di-commit, siapa pun bisa lihat kredensial. (2) Environment differences—.env local berbeda dengan production. (3) Git conflict—setiap developer edit .env beda-beda, akan conflict terus. Best practice: (1) Commit .env.example (template tanpa nilai sensitif). (2) Tambahkan .env ke .gitignore. (3) Setiap developer/server copy .env.example jadi .env, isi nilai masing-masing. (4) Production: set environment variable di server (tidak pakai .env file) atau gunakan secrets management. Jika tidak sengaja commit .env: (1) Revoke/ganti semua API keys. (2) Generate APP_KEY baru: php artisan key:generate. (3) Gunakan git filter-branch atau BFG Repo-Cleaner untuk hapus dari history."
  - question: "Berapa lama waktu yang dibutuhkan untuk bisa membuat aplikasi Laravel pertama?"
    answer: "Timeline realistis untuk pemula dengan dasar PHP: (1) Minggu 1-2: Belajar routing, controller, view Blade, passing data—bisa buat halaman static dengan dynamic data. (2) Minggu 3-4: Belajar Eloquent ORM, migration, CRUD operations—bisa buat aplikasi blog/todo list sederhana. (3) Minggu 5-6: Belajar validation, authentication, form requests—bisa buat aplikasi dengan login/register. (4) Minggu 7-8: Belajar relationships, query optimization, file upload—bisa buat aplikasi complete seperti e-commerce sederhana. Total: 2 bulan untuk aplikasi complete. Jika sudah paham PHP OOP: bisa 2-4 minggu. Jika pemula total (belum pernah coding): 3-6 bulan. Kunci sukses: (1) Praktik setiap hari 1-2 jam. (2) Buat project kecil: todo app, blog, contact form. (3) Jangan stuck di tutorial hell—tonton tutorial, langsung praktik. (4) Join komunitas Laravel Indonesia untuk tanya jawab. Jangan buru-buru—fokus pahami konsep, bukan hafal syntax."
  - question: "Apa saja resources terbaik untuk belajar Laravel bagi pemula Indonesia?"
    answer: "Resources berbahasa Indonesia: (1) Dokumentasi Laravel (https://laravel.com/docs)—ada Google Translate atau baca versi Inggris (paling lengkap). (2) Channel YouTube: Web Programming UNPAS (Pak Sandhika Galih), Parsinta, Nusendra, IDStack. (3) Platform belajar: BuildWithAngga, Sekolah Koding, Codepolitan. (4) Komunitas: Facebook Group Laravel Indonesia, Telegram Laravel Indonesia, Discord IDStack. (5) Blog: Medium tag Laravel Indonesia, Dev.to. Resources berbahasa Inggris (recommended): (1) Laracasts (laracasts.com)—best paid course, $15/bulan, ratusan video. (2) Laravel Daily (laraveldaily.com)—tips praktis. (3) Laravel News (laravel-news.com)—update terbaru. (4) GitHub Awesome Laravel—kumpulan resource. Roadmap belajar: (1) Tonton course basic Laravel (20-30 jam). (2) Buat 3-5 project kecil (todo, blog, contact). (3) Baca documentation saat stuck. (4) Join komunitas, tanya jika bingung. (5) Ikuti Laravel update (baca release notes). Jangan loncat-loncat tutorial—selesaikan satu course dulu sebelum mulai yang lain."
---

Ketika kita pertama kali melangkah ke dalam dunia pengembangan web, rasanya seperti memasuki sebuah labirin yang penuh dengan kode dan logika yang rumit. Namun, ada sesuatu yang menarik tentang proses belajar bagaimana segala sesuatu terhubung dan bekerja bersama untuk membentuk sebuah aplikasi web.

Apakah Anda sedang mencari hobi baru atau ingin mengejar karier sebagai pengembang web, membangun aplikasi pertama Anda adalah pengalaman yang sangat berharga. Dengan memahami dasar-dasar pengembangan web, Anda akan memiliki dasar yang kuat untuk mempelajari teknologi-teknologi baru dan membangun aplikasi yang lebih kompleks di masa depan.

Dalam blog kali ini, saya akan membawa Anda melalui proses pembuatan aplikasi web pertama Anda dengan Laravel, sebuah framework PHP yang akan memudahkan kita mengatur dan menulis kode. Dengan Laravel, tugas-tugas yang dulu tampak rumit sekarang bisa kita lakukan dengan lebih terorganisir dan efisien.

Saya akan menunjukkan kepada Anda bahwa siapa pun bisa mulai membuat aplikasi, dan dengan sedikit kesabaran serta ketekunan, Anda akan bisa membuat sesuatu yang bisa Anda banggakan. Jadi, mari kita mulai petualangan ini bersama-sama dan lihat apa yang bisa kita ciptakan!

Langkah 1: Persiapan dan Instalasi
----------------------------------

Sebelum kita mulai, ada beberapa alat yang perlu Anda siapkan dan install di komputer Anda:

1.  PHP: Versi 7.3 atau lebih tinggi diperlukan. Unduh dari [situs resmi PHP](https://www.php.net).
2.  Composer: Manajemen dependensi untuk PHP. Unduh dari [situs resmi Composer](https://getcomposer.org).
3.  Server Web: Gunakan XAMPP atau MAMP untuk pengembangan lokal.
4.  Text Editor: Visual Studio Code atau Sublime Text disarankan.
5.  Terminal atau Command Prompt: Untuk menjalankan perintah Laravel.
6.  Node.js (Opsional): Untuk menjalankan npm atau development mode.

Langkah 2: Instalasi Laravel
----------------------------

Buka terminal atau command prompt dan jalankan perintah berikut:

```bash
composer create-project laravel/laravel example-app **namaAplikasi**
```

Sesuaikan **namaAplikasi** dengan nama yang Anda inginkan. Proses ini akan mengunduh dan menginstal Laravel serta dependensinya.

Langkah 3: Menjelajahi Struktur Laravel
---------------------------------------

Setelah instalasi, Anda akan memiliki struktur folder yang dapat dijelajahi sebagai berikut:

*   app/: Berisi kode inti aplikasi Anda seperti controllers dan models.
*   bootstrap/: Mengandung file app.php yang melakukan bootstrap framework dan konfigurasi autoloading.
*   config/: Berisi semua file konfigurasi aplikasi Anda.
*   database/: Tempat untuk migrasi database, seeders, dan factories.
*   public/: Root publik aplikasi Anda dengan index.php yang mengarahkan semua permintaan.
*   resources/: Berisi file view Blade, file sumber (LESS, SASS, JS), dan file bahasa.
*   routes/: Berisi semua file rute untuk aplikasi Anda termasuk web, api, console, dan channels.
*   storage/: Direktori untuk menyimpan file yang diunggah, cache, view dikompilasi, dan logs.
*   tests/: Berisi tes otomatis Anda termasuk PHPUnit tests.
*   vendor/: Berisi pustaka Composer dependensi aplikasi Anda.
*   .env: File konfigurasi lingkungan untuk aplikasi Anda.
*   .env.example: Template file .env.
*   .gitignore: Menentukan file apa yang tidak akan ditrack oleh Git.
*   artisan: Command-line interface untuk Laravel.
*   composer.json: File konfigurasi untuk Composer.
*   composer.lock: File kunci untuk dependensi yang diinstal oleh Composer.
*   package.json: Menentukan dependensi Node.js.
*   phpunit.xml: File konfigurasi untuk PHPUnit.
*   README.md: File markdown yang berisi informasi tentang aplikasi.
*   vite.config.js: File konfigurasi untuk Vite yang digunakan dalam pengembangan front-end.

Langkah 4: Menjalankan Web Pertama Anda
---------------------------------------

Jalankan perintah berikut di terminal vscode ataupun terminal kesayangan anda:

```bash
php artisan serve
```

Perintah ini akan menjalankan server pengembangan lokal dan memberikan Anda URL untuk mengakses aplikasi web Anda, seperti link dibawah ini.

*   [http://127.0.0.1:8000](http://127.0.0.1:8000)
*   [http://localhost:8000](http://localhost:8000)

Secara default Laravel akan berjalan di port 8000, jika port tersebut sudah digunakan, maka Laravel akan berjalan di port 8001, 8002, dan seterusnya, namun port tersebut bisa diubah sesuai dengan keinginan anda dengan cara seperti di bawah ini:

```bash
php artisan serve --port=8080

```

Buka browser dan kunjungi URL yang diberikan. Anda akan melihat halaman selamat datang Laravel.
