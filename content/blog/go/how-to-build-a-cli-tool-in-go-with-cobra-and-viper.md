---
title: "How to Build a CLI Tool in Go with Cobra and Viper"
description: "Complete guide to building production-ready command-line tools in Go using Cobra and Viper. Learn commands, subcommands, flags, configuration management, and distribution with real examples."
date: 2025-10-04T14:00:00+07:00
tags: ["Go", "CLI", "Cobra", "Viper", "Tutorial", "DevOps"]
draft: false
author: "Wiku Karno"
keywords: ["golang cli tutorial", "cobra viper go", "build cli tool golang", "go command line application", "cobra framework tutorial", "viper configuration go", "golang cli best practices"]
url: /2025/10/how-to-build-a-cli-tool-in-go-with-cobra-and-viper.html

faq:
  - question: "What's the difference between Cobra and Viper?"
    answer: "Cobra handles command structure - commands, subcommands, flags, and arguments. Viper handles configuration - reading from config files (YAML, JSON, TOML), environment variables, and command-line flags. They work great together: Cobra builds the CLI interface, Viper manages the settings."

  - question: "Do I need both Cobra and Viper for a simple CLI tool?"
    answer: "Not always. For simple CLIs with just a few flags, you can use Go's built-in flag package or just Cobra. Viper becomes useful when you need config files, multiple environments (dev/staging/prod), or want users to configure your tool with YAML/JSON instead of passing dozens of flags."

  - question: "How do I distribute my CLI tool to users?"
    answer: "Cross-compile binaries for different platforms (Linux, macOS, Windows) using Go's built-in cross-compilation. Upload to GitHub releases, or use tools like GoReleaser for automatic builds. For easier distribution, publish to package managers like Homebrew (macOS), apt/yum (Linux), or Chocolatey (Windows)."

  - question: "Can I build interactive CLIs with Cobra?"
    answer: "Yes, but Cobra itself doesn't handle interactivity. Combine it with libraries like survey, promptui, or bubbletea for interactive prompts, menus, and TUI (text user interface). Cobra handles the command structure, these libraries handle user interaction."

  - question: "How do I test CLI commands in Go?"
    answer: "Test commands by calling their Execute functions directly with test inputs. Use buffers to capture stdout/stderr instead of printing to console. Set custom args using command.SetArgs() and verify outputs. Cobra makes testing easy because commands are just functions with clear inputs and outputs."

  - question: "What's the best way to handle configuration priority?"
    answer: "Follow this priority order (highest to lowest): command-line flags -> environment variables -> config file -> default values. Viper handles this automatically. Users can override config file settings with env vars, and override everything with explicit flags. This gives flexibility while maintaining sensible defaults."

  - question: "How do I add auto-completion for my CLI tool?"
    answer: "Cobra has built-in completion generation for bash, zsh, fish, and PowerShell. Just add a completion command that generates the completion script. Users run your-cli completion bash > /etc/bash_completion.d/your-cli and get tab completion for all commands and flags automatically."
---

I've built a lot of CLI tools over the years - deployment scripts, database migration tools, log analyzers, you name it. Every time I start a new one, I reach for Cobra and Viper. Not because they're trendy (though they are), but because they solve the boring parts so I can focus on what my tool actually does.

Think about kubectl, hugo, gh (GitHub CLI) - all built with Cobra. There's a reason for that. Cobra gives you a clean command structure, automatic help generation, flag parsing, and all the stuff you'd otherwise spend hours implementing. Viper adds configuration management so users can configure your tool however they want - config files, environment variables, flags, whatever.

I'll show you how to build a real CLI tool from scratch. Not a toy example, but something you'd actually use in production. We'll build a task manager CLI with commands, subcommands, persistent storage, configuration, and everything you need to distribute it to users.

## Why Cobra and Viper?

**Cobra** handles the structure of your CLI - commands, subcommands, flags, arguments. Without it, you'd write a mess of switch statements parsing os.Args and handling help text manually. Ever tried parsing command-line flags by hand? It's tedious and error-prone.

**Viper** manages configuration. It reads from config files (YAML, JSON, TOML), environment variables, and flags. The best part - it handles priority automatically. Flags override env vars, env vars override config files, config files override defaults. No manual priority checking needed.

What you get with these libraries: automatic help generation, type-safe flag parsing, config file support, environment variable binding, defaults with overrides, input validation, and shell completion scripts. All the boring CLI stuff handled for you.

Go's standard library has a flag package, but it's limited. Fine for quick scripts, painful for real tools. Cobra and Viper are battle-tested - Kubernetes, Docker, and GitHub CLI all use them. If it's good enough for kubectl, it's good enough for your project.

## Understanding CLI Tool Structure

Good CLI tools follow conventions. Look at git, docker, or kubectl - they all share patterns:

