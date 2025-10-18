---
title: "How to Build AI/LLM Applications in Go - OpenAI and Ollama Integration"
description: "Complete guide to building AI applications in Go with OpenAI GPT-4 and local Ollama models. Learn API integration, streaming responses, prompt engineering, RAG systems, and production deployment patterns."
date: 2025-10-18T12:00:00+07:00
tags: ["Go", "AI", "LLM", "OpenAI", "Ollama", "Machine Learning", "Tutorial"]
draft: false
author: "Wiku Karno"
keywords: ["Go AI integration", "OpenAI Go SDK", "Ollama Golang", "LLM applications Go", "GPT-4 Golang tutorial", "AI chatbot Go", "RAG system Go", "streaming AI responses Go"]
url: /2025/10/how-to-build-ai-llm-applications-in-go-openai-and-ollama-integration.html

faq:
  - question: "What is the difference between OpenAI and Ollama for Go applications?"
    answer: "OpenAI is a cloud API service offering GPT-4 and other models with excellent quality but requires internet connection and costs per token. Ollama runs open-source models locally on your machine with zero cost per request, full privacy, and offline capability. Use OpenAI for best quality and scale, Ollama for privacy, cost control, and local development."

  - question: "How do I stream AI responses in real-time with Go?"
    answer: "Both OpenAI and Ollama SDKs support streaming. Create a stream request, iterate over response chunks using range, and write each chunk to your output immediately. For web applications, use Server-Sent Events (SSE) to push chunks to browsers. Enable streaming by setting Stream true in request options and process chunks as they arrive."

  - question: "What models should I use for different AI tasks in Go?"
    answer: "For production applications use GPT-4 Turbo for complex reasoning and analysis, GPT-3.5 Turbo for fast conversational AI and simple tasks, text-embedding-ada-002 for semantic search and RAG systems. For local Ollama use llama2 for general tasks, codellama for code generation, mistral for fast inference, and nomic-embed-text for embeddings. Choose based on quality needs, speed requirements, and budget."

  - question: "How do I implement RAG (Retrieval-Augmented Generation) in Go?"
    answer: "Build RAG by chunking documents into small pieces, generating embeddings for each chunk using OpenAI or Ollama, storing embeddings in a vector database like Qdrant or Milvus, retrieving relevant chunks based on query similarity, and injecting retrieved context into LLM prompts. This lets AI answer questions using your specific documents while avoiding hallucination."

  - question: "How much does it cost to run AI applications with OpenAI vs Ollama?"
    answer: "OpenAI charges per token: GPT-4 Turbo costs $0.01 per 1K input tokens and $0.03 per 1K output tokens, GPT-3.5 Turbo costs $0.0005 per 1K input and $0.0015 per 1K output. A typical chat costs $0.01-0.05. Ollama is completely free but requires local GPU or CPU resources. For high volume applications, Ollama can save thousands monthly but needs infrastructure investment."

  - question: "How do I handle AI errors and rate limits in production Go apps?"
    answer: "Implement exponential backoff retry logic for transient errors, catch rate limit responses and wait before retrying, set request timeouts to prevent hanging, validate API responses before using them, implement circuit breakers to prevent cascading failures, and monitor token usage to avoid unexpected costs. Always gracefully degrade when AI services are unavailable."

---

AI applications are everywhere now. Chatbots answering customer questions, code assistants writing functions, content generators creating blog posts, search systems understanding natural language. If you're building with Go, you need to know how to tap into these language models without fighting with complicated Python libraries or rewriting your entire stack.

The good news: integrating AI into Go applications is straightforward once you understand the patterns. You have two main paths - cloud APIs like OpenAI for maximum quality and scale, or local models with Ollama for privacy and cost control. Sometimes you want both.

This guide shows you how to build real AI features in Go. We'll start with OpenAI integration for GPT-4 and embeddings, move to running local models with Ollama, build streaming chat interfaces, implement semantic search with RAG (Retrieval-Augmented Generation), and cover all the production concerns like rate limiting, error handling, and cost optimization.

## Understanding LLMs and Go Integration

Large Language Models (LLMs) are neural networks trained on massive text datasets. They predict the next token (word or subword) based on previous context, which lets them generate human-like text, answer questions, write code, and more.

**OpenAI** provides cloud-hosted models like GPT-4, GPT-3.5 Turbo, and text embedding models. You send HTTP requests to their API with your prompt, they run inference on their servers, and stream back responses. Simple, scalable, but costs money and requires internet connectivity.

**Ollama** lets you run open-source models like Llama 2, Mistral, and CodeLlama locally on your machine. Download models once, run inference locally without API costs. Perfect for development, privacy-sensitive applications, or high-volume use cases where API costs add up.

**When to use each:**

OpenAI works best for production applications needing best-in-class quality, scale beyond your infrastructure, features like function calling and vision, or when you need embeddings for semantic search. The API is reliable, fast, and keeps improving.

