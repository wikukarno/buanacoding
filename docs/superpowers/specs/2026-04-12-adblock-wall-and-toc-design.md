# Anti-Adblock Hard Wall & Floating Sidebar TOC

**Date:** 2026-04-12
**Status:** Approved
**Scope:** 2 features — anti-adblock wall + floating TOC

---

## Feature 1: Anti-Adblock Hard Wall

### Goal

Block content access for users with ad blockers (Brave, uBlock Origin, AdBlock Plus, etc.). Users must disable adblock before reading any page.

### Detection Strategy (Bait + AdSense Confirmation)

**Step 1 — Bait element (fast, ~300ms):**
- Inject a hidden `<div>` with class names commonly blocked by adblock filters (e.g., `ad-banner`, `ads-container`)
- Set dimensions to 1px, position absolute, off-screen
- After 300ms, check if the element was hidden/removed by adblock
- If element has `offsetHeight === 0` or `display: none` or was removed from DOM → adblock likely active

**Step 2 — AdSense confirmation (~2-3s):**
- Check if `window.adsbygoogle` is undefined
- Check if any `<ins class="adsbygoogle">` element has `offsetHeight === 0`
- If either condition is true → adblock confirmed

**Trigger:** If Step 1 OR Step 2 detects adblock → activate wall.

### Wall Behavior

When adblock is detected:
1. Inject full-screen overlay via JavaScript (`position: fixed`, `z-index: 9999`, dark backdrop)
2. Set `document.body.style.overflow = 'hidden'` (prevent scrolling)
3. Apply `filter: blur(8px)` to main content behind overlay
4. Display message with instructions to disable adblock
5. Show "I've Disabled My Ad Blocker" button that reloads the page (`location.reload()`)

When no adblock:
- Nothing happens, page loads normally

### Overlay Content

```
[Shield Icon]

Ad Blocker Detected

We rely on ads to keep this content free.
Please disable your ad blocker to continue reading.

How to disable:
1. Click the ad blocker icon in your browser toolbar
2. Select "Disable on this site" or "Pause"
3. Refresh the page

[Button: "I've Disabled My Ad Blocker"]
```

Language: English only.

### Scope

Applied to ALL pages (homepage, articles, list pages, static pages).

### Anti-Circumvent Measures

- All CSS and JS inline (no external files that can be blocked)
- Class names obfuscated (avoid filterable names like "adblock-wall", "adblock-overlay")
- Overlay injected via JS, not static HTML (harder for filter lists to target)
- Detection script embedded inline in partial, not in a separate .js file

### Files

| File | Action | Purpose |
|------|--------|---------|
| `layouts/partials/adblock-wall.html` | Create | Overlay HTML + inline CSS + JS detection logic |
| `layouts/_default/baseof.html` | Modify | Include `adblock-wall.html` partial before `</body>` |

---

## Feature 2: Floating Sidebar TOC

### Goal

Add a sticky Table of Contents in the article sidebar that highlights the current section as the user scrolls, improving navigation and time-on-page.

### TOC Generation

Use Hugo built-in `.TableOfContents` which auto-extracts h2 and h3 headings from article markdown. Zero external dependencies.

### Layout & Position

- Placed in the existing right sidebar of `single.html` (desktop only, `lg:block`)
- Position: `sticky`, `top: 80px` (below navbar)
- TOC sits above "Popular Posts" section in sidebar
- TOC only renders if article has >= 3 headings; otherwise sidebar shows Popular Posts only

### Scroll Behavior

- Intersection Observer watches all h2/h3 elements in the article
- When a heading enters the viewport, the corresponding TOC item gets active styling
- Clicking a TOC item smooth-scrolls to the heading

### Styling

- Font: `text-sm`, matching existing sidebar typography
- Heading hierarchy: h2 = no indent, h3 = small left indent (`pl-3`)
- Active item: text color `#0f7ea9`, left border accent (`border-l-2 border-[#0f7ea9]`)
- Inactive: `text-gray-600 dark:text-gray-400`
- Dark mode: follows existing dark theme variables
- Max height: `max-h-[60vh]` with `overflow-y: auto` for long TOCs
- Transition: smooth color transition on active state change

### Responsive

- **Desktop (lg+):** Visible, sticky sidebar
- **Mobile (<lg):** Hidden (`hidden lg:block`), consistent with existing sidebar behavior

### Files

| File | Action | Purpose |
|------|--------|---------|
| `layouts/_default/single.html` | Modify | Add TOC block in sidebar above Popular Posts |
| `layouts/partials/scripts.html` | Modify | Add Intersection Observer JS for scroll highlight |

---

## Out of Scope

- Newsletter/email signup form
- Last updated date display
- PWA/Service Worker
- Multi-language support for adblock wall messages
- Mobile TOC (collapse/expand)
