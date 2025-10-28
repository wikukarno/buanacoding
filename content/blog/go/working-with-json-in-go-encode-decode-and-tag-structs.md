---
title: "Working with JSON in Go - Encode and Decode"
date: 2025-04-30T10:00:00.001+07:00
draft: false
url: /2025/04/working-with-json-in-go-encode-decode.html
tags:
- Go
description: "Learn how to work with JSON in Go: encoding, decoding, and using struct tags."
keywords: ["Go", "JSON", "encoding", "decoding", "struct tags", "maps", "nested JSON"]
faq:
  - question: "Why are some of my struct fields not included when marshaling to JSON?"
    answer: "Only exported (capitalized) fields are marshaled--unexported fields ignored by encoding/json. Problem: type User struct { name string; email string }; json.Marshal(user)--outputs {}. Fields lowercase (unexported), invisible to reflection. Fix: capitalize: type User struct { Name string `json:\"name\"`; Email string `json:\"email\"` }--outputs {\"name\":\"Alice\",\"email\":\"alice@example.com\"}. Tag `json:\"name\"` maps exported Name to lowercase JSON key. Why: Go's reflection can't access unexported fields from other packages--encoding/json in stdlib, your struct in main, can't see private fields. Security benefit: sensitive fields stay private: type User struct { Name string; password string }--password never marshaled. Omitting fields: use tag `json:\"-\"` to explicitly exclude exported field: type User struct { Password string `json:\"-\"` }--never marshaled even though exported. Debugging: if field missing from JSON: (1) Check capitalization: name -> Name. (2) Check tag: `json:\"user_name\"` means key is user_name not Name. (3) Check zero value with omitempty: Name string `json:\"name,omitempty\"`--empty string omitted. Print struct before marshal: fmt.Printf(\"%+v\", user)--verify field has value. Common mistakes: (1) Forgot to capitalize after copy-paste from JSON schema. (2) Tag typo: `josn:\"name\"`--silently uses default field name. (3) Embedded unexported struct: fields not promoted. Best practice: always export fields for marshaling, use tags for naming, use `-` to explicitly exclude."
  - question: "What's the difference between omitempty and pointer fields for handling optional JSON fields?"
    answer: "omitempty omits zero values (empty string, 0, false, nil), pointers distinguish zero from absent--choose based on whether zero is meaningful. omitempty: type User struct { Name string `json:\"name,omitempty\"`; Age int `json:\"age,omitempty\"` }. Behavior: Age=0 -> {\"name\":\"Alice\"} (age omitted), Age=25 -> {\"name\":\"Alice\",\"age\":25}. Problem: can't distinguish 'age not provided' from 'age is 0'. If 0 is valid, omitempty wrong--0-year-old doesn't exist but omitted = looks like not provided. Pointer fields: type User struct { Name string `json:\"name\"`; Age *int `json:\"age,omitempty\"` }. Behavior: Age=nil -> {\"name\":\"Alice\"} (nil omitted), Age=&0 -> {\"name\":\"Alice\",\"age\":0} (0 included). Distinguishes: nil=not provided, *int=provided (even if 0). When omitempty: (1) Zero value means 'not set': empty string, false boolean. (2) Optional text fields: Email, MiddleName. (3) Flags: Active bool--false = inactive, omit from JSON for defaults. When pointer: (1) Zero value is meaningful: Age *int (0 is valid age for newborn), Price *float64 (0.0 = free). (2) Need to distinguish absent vs zero: IsActive *bool--nil = not set, false = explicitly disabled, true = enabled. (3) PATCH requests: only update provided fields--nil = don't update, value = update to this. Trade-off: pointers add complexity (nil checks), but semantic correctness. Decoding: omitempty only affects encoding (marshal), not decoding--json:\"age,omitempty\" doesn't prevent Age field from being set during unmarshal. Best practice: omitempty for string/slice (empty = not set), pointers for numbers/bools where zero is valid. API design: PATCH with pointers--only update non-nil fields."
  - question: "How do I customize JSON marshaling/unmarshaling with MarshalJSON and UnmarshalJSON?"
    answer: "Implement json.Marshaler and json.Unmarshaler interfaces to control encoding/decoding--use for custom formats, computed fields, or validation. MarshalJSON: func (u User) MarshalJSON() ([]byte, error) { type Alias User; return json.Marshal(&struct { *Alias; FullName string `json:\"full_name\"` }{ Alias: (*Alias)(&u), FullName: u.FirstName + \" \" + u.LastName }) }--adds computed field. Why: (1) Custom formats: time.Time as Unix timestamp instead of RFC3339. (2) Computed fields: combine FirstName + LastName -> FullName. (3) Encryption: marshal CreditCard with last 4 digits only. (4) Legacy compatibility: struct field ID but JSON expects id_number. UnmarshalJSON: func (u *User) UnmarshalJSON(data []byte) error { type Alias User; aux := &struct { *Alias; Age string `json:\"age\"` }{ Alias: (*Alias)(u) }; if err := json.Unmarshal(data, aux); err != nil { return err }; if age, err := strconv.Atoi(aux.Age); err == nil { u.Age = age }; return nil }--handles Age as string or int. Why: (1) Multiple formats: accept \"2023-01-01\" or \"01/01/2023\" for date. (2) Validation: reject negative prices during unmarshal. (3) Defaults: set CreatedAt if not provided. (4) Type coercion: string \"true\" -> bool true. Caveat: recursive calls--don't call json.Marshal(*u) inside MarshalJSON--infinite loop! Use alias pattern: type Alias User; json.Marshal((*Alias)(u))--skips custom method. Performance: custom marshaling adds overhead--only use when needed. Common use cases: (1) Time formats: marshal time.Time as ISO8601, Unix, or custom. (2) Enums: marshal int Status as string for API. (3) Polymorphism: unmarshal based on 'type' field--JSON with type:\"circle\" -> Circle struct. Best practice: implement both MarshalJSON and UnmarshalJSON together--symmetry ensures encode/decode round-trip works. Test thoroughly: data, _ := json.Marshal(obj); json.Unmarshal(data, &obj2); assert.Equal(obj, obj2)."
  - question: "How do I handle unknown or extra fields in JSON when unmarshaling into a struct?"
    answer: "By default Go ignores unknown fields--use json.Decoder with DisallowUnknownFields() to reject, or unmarshal to map to capture all. Default behavior: type User struct { Name string }; json.Unmarshal('{\"name\":\"Alice\",\"age\":30}', &user)--succeeds, age ignored, user.Name=\"Alice\". Use case: forward compatibility--old client receives new API fields, doesn't break. Strict mode: dec := json.NewDecoder(bytes.NewReader(data)); dec.DisallowUnknownFields(); err := dec.Decode(&user)--errors on unknown fields: 'json: unknown field \"age\"'. Use case: validation, reject malformed requests, prevent typos (usrname vs username). Capture extras: type User struct { Name string; Extras map[string]json.RawMessage }; manually parse--complex, rarely needed. Or: unmarshal to map first: var raw map[string]interface{}; json.Unmarshal(data, &raw); then extract known fields, store rest in Extras. When to use strict: (1) User input validation--reject unexpected fields in POST /users. (2) Security--unexpected fields might indicate attack. (3) Configuration files--typos silently ignored otherwise. When to allow extras: (1) Client compatibility--server adds fields, old clients continue working. (2) Partial updates--PATCH with subset of fields. (3) Polymorphic data--different objects in same array. Trade-off: strict = safer but less flexible, lenient = compatible but hides typos. Best practice: API endpoints use strict for writes (POST/PUT/PATCH), lenient for reads (GET). Implementation: middleware applies DisallowUnknownFields globally. Alternative: use validation library (go-playground/validator) to check struct after unmarshal--separates concerns. Testing: test with extra fields: data := '{\"name\":\"Alice\",\"unknown\":\"value\"}'; ensure behaves as expected."
  - question: "Should I use json.Marshal or json.Encoder, and what about performance of third-party libraries?"
    answer: "Use json.Marshal for in-memory []byte, json.Encoder for streaming to io.Writer--Encoder is faster for HTTP responses and files. json.Marshal: data, err := json.Marshal(user)--returns []byte. Use when: (1) Need []byte: pass to another function, store in variable. (2) Small payloads: single object, array of objects. (3) Testing: easy to compare: assert.Equal(expected, data). json.Encoder: json.NewEncoder(w).Encode(user)--writes directly to io.Writer. Use when: (1) HTTP responses: json.NewEncoder(w).Encode(response)--streams to client, no intermediate buffer. (2) Files: json.NewEncoder(file).Encode(data)--writes directly. (3) Large payloads: avoids allocating full []byte in memory. Performance: Encoder ~10-20% faster for HTTP--skips allocation. Marshal allocates buffer, then io.Writer.Write(buffer). Encoder writes incrementally. Third-party libraries: (1) jsoniter (json-iterator/go): drop-in replacement, 2-3x faster--import jsoniter \"github.com/json-iterator/go\"; var json = jsoniter.ConfigCompatibleWithStandardLibrary; json.Marshal(). (2) easyjson: code generation, 4-5x faster--generate with easyjson -all user.go, use user.MarshalJSON(). (3) ffjson: deprecated, use easyjson instead. When to use third-party: (1) High-throughput APIs (>10k req/s)--profile shows json.Marshal in top CPU. (2) Large payloads (>1MB)--standard library slow. (3) Latency-sensitive (p99 <10ms)--every ms counts. When stdlib is fine: (1) Most CRUD APIs--json not bottleneck, database is. (2) Internal services--simplicity > speed. (3) Small teams--fewer dependencies. Benchmark first: go test -bench=. -cpuprofile=cpu.out--verify json is actual bottleneck before optimizing. Common mistake: premature optimization--add jsoniter when real bottleneck is N+1 queries. Best practice: start with stdlib Encoder, profile, optimize if needed. Production pattern: json.NewEncoder(w).Encode(resp) for all HTTP handlers--clean, fast, idiomatic."
  - question: "What are common JSON marshaling errors and how do I debug them?"
    answer: "Common errors: unsupported type, cyclic reference, invalid UTF-8, type mismatch on unmarshal--use json.Valid() and debug prints to diagnose. Error 1: 'json: unsupported type: func()'--can't marshal functions, channels, complex. Type must be: struct, slice, array, map, string, number, bool. Fix: remove unsupported field or add `json:\"-\"` tag. Error 2: 'json: unsupported value: encountered a cycle'--struct references itself. Example: type Node struct { Value int; Next *Node }; a := &Node{Value: 1}; a.Next = a; json.Marshal(a)--infinite loop detected. Fix: custom MarshalJSON that breaks cycle, or don't marshal cyclic field. Error 3: 'invalid character 'x' looking for beginning of value'--malformed JSON input. Debug: fmt.Println(string(data))--check raw JSON. Use json.Valid(data) to verify: if !json.Valid(data) { log.Printf(\"invalid JSON: %s\", data) }. Common cause: HTML error page instead of JSON from API. Error 4: 'json: cannot unmarshal string into Go value of type int'--type mismatch. JSON has \"age\":\"30\" (string) but struct expects Age int. Fix: (1) Custom UnmarshalJSON to handle both. (2) Change struct to string, convert after. (3) Fix source data. Error 5: Field not unmarshaled--JSON key doesn't match struct field or tag. Debug: (1) Print JSON: fmt.Println(string(data)). (2) Print struct: fmt.Printf(\"%+v\", user). (3) Check tags: user_name vs userName vs UserName. Error 6: Empty result {}--all fields unexported or omitempty with zero values. Check: capitalization, omitempty with defaults. Debugging tools: (1) json.Valid(data)--check if valid JSON. (2) json.Indent(&buf, data, \"\", \"  \")--pretty-print for readability. (3) online validator: jsonlint.com. (4) Log before/after: log.Printf(\"JSON: %s\", data); err := json.Unmarshal(data, &v); log.Printf(\"Struct: %+v\", v). Production: wrap marshal/unmarshal: func SafeMarshal(v any) ([]byte, error) { data, err := json.Marshal(v); if err != nil { log.Printf(\"marshal error: %v, value: %+v\", err, v) }; return data, err }--logs context for debugging. Best practice: validate input with json.Valid, use struct tags correctly, add custom marshal methods for complex types, log errors with context."
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

```go
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

```go
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

```go
type Product struct {
    ID    int     `json:"id"`
    Name  string  `json:"name"`
    Price float64 `json:"price"`
} 
```

Working with Maps and Dynamic JSON
----------------------------------

Use `map[string]interface{}` when the structure is not fixed:

```go
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

```go
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

```json
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

```go
f, err := os.Create("data.json")
if err != nil {
    log.Fatal(err)
}
defer f.Close()

json.NewEncoder(f).Encode(user) 
```

Decode JSON from File
---------------------

```go
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
