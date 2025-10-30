---
title: "How to Build a REST API with Django REST Framework (Production Ready)"
date: 2025-10-29T08:00:00+07:00
draft: false
url: /2025/10/how-to-build-rest-api-django-rest-framework-production-ready.html
tags:
  - Python
  - Django
  - REST API
  - Backend
description: "Learn how to build production-ready REST APIs with Django REST Framework. Master models, serializers, viewsets, authentication (JWT/Token), permissions, pagination, filtering, testing, and deployment. Complete guide with real project examples."
keywords:
  - django rest framework tutorial
  - build rest api django
  - django drf authentication
  - django rest framework jwt
  - django api development
  - python rest api django
  - django rest framework viewsets
  - django api best practices
  - django rest framework serializers
  - django vs fastapi
faq:
  - question: "What is Django REST Framework and why should I use it?"
    answer: "Django REST Framework (DRF) is the most mature and battle-tested Python framework for building REST APIs. It's built on Django, which powers Instagram, Spotify, and NASA websites. DRF provides built-in authentication, permissions, serialization, browsable API interface, and ORM integration out of the box. Choose DRF for enterprise applications, complex business logic, admin panels, and when you need Django's ecosystem (auth, admin, ORM). It's more opinionated than FastAPI but requires less code for complex apps."

  - question: "Django REST Framework vs FastAPI - which one should I choose?"
    answer: "DRF is better for traditional web apps with complex business logic, admin panels, and mature ecosystem needs. It has more built-in features and Django's ORM is excellent for complex queries. FastAPI is better for microservices, real-time apps, and when raw speed matters--it's 2-3x faster than DRF. Choose DRF if you need Django's admin, authentication system, or are building a monolith. Choose FastAPI for new projects prioritizing performance and modern Python (async/await)."

  - question: "Do I need to know Django before learning Django REST Framework?"
    answer: "Yes, basic Django knowledge helps a lot. You should understand Django models, migrations, querysets, and URL routing. However, if you already know databases and web APIs, you can learn both simultaneously--DRF tutorials usually cover necessary Django concepts. Spend 2-3 days learning Django basics (official tutorial parts 1-4), then jump into DRF. The learning curve is steeper than FastAPI but Django's documentation is excellent."

  - question: "How do I implement JWT authentication in Django REST Framework?"
    answer: "Use the djangorestframework-simplejwt library. Install it, add it to INSTALLED_APPS, configure token lifetime in settings, add JWT URLs to your routes, and protect views with IsAuthenticated permission. Users POST credentials to /api/token/ to get access and refresh tokens, then include 'Authorization: Bearer <token>' in request headers. The library handles token generation, validation, refresh, and blacklisting automatically. It's production-ready and widely used."

  - question: "What are ViewSets and why should I use them instead of APIView?"
    answer: "ViewSets combine list, create, retrieve, update, and delete operations into one class, reducing boilerplate code dramatically. A ModelViewSet that needs 5 separate APIView classes (List, Create, Detail, Update, Delete) becomes one ViewSet with ~10 lines. Use ViewSets with Routers for standard CRUD APIs (95% of cases). Use APIView only for custom endpoints that don't fit REST patterns, like login, password reset, or complex business operations."

  - question: "How do I deploy Django REST Framework API to production?"
    answer: "Use Gunicorn/uWSGI as WSGI server, Nginx as reverse proxy, PostgreSQL as database, and Redis for caching. Set DEBUG=False, configure ALLOWED_HOSTS, use environment variables for secrets, enable HTTPS, set up CORS properly, and use WhiteNoise for static files. Deploy on VPS (DigitalOcean, AWS EC2), PaaS (Heroku, Railway), or containers (Docker + Kubernetes). Always use migrations, set up monitoring (Sentry), and implement rate limiting. Never use SQLite in production."
---

I still remember the first time I built an API for a client's e-commerce platform. I chose FastAPI because everyone on Twitter was hyping it up--"blazing fast," "modern Python," "async everything." The initial setup was smooth, and I built endpoints quickly.

Then reality hit.

The client needed a complex admin panel to manage products, orders, and users. They wanted role-based permissions with granular controls. They needed integration with their existing Django authentication system. And oh, they wanted detailed audit logs for every database change.

I spent three weeks building features that would have been three clicks in Django admin. I wrote hundreds of lines of permission logic that Django has built-in. I implemented audit trails manually while Django has well-tested libraries for this.

That's when I learned a crucial lesson: **framework hype doesn't pay your bills. Shipping features does.**

Don't get me wrong--FastAPI is excellent for certain use cases (I still use it for microservices). But Django REST Framework has won hundreds of my projects because it gets complex applications to production faster with less code, fewer bugs, and better maintainability.

If you're building a REST API that needs authentication, permissions, admin panels, complex database relationships, and third-party integrations--Django REST Framework will save you weeks of work.

This guide will show you how to build production-ready REST APIs with Django REST Framework from scratch. No toy examples. No "hello world" nonsense. Just real code that handles authentication, permissions, pagination, filtering, testing, and deployment.

By the end, you'll understand why companies like Instagram, Mozilla, Red Hat, and Eventbrite chose Django for their APIs.

Let's build something real.

## Django REST Framework vs FastAPI: Honest Comparison

