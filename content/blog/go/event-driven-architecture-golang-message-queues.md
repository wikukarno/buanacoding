---
title: "Event-Driven Architecture with Golang and Message Queues"
description: "Learn how to build scalable event-driven systems using Go and message queues. Master event sourcing, CQRS patterns, and asynchronous communication for resilient distributed applications."
date: 2025-09-27T03:00:00+07:00
tags: ["Go", "Event-Driven", "Message Queue", "Architecture"]
draft: false
author: "Wiku Karno"
keywords: ["Go", "Golang", "Event-Driven Architecture", "Message Queue", "NATS", "RabbitMQ", "Event Sourcing", "CQRS"]
url: /2025/09/event-driven-architecture-golang-message-queues.html
faq:
  - question: "What is event-driven architecture in Go?"
    answer: "Event-driven architecture (EDA) is a style where services communicate by publishing and consuming events instead of calling each other directly. In Go, you typically use a message broker (e.g., NATS, RabbitMQ, or Kafka) and lightweight consumers/producers to decouple services, improve scalability, and handle spikes through asynchronous processing."
  - question: "When should I choose EDA over request/response APIs?"
    answer: "Choose EDA when you need loose coupling, horizontal scalability, resilience to partial failures, and the ability to process workloads asynchronously. If your use case requires synchronous user feedback or strong transactional guarantees across services, mix EDA with request/response patterns or consider a saga pattern to coordinate workflows."
  - question: "Which message broker should I use: NATS, RabbitMQ, or Kafka?"
    answer: "Use NATS for lightweight, low-latency messaging and simple pub/sub; RabbitMQ for robust routing, acknowledgments, and at-least-once delivery semantics; Kafka for very high throughput, event streaming, and durable retention with replay. Pick based on delivery guarantees, throughput, and operational complexity you can manage."
  - question: "How do I handle idempotency and retries?"
    answer: "Include an idempotency key (e.g., event ID) and store processed IDs in a fast store (Redis/DB) with TTL. Make consumers idempotent, use durable queues with acknowledgments, implement exponential backoff, and send poison messages to a dead-letter queue (DLQ) for offline inspection and recovery."
  - question: "What about eventual consistency and data integrity?"
    answer: "Model aggregates to tolerate eventual consistency, emit domain events after local transactions commit, and let downstream services update their read models. Use the outbox pattern to atomically persist events with business data, then a relay publishes them to the broker to avoid dual-write problems."
  - question: "How should I design and version events?"
    answer: "Keep events small and descriptive (name, version, aggregate ID, timestamp, payload). Use schema evolution (add-only, default values) and version fields. Avoid breaking changes; publish new event versions while consumers gradually migrate. Maintain clear contracts and documentation for each event type."
---

Traditional request-response architectures work well for simple applications, but as systems grow in complexity and scale, they often become bottlenecks. Event-driven architecture gives you a better way to build systems by letting components talk to each other through messages instead of direct calls. When combined with Go's excellent concurrency model and robust ecosystem, event-driven systems become powerful tools for building scalable, resilient applications.

In this guide, you'll learn how to build event-driven systems using Go and message queues that actually work in production. We'll explore event sourcing patterns, CQRS implementation, and practical strategies for building systems that can handle high throughput while maintaining data consistency and system reliability.

## Understanding Event-Driven Architecture

Event-driven architecture is built around three main ideas: creating events when things happen, detecting those events, and doing something useful with them. An event represents something significant that happened in your system - a user registered, an order was placed, or a payment was processed. Unlike traditional synchronous architectures where components directly call each other, event-driven systems use events as the primary means of communication.

Every event-driven system has three main parts: services that create events when something important happens, services that listen for those events and do work, and a message system that gets events from creators to listeners reliably.

This approach has some real benefits. Your services don't need to know about each other directly, which makes the system easier to maintain and lets you scale different parts independently. The asynchronous nature improves performance since operations don't block waiting for responses. Additionally, the system becomes more resilient because failures in one component don't immediately cascade to others.

But event-driven systems aren't all sunshine and rainbows. Since things happen asynchronously, your data might not be immediately consistent everywhere. Debugging becomes more challenging because request flows span multiple components. Message ordering and delivery guarantees require careful consideration to ensure your system behaves correctly.

## Choosing the Right Message Queue System

The message queue is the heart of your event-driven system. Each option gives you different trade-offs between speed, reliability, and how hard it is to run in production. Let's examine the most popular options for Go applications.

**NATS** provides lightweight, high-performance messaging with excellent Go support. It's particularly well-suited for microservices communication and real-time applications. NATS offers different messaging patterns including publish-subscribe, request-reply, and queuing, with built-in load balancing and fault tolerance.

**RabbitMQ** offers robust features including message persistence, complex routing, and guaranteed delivery. It supports multiple messaging patterns and provides excellent tooling for monitoring and management. RabbitMQ works well for enterprise applications that need reliable message delivery guarantees.

**Apache Kafka** excels at high-throughput scenarios and provides excellent durability through its distributed log architecture. Kafka is ideal for event sourcing implementations and systems that need to replay events. However, it has higher operational complexity compared to simpler solutions.

