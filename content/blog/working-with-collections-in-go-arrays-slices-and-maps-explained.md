---
title: 'Working with Collections in Go: Arrays, Slices, and Maps Explained'
date: 2025-04-17T22:46:00.002+07:00
draft: false
url: /2025/04/working-with-collections-in-go-arrays.html
tags: 
- Go
---

When building applications in Go, it's common to work with groups of data. For example, you might want to store a list of user names, or map names to scores. In Go, you can use collections like arrays, slices, and maps to do that.

In this article, we’ll explore:

*   What arrays are and how they work
*   How slices offer more flexibility
*   What maps are and how to use them
*   Common operations with collections
*   Practical examples to understand the difference between them

Let’s dive in and learn how Go helps us manage grouped data efficiently.

Arrays in Go
------------

An array is a fixed-size collection of elements of the same type. Once an array is created, its size cannot change.

```
package main

import "fmt"

func main() {
    var numbers [3]int
    numbers[0] = 10
    numbers[1] = 20
    numbers[2] = 30

    fmt.Println(numbers)
} 
```

You can also initialize an array directly:

```
names := [3]string{"Alice", "Bob", "Charlie"}
```

Arrays have a fixed size. All elements must be of the same type, and you can access items using their index (starting from 0).

Arrays are not commonly used in large Go applications, but understanding them is key to learning slices.

Slices in Go
------------

Slices are more flexible than arrays. They are built on top of arrays but allow dynamic resizing.

```
numbers := []int{10, 20, 30}
fmt.Println(numbers) 
```

Adding elements to a slice:

```
numbers = append(numbers, 40)
fmt.Println(numbers) 
```

Creating slices from existing arrays:

```
arr := [5]int{1, 2, 3, 4, 5}
slice := arr[1:4] // includes index 1 to 3
fmt.Println(slice) 
```

Useful slice operations include append, len (length), and cap (capacity). Slices are widely used in Go because they are flexible and efficient.

Another great thing about slices is that they can share the same underlying array. This allows for memory-efficient manipulation of data. However, you should be cautious when modifying shared slices as changes might affect other parts of your code.

Maps in Go
----------

Maps are key-value pairs. You can use them to store and retrieve data by key.

```
scores := map[string]int{
    "Alice": 90,
    "Bob": 85,
}

fmt.Println(scores["Alice"]) 
```

Adding and updating values:

```
scores["Charlie"] = 88
scores["Bob"] = 95 
```

Deleting a value:

```
delete(scores, "Alice")
```

Looping through a map:

```
for name, score := range scores {
    fmt.Println(name, "has score", score)
} 
```

Checking if a key exists:

```
value, exists := scores["David"]
if exists {
    fmt.Println("Score:", value)
} else {
    fmt.Println("David not found")
} 
```

Maps are extremely useful when you need fast lookups or need to associate labels with values. For example, they’re great for storing configuration options, lookup tables, or grouped statistics.

Choosing Between Arrays, Slices, and Maps
-----------------------------------------

Use arrays when the size is known and fixed. Use slices when you need a dynamic list. Use maps when you need to associate keys to values (like name to score).

Each data structure has its own strengths. As a Go developer, you’ll likely use slices and maps much more often than arrays, especially when working with APIs, databases, or handling JSON.

Practical Example: Student Grades
---------------------------------

```
grades := map[string][]int{
    "Alice": {90, 85, 88},
    "Bob": {78, 82, 80},
}

for name, gradeList := range grades {
    total := 0
    for _, grade := range gradeList {
        total += grade
    }
    average := total / len(gradeList)
    fmt.Println(name, "average grade:", average)
} 
```

This example combines maps and slices to store multiple grades for each student and calculates the average.

Summary
-------

Collections in Go help you group and organize data. Arrays are useful but limited by their fixed size. Slices are flexible and the most commonly used collection in Go. Maps let you link one value to another using keys.

By understanding and practicing with these three types of collections, you’ll be ready to write real-world programs that work with lists of data, settings, or records.

As you continue learning Go, try building small programs that use slices and maps. Practice manipulating data, looping through collections, and performing operations like sorting or searching. These are real-world tasks you'll encounter as a developer.

Keep exploring and happy coding!