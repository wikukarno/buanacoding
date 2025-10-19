---
title: "How to Implement Message Queuing with RabbitMQ in Go"
description: "Complete guide to implementing message queuing with RabbitMQ in Go. Learn producers, consumers, work queues, pub/sub patterns, routing, topics, error handling, and production best practices."
date: 2025-10-20T06:00:00+07:00
tags: ["Go", "RabbitMQ", "Message Queue", "Distributed Systems", "Tutorial", "AMQP"]
draft: false
author: "Wiku Karno"
keywords: ["RabbitMQ Go", "message queue Golang", "RabbitMQ tutorial Go", "AMQP Go", "distributed systems Go", "async messaging Go", "RabbitMQ producer consumer", "Go message broker"]
url: /2025/10/how-to-implement-message-queuing-with-rabbitmq-in-go.html

faq:
  - question: "What is RabbitMQ and why use it with Go applications?"
    answer: "RabbitMQ is a message broker that implements AMQP (Advanced Message Queuing Protocol). It decouples services by allowing asynchronous communication through queues. Use RabbitMQ with Go for distributed task processing, microservices communication, event-driven architectures, load balancing work across multiple workers, and handling traffic spikes. It provides reliability, message persistence, acknowledgments, and flexible routing patterns that make building scalable systems easier."

  - question: "What's the difference between a producer and a consumer in RabbitMQ?"
    answer: "A producer is an application that sends messages to RabbitMQ queues, while a consumer receives and processes messages from queues. Producers publish work or events without knowing who will process them. Consumers subscribe to queues and handle messages asynchronously. This separation allows producers to send messages even when consumers are offline, and enables multiple consumers to process messages in parallel for better performance."

  - question: "How do I ensure messages aren't lost in RabbitMQ with Go?"
    answer: "Enable message persistence by setting delivery_mode to 2, declare queues as durable so they survive broker restarts, use publisher confirms to verify messages reached the broker, implement consumer acknowledgments so messages aren't deleted until successfully processed, and use dead letter exchanges for failed messages. In Go, use channel.Confirm() for publisher confirms and manually acknowledge messages with channel.Ack() after processing succeeds."

  - question: "What are the main RabbitMQ exchange types and when to use each?"
    answer: "Direct exchange routes messages to queues based on exact routing key match - use for targeted message delivery. Fanout exchange broadcasts messages to all bound queues - use for pub/sub patterns and event broadcasting. Topic exchange routes based on pattern matching with wildcards - use for complex routing like log levels or categorization. Headers exchange routes based on message headers - use when routing logic is more complex than key matching."

  - question: "How do I handle RabbitMQ connection failures in Go?"
    answer: "Implement automatic reconnection with exponential backoff, listen to connection and channel closure notifications using NotifyClose(), recreate channels after connection loss, use circuit breaker pattern to avoid overwhelming the broker during outages, implement health checks to detect connection issues early, and log connection events for monitoring. Always handle errors from RabbitMQ operations and have retry logic for transient failures."

  - question: "What's the difference between work queues and pub/sub in RabbitMQ?"
    answer: "Work queues distribute tasks among multiple workers with round-robin delivery - each message goes to one consumer for load balancing. Pub/sub broadcasts messages to multiple consumers - each subscribed consumer receives a copy of every message. Use work queues for task processing where only one worker should handle each job. Use pub/sub when multiple services need to react to the same event, like notifying multiple microservices about a user registration."

---

Picture this: it's 3 AM, and your phone won't stop buzzing. Your API just got hit with 10,000 requests in 30 seconds. Users uploading images, generating PDF reports, sending welcome emails, processing credit cards - all at once. Your server's trying to handle everything synchronously and it's dying. Response times creep from 200ms to 15 seconds. Timeout errors everywhere. Your monitoring dashboard looks like a Christmas tree, but red instead of green.

I've been there. It's not fun.

Here's what changed everything for me: message queues. Instead of trying to do everything right now, you queue it up and process it when you can. Your API responds in milliseconds. Workers in the background handle the heavy lifting at whatever pace they can sustain. RabbitMQ is the tool that made this click for me.

In this guide, I'll walk you through everything I learned about RabbitMQ and Go. We'll start simple with basic message sending, then build up to work queues, pub/sub patterns, sophisticated routing, and all the production stuff like reconnection logic and error handling. By the end, you'll know how to build systems that don't fall over when things get busy.

## Understanding RabbitMQ and Message Queuing

Think about how you'd handle a busy restaurant. When customers place orders, the waiter doesn't run back to the kitchen, watch the chef cook everything, then deliver it to the table. That would be insane. Instead, orders go to the kitchen queue. The chef processes them as fast as possible. The waiter moves on to the next customer.