For this guide, we'll focus primarily on NATS and RabbitMQ, as they provide good balance between features and simplicity for most Go applications.

## Implementing Event-Driven Patterns with NATS

We'll build a real-world example using NATS - an e-commerce order processing system that shows you the patterns you'll actually use in production.

First, install and set up NATS:

```bash
# Install NATS server
go get github.com/nats-io/nats-server/v2
go get github.com/nats-io/nats.go

# Start NATS server (for development)
nats-server
```

Create the basic event infrastructure:

```go
// pkg/events/event.go
package events

import (
    "encoding/json"
    "time"
)

// Event represents a domain event in our system
type Event struct {
    ID        string                 `json:"id"`
    Type      string                 `json:"type"`
    Source    string                 `json:"source"`
    Data      map[string]interface{} `json:"data"`
    Version   string                 `json:"version"`
    Timestamp time.Time              `json:"timestamp"`
}

// NewEvent creates a new event with required metadata
func NewEvent(eventType, source string, data map[string]interface{}) *Event {
    return &Event{
        ID:        generateEventID(),
        Type:      eventType,
        Source:    source,
        Data:      data,
        Version:   "1.0",
        Timestamp: time.Now(),
    }
}

// ToJSON converts the event to JSON for transmission
func (e *Event) ToJSON() ([]byte, error) {
    return json.Marshal(e)
}

// FromJSON creates an event from JSON data
func FromJSON(data []byte) (*Event, error) {
    var event Event
    err := json.Unmarshal(data, &event)
    return &event, err
}

func generateEventID() string {
    // Implementation would generate a unique ID
    // Using UUID or similar
    return fmt.Sprintf("evt_%d", time.Now().UnixNano())
}
```

Implement the event publisher:

```go
// pkg/events/publisher.go
package events

import (
    "fmt"
    "log"

    "github.com/nats-io/nats.go"
)

type Publisher struct {
    conn *nats.Conn
}

func NewPublisher(natsURL string) (*Publisher, error) {
    conn, err := nats.Connect(natsURL)
    if err != nil {
        return nil, fmt.Errorf("failed to connect to NATS: %w", err)
    }

    return &Publisher{conn: conn}, nil
}

func (p *Publisher) Publish(subject string, event *Event) error {
    data, err := event.ToJSON()
    if err != nil {
        return fmt.Errorf("failed to serialize event: %w", err)
    }

    err = p.conn.Publish(subject, data)
    if err != nil {
        return fmt.Errorf("failed to publish event: %w", err)
    }

    log.Printf("Published event %s to subject %s", event.ID, subject)
    return nil
}

func (p *Publisher) PublishSync(subject string, event *Event) error {
    err := p.Publish(subject, event)
    if err != nil {
        return err
    }

    // Ensure message is delivered before returning
    return p.conn.Flush()
}

func (p *Publisher) Close() {
    p.conn.Close()
}
```

Create event consumers with different processing patterns:

```go
// pkg/events/consumer.go
package events

import (
    "context"
    "fmt"
    "log"
    "sync"

    "github.com/nats-io/nats.go"
)

type EventHandler func(ctx context.Context, event *Event) error

type Consumer struct {
    conn         *nats.Conn
    handlers     map[string]EventHandler
    mu           sync.RWMutex
    subscriptions []*nats.Subscription
}

func NewConsumer(natsURL string) (*Consumer, error) {
    conn, err := nats.Connect(natsURL)
    if err != nil {
        return nil, fmt.Errorf("failed to connect to NATS: %w", err)
    }

    return &Consumer{
        conn:     conn,
        handlers: make(map[string]EventHandler),
    }, nil
}

func (c *Consumer) RegisterHandler(eventType string, handler EventHandler) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.handlers[eventType] = handler
}

func (c *Consumer) Subscribe(subject string) error {
    sub, err := c.conn.Subscribe(subject, c.handleMessage)
    if err != nil {
        return fmt.Errorf("failed to subscribe to %s: %w", subject, err)
    }

    c.subscriptions = append(c.subscriptions, sub)
    log.Printf("Subscribed to subject: %s", subject)
    return nil
}

func (c *Consumer) SubscribeQueue(subject, queue string) error {
    sub, err := c.conn.QueueSubscribe(subject, queue, c.handleMessage)
    if err != nil {
        return fmt.Errorf("failed to queue subscribe to %s: %w", subject, err)
    }

    c.subscriptions = append(c.subscriptions, sub)
    log.Printf("Queue subscribed to subject: %s, queue: %s", subject, queue)
    return nil
}

func (c *Consumer) handleMessage(msg *nats.Msg) {
    event, err := FromJSON(msg.Data)
    if err != nil {
        log.Printf("Failed to parse event: %v", err)
        return
    }

    c.mu.RLock()
    handler, exists := c.handlers[event.Type]
    c.mu.RUnlock()

    if !exists {
        log.Printf("No handler registered for event type: %s", event.Type)
        return
    }

    ctx := context.Background()
    if err := handler(ctx, event); err != nil {
        log.Printf("Handler failed for event %s: %v", event.ID, err)
        // In production, you might want to implement retry logic or dead letter queues
    }
}

func (c *Consumer) Close() {
    for _, sub := range c.subscriptions {
        sub.Unsubscribe()
    }
    c.conn.Close()
}
```

