---
title: "FastAPI Tutorial Build REST API from Scratch (Beginner Guide)"
date: 2025-08-25T07:00:00.000+07:00
draft: false
url: /2025/08/fastapi-tutorial-build-rest-api-from-scratch-beginner-guide.html
tags:
  - Python
  - FastAPI
  - REST API
  - Tutorial
  - Beginner
description: "Learn how to build a complete REST API from scratch using FastAPI. This beginner-friendly tutorial covers everything from setup to deployment with practical examples and clear explanations."
keywords: ["fastapi", "python", "rest api", "tutorial", "beginner", "web development", "api development", "fastapi tutorial"]
---

Building APIs used to scare me when I first started programming. There's so much to learn - databases, HTTP methods, authentication, error handling. But FastAPI changed everything for me. It's like having training wheels that actually make you faster, not slower.

We're going to build a real Book Library API from the ground up. No fluff, no complicated setups - just practical, working code that you can understand and expand on. By the end of this guide, you'll have a fully functional REST API that can handle creating, reading, updating, and deleting books.

Once you master the basics here, you can take your FastAPI skills further with [JWT authentication and OAuth2 security]({{< relref "blog/python/fastapi-jwt-auth-oauth2-password-flow-pydantic-v2-sqlalchemy-2.md" >}}), or learn how to [deploy your FastAPI application to production]({{< relref "blog/python/deploy-fastapi-ubuntu-24-04-gunicorn-nginx-certbot.md" >}}).

<!--readmore-->

I'm not going to throw a bunch of code at you and hope it sticks. We'll walk through each piece together, and I'll explain why we're doing things a certain way. Think of it as pair programming through an article. Everything runs locally too - no cloud accounts or credit cards needed.

What you'll build:
- A complete Book Library REST API
- CRUD operations (Create, Read, Update, Delete)
- Data validation with Pydantic
- SQLite database integration  
- Interactive API documentation
- Error handling and responses
- Testing with real HTTP requests

## Prerequisites

Before we dive in, make sure you have:
- Python 3.8 or higher installed
- Basic Python knowledge (variables, functions, classes)
- A code editor (VS Code, PyCharm, or any text editor)
- Command line familiarity

Don't worry if you're not an expert in any of these - we'll explain everything as we go.

## Why FastAPI?

Why FastAPI and not Django or Flask? Good question. I've used all three in production, and here's my take: Django feels like driving a truck when you need a motorcycle. Flask is that motorcycle, but you end up building the truck yourself anyway. FastAPI? It's like a sports car that comes with GPS, heated seats, and a great sound system right out of the box.

FastAPI automatically generates interactive documentation for your API, validates request data, and handles serialization. These features alone save hours of manual work. Plus, it's built on modern Python features like type hints, making your code more readable and less bug-prone.

## Setting Up the Development Environment

First things first - let's set up a proper workspace. Open your terminal and create a new directory:

```bash
mkdir book-library-api
cd book-library-api
```

Now create a virtual environment. This keeps our project dependencies separate from other Python projects on your system:

```bash
python -m venv venv
```

Activate the virtual environment:

**On Windows:**
```bash
venv\Scripts\activate
```

**On macOS/Linux:**
```bash
source venv/bin/activate
```

You should see `(venv)` at the beginning of your command prompt, indicating the virtual environment is active.

## Installing Dependencies

We need just a few packages to get started:

```bash
pip install fastapi uvicorn sqlalchemy
```

Here's what each package does:
- **FastAPI**: The web framework itself
- **Uvicorn**: ASGI server to run our application
- **SQLAlchemy**: Database ORM (Object-Relational Mapping)

Let's also create a requirements.txt file to track our dependencies:

```bash
pip freeze > requirements.txt
```

## Project Structure

Good organization makes your code easier to understand and maintain. Create this folder structure:

```bash
mkdir app
mkdir app/models
mkdir app/schemas
mkdir app/database
touch app/__init__.py
touch app/main.py
touch app/models/__init__.py
touch app/models/book.py
touch app/schemas/__init__.py
touch app/schemas/book.py
touch app/database/__init__.py
touch app/database/database.py
```

Your project should now look like this:

```
book-library-api/
├── venv/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── models/
│   │   ├── __init__.py
│   │   └── book.py
│   ├── schemas/
│   │   ├── __init__.py
│   │   └── book.py
│   └── database/
│       ├── __init__.py
│       └── database.py
└── requirements.txt
```