Ollama shines for local development without API costs, applications requiring data privacy, high-volume batch processing where API costs would be prohibitive, or environments without reliable internet. Performance depends on your hardware - good GPU helps significantly.

## Prerequisites and Setup

Before we start coding, set up your environment.

### Installing Dependencies

Create a new Go project:

```bash
mkdir ai-go-tutorial
cd ai-go-tutorial
go mod init github.com/yourusername/ai-go-tutorial
```

Install the OpenAI Go SDK:

```bash
go get github.com/sashabaranov/go-openai
```

For Ollama, install the Ollama application first:

```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh

# Windows - download from ollama.com
```

Install the Ollama Go client:

```bash
go get github.com/ollama/ollama/api
```

### OpenAI API Setup

Sign up at platform.openai.com and create an API key from the API keys section. Never commit API keys to version control.

Set your API key as an environment variable:

```bash
export OPENAI_API_KEY=sk-your-api-key-here
```

For production, use secrets management like AWS Secrets Manager, HashiCorp Vault, or environment variables in your deployment platform.

### Ollama Setup

Start the Ollama service:

```bash
ollama serve
```

Download models you want to use:

```bash
# Download Llama 2 (4GB)
ollama pull llama2

# Download Mistral (4GB)
ollama pull mistral

# Download CodeLlama for code tasks
ollama pull codellama

# Download embedding model
ollama pull nomic-embed-text
```

Models download to ~/.ollama/models by default. Verify installation:

```bash
ollama list
```

## OpenAI Integration Basics

Let's start with the simplest possible integration - sending a prompt to GPT-4 and getting a response.

```go
// main.go
package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/sashabaranov/go-openai"
)

func main() {
	apiKey := os.Getenv("OPENAI_API_KEY")
	if apiKey == "" {
		log.Fatal("OPENAI_API_KEY environment variable not set")
	}

	client := openai.NewClient(apiKey)

	resp, err := client.CreateChatCompletion(
		context.Background(),
		openai.ChatCompletionRequest{
			Model: openai.GPT4TurboPreview,
			Messages: []openai.ChatCompletionMessage{
				{
					Role:    openai.ChatMessageRoleUser,
					Content: "Explain concurrency in Go in one paragraph",
				},
			},
		},
	)
	if err != nil {
		log.Fatalf("ChatCompletion error: %v", err)
	}

	fmt.Println(resp.Choices[0].Message.Content)
}
```

Run this:

```bash
go run main.go
```

You'll get a detailed explanation of Go concurrency from GPT-4. The response comes back in seconds.

### Understanding the Request Structure

Let's break down what's happening:

```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/sashabaranov/go-openai"
)

type ChatService struct {
	client *openai.Client
}

func NewChatService(apiKey string) *ChatService {
	return &ChatService{
		client: openai.NewClient(apiKey),
	}
}

func (s *ChatService) Chat(ctx context.Context, model string, messages []openai.ChatCompletionMessage) (string, error) {
	resp, err := s.client.CreateChatCompletion(ctx, openai.ChatCompletionRequest{
		Model:       model,
		Messages:    messages,
		Temperature: 0.7,
		MaxTokens:   1000,
	})
	if err != nil {
		return "", fmt.Errorf("chat completion failed: %w", err)
	}

	if len(resp.Choices) == 0 {
		return "", fmt.Errorf("no response choices returned")
	}

	return resp.Choices[0].Message.Content, nil
}

func main() {
	service := NewChatService(os.Getenv("OPENAI_API_KEY"))

	messages := []openai.ChatCompletionMessage{
		{
			Role:    openai.ChatMessageRoleSystem,
			Content: "You are a helpful Go programming expert",
		},
		{
			Role:    openai.ChatMessageRoleUser,
			Content: "How do channels work in Go?",
		},
	}

	response, err := service.Chat(context.Background(), openai.GPT4TurboPreview, messages)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}

	fmt.Println("AI Response:")
	fmt.Println(response)
}
```

**Model** specifies which AI model to use. GPT-4 Turbo is the latest and best, GPT-3.5 Turbo is faster and cheaper.

**Messages** is a conversation history. System messages set behavior, user messages are prompts, assistant messages are previous AI responses.

**Temperature** controls randomness (0-2). Lower values (0.2) give focused, deterministic responses. Higher values (0.8) give creative, varied responses.

**MaxTokens** limits response length. One token is roughly 4 characters in English. Set this to prevent unexpectedly long (expensive) responses.

### Building a Conversational Chat

Real chat applications maintain conversation history:

```go
package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/sashabaranov/go-openai"
)

type ConversationManager struct {
	client   *openai.Client
	messages []openai.ChatCompletionMessage
	model    string
}

func NewConversationManager(apiKey string, systemPrompt string) *ConversationManager {
	messages := []openai.ChatCompletionMessage{
		{
			Role:    openai.ChatMessageRoleSystem,
			Content: systemPrompt,
		},
	}

	return &ConversationManager{
		client:   openai.NewClient(apiKey),
		messages: messages,
		model:    openai.GPT4TurboPreview,
	}
}

func (cm *ConversationManager) SendMessage(ctx context.Context, userMessage string) (string, error) {
	// Add user message to history
	cm.messages = append(cm.messages, openai.ChatCompletionMessage{
		Role:    openai.ChatMessageRoleUser,
		Content: userMessage,
	})

	// Get AI response
	resp, err := cm.client.CreateChatCompletion(ctx, openai.ChatCompletionRequest{
		Model:    cm.model,
		Messages: cm.messages,
	})
	if err != nil {
		return "", fmt.Errorf("completion error: %w", err)
	}

	assistantMessage := resp.Choices[0].Message.Content

	// Add assistant response to history
	cm.messages = append(cm.messages, openai.ChatCompletionMessage{
		Role:    openai.ChatMessageRoleAssistant,
		Content: assistantMessage,
	})

	return assistantMessage, nil
}

func (cm *ConversationManager) GetMessageCount() int {
	return len(cm.messages)
}

func main() {
	apiKey := os.Getenv("OPENAI_API_KEY")
	if apiKey == "" {
		log.Fatal("OPENAI_API_KEY not set")
	}

	conversation := NewConversationManager(
		apiKey,
		"You are a helpful assistant that explains Go programming concepts clearly.",
	)

	fmt.Println("Chat with AI (type 'quit' to exit)")
	fmt.Println("----------------------------------------")

	scanner := bufio.NewScanner(os.Stdin)

	for {
		fmt.Print("You: ")
		if !scanner.Scan() {
			break
		}

		userInput := strings.TrimSpace(scanner.Text())
		if userInput == "" {
			continue
		}

		if userInput == "quit" {
			fmt.Println("Goodbye!")
			break
		}

		response, err := conversation.SendMessage(context.Background(), userInput)
		if err != nil {
			log.Printf("Error: %v", err)
			continue
		}

		fmt.Printf("AI: %s\n\n", response)
	}
}
```

This maintains full conversation context. The AI remembers what you discussed earlier, so follow-up questions work naturally. Watch token usage though - long conversations accumulate tokens quickly.

## Streaming Responses for Better UX

Nobody wants to stare at a blank screen for 10 seconds waiting for a response. Streaming shows text as it generates, giving users immediate feedback.

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/sashabaranov/go-openai"
)

func streamChat(client *openai.Client, prompt string) error {
	ctx := context.Background()

	req := openai.ChatCompletionRequest{
		Model: openai.GPT4TurboPreview,
		Messages: []openai.ChatCompletionMessage{
			{
				Role:    openai.ChatMessageRoleUser,
				Content: prompt,
			},
		},
		Stream: true,
	}

	stream, err := client.CreateChatCompletionStream(ctx, req)
	if err != nil {
		return fmt.Errorf("stream creation failed: %w", err)
	}
	defer stream.Close()

	fmt.Print("AI: ")

	for {
		response, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			fmt.Println("\n")
			return nil
		}

		if err != nil {
			return fmt.Errorf("stream error: %w", err)
		}

		if len(response.Choices) > 0 {
			fmt.Print(response.Choices[0].Delta.Content)
		}
	}
}

func main() {
	client := openai.NewClient(os.Getenv("OPENAI_API_KEY"))

	err := streamChat(client, "Write a haiku about Go programming")
	if err != nil {
		log.Fatalf("Error: %v", err)
	}
}
```

Run this and you'll see the response appear word by word, just like ChatGPT's interface. Much better UX than waiting for everything.

### Streaming to Web Clients with SSE

For web applications, use Server-Sent Events to push chunks to browsers:

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	"github.com/sashabaranov/go-openai"
)

func streamHandler(w http.ResponseWriter, r *http.Request) {
	prompt := r.URL.Query().Get("prompt")
	if prompt == "" {
		http.Error(w, "prompt parameter required", http.StatusBadRequest)
		return
	}

	// Set headers for SSE
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	client := openai.NewClient(os.Getenv("OPENAI_API_KEY"))

	req := openai.ChatCompletionRequest{
		Model: openai.GPT35Turbo,
		Messages: []openai.ChatCompletionMessage{
			{
				Role:    openai.ChatMessageRoleUser,
				Content: prompt,
			},
		},
		Stream: true,
	}

	stream, err := client.CreateChatCompletionStream(context.Background(), req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer stream.Close()

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
		return
	}

	for {
		response, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			fmt.Fprintf(w, "data: [DONE]\n\n")
			flusher.Flush()
			return
		}

		if err != nil {
			log.Printf("Stream error: %v", err)
			return
		}

		if len(response.Choices) > 0 {
			content := response.Choices[0].Delta.Content
			fmt.Fprintf(w, "data: %s\n\n", content)
			flusher.Flush()
		}
	}
}

func main() {
	http.HandleFunc("/stream", streamHandler)

	fmt.Println("Server starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
```

Test it:

```bash
curl "http://localhost:8080/stream?prompt=Explain%20goroutines"
```