## Building Domain Services with Event Publishing

Now let's implement domain services that publish events when important business operations occur:

```go
// internal/order/service.go
package order

import (
    "context"
    "fmt"
    "time"

    "your-app/pkg/events"
)

type Order struct {
    ID          string    `json:"id"`
    CustomerID  string    `json:"customer_id"`
    Items       []Item    `json:"items"`
    TotalAmount float64   `json:"total_amount"`
    Status      string    `json:"status"`
    CreatedAt   time.Time `json:"created_at"`
}

type Item struct {
    ProductID string  `json:"product_id"`
    Quantity  int     `json:"quantity"`
    Price     float64 `json:"price"`
}

type Service struct {
    publisher events.Publisher
    repo      Repository
}

func NewService(publisher events.Publisher, repo Repository) *Service {
    return &Service{
        publisher: publisher,
        repo:      repo,
    }
}

func (s *Service) CreateOrder(ctx context.Context, customerID string, items []Item) (*Order, error) {
    // Calculate total amount
    totalAmount := 0.0
    for _, item := range items {
        totalAmount += item.Price * float64(item.Quantity)
    }

    order := &Order{
        ID:          generateOrderID(),
        CustomerID:  customerID,
        Items:       items,
        TotalAmount: totalAmount,
        Status:      "pending",
        CreatedAt:   time.Now(),
    }

    // Save order to database
    err := s.repo.Save(ctx, order)
    if err != nil {
        return nil, fmt.Errorf("failed to save order: %w", err)
    }

    // Publish order created event
    event := events.NewEvent("order.created", "order-service", map[string]interface{}{
        "order_id":     order.ID,
        "customer_id":  order.CustomerID,
        "total_amount": order.TotalAmount,
        "items":        order.Items,
    })

    err = s.publisher.Publish("orders.events", event)
    if err != nil {
        log.Printf("Failed to publish order created event: %v", err)
        // Note: In production, you might want to use the outbox pattern
        // to ensure events are published reliably
    }

    return order, nil
}

func (s *Service) UpdateOrderStatus(ctx context.Context, orderID, status string) error {
    order, err := s.repo.GetByID(ctx, orderID)
    if err != nil {
        return fmt.Errorf("failed to get order: %w", err)
    }

    previousStatus := order.Status
    order.Status = status

    err = s.repo.Update(ctx, order)
    if err != nil {
        return fmt.Errorf("failed to update order: %w", err)
    }

    // Publish status change event
    event := events.NewEvent("order.status_changed", "order-service", map[string]interface{}{
        "order_id":        order.ID,
        "previous_status": previousStatus,
        "new_status":      status,
        "updated_at":      time.Now(),
    })

    err = s.publisher.Publish("orders.events", event)
    if err != nil {
        log.Printf("Failed to publish order status changed event: %v", err)
    }

    return nil
}

func generateOrderID() string {
    return fmt.Sprintf("order_%d", time.Now().UnixNano())
}
```

Implement event handlers for different services:

```go
// internal/inventory/event_handler.go
package inventory

import (
    "context"
    "log"

    "your-app/pkg/events"
)

type EventHandler struct {
    service *Service
}

func NewEventHandler(service *Service) *EventHandler {
    return &EventHandler{service: service}
}

func (h *EventHandler) HandleOrderCreated(ctx context.Context, event *events.Event) error {
    orderID, ok := event.Data["order_id"].(string)
    if !ok {
        return fmt.Errorf("invalid order_id in event data")
    }

    items, ok := event.Data["items"].([]interface{})
    if !ok {
        return fmt.Errorf("invalid items in event data")
    }

    log.Printf("Processing inventory reservation for order: %s", orderID)

    // Reserve inventory for each item
    for _, itemData := range items {
        item, ok := itemData.(map[string]interface{})
        if !ok {
            continue
        }

        productID, _ := item["product_id"].(string)
        quantity, _ := item["quantity"].(float64)

        err := h.service.ReserveInventory(ctx, productID, int(quantity))
        if err != nil {
            log.Printf("Failed to reserve inventory for product %s: %v", productID, err)

            // Publish inventory reservation failed event
            failEvent := events.NewEvent("inventory.reservation_failed", "inventory-service", map[string]interface{}{
                "order_id":   orderID,
                "product_id": productID,
                "quantity":   quantity,
                "reason":     err.Error(),
            })

            // This would typically use the same publisher instance
            // h.publisher.Publish("inventory.events", failEvent)

            return err
        }
    }

    // Publish successful reservation event
    successEvent := events.NewEvent("inventory.reserved", "inventory-service", map[string]interface{}{
        "order_id": orderID,
        "items":    items,
    })

    // h.publisher.Publish("inventory.events", successEvent)
    log.Printf("Successfully reserved inventory for order: %s", orderID)

    return nil
}
```

