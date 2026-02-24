---
title: 'Modern CLI Tools That Replace the Classics (grep, cat, ls, find, and More)'
description: >-
  Still using grep, cat, and ls from the 1970s? These modern CLI replacements
  are faster, prettier, and way more useful. Here's what to install and why you
  won't go back.
date: '2026-02-24T09:18:59.212Z'
tags:
  - Linux
  - Developer Tools
  - CLI
  - Terminal
  - Productivity
draft: false
author: Wiku Karno
keywords:
  - modern cli tools
  - terminal tools
  - ripgrep vs grep
  - bat vs cat
  - eza vs ls
  - modern terminal
  - best cli tools 2026
  - linux tools
  - developer terminal setup
  - fzf fuzzy finder
  - command line tools
  - zoxide
  - delta git diff
  - modern linux commands
  - cli alternatives
url: /2026/02/modern-cli-tools-that-replace-the-classics.html
image: /images/blog/code.webp
faq:
  - question: Will these modern CLI tools break my existing scripts?
    answer: >-
      No, installing these tools doesn't remove or modify the original commands.
      ripgrep installs as 'rg', bat installs as 'bat', eza installs as 'eza' —
      they all have their own binary names. Your existing scripts that use grep,
      cat, and ls will continue to work exactly as before. You can optionally
      create shell aliases to use the new tools as defaults, but that's entirely
      up to you.
  - question: Do these tools work on macOS or only Linux?
    answer: >-
      All the tools listed in this article work on macOS, Linux, and most work
      on Windows too. On macOS you can install them through Homebrew (brew
      install ripgrep bat eza fd zoxide fzf). On Linux, most are available
      through your package manager or as prebuilt binaries. The experience is
      nearly identical across platforms.
  - question: Which modern CLI tool should I install first?
    answer: >-
      Start with ripgrep (rg) and fzf. These two will have the biggest immediate
      impact on your daily workflow. ripgrep replaces grep and is dramatically
      faster for searching code. fzf adds fuzzy finding to everything — file
      search, command history, git branches. Once you're comfortable with those,
      add bat (better cat), eza (better ls), and zoxide (better cd) in that
      order.
  - question: Are modern CLI tools faster than the originals?
    answer: >-
      In most cases, significantly faster. ripgrep is 2-5x faster than grep for
      code searches because it respects .gitignore, skips binary files, and uses
      parallelism by default. fd is faster than find for the same reasons.
      However, for simple single-file operations, the performance difference is
      negligible. The real benefit is often the better defaults and more
      readable output rather than raw speed.
---

Most developers spend hours every day in the terminal. And most of us are still using tools written in the 1970s and 80s — `grep`, `cat`, `ls`, `find`, `cd`. They work, sure. But they were designed for a time when terminals had 24 rows and 80 columns, file systems were tiny, and nobody expected colored output or Unicode.

Sometime in the last few years, people started building modern replacements. Mostly in Rust, some in Go. They're faster, they have sane defaults, and they produce output you can actually read without squinting. I've been swapping out the classics one by one, and at this point I can't go back.

Here's what I use now and why.

## ripgrep (rg) — Replaces grep

**Install:** `brew install ripgrep` or `apt install ripgrep`

If you install only one tool from this list, make it ripgrep.

[grep](/2025/08/essential-linux-commands-every-developer-must-know-2025.html) is fine for simple searches. But the moment you're searching through a codebase, it falls apart. It searches binary files. It doesn't respect `.gitignore`. It's slow on large directories. And the output is a wall of text with no color.

ripgrep (`rg`) fixes all of that:

```bash
# Search for "handleRequest" in your project
rg "handleRequest"

# Search only in Go files
rg "handleRequest" -t go

# Search with context (3 lines above and below)
rg "handleRequest" -C 3

# Search ignoring case
rg -i "handlerequest"
```

It respects `.gitignore` automatically, so no more results from `node_modules` or `vendor/`. It skips binary files by default. It uses parallelism and memory maps under the hood, so on a large monorepo it finishes in seconds where grep takes minutes. And the output comes with colors and line numbers out of the box — you can actually read what you find.

Oh, and it uses regex by default. No more `grep -E` or trying to remember the difference between basic and extended regex.

After a week with ripgrep, going back to grep feels like typing with oven mitts on.

## bat — Replaces cat