Message queues work the same way for services. Service A drops a message in the queue and keeps going. Service B picks it up when ready. Nobody's waiting around, tapping their fingers.

**RabbitMQ** is the kitchen manager in this analogy. It's a message broker running AMQP (Advanced Message Queuing Protocol). Think of it as a standalone server sitting between your services, taking messages from producers and delivering them to consumers based on whatever rules you set up.

Here's the vocabulary you need to know:

**Producers** are services that send messages. They drop stuff into exchanges without caring who's listening on the other end.

**Exchanges** are like post offices. They receive messages and figure out which queues should get them. Different exchange types have different routing strategies - we'll cover those later.

**Queues** are mailboxes. They hold messages in order until someone's ready to process them. You can make them durable so messages survive server crashes.

**Consumers** grab messages from queues and do the actual work. You can run multiple consumers on the same queue to split the load.

**Bindings** are the rules connecting exchanges to queues. They define which messages end up where.

So why use RabbitMQ? A few good reasons:

Your services can scale independently without being tied together. Traffic spikes get queued instead of crashing everything. You can spread work across as many workers as you need. Services can restart without losing messages. Plus you get sophisticated routing patterns that would be painful to build yourself.

Use message queues when you're doing background jobs (emails, reports, image processing), building microservices that don't need instant responses, creating event-driven systems where multiple services react to the same thing, balancing load across workers, or dealing with flaky networks and services that go down sometimes.

## Prerequisites and Setup

Let's get RabbitMQ running on your machine. Pick whichever method works best for you:

### Installing RabbitMQ

**macOS:**
```bash
brew install rabbitmq
brew services start rabbitmq
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install rabbitmq-server
sudo systemctl start rabbitmq
sudo systemctl enable rabbitmq
```

**Docker (recommended for development):**
```bash
docker run -d --name rabbitmq \
  -p 5672:5672 \
  -p 15672:15672 \
  rabbitmq:3-management
```

The management plugin provides a web UI at `http://localhost:15672` (username: guest, password: guest).

**Windows:**

Download the installer from rabbitmq.com/download.html and follow the installation wizard.

### Verify Installation

Check RabbitMQ is running:

```bash
sudo rabbitmqctl status
```

Or visit the management UI at `http://localhost:15672`.

### Go RabbitMQ Client

Create a new Go project:

```bash
mkdir rabbitmq-tutorial
cd rabbitmq-tutorial
go mod init github.com/yourusername/rabbitmq-tutorial
```

Install the RabbitMQ Go client:

```bash
go get github.com/rabbitmq/amqp091-go
```

This is the official Go client for RabbitMQ supporting AMQP 0.9.1.

## Basic Producer - Sending Messages

Time to send our first message. This is the "Hello World" of message queues - simple but it teaches you the fundamentals.

```go
// producer/main.go
package main

import (
	"context"
	"fmt"
	"log"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	// Connect to RabbitMQ
	conn, err := amqp.Dial("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatalf("Failed to connect to RabbitMQ: %v", err)
	}
	defer conn.Close()

	// Create a channel
	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open a channel: %v", err)
	}
	defer ch.Close()

	// Declare a queue
	queue, err := ch.QueueDeclare(
		"hello",    // queue name
		false,      // durable
		false,      // delete when unused
		false,      // exclusive
		false,      // no-wait
		nil,        // arguments
	)
	if err != nil {
		log.Fatalf("Failed to declare queue: %v", err)
	}

	// Prepare message
	body := "Hello, RabbitMQ!"
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Publish message
	err = ch.PublishWithContext(
		ctx,
		"",           // exchange
		queue.Name,   // routing key (queue name)
		false,        // mandatory
		false,        // immediate
		amqp.Publishing{
			ContentType: "text/plain",
			Body:        []byte(body),
		},
	)
	if err != nil {
		log.Fatalf("Failed to publish message: %v", err)
	}

	fmt.Printf("Sent message: %s\n", body)
}
```

Run the producer:

```bash
go run producer/main.go
```

Run this and you've just sent your first message through RabbitMQ. Pretty straightforward, right?

Here's what's happening under the hood:

`amqp.Dial()` connects to RabbitMQ using the AMQP URL format. The default credentials are guest/guest for local development.

`conn.Channel()` creates a channel. Most operations happen on channels, not connections. One connection can have many channels.

`QueueDeclare()` creates a queue if it doesn't exist. The parameters control queue behavior - we're using a simple non-durable queue for now.

`PublishWithContext()` sends the message. Empty exchange means the default exchange, which routes to queues by name.