## Implementing Event Sourcing Patterns

Event sourcing takes event-driven architecture a step further by storing events as the primary source of truth. Instead of storing current state, you store the sequence of events that led to that state. This approach provides complete audit trails and enables powerful features like temporal queries and event replay.

Let's implement a basic event sourcing system:

```go
// pkg/eventsourcing/event_store.go
package eventsourcing

import (
    "context"
    "database/sql"
    "encoding/json"
    "fmt"
    "time"
)

type StoredEvent struct {
    ID           string    `json:"id"`
    AggregateID  string    `json:"aggregate_id"`
    EventType    string    `json:"event_type"`
    EventData    string    `json:"event_data"`
    Version      int       `json:"version"`
    CreatedAt    time.Time `json:"created_at"`
}

type EventStore struct {
    db *sql.DB
}

func NewEventStore(db *sql.DB) *EventStore {
    return &EventStore{db: db}
}

func (es *EventStore) SaveEvent(ctx context.Context, aggregateID string, event interface{}, expectedVersion int) error {
    eventData, err := json.Marshal(event)
    if err != nil {
        return fmt.Errorf("failed to marshal event: %w", err)
    }

    eventType := getEventType(event)

    query := `
        INSERT INTO events (id, aggregate_id, event_type, event_data, version, created_at)
        VALUES ($1, $2, $3, $4, $5, $6)
    `

    eventID := generateEventID()
    version := expectedVersion + 1

    _, err = es.db.ExecContext(ctx, query, eventID, aggregateID, eventType, string(eventData), version, time.Now())
    if err != nil {
        return fmt.Errorf("failed to save event: %w", err)
    }

    return nil
}

func (es *EventStore) GetEvents(ctx context.Context, aggregateID string, fromVersion int) ([]StoredEvent, error) {
    query := `
        SELECT id, aggregate_id, event_type, event_data, version, created_at
        FROM events
        WHERE aggregate_id = $1 AND version > $2
        ORDER BY version ASC
    `

    rows, err := es.db.QueryContext(ctx, query, aggregateID, fromVersion)
    if err != nil {
        return nil, fmt.Errorf("failed to query events: %w", err)
    }
    defer rows.Close()

    var events []StoredEvent
    for rows.Next() {
        var event StoredEvent
        err := rows.Scan(&event.ID, &event.AggregateID, &event.EventType,
                        &event.EventData, &event.Version, &event.CreatedAt)
        if err != nil {
            return nil, fmt.Errorf("failed to scan event: %w", err)
        }
        events = append(events, event)
    }

    return events, nil
}

func (es *EventStore) GetAllEvents(ctx context.Context, aggregateID string) ([]StoredEvent, error) {
    return es.GetEvents(ctx, aggregateID, 0)
}

func getEventType(event interface{}) string {
    // Use reflection or type switches to determine event type
    switch event.(type) {
    case OrderCreatedEvent:
        return "OrderCreated"
    case OrderStatusChangedEvent:
        return "OrderStatusChanged"
    default:
        return "Unknown"
    }
}
```

Create domain events for event sourcing:

```go
// internal/order/events.go
package order

import "time"

type OrderCreatedEvent struct {
    OrderID     string    `json:"order_id"`
    CustomerID  string    `json:"customer_id"`
    Items       []Item    `json:"items"`
    TotalAmount float64   `json:"total_amount"`
    CreatedAt   time.Time `json:"created_at"`
}

type OrderStatusChangedEvent struct {
    OrderID       string    `json:"order_id"`
    PreviousStatus string   `json:"previous_status"`
    NewStatus     string    `json:"new_status"`
    ChangedAt     time.Time `json:"changed_at"`
}

type OrderCancelledEvent struct {
    OrderID     string    `json:"order_id"`
    Reason      string    `json:"reason"`
    CancelledAt time.Time `json:"cancelled_at"`
}
```

Implement an aggregate root that uses event sourcing:

```go
// internal/order/aggregate.go
package order

import (
    "context"
    "fmt"
    "time"

    "your-app/pkg/eventsourcing"
)

type OrderAggregate struct {
    ID           string
    CustomerID   string
    Items        []Item
    TotalAmount  float64
    Status       string
    CreatedAt    time.Time
    version      int
    uncommittedEvents []interface{}
}

func NewOrderAggregate(customerID string, items []Item) *OrderAggregate {
    orderID := generateOrderID()
    totalAmount := calculateTotal(items)

    aggregate := &OrderAggregate{
        version: 0,
    }

    // Apply the order created event
    event := OrderCreatedEvent{
        OrderID:     orderID,
        CustomerID:  customerID,
        Items:       items,
        TotalAmount: totalAmount,
        CreatedAt:   time.Now(),
    }

    aggregate.apply(event)
    aggregate.recordEvent(event)

    return aggregate
}

func LoadOrderAggregate(ctx context.Context, orderID string, eventStore *eventsourcing.EventStore) (*OrderAggregate, error) {
    events, err := eventStore.GetAllEvents(ctx, orderID)
    if err != nil {
        return nil, fmt.Errorf("failed to load events: %w", err)
    }

    if len(events) == 0 {
        return nil, fmt.Errorf("order not found: %s", orderID)
    }

    aggregate := &OrderAggregate{}

    for _, storedEvent := range events {
        event, err := deserializeEvent(storedEvent.EventType, storedEvent.EventData)
        if err != nil {
            return nil, fmt.Errorf("failed to deserialize event: %w", err)
        }

        aggregate.apply(event)
        aggregate.version = storedEvent.Version
    }

    return aggregate, nil
}

func (oa *OrderAggregate) ChangeStatus(newStatus string) error {
    if oa.Status == newStatus {
        return fmt.Errorf("order already has status: %s", newStatus)
    }

    if oa.Status == "cancelled" {
        return fmt.Errorf("cannot change status of cancelled order")
    }

    event := OrderStatusChangedEvent{
        OrderID:        oa.ID,
        PreviousStatus: oa.Status,
        NewStatus:      newStatus,
        ChangedAt:      time.Now(),
    }

    oa.apply(event)
    oa.recordEvent(event)

    return nil
}

func (oa *OrderAggregate) Cancel(reason string) error {
    if oa.Status == "cancelled" {
        return fmt.Errorf("order already cancelled")
    }

    if oa.Status == "completed" {
        return fmt.Errorf("cannot cancel completed order")
    }

    event := OrderCancelledEvent{
        OrderID:     oa.ID,
        Reason:      reason,
        CancelledAt: time.Now(),
    }

    oa.apply(event)
    oa.recordEvent(event)

    return nil
}

func (oa *OrderAggregate) apply(event interface{}) {
    switch e := event.(type) {
    case OrderCreatedEvent:
        oa.ID = e.OrderID
        oa.CustomerID = e.CustomerID
        oa.Items = e.Items
        oa.TotalAmount = e.TotalAmount
        oa.Status = "pending"
        oa.CreatedAt = e.CreatedAt

    case OrderStatusChangedEvent:
        oa.Status = e.NewStatus

    case OrderCancelledEvent:
        oa.Status = "cancelled"
    }
}

func (oa *OrderAggregate) recordEvent(event interface{}) {
    oa.uncommittedEvents = append(oa.uncommittedEvents, event)
}

func (oa *OrderAggregate) Save(ctx context.Context, eventStore *eventsourcing.EventStore) error {
    for _, event := range oa.uncommittedEvents {
        err := eventStore.SaveEvent(ctx, oa.ID, event, oa.version)
        if err != nil {
            return fmt.Errorf("failed to save event: %w", err)
        }
        oa.version++
    }

    oa.uncommittedEvents = nil
    return nil
}

func calculateTotal(items []Item) float64 {
    total := 0.0
    for _, item := range items {
        total += item.Price * float64(item.Quantity)
    }
    return total
}

func deserializeEvent(eventType, eventData string) (interface{}, error) {
    switch eventType {
    case "OrderCreated":
        var event OrderCreatedEvent
        err := json.Unmarshal([]byte(eventData), &event)
        return event, err
    case "OrderStatusChanged":
        var event OrderStatusChangedEvent
        err := json.Unmarshal([]byte(eventData), &event)
        return event, err
    case "OrderCancelled":
        var event OrderCancelledEvent
        err := json.Unmarshal([]byte(eventData), &event)
        return event, err
    default:
        return nil, fmt.Errorf("unknown event type: %s", eventType)
    }
}
```

## Implementing CQRS with Event-Driven Architecture

Command Query Responsibility Segregation (CQRS) pairs naturally with event-driven architecture. CQRS separates read and write operations, allowing you to optimize each side independently. Events serve as the bridge between the command side (writes) and query side (reads).

Let's implement a CQRS system with event-driven updates:

```go
// internal/order/commands.go
package order

import (
    "context"
    "fmt"

    "your-app/pkg/eventsourcing"
)

type CommandHandler struct {
    eventStore *eventsourcing.EventStore
    publisher  EventPublisher
}

func NewCommandHandler(eventStore *eventsourcing.EventStore, publisher EventPublisher) *CommandHandler {
    return &CommandHandler{
        eventStore: eventStore,
        publisher:  publisher,
    }
}

type CreateOrderCommand struct {
    CustomerID string `json:"customer_id"`
    Items      []Item `json:"items"`
}

type ChangeOrderStatusCommand struct {
    OrderID   string `json:"order_id"`
    NewStatus string `json:"new_status"`
}

func (ch *CommandHandler) HandleCreateOrder(ctx context.Context, cmd CreateOrderCommand) (*OrderAggregate, error) {
    // Create new aggregate
    aggregate := NewOrderAggregate(cmd.CustomerID, cmd.Items)

    // Save events to event store
    err := aggregate.Save(ctx, ch.eventStore)
    if err != nil {
        return nil, fmt.Errorf("failed to save order aggregate: %w", err)
    }

    // Publish events to message queue for read model updates
    for _, event := range aggregate.uncommittedEvents {
        err := ch.publisher.PublishDomainEvent(ctx, event)
        if err != nil {
            log.Printf("Failed to publish event: %v", err)
            // In production, you might want to implement compensation logic
        }
    }

    return aggregate, nil
}

func (ch *CommandHandler) HandleChangeOrderStatus(ctx context.Context, cmd ChangeOrderStatusCommand) error {
    // Load aggregate from event store
    aggregate, err := LoadOrderAggregate(ctx, cmd.OrderID, ch.eventStore)
    if err != nil {
        return fmt.Errorf("failed to load order aggregate: %w", err)
    }

    // Execute business logic
    err = aggregate.ChangeStatus(cmd.NewStatus)
    if err != nil {
        return fmt.Errorf("failed to change order status: %w", err)
    }

    // Save new events
    err = aggregate.Save(ctx, ch.eventStore)
    if err != nil {
        return fmt.Errorf("failed to save order aggregate: %w", err)
    }

    // Publish events for read model updates
    for _, event := range aggregate.uncommittedEvents {
        err := ch.publisher.PublishDomainEvent(ctx, event)
        if err != nil {
            log.Printf("Failed to publish event: %v", err)
        }
    }

    return nil
}
```

