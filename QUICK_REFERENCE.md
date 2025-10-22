# BuanaCoding Quick Reference Guide

## File Locations Summary

### Content Files
- **Articles**: `/content/blog/[category]/` (go/, python/, laravel/, linux/, security/, general/)
- **Pages**: `/content/` (about.md, contact.md, privacy-policy.md, disclaimer.md)

### Template Files
- **Base Layout**: `/layouts/_default/baseof.html`
- **Article Layout**: `/layouts/_default/single.html`
- **List/Archive**: `/layouts/_default/list.html`
- **Partials**: `/layouts/partials/` (header, footer, faq, social-share, comments, etc.)
- **Link Rendering**: `/layouts/_default/_markup/render-link.html`

### Configuration
- **Main Config**: `/hugo.toml`
- **i18n Strings**: `/i18n/en.yaml`, `/i18n/id.yaml`
- **Tailwind Config**: `/tailwind.config.js`
- **Node Deps**: `/package.json`

### Important Partials
| File | Purpose |
|------|---------|
| `head.html` | SEO meta tags, OG, Twitter Card, JSON-LD |
| `header.html` | Navigation, search, language switcher, theme toggle |
| `faq.html` | FAQ accordion with schema markup |
| `footer.html` | Footer links |
| `social-share-header.html` | Social sharing buttons below title |
| `comments.html` | Giscus GitHub discussions |
| `scripts.html` | JavaScript: theme toggle, search, scroll-to-top |
| `adsense-*.html` | Various ad unit placements |

---

## Article Frontmatter Template

```yaml
---
title: "Article Title"
date: 2025-10-20T06:00:00+07:00
draft: false
url: /2025/10/article-slug.html
tags:
  - Go
  - Tag2
  - Tag3
description: "Short description for meta tags (150-160 chars)"
keywords:
  - "keyword1"
  - "keyword2"
author: "Wiku Karno"
og_image: "https://example.com/image.jpg"
hero: "https://example.com/hero.jpg"
disable_comments: false

faq:
  - question: "Question 1?"
    answer: "Answer text with **markdown** support"
  - question: "Question 2?"
    answer: "Another answer"
---
```

---

## Article Structure Pattern

```markdown
---
[frontmatter]
---

# Opening Paragraph (1-2 paragraphs with engaging hook)

## Section 1 Title
Content with explanation

```language
code example
```

### Subsection 1.1
More details

## Section 2 Title
[Continue pattern]

## Related Resources
[Links using {{< relref >}}]

## FAQ Section
[Automatically rendered from frontmatter]
```

---

## Hugo Shortcodes & Syntax

### Internal Links
```markdown
[Link text]({{< relref "blog/go/article-filename.md" >}})
```

### Image with Alt Text
```markdown
![Alt text](https://example.com/image.jpg)
```

### Language-specific Content
```markdown
[English text]({{< relref "blog/go/article-slug.md" >}})
```

---

## Navigation & URL Patterns

| Page | URL |
|------|-----|
| Home | `/` or `/id/` (Indonesian) |
| Blog Articles | `/2025/10/article-slug.html` |
| Tag Archive | `/tags/go/`, `/tags/python/`, etc. |
| Category | `/blog/go/` |
| About | `/about` |
| Search | Built-in modal (client-side) |

---

## Key Parameters in hugo.toml

```toml
# Navigation tags shown in header
navTags = ["General", "Go", "Laravel", "Linux", "Python", "Security"]

# Site metadata
author = "Wiku Karno"
description = "Buana Coding is your go-to resource..."
keywords = ["coding", "programming", ...]
defaultImage = "https://www.buanacoding.com/images/og-image.jpg"

# Comments (Giscus)
[params.giscus]
  repo = "wikukarno/buanacoding"
  repoID = "R_kgD0Oj4jAw"
  category = "General"

# Ads
[params.ads]
  forceLive = false  # Set true to show ads in hugo server

# Consent (Google Consent Mode v2)
[params.consent]
  ad_storage = "granted"
  analytics_storage = "granted"
```

---

## SEO Elements Implemented

- **Meta Tags**: title, description, keywords, canonical
- **Open Graph**: og:title, og:description, og:url, og:image, og:type
- **Twitter Card**: twitter:card, twitter:title, twitter:description, twitter:image
- **Hreflang**: Language alternates for multi-language content
- **JSON-LD Schema**: BlogPosting (articles), FAQPage (FAQ sections)
- **Robots.txt**: Auto-generated
- **Sitemap**: `/sitemap.xml` (monthly changefreq, 0.5 priority)

---

## CSS Classes & Styling

### Typography
- `prose prose-blue dark:prose-invert` - Article content (Tailwind Typography)
- `text-2xl font-bold` - H2 headings
- `text-lg font-semibold` - H3 headings

### Layout
- `max-w-7xl mx-auto` - Content wrapper (1280px max)
- `grid grid-cols-1 lg:grid-cols-3 gap-8` - 3-column article layout