Before we start, let's address the elephant in the room. Everyone asks: "Should I use Django REST Framework or FastAPI?"

Here's my honest take after building 50+ production APIs with both:

### When to Choose Django REST Framework

**Complex business applications:**
- E-commerce platforms with products, orders, inventory, shipping
- CMS with content management, versioning, workflows
- SaaS applications with multi-tenancy, billing, subscriptions
- Enterprise apps with complex permissions and user hierarchies

**Need Django's ecosystem:**
- Django Admin panel (saves weeks of development)
- Django Auth (users, groups, permissions out of the box)
- Django ORM (best Python ORM, period)
- Thousands of Django packages (payments, notifications, storage, etc.)

**Database-heavy operations:**
- Complex queries with joins, aggregations, subqueries
- Transaction management
- Multiple database connections
- Advanced ORM features (select_related, prefetch_related)

**Built-in batteries:**
- Authentication (session, token, JWT)
- Permissions system (object-level, model-level)
- Throttling and rate limiting
- Pagination (cursor, page number, limit-offset)
- Filtering and search
- Browsable API interface (test APIs in browser)
- Content negotiation (JSON, XML, YAML)

**Team considerations:**
- Team already knows Django
- Need strict patterns and conventions
- Long-term maintenance (Django has 15+ years of stability)

### When to Choose FastAPI

**Performance-critical applications:**
- Microservices handling 10,000+ req/sec
- Real-time applications (WebSockets, SSE)
- ML model serving with low latency requirements

**Async-first architecture:**
- Lots of I/O-bound operations (external APIs, file uploads)
- Need async database drivers (asyncpg, motor)
- WebSocket-heavy applications

**Modern Python features:**
- Type hints everywhere (automatic validation)
- Async/await native support
- Python 3.10+ features

**Lightweight APIs:**
- Simple CRUD without complex business logic
- Stateless microservices
- API gateway/proxy
- Don't need admin panel

**Greenfield projects:**
- No existing Django code
- Small team comfortable with minimal structure
- Can handle building authentication/permissions from scratch

### Performance Reality Check

Yes, FastAPI is faster--about 2-3x on raw benchmarks. But here's the truth: **for 95% of applications, this doesn't matter.**

If your API spends 50ms querying the database and 5ms in framework overhead, making the framework 3x faster saves you 3ms. Your users won't notice 47ms vs 50ms response time.

Optimize database queries, add caching, and use CDN before worrying about framework speed.

### My Recommendation

**Choose Django REST Framework if:**
- Building a monolithic application or traditional web app
- Need admin panel, complex auth, or Django ecosystem
- Database is primary data source
- Team knows Django or wants opinionated framework
- Building MVP and want to ship fast

**Choose FastAPI if:**
- Building microservices or serverless functions
- Need extreme performance (10k+ req/sec per instance)
- Heavy async/await usage
- Small, focused APIs without complex business logic
- Want full control over architecture

**For this tutorial, we're using Django REST Framework** because it teaches you how to build complete, production-ready APIs with all the bells and whistles--authentication, permissions, admin, testing, deployment.

If you want to collect data from external sources to populate your API, check out my [web scraping guide](/2025/10/how-to-build-web-scraper-python-beautifulsoup-requests.html) to learn how to gather data automatically.

Now let's build.

## Installing Django and Django REST Framework

Let's set up your development environment.

**Prerequisites:**
- Python 3.8 or newer
- Basic understanding of Python, HTTP, and REST APIs
- Basic Django knowledge (models, migrations, URLs) helps but not required

**Create project directory:**

```bash
mkdir bookstore-api
cd bookstore-api

# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Linux/Mac:
source venv/bin/activate
# On Windows:
# venv\Scripts\activate

# Upgrade pip
pip install --upgrade pip
```

**Install Django and DRF:**

```bash
pip install django djangorestframework

# Optional but recommended packages
pip install django-filter        # Filtering
pip install djangorestframework-simplejwt  # JWT authentication
pip install drf-spectacular      # OpenAPI/Swagger documentation
pip install django-cors-headers  # CORS support
pip install psycopg2-binary     # PostgreSQL (we'll use SQLite for dev)
pip install python-decouple     # Environment variables
pip install gunicorn            # Production WSGI server

# Save dependencies
pip freeze > requirements.txt
```

**Create Django project:**

```bash
# Create project
django-admin startproject bookstore .

# Create API app
python manage.py startapp books

# Create another app for authentication
python manage.py startapp accounts
```

Your project structure:

```
bookstore-api/
├── venv/
├── bookstore/          # Project settings
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   ├── asgi.py
│   └── wsgi.py
├── books/             # Books app
│   ├── migrations/
│   ├── __init__.py
│   ├── admin.py
│   ├── apps.py
│   ├── models.py
│   ├── serializers.py  # We'll create this
│   ├── views.py
│   └── urls.py         # We'll create this
├── accounts/          # Custom auth
│   └── ...
├── manage.py
└── requirements.txt
```

**Configure settings.py:**