You'll see chunks arrive in real-time. Frontend code can consume this with EventSource API.

## Ollama Integration for Local AI

Running models locally with Ollama gives you zero API costs and complete privacy. The API is similar to OpenAI's.

### Basic Ollama Chat

```go
package main

import (
	"context"
	"fmt"
	"log"

	"github.com/ollama/ollama/api"
)

func main() {
	client, err := api.ClientFromEnvironment()
	if err != nil {
		log.Fatal(err)
	}

	req := &api.ChatRequest{
		Model: "llama2",
		Messages: []api.Message{
			{
				Role:    "user",
				Content: "Explain goroutines in one paragraph",
			},
		},
	}

	ctx := context.Background()

	err = client.Chat(ctx, req, func(resp api.ChatResponse) error {
		fmt.Print(resp.Message.Content)
		return nil
	})

	if err != nil {
		log.Fatal(err)
	}

	fmt.Println()
}
```

This uses Llama 2 running locally. First run will be slow as it loads the model into memory. Subsequent requests are faster.

### Ollama Chat Service

Create a reusable service:

```go
package main

import (
	"context"
	"fmt"

	"github.com/ollama/ollama/api"
)

type OllamaService struct {
	client *api.Client
	model  string
}

func NewOllamaService(model string) (*OllamaService, error) {
	client, err := api.ClientFromEnvironment()
	if err != nil {
		return nil, fmt.Errorf("failed to create client: %w", err)
	}

	return &OllamaService{
		client: client,
		model:  model,
	}, nil
}

func (s *OllamaService) Chat(ctx context.Context, prompt string) (string, error) {
	var fullResponse string

	req := &api.ChatRequest{
		Model: s.model,
		Messages: []api.Message{
			{
				Role:    "user",
				Content: prompt,
			},
		},
	}

	err := s.client.Chat(ctx, req, func(resp api.ChatResponse) error {
		fullResponse += resp.Message.Content
		return nil
	})

	if err != nil {
		return "", fmt.Errorf("chat failed: %w", err)
	}

	return fullResponse, nil
}

func (s *OllamaService) ChatWithHistory(ctx context.Context, messages []api.Message) (string, error) {
	var fullResponse string

	req := &api.ChatRequest{
		Model:    s.model,
		Messages: messages,
	}

	err := s.client.Chat(ctx, req, func(resp api.ChatResponse) error {
		fullResponse += resp.Message.Content
		return nil
	})

	if err != nil {
		return "", fmt.Errorf("chat failed: %w", err)
	}

	return fullResponse, nil
}

func main() {
	service, err := NewOllamaService("llama2")
	if err != nil {
		log.Fatal(err)
	}

	response, err := service.Chat(context.Background(), "What is the main benefit of using Go?")
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println(response)
}
```

### Comparing OpenAI and Ollama Performance

Here's a service that tries OpenAI first, falls back to Ollama:

```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/ollama/ollama/api"
	"github.com/sashabaranov/go-openai"
)

type AIService struct {
	openaiClient *openai.Client
	ollamaClient *api.Client
	useOpenAI    bool
}

func NewAIService(useOpenAI bool) (*AIService, error) {
	service := &AIService{
		useOpenAI: useOpenAI,
	}

	if useOpenAI {
		apiKey := os.Getenv("OPENAI_API_KEY")
		if apiKey == "" {
			return nil, fmt.Errorf("OPENAI_API_KEY not set")
		}
		service.openaiClient = openai.NewClient(apiKey)
	}

	ollamaClient, err := api.ClientFromEnvironment()
	if err != nil {
		return nil, fmt.Errorf("ollama client failed: %w", err)
	}
	service.ollamaClient = ollamaClient

	return service, nil
}

func (s *AIService) Generate(ctx context.Context, prompt string) (string, time.Duration, error) {
	start := time.Now()

	if s.useOpenAI {
		response, err := s.generateWithOpenAI(ctx, prompt)
		return response, time.Since(start), err
	}

	response, err := s.generateWithOllama(ctx, prompt)
	return response, time.Since(start), err
}

func (s *AIService) generateWithOpenAI(ctx context.Context, prompt string) (string, error) {
	resp, err := s.openaiClient.CreateChatCompletion(ctx, openai.ChatCompletionRequest{
		Model: openai.GPT35Turbo,
		Messages: []openai.ChatCompletionMessage{
			{
				Role:    openai.ChatMessageRoleUser,
				Content: prompt,
			},
		},
	})
	if err != nil {
		return "", err
	}

	return resp.Choices[0].Message.Content, nil
}

func (s *AIService) generateWithOllama(ctx context.Context, prompt string) (string, error) {
	var fullResponse string

	req := &api.ChatRequest{
		Model: "llama2",
		Messages: []api.Message{
			{
				Role:    "user",
				Content: prompt,
			},
		},
	}

	err := s.ollamaClient.Chat(ctx, req, func(resp api.ChatResponse) error {
		fullResponse += resp.Message.Content
		return nil
	})

	return fullResponse, err
}

func main() {
	prompt := "Write a function in Go that reverses a string"

	// Test OpenAI
	openaiService, _ := NewAIService(true)
	response, duration, err := openaiService.Generate(context.Background(), prompt)
	if err != nil {
		log.Printf("OpenAI error: %v", err)
	} else {
		fmt.Printf("OpenAI (%v):\n%s\n\n", duration, response)
	}

	// Test Ollama
	ollamaService, _ := NewAIService(false)
	response, duration, err = ollamaService.Generate(context.Background(), prompt)
	if err != nil {
		log.Printf("Ollama error: %v", err)
	} else {
		fmt.Printf("Ollama (%v):\n%s\n\n", duration, response)
	}
}
```

