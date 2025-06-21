---
title: 'Cara Menjalankan Project Laravel Clone dari GitHub'
date: 2023-04-09T23:08:00.002+07:00
draft: false
featured: true
url: /2023/04/cara-menjalankan-project-laravel-clone.html
image: /images/blog/code.jpg
tags: 
- Laravel
description: "Panduan lengkap cara menjalankan project Laravel yang di-clone dari GitHub. Cocok untuk pemula yang ingin belajar Laravel."
keywords: ["laravel", "clone laravel", "laravel github", "laravel project", "laravel tutorial"]
---

Sebelum kita melakukan cloning project Laravel dari GitHub, pastikan kamu telah menginstal tools berikut agar proses berjalan lancar.

Tools di bawah ini sangat penting. Tanpa keduanya, kamu tidak akan bisa menjalankan project Laravel dengan benar.

1. [Git](https://git-scm.com/)
2. [Composer](https://getcomposer.org/download/)

Untuk mendapatkan project Laravel dari GitHub, ada dua cara:

1. **Menggunakan Git**
2. **Mengunduh via file ZIP**

Tidak ada perbedaan signifikan, hanya beda cara ambilnya. Kita bahas dua-duanya.

## 💻 Cara Clone Menggunakan Git

1. Salin URL repository dari GitHub (HTTPS atau SSH).
2. Buka terminal dan jalankan:

    ```bash
    git clone <url-repository>
    ```

3. Kalau ingin beri nama folder project-nya:

    ```bash
    git clone <url-repository> nama-folder
    ```

4. Tunggu proses cloning selesai.
5. Masuk ke folder project:

    ```bash
    cd nama-folder
    ```

6. Install dependensi:

    ```bash
    composer install
    ```

7. Salin file `.env`:

    ```bash
    cp .env.example .env
    ```

8. Generate key:

    ```bash
    php artisan key:generate
    ```

9. Bersihkan konfigurasi cache (opsional):

    ```bash
    php artisan config:clear
    ```

10. Jalankan Laravel:

    ```bash
    php artisan serve
    ```

Lalu buka `http://127.0.0.1:8000` di browser favorit kamu.

## 📦 Cara Download Menggunakan ZIP

1. Klik tombol **Code** di GitHub, lalu pilih **Download ZIP**.
2. Ekstrak filenya.
3. Buka terminal, masuk ke folder hasil ekstrak.
4. Lanjutkan langkah instalasi seperti pada metode Git di atas (`composer install`, dll).

---

Sebagian besar developer lebih suka menggunakan Git, tapi metode ZIP juga tetap valid. Silakan pilih yang paling nyaman buat kamu.

Semoga bermanfaat!