```python
# bookstore/settings.py

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Third party
    'rest_framework',
    'rest_framework_simplejwt',
    'django_filters',
    'drf_spectacular',
    'corsheaders',

    # Local apps
    'books',
    'accounts',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',  # CORS
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# Rest Framework settings
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 10,
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ],
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
}

# CORS settings (for frontend)
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",  # React
    "http://localhost:5173",  # Vite
]

# Spectacular settings (API documentation)
SPECTACULAR_SETTINGS = {
    'TITLE': 'Bookstore API',
    'DESCRIPTION': 'REST API for online bookstore',
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
}

# JWT settings
from datetime import timedelta

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
}
```

**Run initial migrations:**

```bash
python manage.py migrate
```

**Create superuser:**

```bash
python manage.py createsuperuser
# Enter username, email, password
```

**Test server:**

```bash
python manage.py runserver
```

Visit `http://localhost:8000/admin/` and login with your superuser credentials. If you see Django admin, you're good to go!

## Creating Models

Let's build a bookstore API with books, authors, categories, and reviews.

**Create models (books/models.py):**

```python
from django.db import models
from django.contrib.auth.models import User
from django.core.validators import MinValueValidator, MaxValueValidator

class Author(models.Model):
    name = models.CharField(max_length=200)
    bio = models.TextField(blank=True)
    birth_date = models.DateField(null=True, blank=True)
    website = models.URLField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(unique=True)
    description = models.TextField(blank=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = 'Categories'

    def __str__(self):
        return self.name

class Book(models.Model):
    title = models.CharField(max_length=300)
    slug = models.SlugField(unique=True)
    isbn = models.CharField(max_length=13, unique=True)
    description = models.TextField()
    authors = models.ManyToManyField(Author, related_name='books')
    categories = models.ManyToManyField(Category, related_name='books')
    publisher = models.CharField(max_length=200)
    publication_date = models.DateField()
    pages = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    stock = models.PositiveIntegerField(default=0)
    cover_image = models.URLField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.title

    @property
    def average_rating(self):
        reviews = self.reviews.all()
        if reviews:
            return sum([review.rating for review in reviews]) / len(reviews)
        return 0

    @property
    def is_available(self):
        return self.stock > 0

class Review(models.Model):
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='reviews')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reviews')
    rating = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)]
    )
    title = models.CharField(max_length=200)
    comment = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        unique_together = ['book', 'user']  # One review per user per book

    def __str__(self):
        return f"{self.user.username} - {self.book.title} ({self.rating}/5)"
```

**Create and run migrations:**

```bash
python manage.py makemigrations
python manage.py migrate
```

**Register models in admin (books/admin.py):**

```python
from django.contrib import admin
from .models import Author, Category, Book, Review

@admin.register(Author)
class AuthorAdmin(admin.ModelAdmin):
    list_display = ['name', 'birth_date', 'created_at']
    search_fields = ['name', 'bio']
    prepopulated_fields = {'slug': ('name',)}  # If you add slug field

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'slug']
    search_fields = ['name']
    prepopulated_fields = {'slug': ('name',)}

@admin.register(Book)
class BookAdmin(admin.ModelAdmin):
    list_display = ['title', 'isbn', 'price', 'stock', 'publication_date', 'is_available']
    list_filter = ['publication_date', 'categories', 'authors']
    search_fields = ['title', 'isbn', 'description']
    filter_horizontal = ['authors', 'categories']
    prepopulated_fields = {'slug': ('title',)}

@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ['book', 'user', 'rating', 'created_at']
    list_filter = ['rating', 'created_at']
    search_fields = ['book__title', 'user__username', 'comment']
```

Now you can add books via Django admin at `http://localhost:8000/admin/`. Add a few books to test with.

## Creating Serializers

Serializers convert Django models to JSON (and vice versa). Think of them as translators between Python and JSON.

**Create serializers (books/serializers.py):**