This lets you compare response quality and speed between providers.

## Building a RAG System with Embeddings

RAG (Retrieval-Augmented Generation) lets AI answer questions using your specific documents. Instead of hallucinating, the AI pulls relevant info from your knowledge base.

The process:
1. Split documents into chunks
2. Generate embeddings (vector representations) for each chunk
3. Store embeddings in a vector database
4. When user asks a question, find similar chunks
5. Include relevant chunks in the AI prompt
6. AI answers based on provided context

### Generating Embeddings with OpenAI

```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/sashabaranov/go-openai"
)

type EmbeddingService struct {
	client *openai.Client
}

func NewEmbeddingService(apiKey string) *EmbeddingService {
	return &EmbeddingService{
		client: openai.NewClient(apiKey),
	}
}

func (s *EmbeddingService) GenerateEmbedding(ctx context.Context, text string) ([]float32, error) {
	req := openai.EmbeddingRequest{
		Input: []string{text},
		Model: openai.AdaEmbeddingV2,
	}

	resp, err := s.client.CreateEmbeddings(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("embedding generation failed: %w", err)
	}

	if len(resp.Data) == 0 {
		return nil, fmt.Errorf("no embeddings returned")
	}

	return resp.Data[0].Embedding, nil
}

func (s *EmbeddingService) GenerateBatchEmbeddings(ctx context.Context, texts []string) ([][]float32, error) {
	req := openai.EmbeddingRequest{
		Input: texts,
		Model: openai.AdaEmbeddingV2,
	}

	resp, err := s.client.CreateEmbeddings(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("batch embedding failed: %w", err)
	}

	embeddings := make([][]float32, len(resp.Data))
	for i, data := range resp.Data {
		embeddings[i] = data.Embedding
	}

	return embeddings, nil
}

func main() {
	service := NewEmbeddingService(os.Getenv("OPENAI_API_KEY"))

	texts := []string{
		"Go is a statically typed, compiled programming language",
		"Goroutines are lightweight threads managed by the Go runtime",
		"Channels are the pipes that connect concurrent goroutines",
	}

	embeddings, err := service.GenerateBatchEmbeddings(context.Background(), texts)
	if err != nil {
		log.Fatal(err)
	}

	for i, emb := range embeddings {
		fmt.Printf("Text %d: %d dimensions\n", i+1, len(emb))
		fmt.Printf("First 5 values: %v\n\n", emb[:5])
	}
}
```

Embeddings are 1536-dimensional vectors representing semantic meaning. Similar texts have similar vectors.

### Simple In-Memory Vector Search

Before using a real vector database, here's a simple similarity search:

```go
package main

import (
	"context"
	"fmt"
	"log"
	"math"
	"os"
	"sort"

	"github.com/sashabaranov/go-openai"
)

type Document struct {
	Text      string
	Embedding []float32
}

type VectorStore struct {
	documents []Document
	embedSvc  *EmbeddingService
}

func NewVectorStore(embedSvc *EmbeddingService) *VectorStore {
	return &VectorStore{
		documents: make([]Document, 0),
		embedSvc:  embedSvc,
	}
}

func (vs *VectorStore) AddDocument(ctx context.Context, text string) error {
	embedding, err := vs.embedSvc.GenerateEmbedding(ctx, text)
	if err != nil {
		return err
	}

	vs.documents = append(vs.documents, Document{
		Text:      text,
		Embedding: embedding,
	})

	return nil
}

func cosineSimilarity(a, b []float32) float32 {
	var dotProduct, magA, magB float32

	for i := range a {
		dotProduct += a[i] * b[i]
		magA += a[i] * a[i]
		magB += b[i] * b[i]
	}

	if magA == 0 || magB == 0 {
		return 0
	}

	return dotProduct / (float32(math.Sqrt(float64(magA))) * float32(math.Sqrt(float64(magB))))
}

func (vs *VectorStore) Search(ctx context.Context, query string, topK int) ([]Document, error) {
	queryEmbedding, err := vs.embedSvc.GenerateEmbedding(ctx, query)
	if err != nil {
		return nil, err
	}

	type scored struct {
		doc   Document
		score float32
	}

	scores := make([]scored, len(vs.documents))
	for i, doc := range vs.documents {
		similarity := cosineSimilarity(queryEmbedding, doc.Embedding)
		scores[i] = scored{doc: doc, score: similarity}
	}

	sort.Slice(scores, func(i, j int) bool {
		return scores[i].score > scores[j].score
	})

	if topK > len(scores) {
		topK = len(scores)
	}

	results := make([]Document, topK)
	for i := 0; i < topK; i++ {
		results[i] = scores[i].doc
	}

	return results, nil
}

func main() {
	embedSvc := NewEmbeddingService(os.Getenv("OPENAI_API_KEY"))
	vectorStore := NewVectorStore(embedSvc)

	ctx := context.Background()

	// Add documents
	documents := []string{
		"Go was created at Google by Robert Griesemer, Rob Pike, and Ken Thompson",
		"Goroutines are functions that run concurrently with other functions",
		"Go's garbage collector uses a concurrent mark-and-sweep algorithm",
		"Channels provide a way for goroutines to communicate with each other",
		"The Go compiler produces statically linked binaries with no external dependencies",
	}

	fmt.Println("Adding documents to vector store...")
	for _, doc := range documents {
		if err := vectorStore.AddDocument(ctx, doc); err != nil {
			log.Fatal(err)
		}
	}

	// Search
	query := "How do goroutines communicate?"
	results, err := vectorStore.Search(ctx, query, 2)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("\nQuery: %s\n", query)
	fmt.Println("\nTop results:")
	for i, result := range results {
		fmt.Printf("%d. %s\n", i+1, result.Text)
	}
}
```

