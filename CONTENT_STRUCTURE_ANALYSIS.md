# BuanaCoding Content Structure Analysis

## Executive Summary
BuanaCoding is a Hugo-based static site generator project for a developer blog/tutorial platform. It uses YAML frontmatter for metadata, includes comprehensive SEO features, multi-language support (English and Indonesian), and implements FAQ sections with schema markup.

---

## 1. Overall Folder Structure and Organization

```
buanacoding.com/
├── archetypes/              # Hugo content templates
│   └── default.md          # Default article template
├── assets/                  # CSS and styling
│   └── css/
│       ├── style.css       # Main CSS (Tailwind compiled)
│       └── syntax.css      # Code syntax highlighting
├── content/                 # All markdown content
│   ├── about.md            # About page
│   ├── contact.md          # Contact page
│   ├── disclaimer.md       # Legal pages
│   ├── privacy-policy.md
│   └── blog/               # Article categories
│       ├── general/        # General articles
│       ├── go/             # Go programming tutorials (40+ articles)
│       ├── laravel/        # PHP/Laravel tutorials
│       ├── linux/          # Linux/DevOps tutorials
│       ├── python/         # Python/FastAPI tutorials
│       └── security/       # Security-focused articles
├── i18n/                    # Internationalization
│   ├── en.yaml             # English translations
│   └── id.yaml             # Indonesian translations
├── layouts/                 # Hugo templates
│   ├── _default/
│   │   ├── baseof.html     # Base template
│   │   ├── single.html     # Single article layout
│   │   ├── list.html       # List/taxonomy layout
│   │   ├── taxonomy.html   # Tag pages layout
│   │   └── _markup/
│   │       └── render-link.html  # Custom link rendering
│   └── partials/           # Reusable components
│       ├── head.html       # SEO meta tags
│       ├── header.html     # Navigation
│       ├── footer.html     # Footer
│       ├── faq.html        # FAQ component
│       ├── social-share-*.html  # Social sharing components
│       ├── comments.html   # Giscus comments
│       ├── adsense-*.html  # AdSense ad units
│       ├── scripts.html    # JavaScript
│       └── ... (other partials)
├── public/                  # Generated site (ignored in git)
├── static/                  # Static files (images, postman collections)
├── resources/              # Generated resources
├── hugo.toml              # Hugo configuration
├── package.json           # Node dependencies (Tailwind CSS)
├── tailwind.config.js     # Tailwind CSS config
├── Makefile              # Build commands
└── vercel.json           # Vercel deployment config
```

---

## 2. Article/Content Structure

### 2.1 Article Organization by Category
Articles are stored in `/content/blog/` categorized by topic:

- **Go** (40+ articles): REST APIs, gRPC, Goroutines, Modules, CLI tools, etc.
- **Python** (8+ articles): FastAPI, JWT auth, Computer Vision, REST APIs
- **Laravel** (5+ articles): Queue jobs, Octane, Security, Caching
- **Linux** (6+ articles): Docker, Nginx, Ubuntu setup, Commands
- **Security** (3+ articles): Passkeys, Password managers, Phishing
- **General** (2+ articles): AI tools, VSCode extensions

### 2.2 Frontmatter/Metadata Structure

All articles use YAML frontmatter with consistent fields:

```yaml
---
title: "Article Title"                    # Required
date: 2025-10-20T06:00:00+07:00          # ISO 8601 with timezone
draft: false                              # Publication status
url: /2025/10/article-slug.html          # Custom URL path
tags:                                     # Multiple tags for categorization
  - Go
  - RabbitMQ
  - Message Queue
  - Distributed Systems
description: "SEO description..."         # Short summary for meta tags
keywords:                                 # SEO keywords array
  - "keyword1"
  - "keyword2"
  - "keyword3"
author: "Wiku Karno"                      # Author name (optional)
og_image: "https://example.com/img.jpg"  # Open Graph image (optional)
hero: "https://example.com/hero.jpg"     # Hero/featured image (optional)
disable_comments: false                   # Enable/disable Giscus comments

# Frequently Asked Questions - Schema.org compatible
faq:
  - question: "What is RabbitMQ?"
    answer: "RabbitMQ is a message broker that implements AMQP..."
  - question: "How do I use it?"
    answer: "First, install RabbitMQ. Then connect with..."
---
```