Implement read models that are updated via events:

```go
// internal/order/read_model.go
package order

import (
    "context"
    "database/sql"
    "encoding/json"
    "fmt"
    "time"
)

type OrderReadModel struct {
    ID           string    `json:"id" db:"id"`
    CustomerID   string    `json:"customer_id" db:"customer_id"`
    CustomerName string    `json:"customer_name" db:"customer_name"`
    ItemCount    int       `json:"item_count" db:"item_count"`
    TotalAmount  float64   `json:"total_amount" db:"total_amount"`
    Status       string    `json:"status" db:"status"`
    CreatedAt    time.Time `json:"created_at" db:"created_at"`
    UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`
}

type ReadModelRepository struct {
    db *sql.DB
}

func NewReadModelRepository(db *sql.DB) *ReadModelRepository {
    return &ReadModelRepository{db: db}
}

func (r *ReadModelRepository) Save(ctx context.Context, order *OrderReadModel) error {
    query := `
        INSERT INTO order_read_models (id, customer_id, customer_name, item_count, total_amount, status, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (id)
        DO UPDATE SET
            customer_name = EXCLUDED.customer_name,
            item_count = EXCLUDED.item_count,
            total_amount = EXCLUDED.total_amount,
            status = EXCLUDED.status,
            updated_at = EXCLUDED.updated_at
    `

    _, err := r.db.ExecContext(ctx, query,
        order.ID, order.CustomerID, order.CustomerName, order.ItemCount,
        order.TotalAmount, order.Status, order.CreatedAt, order.UpdatedAt)

    return err
}

func (r *ReadModelRepository) GetByID(ctx context.Context, id string) (*OrderReadModel, error) {
    query := `
        SELECT id, customer_id, customer_name, item_count, total_amount, status, created_at, updated_at
        FROM order_read_models WHERE id = $1
    `

    var order OrderReadModel
    err := r.db.QueryRowContext(ctx, query, id).Scan(
        &order.ID, &order.CustomerID, &order.CustomerName, &order.ItemCount,
        &order.TotalAmount, &order.Status, &order.CreatedAt, &order.UpdatedAt)

    if err != nil {
        return nil, err
    }

    return &order, nil
}

func (r *ReadModelRepository) GetByCustomerID(ctx context.Context, customerID string) ([]*OrderReadModel, error) {
    query := `
        SELECT id, customer_id, customer_name, item_count, total_amount, status, created_at, updated_at
        FROM order_read_models
        WHERE customer_id = $1
        ORDER BY created_at DESC
    `

    rows, err := r.db.QueryContext(ctx, query, customerID)
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    var orders []*OrderReadModel
    for rows.Next() {
        var order OrderReadModel
        err := rows.Scan(&order.ID, &order.CustomerID, &order.CustomerName,
                        &order.ItemCount, &order.TotalAmount, &order.Status,
                        &order.CreatedAt, &order.UpdatedAt)
        if err != nil {
            return nil, err
        }
        orders = append(orders, &order)
    }

    return orders, nil
}
```

Create event handlers for read model updates:

```go
// internal/order/read_model_handler.go
package order

import (
    "context"
    "log"

    "your-app/pkg/events"
)

type ReadModelHandler struct {
    repo         *ReadModelRepository
    customerRepo CustomerRepository // For enriching read models
}

func NewReadModelHandler(repo *ReadModelRepository, customerRepo CustomerRepository) *ReadModelHandler {
    return &ReadModelHandler{
        repo:         repo,
        customerRepo: customerRepo,
    }
}