## Basic Consumer - Receiving Messages

Sending messages is only half the story. Now let's build something to actually receive and process them.

```go
// consumer/main.go
package main

import (
	"fmt"
	"log"

	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	// Connect to RabbitMQ
	conn, err := amqp.Dial("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatalf("Failed to connect to RabbitMQ: %v", err)
	}
	defer conn.Close()

	// Create a channel
	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open a channel: %v", err)
	}
	defer ch.Close()

	// Declare the same queue
	queue, err := ch.QueueDeclare(
		"hello",
		false,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to declare queue: %v", err)
	}

	// Register a consumer
	msgs, err := ch.Consume(
		queue.Name, // queue
		"",         // consumer tag
		true,       // auto-ack
		false,      // exclusive
		false,      // no-local
		false,      // no-wait
		nil,        // args
	)
	if err != nil {
		log.Fatalf("Failed to register consumer: %v", err)
	}

	// Block and wait for messages
	forever := make(chan bool)

	go func() {
		for msg := range msgs {
			fmt.Printf("Received message: %s\n", msg.Body)
		}
	}()

	fmt.Println("Waiting for messages. Press CTRL+C to exit.")
	<-forever
}
```

Run the consumer in a separate terminal:

```bash
go run consumer/main.go
```

Keep the consumer running, then fire up the producer again in another terminal. Watch the magic happen - the consumer picks up the message instantly.

What's going on here:

The consumer also declares the queue. Queue declarations are idempotent - if the queue exists with the same configuration, nothing happens.

`Consume()` registers this application as a consumer. It returns a channel that delivers messages.

`auto-ack: true` means messages are automatically acknowledged when delivered. We'll improve this later.

The goroutine processes messages as they arrive. The channel blocks until new messages appear.

## Work Queues - Distributing Tasks

Now we're getting to the good stuff. Work queues let you spread heavy tasks across multiple workers. Got a thousand images to resize? Spin up five workers and knock them out five times faster.

### Producer with Task Distribution

```go
// producer_tasks/main.go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	conn, err := amqp.Dial("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open channel: %v", err)
	}
	defer ch.Close()

	// Declare durable queue
	queue, err := ch.QueueDeclare(
		"task_queue", // name
		true,         // durable (survives broker restart)
		false,        // delete when unused
		false,        // exclusive
		false,        // no-wait
		nil,          // arguments
	)
	if err != nil {
		log.Fatalf("Failed to declare queue: %v", err)
	}

	// Get message from command line args or use default
	body := "Task with default complexity"
	if len(os.Args) > 1 {
		body = strings.Join(os.Args[1:], " ")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err = ch.PublishWithContext(
		ctx,
		"",
		queue.Name,
		false,
		false,
		amqp.Publishing{
			DeliveryMode: amqp.Persistent, // Persist message to disk
			ContentType:  "text/plain",
			Body:         []byte(body),
		},
	)
	if err != nil {
		log.Fatalf("Failed to publish: %v", err)
	}

	fmt.Printf("Sent task: %s\n", body)
}
```

Notice what we changed here:

`durable: true` means the queue survives restarts. Your messages won't vanish if RabbitMQ crashes.

`DeliveryMode: amqp.Persistent` writes messages to disk. This is important - without it, a crash loses everything in flight.

### Worker with Fair Dispatch

```go
// worker/main.go
package main

import (
	"bytes"
	"fmt"
	"log"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	conn, err := amqp.Dial("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open channel: %v", err)
	}
	defer ch.Close()

	queue, err := ch.QueueDeclare(
		"task_queue",
		true,  // durable
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to declare queue: %v", err)
	}

	// Set QoS to process one message at a time
	err = ch.Qos(
		1,     // prefetch count
		0,     // prefetch size
		false, // global
	)
	if err != nil {
		log.Fatalf("Failed to set QoS: %v", err)
	}

	msgs, err := ch.Consume(
		queue.Name,
		"",
		false, // manual ack
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to register consumer: %v", err)
	}

	forever := make(chan bool)

	go func() {
		for msg := range msgs {
			fmt.Printf("Received task: %s\n", msg.Body)

			// Simulate work (each dot = 1 second)
			dotCount := bytes.Count(msg.Body, []byte("."))
			duration := time.Duration(dotCount) * time.Second
			time.Sleep(duration)

			fmt.Println("Task completed")

			// Manually acknowledge
			msg.Ack(false)
		}
	}()

	fmt.Println("Worker waiting for tasks. Press CTRL+C to exit.")
	<-forever
}
```

Three critical improvements here:

`Qos(1, 0, false)` tells RabbitMQ "only give me one message at a time." Without this, fast workers sit idle while slow ones get buried. Fair dispatch keeps everyone working efficiently.