This structure separates different parts of our application, making it easier to find and modify code later.

## Database Setup

Let's start by setting up our database connection. We'll use SQLite because it's simple and doesn't require a separate database server.

Create the database configuration:

```python
# app/database/database.py
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# SQLite database file
SQLALCHEMY_DATABASE_URL = "sqlite:///./books.db"

# Create engine
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, 
    connect_args={"check_same_thread": False}
)

# Create session
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()

# Dependency to get database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

This code sets up our database connection. The `get_db()` function is a dependency that FastAPI will use to provide database sessions to our API endpoints.

## Creating the Database Model

Now let's define what a book looks like in our database:

```python
# app/models/book.py
from sqlalchemy import Column, Integer, String, Text
from app.database.database import Base

class Book(Base):
    __tablename__ = "books"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    author = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    published_year = Column(Integer, nullable=True)
    isbn = Column(String(20), unique=True, nullable=True)
```

This model defines our book structure with fields for title, author, description, publication year, and ISBN. The `__tablename__` tells SQLAlchemy what to name the table in the database.

## Pydantic Schemas

Pydantic schemas define how data should look when it comes into or goes out of our API. Think of them as contracts that ensure data consistency:

```python
# app/schemas/book.py
from pydantic import BaseModel
from typing import Optional, List, Any

class BookBase(BaseModel):
    title: str
    author: str
    description: Optional[str] = None
    published_year: Optional[int] = None
    isbn: Optional[str] = None

class BookCreate(BookBase):
    pass

class BookUpdate(BaseModel):
    title: Optional[str] = None
    author: Optional[str] = None
    description: Optional[str] = None
    published_year: Optional[int] = None
    isbn: Optional[str] = None

class BookResponse(BookBase):
    id: int
    
    class Config:
        from_attributes = True

# Standard API Response Schemas
class Meta(BaseModel):
    success: bool
    message: str
    total: Optional[int] = None
    page: Optional[int] = None
    limit: Optional[int] = None
    total_pages: Optional[int] = None

class StandardResponse(BaseModel):
    meta: Meta
    data: Any

class BookListResponse(BaseModel):
    meta: Meta
    data: List[BookResponse]

class SingleBookResponse(BaseModel):
    meta: Meta
    data: BookResponse
```

We have different schemas for different purposes:
- `BookBase`: Common fields for all book operations
- `BookCreate`: For creating new books (inherits from BookBase)
- `BookUpdate`: For updating existing books (all fields optional)
- `BookResponse`: For returning book data (includes the ID)
- `Meta`: Metadata for API responses (success status, pagination info)
- `StandardResponse`: Generic response wrapper with meta and data
- `BookListResponse`: Specific response for book lists
- `SingleBookResponse`: Specific response for single book operations

This standard response format makes your API more consistent and easier to consume by frontend applications or other services.

## Building the FastAPI Application

Now for the main event - creating our FastAPI application:

```python
# app/main.py
from fastapi import FastAPI, HTTPException, Depends, status
from sqlalchemy.orm import Session
from typing import List
import math
from app.database.database import engine, get_db
from app.models import book as book_models
from app.schemas import book as book_schemas

# Create database tables
book_models.Base.metadata.create_all(bind=engine)

# Initialize FastAPI app
app = FastAPI(
    title="Book Library API",
    description="A simple REST API for managing books with standardized responses",
    version="1.0.0"
)

# Helper function to create standard responses
def create_response(success: bool, message: str, data=None, total=None, page=None, limit=None):
    meta = book_schemas.Meta(
        success=success,
        message=message,
        total=total,
        page=page,
        limit=limit,
        total_pages=math.ceil(total / limit) if total and limit else None
    )
    return book_schemas.StandardResponse(meta=meta, data=data)

# Root endpoint
@app.get("/")
def read_root():
    return create_response(
        success=True,
        message="Welcome to Book Library API",
        data={"version": "1.0.0", "status": "running"}
    )

# Health check endpoint
@app.get("/health")
def health_check():
    return create_response(
        success=True,
        message="API is healthy",
        data={"status": "healthy", "timestamp": "2024-01-01T00:00:00Z"}
    )

