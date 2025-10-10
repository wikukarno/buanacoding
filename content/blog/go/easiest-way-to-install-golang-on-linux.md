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
faq:
  - question: "Why does 'go version' command not work after installing Go on Linux?"
    answer: "Command not found means Go binary not in PATH—shell can't locate /usr/local/go/bin/go executable. Causes: (1) Forgot to update PATH in shell config. (2) Modified wrong config file (edited .bashrc but using zsh). (3) Didn't reload config (need source ~/.bashrc or restart terminal). (4) Snap installation but snap/bin not in PATH. Fix for manual install: echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc; source ~/.bashrc. Check which shell: echo $SHELL—if /bin/zsh, edit ~/.zshrc instead. Verify PATH: echo $PATH | grep go—should show /usr/local/go/bin. Fix for snap: ensure /snap/bin in PATH: export PATH=$PATH:/snap/bin, or reinstall: sudo snap install go --classic. Debug: (1) Check Go exists: ls /usr/local/go/bin/go—if missing, extraction failed. (2) Run directly: /usr/local/go/bin/go version—works means PATH issue only. (3) Check permissions: sudo chmod +x /usr/local/go/bin/go if not executable. Permanent fix: add export to shell config, not just terminal—survives logout. Ubuntu: edit /etc/environment for system-wide PATH. Don't: add to .bash_profile on most Linux distros—not sourced by default terminal."
  - question: "How do I install and manage multiple Go versions side-by-side on Linux?"
    answer: "Use go install golang.org/dl/goX.Y@latest to install version managers, or manual symlinks. Multiple versions useful for: (1) Testing compatibility. (2) Different projects require different versions. (3) Trying beta releases. Method 1 (official go download command): go install golang.org/dl/go1.21.5@latest; go1.21.5 download; now use go1.21.5 version instead of go. Install another: go install golang.org/dl/go1.22.0@latest; go1.22.0 download. Switch: use go1.21.5 build or go1.22.0 build. Location: installed to ~/go/bin/ and ~/sdk/. Method 2 (manual extraction): download multiple tarballs: wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz; sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz; sudo mv /usr/local/go /usr/local/go1.21. Repeat for other versions. Symlink active version: sudo ln -s /usr/local/go1.21/bin/go /usr/local/bin/go. Switch: rm symlink, create new. Method 3 (g version manager): install g: curl -sSL https://git.io/g-install | bash; then g install 1.21.5; g set 1.21.5—easiest. Also: gvm (Go Version Manager), but less maintained. Best practice: use official go download method (Method 1)—simple, no sudo, per-project .go-version file support. CI/CD: setup-go GitHub Action handles versions automatically. Don't: overwrite /usr/local/go repeatedly—breaks go.mod compatibility checks."
  - question: "Should I use apt-get, snap, or manual installation for Go on Ubuntu/Debian?"
    answer: "Manual installation (official tarball) recommended for latest version and control; snap for simplicity; avoid apt-get (outdated). apt-get install golang: (1) Old versions—Ubuntu repos lag 6-12 months behind. (2) Hard to upgrade—tied to distro release cycle. (3) Might install go1.13 on Ubuntu 20.04 (ancient). Only use if: specific old version needed, locked-down enterprise environment. snap install go --classic: (1) Always latest stable—canonical updates regularly. (2) Auto-updates—security patches applied automatically. (3) Easy install/uninstall. (4) Cons: slight startup delay (snap confinement overhead), larger disk usage (~300MB vs 150MB). Good for: beginners, single-version systems, auto-update preference. Manual (wget + tar): (1) Latest version—go.dev always current. (2) Full control—disable telemetry, custom install path. (3) Multiple versions easy—extract to different dirs. (4) No package manager overhead. (5) Cons: manual updates, no automatic security patches. Best for: developers, CI/CD, multi-version needs. Recommendation matrix: beginners → snap, professional dev → manual, production servers → manual (pinned version for reproducibility), Docker → official golang:1.21 image (don't install in container). Migration: uninstall apt version (sudo apt remove golang-go), install manually. Check version after: go version should show go1.21+ in 2024, not go1.13."
  - question: "How do I properly uninstall and upgrade Go on Linux without breaking my environment?"
    answer: "Remove old installation completely before upgrading—partial removal leaves broken symlinks and PATH conflicts. Uninstall manual installation: (1) Remove directory: sudo rm -rf /usr/local/go. (2) Clean PATH: edit ~/.bashrc or ~/.zshrc, remove export PATH=$PATH:/usr/local/go/bin line. (3) Remove user cache: rm -rf ~/go (optional, keeps installed tools/modules—skip if you want to preserve). (4) Verify: go version should error 'command not found'. Uninstall snap: sudo snap remove go—automatically cleans up, no PATH changes needed. Uninstall apt: sudo apt remove golang-go; sudo apt autoremove. Upgrade manual: (1) Download new version: wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz. (2) Remove old: sudo rm -rf /usr/local/go. (3) Extract new: sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz. (4) PATH already set, no change needed. (5) Verify: go version shows new version. Upgrade snap: sudo snap refresh go—automatic. Pitfalls: (1) Forgot to remove old version—go1.21 and go1.22 both in PATH, which runs depends on order. (2) Removed ~/go—lost all installed tools (godoc, gopls), need reinstall. (3) Broke GOPATH projects—rare, but old GOPATH projects might break on major Go version jump (1.16→1.22). Best practice: test new version in Docker first: docker run -it golang:1.22 go version, then upgrade host. Rollback: keep old tarball, re-extract if new version has issues. Production: pin Go version in Dockerfile/CI config, don't auto-upgrade."
  - question: "What's the difference between GOPATH, GOROOT, and GOMODCACHE, and do I need to set them in 2024?"
    answer: "GOROOT: where Go is installed (/usr/local/go)—rarely need to set, auto-detected. GOPATH: legacy workspace for pre-modules Go (pre-1.11)—defaults to ~/go, usually don't set. GOMODCACHE: where go mod downloads dependencies—defaults to $GOPATH/pkg/mod, rarely changed. Modern Go (1.11+): modules replace GOPATH, you don't need to set any of these for normal development. GOROOT: only set if: (1) Custom install location (e.g., /opt/go instead of /usr/local/go). (2) Multiple Go versions installed, explicitly select one. Check: go env GOROOT—shows /usr/local/go, auto-detected from go binary location. GOPATH: only matters for: (1) go install binaries—installs to $GOPATH/bin (default ~/go/bin). (2) Pre-module projects—ancient code using GOPATH workspace. Modern: ignore GOPATH, use go mod init in project dir. GOMODCACHE: only set if: (1) Shared cache across users—set to /var/cache/go. (2) Disk space issues—move to bigger partition. (3) CI optimization—persistent cache dir. Common mistake: export GOPATH=$HOME/myproject—wrong, GOPATH is global workspace, not per-project. Module projects don't need GOPATH set at all. What to actually set in ~/.bashrc: just PATH: export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin—access go and installed tools. Check defaults: go env shows all vars. Best practice 2024: (1) Don't set GOROOT/GOPATH/GOMODCACHE unless specific need. (2) Do set PATH to include /usr/local/go/bin and ~/go/bin. (3) Use modules (go mod init) for all projects. Legacy: if maintaining old GOPATH project, structure: ~/go/src/github.com/user/repo—but convert to modules."
  - question: "Why does 'go install' put binaries in ~/go/bin and how do I access them easily?"
    answer: "go install compiles and installs binaries to $GOPATH/bin (defaults to ~/go/bin)—separate from Go installation (/usr/local/go/bin). Reason: user-installed tools (gopls, staticcheck, dlv) shouldn't mix with Go distribution binaries. Problem: install tool go install golang.org/x/tools/gopls@latest, run gopls, get 'command not found'—~/go/bin not in PATH. Fix: add to PATH: echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc; source ~/.bashrc. Now gopls, dlv, etc. work. Verify: echo $PATH | grep go/bin should show /home/username/go/bin. Change install location: set GOBIN: export GOBIN=/usr/local/bin—installs to system bin (needs sudo). Or: export GOBIN=$HOME/.local/bin—common user bin dir. Don't: set GOBIN=/usr/local/go/bin—pollutes Go installation. Common tools installed to ~/go/bin: (1) gopls (LSP server for editors). (2) staticcheck (linter). (3) dlv (debugger). (4) godoc (documentation server). (5) Custom CLI tools from your projects. List installed tools: ls ~/go/bin. Remove tool: rm ~/go/bin/gopls (no package manager). Best practice: add ~/go/bin to PATH permanently in shell config—standard Go convention. Alternative: symlink specific tools: sudo ln -s ~/go/bin/gopls /usr/local/bin/gopls—per-tool basis. Production containers: COPY --from=builder /go/bin/myapp /usr/local/bin/myapp in Dockerfile. Project-specific tools: go install ./cmd/mytool installs to ~/go/bin but built from local code."
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