This finds the most relevant documents for a query. In production, use a proper vector database like Qdrant, Milvus, or Pinecone.

### Complete RAG Implementation

Combine retrieval with generation:

```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/sashabaranov/go-openai"
)

type RAGSystem struct {
	vectorStore *VectorStore
	chatClient  *openai.Client
}

func NewRAGSystem(apiKey string) (*RAGSystem, error) {
	embedSvc := NewEmbeddingService(apiKey)
	vectorStore := NewVectorStore(embedSvc)

	return &RAGSystem{
		vectorStore: vectorStore,
		chatClient:  openai.NewClient(apiKey),
	}, nil
}

func (rag *RAGSystem) AddKnowledge(ctx context.Context, texts []string) error {
	for _, text := range texts {
		if err := rag.vectorStore.AddDocument(ctx, text); err != nil {
			return fmt.Errorf("failed to add document: %w", err)
		}
	}
	return nil
}

func (rag *RAGSystem) Ask(ctx context.Context, question string) (string, error) {
	// Retrieve relevant documents
	relevantDocs, err := rag.vectorStore.Search(ctx, question, 3)
	if err != nil {
		return "", fmt.Errorf("search failed: %w", err)
	}

	// Build context from retrieved documents
	var contextParts []string
	for _, doc := range relevantDocs {
		contextParts = append(contextParts, doc.Text)
	}
	context := strings.Join(contextParts, "\n\n")

	// Create prompt with context
	prompt := fmt.Sprintf(`Answer the question based on the following context. If the answer is not in the context, say "I don't have enough information to answer that."

Context:
%s

Question: %s

Answer:`, context, question)

	// Get AI response
	resp, err := rag.chatClient.CreateChatCompletion(ctx, openai.ChatCompletionRequest{
		Model: openai.GPT4TurboPreview,
		Messages: []openai.ChatCompletionMessage{
			{
				Role:    openai.ChatMessageRoleUser,
				Content: prompt,
			},
		},
		Temperature: 0.3,
	})
	if err != nil {
		return "", fmt.Errorf("chat completion failed: %w", err)
	}

	return resp.Choices[0].Message.Content, nil
}

func main() {
	apiKey := os.Getenv("OPENAI_API_KEY")
	if apiKey == "" {
		log.Fatal("OPENAI_API_KEY not set")
	}

	rag, err := NewRAGSystem(apiKey)
	if err != nil {
		log.Fatal(err)
	}

	ctx := context.Background()

	// Add knowledge base
	knowledge := []string{
		"BuanaCoding is a programming tutorial website focused on Go, PHP, and JavaScript.",
		"The site was created by Wiku Karno in 2024.",
		"BuanaCoding provides tutorials on REST APIs, authentication, databases, and deployment.",
		"All tutorials include complete code examples and production best practices.",
		"The site uses Hugo static site generator and is deployed on GitHub Pages.",
	}

	fmt.Println("Building knowledge base...")
	if err := rag.AddKnowledge(ctx, knowledge); err != nil {
		log.Fatal(err)
	}

	// Ask questions
	questions := []string{
		"Who created BuanaCoding?",
		"What programming languages does BuanaCoding cover?",
		"What is the capital of France?", // Not in knowledge base
	}

	for _, question := range questions {
		fmt.Printf("\nQuestion: %s\n", question)

		answer, err := rag.Ask(ctx, question)
		if err != nil {
			log.Printf("Error: %v", err)
			continue
		}

		fmt.Printf("Answer: %s\n", answer)
	}
}
```

