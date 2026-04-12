# Anti-Adblock Hard Wall & Floating Sidebar TOC — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a hard-wall anti-adblock overlay that blocks all content until adblock is disabled, and a floating sticky TOC sidebar for article pages.

**Architecture:** Two independent features. Anti-adblock uses a new Hugo partial with inline JS/CSS injected via `baseof.html` on every page. TOC modifies the existing `single.html` sidebar and adds a small Intersection Observer script to `scripts.html`.

**Tech Stack:** Hugo templates, vanilla JavaScript, Tailwind CSS utility classes, Intersection Observer API.

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `layouts/partials/adblock-wall.html` | **Create** | Adblock detection logic + overlay HTML/CSS/JS (all inline) |
| `layouts/_default/baseof.html` | **Modify (line 25)** | Include adblock-wall partial before `</body>` |
| `layouts/_default/single.html` | **Modify (lines 127-144)** | Add TOC block above Popular Posts in sidebar |
| `layouts/partials/scripts.html` | **Modify (append after line 349)** | Add TOC scroll-highlight Intersection Observer JS |

---

### Task 1: Create Anti-Adblock Hard Wall Partial

**Files:**
- Create: `layouts/partials/adblock-wall.html`

- [ ] **Step 1: Create the adblock-wall partial**

Create `layouts/partials/adblock-wall.html` with the full detection + overlay logic inline:

```html
{{/* Anti-Adblock Hard Wall — all CSS/JS inline to prevent blocking */}}
{{ if or (not hugo.IsServer) (.Site.Params.ads.forceLive) }}
<div id="_cf_chl_opt" style="height:1px;width:1px;position:absolute;left:-9999px;top:-9999px;" class="ad-banner ads-container adsbygoogle"></div>
<script>
(function(){
  var w=window,d=document;
  function checkBait(){
    var b=d.getElementById('_cf_chl_opt');
    if(!b)return true;
    var s=w.getComputedStyle?w.getComputedStyle(b):b.currentStyle;
    if(!s)return true;
    return b.offsetHeight===0||s.display==='none'||s.visibility==='hidden';
  }
  function checkAds(){
    if(typeof w.adsbygoogle==='undefined')return true;
    var ins=d.querySelector('ins.adsbygoogle');
    if(ins&&ins.offsetHeight===0&&ins.dataset.adPushed==='true')return true;
    return false;
  }
  function showWall(){
    if(d.getElementById('_x9k2'))return;
    var o=d.createElement('div');
    o.id='_x9k2';
    o.innerHTML='<div style="position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.85);display:flex;align-items:center;justify-content:center;padding:20px;">'
      +'<div style="background:#fff;border-radius:16px;padding:40px 32px;max-width:480px;width:100%;text-align:center;box-shadow:0 25px 50px rgba(0,0,0,0.3);">'
      +'<div style="width:64px;height:64px;margin:0 auto 20px;background:#fee2e2;border-radius:50%;display:flex;align-items:center;justify-content:center;">'
      +'<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#dc2626" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>'
      +'</div>'
      +'<h2 style="margin:0 0 12px;font-size:22px;font-weight:700;color:#111827;">Ad Blocker Detected</h2>'
      +'<p style="margin:0 0 20px;font-size:15px;color:#6b7280;line-height:1.6;">We rely on ads to keep this content free. Please disable your ad blocker to continue reading.</p>'
      +'<div style="background:#f9fafb;border-radius:12px;padding:16px;margin:0 0 24px;text-align:left;">'
      +'<p style="margin:0 0 8px;font-size:13px;font-weight:600;color:#374151;">How to disable:</p>'
      +'<ol style="margin:0;padding:0 0 0 20px;font-size:13px;color:#6b7280;line-height:1.8;">'
      +'<li>Click the ad blocker icon in your browser toolbar</li>'
      +'<li>Select &quot;Disable on this site&quot; or &quot;Pause&quot;</li>'
      +'<li>Click the button below to reload</li>'
      +'</ol></div>'
      +'<button onclick="location.reload()" style="background:#0f7ea9;color:#fff;border:none;padding:14px 32px;border-radius:10px;font-size:15px;font-weight:600;cursor:pointer;width:100%;transition:background 0.2s;" onmouseover="this.style.background=\'#0c6a8f\'" onmouseout="this.style.background=\'#0f7ea9\'">I\'ve Disabled My Ad Blocker</button>'
      +'</div></div>';
    d.body.appendChild(o);
    d.body.style.overflow='hidden';
    var m=d.querySelector('main');
    if(m)m.style.filter='blur(8px)';
    var h=d.querySelector('header');
    if(h)h.style.filter='blur(8px)';
    var f=d.querySelector('footer');
    if(f)f.style.filter='blur(8px)';
  }
  function detect(){
    if(checkBait()){showWall();return;}
    setTimeout(function(){
      if(checkBait()||checkAds())showWall();
    },2500);
  }
  if(d.readyState==='loading'){d.addEventListener('DOMContentLoaded',function(){setTimeout(detect,300);});}
  else{setTimeout(detect,300);}
})();
</script>
{{ end }}
```

