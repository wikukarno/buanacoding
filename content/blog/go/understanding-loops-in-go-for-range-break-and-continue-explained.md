---
title: 'for, range, break, and continue Explained'
date: 2025-04-16T22:06:00.001+07:00
draft: false
url: /2025/04/understanding-loops-in-go-for-range.html
tags: 
- Go
description: "Learn how to use loops in Go: for, range, break, and continue. Understand how to iterate over collections and control loop flow."
keywords: ["Go", "loops", "for", "range", "break", "continue", "programming"]
faq:
  - question: "How do I iterate over slices and maps idiomatically?"
    answer: "Use for range. For slices you get index and value; for maps you get key and value. Remember that map iteration order is randomized—don’t rely on ordering."
  - question: "Why do goroutines capture the loop variable unexpectedly?"
    answer: "The range variable is reused on each iteration. Create a local copy inside the loop (v := v) before launching a goroutine to capture the correct value."
  - question: "When should I use break vs continue?"
    answer: "Use break to exit the loop entirely, continue to skip to the next iteration. For nested loops, consider labels to break a specific outer loop—but use them sparingly."
  - question: "How do I loop over strings safely with Unicode?"
    answer: "Use for range to iterate over runes, not bytes. This ensures multi-byte UTF-8 characters are handled correctly."
  - question: "Any performance tips for loops in Go?"
    answer: "Pre-allocate slices with make when the size is known, avoid unnecessary conversions, and minimize work inside tight loops. Use benchmarks to guide optimizations."
  - question: "How can I avoid off-by-one errors in loops?"
    answer: "Prefer clear loop conditions, test boundaries, and use len(s) consistently. Write small unit tests to cover edge indices."
---

Loops are a key part of programming. They let us run the same piece of code multiple times without repeating ourselves. In Go, loops are simple but powerful — and they're built using just one keyword: for.

In this article, we’ll explore:

*   The basic for loop in Go
*   Using for as a while loop
*   Looping with range
*   Breaking or skipping parts of loops with break and continue
*   Real-world examples to help you understand how loops work

What is a Loop?
---------------

A loop is a way to repeat a block of code as long as a condition remains true. Instead of writing similar code many times, we can put it in a loop and let the program handle the repetition. This makes our code shorter, cleaner, and easier to manage. Go uses the keyword for for all loop types, which makes it both simple and flexible.

The Basic for Loop
------------------

The most common way to write a loop in Go is with the standard for loop structure. It includes three parts: an initializer, a condition, and a post statement.

```go
package main

import "fmt"

func main() {
    for i := 0; i < 5; i++ {
        fmt.Println("Count:", i)
    }
} 
```

This loop will print numbers from 0 to 4. First, it starts with i = 0. Then it checks the condition i < 5. If true, it runs the code inside the loop. After each loop, i is increased by 1. When the condition is false, the loop stops.

Using for as a while Loop
-------------------------

Go doesn’t have a while keyword. But you can use for in the same way by just writing the condition.

```go
func main() {
    i := 0
    for i < 3 {
        fmt.Println("i is:", i)
        i++
    }
} 
```

This loop works exactly like a while loop. It continues running as long as the condition i < 3 is true. This format is useful when you don’t need a counter setup like in the basic for loop.

Infinite Loops
--------------

Sometimes you want a loop to run forever, such as when building servers or listening to user input. You can do this by writing for without a condition.

```go
func main() {
    for {
        fmt.Println("This runs forever until we break it.")
        break
    }
} 
```

This is an infinite loop, and you control when to stop it using a break statement inside the loop.

Looping with range
------------------

Go provides a very handy way to loop over arrays, slices, strings, and maps using range. It simplifies working with collections.

### Example with a slice:

```go
func main() {
    fruits := []string{"apple", "banana", "cherry"}

    for index, fruit := range fruits {
        fmt.Println(index, fruit)
    }
} 
```

Here, range gives both the index and the value of each item. If you don’t need the index, you can ignore it using an underscore:

```go
for _, fruit := range fruits {
    fmt.Println(fruit)
} 
```

### Looping through a map:

You can use range to loop through key-value pairs in a map:

```go
func main() {
    scores := map[string]int{"Alice": 90, "Bob": 85}

    for name, score := range scores {
        fmt.Println(name, "scored", score)
    }
} 
```

### Looping over a string:

Strings in Go are UTF-8 encoded. Using range lets you loop through each character:

```go
func main() {
    word := "go"

    for _, char := range word {
        fmt.Println(char)
    }
} 
```

Note: This prints the Unicode code points (runes) for each character. If you want the actual character, you can use fmt.Printf("%c", char).

Using break and continue
------------------------

To control your loop more precisely, you can use break to stop the loop early, or continue to skip the current iteration and move to the next one.

### Example with break:

```go
func main() {
    for i := 0; i < 10; i++ {
        if i == 5 {
            break
        }
        fmt.Println(i)
    }
} 
```

### Example with continue:

```go
func main() {
    for i := 0; i < 5; i++ {
        if i == 2 {
            continue
        }
        fmt.Println(i)
    }
} 
```

In this example, when i equals 2, the loop skips that iteration and continues with the next one.

Why Loops Matter
----------------

Loops allow you to handle tasks like processing data, creating repeated outputs, checking conditions, or iterating through user input efficiently. Whether you’re building a calculator, a file reader, or a game, you’ll probably use loops often.

Summary
-------

Loops in Go are powerful but simple. You can use for in different styles: the traditional counter-based loop, while-like loops, infinite loops, and range-based loops for collections. You can even control the flow inside the loop with break and continue.

With just one keyword, Go gives you all the looping tools you need. Try writing your own loops, experiment with slices and maps, and see how you can apply them in your real projects.

Keep learning and happy coding!