```python
from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Author, Category, Book, Review

class AuthorSerializer(serializers.ModelSerializer):
    books_count = serializers.SerializerMethodField()

    class Meta:
        model = Author
        fields = ['id', 'name', 'bio', 'birth_date', 'website', 'books_count', 'created_at']

    def get_books_count(self, obj):
        return obj.books.count()

class CategorySerializer(serializers.ModelSerializer):
    books_count = serializers.SerializerMethodField()

    class Meta:
        model = Category
        fields = ['id', 'name', 'slug', 'description', 'books_count']

    def get_books_count(self, obj):
        return obj.books.count()

class ReviewSerializer(serializers.ModelSerializer):
    user = serializers.StringRelatedField(read_only=True)
    user_id = serializers.IntegerField(read_only=True)

    class Meta:
        model = Review
        fields = ['id', 'book', 'user', 'user_id', 'rating', 'title', 'comment', 'created_at', 'updated_at']
        read_only_fields = ['user']

    def validate_rating(self, value):
        if value < 1 or value > 5:
            raise serializers.ValidationError("Rating must be between 1 and 5")
        return value

    def create(self, validated_data):
        # Automatically set user from request
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)

class BookListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for list view"""
    authors = serializers.StringRelatedField(many=True)
    categories = serializers.StringRelatedField(many=True)
    average_rating = serializers.ReadOnlyField()
    is_available = serializers.ReadOnlyField()

    class Meta:
        model = Book
        fields = [
            'id', 'title', 'slug', 'authors', 'categories',
            'price', 'stock', 'average_rating', 'is_available',
            'cover_image', 'publication_date'
        ]

class BookDetailSerializer(serializers.ModelSerializer):
    """Detailed serializer for single book view"""
    authors = AuthorSerializer(many=True, read_only=True)
    categories = CategorySerializer(many=True, read_only=True)
    reviews = ReviewSerializer(many=True, read_only=True)
    average_rating = serializers.ReadOnlyField()
    is_available = serializers.ReadOnlyField()
    reviews_count = serializers.SerializerMethodField()

    # Write fields (accept IDs)
    author_ids = serializers.PrimaryKeyRelatedField(
        queryset=Author.objects.all(),
        many=True,
        write_only=True,
        source='authors'
    )
    category_ids = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(),
        many=True,
        write_only=True,
        source='categories'
    )

    class Meta:
        model = Book
        fields = [
            'id', 'title', 'slug', 'isbn', 'description',
            'authors', 'author_ids', 'categories', 'category_ids',
            'publisher', 'publication_date', 'pages', 'price', 'stock',
            'cover_image', 'average_rating', 'is_available',
            'reviews', 'reviews_count', 'created_at', 'updated_at'
        ]
        read_only_fields = ['slug']

    def get_reviews_count(self, obj):
        return obj.reviews.count()

    def validate_isbn(self, value):
        # ISBN-13 validation
        if len(value) != 13 or not value.isdigit():
            raise serializers.ValidationError("ISBN must be 13 digits")
        return value

    def validate_price(self, value):
        if value <= 0:
            raise serializers.ValidationError("Price must be positive")
        return value

class BookCreateUpdateSerializer(serializers.ModelSerializer):
    """Serializer for creating/updating books"""

    class Meta:
        model = Book
        fields = [
            'title', 'slug', 'isbn', 'description',
            'authors', 'categories', 'publisher', 'publication_date',
            'pages', 'price', 'stock', 'cover_image'
        ]

    def validate(self, data):
        # Custom validation
        if data.get('pages', 0) <= 0:
            raise serializers.ValidationError({"pages": "Pages must be positive"})
        if data.get('stock', 0) < 0:
            raise serializers.ValidationError({"stock": "Stock cannot be negative"})
        return data
```

**Key serializer concepts:**

- `ModelSerializer` - automatically creates fields from model
- `read_only=True` - field appears in response but can't be set
- `write_only=True` - field accepted in request but not shown in response
- `SerializerMethodField` - custom calculated field (method: `get_<field_name>`)
- `StringRelatedField` - shows `__str__()` representation
- `PrimaryKeyRelatedField` - shows/accepts IDs
- `validate_<field>` - field-level validation
- `validate()` - object-level validation

## Creating Views with ViewSets

ViewSets combine multiple views (list, create, retrieve, update, delete) into one class.

**Create views (books/views.py):**

```python
from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAuthenticatedOrReadOnly, AllowAny
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Q

from .models import Author, Category, Book, Review
from .serializers import (
    AuthorSerializer, CategorySerializer,
    BookListSerializer, BookDetailSerializer, BookCreateUpdateSerializer,
    ReviewSerializer
)
from .permissions import IsOwnerOrReadOnly

class AuthorViewSet(viewsets.ModelViewSet):
    """
    API endpoint for authors.

    list: Get all authors
    create: Create new author (admin only)
    retrieve: Get single author
    update: Update author (admin only)
    destroy: Delete author (admin only)
    """
    queryset = Author.objects.all()
    serializer_class = AuthorSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'bio']
    ordering_fields = ['name', 'created_at']
    ordering = ['name']

    @action(detail=True, methods=['get'])
    def books(self, request, pk=None):
        """Get all books by this author"""
        author = self.get_object()
        books = author.books.all()
        serializer = BookListSerializer(books, many=True)
        return Response(serializer.data)

class CategoryViewSet(viewsets.ModelViewSet):
    """API endpoint for categories"""
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [IsAuthenticatedOrReadOnly]
    lookup_field = 'slug'  # Use slug instead of ID in URL
    filter_backends = [filters.SearchFilter]
    search_fields = ['name', 'description']

    @action(detail=True, methods=['get'])
    def books(self, request, slug=None):
        """Get all books in this category"""
        category = self.get_object()
        books = category.books.all()
        serializer = BookListSerializer(books, many=True)
        return Response(serializer.data)

class BookViewSet(viewsets.ModelViewSet):
    """API endpoint for books"""
    queryset = Book.objects.prefetch_related('authors', 'categories', 'reviews')
    permission_classes = [IsAuthenticatedOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['categories__slug', 'authors', 'publication_date']
    search_fields = ['title', 'description', 'isbn', 'authors__name']
    ordering_fields = ['title', 'price', 'publication_date', 'created_at']
    ordering = ['-created_at']
    lookup_field = 'slug'

    def get_serializer_class(self):
        """Use different serializers for different actions"""
        if self.action == 'list':
            return BookListSerializer
        elif self.action in ['create', 'update', 'partial_update']:
            return BookCreateUpdateSerializer
        return BookDetailSerializer

    def get_queryset(self):
        """Custom filtering"""
        queryset = super().get_queryset()

        # Filter by price range
        min_price = self.request.query_params.get('min_price')
        max_price = self.request.query_params.get('max_price')

        if min_price:
            queryset = queryset.filter(price__gte=min_price)
        if max_price:
            queryset = queryset.filter(price__lte=max_price)

        # Filter by availability
        available = self.request.query_params.get('available')
        if available == 'true':
            queryset = queryset.filter(stock__gt=0)
        elif available == 'false':
            queryset = queryset.filter(stock=0)

        return queryset

    @action(detail=True, methods=['get'])
    def reviews(self, request, slug=None):
        """Get all reviews for this book"""
        book = self.get_object()
        reviews = book.reviews.all()
        serializer = ReviewSerializer(reviews, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def featured(self, request):
        """Get featured books (high rated, in stock)"""
        books = self.get_queryset().filter(stock__gt=0)[:10]
        serializer = BookListSerializer(books, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def search_advanced(self, request):
        """Advanced search with multiple criteria"""
        query = request.query_params.get('q', '')

        books = self.get_queryset().filter(
            Q(title__icontains=query) |
            Q(description__icontains=query) |
            Q(authors__name__icontains=query) |
            Q(categories__name__icontains=query)
        ).distinct()

        serializer = BookListSerializer(books, many=True)
        return Response(serializer.data)

class ReviewViewSet(viewsets.ModelViewSet):
    """API endpoint for reviews"""
    queryset = Review.objects.select_related('book', 'user')
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['book', 'rating', 'user']
    ordering_fields = ['rating', 'created_at']
    ordering = ['-created_at']

    def perform_create(self, serializer):
        """Set user automatically when creating review"""
        serializer.save(user=self.request.user)

    def get_queryset(self):
        """Users can only update/delete their own reviews"""
        queryset = super().get_queryset()

        if self.action in ['update', 'partial_update', 'destroy']:
            return queryset.filter(user=self.request.user)

        return queryset
```