# Get all books
@app.get("/books", response_model=book_schemas.BookListResponse)
def get_books(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    # Get total count for pagination
    total_books = db.query(book_models.Book).count()
    
    # Get books with pagination
    books = db.query(book_models.Book).offset(skip).limit(limit).all()
    
    current_page = (skip // limit) + 1
    
    meta = book_schemas.Meta(
        success=True,
        message="Books retrieved successfully",
        total=total_books,
        page=current_page,
        limit=limit,
        total_pages=math.ceil(total_books / limit) if total_books > 0 else 0
    )
    
    return book_schemas.BookListResponse(meta=meta, data=books)

# Get single book by ID
@app.get("/books/{book_id}", response_model=book_schemas.SingleBookResponse)
def get_book(book_id: int, db: Session = Depends(get_db)):
    book = db.query(book_models.Book).filter(book_models.Book.id == book_id).first()
    if not book:
        meta = book_schemas.Meta(
            success=False,
            message=f"Book with id {book_id} not found"
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"meta": meta.dict(), "data": None}
        )
    
    meta = book_schemas.Meta(
        success=True,
        message="Book retrieved successfully"
    )
    return book_schemas.SingleBookResponse(meta=meta, data=book)

# Create new book
@app.post("/books", response_model=book_schemas.SingleBookResponse, status_code=status.HTTP_201_CREATED)
def create_book(book: book_schemas.BookCreate, db: Session = Depends(get_db)):
    # Check if book with same ISBN already exists
    if book.isbn:
        existing_book = db.query(book_models.Book).filter(book_models.Book.isbn == book.isbn).first()
        if existing_book:
            meta = book_schemas.Meta(
                success=False,
                message=f"Book with ISBN {book.isbn} already exists"
            )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"meta": meta.dict(), "data": None}
            )
    
    db_book = book_models.Book(**book.dict())
    db.add(db_book)
    db.commit()
    db.refresh(db_book)
    
    meta = book_schemas.Meta(
        success=True,
        message="Book created successfully"
    )
    return book_schemas.SingleBookResponse(meta=meta, data=db_book)

# Update existing book
@app.put("/books/{book_id}", response_model=book_schemas.SingleBookResponse)
def update_book(book_id: int, book_update: book_schemas.BookUpdate, db: Session = Depends(get_db)):
    book = db.query(book_models.Book).filter(book_models.Book.id == book_id).first()
    if not book:
        meta = book_schemas.Meta(
            success=False,
            message=f"Book with id {book_id} not found"
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"meta": meta.dict(), "data": None}
        )
    
    # Update only provided fields
    update_data = book_update.dict(exclude_unset=True)
    if not update_data:
        meta = book_schemas.Meta(
            success=False,
            message="No fields provided for update"
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"meta": meta.dict(), "data": None}
        )
    
    for field, value in update_data.items():
        setattr(book, field, value)
    
    db.commit()
    db.refresh(book)
    
    meta = book_schemas.Meta(
        success=True,
        message="Book updated successfully"
    )
    return book_schemas.SingleBookResponse(meta=meta, data=book)

# Delete book
@app.delete("/books/{book_id}")
def delete_book(book_id: int, db: Session = Depends(get_db)):
    book = db.query(book_models.Book).filter(book_models.Book.id == book_id).first()
    if not book:
        meta = book_schemas.Meta(
            success=False,
            message=f"Book with id {book_id} not found"
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"meta": meta.dict(), "data": None}
        )
    
    db.delete(book)
    db.commit()
    
    return create_response(
        success=True,
        message=f"Book with id {book_id} deleted successfully",
        data={"deleted_book_id": book_id}
    )
```

This is the heart of our API. Let's break down what each endpoint does:

- `GET /`: Welcome message with standardized response
- `GET /health`: Simple health check with status information  
- `GET /books`: Get all books with pagination and metadata
- `GET /books/{book_id}`: Get a specific book by ID
- `POST /books`: Create a new book with validation
- `PUT /books/{book_id}`: Update an existing book
- `DELETE /books/{book_id}`: Delete a book

## Standard Response Format

Notice how all our responses now follow a consistent structure with `meta` and `data` fields:

```json
{
  "meta": {
    "success": true,
    "message": "Books retrieved successfully",
    "total": 25,
    "page": 1,
    "limit": 10,
    "total_pages": 3
  },
  "data": [
    {
      "id": 1,
      "title": "The Python Guide",
      "author": "Real Python",
      "description": "A comprehensive guide to Python programming",
      "published_year": 2023,
      "isbn": "978-0123456789"
    }
  ]
}
```

This format provides several benefits:
- **Consistent structure** across all endpoints
- **Success/failure indication** in every response
- **Helpful messages** for debugging and user feedback
- **Pagination metadata** for list endpoints
- **Easy parsing** for frontend applications

## Running the Application

Let's see our API in action! Run this command from your project root:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The `--reload` flag automatically restarts the server when you change code, making development much smoother.

Open your browser and go to `http://127.0.0.1:8000`. You should see:

```json
{
  "meta": {
    "success": true,
    "message": "Welcome to Book Library API",
    "total": null,
    "page": null,
    "limit": null,
    "total_pages": null
  },
  "data": {
    "version": "1.0.0",
    "status": "running"
  }
}
```

## Interactive API Documentation

Now for the coolest part. Navigate to `http://127.0.0.1:8000/docs` and prepare to be impressed. FastAPI automatically created interactive documentation for your entire API. You can test every endpoint right in the browser - no Postman needed.

Try creating a book:
1. Click on the `POST /books` endpoint
2. Click "Try it out"
3. Enter this sample data:

```json
{
  "title": "The Python Guide",
  "author": "Real Python",
  "description": "A comprehensive guide to Python programming",
  "published_year": 2023,
  "isbn": "978-0123456789"
}
```

4. Click "Execute"

You should get a successful response with your newly created book in the standard format:

```json
{
  "meta": {
    "success": true,
    "message": "Book created successfully",
    "total": null,
    "page": null,
    "limit": null,
    "total_pages": null
  },
  "data": {
    "id": 1,
    "title": "The Python Guide",
    "author": "Real Python",
    "description": "A comprehensive guide to Python programming",
    "published_year": 2023,
    "isbn": "978-0123456789"
  }
}
```

## Testing Your API

Let's test all our endpoints to make sure everything works. You can use the interactive docs at `http://127.0.0.1:8000/docs`, or test via command line with these examples:

### Method 1: Copy-Paste Ready Commands

**Create a book (single line - just copy and paste):**
```bash
curl -X POST "http://127.0.0.1:8000/books" -H "Content-Type: application/json" -d '{"title": "FastAPI for Beginners", "author": "Jane Developer", "description": "Learn FastAPI step by step", "published_year": 2024, "isbn": "978-0987654321"}'
```

**Get all books:**
```bash
curl "http://127.0.0.1:8000/books"
```

**Get a specific book:**
```bash
curl "http://127.0.0.1:8000/books/1"
```

**Update a book:**
```bash
curl -X PUT "http://127.0.0.1:8000/books/1" -H "Content-Type: application/json" -d '{"title": "FastAPI for Beginners - Updated Edition"}'
```

**Delete a book:**
```bash
curl -X DELETE "http://127.0.0.1:8000/books/1"
```

### Method 2: Using JSON Files (Recommended for Complex Data)

For easier testing with complex data, create JSON files:

**Create `book.json`:**
```bash
cat > book.json << 'EOF'
{
  "title": "FastAPI for Beginners",
  "author": "Jane Developer",
  "description": "Learn FastAPI step by step",
  "published_year": 2024,
  "isbn": "978-0987654321"
}
EOF
```

**Then use the file:**
```bash
curl -X POST "http://127.0.0.1:8000/books" -H "Content-Type: application/json" --data-binary @book.json
```

**Create `update.json`:**
```bash
cat > update.json << 'EOF'
{
  "title": "FastAPI for Beginners - Updated Edition",
  "description": "Learn FastAPI step by step with the latest updates"
}
EOF
```

**Update using file:**
```bash
curl -X PUT "http://127.0.0.1:8000/books/1" -H "Content-Type: application/json" --data-binary @update.json
```

### Expected Response Examples

**Successful book creation:**
```json
{
  "meta": {
    "success": true,
    "message": "Book created successfully",
    "total": null,
    "page": null,
    "limit": null,
    "total_pages": null
  },
  "data": {
    "id": 1,
    "title": "FastAPI for Beginners",
    "author": "Jane Developer",
    "description": "Learn FastAPI step by step",
    "published_year": 2024,
    "isbn": "978-0987654321"
  }
}
```