- [ ] **Step 2: Verify file created**

Run: `cat layouts/partials/adblock-wall.html | head -5`
Expected: Shows the Hugo comment and conditional on first lines.

- [ ] **Step 3: Commit**

```bash
git add layouts/partials/adblock-wall.html
git commit -m "feat: add anti-adblock hard wall partial with bait + AdSense detection"
```

---

### Task 2: Include Adblock Wall in Base Layout

**Files:**
- Modify: `layouts/_default/baseof.html:23-26`

- [ ] **Step 1: Add partial include before closing body tag**

In `layouts/_default/baseof.html`, add the adblock-wall partial after `scripts.html` (line 23) and before `</body>` (line 26).

Find this block (lines 23-26):
```html
    {{ partial "scripts.html" . }}

    
  </body>
```

Replace with:
```html
    {{ partial "scripts.html" . }}

    {{ partial "adblock-wall.html" . }}
  </body>
```

- [ ] **Step 2: Build and verify**

Run: `npx hugo --minify 2>&1 | tail -3`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add layouts/_default/baseof.html
git commit -m "feat: include adblock-wall partial in base layout"
```

---

### Task 3: Add Floating TOC to Article Sidebar

**Files:**
- Modify: `layouts/_default/single.html:127-144`

- [ ] **Step 1: Replace sidebar content with TOC + Popular Posts**

In `layouts/_default/single.html`, find the sidebar section (lines 127-144):

```html
  <!-- ==== RIGHT: SIDEBAR (Desktop Only) ==== -->
  <aside class="space-y-10 hidden lg:block">
    <!-- POPULAR POST -->
    <div>
      <h3 class="text-xl font-bold mb-4 text-gray-900 dark:text-white">{{ i18n "popular_post" }}</h3>
      <ul
        class="space-y-3 list-disc list-outside pl-5 text-sm text-gray-800 dark:text-gray-200"
      >
        {{ range first 5 (where .Site.RegularPages "Type" "blog") }}
        <li>
          <a href="{{ .RelPermalink }}" class="hover:text-[#0f7ea9] transition">{{ .Title }}</a>
        </li>
        {{ end }}
      </ul>
    </div>

    <!-- Sticky sidebar ad removed for better UX -->
  </aside>
```

Replace with:

```html
  <!-- ==== RIGHT: SIDEBAR (Desktop Only) ==== -->
  <aside class="hidden lg:block">
    <div class="sticky top-20 space-y-10">
      {{/* Table of Contents — only show if article has 3+ headings */}}
      {{ if and (eq .Section "blog") (gt (len .TableOfContents) 100) }}
      <nav id="toc-sidebar" class="not-prose">
        <h3 class="text-sm font-bold mb-3 text-gray-900 dark:text-white uppercase tracking-wide">Table of Contents</h3>
        <div id="toc-list" class="text-sm max-h-[60vh] overflow-y-auto pr-2 space-y-0.5">
          {{ .TableOfContents }}
        </div>
      </nav>
      {{ end }}

      <!-- POPULAR POST -->
      <div>
        <h3 class="text-xl font-bold mb-4 text-gray-900 dark:text-white">{{ i18n "popular_post" }}</h3>
        <ul
          class="space-y-3 list-disc list-outside pl-5 text-sm text-gray-800 dark:text-gray-200"
        >
          {{ range first 5 (where .Site.RegularPages "Type" "blog") }}
          <li>
            <a href="{{ .RelPermalink }}" class="hover:text-[#0f7ea9] transition">{{ .Title }}</a>
          </li>
          {{ end }}
        </ul>
      </div>
    </div>
  </aside>
```

Key changes:
- `<aside>` no longer has `space-y-10` — moved to inner `sticky` div
- Added `sticky top-20` wrapper so sidebar sticks while scrolling
- TOC nav block with `id="toc-sidebar"` conditionally rendered (only if `.TableOfContents` has content — Hugo returns minimal HTML when no headings, checking length > 100 catches this)
- Popular Posts preserved below TOC

- [ ] **Step 2: Build and verify**

Run: `npx hugo --minify 2>&1 | tail -3`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add layouts/_default/single.html
git commit -m "feat: add floating sidebar TOC for article pages"
```

---

### Task 4: Add TOC Styling via Tailwind Prose Override

**Files:**
- Modify: `layouts/_default/single.html` (TOC nav block from Task 3)

Hugo's `.TableOfContents` outputs a `<nav id="TableOfContents">` with nested `<ul>` and `<li>` elements. We need to style these since they're inside a `not-prose` context.

- [ ] **Step 1: Add inline style block for TOC links**

In `layouts/_default/single.html`, find the TOC nav block added in Task 3:

```html
      <nav id="toc-sidebar" class="not-prose">
        <h3 class="text-sm font-bold mb-3 text-gray-900 dark:text-white uppercase tracking-wide">Table of Contents</h3>
        <div id="toc-list" class="text-sm max-h-[60vh] overflow-y-auto pr-2 space-y-0.5">
          {{ .TableOfContents }}
        </div>
      </nav>
```

Replace with:

```html
      <nav id="toc-sidebar" class="not-prose">
        <h3 class="text-sm font-bold mb-3 text-gray-900 dark:text-white uppercase tracking-wide">Table of Contents</h3>
        <div id="toc-list" class="text-sm max-h-[60vh] overflow-y-auto pr-2">
          {{ .TableOfContents }}
        </div>
        <style>
          #toc-list ul{list-style:none;margin:0;padding:0}
          #toc-list li{margin:0;padding:0}
          #toc-list li li{padding-left:0.75rem}
          #toc-list a{display:block;padding:4px 8px;border-left:2px solid transparent;color:#6b7280;text-decoration:none;transition:all 0.2s;border-radius:0 4px 4px 0;font-size:0.8125rem;line-height:1.5}
          #toc-list a:hover{color:#0f7ea9;background:rgba(15,126,169,0.05)}
          #toc-list a.active{color:#0f7ea9;border-left-color:#0f7ea9;font-weight:600;background:rgba(15,126,169,0.08)}
          [data-theme="dark"] #toc-list a{color:#9ca3af}
          [data-theme="dark"] #toc-list a:hover{color:#38bdf8;background:rgba(56,189,248,0.08)}
          [data-theme="dark"] #toc-list a.active{color:#38bdf8;border-left-color:#38bdf8;background:rgba(56,189,248,0.1)}
        </style>
      </nav>
```

- [ ] **Step 2: Build and verify**

Run: `npx hugo --minify 2>&1 | tail -3`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add layouts/_default/single.html
git commit -m "feat: add TOC link styling with active state and dark mode support"
```

---

### Task 5: Add TOC Scroll Highlight JavaScript

**Files:**
- Modify: `layouts/partials/scripts.html` (append before closing `</script>` tag, line 349)

- [ ] **Step 1: Add Intersection Observer for TOC highlight**

In `layouts/partials/scripts.html`, find the closing `</script>` tag at line 350. Insert the following code BEFORE it (after line 349, the closing `})();` of the Google Translate IIFE):

Find:
```javascript
  })();
</script>
```

Replace with:
```javascript
  })();

  // TOC scroll highlight
  (function(){
    var tocEl=document.getElementById('toc-list');
    if(!tocEl)return;
    var links=tocEl.querySelectorAll('a[href^="#"]');
    if(!links.length)return;
    var headings=[];
    links.forEach(function(a){
      var id=decodeURIComponent(a.getAttribute('href').slice(1));
      var h=document.getElementById(id);
      if(h)headings.push({el:h,link:a});
    });
    if(!headings.length)return;
    var current=null;
    var observer=new IntersectionObserver(function(entries){
      entries.forEach(function(entry){
        if(entry.isIntersecting){
          if(current)current.classList.remove('active');
          var match=headings.find(function(h){return h.el===entry.target;});
          if(match){match.link.classList.add('active');current=match.link;
            match.link.scrollIntoView&&match.link.scrollIntoView({block:'nearest',behavior:'smooth'});
          }
        }
      });
    },{rootMargin:'-80px 0px -70% 0px',threshold:0});
    headings.forEach(function(h){observer.observe(h.el);});
    // Smooth scroll on TOC click
    links.forEach(function(a){
      a.addEventListener('click',function(e){
        e.preventDefault();
        var id=decodeURIComponent(a.getAttribute('href').slice(1));
        var target=document.getElementById(id);
        if(target)target.scrollIntoView({behavior:'smooth',block:'start'});
        history.pushState(null,null,a.getAttribute('href'));
      });
    });
  })();
</script>
```

- [ ] **Step 2: Build and verify**

Run: `npx hugo --minify 2>&1 | tail -3`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add layouts/partials/scripts.html
git commit -m "feat: add TOC scroll-highlight with Intersection Observer"
```

---

### Task 6: Final Build Verification & Push

**Files:** None (verification only)

- [ ] **Step 1: Full build**

Run: `npx hugo --minify 2>&1 | tail -5`
Expected: Build succeeds, page count unchanged (~539 pages).

- [ ] **Step 2: Spot-check generated HTML for adblock wall**

Run: `grep '_cf_chl_opt' public/index.html | head -1`
Expected: Shows the bait div element in homepage output.

- [ ] **Step 3: Spot-check generated HTML for TOC**

Run: `grep 'toc-sidebar' public/2025/09/event-driven-architecture-golang-message-queues.html | head -1`
Expected: Shows the TOC nav element in an article page.

- [ ] **Step 4: Push to remote**

```bash
git push origin main
```