The RAG system retrieves relevant context before answering. This prevents hallucination and grounds answers in your actual documents.

## Production Considerations

Development demos are fun, but production AI apps need proper error handling, rate limiting, monitoring, and cost control.

### Rate Limiting and Retry Logic

```go
package main

import (
	"context"
	"fmt"
	"time"

	"github.com/sashabaranov/go-openai"
)

type RateLimitedClient struct {
	client     *openai.Client
	maxRetries int
	baseDelay  time.Duration
}

func NewRateLimitedClient(apiKey string) *RateLimitedClient {
	return &RateLimitedClient{
		client:     openai.NewClient(apiKey),
		maxRetries: 3,
		baseDelay:  time.Second,
	}
}

func (rlc *RateLimitedClient) ChatWithRetry(ctx context.Context, req openai.ChatCompletionRequest) (*openai.ChatCompletionResponse, error) {
	var lastErr error

	for attempt := 0; attempt < rlc.maxRetries; attempt++ {
		resp, err := rlc.client.CreateChatCompletion(ctx, req)
		if err == nil {
			return &resp, nil
		}

		lastErr = err

		// Check if it's a rate limit error
		if isRateLimitError(err) {
			delay := rlc.baseDelay * time.Duration(1<<uint(attempt))
			fmt.Printf("Rate limited, retrying in %v...\n", delay)
			time.Sleep(delay)
			continue
		}

		// For other errors, don't retry
		return nil, err
	}

	return nil, fmt.Errorf("max retries exceeded: %w", lastErr)
}

func isRateLimitError(err error) bool {
	// Check error message for rate limit indicators
	errMsg := err.Error()
	return contains(errMsg, "rate limit") || contains(errMsg, "429")
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > len(substr) && (s[:len(substr)] == substr || s[len(s)-len(substr):] == substr || containsInner(s, substr)))
}

func containsInner(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

func main() {
	client := NewRateLimitedClient(os.Getenv("OPENAI_API_KEY"))

	req := openai.ChatCompletionRequest{
		Model: openai.GPT35Turbo,
		Messages: []openai.ChatCompletionMessage{
			{
				Role:    openai.ChatMessageRoleUser,
				Content: "Hello!",
			},
		},
	}

	resp, err := client.ChatWithRetry(context.Background(), req)
	if err != nil {
		log.Fatalf("Request failed: %v", err)
	}

	fmt.Println(resp.Choices[0].Message.Content)
}
```

### Cost Tracking and Token Counting

```go
package main

import (
	"context"
	"fmt"
	"sync"

	"github.com/sashabaranov/go-openai"
)

type CostTracker struct {
	client          *openai.Client
	totalTokens     int
	totalCost       float64
	mu              sync.Mutex
	inputPricePerK  float64
	outputPricePerK float64
}

func NewCostTracker(apiKey string, model string) *CostTracker {
	ct := &CostTracker{
		client: openai.NewClient(apiKey),
	}

	// Set prices based on model
	switch model {
	case openai.GPT4TurboPreview:
		ct.inputPricePerK = 0.01
		ct.outputPricePerK = 0.03
	case openai.GPT35Turbo:
		ct.inputPricePerK = 0.0005
		ct.outputPricePerK = 0.0015
	default:
		ct.inputPricePerK = 0.001
		ct.outputPricePerK = 0.002
	}

	return ct
}

func (ct *CostTracker) Chat(ctx context.Context, req openai.ChatCompletionRequest) (string, error) {
	resp, err := ct.client.CreateChatCompletion(ctx, req)
	if err != nil {
		return "", err
	}

	// Track usage
	ct.mu.Lock()
	inputTokens := resp.Usage.PromptTokens
	outputTokens := resp.Usage.CompletionTokens
	ct.totalTokens += resp.Usage.TotalTokens

	inputCost := float64(inputTokens) / 1000.0 * ct.inputPricePerK
	outputCost := float64(outputTokens) / 1000.0 * ct.outputPricePerK
	ct.totalCost += inputCost + outputCost
	ct.mu.Unlock()

	return resp.Choices[0].Message.Content, nil
}

func (ct *CostTracker) GetStats() (int, float64) {
	ct.mu.Lock()
	defer ct.mu.Unlock()
	return ct.totalTokens, ct.totalCost
}

func main() {
	tracker := NewCostTracker(os.Getenv("OPENAI_API_KEY"), openai.GPT4TurboPreview)

	questions := []string{
		"What is Go?",
		"Explain goroutines",
		"How do channels work?",
	}

	for _, q := range questions {
		req := openai.ChatCompletionRequest{
			Model: openai.GPT4TurboPreview,
			Messages: []openai.ChatCompletionMessage{
				{Role: openai.ChatMessageRoleUser, Content: q},
			},
		}

		answer, err := tracker.Chat(context.Background(), req)
		if err != nil {
			log.Printf("Error: %v", err)
			continue
		}

		fmt.Printf("Q: %s\nA: %s\n\n", q, answer)
	}

	tokens, cost := tracker.GetStats()
	fmt.Printf("Total tokens used: %d\n", tokens)
	fmt.Printf("Total cost: $%.4f\n", cost)
}
```