### 2.3 Content Body Structure

Article content uses standard Markdown with:

1. **Opening**: Engaging introduction paragraph (1-2 paragraphs)
2. **Table of Contents**: Auto-generated from headings
3. **Sections**: H2 headers (`##`) for main sections, H3 (`###`) for subsections
4. **Code Blocks**: Fenced with language specification (```go, ```bash, etc.)
5. **Internal Links**: Using Hugo's relref syntax
   ```
   {{< relref "blog/go/other-article.md" >}}
   ```
6. **Call-to-Outs**: References to related articles
7. **Practical Examples**: Real code snippets with explanations
8. **Best Practices**: Tips and warnings throughout

### 2.4 Example Article Structure

**File**: `/home/wikukarno/development/buanacoding.com/content/blog/go/building-rest-api-gin-framework-golang-production-ready.md`

- **Size**: 917 lines
- **Sections**:
  - Why Choose Gin Over Standard net/http
  - Setting Up Development Environment
  - Project Structure and Architecture
  - Creating User Model and Validation
  - Utility Functions for Security
  - Controllers and Request Handling
  - Middleware Implementation
  - Error Handling
  - Production Deployment
- **FAQ Items**: 6 comprehensive Q&A pairs
- **Code Examples**: 10+ complete Go code snippets
- **Internal References**: Links to related tutorials

---

## 3. Header/Navigation Components

### 3.1 Header Component (`/layouts/partials/header.html`)

**Features**:
- **Logo**: BUANACODING text-based logo linking to home
- **Desktop Navigation** (hidden on mobile):
  - Tag links (curated from `params.navTags` in hugo.toml)
  - Language switcher (EN/ID buttons)
  - Search icon
  - Theme toggle (dark/light)
- **Mobile Menu** (hamburger icon toggle):
  - Collapsible tag links
  - Language switcher
  - Search button
  - Theme toggle
- **Search Modal**: Full-width search with Fuse.js for client-side search

### 3.2 Navigation Tags Configuration

In `hugo.toml`:
```toml
[params]
  navTags = ["General", "Go", "Laravel", "Linux", "Python", "Security"]
```

### 3.3 Header Styling
- Color: `#0f7ea9` (corporate teal blue)
- Dark mode: `#094d66`
- Uses Tailwind CSS utility classes
- Feather Icons for UI icons (search, sun/moon, menu)

---

## 4. Content Structure and Patterns

### 4.1 Single Article Layout (`/layouts/_default/single.html`)

**Layout**: 3-column grid on desktop (2 on mobile)

```
┌─────────────────────────────────────────┐
│              Header/Nav                 │
├────────────────────┬────────────────────┤
│                    │                    │
│  Article Content   │   Right Sidebar    │
│  (col-span 2)      │   (hidden mobile)  │
│                    │                    │
│ • Breadcrumb nav   │ • Popular Posts    │
│ • Title            │ • Tags             │
│ • Social share     │                    │
│ • Hero image       │                    │
│ • Content (prose)  │                    │
│ • Ads (in-article) │                    │
│ • "Read Also" box  │                    │
│ • FAQ section      │                    │
│ • Comments        │                    │
└────────────────────┴────────────────────┘
```

### 4.2 Content Rendering Features

**Breadcrumb Navigation**:
```html
Home / #{{ first_tag }} / Article Title
```

**Social Share Icons** (below title):
- Twitter/X
- Facebook
- LinkedIn
- WhatsApp
- Copy Link (with feedback)