`auto-ack: false` turns off automatic acknowledgment. Now messages only disappear after you explicitly confirm you handled them.

`msg.Ack(false)` confirms "yeah, I processed this successfully." If your worker crashes before acking, RabbitMQ sends that message to another worker. No lost work.

**Testing work distribution:**

Run multiple workers in different terminals:

```bash
# Terminal 1
go run worker/main.go

# Terminal 2
go run worker/main.go

# Terminal 3
go run worker/main.go
```

Send tasks with different complexities:

```bash
go run producer_tasks/main.go "Task one."
go run producer_tasks/main.go "Task two...."
go run producer_tasks/main.go "Task three."
go run producer_tasks/main.go "Task four......"
```

Watch what happens - tasks get distributed evenly across your workers. Each dot simulates one second of work, so "Task four......" takes six seconds. The worker that finishes first grabs the next task. Beautiful.

## Publish/Subscribe Pattern

Sometimes you need to broadcast the same message to everyone. Think logging systems where you want to save logs to a file AND send them to a monitoring service AND display them in the console. That's pub/sub.

### Publisher with Fanout Exchange

```go
// publisher/main.go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	conn, err := amqp.Dial("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open channel: %v", err)
	}
	defer ch.Close()

	// Declare fanout exchange
	err = ch.ExchangeDeclare(
		"logs",   // name
		"fanout", // type
		true,     // durable
		false,    // auto-deleted
		false,    // internal
		false,    // no-wait
		nil,      // arguments
	)
	if err != nil {
		log.Fatalf("Failed to declare exchange: %v", err)
	}

	body := "Info: Something happened"
	if len(os.Args) > 1 {
		body = strings.Join(os.Args[1:], " ")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err = ch.PublishWithContext(
		ctx,
		"logs", // exchange
		"",     // routing key (ignored for fanout)
		false,
		false,
		amqp.Publishing{
			ContentType: "text/plain",
			Body:        []byte(body),
		},
	)
	if err != nil {
		log.Fatalf("Failed to publish: %v", err)
	}

	fmt.Printf("Published log: %s\n", body)
}
```

The fanout exchange is like yelling in a crowded room - everyone hears it. The routing key doesn't matter here.

### Subscriber

```go
// subscriber/main.go
package main

import (
	"fmt"
	"log"

	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	conn, err := amqp.Dial("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open channel: %v", err)
	}
	defer ch.Close()

	err = ch.ExchangeDeclare(
		"logs",
		"fanout",
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to declare exchange: %v", err)
	}

	// Declare exclusive queue (auto-delete when consumer disconnects)
	queue, err := ch.QueueDeclare(
		"",    // empty name = random queue name
		false, // durable
		false, // delete when unused
		true,  // exclusive
		false, // no-wait
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to declare queue: %v", err)
	}

	// Bind queue to exchange
	err = ch.QueueBind(
		queue.Name, // queue name
		"",         // routing key
		"logs",     // exchange
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to bind queue: %v", err)
	}

	msgs, err := ch.Consume(
		queue.Name,
		"",
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to register consumer: %v", err)
	}

	forever := make(chan bool)

	go func() {
		for msg := range msgs {
			fmt.Printf("Received log: %s\n", msg.Body)
		}
	}()

	fmt.Println("Waiting for logs. Press CTRL+C to exit.")
	<-forever
}
```

**Testing pub/sub:**

Run multiple subscribers in different terminals:

```bash
# Terminal 1
go run subscriber/main.go

# Terminal 2
go run subscriber/main.go

# Terminal 3
go run subscriber/main.go
```

Publish a message:

```bash
go run publisher/main.go "Error: Database connection failed"
```

Boom - all three subscribers get the exact same message. Perfect for when multiple services need to know about the same event.

## Routing with Direct Exchange

Fanout is great, but sometimes you want selective delivery. Maybe you only want errors going to your pager, while warnings go to logs. Direct exchanges let you route based on exact key matches.

### Producer with Routing

```go
// emit_log_direct/main.go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	conn, err := amqp.Dial("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open channel: %v", err)
	}
	defer ch.Close()

	// Declare direct exchange
	err = ch.ExchangeDeclare(
		"logs_direct", // name
		"direct",      // type
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to declare exchange: %v", err)
	}

	// Get severity and message from args
	severity := "info"
	if len(os.Args) > 1 {
		severity = os.Args[1]
	}

	body := "Default log message"
	if len(os.Args) > 2 {
		body = strings.Join(os.Args[2:], " ")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err = ch.PublishWithContext(
		ctx,
		"logs_direct", // exchange
		severity,      // routing key
		false,
		false,
		amqp.Publishing{
			ContentType: "text/plain",
			Body:        []byte(body),
		},
	)
	if err != nil {
		log.Fatalf("Failed to publish: %v", err)
	}

	fmt.Printf("Sent [%s] %s\n", severity, body)
}
```

