---
title: "How to Build a REST API in Go using net/http"
date: 2025-05-11T10:00:00.002+07:00
draft: false
url: /2025/05/how-to-build-rest-api-in-go-using-net-http.html
tags:
  - Go
description: "Learn how to build a REST API in Go using the net/http package. This guide covers the basics of setting up a server, handling requests, and returning JSON responses."
keywords: ["go", "golang", "rest api", "net/http", "json", "web development"]
---

Building a REST API in Go is one of the most practical ways to learn how Go handles HTTP servers, [JSON](https://www.buanacoding.com/2025/04/working-with-json-in-go-encode-decode.html), and struct-based logic. In this tutorial, you’ll learn how to create a simple RESTful API using the standard net/http package—without using any third-party frameworks. This is a great starting point before moving to more complex architectures.

In this guide, we’ll create a simple API for managing books. Each book will have an ID, title, and author.

## What You’ll Learn
  - How to create HTTP server routes in Go
  - How to handle GET, POST, PUT, and DELETE requests
  - How to encode and decode [JSON](https://www.buanacoding.com/2025/04/working-with-json-in-go-encode-decode.html) data
  - How to organize handlers and write clean code

### Step 1: Define a Book Struct
```go
package main

type Book struct {
    ID     string `json:"id"`
    Title  string `json:"title"`
    Author string `json:"author"`
}
```
We’ll use this struct to store data in memory.

### Step 2: Step 2: Create a Global Book Slice
```go
var books = []Book{
    {ID: "1", Title: "Go Basics", Author: "John Doe"},
    {ID: "2", Title: "Mastering Go", Author: "Jane Smith"},
}
```

### Step 3: Create Handlers

#### Get All Books
```go
func getBooks(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(books)
}
```

#### Get a Single Book
```go
func getBook(w http.ResponseWriter, r *http.Request) {
    id := strings.TrimPrefix(r.URL.Path, "/books/")
    for _, book := range books {
        if book.ID == id {
            json.NewEncoder(w).Encode(book)
            return
        }
    }
    http.NotFound(w, r)
}
```

#### Create a New Book
```go
func createBook(w http.ResponseWriter, r *http.Request) {
    var book Book
    json.NewDecoder(r.Body).Decode(&book)
    books = append(books, book)
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(book)
}
```

#### Update a Book
```go
func updateBook(w http.ResponseWriter, r *http.Request) {
    id := strings.TrimPrefix(r.URL.Path, "/books/")
    for i, book := range books {
        if book.ID == id {
            json.NewDecoder(r.Body).Decode(&books[i])
            w.WriteHeader(http.StatusOK)
            json.NewEncoder(w).Encode(books[i])
            return
        }
    }
    http.NotFound(w, r)
}
```

#### Delete a Book
```go
func deleteBook(w http.ResponseWriter, r *http.Request) {
    id := strings.TrimPrefix(r.URL.Path, "/books/")
    for i, book := range books {
        if book.ID == id {
            books = append(books[:i], books[i+1:]...)
            w.WriteHeader(http.StatusNoContent)
            return
        }
    }
    http.NotFound(w, r)
}
```

### Step 4: Set Up Routes
```go
func main() {
    http.HandleFunc("/books", getBooks)
    http.HandleFunc("/books/", func(w http.ResponseWriter, r *http.Request) {
        switch r.Method {
        case http.MethodGet:
            getBook(w, r)
        case http.MethodPost:
            createBook(w, r)
        case http.MethodPut:
            updateBook(w, r)
        case http.MethodDelete:
            deleteBook(w, r)
        default:
            http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        }
    })

    fmt.Println("Server running on http://localhost:8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

## Step 5: Run the Server
To run the server, save your code in a file named `main.go` and execute the following command in your terminal:
```bash
go run main.go
```
You should see the message `Server running on http://localhost:8080`.
You can now test your API using tools like Postman or curl.
### Step 6: Test the API
#### Get All Books
```bash
curl -X GET http://localhost:8080/books
```
#### Get a Single Book
```bash
curl -X GET http://localhost:8080/books/1
```
#### Create a New Book
```bash
curl -X POST http://localhost:8080/books \
-H "Content-Type: application/json" \
-d '{"id":"3", "title":"Learning Go", "author":"Alice Johnson"}'
```
#### Update a Book
```bash
curl -X PUT http://localhost:8080/books/1 \
-H "Content-Type: application/json" \
-d '{"id":"1", "title":"Go Basics Updated", "author":"John Doe"}'
```
#### Delete a Book
```bash
curl -X DELETE http://localhost:8080/books/1
```
### Conclusion
Congratulations! You’ve built a simple REST API in Go using the net/http package. This is just the beginning; you can extend this API by adding features like authentication, database integration, and more.
Feel free to explore the Go documentation and other resources to deepen your understanding of Go and RESTful APIs.

If you have any questions or need further assistance, don’t hesitate to ask. Happy coding!
## Additional Resources
- [Go Documentation](https://golang.org/doc/)
- [Go by Example](https://gobyexample.com/)
- [Building Web Applications in Go](https://golang.org/doc/articles/wiki/)
- [Repository](https://github.com/wikukarno/blog-source-code)