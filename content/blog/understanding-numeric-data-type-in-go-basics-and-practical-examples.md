---
title: 'Understanding Numeric Data Type In Go : Basics and Practical Examples'
date: 2024-07-20T19:00:00.004+07:00
draft: false
url: /2024/07/understanding-numeric-data-type-in-go.html
tags: 
- Go
---

Go, also known as Golang, is a statically typed language developed by Google. It's known for its simplicity and efficiency, especially when it comes to systems and concurrent programming. In this article, we'll explore the numeric types in Go and provide practical examples to illustrate their usage.

Basic Numeric Types
-------------------

Go offers several basic numeric types categorized into integers, floating point numbers, and complex numbers. Here’s a quick overview:

### Integer

Integer types are divided into two categories, signed and unsigned. The signed integers **int8, int16, int32, int64** can hold both negative and positive values, whereas unsigned integers **int8, int16, int32, int64** can only hold positive values and zero.

Here’s an example of how you can declare and initialize an integer variable in Go:

```
`package main

import "fmt"

func main() {
    var a int8 = 127    // a := int8(127)
    var b uint8 = 255   // b := uint8(255)
    fmt.Printf("Type: %T Value: %v\n", a, a)
    fmt.Printf("Type: %T Value: %v\n", b, b)
}` 

```

Output

```
`Type: int8 Value: 127
Type: uint8 Value: 255`

```

### Floating Point

go has two floating point types: **float32** and **float64**. The numbers represent single and double precision floating point numbers respectively.

Here’s an example of how you can declare and initialize a floating point variable in Go:

```
`package main
import "fmt"

func main() {
    var pi float64 = 3.14159
    fmt.Printf("Type: %T Value: %v\n", pi, pi)
}` 

```

Output

```
`Type: float64 Value: 3.14159`

```

### Complex Numbers

Go has two complex number types: **complex64** and **complex128**. The numbers represent complex numbers with **float32** and **float64** real and imaginary parts respectively.

Here’s an example of how you can declare and initialize a complex number variable in Go:

```
`package main
import "fmt"

func main() {
    c := complex(3, 4)
    fmt.Printf("Type: %T Value: %v\n", c, c)
}` 

```

Output

```
`Type: complex128 Value: (3+4i)`

```

Numeric Literals
----------------

Go supports several numeric literals, including decimal, binary, octal, and hexadecimal. Here’s an example of how you can declare and initialize numeric literals in Go:

```
`package main
import "fmt"

func main() {
    a := 42
    b := 0b101010 // binary literal
    c := 0o52    // octal literal
    d := 0x2a    // hexadecimal literal
    fmt.Println(a, b, c, d)
}` 

```

Output

```
`42 42 42 42`

```

Numeric Operations
------------------

Go supports several arithmetic operations on numeric types, including addition, subtraction, multiplication, division, and modulus. Here’s an example of how you can perform arithmetic operations in Go:

```
`package main
import "fmt"

func main() {
    a := 10
    b := 20
    sum := a + b
    diff := a - b
    product := a * b
    quotient := a / b
    remainder := a % b
    fmt.Println(sum, diff, product, quotient, remainder)
}` 

```

Output

```
`30 -10 200 0 10`

```

Conclusion
----------

Go provides a rich set of numeric types and operations that make it easy to work with numbers in your programs. By understanding the different numeric types and their usage, you can write efficient and reliable code that performs well in a variety of scenarios.

For more information on Go’s numeric types, you can refer to the official [Go documentation](https://golang.org/ref/spec#Numeric_types).

Happy coding!