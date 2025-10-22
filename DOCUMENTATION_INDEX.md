# BuanaCoding Documentation Index

## Overview
This directory contains comprehensive documentation of the BuanaCoding website structure, content organization, and implementation patterns.

---

## Documentation Files

### 1. CONTENT_STRUCTURE_ANALYSIS.md (23 KB)
**Comprehensive technical analysis of the entire codebase**

Contents:
- Overall folder structure and organization
- Article/content structure and organization
- Header/navigation components
- Content structure and rendering patterns
- FAQ implementation details
- SEO implementation (meta tags, structured data)
- Title and heading patterns
- Internal linking structure and patterns
- Markdown/content files format
- Configuration files related to content management
- Content management summary with best practices

**Best For**: Understanding how the site works, architectural decisions, comprehensive reference

**Read This If**: You need to understand the entire system, make major changes, or onboard new team members

---

### 2. QUICK_REFERENCE.md (8.8 KB)
**Practical quick-lookup guide for daily development tasks**

Contents:
- File locations summary
- Article frontmatter template
- Article structure pattern
- Hugo shortcodes and syntax
- Navigation and URL patterns
- Key parameters in hugo.toml
- SEO elements implemented
- CSS classes and styling
- Taxonomy and tags
- Markdown formatting examples
- Development commands
- Important notes and conventions
- Common edits and troubleshooting

**Best For**: Quick lookups during content creation, practical examples, daily tasks

**Read This If**: You're writing articles, editing content, or troubleshooting common issues

---

## Quick Navigation

### I Need To...

| Task | See Section | Document |
|------|-------------|----------|
| Understand the site architecture | Section 1 | CONTENT_STRUCTURE_ANALYSIS |
| Write a new article | Article Structure Pattern | QUICK_REFERENCE |
| Create frontmatter | Article Frontmatter Template | QUICK_REFERENCE |
| Add internal links | Hugo Shortcodes & Syntax | QUICK_REFERENCE |
| Implement FAQ | Section 5 | CONTENT_STRUCTURE_ANALYSIS |
| Optimize for SEO | Section 6 | CONTENT_STRUCTURE_ANALYSIS |
| Change navigation tags | Key Parameters in hugo.toml | QUICK_REFERENCE |
| Find a component file | File Locations Summary | QUICK_REFERENCE |
| Understand link rendering | Section 8 | CONTENT_STRUCTURE_ANALYSIS |
| Fix a problem | Troubleshooting | QUICK_REFERENCE |

---

## Key Facts

**Technology Stack**
- Hugo static site generator
- Tailwind CSS with Typography plugin
- Vercel hosting
- Giscus for comments
- Google Analytics and AdSense
- Fuse.js for client-side search

**Content Organization**
- 50+ articles across 6 categories
- YAML frontmatter metadata
- Multi-language support (English + Indonesian)
- 3-8 FAQ items per article
- 2-5 internal links per article

**SEO Implementation**
- Comprehensive meta tags
- Open Graph + Twitter Card
- BlogPosting + FAQPage schema.org markup
- Hreflang for language alternates
- Auto-generated sitemap

**Article Specifications**
- Average: 900 words (~600 lines)
- Average code blocks: 5-15 per article
- FAQ questions: 3-8 per article
- Categories: Go, Python, Laravel, Linux, Security, General

---

## File Locations Quick Reference

```
buanacoding.com/
├── CONTENT_STRUCTURE_ANALYSIS.md    ← Comprehensive analysis
├── QUICK_REFERENCE.md               ← Practical guide
├── DOCUMENTATION_INDEX.md           ← This file
├── content/
│   ├── blog/
│   │   ├── go/                      (40+ articles)
│   │   ├── python/                  (8+ articles)
│   │   ├── laravel/                 (5+ articles)
│   │   ├── linux/                   (6+ articles)
│   │   ├── security/                (3+ articles)
│   │   └── general/                 (2+ articles)
│   ├── about.md
│   ├── contact.md
│   ├── privacy-policy.md
│   └── disclaimer.md
├── layouts/
│   ├── _default/
│   │   ├── baseof.html              (base template)
│   │   ├── single.html              (article layout)
│   │   ├── list.html                (list/category layout)
│   │   └── _markup/
│   │       └── render-link.html     (link rendering)
│   └── partials/                    (reusable components)
│       ├── head.html                (SEO meta tags)
│       ├── header.html              (navigation)
│       ├── faq.html                 (FAQ component)
│       ├── footer.html              (footer)
│       ├── social-share-*.html      (share buttons)
│       ├── comments.html            (Giscus)
│       ├── scripts.html             (JavaScript)
│       └── adsense-*.html           (ad placements)
├── hugo.toml                        (main config)
├── i18n/
│   ├── en.yaml                      (English translations)
│   └── id.yaml                      (Indonesian translations)
├── assets/css/
│   ├── style.css                    (Tailwind CSS)
│   └── syntax.css                   (code highlighting)
├── tailwind.config.js               (CSS config)
├── package.json                     (Node dependencies)
└── vercel.json                      (deployment config)
```

---

## Common Workflows

### Creating a New Article