**Create custom permission (books/permissions.py):**

```python
from rest_framework import permissions

class IsOwnerOrReadOnly(permissions.BasePermission):
    """
    Custom permission: object owner can edit, others can only read.
    """

    def has_object_permission(self, request, view, obj):
        # Read permissions allowed for any request (GET, HEAD, OPTIONS)
        if request.method in permissions.SAFE_METHODS:
            return True

        # Write permissions only for object owner
        return obj.user == request.user
```

## URL Routing with Routers

DRF Routers automatically generate URLs for ViewSets.

**Create URLs (books/urls.py):**

```python
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AuthorViewSet, CategoryViewSet, BookViewSet, ReviewViewSet

router = DefaultRouter()
router.register(r'authors', AuthorViewSet, basename='author')
router.register(r'categories', CategoryViewSet, basename='category')
router.register(r'books', BookViewSet, basename='book')
router.register(r'reviews', ReviewViewSet, basename='review')

urlpatterns = [
    path('', include(router.urls)),
]
```

**Update project URLs (bookstore/urls.py):**

```python
from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path('admin/', admin.site.urls),

    # API endpoints
    path('api/', include('books.urls')),

    # Authentication
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # API documentation
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),

    # Browsable API auth
    path('api-auth/', include('rest_framework.urls')),
]
```

**Generated URLs:**

```
GET    /api/books/              - List all books
POST   /api/books/              - Create book
GET    /api/books/{slug}/       - Get single book
PUT    /api/books/{slug}/       - Update book (full)
PATCH  /api/books/{slug}/       - Update book (partial)
DELETE /api/books/{slug}/       - Delete book
GET    /api/books/{slug}/reviews/ - Custom action
GET    /api/books/featured/     - Custom list action

GET    /api/authors/            - List authors
POST   /api/authors/            - Create author
GET    /api/authors/{id}/       - Get author
GET    /api/authors/{id}/books/ - Author's books

GET    /api/categories/         - List categories
GET    /api/categories/{slug}/  - Get category
GET    /api/categories/{slug}/books/ - Category's books

GET    /api/reviews/            - List reviews
POST   /api/reviews/            - Create review
GET    /api/reviews/{id}/       - Get review
PATCH  /api/reviews/{id}/       - Update review (owner only)
DELETE /api/reviews/{id}/       - Delete review (owner only)
```

Start server and test:

```bash
python manage.py runserver
```

Visit:
- `http://localhost:8000/api/` - Browsable API
- `http://localhost:8000/api/books/` - Books list
- `http://localhost:8000/api/docs/` - Swagger UI documentation

## Authentication with JWT

Let's implement JWT (JSON Web Token) authentication.

**JWT is already configured** in settings.py. Now let's test it.

**Get JWT token:**

```bash
curl -X POST http://localhost:8000/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"username": "your_username", "password": "your_password"}'
```

Response:

```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

**Use access token:**

```bash
curl http://localhost:8000/api/books/ \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..."
```

**Refresh token when expired:**

```bash
curl -X POST http://localhost:8000/api/token/refresh/ \
  -H "Content-Type: application/json" \
  -d '{"refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."}'
```

**Create user registration endpoint (accounts/serializers.py):**

```python
from rest_framework import serializers
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password2', 'first_name', 'last_name']

    def validate(self, attrs):
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({"password": "Password fields didn't match."})
        return attrs

    def create(self, validated_data):
        validated_data.pop('password2')
        user = User.objects.create_user(**validated_data)
        return user

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'date_joined']
```

**Create registration view (accounts/views.py):**

```python
from rest_framework import generics, permissions
from rest_framework.response import Response
from django.contrib.auth.models import User
from .serializers import RegisterSerializer, UserSerializer

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = [permissions.AllowAny]
    serializer_class = RegisterSerializer