**Install:** `brew install bat` or `apt install bat`

`cat` dumps file contents to stdout. That's it. No line numbers, no syntax highlighting, no paging. If the file is longer than your terminal, the top scrolls away and you're left reading the bottom.

`bat` does what `cat` should have done decades ago:

```bash
# View a file with syntax highlighting and line numbers
bat main.go

# View with a specific theme
bat --theme="Dracula" config.yaml

# View only a range of lines
bat -r 10:20 main.go

# Use as a drop-in cat replacement (no decorations)
bat --plain README.md
```

You get syntax highlighting for hundreds of languages, line numbers, and git integration that shows modified lines in the margin. Long files automatically pipe through a pager. Short files just print normally.

One thing I appreciate: bat is smart about piping. If you pipe its output to another command (`bat file.go | head`), it drops the decorations and behaves like plain `cat`. So it won't break your pipelines.

I have `alias cat="bat"` in my shell config and I've never had an issue.

## eza — Replaces ls

**Install:** `brew install eza` or `apt install eza`

(eza is the maintained fork of `exa`, which is no longer active.)

`ls` gives you a flat list of filenames. `ls -la` gives you a wall of permission strings and dates in a format nobody can parse at a glance. It works, but it hasn't changed since 1987.

```bash
# Basic listing with colors and icons
eza --icons

# Long format with human-readable sizes and git status
eza -la --icons --git

# Tree view (replaces the 'tree' command too)
eza --tree --level=2

# Sort by modification time
eza -la --sort=modified

# Only show directories
eza -D
```

The big selling points: file types are color-coded so you can tell directories from executables from symlinks at a glance. The long format shows human-readable sizes ("4.2M" instead of "4392837") and labels the columns with a header row. Git status per file is baked in — you see which files are modified, staged, or untracked right in the listing.

The tree view alone is worth the install. `eza --tree --level=3 --icons` gives you a project overview that you'd normally need a GUI file manager to get.

## fd — Replaces find

**Install:** `brew install fd` or `apt install fd-find`

If you've ever written a `find` command from memory on the first try without Googling the syntax, you're a better developer than me.

```bash
# find syntax — who remembers this?
find . -name "*.go" -type f -not -path "*/vendor/*"

# fd syntax — just type what you want
fd ".go$"
fd --type f --extension go
```

That alone should sell you on it. But there's more:

```bash
# Find all markdown files
fd -e md

# Find files matching a pattern
fd "test.*\.go$"

# Find and delete all .DS_Store files
fd -H ".DS_Store" -x rm {}

# Find directories only
fd --type d "config"

# Find files changed in the last 24 hours
fd --changed-within 1d
```

Same philosophy as ripgrep: respects `.gitignore`, regex by default, colored output. `fd -x` runs commands in parallel where `find -exec` runs them one at a time. And the syntax is something you can actually remember without checking the man page every time.

I use fd and ripgrep together constantly. `fd` finds files by name, `rg` finds files by content. Between the two, I rarely need anything else for searching.

## zoxide — Replaces cd

**Install:** `brew install zoxide` or `apt install zoxide`

This one solves a small problem but solves it really well. You know how you type the same long paths over and over?

```bash
cd ~/projects/company/backend/services/auth
cd ~/projects/company/frontend/src/components
cd /etc/nginx/sites-available
```

zoxide tracks where you've been and lets you jump back with partial names:

```bash
# After visiting a directory once, jump back from anywhere
z auth        # jumps to ~/projects/company/backend/services/auth
z components  # jumps to ~/projects/company/frontend/src/components
z nginx       # jumps to /etc/nginx/sites-available

# Interactive selection when multiple matches exist
zi auth       # shows a list and lets you pick
```

It keeps a database of your directory history, ranked by frequency and recency (they call it "frecency"). Type `z foo` and it jumps to the highest-ranked directory with "foo" in the path. Gets smarter the more you use it.

Add the init to your shell config:

```bash
# For bash
eval "$(zoxide init bash)"

# For zsh
eval "$(zoxide init zsh)"

# For fish
zoxide init fish | source
```

After a day of normal usage, you can jump anywhere in 2-3 keystrokes. Sounds minor, but once you're used to it, plain `cd` feels painfully slow.

## fzf — Fuzzy Finder for Everything

**Install:** `brew install fzf` or `apt install fzf`

