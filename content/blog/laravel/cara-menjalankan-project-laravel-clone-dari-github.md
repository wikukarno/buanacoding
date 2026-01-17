---
title: 'Cara Menjalankan Project Laravel Clone dari GitHub'
date: 2023-04-09T23:08:00.002+07:00
draft: false
featured: true
url: /2023/04/cara-menjalankan-project-laravel-clone.html
image: https://cdn.buanacoding.com/cdn-cgi/image/width=800,quality=80,format=auto/code.jpg
tags:
- Laravel
description: "Panduan lengkap cara menjalankan project Laravel yang di-clone dari GitHub. Cocok untuk pemula yang ingin belajar Laravel dari setup awal hingga troubleshooting."
keywords: ["laravel", "clone laravel", "laravel github", "laravel project", "laravel tutorial", "composer install", "laravel migration", "laravel seeder", "env laravel"]
schema: "Article"
author: "BuanaCoding"
datePublished: "2023-04-09"
dateModified: "2023-04-09"

faq:
  - question: "Apa saja yang harus diinstall sebelum menjalankan project Laravel dari GitHub?"
    answer: "Kamu perlu install Git untuk cloning repository, Composer untuk mengelola dependency PHP, PHP (minimal versi 8.1 untuk Laravel 10), dan database seperti MySQL atau PostgreSQL. Pastikan juga ekstensi PHP yang dibutuhkan sudah aktif seperti OpenSSL, PDO, Mbstring, Tokenizer, XML, dan Ctype. Tanpa tools ini, project Laravel tidak akan bisa jalan."

  - question: "Kenapa muncul error 'No application encryption key has been specified'?"
    answer: "Error ini muncul karena APP_KEY di file .env belum di-generate. Solusinya jalankan php artisan key:generate di terminal. Command ini akan membuat encryption key otomatis dan menyimpannya di file .env. Key ini penting untuk enkripsi session dan data sensitif di Laravel."

  - question: "Bagaimana cara setup database untuk project Laravel yang baru di-clone?"
    answer: "Buat database baru di MySQL atau PostgreSQL, lalu edit file .env dan isi DB_DATABASE dengan nama database, DB_USERNAME dengan username database, dan DB_PASSWORD dengan password. Setelah itu jalankan php artisan migrate untuk membuat tabel-tabel, dan php artisan db:seed jika ada seeder untuk data dummy."

  - question: "Apa beda clone pakai Git dengan download ZIP dari GitHub?"
    answer: "Git clone membuat koneksi ke repository sehingga kamu bisa pull update terbaru dan push perubahan. Download ZIP hanya mengambil snapshot kode tanpa history Git, jadi tidak bisa sync dengan repository. Untuk development aktif, pakai Git clone. Untuk sekedar coba-coba, download ZIP sudah cukup."

  - question: "Kenapa folder storage dan bootstrap/cache permission denied?"
    answer: "Laravel butuh write permission di folder storage dan bootstrap/cache untuk menyimpan log, cache, dan compiled views. Di Linux/Mac jalankan chmod -R 775 storage bootstrap/cache lalu chown -R www-data:www-data storage bootstrap/cache. Di Windows, pastikan folder tidak read-only dan user punya akses penuh."

  - question: "Apakah harus jalankan composer update setelah composer install?"
    answer: "Tidak perlu. composer install sudah cukup karena akan install dependency sesuai versi yang tercatat di composer.lock. Justru composer update berbahaya karena bisa upgrade package ke versi terbaru yang mungkin breaking changes. Hanya jalankan composer update kalau memang mau upgrade dependency dengan sadar risikonya."

  - question: "Bagaimana cara troubleshooting kalau Laravel tidak mau jalan setelah di-clone?"
    answer: "Cek step by step: pastikan composer install sukses tanpa error, file .env sudah ada dan dikonfigurasi benar, APP_KEY sudah di-generate, database connection di .env sudah benar, migration sudah dijalankan, folder storage dan bootstrap/cache punya permission yang tepat, dan versi PHP sesuai requirement Laravel. Lihat juga file storage/logs/laravel.log untuk error detail."
---

Dapat project Laravel dari GitHub tapi bingung cara jalankannya? Atau malah error melulu saat setup? Tenang, kamu tidak sendirian. Banyak developer pemula (bahkan yang udah agak senior) sering stuck di tahap ini.

Clone project Laravel dari GitHub itu gampang kalau tau step-by-step yang benar. Tapi kalau asal comot dan langsung jalankan, siap-siap ketemu segudang error dari missing dependencies, database connection failed, sampai permission issues.

Panduan ini akan ngajarin kamu cara yang benar - mulai dari persiapan tools, proses cloning, konfigurasi environment, setup database, sampai troubleshooting error-error umum yang sering muncul. Saya jelaskan juga kenapa setiap step penting, jadi kamu paham beneran, bukan cuma ikutin command buta.

## Persiapan: Tools yang Wajib Ada

Sebelum mulai clone project Laravel, pastikan kamu sudah install tools-tools ini. Tanpa mereka, project Laravel tidak akan bisa jalan sama sekali.

### Git - Version Control System

Git dipakai untuk clone repository dari GitHub. Ini tools wajib pertama yang harus ada.

**Install Git:**