### Colors
- Primary: `#0f7ea9` (teal blue)
- Dark mode: `#094d66`
- Background: Light `#fafaf8`, Dark `#0f172a`

### Responsive
- `hidden lg:block` - Desktop only
- `lg:hidden` - Mobile only
- `sm:col-span-2` - Responsive grid

---

## Taxonomy & Tags

### Available Categories
1. **General** - AI tools, productivity
2. **Go** - REST APIs, Goroutines, Modules, CLI
3. **Python** - FastAPI, JWT, Computer Vision
4. **Laravel** - Queue jobs, Octane, Security
5. **Linux** - Docker, Nginx, Ubuntu setup
6. **Security** - Passkeys, Password mgmt, Phishing

### Tag Rules
- Minimum 2 articles to show in sidebar
- Max 20 tags in sidebar
- Curated nav tags: ["General", "Go", "Laravel", "Linux", "Python", "Security"]

---

## Markdown Formatting Examples

```markdown
# H1 - Page Title
## H2 - Main Section
### H3 - Subsection

**Bold text**
*Italic text*
`inline code`

> Blockquote

- Unordered list item 1
- Unordered list item 2

1. Ordered item 1
2. Ordered item 2

```language
code block with syntax highlighting
```

[Link text](https://example.com)
[Internal link]({{< relref "blog/go/article.md" >}})

![Alt text](https://example.com/image.jpg)

<!--readmore-->
(Marks article excerpt boundary)
```

---

## Development Commands

```bash
# Local development (hot reload)
hugo server

# Build production
hugo

# Clean build
rm -rf public && hugo

# New article
hugo new blog/go/article-title.md
```

---

## File Size Reference

| Type | Typical Size |
|------|--------------|
| Simple article | 300-500 lines |
| Detailed tutorial | 800-1200 lines |
| Comprehensive guide | 1500+ lines |
| Average | 900 words (~600 lines) |

---

## Important Notes

1. **URLs are custom** - Each article has a `url` parameter in frontmatter
2. **Tags drive navigation** - Both header nav and sidebar populate from tags
3. **FAQ is schema-marked** - Appears in rich snippets, auto-closes
4. **Relref links are safe** - Won't break if files move (within content/)
5. **Images are optional** - og_image and hero are fallback chain
6. **Comments are GitHub Discussions** - Requires GitHub login
7. **Search is client-side** - Uses Fuse.js with JSON index
8. **Multi-language** - English root, Indonesian at /id/

---

## External Integrations

- **Comments**: Giscus (GitHub Discussions)
- **Analytics**: Google Analytics (G-0EN9J73FXF)
- **Ads**: Google AdSense (ca-pub-3149036684216973)
- **Hosting**: Vercel
- **Build**: Hugo Static Site Generator
- **Styling**: Tailwind CSS + Typography plugin

---

## Conventions

### URL Pattern
```
/YYYY/MM/article-slug.html
```

### Filename Pattern
```
article-title-with-hyphens.md
```

### Directory Pattern
```
/content/blog/[category]/filename.md
```

### Title Pattern
```
"Action/Description - Technology/Focus Area"
```
Examples:
- "Building REST API with Gin Framework Golang - Production Ready"
- "How to Implement Message Queuing with RabbitMQ in Go"
- "FastAPI JWT Auth with OAuth2 Password Flow (Pydantic v2 + SQLAlchemy 2.0)"

---

## Performance Features

- **Static Generation** - No database queries, CDN-friendly
- **CSS Pruning** - Tailwind removes unused styles
- **Responsive Images** - Lazy loading with loading="eager" on hero
- **Code Highlighting** - Syntax.css for fast highlighting
- **Client-side Search** - Fuse.js, no server requests
- **Gzip Compression** - HTML/CSS/JS auto-compressed by hosting
- **HTTP/2** - Vercel provides multiplexing

---

## Common Edits

### Add New Article
1. Create `/content/blog/[category]/article-slug.md`
2. Copy frontmatter template
3. Write content in markdown
4. Add FAQ items
5. Add internal links using relref
6. Set `draft: false`
7. Run `hugo` to build

### Update Article
1. Edit file in `/content/blog/[category]/`
2. Update `date` to current date (optional, for "recently updated")
3. Rebuild: `hugo`

### Add Navigation Tag
1. Edit `hugo.toml`
2. Update `navTags` array
3. Rebuild: `hugo`

### Change Theme Color
1. Search for `#0f7ea9` in files
2. Replace with new color hex
3. Also update dark mode color `#094d66`

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Article not showing | Check `draft: false` in frontmatter |
| Broken internal link | Use relref syntax, check filename |
| Image not loading | Use full HTTPS URL |
| FAQ not rendering | Check YAML syntax in faq array |
| Comments not showing | Verify Giscus config in hugo.toml |
| Search not working | Check `/public/index.json` exists |
| Dark mode not toggling | Verify scripts.html is loaded |

---

## See Also
- Full analysis: `/CONTENT_STRUCTURE_ANALYSIS.md`
- Hugo docs: https://gohugo.io/documentation/
- Tailwind docs: https://tailwindcss.com/