fzf doesn't replace one specific command. It's a general-purpose fuzzy finder that plugs into everything. Pipe any list into it and it becomes interactive and searchable.

```bash
# Fuzzy search through files and open in editor
vim $(fzf)

# Search command history interactively (Ctrl+R becomes amazing)
# Just install fzf and press Ctrl+R — it hooks in automatically

# Preview files while searching
fzf --preview "bat --color=always {}"

# Search git branches and switch
git branch | fzf | xargs git checkout

# Kill a process interactively
ps aux | fzf | awk '{print $2}' | xargs kill
```

You can combine it with other tools for some really powerful stuff:

```bash
# Search code with ripgrep, fuzzy filter results, open in vim
rg --line-number "" | fzf --delimiter=: --preview "bat --color=always --highlight-line {2} {1}" | cut -d: -f1 | xargs vim
```

But honestly, the main reason to install fzf is the **Ctrl+R upgrade**. Your shell's command history search goes from "you must type the exact prefix" to "type any fragment and fuzzy match across your entire history." That feature alone justifies the install. Ctrl+T (file search) and Alt+C (directory jump) are nice bonuses.

fzf turns your terminal from "you must know the exact name" into "type a few characters and pick from a list." It's the closest thing to having IDE-like search in a terminal.

## delta — Replaces diff (and improves git diff)

**Install:** `brew install git-delta` or download from GitHub releases

Standard `diff` and `git diff` output is functional but ugly. Hard to see exactly what changed, especially in large diffs.

delta transforms your diffs. The best way to use it is as your git pager:

```ini
# ~/.gitconfig
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    line-numbers = true
    side-by-side = false

[merge]
    conflictstyle = diff3

[diff]
    colorMoved = default
```

Once that's set up, every `git diff`, `git log -p`, and `git show` automatically gets syntax highlighting inside diffs (actual language colors, not just red/green), line numbers on both sides, and word-level diff highlighting. That last one is the real killer — instead of marking an entire line as changed, delta highlights the specific words that differ. Makes spotting small edits trivial.

You can also use `delta --side-by-side` for a two-column view and navigate between files with n/N.

Once you review a PR with delta's output, going back to plain `git diff` feels like reading code on a receipt printer.

## btop — Replaces top and htop

**Install:** `brew install btop` or `apt install btop`

`top` is a relic. `htop` was a big step up. `btop` takes it further.

```bash
btop
```

One command gives you CPU usage per core with historical graphs, memory breakdown, disk I/O, network traffic per interface, and a sortable/searchable/filterable process list. All in a TUI you can navigate with mouse or keyboard.

It looks like a monitoring dashboard that someone spent weeks building, except it's one binary with zero config. Supports themes, custom layouts, and GPU monitoring if you have the right drivers.

Not a tool you use all day, but when you need to figure out what's eating your CPU or memory, nothing beats it.

## httpie — Replaces curl (for API testing)

**Install:** `brew install httpie` or `apt install httpie`

Let me be clear: curl is great. It handles FTP, SCP, proxies, and dozens of protocols. But for the one thing most developers actually use it for — testing HTTP APIs — the syntax is rough.

```bash
# curl — lots of flags and quoting
curl -X POST https://api.example.com/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token123" \
  -d '{"name": "John", "email": "john@example.com"}'

# httpie — just type what you mean
http POST api.example.com/users \
  name=John \
  email=john@example.com \
  Authorization:"Bearer token123"
```

httpie sends JSON by default (no Content-Type header needed), syntax-highlights the response, and has intuitive shortcuts: `param=value` for JSON data, `Header:Value` for headers, `param==value` for query strings. It also supports sessions, so you can save auth tokens and reuse them.

I still reach for curl when I need something specific, but for quick "does this endpoint work?" checks, httpie is way less typing.

## lazygit — A Terminal UI for Git

**Install:** `brew install lazygit` or `go install github.com/jesseduffield/lazygit@latest`

This one doesn't replace a single command. It replaces the whole `git status` → `git add` → `git diff` → `git commit` → `git log` cycle that you repeat dozens of times a day.

```bash
lazygit
```

Full terminal UI with panels for file status, staging, commit history, branches, and stash. Everything you'd do with 5-6 different git commands, you do with keyboard shortcuts in one interface.