### Consumer with Selective Routing

```go
// receive_logs_direct/main.go
package main

import (
	"fmt"
	"log"
	"os"

	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	conn, err := amqp.Dial("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open channel: %v", err)
	}
	defer ch.Close()

	err = ch.ExchangeDeclare(
		"logs_direct",
		"direct",
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to declare exchange: %v", err)
	}

	queue, err := ch.QueueDeclare(
		"",
		false,
		false,
		true,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to declare queue: %v", err)
	}

	// Get severities from command line args
	severities := os.Args[1:]
	if len(severities) == 0 {
		log.Printf("Usage: %s [info] [warning] [error]", os.Args[0])
		os.Exit(1)
	}

	// Bind queue for each severity
	for _, severity := range severities {
		err = ch.QueueBind(
			queue.Name,
			severity,      // routing key
			"logs_direct", // exchange
			false,
			nil,
		)
		if err != nil {
			log.Fatalf("Failed to bind queue: %v", err)
		}
		fmt.Printf("Bound to severity: %s\n", severity)
	}

	msgs, err := ch.Consume(
		queue.Name,
		"",
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to register consumer: %v", err)
	}

	forever := make(chan bool)

	go func() {
		for msg := range msgs {
			fmt.Printf("[%s] %s\n", msg.RoutingKey, msg.Body)
		}
	}()

	fmt.Println("Waiting for logs. Press CTRL+C to exit.")
	<-forever
}
```

**Testing routing:**

Start a consumer that only receives errors:

```bash
go run receive_logs_direct/main.go error
```

Start another consumer for warnings and errors:

```bash
go run receive_logs_direct/main.go warning error
```

Send different log levels:

```bash
go run emit_log_direct/main.go info "Application started"
go run emit_log_direct/main.go warning "CPU usage high"
go run emit_log_direct/main.go error "Database connection failed"
```

The first consumer only catches the error. The second one sees both warnings and errors. Super useful for setting up different alert levels.

## Topic Exchange for Pattern Matching

Direct routing works, but what if you want more flexibility? Topics let you use wildcards for pattern matching. Way more powerful.

### Publisher with Topics

```go
// emit_log_topic/main.go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	conn, err := amqp.Dial("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open channel: %v", err)
	}
	defer ch.Close()

	// Declare topic exchange
	err = ch.ExchangeDeclare(
		"logs_topic", // name
		"topic",      // type
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to declare exchange: %v", err)
	}

	// Get routing key and message
	routingKey := "anonymous.info"
	if len(os.Args) > 1 {
		routingKey = os.Args[1]
	}

	body := "Default message"
	if len(os.Args) > 2 {
		body = strings.Join(os.Args[2:], " ")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err = ch.PublishWithContext(
		ctx,
		"logs_topic",
		routingKey,
		false,
		false,
		amqp.Publishing{
			ContentType: "text/plain",
			Body:        []byte(body),
		},
	)
	if err != nil {
		log.Fatalf("Failed to publish: %v", err)
	}

	fmt.Printf("Sent [%s] %s\n", routingKey, body)
}
```

### Subscriber with Pattern Matching

```go
// receive_logs_topic/main.go
package main

import (
	"fmt"
	"log"
	"os"

	amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
	conn, err := amqp.Dial("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open channel: %v", err)
	}
	defer ch.Close()

	err = ch.ExchangeDeclare(
		"logs_topic",
		"topic",
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to declare exchange: %v", err)
	}

	queue, err := ch.QueueDeclare(
		"",
		false,
		false,
		true,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to declare queue: %v", err)
	}

	// Get binding keys from args
	bindingKeys := os.Args[1:]
	if len(bindingKeys) == 0 {
		log.Printf("Usage: %s [binding_key]...", os.Args[0])
		log.Printf("Example patterns:")
		log.Printf("  *.critical - all critical logs")
		log.Printf("  kern.* - all kernel logs")
		log.Printf("  *.*.error - all error logs from any facility")
		os.Exit(1)
	}

	// Bind queue with each pattern
	for _, key := range bindingKeys {
		err = ch.QueueBind(
			queue.Name,
			key,
			"logs_topic",
			false,
			nil,
		)
		if err != nil {
			log.Fatalf("Failed to bind queue: %v", err)
		}
		fmt.Printf("Bound with pattern: %s\n", key)
	}

	msgs, err := ch.Consume(
		queue.Name,
		"",
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to register consumer: %v", err)
	}

	forever := make(chan bool)

	go func() {
		for msg := range msgs {
			fmt.Printf("[%s] %s\n", msg.RoutingKey, msg.Body)
		}
	}()

	fmt.Println("Waiting for logs. Press CTRL+C to exit.")
	<-forever
}
```