**Get all books response:**
```json
{
  "meta": {
    "success": true,
    "message": "Books retrieved successfully",
    "total": 1,
    "page": 1,
    "limit": 100,
    "total_pages": 1
  },
  "data": [
    {
      "id": 1,
      "title": "FastAPI for Beginners",
      "author": "Jane Developer",
      "description": "Learn FastAPI step by step",
      "published_year": 2024,
      "isbn": "978-0987654321"
    }
  ]
}
```

### Testing with Pagination

**Get books with pagination:**
```bash
curl "http://127.0.0.1:8000/books?skip=0&limit=5"
```

**Get second page:**
```bash
curl "http://127.0.0.1:8000/books?skip=5&limit=5"
```

## Understanding the Code

Before we move on, let me explain a few important concepts that might not be obvious:

**Dependency Injection:** The `Depends(get_db)` parameter in our endpoints is dependency injection. FastAPI automatically calls `get_db()` and provides the database session to your function.

**Type Hints:** Notice how we specify types like `book_id: int` and `response_model=List[book_schemas.BookResponse]`. This isn't just for documentation - FastAPI uses these to validate data and provide better error messages.

**HTTP Status Codes:** We use appropriate status codes like 201 for created resources and 404 for not found. This makes our API more professional and easier to integrate with.

**Error Handling:** When something goes wrong (like trying to access a non-existent book), we raise HTTPException with appropriate status codes and messages.

## Adding More Features

Want to extend your API? Here are some ideas:

**Search functionality:**
```python
@app.get("/books/search", response_model=List[book_schemas.BookResponse])
def search_books(q: str, db: Session = Depends(get_db)):
    books = db.query(book_models.Book).filter(
        book_models.Book.title.contains(q) | 
        book_models.Book.author.contains(q)
    ).all()
    return books
```

**Filtering by author:**
```python
@app.get("/books/by-author/{author}", response_model=List[book_schemas.BookResponse])
def get_books_by_author(author: str, db: Session = Depends(get_db)):
    books = db.query(book_models.Book).filter(book_models.Book.author == author).all()
    return books
```

## Common Issues and Solutions

**Import Errors:** Make sure all your `__init__.py` files exist and you're running commands from the project root.

**Database Errors:** If you get database-related errors, delete the `books.db` file and restart the application to recreate it.

**Port Already in Use:** If port 8000 is busy, use a different port: `uvicorn app.main:app --reload --port 8001`

**curl Command Issues:** If you get "command not found" errors when copying multiline curl commands, use the single-line versions provided above, or create JSON files as shown in Method 2.

**JSON Parsing Errors:** Make sure your JSON is valid. If you get "Field required" errors, check that your JSON structure matches the expected schema. Use the interactive docs at `/docs` to see the exact format needed.

**Permission Errors:** On some systems, you might need to escape quotes differently. If single quotes don't work, try double quotes with escaped inner quotes:
```bash
curl -X POST "http://127.0.0.1:8000/books" -H "Content-Type: application/json" -d "{\"title\": \"FastAPI for Beginners\", \"author\": \"Jane Developer\"}"
```

## Next Steps

Congratulations! You've built a complete REST API from scratch. Here's what you can do next:

1. **Add Authentication:** Protect your endpoints with [JWT authentication and OAuth2 password flow]({{< relref "blog/python/fastapi-jwt-auth-oauth2-password-flow-pydantic-v2-sqlalchemy-2.md" >}})
2. **Deploy to Production:** Learn how to [deploy FastAPI on Ubuntu 24.04 with Nginx and HTTPS]({{< relref "blog/python/deploy-fastapi-ubuntu-24-04-gunicorn-nginx-certbot.md" >}})
3. **Add Validation:** Implement more complex validation rules with Pydantic
4. **Add Tests:** Write unit tests for your endpoints  
5. **Add a Frontend:** Build a web interface to interact with your API
6. **Scale with Docker:** Containerize your application for easier deployment

## Wrapping Up

Look at what you just built - a real REST API that handles data, validates input, and documents itself. That's not trivial stuff. You went from zero to having something that could actually power a web app or mobile app.

What I love about this setup is how easy it is to extend. Need user accounts? Add a User model. Want to track book reviews? Create a Review endpoint. The foundation is solid, and FastAPI handles the boring stuff so you can focus on the interesting problems.

Keep experimenting with different endpoints and features. The best way to learn API development is by building real projects and solving real problems. Your Book Library API is just the beginning - imagine what you'll build next!