Windows - Download dari [git-scm.com](https://git-scm.com/) dan install seperti biasa.

macOS - Biasanya sudah ada, kalau belum:
```bash
brew install git
```

Linux (Ubuntu/Debian):
```bash
sudo apt-get update
sudo apt-get install git
```

Cek instalasi Git:
```bash
git --version
# git version 2.40.0
```

### Composer - PHP Dependency Manager

Composer itu kayak npm-nya PHP. Laravel butuh Composer untuk install semua package dan dependency yang diperlukan.

**Install Composer:**

Download installer dari [getcomposer.org](https://getcomposer.org/download/) dan ikuti instruksi untuk sistem operasi kamu.

Verifikasi instalasi:
```bash
composer --version
# Composer version 2.6.5
```

Composer harus terinstall global supaya bisa dipanggil dari mana aja di terminal.

### PHP - Minimal Versi 8.1

Laravel 10 butuh PHP minimal 8.1. Laravel 11 butuh PHP 8.2. Cek versi PHP kamu:

```bash
php -v
# PHP 8.2.0
```

Kalau versi PHP kamu masih lama, upgrade dulu. Di Ubuntu:

```bash
sudo add-apt-repository ppa:ondrej/php
sudo apt-get update
sudo apt-get install php8.2
```

Di macOS pakai Homebrew:

```bash
brew install php@8.2
```

### Ekstensi PHP yang Dibutuhkan

Laravel butuh beberapa ekstensi PHP. Cek dengan `php -m` dan pastikan ada:

- OpenSSL
- PDO
- Mbstring
- Tokenizer
- XML
- Ctype
- JSON
- BCMath

Kalau ada yang kurang, install sesuai package manager OS kamu. Di Ubuntu contohnya:

```bash
sudo apt-get install php8.2-mbstring php8.2-xml php8.2-bcmath
```

### Database - MySQL atau PostgreSQL

Laravel support berbagai database, tapi yang paling umum:

**MySQL:**
```bash
# Ubuntu
sudo apt-get install mysql-server

# macOS
brew install mysql
```

**PostgreSQL:**
```bash
# Ubuntu
sudo apt-get install postgresql

# macOS
brew install postgresql
```

Start service database setelah install:

```bash
# MySQL
sudo systemctl start mysql

# PostgreSQL
sudo systemctl start postgresql
```

Pastikan kamu punya akses root atau buat user database baru untuk Laravel.

### Node.js dan NPM (Opsional tapi Sering Perlu)

Kalau project Laravel pakai frontend assets (Vue, React, atau Tailwind), kamu butuh Node.js untuk compile assets.

```bash
# Ubuntu
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# macOS
brew install node
```

Verifikasi:
```bash
node -v
npm -v
```

Sekarang semua tools sudah ready. Lanjut ke proses cloning.

## Cara 1: Clone Menggunakan Git (Recommended)

Ini cara yang paling proper dan flexible. Kamu dapat full repository dengan git history, bisa pull update, dan push changes kalau punya akses.

### Step 1: Dapatkan URL Repository

Buka repository Laravel di GitHub. Klik tombol hijau **Code**, copy URL-nya. Ada dua pilihan:

**HTTPS** - `https://github.com/username/project-laravel.git`
Gampang, tapi harus login terus kalau push.

**SSH** - `git@github.com:username/project-laravel.git`
Perlu setup SSH key dulu, tapi lebih aman dan ga perlu login berkali-kali.

Untuk pemula, pakai HTTPS dulu aja.

### Step 2: Clone Repository

Buka terminal, masuk ke folder tempat kamu mau simpan project:

```bash
cd ~/Documents/projects
```

Clone repository:

```bash
git clone https://github.com/username/project-laravel.git
```

Kalau mau ganti nama folder:

```bash
git clone https://github.com/username/project-laravel.git nama-project-baru
```

Git akan download semua file dari repository ke komputer kamu. Tunggu sampai selesai.

### Step 3: Masuk ke Folder Project

```bash
cd project-laravel
```

Cek isi folder:

```bash
ls -la
```

Kamu harusnya lihat struktur Laravel standar: `app/`, `config/`, `database/`, `public/`, dll.

### Step 4: Install Dependencies dengan Composer

Ini step paling penting. Folder `vendor/` yang berisi semua package Laravel tidak di-commit ke Git (karena terlalu besar). Jadi kamu harus install manual.

```bash
composer install
```

Command ini baca file `composer.json` dan `composer.lock`, lalu download semua dependency yang dibutuhkan ke folder `vendor/`.

Prosesnya bisa 1-5 menit tergantung koneksi internet dan jumlah package. Kalau sukses, kamu lihat output:

```
Package operations: 108 installs, 0 updates, 0 removals
  - Installing doctrine/inflector (2.0.8)
  - Installing doctrine/lexer (3.0.0)
  ...
Generating optimized autoload files
```

**Jangan pakai `composer update`!** Itu akan upgrade package ke versi terbaru yang mungkin incompatible dengan project. Selalu pakai `composer install` untuk install dependency sesuai versi di `composer.lock`.

### Step 5: Setup File Environment (.env)

Laravel pakai file `.env` untuk konfigurasi environment-specific seperti database credentials, APP_KEY, debug mode, dll.

File `.env` tidak di-commit ke Git karena berisi data sensitif. Yang di-commit itu `.env.example` sebagai template.

Copy `.env.example` jadi `.env`:

```bash
cp .env.example .env
```

Di Windows pakai:

```cmd
copy .env.example .env
```

Sekarang kamu punya file `.env` yang bisa dikonfigurasi.

### Step 6: Generate Application Key

Laravel butuh APP_KEY untuk enkripsi session, cookies, dan data sensitif lainnya. Generate dengan:

```bash
php artisan key:generate
```

Output:
```
Application key set successfully.
```

Command ini otomatis update `APP_KEY` di file `.env` dengan random string 32 karakter.

Kalau kamu skip step ini, nanti error:

```
RuntimeException: No application encryption key has been specified.
```

### Step 7: Konfigurasi Database

Buka file `.env` dengan text editor favorit:

```bash
nano .env
# atau
code .env
# atau editor lain
```

Cari bagian database configuration:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=nama_database
DB_USERNAME=root
DB_PASSWORD=
```

Sesuaikan dengan setup database kamu:

**DB_DATABASE** - Nama database yang akan dipakai. Pastikan database ini sudah dibuat di MySQL/PostgreSQL.

**DB_USERNAME** - Username database (biasanya `root` untuk MySQL lokal).

**DB_PASSWORD** - Password database (kosongkan kalau ga pakai password di lokal).

**Contoh untuk MySQL lokal:**

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel_project
DB_USERNAME=root
DB_PASSWORD=secret123
```

**Contoh untuk PostgreSQL:**

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=laravel_project
DB_USERNAME=postgres
DB_PASSWORD=password
```

Save file `.env` setelah edit.

### Step 8: Buat Database

Sebelum migrate, pastikan database sudah ada. Masuk ke MySQL atau PostgreSQL dan buat database:

**MySQL:**
```bash
mysql -u root -p
```

Di MySQL console:
```sql
CREATE DATABASE laravel_project;
EXIT;
```

**PostgreSQL:**
```bash
psql -U postgres
```

Di PostgreSQL console:
```sql
CREATE DATABASE laravel_project;
\q
```

Nama database harus sama dengan `DB_DATABASE` di file `.env`.

### Step 9: Jalankan Migration

Migration itu file-file PHP yang define struktur database (tabel, kolom, index, dll). Laravel pakai migration untuk bikin tabel secara programmatic.

Jalankan migration:

```bash
php artisan migrate
```

Laravel akan baca semua file di `database/migrations/` dan execute query untuk bikin tabel. Output:

```
Migration table created successfully.
Migrating: 2014_10_12_000000_create_users_table
Migrated:  2014_10_12_000000_create_users_table (85.32ms)
Migrating: 2014_10_12_100000_create_password_reset_tokens_table
Migrated:  2014_10_12_100000_create_password_reset_tokens_table (48.21ms)
...
```

Kalau error "Access denied for user", cek lagi credential database di `.env`.

Kalau error "Unknown database", pastikan database sudah dibuat di step sebelumnya.

### Step 10: Seed Database (Opsional)

Kalau project punya seeder untuk data dummy atau data awal, jalankan:

```bash
php artisan db:seed
```

Atau seed specific seeder:

```bash
php artisan db:seed --class=UserSeeder
```

Seeder populate database dengan data sample buat testing atau development. Tidak semua project punya seeder, jadi kalau error "Class DatabaseSeeder does not exist", skip aja.

### Step 11: Set Permissions untuk Storage dan Cache

Laravel butuh write permission di folder `storage/` dan `bootstrap/cache/` untuk simpan log, cache, compiled views, uploaded files, dll.

**Di Linux/macOS:**

```bash
chmod -R 775 storage bootstrap/cache
```

Kalau pakai web server seperti Nginx atau Apache:

```bash
sudo chown -R www-data:www-data storage bootstrap/cache
```

Ganti `www-data` dengan user web server kamu (bisa `nginx`, `apache`, atau lainnya).

**Di Windows:**

Klik kanan folder `storage` dan `bootstrap/cache`, masuk Properties > Security, pastikan user kamu punya Full Control. Uncheck "Read-only" kalau aktif.

### Step 12: Install NPM Dependencies (Kalau Ada)

Kalau project pakai frontend framework atau CSS preprocessor, kamu perlu install NPM packages:

```bash
npm install
```

Lalu compile assets:

```bash
# Development
npm run dev

# Production
npm run build
```

Kalau ga ada `package.json`, skip step ini.

### Step 13: Clear Cache (Opsional tapi Disarankan)

Kadang Laravel nyimpen cache yang ga sesuai dengan environment baru. Clear semua cache:

```bash
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
```

Ini ensure Laravel mulai fresh tanpa cache lama yang bikin bingung.

### Step 14: Jalankan Development Server

Sekarang project siap dijalankan. Start Laravel development server:

```bash
php artisan serve
```

Output:
```
INFO  Server running on [http://127.0.0.1:8000].

Press Ctrl+C to stop the server
```

Buka browser dan akses `http://127.0.0.1:8000`. Kalau semua step benar, kamu lihat homepage Laravel.

Kalau mau ganti port:

```bash
php artisan serve --port=8080
```

Atau bind ke IP tertentu:

```bash
php artisan serve --host=0.0.0.0 --port=8000
```

Ini bikin Laravel bisa diakses dari komputer lain di network yang sama.

## Cara 2: Download ZIP dari GitHub

Kalau ga mau pake Git (entah kenapa), kamu bisa download project sebagai ZIP file.

### Step 1: Download ZIP

Di halaman GitHub repository, klik tombol **Code** > **Download ZIP**.

Save file ZIP ke komputer, lalu extract.

### Step 2: Masuk ke Folder Project

Buka terminal, navigate ke folder hasil extract:

```bash
cd ~/Downloads/project-laravel-main
```

Nama folder biasanya `nama-repo-main` atau `nama-repo-master` tergantung branch default.

### Step 3: Lanjutkan Step Install Seperti Cara Git

Mulai dari **Step 4** di metode Git di atas:

1. `composer install`
2. `cp .env.example .env`
3. `php artisan key:generate`
4. Konfigurasi database di `.env`
5. Buat database
6. `php artisan migrate`
7. Set permissions
8. `php artisan serve`

Semua step sama persis, cuma beda di awal aja (download ZIP vs git clone).

### Kekurangan Metode ZIP

Download ZIP berarti kamu ga punya Git history. Kamu ga bisa:

- Pull update terbaru dari repository
- Push perubahan kamu ke GitHub
- Lihat commit history
- Switch branch

Jadi metode ini cuma cocok buat sekedar coba-coba atau belajar. Untuk development serius, pakai Git clone.

## Setup Database: Lebih Detail

Database configuration sering jadi sumber error paling banyak. Mari bahas lebih dalam.

### Memilih Database Driver

Laravel support beberapa database. Pilih sesuai kebutuhan project:

**MySQL** - Paling populer, banyak hosting support, performa bagus untuk aplikasi medium.

**PostgreSQL** - Lebih advanced features, strict data integrity, bagus untuk aplikasi enterprise.

**SQLite** - File-based, gampang setup, cocok untuk testing atau aplikasi kecil.

**SQL Server** - Untuk environment Windows Server dan .NET integration.

Di `.env`, set `DB_CONNECTION` sesuai database yang kamu pakai:

```env
# MySQL
DB_CONNECTION=mysql

# PostgreSQL
DB_CONNECTION=pgsql

# SQLite
DB_CONNECTION=sqlite

# SQL Server
DB_CONNECTION=sqlsrv
```

### Konfigurasi MySQL

Edit `.env`:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel_app
DB_USERNAME=laravel_user
DB_PASSWORD=secure_password
```

**Best practice:** Jangan pakai user `root` untuk aplikasi. Buat user khusus dengan privilege terbatas:

```sql
CREATE DATABASE laravel_app;
CREATE USER 'laravel_user'@'localhost' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON laravel_app.* TO 'laravel_user'@'localhost';
FLUSH PRIVILEGES;
```

### Konfigurasi PostgreSQL

Edit `.env`:

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=laravel_app
DB_USERNAME=laravel_user
DB_PASSWORD=secure_password
```

Di PostgreSQL:

```sql
CREATE DATABASE laravel_app;
CREATE USER laravel_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE laravel_app TO laravel_user;
```

### Konfigurasi SQLite

SQLite simple, ga butuh server terpisah. Database-nya cuma file.

Edit `.env`:

```env
DB_CONNECTION=sqlite
# Hapus atau comment line DB_HOST, DB_PORT, DB_DATABASE, dll
```

Buat file database:

```bash
touch database/database.sqlite
```

Jalankan migration langsung, Laravel otomatis pakai file itu.

### Test Koneksi Database

Sebelum migrate, test dulu koneksi database:

```bash
php artisan tinker
```

Di Tinker console:

```php
DB::connection()->getPdo();
```

Kalau sukses, output object PDO. Kalau error, cek lagi credential di `.env`.

Exit Tinker:

```php
exit
```

## Running Migrations: Yang Perlu Kamu Tau

Migration itu version control untuk database schema. Setiap perubahan struktur database (bikin tabel, tambah kolom, dll) dibuat sebagai migration file.

### Struktur Migration File

Migration file ada di `database/migrations/`. Contoh:

```
2014_10_12_000000_create_users_table.php
2014_10_12_100000_create_password_reset_tokens_table.php
2023_05_15_143022_create_posts_table.php
```

Format: `YYYY_MM_DD_HHMMSS_description.php`

Timestamp ensure migration jalan sesuai urutan.

### Isi Migration File

Contoh `create_users_table.php`:

```php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->unique();
            $table->timestamp('email_verified_at')->nullable();
            $table->string('password');
            $table->rememberToken();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
```

**Method `up()`** - Dijalankan saat migrate, define struktur tabel.

**Method `down()`** - Dijalankan saat rollback, revert perubahan.

### Jalankan Migration

Command dasar:

```bash
# Jalankan semua migration yang belum dijalankan
php artisan migrate

# Rollback migration terakhir
php artisan migrate:rollback

# Rollback semua migration
php artisan migrate:reset

# Rollback semua, lalu migrate lagi (fresh start)
php artisan migrate:refresh

# Drop semua tabel, lalu migrate lagi
php artisan migrate:fresh

# Migrate dengan seeder
php artisan migrate --seed
```

**Hati-hati dengan `migrate:fresh` dan `migrate:refresh`!** Kedua command ini drop semua data di database. Jangan pakai di production.

### Migration Status

Cek migration mana yang sudah jalan:

```bash
php artisan migrate:status
```

Output:

```
+------+---------------------------------------------+-------+
| Ran? | Migration                                   | Batch |
+------+---------------------------------------------+-------+
| Yes  | 2014_10_12_000000_create_users_table        | 1     |
| Yes  | 2014_10_12_100000_create_password_resets    | 1     |
| No   | 2023_05_15_143022_create_posts_table        | -     |
+------+---------------------------------------------+-------+
```

Ini bantu kamu tau migration mana yang pending.

### Troubleshooting Migration Error

**Error: SQLSTATE[42S01]: Base table or view already exists**

Tabel sudah ada. Rollback dulu atau drop manual:

```bash
php artisan migrate:rollback
```

**Error: Syntax error or access violation**

Biasanya typo di migration file atau privilege database kurang. Cek query di migration file dan privilege user database.

**Error: Class 'Database' not found**

Pastikan `composer install` sudah jalan dan autoload di-generate:

```bash
composer dump-autoload
```

## Menangani Seeders dan Dummy Data

Seeder populate database dengan data awal atau sample. Berguna untuk development dan testing.

### Check Seeder yang Tersedia

Lihat folder `database/seeders/`. File utama biasanya `DatabaseSeeder.php`:

```php
namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            UserSeeder::class,
            PostSeeder::class,
            CategorySeeder::class,
        ]);
    }
}
```

Seeder lain dipanggil dari `DatabaseSeeder`.

### Jalankan Seeder

Jalankan semua seeder:

```bash
php artisan db:seed
```

Atau seeder tertentu:

```bash
php artisan db:seed --class=UserSeeder
```

### Migrate + Seed Sekaligus

```bash
php artisan migrate --seed
```

Atau fresh migrate dengan seed:

```bash
php artisan migrate:fresh --seed
```

Ini drop semua tabel, migrate lagi, lalu seed. Cocok buat reset database ke state awal.

### Seeder untuk Production

Jangan jalankan seeder sembarangan di production. Seeder biasanya cuma untuk development data.

Kalau butuh data awal di production (misal: roles, permissions, default settings), buat seeder khusus dan document dengan jelas.

## Permission dan Storage: Kenapa Penting

Laravel butuh write access ke beberapa folder untuk nyimpen file temporary, cache, log, dan uploaded files.

### Folder yang Butuh Write Permission

**storage/app/** - File upload, temporary files

**storage/framework/** - Cache, sessions, compiled views

**storage/logs/** - Application logs

**bootstrap/cache/** - Compiled services dan packages

Tanpa write permission, Laravel error kayak:

```
The stream or file "storage/logs/laravel.log" could not be opened:
failed to open stream: Permission denied
```

### Set Permission di Linux/macOS

```bash
chmod -R 775 storage bootstrap/cache
```

Kalau pakai web server:

```bash
sudo chown -R www-data:www-data storage bootstrap/cache
```

User `www-data` harus punya akses write. Ganti sesuai user web server kamu (`nginx`, `apache`, dll).

### Troubleshooting Permission Issues

**Error: failed to open stream: Permission denied**

Folder atau file ga punya permission. Set ulang:

```bash
chmod -R 775 storage
```

**Error: The stream or file could not be opened in append mode**

Log file ga bisa di-write. Fix:

```bash
chmod -R 775 storage/logs
```

Atau delete log file lama:

```bash
rm storage/logs/laravel.log
```

Laravel auto-create file baru dengan permission yang benar.

### Permission di Windows

Windows jarang ada masalah permission. Tapi kalau error:

1. Klik kanan folder `storage` dan `bootstrap/cache`
2. Properties > Security
3. Edit > pilih user kamu
4. Check "Full control"
5. Apply

Pastikan juga folder tidak Read-only:

1. Properties > General
2. Uncheck "Read-only"
3. Apply to all subfolders

## Compile Frontend Assets

Banyak project Laravel modern pakai frontend framework atau CSS framework yang butuh compilation.

### Check Package.json

Lihat file `package.json` di root project. Kalau ada, berarti project butuh npm:

```json
{
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  },
  "devDependencies": {
    "axios": "^1.6.0",
    "laravel-vite-plugin": "^1.0",
    "vite": "^5.0"
  }
}
```

### Install NPM Dependencies

```bash
npm install
```

Ini download semua packages di `node_modules/`. Folder ini juga ga di-commit ke Git karena besar.

### Compile Assets untuk Development

```bash
npm run dev
```

Vite (atau Laravel Mix untuk project lama) compile assets dan watch perubahan. Output:

```
VITE v5.0.0  ready in 543 ms

➜  Local:   http://localhost:5173/
➜  Network: use --host to expose
➜  press h + enter to show help
```

Biarkan running di terminal terpisah. Setiap kali kamu edit JS/CSS, auto recompile.

### Build untuk Production

```bash
npm run build
```

Ini compile assets dengan optimisasi penuh (minify, tree shaking, dll). File hasil ada di `public/build/`.

### Kalau Ga Ada package.json

Berarti project ga pakai build tools. Assets langsung di `public/` dan siap pakai.

## Troubleshooting: Error Umum dan Solusinya

Setelah bantu ratusan developer setup Laravel, ini error yang paling sering muncul.

### Error: "No application encryption key has been specified"

**Penyebab:** `APP_KEY` di `.env` kosong atau belum di-generate.

**Solusi:**

```bash
php artisan key:generate
```

Refresh browser, error hilang.

### Error: "SQLSTATE[HY000] [1045] Access denied for user"

**Penyebab:** Username atau password database salah di `.env`.

**Solusi:**

1. Cek credential database di `.env`
2. Test login manual ke database:
   ```bash
   mysql -u username -p
   ```
3. Kalau ga bisa login, reset password atau buat user baru

### Error: "SQLSTATE[HY000] [1049] Unknown database"

**Penyebab:** Database belum dibuat.

**Solusi:**

```bash
mysql -u root -p
CREATE DATABASE nama_database;
EXIT;
```

Sesuaikan `nama_database` dengan `DB_DATABASE` di `.env`.

### Error: "Class 'XXX' not found"

**Penyebab:** Autoload belum di-generate atau ada class yang missing.

**Solusi:**

```bash
composer dump-autoload
```

Kalau masih error, cek apakah ada typo di namespace atau class name.

### Error: "The stream or file could not be opened: failed to open stream: Permission denied"

**Penyebab:** Folder `storage/` atau `bootstrap/cache/` ga punya write permission.

**Solusi:**

```bash
chmod -R 775 storage bootstrap/cache
```

### Error: "419 Page Expired" saat Submit Form

**Penyebab:** CSRF token expired atau missing.

**Solusi:**

1. Clear cache:
   ```bash
   php artisan cache:clear
   ```

2. Pastikan form punya `@csrf`:
   ```blade
   <form method="POST">
       @csrf
       <!-- form fields -->
   </form>
   ```

3. Set `SESSION_DRIVER` di `.env`:
   ```env
   SESSION_DRIVER=file
   ```

### Error: "Vite manifest not found"

**Penyebab:** Frontend assets belum di-compile.

**Solusi:**

```bash
npm install
npm run dev
```

Atau untuk production:

```bash
npm run build
```

### Error: "Target class [XXXController] does not exist"

**Penyebab:** Route reference controller yang ga ada atau namespace salah.

**Solusi:**

1. Cek file controller ada di `app/Http/Controllers/`
2. Pastikan namespace benar:
   ```php
   namespace App\Http\Controllers;
   ```
3. Clear route cache:
   ```bash
   php artisan route:clear
   ```

### Error: "The Mix manifest does not exist"

**Penyebab:** Project pakai Laravel Mix tapi assets belum di-compile.

**Solusi:**

```bash
npm install
npm run dev
```

Laravel Mix itu predecessor Vite, masih dipakai di project Laravel lama.

## Environment Configuration: Deep Dive

File `.env` itu jantung konfigurasi Laravel. Setiap environment (local, staging, production) punya `.env` berbeda.

### Struktur File .env

Contoh `.env` lengkap:

```env
APP_NAME=Laravel
APP_ENV=local
APP_KEY=base64:xxx
APP_DEBUG=true
APP_TIMEZONE=Asia/Jakarta
APP_URL=http://localhost:8000

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel_app
DB_USERNAME=root
DB_PASSWORD=

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your@email.com
MAIL_PASSWORD=your-app-password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@yourdomain.com
MAIL_FROM_NAME="${APP_NAME}"
```

### APP_ENV: Environment Type

**local** - Development di komputer lokal. Debug mode aktif, error ditampilkan lengkap.

**staging** - Testing environment sebelum production. Setup mirip production tapi data dummy.

**production** - Live server. Debug mode off, error ga detail ke user.

Set sesuai environment:

```env
APP_ENV=local
```

### APP_DEBUG: Debug Mode

**true** - Tampilkan error detail dengan stack trace. Jangan pakai di production!

**false** - Error generic, detail hanya di log file. Wajib di production.

```env
APP_DEBUG=true  # local
APP_DEBUG=false # production
```

### APP_URL: Base URL

URL dasar aplikasi. Penting untuk generate link dan asset path yang benar.

```env
APP_URL=http://localhost:8000          # local
APP_URL=https://staging.yourdomain.com # staging
APP_URL=https://yourdomain.com         # production
```

### Mail Configuration

Kalau project kirim email (reset password, notification, dll), configure mail:

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
MAIL_ENCRYPTION=tls
```

Untuk Gmail, pakai [App Password](https://support.google.com/accounts/answer/185833), bukan password akun.

### Cache dan Session

**CACHE_DRIVER** - Tempat simpan cache. Pilihan: `file`, `redis`, `memcached`, `database`.

**SESSION_DRIVER** - Tempat simpan session. Pilihan: `file`, `cookie`, `database`, `redis`.

Untuk local development, `file` sudah cukup:

```env
CACHE_DRIVER=file
SESSION_DRIVER=file
```

Production biasanya pakai `redis` untuk performa lebih baik.

### Queue Configuration

**QUEUE_CONNECTION** - Driver untuk job queue.

Development pakai `sync` (langsung execute):

```env
QUEUE_CONNECTION=sync
```

Production pakai `redis` atau `database`:

```env
QUEUE_CONNECTION=redis
```

Jangan lupa jalankan queue worker:

```bash
php artisan queue:work
```

## Testing Project: Memastikan Semuanya Jalan

Setelah setup, test apakah project bener-bener jalan.

### Test Homepage

Akses `http://127.0.0.1:8000` di browser. Kalau muncul homepage Laravel atau custom homepage project, berarti routing basic works.

### Test Database Connection

Buka route yang query database (misal: `/users`, `/posts`). Kalau data muncul tanpa error, database connection sukses.

Atau test via Tinker:

```bash
php artisan tinker
```

```php
User::count();  // Harus return number, bukan error
```

### Test Authentication

Kalau project punya login/register, test:

1. Register user baru
2. Login dengan user tersebut
3. Akses halaman yang butuh auth

Kalau sukses tanpa error 419 atau redirect loop, auth system works.

### Test File Upload

Kalau ada fitur upload (avatar, post image, dll), test upload file. Pastikan:

1. File tersimpan di `storage/app/`
2. File bisa diakses via URL kalau public
3. Ga ada error permission

### Run Automated Tests

Kalau project punya unit test atau feature test:

```bash
php artisan test
```

Atau pakai PHPUnit langsung:

```bash
./vendor/bin/phpunit
```

Test yang pass berarti core functionality project ga rusak.

### Check Logs

Buka `storage/logs/laravel.log`. Lihat apakah ada error atau warning yang mencurigakan.

Kalau ada error meski aplikasi jalan, fix sekarang sebelum jadi masalah besar.

## Git Workflow Setelah Clone

Setelah clone dan setup, kamu biasanya mau mulai development. Ini workflow Git yang proper.

### Create Development Branch

Jangan langsung coding di `main` atau `master`. Buat branch baru:

```bash
git checkout -b feature/user-profile
```

Atau untuk bugfix:

```bash
git checkout -b fix/login-error
```

### Commit Changes

Setelah coding:

```bash
git add .
git commit -m "Add user profile page with avatar upload"
```

Commit message harus descriptive, jelasin apa yang kamu tambah/ubah/fix.

### Push ke GitHub

```bash
git push origin feature/user-profile
```

Kalau belum punya akses push, fork dulu repository-nya, clone fork kamu, baru push.

### Pull Request

Di GitHub, buat Pull Request dari branch kamu ke `main`. Tunggu code review dari team.

### Pull Latest Changes

Sebelum mulai coding, selalu pull changes terbaru:

```bash
git checkout main
git pull origin main
git checkout -b feature/new-feature
```

Ini ensure kamu coding di codebase terbaru, ga conflict dengan perubahan orang lain.

### Sync Fork

Kalau kamu pake fork, sync dengan upstream repository:

```bash
git remote add upstream https://github.com/original-owner/repo.git
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

## Deployment Considerations

Project udah jalan di lokal? Saatnya mikir deployment ke production.

### Environment Variables

**Jangan commit file `.env` ke Git!** File ini berisi credentials dan secret keys.

Di server production:

1. Copy `.env.example` jadi `.env`
2. Edit sesuai production environment
3. Set `APP_ENV=production` dan `APP_DEBUG=false`

### Optimize untuk Production

Jalankan optimization commands:

```bash
# Cache configuration
php artisan config:cache

# Cache routes
php artisan route:cache

# Cache views
php artisan view:cache

# Optimize Composer autoload
composer install --optimize-autoloader --no-dev
```

Ini bikin Laravel load lebih cepat dengan cache semua configuration dan routes.

### Database Migration di Production

**Hati-hati dengan migration di production!** Bisa bikin downtime atau data loss.

Best practice:

1. Backup database dulu
2. Test migration di staging dengan production data
3. Run migration saat traffic rendah
4. Monitor error logs

```bash
# Backup
mysqldump -u user -p database > backup.sql

# Migrate
php artisan migrate --force
```

Flag `--force` diperlukan di production karena Laravel confirm dulu.

### Web Server Configuration

Kalau pakai Nginx atau Apache, pastikan document root point ke `public/` folder, bukan root project.

**Nginx contoh:**

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    root /var/www/laravel-app/public;

    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

**Apache contoh (.htaccess sudah ada di public/):**

```apache
<VirtualHost *:80>
    ServerName yourdomain.com
    DocumentRoot /var/www/laravel-app/public

    <Directory /var/www/laravel-app/public>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

### Security Checklist

Sebelum go live:

- `APP_DEBUG=false` di `.env`
- `APP_ENV=production` di `.env`
- HTTPS aktif (SSL certificate installed)
- File `.env` ga accessible via web
- Folder `storage/` dan `bootstrap/cache/` ga accessible via web
- Database user punya privilege minimal (bukan root)
- Firewall configured (hanya port 80, 443, dan SSH)
- Regular backup database dan files

## Working with Teams

Clone project dari team? Ikuti konvensi dan workflow mereka.

### README.md

Baca `README.md` di root project. Biasanya ada instruksi khusus untuk setup:

- Versi PHP dan extensions yang dibutuhkan
- Database yang harus dipakai
- External services (Redis, ElasticSearch, dll)
- Custom setup steps
- Environment variables yang perlu di-set

Ikuti README itu. Developer sebelumnya udah documentasikan hal-hal penting.

### Contributing Guidelines

File `CONTRIBUTING.md` menjelaskan:

- Branch naming convention
- Commit message format
- Code style guide
- Pull request process
- Testing requirements

Ikuti guidelines ini supaya PR kamu ga direject.

### Project-Specific Commands

Cek `composer.json` bagian `scripts`. Sering ada custom commands:

```json
"scripts": {
    "post-install-cmd": [
        "@php artisan key:generate --ansi"
    ],
    "setup": [
        "composer install",
        "npm install",
        "cp .env.example .env",
        "@php artisan key:generate",
        "@php artisan migrate --seed"
    ]
}
```

Kalau ada script `setup`, kamu bisa jalankan:

```bash
composer run setup
```

Ini auto-execute semua command setup sekaligus.

### Ask Questions

Ga ngerti sesuatu? Tanya team lead atau developer lain. Lebih baik tanya daripada asal asumsi dan bikin bug.

## Advanced: Docker dan Laravel Sail

Banyak project Laravel modern pakai Docker untuk development environment yang consistent.

### Laravel Sail

Laravel Sail itu Docker wrapper buat Laravel. Tinggal satu command, environment siap.

Kalau project punya file `docker-compose.yml` dan folder `vendor/laravel/sail`, kemungkinan pakai Sail.

### Setup dengan Sail

```bash
# Install dependencies via Docker (ga perlu PHP atau Composer di local)
docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$(pwd):/var/www/html" \
    -w /var/www/html \
    laravelsail/php82-composer:latest \
    composer install --ignore-platform-reqs

# Copy .env
cp .env.example .env

# Start Sail
./vendor/bin/sail up -d

# Generate key
./vendor/bin/sail artisan key:generate

# Migrate
./vendor/bin/sail artisan migrate
```

### Sail Commands

Setelah Sail running, semua command Laravel pakai prefix `sail`:

```bash
# Artisan
./vendor/bin/sail artisan migrate

# Composer
./vendor/bin/sail composer require package/name

# NPM
./vendor/bin/sail npm install

# Tinker
./vendor/bin/sail tinker

# Bash ke container
./vendor/bin/sail bash
```

### Alias untuk Sail

Biar ga cape ngetik `./vendor/bin/sail` terus, buat alias:

```bash
alias sail='./vendor/bin/sail'
```

Add ke `~/.bashrc` atau `~/.zshrc` supaya permanent.

Sekarang tinggal:

```bash
sail up
sail artisan migrate
sail composer install
```

### Benefits Pakai Sail

- Consistent environment semua developer (same PHP, MySQL, Redis version)
- Ga perlu install PHP, MySQL, dll di local machine
- Easy switch antar project dengan setup berbeda
- Mirip production environment

## Common Mistakes dan Cara Menghindarinya

Dari pengalaman ngajarin Laravel, ini kesalahan umum pemula.

### Mistake 1: Langsung `composer update`

**Salah:** Habis clone, langsung `composer update`.

**Kenapa salah:** `composer update` upgrade packages ke versi terbaru, bisa breaking compatibility.

**Benar:** Selalu `composer install`. Ini install sesuai versi di `composer.lock`.

### Mistake 2: Lupa Generate APP_KEY

**Salah:** Langsung akses aplikasi tanpa generate key.

**Kenapa salah:** Error "No application encryption key" dan session ga jalan.

**Benar:** Selalu `php artisan key:generate` setelah copy `.env`.

### Mistake 3: Pakai Database Root User

**Salah:** Set `DB_USERNAME=root` di `.env` production.

**Kenapa salah:** Security risk. Root user punya akses penuh ke semua database.

**Benar:** Buat user khusus dengan privilege minimal untuk aplikasi.

### Mistake 4: Debug Mode di Production

**Salah:** `APP_DEBUG=true` di production.

**Kenapa salah:** Expose sensitive info (database queries, file paths, environment variables) ke user.

**Benar:** Selalu `APP_DEBUG=false` di production.

### Mistake 5: Ignore Storage Permissions

**Salah:** Ga set permission di `storage/` dan `bootstrap/cache/`.

**Kenapa salah:** Laravel ga bisa write logs, cache, sessions. Aplikasi error atau lambat.

**Benar:** Always `chmod -R 775 storage bootstrap/cache` setelah clone.

### Mistake 6: Commit File .env

**Salah:** Add file `.env` ke Git.

**Kenapa salah:** Credentials dan secrets ke-expose di repository.

**Benar:** `.env` harus ada di `.gitignore`. Commit hanya `.env.example`.

### Mistake 7: Skip Migration

**Salah:** Langsung akses halaman tanpa migrate.

**Kenapa salah:** Tabel belum ada, query error.

**Benar:** Selalu `php artisan migrate` setelah setup database.

## Laravel Versions dan Compatibility

Project Laravel beda versi punya requirement beda.

### Laravel 11 (Latest)

- PHP 8.2 minimum
- New application structure
- Streamlined configuration
- Better performance

### Laravel 10

- PHP 8.1 minimum
- Long Term Support (LTS) until Feb 2025
- Native type hints
- Improved processes

### Laravel 9

- PHP 8.0 minimum
- LTS until Feb 2024 (already ended)
- Controller route groups
- Improved Eloquent

### Laravel 8

- PHP 7.3 minimum
- Jetstream and Fortify
- Job batching
- Migration squashing

### Check Laravel Version

Lihat di `composer.json`:

```json
"require": {
    "php": "^8.1",
    "laravel/framework": "^10.0"
}
```

Atau via Artisan:

```bash
php artisan --version
# Laravel Framework 10.48.4
```

Pastikan versi PHP kamu sesuai dengan minimum requirement Laravel yang dipakai project.

## Resources dan Learning Path

Habis berhasil clone dan jalanin project Laravel, lanjut belajar apa?

### Official Documentation

[Laravel Documentation](https://laravel.com/docs) - Selalu refer ke docs versi yang sesuai project kamu.

### Tutorial Lanjutan

Kalau kamu tertarik lebih dalam dengan Laravel, cek artikel-artikel ini:

- [Cara Install dan Configure Yajra DataTable di Laravel](/2023/08/how-to-install-and-configure-yajra.html) - Buat tabel data interaktif
- Integrasi Laravel dengan API external
- Authentication dan authorization advanced
- Queue dan background jobs
- Real-time dengan Laravel Echo dan Pusher

### Backend Development Path

Laravel itu bagian dari ekosistem backend development. Perluas skill dengan:

- [REST API development](/tags/rest-api/) - Build dan consume APIs
- [Database management](/tags/database/) - Optimization dan scaling
- [Docker deployment](/tags/docker/) - Containerization dan orchestration

### Community

Join komunitas Laravel:

- [Laracasts](https://laracasts.com/) - Video tutorials berkualitas
- [Laravel News](https://laravel-news.com/) - Update terbaru Laravel
- Laravel Indonesia Telegram/Discord - Diskusi dengan developer lokal