**Topic routing rules:**

`*` (star) matches exactly one word.
`#` (hash) matches zero or more words.

Words are separated by dots.

**Examples:**

Routing key `kern.critical` matches pattern `kern.*` and `*.critical` and `#`.

Routing key `kern.info.security` matches `kern.#` and `#.security` and `kern.*.security`.

**Testing topics:**

Receive all kernel logs:

```bash
go run receive_logs_topic/main.go "kern.*"
```

Receive all critical logs:

```bash
go run receive_logs_topic/main.go "*.critical"
```

Receive all logs:

```bash
go run receive_logs_topic/main.go "#"
```

Send various log types:

```bash
go run emit_log_topic/main.go "kern.critical" "Kernel panic"
go run emit_log_topic/main.go "kern.info" "System booted"
go run emit_log_topic/main.go "app.critical" "Out of memory"
```

## Connection Management and Error Handling

Here's where things get real. In production, connections drop. Networks hiccup. RabbitMQ restarts for updates. Your code needs to handle all of this gracefully without losing messages.

```go
// pkg/rabbitmq/connection.go
package rabbitmq

import (
	"fmt"
	"log"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

type Connection struct {
	conn    *amqp.Connection
	channel *amqp.Channel
	url     string
	done    chan bool
}

func NewConnection(url string) (*Connection, error) {
	c := &Connection{
		url:  url,
		done: make(chan bool),
	}

	err := c.connect()
	if err != nil {
		return nil, err
	}

	go c.handleReconnect()

	return c, nil
}

func (c *Connection) connect() error {
	var err error

	c.conn, err = amqp.Dial(c.url)
	if err != nil {
		return fmt.Errorf("failed to connect: %w", err)
	}

	c.channel, err = c.conn.Channel()
	if err != nil {
		c.conn.Close()
		return fmt.Errorf("failed to open channel: %w", err)
	}

	log.Println("Connected to RabbitMQ")
	return nil
}

func (c *Connection) handleReconnect() {
	for {
		select {
		case <-c.done:
			return
		case err := <-c.conn.NotifyClose(make(chan *amqp.Error)):
			if err != nil {
				log.Printf("Connection closed: %v", err)
				c.reconnect()
			}
		}
	}
}

func (c *Connection) reconnect() {
	for {
		log.Println("Attempting to reconnect...")
		err := c.connect()
		if err == nil {
			return
		}

		log.Printf("Reconnection failed: %v. Retrying in 5 seconds...", err)
		time.Sleep(5 * time.Second)
	}
}

func (c *Connection) Channel() *amqp.Channel {
	return c.channel
}

func (c *Connection) Close() {
	close(c.done)
	if c.channel != nil {
		c.channel.Close()
	}
	if c.conn != nil {
		c.conn.Close()
	}
}
```

Usage:

```go
// main.go
package main

import (
	"log"
	"time"

	"github.com/yourusername/rabbitmq-tutorial/pkg/rabbitmq"
)

func main() {
	conn, err := rabbitmq.NewConnection("amqp://guest:guest@localhost:5672/")
	if err != nil {
		log.Fatalf("Failed to establish connection: %v", err)
	}
	defer conn.Close()

	// Use conn.Channel() for operations
	ch := conn.Channel()

	// Your application logic here
	time.Sleep(60 * time.Second)
}
```

This handles disconnections automatically. Network blip? No problem. RabbitMQ restart? It'll reconnect and keep going. You won't lose messages.

## Publisher Confirms for Reliability

Want to be absolutely sure your messages made it to RabbitMQ? Publisher confirms give you that guarantee. RabbitMQ sends back a confirmation for each message.