**Hero Image**:
- Optional (from `og_image` or `hero` frontmatter)
- Responsive with rounded corners and border

**Prose Styling**:
- Uses Tailwind's `@tailwindcss/typography` plugin
- Class: `prose prose-blue dark:prose-invert`
- Responsive text sizing
- Code highlighting with syntax.css

**Related Articles**:
- "Read Also" section showing 3 related articles
- Filtering by first tag (intelligent matching)
- Falls back to all blog articles if no matches

**Ad Placement**:
- Header leaderboard (468x60)
- After 3 paragraphs (mid-article)
- Sidebar 300x250 (desktop only)
- Mobile banner
- In-feed ads
- Footer banner

---

## 5. FAQ Implementation

### 5.1 FAQ Component (`/layouts/partials/faq.html`)

**Features**:
- Accordion-style using HTML `<details>` element
- Auto-close behavior (one open at a time)
- Arrow icon rotation animation
- Smooth transitions
- Schema.org markup for SEO

### 5.2 FAQ Data Structure

Frontmatter FAQ array:
```yaml
faq:
  - question: "Short question?"
    answer: "Detailed answer with markdown support"
  - question: "Another question?"
    answer: "Can include **bold**, *italics*, `code`"
```

### 5.3 Schema Markup

Implements `FAQPage` schema.org structure:
```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "question text",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "answer text"
      }
    }
  ]
}
```

**Benefits**:
- Rich snippets in Google Search Results
- Featured FAQ display
- Improved click-through rate
- Mobile-friendly

### 5.4 Styling
- Question text is bold (font-semibold)
- Answer content uses prose styling with markdown support
- Responsive padding (py-5 md:py-6)
- Hover effect on questions
- Mobile-optimized spacing

---

## 6. SEO Implementation

### 6.1 Meta Tags (`/layouts/partials/head.html`)

**Standard Meta Tags**:
```html
<title>{{ title }}</title>
<meta name="description" content="{{ description }}">
<meta name="keywords" content="{{ keywords }}">
<link rel="canonical" href="{{ .Permalink }}">
```

**Hreflang Alternates** (for multi-language):
```html
<link rel="alternate" hreflang="en" href="...">
<link rel="alternate" hreflang="id" href="...">
<link rel="alternate" hreflang="x-default" href="...">
```

**Open Graph / Facebook**:
```html
<meta property="og:type" content="article|website">
<meta property="og:title" content="{{ title }}">
<meta property="og:description" content="{{ description }}">
<meta property="og:url" content="{{ permalink }}">
<meta property="og:image" content="{{ image }}">
```

**Twitter Card**:
```html
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{{ title }}">
<meta name="twitter:description" content="{{ description }}">
<meta name="twitter:image" content="{{ image }}">
```

### 6.2 Structured Data (JSON-LD)

**BlogPosting Schema** (for articles):
```json
{
  "@context": "https://schema.org",
  "@type": "BlogPosting",
  "headline": "Article Title",
  "description": "Article description",
  "datePublished": "2025-10-20T06:00:00Z",
  "dateModified": "2025-10-20T06:00:00Z",
  "author": {
    "@type": "Person",
    "name": "Wiku Karno"
  },
  "publisher": {
    "@type": "Organization",
    "name": "Buana Coding"
  },
  "image": "https://..."
}
```

### 6.3 Sitemap and Robots
- Auto-generated sitemap.xml
- Robots.txt (from Hugo output)
- Monthly changefreq, 0.5 priority default
- Supports language-specific sitemaps

### 6.4 Analytics & Tracking
- Google Analytics (ID: G-0EN9J73FXF)
- Google Consent Mode v2
- AdSense integration (ca-pub-3149036684216973)
- Giscus comments system
- Environment-based tracking (disabled on `hugo server`)

### 6.5 Canonical URLs

Each article has a custom `url` in frontmatter:
```yaml
url: /2025/10/article-slug.html
```