```bash
# Root command with global flags
mytool --config=/path/to/config

# Subcommands for different actions
mytool create task
mytool list tasks
mytool delete task 123

# Flags at different levels
mytool --verbose create task --priority=high
```

This structure makes CLIs discoverable. Users don't need to memorize everything - they can explore with `--help` at any level.

**Root Command** is your main executable. It might do something by default, or just show help and available subcommands.

**Subcommands** are actions your tool can perform. Think `git commit`, `docker build`, `kubectl apply`. Each subcommand can have its own flags and logic.

**Flags** are options that modify behavior. They come in two types:
- **Persistent flags**: Available to all subcommands (like `--config` or `--verbose`)
- **Local flags**: Only available to specific commands (like `--priority` for creating tasks)

**Arguments** are positional values after the command and flags. Like the task ID in `mytool delete 123`.

Cobra makes this structure natural to build.

## Project Setup

Let's build a task manager CLI called `tasker`. It'll let users create, list, update, and delete tasks from the command line. Tasks will be stored locally, and users can configure behavior with a YAML file.

Create your project:

```bash
mkdir tasker
cd tasker
go mod init github.com/yourusername/tasker
```

Install Cobra and Viper:

```bash
go get -u github.com/spf13/cobra@latest
go get -u github.com/spf13/viper@latest
```

Cobra has a generator to scaffold CLI apps, but I'll show you the manual way so you understand what's happening:

```bash
tasker/
├── cmd/
│   ├── root.go          # Root command
│   ├── create.go        # Create task command
│   ├── list.go          # List tasks command
│   ├── delete.go        # Delete task command
│   └── update.go        # Update task command
├── internal/
│   ├── task/
│   │   └── task.go      # Task model and storage
│   └── config/
│       └── config.go    # Configuration handling
├── main.go
└── .tasker.yaml         # Example config file
```

This structure separates commands from business logic. Commands live in `cmd/`, actual functionality in `internal/`.

## Building the Root Command

The root command is your CLI's entry point. Create `cmd/root.go`:

```go
// cmd/root.go
package cmd

import (
    "fmt"
    "os"

    "github.com/spf13/cobra"
    "github.com/spf13/viper"
)

var (
    cfgFile string
    verbose bool
)

// rootCmd represents the base command
var rootCmd = &cobra.Command{
    Use:   "tasker",
    Short: "A simple task manager CLI",
    Long: `Tasker is a command-line task manager that helps you organize
your work. Create tasks, set priorities, mark them complete, and
stay productive from your terminal.`,
    Run: func(cmd *cobra.Command, args []string) {
        // If called without subcommands, show help
        cmd.Help()
    },
}

// Execute runs the root command
func Execute() {
    if err := rootCmd.Execute(); err != nil {
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}

func init() {
    // Run before any command executes
    cobra.OnInitialize(initConfig)

    // Persistent flags available to all subcommands
    rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.tasker.yaml)")
    rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")

    // Bind flags to viper
    viper.BindPFlag("verbose", rootCmd.PersistentFlags().Lookup("verbose"))
}

func initConfig() {
    if cfgFile != "" {
        // Use config file from flag
        viper.SetConfigFile(cfgFile)
    } else {
        // Search for config in home directory
        home, err := os.UserHomeDir()
        if err != nil {
            fmt.Fprintln(os.Stderr, err)
            os.Exit(1)
        }

        viper.AddConfigPath(home)
        viper.SetConfigType("yaml")
        viper.SetConfigName(".tasker")
    }

    // Read environment variables
    viper.AutomaticEnv()

    // Read config file if it exists
    if err := viper.ReadInConfig(); err == nil {
        if viper.GetBool("verbose") {
            fmt.Println("Using config file:", viper.ConfigFileUsed())
        }
    }
}
```

Let's break this down:

**rootCmd** defines the command structure. `Use` is the command name, `Short` and `Long` are help text, `Run` is what executes when someone runs `tasker` without subcommands.

**Execute()** is called from main.go. It starts the command execution chain.

**init()** runs when the package loads. We set up persistent flags here - flags available to all subcommands.

**initConfig()** loads configuration from files and environment variables. Viper checks the config file location, reads it if it exists, and makes values available throughout the app.

Now create `main.go`:

```go
// main.go
package main

import "github.com/yourusername/tasker/cmd"

func main() {
    cmd.Execute()
}
```

That's it. Main just calls Execute(). All logic lives in cmd/.

Test it:

```bash
go run main.go
# Shows help text with available commands

go run main.go --help
# Same thing, explicit help flag
```

## Task Model and Storage

Before building commands, we need a task model and storage. Keep it simple - store tasks in a JSON file. Create `internal/task/task.go`:

```go
// internal/task/task.go
package task

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "time"
)

type Task struct {
    ID        int       `json:"id"`
    Title     string    `json:"title"`
    Priority  string    `json:"priority"`
    Completed bool      `json:"completed"`
    CreatedAt time.Time `json:"created_at"`
}

type Storage struct {
    filepath string
    tasks    []Task
}

// NewStorage creates a new storage instance
func NewStorage() (*Storage, error) {
    home, err := os.UserHomeDir()
    if err != nil {
        return nil, err
    }

    filepath := filepath.Join(home, ".tasker-data.json")

    s := &Storage{
        filepath: filepath,
        tasks:    []Task{},
    }

    // Load existing tasks if file exists
    if err := s.load(); err != nil && !os.IsNotExist(err) {
        return nil, err
    }

    return s, nil
}

// load reads tasks from disk
func (s *Storage) load() error {
    data, err := os.ReadFile(s.filepath)
    if err != nil {
        return err
    }

    return json.Unmarshal(data, &s.tasks)
}

// save writes tasks to disk
func (s *Storage) save() error {
    data, err := json.MarshalIndent(s.tasks, "", "  ")
    if err != nil {
        return err
    }

    return os.WriteFile(s.filepath, data, 0644)
}

// Create adds a new task
func (s *Storage) Create(title, priority string) (*Task, error) {
    // Generate ID
    id := 1
    if len(s.tasks) > 0 {
        id = s.tasks[len(s.tasks)-1].ID + 1
    }

    task := &Task{
        ID:        id,
        Title:     title,
        Priority:  priority,
        Completed: false,
        CreatedAt: time.Now(),
    }

    s.tasks = append(s.tasks, *task)

    if err := s.save(); err != nil {
        return nil, err
    }

    return task, nil
}

// List returns all tasks
func (s *Storage) List() []Task {
    return s.tasks
}

// Get returns a task by ID
func (s *Storage) Get(id int) (*Task, error) {
    for i := range s.tasks {
        if s.tasks[i].ID == id {
            return &s.tasks[i], nil
        }
    }
    return nil, fmt.Errorf("task %d not found", id)
}

// Delete removes a task
func (s *Storage) Delete(id int) error {
    for i := range s.tasks {
        if s.tasks[i].ID == id {
            s.tasks = append(s.tasks[:i], s.tasks[i+1:]...)
            return s.save()
        }
    }
    return fmt.Errorf("task %d not found", id)
}

// Update modifies a task
func (s *Storage) Update(id int, title, priority string, completed *bool) error {
    task, err := s.Get(id)
    if err != nil {
        return err
    }

    if title != "" {
        task.Title = title
    }
    if priority != "" {
        task.Priority = priority
    }
    if completed != nil {
        task.Completed = *completed
    }

    return s.save()
}
```

This gives us basic CRUD operations on tasks. In production, you'd use a real database, but JSON files work fine for CLI tools that don't need concurrent access.

## Building Create Command

Now let's build the command to create tasks. Create `cmd/create.go`:

```go
// cmd/create.go
package cmd

import (
    "fmt"

    "github.com/spf13/cobra"
    "github.com/yourusername/tasker/internal/task"
)

var (
    priority string
)

var createCmd = &cobra.Command{
    Use:   "create [title]",
    Short: "Create a new task",
    Long: `Create a new task with the specified title.
You can optionally set the priority using the --priority flag.`,
    Args: cobra.ExactArgs(1), // Require exactly one argument
    Run: func(cmd *cobra.Command, args []string) {
        title := args[0]

        // Create storage
        storage, err := task.NewStorage()
        if err != nil {
            fmt.Println("Error:", err)
            return
        }

        // Create task
        t, err := storage.Create(title, priority)
        if err != nil {
            fmt.Println("Error creating task:", err)
            return
        }

        fmt.Printf("Created task #%d: %s (priority: %s)\n", t.ID, t.Title, t.Priority)
    },
}

func init() {
    // Add create command to root
    rootCmd.AddCommand(createCmd)

    // Local flag only for create command
    createCmd.Flags().StringVarP(&priority, "priority", "p", "medium", "Task priority (low, medium, high)")
}
```

**Args: cobra.ExactArgs(1)** validates that exactly one argument is provided. Cobra has built-in validators: `ExactArgs(n)`, `MinimumNArgs(n)`, `MaximumNArgs(n)`, `RangeArgs(min, max)`, `NoArgs`.

**args[0]** is the task title from the command line.

**Local flags** using `createCmd.Flags()` are only available for this command. Compare with `rootCmd.PersistentFlags()` which are available everywhere.

Test it:

```bash
go run main.go create "Finish OAuth2 article" --priority=high
# Created task #1: Finish OAuth2 article (priority: high)

go run main.go create "Review pull requests" -p low
# Created task #2: Review pull requests (priority: low)
```

## Building List Command

