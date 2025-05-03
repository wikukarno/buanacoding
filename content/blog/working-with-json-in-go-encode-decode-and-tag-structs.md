---
title: 'Working with JSON in Go: Encode, Decode, and Tag Structs'
date: 2025-04-30T10:00:00.001+07:00
draft: false
url: /2025/04/working-with-json-in-go-encode-decode.html
tags: 
- Go
---

JSON (JavaScript Object Notation) is a widely used data format in APIs and web applications. Go provides strong support for JSON through the standard `encoding/json` package. In this article, you’ll learn how to parse JSON into structs, generate JSON from Go data, use struct tags, and work with nested or dynamic structures.

In this article, you’ll learn:

*   How to encode Go structs to JSON
*   How to decode JSON into Go structs
*   Using JSON tags to customize field names
*   Working with maps and dynamic JSON
*   Handling nested JSON structures
*   Best practices and error handling

Encoding Structs to JSON
------------------------

Use `json.Marshal` to convert Go structs into JSON strings:

```
type User struct {
    Name  string `json:"name"`
    Email string `json:"email"`
    Age   int    `json:"age"`
}

func main() {
    user := User{"Alice", "alice@example.com", 30}

    jsonData, err := json.Marshal(user)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println(string(jsonData))
} 
```

Decoding JSON into Structs
--------------------------

Use `json.Unmarshal` to parse JSON into a struct:

```
var jsonInput = []byte(`{"name":"Bob","email":"bob@example.com","age":25}`)

var user User
err := json.Unmarshal(jsonInput, &user)
if err != nil {
    log.Fatal(err)
}

fmt.Println(user.Name, user.Email, user.Age) 
```

Using Struct Tags
-----------------

By default, Go uses struct field names as JSON keys. Use tags to customize:

```
type Product struct {
    ID    int     `json:"id"`
    Name  string  `json:"name"`
    Price float64 `json:"price"`
} 
```

Working with Maps and Dynamic JSON
----------------------------------

Use `map[string]interface{}` when the structure is not fixed:

```
var data = []byte(`{"status":"ok","code":200}`)

var result map[string]interface{}
err := json.Unmarshal(data, &result)
if err != nil {
    log.Fatal(err)
}

fmt.Println(result["status"], result["code"]) 
```

Nested JSON Example
-------------------

```
type Address struct {
    City    string `json:"city"`
    Country string `json:"country"`
}

type Employee struct {
    Name    string  `json:"name"`
    Address Address `json:"address"`
} 
```

JSON:

```
 {
  "name": "John",
  "address": {
    "city": "Jakarta",
    "country": "Indonesia"
  }
} 
```

Encode JSON to File
-------------------

```
f, err := os.Create("data.json")
if err != nil {
    log.Fatal(err)
}
defer f.Close()

json.NewEncoder(f).Encode(user) 
```

Decode JSON from File
---------------------

```
f, err := os.Open("data.json")
if err != nil {
    log.Fatal(err)
}
defer f.Close()

json.NewDecoder(f).Decode(&user) 
```

Best Practices
--------------

*   Always handle encoding/decoding errors
*   Use struct tags for clean JSON output
*   Validate incoming JSON before using
*   Use `omitempty` tag to skip empty fields

Conclusion
----------

Working with JSON in Go is simple, powerful, and type-safe. Whether you're building APIs, reading config files, or exchanging data between systems, the `encoding/json` package gives you everything you need.

Next, we’ll dive into building a REST API in Go using `net/http`.

Happy coding!