Generates canonical: `https://www.buanacoding.com/2025/10/article-slug.html`

---

## 7. Title/Heading Patterns

### 7.1 Page Title Generation

**Home Page**:
```
Buana Coding
```

**Article Pages**:
```
{{ Article Title }} | Buana Coding
```

**Category/Tag Pages**:
```
{{ Category Name }} | Buana Coding
```

### 7.2 Article Heading Hierarchy

**H1 (Page Title)**:
```markdown
{{ .Title }}
```

**H2 (Main Sections)**:
```markdown
## Why Choose Gin Over Standard net/http
## Setting Up Your Development Environment
## Project Structure and Architecture
```

**H3 (Subsections)**:
```markdown
### Installing RabbitMQ
### Verify Installation
### Go RabbitMQ Client
```

### 7.3 Title Conventions

Articles use descriptive, SEO-friendly titles:
- Pattern: `[Action/Description]-[Technology]-[Focus Area]`
- Examples:
  - "Building REST API with Gin Framework Golang - Production Ready"
  - "FastAPI JWT Auth with OAuth2 Password Flow (Pydantic v2 + SQLAlchemy 2.0)"
  - "How to Implement Message Queuing with RabbitMQ in Go"

---

## 8. Internal Linking Structure and Patterns

### 8.1 Internal Link Implementation

**Hugo Relref Syntax**:
```markdown
[Link text]({{< relref "blog/go/article-filename.md" >}})
```

**Cross-Language Links**:
```markdown
{{< relref "blog/python/fastapi-jwt-auth-oauth2-password-flow-pydantic-v2-sqlalchemy-2.md" >}}
```