Create `cmd/list.go`:

```go
// cmd/list.go
package cmd

import (
    "fmt"
    "os"
    "text/tabwriter"
    "time"

    "github.com/spf13/cobra"
    "github.com/yourusername/tasker/internal/task"
)

var (
    showCompleted bool
)

var listCmd = &cobra.Command{
    Use:   "list",
    Short: "List all tasks",
    Long:  `Display all tasks in a formatted table.`,
    Run: func(cmd *cobra.Command, args []string) {
        storage, err := task.NewStorage()
        if err != nil {
            fmt.Println("Error:", err)
            return
        }

        tasks := storage.List()

        if len(tasks) == 0 {
            fmt.Println("No tasks found. Create one with: tasker create <title>")
            return
        }

        // Use tabwriter for aligned output
        w := tabwriter.NewWriter(os.Stdout, 0, 0, 3, ' ', 0)
        fmt.Fprintln(w, "ID\tTITLE\tPRIORITY\tSTATUS\tCREATED")
        fmt.Fprintln(w, "──\t─────\t────────\t──────\t───────")

        for _, t := range tasks {
            // Skip completed tasks unless flag is set
            if t.Completed && !showCompleted {
                continue
            }

            status := "pending"
            if t.Completed {
                status = "done"
            }

            created := t.CreatedAt.Format("2006-01-02")

            fmt.Fprintf(w, "%d\t%s\t%s\t%s\t%s\n",
                t.ID, t.Title, t.Priority, status, created)
        }

        w.Flush()
    },
}

func init() {
    rootCmd.AddCommand(listCmd)

    listCmd.Flags().BoolVarP(&showCompleted, "all", "a", false, "Show completed tasks")
}
```

**tabwriter** is a standard library package that aligns columns nicely. Much better than manually spacing text.

Test it:

```bash
go run main.go list
# ID   TITLE                      PRIORITY   STATUS    CREATED
# ──   ─────                      ────────   ──────    ───────
# 1    Finish OAuth2 article      high       pending   2025-10-04
# 2    Review pull requests       low        pending   2025-10-04
```

## Building Delete Command

Create `cmd/delete.go`:

```go
// cmd/delete.go
package cmd

import (
    "fmt"
    "strconv"

    "github.com/spf13/cobra"
    "github.com/yourusername/tasker/internal/task"
)

var deleteCmd = &cobra.Command{
    Use:   "delete [id]",
    Short: "Delete a task",
    Long:  `Delete a task by its ID.`,
    Args:  cobra.ExactArgs(1),
    Run: func(cmd *cobra.Command, args []string) {
        id, err := strconv.Atoi(args[0])
        if err != nil {
            fmt.Println("Error: ID must be a number")
            return
        }

        storage, err := task.NewStorage()
        if err != nil {
            fmt.Println("Error:", err)
            return
        }

        // Get task first to show what we're deleting
        t, err := storage.Get(id)
        if err != nil {
            fmt.Println("Error:", err)
            return
        }

        if err := storage.Delete(id); err != nil {
            fmt.Println("Error deleting task:", err)
            return
        }

        fmt.Printf("Deleted task #%d: %s\n", id, t.Title)
    },
}

func init() {
    rootCmd.AddCommand(deleteCmd)
}
```

Test it:

```bash
go run main.go delete 2
# Deleted task #2: Review pull requests
```

## Building Update Command

Create `cmd/update.go`:

```go
// cmd/update.go
package cmd

import (
    "fmt"
    "strconv"

    "github.com/spf13/cobra"
    "github.com/yourusername/tasker/internal/task"
)

var (
    updateTitle    string
    updatePriority string
    markComplete   bool
)

var updateCmd = &cobra.Command{
    Use:   "update [id]",
    Short: "Update a task",
    Long:  `Update task properties like title, priority, or completion status.`,
    Args:  cobra.ExactArgs(1),
    Run: func(cmd *cobra.Command, args []string) {
        id, err := strconv.Atoi(args[0])
        if err != nil {
            fmt.Println("Error: ID must be a number")
            return
        }

        storage, err := task.NewStorage()
        if err != nil {
            fmt.Println("Error:", err)
            return
        }

        // Check if task exists
        _, err = storage.Get(id)
        if err != nil {
            fmt.Println("Error:", err)
            return
        }

        // Update only fields that were specified
        var completed *bool
        if cmd.Flags().Changed("complete") {
            completed = &markComplete
        }

        if err := storage.Update(id, updateTitle, updatePriority, completed); err != nil {
            fmt.Println("Error updating task:", err)
            return
        }

        fmt.Printf("Updated task #%d\n", id)
    },
}

func init() {
    rootCmd.AddCommand(updateCmd)

    updateCmd.Flags().StringVarP(&updateTitle, "title", "t", "", "New title")
    updateCmd.Flags().StringVarP(&updatePriority, "priority", "p", "", "New priority")
    updateCmd.Flags().BoolVarP(&markComplete, "complete", "c", false, "Mark as complete")
}
```