```go
// pkg/rabbitmq/reliable_publisher.go
package rabbitmq

import (
	"context"
	"fmt"
	"log"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

type ReliablePublisher struct {
	channel *amqp.Channel
}

func NewReliablePublisher(channel *amqp.Channel) (*ReliablePublisher, error) {
	// Enable publisher confirms
	err := channel.Confirm(false)
	if err != nil {
		return nil, fmt.Errorf("failed to enable confirms: %w", err)
	}

	return &ReliablePublisher{
		channel: channel,
	}, nil
}

func (p *ReliablePublisher) Publish(ctx context.Context, exchange, routingKey string, body []byte) error {
	// Create confirm channel
	confirms := p.channel.NotifyPublish(make(chan amqp.Confirmation, 1))

	err := p.channel.PublishWithContext(
		ctx,
		exchange,
		routingKey,
		false,
		false,
		amqp.Publishing{
			DeliveryMode: amqp.Persistent,
			ContentType:  "application/json",
			Body:         body,
		},
	)
	if err != nil {
		return fmt.Errorf("failed to publish: %w", err)
	}

	// Wait for confirmation
	select {
	case confirm := <-confirms:
		if !confirm.Ack {
			return fmt.Errorf("message not acknowledged by broker")
		}
		log.Println("Message confirmed by broker")
		return nil
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(5 * time.Second):
		return fmt.Errorf("confirmation timeout")
	}
}
```

Usage:

```go
publisher, err := NewReliablePublisher(ch)
if err != nil {
	log.Fatal(err)
}

ctx := context.Background()
err = publisher.Publish(ctx, "exchange", "routing.key", []byte("message"))
if err != nil {
	log.Printf("Publish failed: %v", err)
}
```

## Consumer with Retry Logic

Processing fails sometimes. Database is down, external API times out, whatever. You don't want to lose the message, but you also don't want to retry forever. Here's how to handle it properly.

```go
// pkg/rabbitmq/reliable_consumer.go
package rabbitmq

import (
	"fmt"
	"log"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

type MessageHandler func([]byte) error

type ReliableConsumer struct {
	channel     *amqp.Channel
	queueName   string
	handler     MessageHandler
	maxRetries  int
	retryDelay  time.Duration
}

func NewReliableConsumer(
	channel *amqp.Channel,
	queueName string,
	handler MessageHandler,
) *ReliableConsumer {
	return &ReliableConsumer{
		channel:    channel,
		queueName:  queueName,
		handler:    handler,
		maxRetries: 3,
		retryDelay: 5 * time.Second,
	}
}

func (c *ReliableConsumer) Start() error {
	// Declare dead letter exchange
	err := c.channel.ExchangeDeclare(
		"dlx",
		"direct",
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		return fmt.Errorf("failed to declare DLX: %w", err)
	}

	// Declare dead letter queue
	_, err = c.channel.QueueDeclare(
		"dlq",
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		return fmt.Errorf("failed to declare DLQ: %w", err)
	}

	// Bind DLQ to DLX
	err = c.channel.QueueBind("dlq", c.queueName, "dlx", false, nil)
	if err != nil {
		return fmt.Errorf("failed to bind DLQ: %w", err)
	}

	// Declare main queue with DLX
	_, err = c.channel.QueueDeclare(
		c.queueName,
		true,
		false,
		false,
		false,
		amqp.Table{
			"x-dead-letter-exchange": "dlx",
		},
	)
	if err != nil {
		return fmt.Errorf("failed to declare queue: %w", err)
	}

	// Set QoS
	err = c.channel.Qos(1, 0, false)
	if err != nil {
		return fmt.Errorf("failed to set QoS: %w", err)
	}

	// Start consuming
	msgs, err := c.channel.Consume(
		c.queueName,
		"",
		false, // manual ack
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		return fmt.Errorf("failed to start consuming: %w", err)
	}

	go c.handleMessages(msgs)

	return nil
}

func (c *ReliableConsumer) handleMessages(msgs <-chan amqp.Delivery) {
	for msg := range msgs {
		retries := c.getRetryCount(msg)

		err := c.handler(msg.Body)
		if err != nil {
			log.Printf("Handler error: %v", err)

			if retries < c.maxRetries {
				// Reject with requeue for retry
				log.Printf("Retry %d/%d", retries+1, c.maxRetries)
				msg.Nack(false, true)
				time.Sleep(c.retryDelay)
			} else {
				// Max retries exceeded, send to DLQ
				log.Printf("Max retries exceeded, sending to DLQ")
				msg.Nack(false, false)
			}
		} else {
			// Success
			msg.Ack(false)
		}
	}
}

func (c *ReliableConsumer) getRetryCount(msg amqp.Delivery) int {
	if msg.Headers == nil {
		return 0
	}

	if count, ok := msg.Headers["x-retry-count"].(int); ok {
		return count
	}

	return 0
}
```

## Production Best Practices

### Connection Pooling

For high-throughput applications, maintain a pool of connections:

```go
type ConnectionPool struct {
	connections []*Connection
	current     int
	mu          sync.Mutex
}

func NewConnectionPool(url string, size int) (*ConnectionPool, error) {
	pool := &ConnectionPool{
		connections: make([]*Connection, size),
	}

	for i := 0; i < size; i++ {
		conn, err := NewConnection(url)
		if err != nil {
			return nil, err
		}
		pool.connections[i] = conn
	}

	return pool, nil
}

func (p *ConnectionPool) Get() *Connection {
	p.mu.Lock()
	defer p.mu.Unlock()

	conn := p.connections[p.current]
	p.current = (p.current + 1) % len(p.connections)
	return conn
}
```

### Monitoring and Metrics

Track queue depth, consumer count, and message rates:

```go
func (c *Connection) GetQueueInfo(queueName string) (*QueueInfo, error) {
	queue, err := c.channel.QueueInspect(queueName)
	if err != nil {
		return nil, err
	}

	return &QueueInfo{
		Messages:   queue.Messages,
		Consumers:  queue.Consumers,
		Name:       queue.Name,
	}, nil
}

type QueueInfo struct {
	Messages  int
	Consumers int
	Name      string
}
```

### Configuration Management

Use environment variables for configuration:

```go
type Config struct {
	URL              string
	Exchange         string
	QueueName        string
	RoutingKey       string
	PrefetchCount    int
	ReconnectDelay   time.Duration
}

func LoadConfig() *Config {
	return &Config{
		URL:            getEnv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/"),
		Exchange:       getEnv("RABBITMQ_EXCHANGE", "default"),
		QueueName:      getEnv("RABBITMQ_QUEUE", "default_queue"),
		RoutingKey:     getEnv("RABBITMQ_ROUTING_KEY", ""),
		PrefetchCount:  getEnvInt("RABBITMQ_PREFETCH", 1),
		ReconnectDelay: getEnvDuration("RABBITMQ_RECONNECT_DELAY", 5*time.Second),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
```

### Security Considerations

Use TLS for production:

```go
conn, err := amqp.DialTLS("amqps://user:pass@hostname:5671/", &tls.Config{
	MinVersion: tls.VersionTLS12,
})
```

Create dedicated users with limited permissions instead of using the guest account.

### Performance Optimization

Batch messages when possible:

```go
func (p *Publisher) PublishBatch(messages []Message) error {
	for _, msg := range messages {
		err := p.channel.PublishWithContext(
			context.Background(),
			p.exchange,
			msg.RoutingKey,
			false,
			false,
			amqp.Publishing{
				Body: msg.Body,
			},
		)
		if err != nil {
			return err
		}
	}
	return nil
}
```

Use connection and channel pooling for concurrent publishing.

## Integration with Other Go Features

Combine RabbitMQ with other patterns for robust applications.

For background job processing, use RabbitMQ with [Asynq and Redis](/2025/10/how-to-implement-background-jobs-in-go-with-asynq-and-redis.html) for complementary features.

Store message metadata in [PostgreSQL](/2025/05/connecting-postgresql-in-go-using-sqlx.html) or [MongoDB](/2025/10/how-to-work-with-mongodb-in-go-complete-crud-tutorial.html) for audit trails.

Use [structured logging with slog](/2025/09/complete-guide-slog-go-structured-logging-2025.html) to track message processing.

Implement [rate limiting](/2025/10/how-to-implement-rate-limiting-in-go-protect-api-from-abuse.html) for message publishing.

Secure message endpoints with [JWT authentication](/2025/09/how-to-implement-jwt-authentication-in-go-secure-rest-api.html).

## Wrapping Up

RabbitMQ completely changed how I build distributed systems. Before message queues, everything was tightly coupled - one service called another, waited for a response, hoped nothing broke. Painful. With RabbitMQ, services barely know each other exist. They drop messages in queues and move on. Way more resilient.

We covered a lot of ground here. Basic producers and consumers, work queues for distributing load, pub/sub for broadcasting, routing patterns for selective delivery, connection management that handles failures, and all the production stuff like publisher confirms and retry logic. That's your foundation right there.

One thing to keep in mind: message queues mean eventual consistency. Work happens asynchronously. Data doesn't update instantly everywhere. That takes some getting used to if you're coming from a synchronous world, but once it clicks, you'll never want to go back. Systems that handle failures gracefully and scale horizontally are worth the mental shift.

For production, watch your queue depths - if they keep growing, you need more workers. Set up dead letter queues for messages that fail repeatedly. Use publisher confirms when you can't afford to lose data. Pool connections for high throughput. These aren't optional niceties - they're what keep your messaging infrastructure solid when things get busy.

The best way to really learn this stuff is to build something real with it. Pick a feature in your application that's slow or blocks - image processing, report generation, email sending, whatever. Throw it behind RabbitMQ and see how much better it feels. You'll be hooked.
