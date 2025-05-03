---
title: 'Cara Mudah Pasang Golang di Linux: Pilih Snap atau Langsung dari Sumber'
date: 2024-04-08T06:23:00.000+07:00
draft: false
url: /2024/04/cara-mudah-pasang-golang-di-linux-pilih.html
tags: 
- Go
---

[![Cara Mudah Pasang Golang di Linux](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiqP2q8Xiu1O9y7wlAyDx8y8O978IsB3aLkTF41hyaQ1XGb73qr5ZLwN5pp9dhIPe9vrs6sckE6kCR-FiVNQefUYLdntvRBGB6sSbKVl1c4oU4DBh34QOzHFFC4pzzuzq3B2qkgppdEpj92O5fMWk0Nc8C1folIuBsiEd1gWv4w3JE_7QqKFbDasAs630Qu/w640-h366/DALL%C2%B7E%202024-04-08%2006.07.08%20-%20Create%20a%20simple%20and%20clean%20digital%20thumbnail%20for%20a%20blog%20post%20in%20landscape%20orientation,%20showcasing%20the%20concept%20of%20installing%20the%20Go%20programming%20language.webp "Cara Mudah Pasang Golang di Linux")](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiqP2q8Xiu1O9y7wlAyDx8y8O978IsB3aLkTF41hyaQ1XGb73qr5ZLwN5pp9dhIPe9vrs6sckE6kCR-FiVNQefUYLdntvRBGB6sSbKVl1c4oU4DBh34QOzHFFC4pzzuzq3B2qkgppdEpj92O5fMWk0Nc8C1folIuBsiEd1gWv4w3JE_7QqKFbDasAs630Qu/s1792/DALL%C2%B7E%202024-04-08%2006.07.08%20-%20Create%20a%20simple%20and%20clean%20digital%20thumbnail%20for%20a%20blog%20post%20in%20landscape%20orientation,%20showcasing%20the%20concept%20of%20installing%20the%20Go%20programming%20language.webp)

Belajar Golang baru-baru ini telah membuka wawasan baru bagi saya dalam pengembangan software. Dalam proses belajar, saya menemukan bahwa salah satu cara terbaik untuk memperdalam pemahaman adalah dengan membagikan ilmu tersebut. Itu sebabnya, melalui artikel ini, saya ingin berbagi pengalaman saya menginstal Golang di Linux, baik melalui Snap maupun dari sumber langsung.

Menulis ini bukan hanya tentang berbagi, tapi juga cara untuk mengukuhkan apa yang telah saya pelajari. Saya percaya, dengan mendokumentasikan prosesnya, saya tidak hanya dapat membantu rekan-rekan yang juga tertarik untuk belajar Golang, tapi juga memperkuat ingatan saya sendiri tentang langkah-langkah tersebut.

### Instalasi Golang Melalui Snap

Snap merupakan sistem paket yang dikembangkan oleh Canonical, perusahaan di balik Ubuntu. Snap memudahkan instalasi dan pembaruan aplikasi di berbagai distro Linux dengan mengemas aplikasi tersebut beserta semua dependensinya. Ini berarti, dengan Snap, Anda dapat menginstal Golang tanpa khawatir tentang dependensi yang hilang atau versi yang tidak cocok.

1.  **Pertama, Pastikan Snap Tersedia**

Di sebagian besar distribusi Linux terbaru, Snap sudah terinstal secara default. Namun, jika Anda belum memilikinya, instal dengan perintah:

```
sudo apt update
sudo apt install snapd 
```4.  **Instal Golang**

Setelah Snap terinstal, Anda dapat menginstal Golang dengan perintah:

```
sudo snap install go --classic 
```7.  **Verifikasi Instalasi**

Untuk memastikan Golang terinstal dengan benar, jalankan perintah:

```
go version 
```

### Instalasi Golang dari Sumber / Source

1.  **Unduh Paket Sumber / Source**

Kunjungi [situs resmi Go](https://go.dev/dl/) untuk mengunduh paket sumber terbaru. Anda dapat menggunakan perintah wget atau curl untuk mengunduh paket tersebut. Sebagai contoh, untuk mengunduh Go versi 1.16.3, jalankan perintah:

```
wget https://golang.org/dl/go1.16.3.linux-amd64.tar.gz 
```4.  **Ekstrak Paket**

Gunakan perintah tar untuk mengekstrak paket ke direktori pilihan. Sebagai konvensi, Go biasanya diinstal di /usr/local atau direktori home pengguna.

```
sudo tar -C /usr/local -xzf go1.16.3.linux-amd64.tar.gz 
```7.  **Konfigurasi PATH**

Tambahkan direktori bin Go ke PATH Anda agar perintah Go dapat dijalankan dari terminal mana pun. Tambahkan baris berikut ke file .profile atau .bashrc Anda:

```
export PATH=$PATH:/usr/local/go/bin 
```10.  **Verifikasi Instalasi**

Untuk memastikan Golang terinstal dengan benar, jalankan perintah:

```
go version 
```

### Kesimpulan

Memilih antara Snap dan instalasi dari sumber tergantung pada preferensi dan kebutuhan Anda. Snap menawarkan kemudahan dan kecepatan, sementara instalasi dari sumber memberikan kontrol lebih dan akses ke versi terbaru. Kedua metodenya, jika diikuti dengan benar, akan membawa Anda ke dunia pengembangan Go dengan mulus dan efisien. Dengan Golang yang terinstal di sistem Linux Anda, dunia pengembangan software modern terbuka lebar dengan segala kemungkinannya. Selamat belajar!