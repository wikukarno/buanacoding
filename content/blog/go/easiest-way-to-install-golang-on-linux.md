---
title: "Easiest Way to Install Golang on Linux Snap or Manual Source?"
date: 2024-04-08T06:23:00+07:00
draft: false
url: /2024/04/easiest-way-to-install-golang-on-linux.html
tags:
  - Go
image: /images/golang-linux.jpg
description: "Learn how to install Golang on Linux using either Snap or manual source installation. Ideal for beginners and developers setting up their Go environment."
keywords: ["golang", "install go", "linux go installation", "snap install go", "manual install go"]
---

Learning Golang recently opened up new perspectives for me in software development. One of the best ways to solidify your understanding is by teaching others. That’s why in this article, I’m sharing my experience installing Go on Linux—using both Snap and manual source installation.

Writing this guide not only helps others get started, but also helps reinforce the steps in my own memory.

---

## Installing Golang Using Snap

Snap is a universal package manager developed by Canonical (Ubuntu’s creator). It simplifies app installation by bundling dependencies, ensuring compatibility across most Linux distributions.

1. **Ensure Snap is Installed**  
   On many modern Linux distros, Snap is pre-installed. If not, you can install it via terminal:

    ```bash
    sudo apt update
    sudo apt install snapd
    ```

2. **Install Go via Snap**

    ```bash
    sudo snap install go --classic
    ```

3. **Verify the Installation**

    ```bash
    go version
    ```

That’s it! You’ve successfully installed Go using Snap.

---

## 🛠️ Installing Golang from Official Source

If you want more control over your Go installation or prefer not to use Snap, manual installation is the way to go.

1. **Download the Official Go Tarball**  
   Visit the [official Go downloads page](https://go.dev/dl/) and download the latest version. Example:

    ```bash
    wget https://go.dev/dl/go1.16.3.linux-amd64.tar.gz
    ```

2. **Extract the Archive to `/usr/local`**

    ```bash
    sudo tar -C /usr/local -xzf go1.16.3.linux-amd64.tar.gz
    ```

3. **Update Your PATH**  
   Add Go’s binary path to your environment variable:

    ```bash
    export PATH=$PATH:/usr/local/go/bin
    ```

   Add that line to `~/.bashrc` or `~/.zshrc`, then apply:

    ```bash
    source ~/.bashrc
    ```

4. **Verify the Installation**

    ```bash
    go version
    ```

---

## Snap vs Manual Installation – Which One is Better?

| Method  | Pros                                 | Cons                          |
|---------|--------------------------------------|-------------------------------|
| Snap    | Quick, easy, auto-updates            | Slightly slower start-up time |
| Source  | Full control, latest versions        | Manual setup & maintenance    |

---

## Conclusion

Whether you choose Snap or manual installation, both methods are solid and effective. Snap is faster for beginners, while manual installation is great for advanced users or multi-version management.

Now that Go is installed, you're ready to build high-performance APIs, CLI tools, or even web servers. Happy coding with Golang!