This tracks API costs in real-time, essential for production applications with budgets.

### Error Handling and Graceful Degradation

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/ollama/ollama/api"
	"github.com/sashabaranov/go-openai"
)

type ResilientAI struct {
	openaiClient *openai.Client
	ollamaClient *api.Client
	useOpenAI    bool
	timeout      time.Duration
}

func NewResilientAI() (*ResilientAI, error) {
	rai := &ResilientAI{
		timeout: 30 * time.Second,
	}

	// Try OpenAI first
	if apiKey := os.Getenv("OPENAI_API_KEY"); apiKey != "" {
		rai.openaiClient = openai.NewClient(apiKey)
		rai.useOpenAI = true
	}

	// Set up Ollama as fallback
	ollamaClient, err := api.ClientFromEnvironment()
	if err == nil {
		rai.ollamaClient = ollamaClient
	}

	if rai.openaiClient == nil && rai.ollamaClient == nil {
		return nil, errors.New("no AI backends available")
	}

	return rai, nil
}

func (rai *ResilientAI) Generate(ctx context.Context, prompt string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, rai.timeout)
	defer cancel()

	// Try OpenAI first if available
	if rai.useOpenAI && rai.openaiClient != nil {
		resp, err := rai.tryOpenAI(ctx, prompt)
		if err == nil {
			return resp, nil
		}
		log.Printf("OpenAI failed: %v, falling back to Ollama", err)
	}

	// Fall back to Ollama
	if rai.ollamaClient != nil {
		resp, err := rai.tryOllama(ctx, prompt)
		if err == nil {
			return resp, nil
		}
		log.Printf("Ollama failed: %v", err)
	}

	return "", errors.New("all AI backends failed")
}

func (rai *ResilientAI) tryOpenAI(ctx context.Context, prompt string) (string, error) {
	resp, err := rai.openaiClient.CreateChatCompletion(ctx, openai.ChatCompletionRequest{
		Model: openai.GPT35Turbo,
		Messages: []openai.ChatCompletionMessage{
			{Role: openai.ChatMessageRoleUser, Content: prompt},
		},
	})
	if err != nil {
		return "", err
	}
	return resp.Choices[0].Message.Content, nil
}

func (rai *ResilientAI) tryOllama(ctx context.Context, prompt string) (string, error) {
	var response string

	req := &api.ChatRequest{
		Model: "llama2",
		Messages: []api.Message{
			{Role: "user", Content: prompt},
		},
	}

	err := rai.ollamaClient.Chat(ctx, req, func(resp api.ChatResponse) error {
		response += resp.Message.Content
		return nil
	})

	return response, err
}

func main() {
	ai, err := NewResilientAI()
	if err != nil {
		log.Fatal(err)
	}

	response, err := ai.Generate(context.Background(), "Explain Go interfaces")
	if err != nil {
		log.Fatalf("All backends failed: %v", err)
	}

	fmt.Println(response)
}
```

This automatically falls back from OpenAI to Ollama if the cloud service is down or rate-limited.

## Wrapping Up

Building AI features in Go is straightforward once you understand the APIs. OpenAI gives you best-in-class quality through simple HTTP calls. Ollama lets you run models locally for privacy and cost savings. Both integrate cleanly into Go applications.

The patterns covered here - streaming responses, conversation management, RAG systems, error handling - apply to most AI features you'll build. Start simple with basic completions, add streaming for better UX, implement RAG when you need document-grounded answers, and layer in production concerns like rate limiting and cost tracking.

For production applications, use OpenAI for quality and reliability, implement proper error handling and retries, track token usage and costs, consider Ollama for high-volume or privacy-sensitive workloads, and monitor AI performance and accuracy over time.

To build complete AI-powered applications, combine these patterns with other Go features. Use [Redis for caching](/2025/08/how-to-use-redis-with-go-caching-session-management.html) AI responses to reduce API costs, implement [rate limiting](/2025/08/how-to-implement-rate-limiting-in-go-protect-api.html) to prevent API abuse, add [JWT authentication](/2025/08/how-to-implement-jwt-authentication-in-go-secure-rest-api.html) to secure your AI endpoints, and use [WebSockets](/2025/09/how-to-build-websocket-applications-in-go-real-time-chat.html) for real-time streaming chat interfaces. For storing conversation history and user data, check out our guides on [working with PostgreSQL](/2025/09/connecting-postgresql-in-go-using-sqlx.html) or [MongoDB](/2025/08/how-to-work-with-mongodb-in-go-complete-crud-tutorial.html).

The AI landscape moves fast, but the fundamentals stay stable. Understanding embeddings, prompts, and API patterns gives you a foundation that works regardless of which models you use. Build iteratively, measure results, and keep improving based on real user feedback.