1. **Create file**: `/content/blog/[category]/article-slug.md`
2. **Add frontmatter**: Use template from QUICK_REFERENCE
3. **Write content**: Use Markdown format from QUICK_REFERENCE
4. **Add FAQ items**: 3-8 questions in frontmatter
5. **Add internal links**: Use {{< relref >}} syntax
6. **Set draft: false**: When ready to publish
7. **Build**: Run `hugo` to generate static files

### Understanding a Component

1. **Identify component**: Find file in file locations table
2. **Check partial**: Most reusable components are in `/layouts/partials/`
3. **Review template**: Look at HTML structure
4. **Check parameters**: See what data it needs
5. **Find examples**: Search content files for usage

### Adding a New Category

1. **Create directory**: `/content/blog/new-category/`
2. **Add articles**: Create `.md` files in directory
3. **Add to navTags**: Update `hugo.toml` if needed
4. **Add i18n**: Optional, update `/i18n/` files
5. **Rebuild**: Run `hugo` to generate

---

## SEO Quick Reference

**For Each Article Include**:
- Meta title: "{{ title }} | Buana Coding"
- Meta description: 150-160 characters
- Keywords: 5-7 related terms
- Canonical URL: Custom `url` in frontmatter
- Open Graph image: Hero or og_image
- FAQ items: 3-8 Q&A pairs with schema markup

**Automatic SEO Elements**:
- BlogPosting schema.org markup
- Hreflang alternates for translations
- Sitemap generation
- Twitter Card markup
- Social share metadata

---

## Configuration Overview

### Main Settings (hugo.toml)
```toml
baseURL = "https://www.buanacoding.com/"
title = "Buana Coding"
author = "Wiku Karno"
navTags = ["General", "Go", "Laravel", "Linux", "Python", "Security"]
```

### i18n Support
- English: Default, at root (`/`)
- Indonesian: At `/id/`
- Translations in `/i18n/{en,id}.yaml`

### Comments (Giscus)
- GitHub Discussions integration
- Enables per-article comments
- Requires GitHub login to comment

### Monetization
- Google AdSense: ca-pub-3149036684216973
- 6 ad placement locations
- Consent Mode v2 integration

---

## Development Commands

```bash
# Local development with hot reload
hugo server

# Build for production
hugo

# Create new article
hugo new blog/category/article-title.md

# Clean and rebuild
rm -rf public && hugo
```

---

## Important Conventions

**Filename Pattern**:
```
article-title-with-hyphens.md
```

**URL Pattern**:
```
/YYYY/MM/article-slug.html
```

**Title Pattern**:
```
"Action/Description - Technology - Focus Area"
```

**Tag Convention**:
- Consistent capitalization (e.g., "Go", not "go")
- 2+ articles required to show in sidebar
- Max 20 tags in sidebar

**Directory Pattern**:
```
/content/blog/[category]/filename.md
```

---

## Troubleshooting Guide

| Problem | Solution | Reference |
|---------|----------|-----------|
| Article not visible | Check `draft: false` | QUICK_REFERENCE: Common Edits |
| Broken link | Use relref syntax | QUICK_REFERENCE: Hugo Shortcodes |
| Image not loading | Use full HTTPS URL | QUICK_REFERENCE: Important Notes |
| FAQ not showing | Check YAML syntax | QUICK_REFERENCE: Markdown Examples |
| Search broken | Rebuild site: `hugo` | QUICK_REFERENCE: Development Commands |
| Theme not toggling | Check scripts.html loaded | CONTENT_STRUCTURE: Section 3 |

---

## Best Practices

1. **Always use relref** for internal links (prevents broken links)
2. **Include FAQ** for improved search rankings (3-8 items)
3. **Use consistent metadata** (title, description, keywords)
4. **Write semantic HTML** (proper heading hierarchy)
5. **Optimize images** (use HTTPS URLs, appropriate sizes)
6. **Test responsively** (mobile + desktop)
7. **Link between articles** (builds internal authority)
8. **Keep metadata consistent** (title format, tag capitalization)

---

## Performance Considerations

- **Static generation**: Zero database queries
- **CSS purging**: Tailwind removes unused styles
- **Image optimization**: Lazy loading on hero images
- **Search optimization**: Client-side with Fuse.js
- **Caching**: CDN-friendly static assets
- **Compression**: Gzip by default on Vercel

---

## Further Reading

- **Hugo Documentation**: https://gohugo.io/documentation/
- **Tailwind CSS**: https://tailwindcss.com/
- **Schema.org**: https://schema.org/
- **Giscus**: https://giscus.app/
- **Vercel Docs**: https://vercel.com/docs

---

## Contact & Support

For questions about the site structure:
- See CONTENT_STRUCTURE_ANALYSIS.md for technical details
- See QUICK_REFERENCE.md for practical solutions
- Check existing articles for examples
- Review configuration files for settings

---

## Document Versions

- **CONTENT_STRUCTURE_ANALYSIS.md**: v1.0 (2025-10-21)
- **QUICK_REFERENCE.md**: v1.0 (2025-10-21)
- **DOCUMENTATION_INDEX.md**: v1.0 (2025-10-21)

Last Updated: 2025-10-21

---

*This documentation provides a complete overview of the BuanaCoding website structure, content organization, and implementation patterns. For updates or corrections, please refer to the source files and configuration.*
