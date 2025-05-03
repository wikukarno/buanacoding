---
title: 'Cara menjalankan project laravel clone dari github'
date: 2023-04-09T23:08:00.002+07:00
draft: false
featured: true
url: /2023/04/cara-menjalankan-project-laravel-clone.html
image: /images/blog/code.jpg
tags: 
- Laravel
---

Sebelum kita melakukan cloning project laravel dari github, pastikan kamu telah menginstall tools yang tertera dibawah ini, agar proses cloning berjalan dengan lancar.

1.  [git](https://git-scm.com/)
2.  [composer](https://getcomposer.org/download/)

Tools diatas sangat penting untuk melakukan cloning project laravel dari github, jika tidak ada maka kita tidak bisa melakukannya.

  

Untuk melakukan cloning atau download project laravel dari github ini ada dua cara, pertama menggunakan git dan yang kedua adalah download menggunakan zip seperti gambar dibawah ini.

  

[![clone project from github](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiS_h6FCNSFXUu1GNAgaPNHhC3n_6oWhPFrFxpqL72UYfDwoc3dCj8VoN71p2EmYo-Zqp-be9jvHk7vaXSxCrieU12oiZWLAlIWzPYr9SihVmZfPOQ_0_Gb0UqPb1theAWshcN2zuGzTesIoh-KaOdqhQSxIu8s8wc9FoWGnAMhG_rhcbeCDUwHfDHsPA/w400-h233/cloningprojectgithub.webp)](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiS_h6FCNSFXUu1GNAgaPNHhC3n_6oWhPFrFxpqL72UYfDwoc3dCj8VoN71p2EmYo-Zqp-be9jvHk7vaXSxCrieU12oiZWLAlIWzPYr9SihVmZfPOQ_0_Gb0UqPb1theAWshcN2zuGzTesIoh-KaOdqhQSxIu8s8wc9FoWGnAMhG_rhcbeCDUwHfDHsPA/s512/cloningprojectgithub.webp)

  

Sebenarnya tidak ada perbedaan yang signifikan dari kedua cara tersebut, dan hasil akhirnya adalah sama, cuman beda cara saja.

  

Pada artikel ini kita akan melakukan kedua cara tersebut supaya lebih jelas perbedaannya, ya walaupun tidak berbeda jauh.

  

### Cara clone menggunakan git

1.  copykan script dari https atau ssh ke dalam terminal kamu.
2.  buka terminal kamu dan ketikan git clone url repository seperti gambar dibawah ini.  
      
    
    [![git clone](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEg3AiWs__PvFlpfdzQ7rjCtdEurYJ0Jo5NwlEHXIF3G83ZNxa1KkmRrIi-3GCqEe_wjA4IEhdAZCyrVUgm1wPn2zfxsyZf_w-ezNh7Q1Z_PlukfZaVLdRqfqyRjgMjyg-IL8ZLgWuk0bIeCSSXIuKvhf6b3f_KdJhnvNelgRLrHw4Lj9gH6ZAgC4wmuBA/w400-h48/Screenshot%20from%202023-04-09%2022-00-54.webp)](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEg3AiWs__PvFlpfdzQ7rjCtdEurYJ0Jo5NwlEHXIF3G83ZNxa1KkmRrIi-3GCqEe_wjA4IEhdAZCyrVUgm1wPn2zfxsyZf_w-ezNh7Q1Z_PlukfZaVLdRqfqyRjgMjyg-IL8ZLgWuk0bIeCSSXIuKvhf6b3f_KdJhnvNelgRLrHw4Lj9gH6ZAgC4wmuBA/s823/Screenshot%20from%202023-04-09%2022-00-54.webp)
    
      
    
3.  kamu juga bisa memberikan nama pada project yang kamu clone seperti gambar dibawah ini.  
      
    
    [![clone with name folder](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEh9NdPFK-UgC4NweRIRHxj-lMnYg4qJz_GyQcw_Ue0GnRA2NCHaHDadkGAjPoufcqgZupmoYcnKW4xjHMxZJ6K4FPihbAHFwyLMHqB6VtXATqXlt7Pd1Fkk6e6sKlSz7gDpxI_pnJnbavQeAdz6KrUaZaZRzX23y3RlgBioU_a2szitR2xM_89cPgiZSA/w400-h102/Screenshot%20from%202023-04-09%2022-16-16.webp)](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEh9NdPFK-UgC4NweRIRHxj-lMnYg4qJz_GyQcw_Ue0GnRA2NCHaHDadkGAjPoufcqgZupmoYcnKW4xjHMxZJ6K4FPihbAHFwyLMHqB6VtXATqXlt7Pd1Fkk6e6sKlSz7gDpxI_pnJnbavQeAdz6KrUaZaZRzX23y3RlgBioU_a2szitR2xM_89cPgiZSA/s1192/Screenshot%20from%202023-04-09%2022-16-16.webp)
    
      
    
4.  Jika sudah tunggu proses cloning hingga selesai 
5.  Jika sudah masuk kedalam direktori project seperti printah dibawah ini  
    
    > cd nama project clone
    
6.  Jika sudah masuk kedalam direktori silahkan ketikan perintah dibawah ini.  
      
    
    > composer install 
    
    jika proses installasi dependensi sudah selesai maka langkah selanjutnya kamu harus copy file .env.example seperti dibawah ini.  
    
    > cp .env.example .env 
    
    Jika sudah silahkan generate app\_key laravel seperti script dibawah ini  
    
    > php artisan key:generate
    
    Jika sudah seharusnya kita sudah bisa menjalankan project laravel, namu alangkah lebih baiknya kita clear cache jika baru clone project dari git, untuk meminimalisir terjadinya error menggunakan perintah seperti dibawah ini.  
    
    > php artisan config:clear
    
    Jika sudah maka tinggal kita jalankan project yang sudah kita clone menggunakan perintah dibawah ini.  
    
    > php artisan serve
    
    Lalu pastekan link url (http://127.0.0.1:8000) pada browser favorit anda, maka project laravel pun berhasil dijalankan seperti gambar dibawah ini.  
    

[![Laravel](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjAIrzSKCzEPor0O_MbtDVEgdd-MQ7jPpgZE-9ThUh8twoDtQWy6NZpt0yFdXhtFgsdBzPRTc0e0ADktGS_7FpviatBH8LDpQwTEFeqFc-KxEPmTFYNLYNzH48YS1SZmsUXbn3V2LpXgjmQDfF7f1JNWZ4c_hsHCSI5Y641J-PzDJfhCnG1vZe0LQdh4g/w640-h298/Screenshot%20from%202023-04-09%2022-18-14.webp)](https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjAIrzSKCzEPor0O_MbtDVEgdd-MQ7jPpgZE-9ThUh8twoDtQWy6NZpt0yFdXhtFgsdBzPRTc0e0ADktGS_7FpviatBH8LDpQwTEFeqFc-KxEPmTFYNLYNzH48YS1SZmsUXbn3V2LpXgjmQDfF7f1JNWZ4c_hsHCSI5Y641J-PzDJfhCnG1vZe0LQdh4g/s1355/Screenshot%20from%202023-04-09%2022-18-14.webp)

  

  

  

### Cara Clone atau Download menggunakan Zip

Sebenernya cara ini cukup mudah tinggal kita klik maka secara otomatis project langsung terdownload.

  

Untuk konfigurasi sama seperti script diatas hanya beda cara saja, biasanya kebanyakan dari developer mengunakan git untuk cloning project.

  

Namun kembali lagi kepada diri sendiri lebih enak dan nyaman mengunakan yang mana, semoga bermanfaat terimakasih.