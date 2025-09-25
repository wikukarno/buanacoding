---
title: 'Read, Write, and Manage Files'
date: 2025-04-29T10:00:00.000+07:00
draft: false
url: /2025/04/file-handling-in-go-read-write-and.html
tags: 
- Go
description: "Learn how to handle files in Go: create, read, write, append, and manage directories."
keywords: ["Go", "file", "handling", "read", "write", "append", "directory", "management"]
---

In Go, file handling is straightforward and powerful. You can create, read, write, and manage files using standard packages like `os`, `io`, and `ioutil` (deprecated but still common). Understanding how to work with files is essential when building CLI tools, web servers, or any application that deals with local data.

In this article, you’ll learn:

*   How to create and write to a file
*   How to read a file
*   Appending data to files
*   Working with directories
*   Checking if a file exists
*   Best practices and error handling

Creating and Writing to a File
------------------------------

To create and write content to a file:

```go
func main() {
    content := []byte("Hello, file!")

    err := os.WriteFile("example.txt", content, 0644)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println("File written successfully")
} 
```

`os.WriteFile` creates the file if it doesn't exist and replaces it if it does.

Reading a File
--------------

To read the entire content of a file:

```go
func main() {
    data, err := os.ReadFile("example.txt")
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println("File content:", string(data))
} 
```

Appending to a File
-------------------

If you want to add content to an existing file without overwriting it:

```go
func main() {
    f, err := os.OpenFile("example.txt", os.O_APPEND|os.O_WRONLY, 0644)
    if err != nil {
        log.Fatal(err)
    }
    defer f.Close()

    if _, err := f.WriteString("\nThis is appended."); err != nil {
        log.Fatal(err)
    }

    fmt.Println("Appended successfully")
} 
```

Working with Directories
------------------------

### Create a new folder:

```go
err := os.Mkdir("myfolder", 0755)
```

### Create nested folders:

```go
err := os.MkdirAll("path/to/folder", 0755)
```

### List files in a folder:

```go
files, err := os.ReadDir(".")
for _, file := range files {
    fmt.Println(file.Name())
} 
```

Check if a File Exists
----------------------

```go
func fileExists(filename string) bool {
    _, err := os.Stat(filename)
    return !os.IsNotExist(err)
} 
```

Deleting a File or Folder
-------------------------

```go
err := os.Remove("example.txt")              // delete file
err := os.RemoveAll("path/to/folder")        // delete folder and contents 
```

Best Practices
--------------

*   Always handle file errors (file not found, permissions)
*   Use `defer f.Close()` after opening files
*   Use `os.ReadFile` and `os.WriteFile` for simple tasks
*   Use buffered I/O (like `bufio`) for large files

Conclusion
----------

File handling in Go is clean and efficient. Whether you're reading logs, saving data, or managing folders, the standard library provides everything you need. Understanding how to work with files opens the door to building robust and real-world applications in Go.

Next, we’ll look into working with JSON in Go — another essential skill for building APIs and storing structured data.

Happy coding!