func (h *ReadModelHandler) HandleOrderCreated(ctx context.Context, event *events.Event) error {
    var orderEvent OrderCreatedEvent
    eventData, _ := json.Marshal(event.Data)
    err := json.Unmarshal(eventData, &orderEvent)
    if err != nil {
        return fmt.Errorf("failed to unmarshal order created event: %w", err)
    }

    // Enrich with customer data
    customer, err := h.customerRepo.GetByID(ctx, orderEvent.CustomerID)
    if err != nil {
        log.Printf("Failed to get customer data: %v", err)
        // Continue with empty customer name
    }

    customerName := ""
    if customer != nil {
        customerName = customer.Name
    }

    readModel := &OrderReadModel{
        ID:           orderEvent.OrderID,
        CustomerID:   orderEvent.CustomerID,
        CustomerName: customerName,
        ItemCount:    len(orderEvent.Items),
        TotalAmount:  orderEvent.TotalAmount,
        Status:       "pending",
        CreatedAt:    orderEvent.CreatedAt,
        UpdatedAt:    orderEvent.CreatedAt,
    }

    err = h.repo.Save(ctx, readModel)
    if err != nil {
        return fmt.Errorf("failed to save order read model: %w", err)
    }

    log.Printf("Updated read model for order: %s", orderEvent.OrderID)
    return nil
}

func (h *ReadModelHandler) HandleOrderStatusChanged(ctx context.Context, event *events.Event) error {
    var statusEvent OrderStatusChangedEvent
    eventData, _ := json.Marshal(event.Data)
    err := json.Unmarshal(eventData, &statusEvent)
    if err != nil {
        return fmt.Errorf("failed to unmarshal order status changed event: %w", err)
    }

    // Load existing read model
    readModel, err := h.repo.GetByID(ctx, statusEvent.OrderID)
    if err != nil {
        return fmt.Errorf("failed to get existing read model: %w", err)
    }

    // Update status and timestamp
    readModel.Status = statusEvent.NewStatus
    readModel.UpdatedAt = statusEvent.ChangedAt

    err = h.repo.Save(ctx, readModel)
    if err != nil {
        return fmt.Errorf("failed to update order read model: %w", err)
    }

    log.Printf("Updated read model status for order: %s to %s", statusEvent.OrderID, statusEvent.NewStatus)
    return nil
}
```

## Error Handling and Resilience Patterns

Event-driven systems require robust error handling and resilience patterns. Network failures, service outages, and processing errors are inevitable in distributed systems.

Implement retry mechanisms with exponential backoff:

```go
// pkg/resilience/retry.go
package resilience

import (
    "context"
    "fmt"
    "math"
    "time"
)

type RetryConfig struct {
    MaxAttempts int           `json:"max_attempts"`
    BaseDelay   time.Duration `json:"base_delay"`
    MaxDelay    time.Duration `json:"max_delay"`
    Multiplier  float64       `json:"multiplier"`
}

func DefaultRetryConfig() RetryConfig {
    return RetryConfig{
        MaxAttempts: 3,
        BaseDelay:   100 * time.Millisecond,
        MaxDelay:    30 * time.Second,
        Multiplier:  2.0,
    }
}

func RetryWithBackoff(ctx context.Context, config RetryConfig, operation func() error) error {
    var lastErr error

    for attempt := 1; attempt <= config.MaxAttempts; attempt++ {
        lastErr = operation()
        if lastErr == nil {
            return nil
        }

        if attempt == config.MaxAttempts {
            break
        }

        // Calculate delay with exponential backoff
        delay := time.Duration(float64(config.BaseDelay) * math.Pow(config.Multiplier, float64(attempt-1)))
        if delay > config.MaxDelay {
            delay = config.MaxDelay
        }

        log.Printf("Operation failed (attempt %d/%d): %v. Retrying in %v",
                   attempt, config.MaxAttempts, lastErr, delay)

        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-time.After(delay):
            // Continue to next attempt
        }
    }

    return fmt.Errorf("operation failed after %d attempts: %w", config.MaxAttempts, lastErr)
}
```

Implement dead letter queue handling:

```go
// pkg/events/dead_letter.go
package events

import (
    "context"
    "encoding/json"
    "log"
    "time"
)

type DeadLetter struct {
    OriginalEvent  *Event    `json:"original_event"`
    FailureReason  string    `json:"failure_reason"`
    FailureCount   int       `json:"failure_count"`
    FirstFailedAt  time.Time `json:"first_failed_at"`
    LastFailedAt   time.Time `json:"last_failed_at"`
}

type DeadLetterHandler struct {
    publisher *Publisher
    storage   DeadLetterStorage
}

func NewDeadLetterHandler(publisher *Publisher, storage DeadLetterStorage) *DeadLetterHandler {
    return &DeadLetterHandler{
        publisher: publisher,
        storage:   storage,
    }
}