class UserProfileView(generics.RetrieveUpdateAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user
```

**Add URLs (accounts/urls.py):**

```python
from django.urls import path
from .views import RegisterView, UserProfileView

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('profile/', UserProfileView.as_view(), name='profile'),
]
```

**Update project URLs:**

```python
# bookstore/urls.py
urlpatterns = [
    # ... existing patterns
    path('api/accounts/', include('accounts.urls')),
]
```

**Test registration:**

```bash
curl -X POST http://localhost:8000/api/accounts/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newuser",
    "email": "user@example.com",
    "password": "SecurePass123!",
    "password2": "SecurePass123!",
    "first_name": "John",
    "last_name": "Doe"
  }'
```

Now you have complete auth: registration, login (JWT), and profile management.

## Permissions and Throttling

Control who can access what and prevent API abuse.

**Built-in permissions:**

- `AllowAny` - anyone (default)
- `IsAuthenticated` - logged in users only
- `IsAdminUser` - admin users only
- `IsAuthenticatedOrReadOnly` - read for all, write for authenticated

**Apply permissions per view:**

```python
from rest_framework.permissions import IsAdminUser

class BookViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get_permissions(self):
        """Different permissions for different actions"""
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsAdminUser()]
        return [IsAuthenticatedOrReadOnly()]
```

**Custom object-level permissions:**

```python
# books/permissions.py

class IsAdminOrReadOnly(permissions.BasePermission):
    """Admin can edit, others read only"""

    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return request.user and request.user.is_staff

class IsOwnerOrAdmin(permissions.BasePermission):
    """Owner or admin can edit"""

    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True

        if request.user.is_staff:
            return True

        return obj.user == request.user
```

**Throttling (rate limiting):**

```python
# settings.py

REST_FRAMEWORK = {
    # ... existing config
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle'
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/day',      # Anonymous users: 100 requests per day
        'user': '1000/day',     # Authenticated users: 1000 per day
    }
}
```

**Custom throttling per view:**

```python
from rest_framework.throttling import UserRateThrottle

class BurstRateThrottle(UserRateThrottle):
    rate = '60/min'  # 60 requests per minute

class BookViewSet(viewsets.ModelViewSet):
    throttle_classes = [BurstRateThrottle]
```

## Filtering, Pagination, and Search

Make your API flexible and performant. Once your API is collecting data, you can analyze usage patterns, user behavior, and performance metrics with [Pandas](/2025/10/how-to-analyze-data-python-pandas-from-zero-to-insights.html).

### Filtering

Already configured with `django-filter`. Use query parameters:

```bash
# Filter by category slug
GET /api/books/?categories__slug=fiction

# Filter by author ID
GET /api/books/?authors=1

# Filter by publication date
GET /api/books/?publication_date=2024-01-01

# Multiple filters
GET /api/books/?categories__slug=fiction&min_price=10&max_price=50

# Filter by availability
GET /api/books/?available=true
```

**Add custom filter backend:**

```python
# books/filters.py

import django_filters
from .models import Book

class BookFilter(django_filters.FilterSet):
    min_price = django_filters.NumberFilter(field_name='price', lookup_expr='gte')
    max_price = django_filters.NumberFilter(field_name='price', lookup_expr='lte')
    title = django_filters.CharFilter(lookup_expr='icontains')
    author_name = django_filters.CharFilter(field_name='authors__name', lookup_expr='icontains')

    class Meta:
        model = Book
        fields = ['categories', 'authors', 'publication_date']

# In views.py
from .filters import BookFilter

class BookViewSet(viewsets.ModelViewSet):
    filterset_class = BookFilter
```

### Search

```bash
# Search in title, description, ISBN, author name
GET /api/books/?search=python

# Search authors
GET /api/authors/?search=rowling
```

### Ordering

```bash
# Order by price (ascending)
GET /api/books/?ordering=price

# Order by price (descending)
GET /api/books/?ordering=-price

# Multiple ordering
GET /api/books/?ordering=-publication_date,title
```

### Pagination

**Page number pagination (default):**

```bash
GET /api/books/              # Page 1 (default)
GET /api/books/?page=2       # Page 2
GET /api/books/?page_size=20 # Custom page size
```

Response:

```json
{
  "count": 150,
  "next": "http://localhost:8000/api/books/?page=3",
  "previous": "http://localhost:8000/api/books/?page=1",
  "results": [...]
}
```

**Limit-offset pagination:**

```python
# settings.py
REST_FRAMEWORK = {
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.LimitOffsetPagination',
    'PAGE_SIZE': 10
}
```

```bash
GET /api/books/?limit=20&offset=40  # Items 41-60
```

**Cursor pagination (best for large datasets):**

```python
# settings.py
REST_FRAMEWORK = {
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.CursorPagination',
    'PAGE_SIZE': 10
}
```

More efficient for large tables, prevents offset issues.

**Custom pagination:**

```python
# books/pagination.py

from rest_framework.pagination import PageNumberPagination