**cmd.Flags().Changed("complete")** checks if the flag was explicitly set. This lets us distinguish between "flag not provided" and "flag set to false". Important for boolean flags where false is a valid value.

Test it:

```bash
go run main.go update 1 --complete
# Updated task #1

go run main.go update 1 -t "Finish and publish OAuth2 article" -p high
# Updated task #1
```

## Configuration with Viper

Now let's add configuration support. Users can customize default priority, storage location, output format, etc. Create `.tasker.yaml` in your home directory:

```yaml
# ~/.tasker.yaml
defaults:
  priority: medium
  show_completed: false

storage:
  filepath: ~/.tasker-data.json

output:
  format: table  # table or json
  colors: true
```

Update `cmd/root.go` to use these configs:

```go
// cmd/root.go
func initConfig() {
    if cfgFile != "" {
        viper.SetConfigFile(cfgFile)
    } else {
        home, err := os.UserHomeDir()
        if err != nil {
            fmt.Fprintln(os.Stderr, err)
            os.Exit(1)
        }

        viper.AddConfigPath(home)
        viper.SetConfigType("yaml")
        viper.SetConfigName(".tasker")
    }

    // Set defaults
    viper.SetDefault("defaults.priority", "medium")
    viper.SetDefault("defaults.show_completed", false)
    viper.SetDefault("output.format", "table")
    viper.SetDefault("output.colors", true)

    // Bind environment variables with prefix
    viper.SetEnvPrefix("TASKER")
    viper.AutomaticEnv()

    if err := viper.ReadInConfig(); err == nil {
        if viper.GetBool("verbose") {
            fmt.Println("Using config file:", viper.ConfigFileUsed())
        }
    }
}
```

Now update create command to use config defaults:

```go
// cmd/create.go
func init() {
    rootCmd.AddCommand(createCmd)

    // Use viper default instead of hardcoded value
    createCmd.Flags().StringVarP(&priority, "priority", "p",
        viper.GetString("defaults.priority"), "Task priority")
}
```

Users can now override defaults in three ways:

```bash
# 1. Config file
# Set in ~/.tasker.yaml

# 2. Environment variable
export TASKER_DEFAULTS_PRIORITY=high
go run main.go create "Important task"

# 3. Command-line flag (highest priority)
go run main.go create "Urgent task" --priority=high
```

Viper handles the priority automatically: flags > env vars > config file > defaults.

## Adding JSON Output Format

Let's support JSON output for scripting. Update `cmd/list.go`:

```go
// cmd/list.go
import (
    "encoding/json"
    // ... other imports
)

var (
    showCompleted bool
    outputFormat  string
)

var listCmd = &cobra.Command{
    Use:   "list",
    Short: "List all tasks",
    Run: func(cmd *cobra.Command, args []string) {
        storage, err := task.NewStorage()
        if err != nil {
            fmt.Println("Error:", err)
            return
        }

        tasks := storage.List()

        if len(tasks) == 0 {
            if outputFormat != "json" {
                fmt.Println("No tasks found.")
            }
            return
        }

        // Filter completed tasks
        var filtered []task.Task
        for _, t := range tasks {
            if !t.Completed || showCompleted {
                filtered = append(filtered, t)
            }
        }

        // Output based on format
        switch outputFormat {
        case "json":
            data, _ := json.MarshalIndent(filtered, "", "  ")
            fmt.Println(string(data))
        default:
            printTable(filtered)
        }
    },
}

func printTable(tasks []task.Task) {
    w := tabwriter.NewWriter(os.Stdout, 0, 0, 3, ' ', 0)
    fmt.Fprintln(w, "ID\tTITLE\tPRIORITY\tSTATUS\tCREATED")
    fmt.Fprintln(w, "──\t─────\t────────\t──────\t───────")

    for _, t := range tasks {
        status := "pending"
        if t.Completed {
            status = "done"
        }
        created := t.CreatedAt.Format("2006-01-02")
        fmt.Fprintf(w, "%d\t%s\t%s\t%s\t%s\n",
            t.ID, t.Title, t.Priority, status, created)
    }

    w.Flush()
}

func init() {
    rootCmd.AddCommand(listCmd)

    listCmd.Flags().BoolVarP(&showCompleted, "all", "a", false, "Show completed tasks")
    listCmd.Flags().StringVarP(&outputFormat, "format", "f",
        viper.GetString("output.format"), "Output format (table, json)")
}
```

Now users can pipe output to other tools:

```bash
go run main.go list --format=json | jq '.[] | select(.priority == "high")'
```

## Input Validation

Add validation to prevent invalid data. Update `cmd/create.go`:

```go
// cmd/create.go
var createCmd = &cobra.Command{
    Use:   "create [title]",
    Short: "Create a new task",
    Args:  cobra.ExactArgs(1),
    PreRunE: func(cmd *cobra.Command, args []string) error {
        // Validate priority
        validPriorities := map[string]bool{
            "low": true, "medium": true, "high": true,
        }

        if !validPriorities[priority] {
            return fmt.Errorf("invalid priority '%s'. Must be: low, medium, or high", priority)
        }

        // Validate title length
        if len(args[0]) < 3 {
            return fmt.Errorf("title must be at least 3 characters")
        }

        return nil
    },
    Run: func(cmd *cobra.Command, args []string) {
        // ... existing code
    },
}
```

**PreRunE** runs before the main Run function. Return an error to abort execution. There's also **PostRunE** that runs after.

Test validation:

```bash
go run main.go create "ab"
# Error: title must be at least 3 characters

go run main.go create "Test task" --priority=urgent
# Error: invalid priority 'urgent'. Must be: low, medium, or high
```

## Shell Completion

Cobra can generate completion scripts for bash, zsh, fish, and PowerShell. Add a completion command:

```go
// cmd/completion.go
package cmd

import (
    "os"

    "github.com/spf13/cobra"
)

var completionCmd = &cobra.Command{
    Use:   "completion [bash|zsh|fish|powershell]",
    Short: "Generate shell completion script",
    Long: `Generate shell completion script for tasker.

To load completions:

Bash:
  $ source <(tasker completion bash)
  # To load permanently:
  $ tasker completion bash > /etc/bash_completion.d/tasker

Zsh:
  $ source <(tasker completion zsh)
  # To load permanently:
  $ tasker completion zsh > "${fpath[1]}/_tasker"

Fish:
  $ tasker completion fish | source
  # To load permanently:
  $ tasker completion fish > ~/.config/fish/completions/tasker.fish

PowerShell:
  PS> tasker completion powershell | Out-String | Invoke-Expression
`,
    Args: cobra.ExactArgs(1),
    Run: func(cmd *cobra.Command, args []string) {
        switch args[0] {
        case "bash":
            cmd.Root().GenBashCompletion(os.Stdout)
        case "zsh":
            cmd.Root().GenZshCompletion(os.Stdout)
        case "fish":
            cmd.Root().GenFishCompletion(os.Stdout, true)
        case "powershell":
            cmd.Root().GenPowerShellCompletion(os.Stdout)
        }
    },
}

func init() {
    rootCmd.AddCommand(completionCmd)
}
```

Users can now install tab completion:

```bash
# Bash
tasker completion bash > /etc/bash_completion.d/tasker

# Now they can tab-complete
tasker cr<TAB>     # completes to "create"
tasker list --<TAB> # shows all available flags
```

## Building and Distribution

Build your CLI for distribution:

```bash
# Build for current platform
go build -o tasker

# Cross-compile for other platforms
GOOS=linux GOARCH=amd64 go build -o tasker-linux-amd64
GOOS=darwin GOARCH=amd64 go build -o tasker-darwin-amd64
GOOS=darwin GOARCH=arm64 go build -o tasker-darwin-arm64
GOOS=windows GOARCH=amd64 go build -o tasker-windows-amd64.exe
```

For production releases, use **GoReleaser**. Create `.goreleaser.yaml`:

```yaml
project_name: tasker

builds:
  - env:
      - CGO_ENABLED=0
    goos:
      - linux
      - darwin
      - windows
    goarch:
      - amd64
      - arm64
    ignore:
      - goos: windows
        goarch: arm64

archives:
  - format: tar.gz
    name_template: >-
      {{ .ProjectName }}_
      {{- .Version }}_
      {{- .Os }}_
      {{- .Arch }}
    format_overrides:
      - goos: windows
        format: zip

checksum:
  name_template: 'checksums.txt'

changelog:
  sort: asc
```

Install GoReleaser:

```bash
brew install goreleaser
```

Create a release:

```bash
# Tag your version
git tag -a v1.0.0 -m "First release"
git push origin v1.0.0

# Build and release
goreleaser release
```

GoReleaser builds binaries for all platforms, creates GitHub releases, generates checksums, and publishes everything automatically.

## Testing CLI Commands

Test commands by calling them directly. Create `cmd/create_test.go`:

```go
// cmd/create_test.go
package cmd

import (
    "bytes"
    "os"
    "testing"
)

func TestCreateCommand(t *testing.T) {
    // Redirect stdout to capture output
    old := os.Stdout
    r, w, _ := os.Pipe()
    os.Stdout = w

    // Set test args
    rootCmd.SetArgs([]string{"create", "Test task", "--priority=high"})

    // Execute command
    err := rootCmd.Execute()
    if err != nil {
        t.Fatalf("Expected no error, got %v", err)
    }

    // Read output
    w.Close()
    os.Stdout = old
    var buf bytes.Buffer
    buf.ReadFrom(r)
    output := buf.String()

    // Verify output
    if !bytes.Contains([]byte(output), []byte("Created task")) {
        t.Errorf("Expected success message, got: %s", output)
    }

    // Clean up test data
    os.Remove(os.ExpandEnv("$HOME/.tasker-data.json"))
}
```

Run tests:

```bash
go test ./cmd/...
```

For integration with existing tools, you might want to build REST APIs alongside your CLI. Check out [how to build REST APIs with Gin framework](/2025/09/building-rest-api-gin-framework-golang-production-ready.html) for creating web interfaces to your tools.

## Advanced Features

**Custom Validators** for complex validation:

```go
func validateTaskID(cmd *cobra.Command, args []string) error {
    id, err := strconv.Atoi(args[0])
    if err != nil {
        return fmt.Errorf("ID must be a number")
    }
    if id < 1 {
        return fmt.Errorf("ID must be positive")
    }
    return nil
}

var deleteCmd = &cobra.Command{
    Args: validateTaskID,
    // ...
}
```

**Command Aliases** for convenience:

```go
var listCmd = &cobra.Command{
    Use:     "list",
    Aliases: []string{"ls", "l"},
    // ...
}
```

Now `tasker list`, `tasker ls`, and `tasker l` all work.

**Dynamic Completion** for smarter autocomplete:

```go
func taskIDCompletion(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
    storage, _ := task.NewStorage()
    tasks := storage.List()

    var completions []string
    for _, t := range tasks {
        completions = append(completions, fmt.Sprintf("%d\t%s", t.ID, t.Title))
    }

    return completions, cobra.ShellCompDirectiveNoFileComp
}

var deleteCmd = &cobra.Command{
    ValidArgsFunction: taskIDCompletion,
    // ...
}
```

Tab completion now shows actual task IDs and titles.

## Real-World Example: DevOps Tool

Let's build something more practical - a deployment tool. It reads service configs, connects to servers, and deploys applications:

```go
// cmd/deploy.go
package cmd

import (
    "fmt"
    "os/exec"

    "github.com/spf13/cobra"
    "github.com/spf13/viper"
)

var (
    environment string
    dryRun     bool
)

var deployCmd = &cobra.Command{
    Use:   "deploy [service]",
    Short: "Deploy a service to specified environment",
    Args:  cobra.ExactArgs(1),
    PreRunE: func(cmd *cobra.Command, args []string) error {
        // Validate environment
        validEnvs := []string{"dev", "staging", "production"}
        for _, env := range validEnvs {
            if environment == env {
                return nil
            }
        }
        return fmt.Errorf("invalid environment: %s", environment)
    },
    Run: func(cmd *cobra.Command, args []string) {
        service := args[0]

        // Load service config from viper
        host := viper.GetString(fmt.Sprintf("services.%s.%s.host", service, environment))
        port := viper.GetInt(fmt.Sprintf("services.%s.%s.port", service, environment))
        dockerImage := viper.GetString(fmt.Sprintf("services.%s.image", service))

        if host == "" {
            fmt.Printf("Service %s not configured for %s\n", service, environment)
            return
        }

        fmt.Printf("Deploying %s to %s...\n", service, environment)
        fmt.Printf("Host: %s:%d\n", host, port)
        fmt.Printf("Image: %s\n", dockerImage)

        if dryRun {
            fmt.Println("Dry run - no changes made")
            return
        }

        // Execute deployment
        cmd := exec.Command("ssh", host,
            fmt.Sprintf("docker pull %s && docker-compose up -d", dockerImage))

        output, err := cmd.CombinedOutput()
        if err != nil {
            fmt.Printf("Deployment failed: %v\n%s\n", err, output)
            return
        }

        fmt.Println("Deployment successful")
    },
}

func init() {
    rootCmd.AddCommand(deployCmd)

    deployCmd.Flags().StringVarP(&environment, "env", "e", "dev", "Deployment environment")
    deployCmd.Flags().BoolVar(&dryRun, "dry-run", false, "Show what would be deployed without deploying")
}
```

Config file `.deployer.yaml`:

```yaml
services:
  api:
    image: mycompany/api:latest
    dev:
      host: dev.mycompany.com
      port: 8080
    staging:
      host: staging.mycompany.com
      port: 8080
    production:
      host: prod.mycompany.com
      port: 8080

  frontend:
    image: mycompany/frontend:latest
    dev:
      host: dev.mycompany.com
      port: 3000
    staging:
      host: staging.mycompany.com
      port: 3000
    production:
      host: prod.mycompany.com
      port: 3000
```

Usage:

```bash
deployer deploy api --env=production
# Deploying api to production...
# Host: prod.mycompany.com:8080
# Image: mycompany/api:latest
# Deployment successful

deployer deploy frontend --env=staging --dry-run
# Dry run - no changes made
```

## Integration with Other Systems

CLI tools often need to interact with APIs. For authentication, implement [JWT authentication](/2025/08/how-to-implement-jwt-authentication-in-go-secure-rest-api.html) to secure your API calls. For file operations, check out [uploading files to AWS S3](/2025/10/how-to-upload-files-to-aws-s3-in-go-with-sdk-v2.html) for cloud storage integration.

If your CLI needs caching, use [Redis for session management](/2025/08/how-to-use-redis-with-go-caching-session-management.html) to speed up repeated operations.

## Error Handling Best Practices

Good error messages make CLIs usable. Bad ones frustrate users:

```go
// Bad - generic error
if err != nil {
    fmt.Println("Error:", err)
    return
}

// Good - actionable error
if err != nil {
    fmt.Printf("Failed to connect to %s: %v\n", host, err)
    fmt.Println("Check your network connection and try again")
    return
}
```

Wrap errors with context:

```go
import "fmt"

func loadConfig() error {
    if err := viper.ReadInConfig(); err != nil {
        return fmt.Errorf("failed to load config from %s: %w",
            viper.ConfigFileUsed(), err)
    }
    return nil
}
```

Use exit codes for scripting:

```go
var rootCmd = &cobra.Command{
    Run: func(cmd *cobra.Command, args []string) {
        if err := doSomething(); err != nil {
            fmt.Fprintln(os.Stderr, err)
            os.Exit(1) // Non-zero exit code signals failure
        }
        os.Exit(0) // Zero means success
    },
}
```

Scripts can check exit codes:

```bash
if tasker create "Test"; then
    echo "Success"
else
    echo "Failed"
fi
```

## Color and Styling

Add color to make output readable. Use the `fatih/color` package:

```go
import "github.com/fatih/color"

// Define colors
var (
    successColor = color.New(color.FgGreen, color.Bold)
    errorColor   = color.New(color.FgRed, color.Bold)
    warnColor    = color.New(color.FgYellow)
)

// Use in commands
successColor.Println("Task created successfully")
errorColor.Printf("Failed to connect to server: %v\n", err)
warnColor.Println("Warning: Config file not found, using defaults")
```

Respect the user's environment:

```go
// Check if colors should be disabled
if viper.GetBool("output.colors") && color.NoColor {
    color.NoColor = false
} else if !viper.GetBool("output.colors") {
    color.NoColor = true
}
```

Users can disable colors:

```bash
# In config
output:
  colors: false

# Or environment variable
NO_COLOR=1 tasker list
```

## Logging and Debugging

Add verbose mode for debugging. Update `cmd/root.go`:

```go
import "log"

var rootCmd = &cobra.Command{
    PersistentPreRun: func(cmd *cobra.Command, args []string) {
        if verbose {
            log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
            log.Println("Verbose mode enabled")
            log.Printf("Config file: %s\n", viper.ConfigFileUsed())
        } else {
            log.SetFlags(0)
            log.SetOutput(io.Discard)
        }
    },
}
```

Use throughout your code:

```go
func deploy(service string) error {
    log.Printf("Starting deployment of %s\n", service)

    config := loadServiceConfig(service)
    log.Printf("Loaded config: %+v\n", config)

    // ... deployment logic

    log.Println("Deployment completed successfully")
    return nil
}
```

Only shows when `--verbose` is set:

```bash
tasker deploy api --verbose
# 2025/10/04 14:30:00 deploy.go:15: Starting deployment of api
# 2025/10/04 14:30:01 deploy.go:18: Loaded config: {Host:prod.mycompany.com Port:8080}
# 2025/10/04 14:30:05 deploy.go:23: Deployment completed successfully
```

## Conclusion

You've built a complete CLI tool with commands, subcommands, flags, configuration, validation, completion, and distribution. Cobra handles the command structure, Viper manages configuration, and you wrote the actual functionality.

The patterns here scale from simple scripts to complex tools. kubectl has hundreds of commands but follows the same structure. GitHub CLI has dozens of subcommands with their own flags. All built with Cobra.

Key takeaways: structure your commands logically, validate inputs early, make errors actionable, support configuration files for complex tools, generate completion scripts for better UX, and cross-compile for easy distribution.

CLI tools are powerful because they compose. Users pipe them together, script them, automate with them. Build tools that do one thing well, accept standard input/output, and follow conventions. Your tools will fit naturally into developers' workflows.

The code we built is production-ready. Add tests, CI/CD for releases with GoReleaser, and publish to package managers. Users will appreciate a well-built CLI that respects their time and follows best practices.