func (dlh *DeadLetterHandler) HandleFailedEvent(ctx context.Context, event *Event, err error) {
    deadLetter := &DeadLetter{
        OriginalEvent: event,
        FailureReason: err.Error(),
        FailureCount:  1,
        FirstFailedAt: time.Now(),
        LastFailedAt:  time.Now(),
    }

    // Check if this event has failed before
    existing, err := dlh.storage.GetByEventID(ctx, event.ID)
    if err == nil && existing != nil {
        deadLetter.FailureCount = existing.FailureCount + 1
        deadLetter.FirstFailedAt = existing.FirstFailedAt
    }

    // Store in dead letter storage
    err = dlh.storage.Save(ctx, deadLetter)
    if err != nil {
        log.Printf("Failed to save dead letter: %v", err)
    }

    // Publish to dead letter queue for manual processing
    dlEvent := NewEvent("dead_letter.created", "dead-letter-handler", map[string]interface{}{
        "event_id":       event.ID,
        "failure_reason": deadLetter.FailureReason,
        "failure_count":  deadLetter.FailureCount,
    })

    err = dlh.publisher.Publish("dead_letters", dlEvent)
    if err != nil {
        log.Printf("Failed to publish dead letter event: %v", err)
    }

    log.Printf("Event %s moved to dead letter queue after %d failures", event.ID, deadLetter.FailureCount)
}

func (dlh *DeadLetterHandler) ReprocessDeadLetter(ctx context.Context, eventID string) error {
    deadLetter, err := dlh.storage.GetByEventID(ctx, eventID)
    if err != nil {
        return fmt.Errorf("failed to get dead letter: %w", err)
    }

    // Republish the original event
    err = dlh.publisher.Publish("retry_queue", deadLetter.OriginalEvent)
    if err != nil {
        return fmt.Errorf("failed to republish event: %w", err)
    }

    // Remove from dead letter storage
    err = dlh.storage.Delete(ctx, eventID)
    if err != nil {
        log.Printf("Failed to delete dead letter: %v", err)
    }

    return nil
}
```

## Performance Optimization and Monitoring

Event-driven systems require careful monitoring to ensure healthy operation. Implement comprehensive metrics and observability:

```go
// pkg/monitoring/metrics.go
package monitoring

import (
    "context"
    "time"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

type EventMetrics struct {
    eventsPublished   prometheus.Counter
    eventsConsumed    prometheus.Counter
    eventsFailed      prometheus.Counter
    processingTime    prometheus.Histogram
    queueDepth        prometheus.Gauge
}

func NewEventMetrics() *EventMetrics {
    return &EventMetrics{
        eventsPublished: promauto.NewCounter(prometheus.CounterOpts{
            Name: "events_published_total",
            Help: "Total number of events published",
        }),
        eventsConsumed: promauto.NewCounter(prometheus.CounterOpts{
            Name: "events_consumed_total",
            Help: "Total number of events consumed",
        }),
        eventsFailed: promauto.NewCounter(prometheus.CounterOpts{
            Name: "events_failed_total",
            Help: "Total number of failed event processing attempts",
        }),
        processingTime: promauto.NewHistogram(prometheus.HistogramOpts{
            Name: "event_processing_duration_seconds",
            Help: "Time taken to process events",
            Buckets: prometheus.DefBuckets,
        }),
        queueDepth: promauto.NewGauge(prometheus.GaugeOpts{
            Name: "event_queue_depth",
            Help: "Current depth of event queue",
        }),
    }
}

func (em *EventMetrics) RecordEventPublished() {
    em.eventsPublished.Inc()
}

func (em *EventMetrics) RecordEventConsumed(duration time.Duration) {
    em.eventsConsumed.Inc()
    em.processingTime.Observe(duration.Seconds())
}

func (em *EventMetrics) RecordEventFailed() {
    em.eventsFailed.Inc()
}

func (em *EventMetrics) UpdateQueueDepth(depth float64) {
    em.queueDepth.Set(depth)
}
```

## Production Deployment and Best Practices

When deploying event-driven systems to production, several key considerations ensure reliability and performance:

**Message Ordering**: For scenarios requiring strict ordering, use partitioned topics or single-threaded consumers. However, consider whether eventual consistency might be acceptable to achieve better performance.

**Idempotency**: Design event handlers to be idempotent since message delivery guarantees might result in duplicate processing. Use event IDs or business keys to detect and handle duplicates.

**Event Schema Evolution**: Plan for event schema changes by using versioned events and maintaining backward compatibility. Consider using tools like Protocol Buffers or Avro for schema evolution support.

**Monitoring and Alerting**: Implement comprehensive monitoring for queue depths, processing latencies, error rates, and dead letter queues. Set up alerts for unusual patterns that might indicate system issues.

**Capacity Planning**: Monitor resource usage patterns and plan for scaling both message brokers and consumers based on traffic patterns and growth projections.

## Conclusion

Event-driven architecture with Go provides a powerful foundation for building scalable, resilient distributed systems. The patterns and implementations covered in this guide demonstrate how to leverage Go's strengths while addressing the unique challenges of asynchronous, event-based communication.

Key takeaways include the importance of choosing the right message queue technology for your needs, implementing proper error handling and resilience patterns, and maintaining comprehensive monitoring and observability. Whether you're building [microservices systems](/2025/09/microservices-golang-architecture-implementation-guide.html) or modernizing existing applications, event-driven patterns can significantly improve scalability and maintainability.

The investment in understanding event-driven architecture patterns pays dividends in building applications that can handle high throughput, provide better user experiences through asynchronous processing, and maintain system reliability even when individual components experience failures. As your systems grow in complexity, these patterns become essential tools for managing distributed system challenges while maintaining development velocity and operational stability.