class StandardResultsSetPagination(PageNumberPagination):
    page_size = 10
    page_size_query_param = 'page_size'
    max_page_size = 100

class LargeResultsSetPagination(PageNumberPagination):
    page_size = 100
    page_size_query_param = 'page_size'
    max_page_size = 1000

# In views.py
class BookViewSet(viewsets.ModelViewSet):
    pagination_class = StandardResultsSetPagination
```

## Testing Your API

Writing tests ensures your API works correctly and catches regressions.

**Create tests (books/tests.py):**

```python
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from django.urls import reverse
from .models import Author, Category, Book, Review

class BookAPITestCase(APITestCase):

    def setUp(self):
        """Set up test data"""
        # Create users
        self.admin = User.objects.create_superuser('admin', 'admin@test.com', 'admin123')
        self.user = User.objects.create_user('user', 'user@test.com', 'user123')

        # Create test data
        self.author = Author.objects.create(name='Test Author')
        self.category = Category.objects.create(name='Fiction', slug='fiction')

        self.book = Book.objects.create(
            title='Test Book',
            slug='test-book',
            isbn='1234567890123',
            description='Test description',
            publisher='Test Publisher',
            publication_date='2024-01-01',
            pages=300,
            price=29.99,
            stock=10
        )
        self.book.authors.add(self.author)
        self.book.categories.add(self.category)

        self.client = APIClient()

    def test_list_books(self):
        """Test retrieving book list"""
        response = self.client.get('/api/books/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)

    def test_retrieve_book(self):
        """Test retrieving single book"""
        response = self.client.get(f'/api/books/{self.book.slug}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['title'], 'Test Book')

    def test_create_book_unauthenticated(self):
        """Test creating book without authentication fails"""
        data = {
            'title': 'New Book',
            'slug': 'new-book',
            'isbn': '9876543210987',
            'description': 'New book description',
            'publisher': 'New Publisher',
            'publication_date': '2024-02-01',
            'pages': 250,
            'price': 19.99,
            'stock': 5,
            'authors': [self.author.id],
            'categories': [self.category.id]
        }
        response = self.client.post('/api/books/', data)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_book_authenticated(self):
        """Test creating book as authenticated admin"""
        self.client.force_authenticate(user=self.admin)

        data = {
            'title': 'New Book',
            'slug': 'new-book',
            'isbn': '9876543210987',
            'description': 'New book description',
            'publisher': 'New Publisher',
            'publication_date': '2024-02-01',
            'pages': 250,
            'price': 19.99,
            'stock': 5,
            'authors': [self.author.id],
            'categories': [self.category.id]
        }
        response = self.client.post('/api/books/', data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Book.objects.count(), 2)

    def test_update_book(self):
        """Test updating book"""
        self.client.force_authenticate(user=self.admin)

        data = {'price': 39.99}
        response = self.client.patch(f'/api/books/{self.book.slug}/', data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.book.refresh_from_db()
        self.assertEqual(float(self.book.price), 39.99)

    def test_delete_book(self):
        """Test deleting book"""
        self.client.force_authenticate(user=self.admin)

        response = self.client.delete(f'/api/books/{self.book.slug}/')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(Book.objects.count(), 0)

    def test_filter_books_by_category(self):
        """Test filtering books by category"""
        response = self.client.get('/api/books/?categories__slug=fiction')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)

    def test_search_books(self):
        """Test searching books"""
        response = self.client.get('/api/books/?search=Test')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)

    def test_create_review(self):
        """Test creating review"""
        self.client.force_authenticate(user=self.user)

        data = {
            'book': self.book.id,
            'rating': 5,
            'title': 'Great book!',
            'comment': 'Really enjoyed this book.'
        }
        response = self.client.post('/api/reviews/', data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Review.objects.count(), 1)

    def test_update_own_review(self):
        """Test user can update their own review"""
        self.client.force_authenticate(user=self.user)

        review = Review.objects.create(
            book=self.book,
            user=self.user,
            rating=4,
            title='Good',
            comment='Nice book'
        )

        data = {'rating': 5, 'title': 'Excellent!'}
        response = self.client.patch(f'/api/reviews/{review.id}/', data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        review.refresh_from_db()
        self.assertEqual(review.rating, 5)

    def test_cannot_update_others_review(self):
        """Test user cannot update another user's review"""
        other_user = User.objects.create_user('other', 'other@test.com', 'pass123')

        review = Review.objects.create(
            book=self.book,
            user=other_user,
            rating=4,
            title='Good',
            comment='Nice book'
        )

        self.client.force_authenticate(user=self.user)
        data = {'rating': 1}
        response = self.client.patch(f'/api/reviews/{review.id}/', data)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
```

**Run tests:**

```bash
# Run all tests
python manage.py test

# Run specific app tests
python manage.py test books

# Run specific test case
python manage.py test books.tests.BookAPITestCase

# Run with verbose output
python manage.py test --verbosity=2

# Keep test database for inspection
python manage.py test --keepdb
```

**Test coverage:**

```bash
pip install coverage

# Run tests with coverage
coverage run --source='.' manage.py test

# View coverage report
coverage report

# Generate HTML report
coverage html
# Open htmlcov/index.html in browser
```

Want to automate your testing workflow? Check out my [Python automation guide](/2025/10/python-automation-scripts-every-developer-should-know.html) to learn how to automatically run tests, generate reports, and send notifications.

## Deploying to Production

Let's deploy your API to a VPS (DigitalOcean, AWS EC2, etc.).

**Production checklist:**

1. **Environment variables**

```python
# settings.py
from decouple import config

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', cast=lambda v: [s.strip() for s in v.split(',')])

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME'),
        'USER': config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
    }
}
```

Create `.env` file:

```bash
SECRET_KEY=your-secret-key-here
DEBUG=False
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
DB_NAME=bookstore_db
DB_USER=bookstore_user
DB_PASSWORD=secure-password
DB_HOST=localhost
DB_PORT=5432
```

2. **Install production dependencies:**

```bash
pip install gunicorn psycopg2-binary whitenoise
```

3. **Static files:**

```python
# settings.py

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # Add this
    # ... other middleware
]

STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
```

4. **Security settings:**

```python
# settings.py (production)

DEBUG = False
ALLOWED_HOSTS = ['yourdomain.com', 'www.yourdomain.com']

SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'

# CORS (adjust for your frontend)
CORS_ALLOWED_ORIGINS = [
    "https://yourdomain.com",
    "https://www.yourdomain.com",
]
```

5. **Gunicorn configuration:**

```python
# gunicorn_config.py

bind = "0.0.0.0:8000"
workers = 3
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2
```

6. **Nginx configuration:**

```nginx
# /etc/nginx/sites-available/bookstore

server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    location = /favicon.ico { access_log off; log_not_found off; }

    location /static/ {
        alias /home/user/bookstore-api/staticfiles/;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

7. **Systemd service:**

```ini
# /etc/systemd/system/bookstore.service

[Unit]
Description=Bookstore API
After=network.target

[Service]
User=user
Group=www-data
WorkingDirectory=/home/user/bookstore-api
Environment="PATH=/home/user/bookstore-api/venv/bin"
ExecStart=/home/user/bookstore-api/venv/bin/gunicorn \
    --config gunicorn_config.py \
    bookstore.wsgi:application

[Install]
WantedBy=multi-user.target
```

8. **Deploy commands:**

```bash
# On server
git clone your-repo
cd bookstore-api
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Set up PostgreSQL
sudo -u postgres psql
CREATE DATABASE bookstore_db;
CREATE USER bookstore_user WITH PASSWORD 'password';
GRANT ALL PRIVILEGES ON DATABASE bookstore_db TO bookstore_user;
\q

# Run migrations
python manage.py migrate

# Collect static files
python manage.py collectstatic --noinput

# Create superuser
python manage.py createsuperuser

# Start service
sudo systemctl start bookstore
sudo systemctl enable bookstore

# Restart Nginx
sudo systemctl restart nginx

# Check status
sudo systemctl status bookstore
```

9. **SSL with Let's Encrypt:**

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

For detailed SSL setup instructions, see my [Nginx with Certbot guide](/2025/08/nginx-certbot-ubuntu-24-04-free-https.html).

Your API is now live at `https://yourdomain.com/api/`!

## Next Steps

You now know how to build production-ready REST APIs with Django REST Framework. Here's what to explore next:

**Advanced DRF topics:**
- Nested serializers and writable nested relationships
- Custom authentication backends
- WebSocket support with Django Channels
- Caching strategies (Redis, Memcached)
- File uploads and cloud storage (S3, Cloudinary)
- API versioning
- Rate limiting strategies
- Background tasks with Celery
- GraphQL with Graphene-Django

**Related skills:**
- **Frontend integration**: Connect React/Vue to your API
- **Deployment automation**: CI/CD with GitHub Actions, GitLab CI
- **Monitoring**: Sentry for errors, Prometheus for metrics
- **Load balancing**: Multiple Gunicorn instances behind Nginx
- **Containerization**: Docker and Kubernetes
- **Database optimization**: Query optimization, indexing, connection pooling

**For faster APIs**, check out my [FastAPI tutorial](/2025/08/fastapi-tutorial-build-rest-api-from-scratch-beginner-guide.html) to compare Django REST Framework with FastAPI's async approach.

**For automation**, my [Python automation guide](/2025/10/python-automation-scripts-every-developer-should-know.html) shows how to automate API testing, deployment, and monitoring tasks.

**For data analysis on API logs**, see [Pandas data analysis tutorial](/2025/10/how-to-analyze-data-python-pandas-from-zero-to-insights.html) to analyze request patterns, user behavior, and performance metrics.

The best way to master DRF is to build real projects. Start with a simple API (todo list, blog, inventory), add authentication, deploy it, then add complexity (payments, notifications, real-time features).

Django REST Framework powers some of the world's largest APIs. You're now equipped with the same tools.

Go build something real.

---

If you enjoyed this tutorial, you might also like learning [how to build web scrapers with Python](/2025/10/how-to-build-web-scraper-python-beautifulsoup-requests.html) to collect data for your APIs, or check out my guide on [Python automation scripts](/2025/10/python-automation-scripts-every-developer-should-know.html) to streamline your development workflow. For analyzing API usage data, see my [Pandas data analysis tutorial](/2025/10/how-to-analyze-data-python-pandas-from-zero-to-insights.html).

**Questions or feedback?** Drop a comment below!