**Link Render Hook** (`/layouts/_default/_markup/render-link.html`):
- Detects external links (http://, https://)
- Adds `target="_blank"` and `rel="nofollow noopener noreferrer"` to external links
- Preserves internal/relative links
- Handles anchors and mailto/tel schemes

### 8.2 Linking Patterns in Articles

**Type 1: Related Topic Links** (within article body):
```
"If you're new to Go project organization, check out our guide on [structuring Go 
projects with clean architecture]({{< relref "blog/go/structuring-go-projects-clean-project-structure-and-best-practices.md" >}})"
```

**Type 2: "Read Also" Section** (auto-generated):
- Displays 3 related articles by matching tags
- Falls back to popular articles if no tag matches
- Links: `<a href="{{ .RelPermalink }}">`

**Type 3: Navigation Links**:
- Tag pages: `/tags/go`, `/tags/python`, etc.
- Category pages: `/blog/go`, `/blog/python`
- Home: `/` or `{{ "/" | relLangURL }}`

**Type 4: Breadcrumb Navigation**:
```html
Home / #{{ tag }} / Article Title
```

### 8.3 Link Statistics

**Go Category Example** (`building-rest-api-gin-framework-golang-production-ready.md`):
- 3 internal relref links to related Go articles
- 1 internal link to Linux installation guide
- Multiple references in FAQ section

---

## 9. Markdown/Content Files Format

### 9.1 File Naming Convention

Pattern: `{{ article-title-with-hyphens }}.md`

Examples:
- `how-to-implement-message-queuing-with-rabbitmq-in-go.md`
- `fastapi-jwt-auth-oauth2-password-flow-pydantic-v2-sqlalchemy-2.md`
- `building-rest-api-gin-framework-golang-production-ready.md`

### 9.2 Default Archetype

`/archetypes/default.md`:
```toml
+++
date = '{{ .Date }}'
draft = true
title = '{{ replace .File.ContentBaseName "-" " " | title }}'
+++
```

**Note**: Uses TOML frontmatter format (can be converted to YAML)

### 9.3 Content Section

**HTML Comments**:
```markdown
<!--readmore-->
```
- Marks article excerpt boundary
- Used for truncation on list pages

**Code Blocks**:
```
```go
package main
func main() {}
```
```
- Syntax highlighting with language specification
- Supported: go, bash, python, javascript, sql, etc.

**Lists**:
- Unordered: `- Item` or `* Item`
- Ordered: `1. Item`
- Nested support

**Callout Patterns**:
- **Bold** for emphasis: `**Important concept**`
- *Italics* for definitions: `*term*`
- `Inline code` for technical terms: `` `code` ``
- Block quotes: `> Blockquote text`

### 9.4 Content File Statistics

- **Average Length**: 500-1000+ lines
- **Code Blocks**: 5-15 per article
- **Internal Links**: 2-5 per article
- **FAQ Items**: 3-8 per article
- **Sections (H2)**: 5-10 per article

---

## 10. Configuration Files Related to Content Management

### 10.1 Hugo Configuration (`hugo.toml`)

```toml
baseURL = "https://www.buanacoding.com/"
languageCode = "en"
title = "Buana Coding"
defaultContentLanguage = "en"
defaultContentLanguageInSubdir = false

[markup.highlight]
  style = "github"
  noClasses = false

[taxonomies]
  tag = "tags"

[pagination]
  pagerSize = 6

[sitemap]
  changefreq = "monthly"
  priority = 0.5
  filename = "sitemap.xml"

[outputs]
  home = ["HTML", "RSS", "JSON", "SITEMAP", "ROBOTS"]
  section = ["HTML", "RSS", "SITEMAP"]
  taxonomy = ["HTML", "SITEMAP"]

[params]
  author = "Wiku Karno"
  description = "Buana Coding is your go-to resource for programming tutorials..."
  keywords = ["coding", "programming", "web development", ...]
  defaultImage = "https://www.buanacoding.com/images/og-image.jpg"
  navTags = ["General", "Go", "Laravel", "Linux", "Python", "Security"]

  [params.tags]
    minCount = 2
    maxSidebar = 20

  [params.giscus]
    repo = "wikukarno/buanacoding"
    repoID = "R_kgD0Oj4jAw"
    category = "General"
    categoryID = "DIC_kwD0Oj4jA84Cr_fx"

[languages]
  [languages.en]
    languageName = "English"
    weight = 1
  [languages.id]
    languageName = "Indonesia"
    weight = 2
```

### 10.2 Build Configuration

**package.json** (Node dependencies):
```json
{
  "devDependencies": {
    "@tailwindcss/typography": "^0.5.16",
    "tailwindcss": "^4.1.4",
    "autoprefixer": "^10.4.21",
    "postcss": "^8.5.3"
  }
}
```

**tailwind.config.js**:
```javascript
module.exports = {
  content: [
    "./layouts/**/*.html",
    "./content/**/*.md",
    "./themes/**/*.{html,js}",
    "./assets/js/**/*.js"
  ],
  theme: { extend: {} },
  plugins: [require('@tailwindcss/typography')]
};
```

### 10.3 Internationalization (`i18n/`)

**en.yaml** and **id.yaml**:
```yaml
- id: read_more
  translation: "Read more"
- id: home
  translation: "Home"
- id: blog
  translation: "Blog"
- id: frequently_asked_questions
  translation: "Frequently Asked Questions"
```

Used in templates: `{{ i18n "home" }}`

### 10.4 Giscus Comments Configuration

In `hugo.toml`:
```toml
[params.giscus]
  repo = "wikukarno/buanacoding"
  repoID = "R_kgD0Oj4jAw"
  category = "General"
  categoryID = "DIC_kwD0Oj4jA84Cr_fx"
```

GitHub Discussions integration for article comments.

### 10.5 Deployment Configurations

**vercel.json** (Vercel deployment):
- Specifies build and output settings
- Redirects configuration
- Environment variables setup

**Makefile** (Build commands):
```makefile
build:    # Build with Hugo
serve:    # Serve locally with hot reload
clean:    # Clean output
```

---

## 11. Content Management Summary

### Key Metrics
- **Total Articles**: 50+ across 6 categories
- **Languages**: 2 (English + Indonesian)
- **SEO Elements**: Comprehensive (meta, OG, Twitter Card, structured data)
- **Average Article**: 500-1000 lines, 900+ words
- **FAQ Per Article**: 3-8 questions
- **Code Examples**: 5-15 per article
- **Internal Links**: 2-5 per article

### Content Workflow

1. **Create**: Article in `content/blog/[category]/`
2. **Format**: YAML frontmatter + markdown body
3. **Link**: Use Hugo relref for internal links
4. **FAQ**: Add structured Q&A pairs
5. **Publish**: Set `draft: false` in frontmatter
6. **Build**: Hugo generates static HTML
7. **Deploy**: Push to Vercel

### Best Practices Identified

1. **Consistent Frontmatter**: All required fields standardized
2. **Structured Linking**: Using relref prevents broken links
3. **FAQ Schema**: JSON-LD for rich snippets
4. **Multi-Language**: i18n support baked in
5. **Performance**: Static site generation (zero DB queries)
6. **Responsive**: Mobile-first with Tailwind CSS
7. **Accessibility**: Semantic HTML, ARIA labels
8. **SEO**: Comprehensive meta, OG, JSON-LD, canonical URLs

---

## Practical Examples

### Example 1: Article File Path
```
/content/blog/go/how-to-implement-message-queuing-with-rabbitmq-in-go.md
```

### Example 2: Generated URL
```
https://www.buanacoding.com/2025/10/how-to-implement-message-queuing-with-rabbitmq-in-go.html
```

### Example 3: Frontmatter
```yaml
---
title: "How to Implement Message Queuing with RabbitMQ in Go"
description: "Complete guide to implementing message queuing with RabbitMQ in Go..."
date: 2025-10-20T06:00:00+07:00
tags: ["Go", "RabbitMQ", "Message Queue", "Distributed Systems"]
url: /2025/10/how-to-implement-message-queuing-with-rabbitmq-in-go.html
faq:
  - question: "What is RabbitMQ?"
    answer: "RabbitMQ is a message broker..."
---
```

### Example 4: Internal Link
```markdown
[Structuring Go Projects]({{< relref "blog/go/structuring-go-projects-clean-project-structure-and-best-practices.md" >}})
```

### Example 5: Breadcrumb
```
Home / #Go / Building REST API with Gin Framework Golang
```

---

## File Location Reference

| Component | Path | Purpose |
|-----------|------|---------|
| Articles | `/content/blog/[category]/` | Main article storage |
| Layouts | `/layouts/` | HTML templates |
| Head/SEO | `/layouts/partials/head.html` | Meta tags & structured data |
| Navigation | `/layouts/partials/header.html` | Navigation components |
| FAQ | `/layouts/partials/faq.html` | FAQ implementation |
| Single Page | `/layouts/_default/single.html` | Article page layout |
| List Page | `/layouts/_default/list.html` | Category/archive layout |
| Config | `/hugo.toml` | Main configuration |
| i18n | `/i18n/` | Language files |
| Styles | `/assets/css/` | CSS files (Tailwind) |
| Static | `/static/` | Images, downloads |
| Archetypes | `/archetypes/` | Content templates |

---

## Conclusion

BuanaCoding is a well-structured, production-ready Hugo site with:
- Professional SEO implementation (meta tags, OG, JSON-LD, FAQ schema)
- Comprehensive content organization across 6 topic categories
- Multi-language support (English/Indonesian)
- Interactive features (search, comments, dark mode)
- Monetization (AdSense integration)
- Developer-friendly content format (YAML frontmatter, markdown)
- Responsive design with Tailwind CSS
- Static site generation for performance and security

All content follows consistent patterns and conventions, making it easy to maintain and scale.