The feature that won me over is **interactive staging**. You can stage specific lines within a file — not just whole files, individual lines. This is great when you've made multiple unrelated changes and want clean, focused commits. The built-in `git add -p` does this technically, but the UX is painful. In lazygit, it takes two seconds.

For [complex git operations](/2025/01/git-commands-cheat-sheet-every-developer-must-know.html) like rebasing, conflict resolution, and cherry-picking, having a visual interface makes these things way less intimidating.

## tldr — Replaces man (sort of)

**Install:** `brew install tldr` or `npm install -g tldr`

Man pages are thorough. That's the problem. When you just need to remember how `tar` or `rsync` works, wading through 2000 lines of documentation is way more than what the situation calls for.

`tldr` gives you community-maintained cheat sheets:

```bash
# Instead of: man tar (900 lines)
tldr tar

# Output:
# tar
# Archiving utility.
# Often combined with a compression method, such as gzip or bzip2.
#
# - Create an archive and write it to a file:
#   tar cf target.tar file1 file2 file3
#
# - Create a gzipped archive and write it to a file:
#   tar czf target.tar.gz file1 file2 file3
#
# - Extract a (compressed) archive into the current directory:
#   tar xf source.tar[.gz|.bz2|.xz]
```

The 5-6 most common use cases for each command. That's what you need 95% of the time. When you actually need the full details, `man` is still there.

## starship — Replaces Your Shell Prompt

**Install:** `brew install starship` or `curl -sS https://starship.rs/install.sh | sh`

Your default prompt shows username and current directory. Starship swaps that for a context-aware prompt:

```bash
# Add to your shell config
eval "$(starship init zsh)"   # or bash, fish
```

In a Git repo, it shows the branch and status. In a Go project, it shows the Go version. In a Python virtualenv, it shows the env name. When a command takes a long time, it shows the duration. When a command fails, the prompt turns red. It only shows what's relevant to where you are.

Configuration lives in `~/.config/starship.toml` if you want to customize it. Purely cosmetic, but it makes your terminal feel more informative without cluttering it.

## The Install Script

Want everything at once?

### macOS

```bash
brew install ripgrep bat eza fd zoxide fzf git-delta btop httpie lazygit tldr starship
```

### Ubuntu/Debian

```bash
sudo apt install ripgrep bat fd-find fzf btop httpie
# For eza, zoxide, delta, lazygit, starship — check their GitHub releases
# or use cargo install if you have Rust toolchain
```

### Shell Aliases (add to ~/.zshrc or ~/.bashrc)

```bash
# Modern replacements
alias cat="bat"
alias ls="eza --icons"
alias ll="eza -la --icons --git"
alias lt="eza --tree --level=2 --icons"
alias grep="rg"
alias find="fd"
alias top="btop"
alias diff="delta"

# fzf + bat preview
alias preview="fzf --preview 'bat --color=always {}'"

# Initialize zoxide
eval "$(zoxide init zsh)"

# Initialize starship
eval "$(starship init zsh)"
```

After adding aliases, run `source ~/.zshrc` (or open a new terminal) and you're set.

## Which Ones Are Worth It?

If you don't want to install all twelve, here's how I'd prioritize:

1. **ripgrep** — Biggest daily impact. No question.
2. **fzf** — The Ctrl+R upgrade alone is worth it.
3. **bat** — Small change, but you notice it every time you read a file.
4. **eza** — Nice to have. The git integration is the main draw.
5. **zoxide** — Worth it if you jump between project directories a lot.
6. **delta** — Install if you review diffs often (so... all of us).
7. **fd** — Solid find replacement, though you might not use find that often.
8. **lazygit** — Great if you prefer terminal over GUI git clients.
9. **btop** — Beautiful system monitor, but you only check it occasionally.
10. **httpie** — Handy for API work, but curl muscle memory dies hard.
11. **tldr** — For the "how does tar work again?" moments.
12. **starship** — Cosmetic, but makes your prompt actually useful.

The first three took me five minutes to install and made an immediate difference. Start there and add the rest when you feel like it.

## Closing Thought

None of these tools let you do something you couldn't do before. Everything here, you could pull off with the classic commands plus flags and piping. What changes is the friction. Less Googling for syntax, less squinting at monochrome output, less waiting for slow searches to finish.

In a job where you run hundreds of terminal commands per day, that friction adds up more than you'd think.
