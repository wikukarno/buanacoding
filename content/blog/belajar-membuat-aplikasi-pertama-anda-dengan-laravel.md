---
title: 'Belajar Membuat Aplikasi Pertama Anda dengan Laravel'
date: 2024-04-19T15:58:00.001+07:00
draft: false
url: /2024/04/belajar-membuat-aplikasi-pertama-anda-dengan-laravel.html
tags: 
- Laravel
---

[![Cara Membuat Aplikasi Pertama dengan Laravel](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgm_XQhYi11VC5_tCFj3Tu-d7EOcvuAEif0GtrvDggiW1751GBunrrRhiPEiJb0FwjsnazkPA3wqNpHukCDu0XRGvh-bIZx03FfRuBV4MuReZOMz3T3875g87t_SPlyGLMBjYbFWUR0GKgU4f-HAtEeiEd0stb_DwUMfve4yk9iHhdkgMlzWvJHZy5hrCqY/w640-h366/DALL%C2%B7E%202024-04-15%2017.44.33%20-%20A%20photograph%20of%20a%20laptop%20on%20a%20wooden%20desk%20with%20code%20on%20the%20screen,%20and%20next%20to%20it%20sits%20a%20plush%20toy%20elephant%20that%20typically%20represents%20PHP.%20However,%20th.webp "Cara Membuat Aplikasi Pertama dengan Laravel")](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgm_XQhYi11VC5_tCFj3Tu-d7EOcvuAEif0GtrvDggiW1751GBunrrRhiPEiJb0FwjsnazkPA3wqNpHukCDu0XRGvh-bIZx03FfRuBV4MuReZOMz3T3875g87t_SPlyGLMBjYbFWUR0GKgU4f-HAtEeiEd0stb_DwUMfve4yk9iHhdkgMlzWvJHZy5hrCqY/s1792/DALL%C2%B7E%202024-04-15%2017.44.33%20-%20A%20photograph%20of%20a%20laptop%20on%20a%20wooden%20desk%20with%20code%20on%20the%20screen,%20and%20next%20to%20it%20sits%20a%20plush%20toy%20elephant%20that%20typically%20represents%20PHP.%20However,%20th.webp)

  

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

```
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

```
php artisan serve
```

Perintah ini akan menjalankan server pengembangan lokal dan memberikan Anda URL untuk mengakses aplikasi web Anda, seperti link dibawah ini.

*   [http://127.0.0.1:8000](http://127.0.0.1:8000)
*   [http://localhost:8000](http://localhost:8000)

Secara default Laravel akan berjalan di port 8000, jika port tersebut sudah digunakan, maka Laravel akan berjalan di port 8001, 8002, dan seterusnya, namun port tersebut bisa diubah sesuai dengan keinginan anda dengan cara seperti di bawah ini:

```
php artisan serve --port=8080

```

Buka browser dan kunjungi URL yang diberikan. Anda akan melihat halaman selamat datang Laravel.

[![Welcome to Laravel](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgElsFwh46WsLgmCebXc3kNYnZ5w5OImmZpvCynQdPW3lxHB86H2JHTTYWZ1GbkvIm0CZuH8WpWNzMPfQD9huCn8HDmdV3_qEQCD9NMaNLO40eTebitvMHTkmeZFacX_szb2Ttq04ttrEC89KR3i4z7zziRRUUnBLH8AUpHaHep1KfyjV08M230uhsQi2qt/w640-h314/Screenshot%20from%202024-04-18%2015-01-02.png "Welcome to Laravel")](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgElsFwh46WsLgmCebXc3kNYnZ5w5OImmZpvCynQdPW3lxHB86H2JHTTYWZ1GbkvIm0CZuH8WpWNzMPfQD9huCn8HDmdV3_qEQCD9NMaNLO40eTebitvMHTkmeZFacX_szb2Ttq04ttrEC89KR3i4z7zziRRUUnBLH8AUpHaHep1KfyjV08M230uhsQi2qt/s1902/Screenshot%20from%202024-04-18%2015-01-02.png)