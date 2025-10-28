---
title: "How to Build a Web Scraper in Python with BeautifulSoup and Requests"
date: 2025-10-27T10:00:00+07:00
draft: false
url: /2025/10/how-to-build-web-scraper-python-beautifulsoup-requests.html
tags:
  - Python
  - Web Scraping
  - BeautifulSoup
  - Tutorial
  - Automation
description: "Learn how to build a complete web scraper in Python using BeautifulSoup and Requests. Step-by-step tutorial covering HTML parsing, data extraction, ethical scraping practices, and real-world projects."
keywords: ["python web scraping", "beautifulsoup tutorial", "requests library", "web scraper python", "html parsing", "data extraction", "python automation", "web scraping tutorial"]
featured: false
faq:
  - question: "Is web scraping legal and how can I scrape ethically without getting blocked?"
    answer: "Web scraping is legal when you're collecting publicly available data, but legality depends on what you scrape, how you access it, and your jurisdiction. Always check robots.txt (located at website.com/robots.txt) to see which paths are allowed or disallowed for crawlers. Respect rate limits by implementing delays between requests--a conservative approach is one request every 10-15 seconds. Use a realistic User-Agent header instead of the default Python-requests identifier which screams 'bot' to websites. Never scrape data behind authentication without permission, avoid collecting personal identifiable information (PII), and never bypass CAPTCHAs or security measures. The GDPR in Europe now treats ignoring robots.txt as a factor against your legitimate interest claim. Recent court cases like Meta vs Bright Data have sided with public web scraping, but you must act in good faith. Always honor Terms of Service where reasonable, implement exponential backoff on errors, and consider reaching out to sites for API access first. Ethical scraping respects server resources--if your scraper causes performance issues or costs, you've crossed the line. Add delays with time.sleep(), randomize request intervals, cache results to avoid repeat requests, and monitor HTTP status codes (429 means rate limited, 503 means server overloaded). Include contact info in your User-Agent so webmasters can reach you if needed. For production scrapers, implement proper logging, rotate user agents and IPs if scraping at scale, and always assume the website owner can see your activity. The golden rule: scrape websites the way you'd want others to scrape yours--respectfully, transparently, and without causing harm."
  - question: "What's the difference between BeautifulSoup parsers (html.parser, lxml, html5lib) and which should I use?"
    answer: "BeautifulSoup supports three main parsers and each has trade-offs for speed, accuracy, and dependencies. html.parser is Python's built-in parser--it requires no external dependencies, works everywhere Python runs, and handles most websites fine. It's moderately fast and lenient with broken HTML but sometimes fails on severely malformed markup. Use it for simple scrapers, learning, or when you can't install dependencies. lxml is the fastest parser available, often 5-10x quicker than html.parser on large documents. It requires the lxml C library to be installed (pip install lxml), which can be tricky on some systems. It's strict about HTML structure but includes good error recovery. Choose lxml for production scrapers processing many pages, large HTML documents, or when performance matters. It's the default choice for most professional scrapers. html5lib is the most lenient parser--it parses HTML exactly like a web browser would, handling even horribly broken HTML gracefully. It requires the html5lib package and is significantly slower than both alternatives, often 10-50x slower than lxml. Use it only when html.parser and lxml both fail on broken markup, or when you absolutely need browser-identical parsing behavior. The parser affects how BeautifulSoup builds the parse tree and handles edge cases. Switching parsers can change results on malformed HTML--text might appear in different places in the tree or be missing entirely. In practice: start with html.parser for learning and simple scripts, upgrade to lxml when you need speed or are scraping many pages, and only use html5lib as a last resort for problem websites. When specifying: BeautifulSoup(html, 'html.parser') vs BeautifulSoup(html, 'lxml') vs BeautifulSoup(html, 'html5lib'). If you don't specify, BeautifulSoup picks automatically based on what's installed, preferring lxml if available. For production code, always explicitly specify the parser so behavior is consistent across environments."
  - question: "How do I handle dynamic content loaded by JavaScript when BeautifulSoup only sees the initial HTML?"
    answer: "BeautifulSoup and Requests only fetch the raw HTML response from the server--they don't execute JavaScript, so any content loaded dynamically won't appear in your parsed data. There are several solutions depending on your needs. First, check if the site has an API--open browser DevTools (F12), go to the Network tab, and reload the page while filtering by XHR/Fetch requests. Many sites load data via JSON APIs that JavaScript then renders. Scraping the API directly is faster, more reliable, and less likely to break than parsing HTML. Look for requests to endpoints returning JSON--you can often call these directly with requests.get() and parse JSON instead of HTML. Second, use Selenium or Playwright for full browser automation--these tools control real browsers (Chrome, Firefox) and wait for JavaScript to execute before extracting content. Selenium is mature and widely used: from selenium import webdriver; driver = webdriver.Chrome(); driver.get(url). Playwright is newer, faster, and has better APIs. Both let you wait for elements to appear, scroll pages to trigger infinite scroll, click buttons, and interact like a human. The downside is they're much slower (seconds vs milliseconds) and more resource-intensive than Requests. Use them only when necessary. Third, analyze the JavaScript source code to find data sources--sometimes data is embedded in script tags as JSON, or the JS builds API URLs you can replicate. Search the page source for JSON-looking data structures. Fourth, use requests-html library which includes a simple JavaScript renderer based on Chromium. Fifth, consider using a headless browser service like Splash or paid APIs like ScraperAPI that handle JavaScript rendering for you. For dynamic content patterns like infinite scroll, Selenium is usually required--you'll scroll gradually (driver.execute_script('window.scrollTo(0, document.body.scrollHeight)')) and wait for content to load between scrolls. For sites requiring interaction (clicking 'load more', filling forms), browser automation is your only option. However, check robots.txt and Terms of Service extra carefully when using browser automation--it's more detectable and resource-intensive than simple HTTP requests. A hybrid approach works well: use Requests + BeautifulSoup for static content and Selenium only for pages requiring JavaScript. This keeps most scraping fast while handling edge cases."
  - question: "My scraper worked yesterday but returns different HTML or errors today--how do I make it reliable and maintainable?"
    answer: "Websites change constantly and scrapers break--it's the nature of web scraping. Building reliable scrapers requires defensive programming, monitoring, and maintenance strategies. First, expect and handle failures gracefully. Wrap all requests in try-except blocks catching requests.exceptions.RequestException for network issues, and check response.status_code before parsing (200 means success, 404 is not found, 429 is rate limited, 503 is server error). Implement retry logic with exponential backoff--if a request fails, wait 1 second and retry, then 2 seconds, then 4, up to a maximum. Use the retrying or tenacity libraries to automate this. Second, websites change their HTML structure. Avoid brittle selectors like soup.find('div').find('div').find('span')--the nth div might change. Instead, use semantic selectors targeting IDs, classes with clear names, or data attributes that are less likely to change. soup.find('article', class_='product-card') is more stable than soup.find_all('div')[7]. Add fallback selectors: try multiple ways to find the same data. If soup.find(id='price') fails, try soup.find(class_='price-tag'), then regex on text. Third, validate extracted data immediately. Check types, ranges, and required fields: if price is None or not price.strip() or float(price) < 0: log_error(). This catches problems early before bad data enters your pipeline. Fourth, implement comprehensive logging. Log every request URL, response status, parsing success/failure, and extracted data samples. Use Python's logging module with timestamps and levels (DEBUG, INFO, WARNING, ERROR). When things break, logs tell you exactly what changed. Fifth, separate scraping logic from parsing logic. Write functions like fetch_page(url) and parse_product(soup) separately. This makes testing easier and lets you cache HTML for testing parsing logic without hitting the website repeatedly. Sixth, add monitoring and alerts. For production scrapers, track metrics like success rate, average response time, and data quality. Alert when success rate drops below 90% or no data extracted for X hours. Tools like Sentry or simple email alerts work. Seventh, version control your scrapers in git and document which HTML structure they expect. When updating, keep old parsing code for a while to compare outputs. Eighth, for important scrapers, save raw HTML periodically so you can reprocess if parsing logic improves. Finally, accept that maintenance is unavoidable--websites redesign, add anti-bot protection, or go offline. Plan for regular updates and monitoring. Build scrapers knowing they'll need attention every few months."
  - question: "How do I scrape multiple pages efficiently--should I use threading, asyncio, or multiprocessing?"
    answer: "When scraping multiple pages, the right concurrency approach depends on your bottleneck. Web scraping is IO-bound (waiting for network responses) not CPU-bound, so threading or asyncio is almost always better than multiprocessing. Sequential scraping (one request at a time) is simplest but slow--if each page takes 2 seconds and you need 1000 pages, that's 33 minutes. With concurrency, you can get 10-50x speedup depending on the website. Threading with concurrent.futures.ThreadPoolExecutor is the easiest concurrency approach. Threads share memory, work well with blocking libraries like Requests, and Python's ThreadPoolExecutor handles the complexity. Example: with ThreadPoolExecutor(max_workers=5) as executor: results = executor.map(scrape_page, urls). Start with 5-10 workers and increase gradually while monitoring for errors or rate limiting. Too many concurrent requests will get you blocked--respect the website. Threading has overhead from thread creation and the GIL (Global Interpreter Lock) limits true parallelism, but for IO-bound scraping this doesn't matter. asyncio with aiohttp is faster than threading for large-scale scraping. It uses cooperative multitasking--one thread interleaves many requests during IO waits. asyncio scales to hundreds or thousands of concurrent requests with lower overhead than threads. However, it requires async/await syntax throughout your code (async def scrape(), await response.text()) and you can't use synchronous libraries like Requests--you must use aiohttp. BeautifulSoup works fine in async code since parsing is synchronous. Use asyncio when scraping thousands of pages and you're comfortable with async Python. multiprocessing spawns separate Python processes, bypassing the GIL for true parallelism. Use it only when parsing HTML is the bottleneck (CPU-intensive regex, large documents) not network requests. Processes have high overhead and don't share memory easily. Rarely needed for web scraping. Best practices for concurrent scraping: implement rate limiting even with concurrency--add delays between requests or use a token bucket algorithm. Handle errors per-request, not per-batch--one failure shouldn't crash your whole scraper. Use a queue or job system for large scrape jobs so you can pause/resume and track progress. Save results incrementally, not at the end--if your scraper crashes after 6 hours, you don't want to lose everything. Consider using a task queue like Celery for production scrapers that need reliability, monitoring, and retries. For small to medium scrapers (under 10,000 pages), threading with ThreadPoolExecutor and 5-10 workers is the sweet spot--simple, fast enough, and compatible with all libraries. For large-scale scraping, invest time learning asyncio or use a framework like Scrapy that handles concurrency for you. Always test concurrency levels gradually and monitor website response--getting blocked wastes more time than slow scraping."
  - question: "How should I store and export scraped data, and what's the best way to handle large datasets?"
    answer: "Data storage depends on your data volume, structure, and intended use. For small scraping jobs (hundreds to a few thousand records), CSV files are simplest: use Python's csv module or pandas.to_csv(). CSV is universal, opens in Excel, and easy to share. However, CSV has limitations--no standard for nested data, encoding issues with special characters, and no data types (everything becomes text). For structured data with relationships, use JSON: json.dump(data, file) or pandas.to_json(). JSON preserves data types, handles nested structures naturally, and is widely supported. But JSON files can be huge and aren't efficient for querying. For medium datasets (thousands to millions of records) or when you need to query data, use SQLite--it's a file-based SQL database requiring no server setup. Use Python's sqlite3 module or SQLAlchemy ORM. SQLite lets you query, index, and join data efficiently. Create a database schema matching your scraped data structure, insert records as you scrape (commit every 100-1000 records for performance), and query results later. For large-scale or production scraping, use a proper database server like PostgreSQL or MySQL. They handle concurrent access, large datasets efficiently, and integrate with analytics tools. For high-volume scraping, consider these strategies: stream data to disk incrementally rather than loading everything in memory--scrape one page, write results, clear memory, repeat. Use batch inserts for databases (100-1000 records at once) instead of inserting one at a time. If scraping millions of records, partition data by date, category, or chunks to avoid giant files. For huge datasets, consider data warehouses like BigQuery or data lakes. File format matters for large data: Parquet is a columnar format that compresses well and queries fast--used widely in data engineering. Consider pandas.to_parquet() for analytical datasets. JSONL (newline-delimited JSON) is better than JSON for large files--each line is a valid JSON object, so you can stream-process without loading the entire file. Best practices for data export: validate data immediately after scraping--check for required fields, data types, and reasonable values. Store raw scraped data separately from cleaned data so you can reprocess if cleaning logic improves. Include metadata like scrape timestamp, source URL, and scraper version. Implement deduplication--use unique IDs or hashes to avoid scraping the same item twice. For production systems, consider this pipeline: scrape -> store raw data in database or files -> transform/clean data -> export to final format. Use a tool like Apache Airflow to orchestrate this pipeline. Handle incremental scraping for sites that update--only scrape new or changed items by tracking last-scrape timestamps or comparing hashes. For sharing data, CSV or Excel for business users, JSON or Parquet for developers, SQL database dumps for technical users. Always document your data schema, field meanings, and any data quality issues. Include a README with scrape date, methodology, and known limitations. Most importantly, secure your data appropriately--scraped data might contain PII or sensitive information, so encrypt at rest, limit access, and comply with data protection regulations like GDPR. Choose storage based on this decision tree: prototype or one-time scrape -> CSV or JSON. Repeated scraping or need to query -> SQLite. Production system or team access -> PostgreSQL. Big data or analytics -> Parquet or data warehouse."
---

I spent three weeks last month manually copying product prices from competitor websites into spreadsheets for a client's market analysis. Three. Weeks. Every day, opening dozens of browser tabs, copying prices, checking specifications, pasting into Excel. My eyes hurt, my wrists hurt, and I kept making mistakes because humans aren't meant to do repetitive tasks for hours.

Then I learned web scraping. That same job that took three weeks? Now runs automatically in twenty minutes while I grab coffee. The data is cleaner, more accurate, and I can run it daily instead of monthly. Web scraping literally gave me my life back.

If you've ever found yourself manually copying data from websites, this tutorial is for you. We're going to build real web scrapers from scratch using Python's BeautifulSoup and Requests libraries--no fluff, just practical code you can actually use. By the end, you'll be automating data collection like a pro.

Once you've got web scraping down, you can level up by [building APIs to serve your scraped data with FastAPI](/2025/08/fastapi-tutorial-build-rest-api-from-scratch-beginner-guide.html), or [automate your scrapers to run on schedules using Linux cron jobs](/2025/10/how-to-automate-tasks-cron-jobs-shell-scripts-linux.html).

<!--readmore-->

## Why Web Scraping Is a Superpower You Need

Look, I get it--web scraping sounds technical and maybe a little intimidating. But here's the thing: it's just automating what you already do manually. When you visit a website and copy information, you're reading HTML, finding the data you want, and recording it somewhere. Web scraping is teaching your computer to do exactly that, but thousands of times faster and without mistakes.

Think about all the use cases: price monitoring for e-commerce, collecting job postings for market research, gathering news articles for sentiment analysis, tracking real estate listings, monitoring competitor products, aggregating reviews, building datasets for machine learning. The list goes on. Any time you need data from websites and the site doesn't provide an API, web scraping is your answer.

The best part? BeautifulSoup and Requests make it genuinely easy. We're not talking about complex browser automation or reverse-engineering APIs (though we'll touch on that later). We're talking about straightforward Python code that fetches HTML and extracts data. If you can write a for loop and understand basic HTML structure, you can build scrapers.

## Prerequisites and What You'll Learn

Before we dive in, here's what you need:

- Python 3.8 or higher installed ([check our Python installation guides](/2025/08/fastapi-tutorial-build-rest-api-from-scratch-beginner-guide.html) if you need help)
- Basic Python knowledge (variables, functions, lists, dictionaries)
- Understanding of HTML structure (tags, attributes, classes) - don't worry, I'll explain as we go
- A code editor (VS Code, PyCharm, or even a simple text editor)
- Internet connection for installing libraries and testing scrapers

What we'll build together:

1. A simple scraper to extract article titles and links from a blog
2. A product scraper that collects names, prices, and images from an e-commerce site
3. A news aggregator that scrapes headlines from multiple sources
4. Handling pagination to scrape multiple pages automatically
5. Dealing with common anti-scraping measures (politely and ethically)

## Setting Up Your Scraping Environment

Let's get your environment ready. I always create a separate virtual environment for scraping projects--it keeps dependencies isolated and prevents version conflicts.

**Create a new project directory:**

```bash
mkdir web-scraping-tutorial
cd web-scraping-tutorial
```

**Set up a virtual environment:**

```bash
# On macOS/Linux
python3 -m venv venv
source venv/bin/activate

# On Windows
python -m venv venv
venv\Scripts\activate
```

You should see `(venv)` at the beginning of your command prompt, indicating the virtual environment is active.

**Install the required libraries:**

```bash
pip install requests beautifulsoup4 lxml
```

Here's what each library does:

- **requests**: Fetches web pages by sending HTTP requests (it's like your browser, but for Python)
- **beautifulsoup4**: Parses HTML and lets you extract data using simple Python code
- **lxml**: Fast HTML parser that BeautifulSoup uses under the hood (faster than Python's built-in parser)

**Optional but recommended:**

```bash
pip install fake-useragent  # Rotate user agents to avoid detection
pip install pandas          # For exporting scraped data to CSV/Excel
```

**Verify your installation:**

```python
import requests
from bs4 import BeautifulSoup

print(f"Requests version: {requests.__version__}")
print(f"BeautifulSoup imported successfully")
print("Setup complete!")
```

If this runs without errors, you're ready to start scraping.

## Understanding How Web Scraping Actually Works

Before writing code, let's understand the process at a high level. When you visit a website in your browser, here's what happens:

1. Your browser sends an HTTP request to the server
2. The server responds with HTML, CSS, and JavaScript
3. Your browser parses the HTML and renders it visually
4. JavaScript might load additional content dynamically

Web scraping replicates steps 1 and 2, but instead of rendering visually, we parse the HTML programmatically to extract data. Here's the basic flow:

```
Your Python Script
      ?
Send HTTP Request (requests library)
      ?
Receive HTML Response
      ?
Parse HTML (BeautifulSoup)
      ?
Extract Desired Data
      ?
Store or Process Data
```

The key insight: websites are just text files (HTML) with a structure. BeautifulSoup lets you navigate that structure like a tree of nested tags. Once you understand how to locate elements in HTML, extracting data is straightforward.

**Quick HTML refresher:**

HTML is made up of tags that nest inside each other:

```html
<div class="product">
    <h2 class="product-title">Laptop</h2>
    <span class="price">$999</span>
    <a href="/product/123">View Details</a>
</div>
```

Each element has:
- **Tag name**: `div`, `h2`, `span`, `a`
- **Attributes**: `class="product"`, `href="/product/123"`
- **Text content**: "Laptop", "$999", "View Details"

BeautifulSoup lets you find elements by tag name, class, ID, or any attribute, then extract text or attributes.

## Your First Web Scraper: Fetching and Parsing HTML

Let's build the simplest possible scraper. We'll fetch a web page and extract its title--just to see the process end-to-end.

**Create a file called `first_scraper.py`:**

```python
import requests
from bs4 import BeautifulSoup

def scrape_page_title(url):
    """Fetch a web page and extract its title."""

    # Send HTTP GET request
    response = requests.get(url)

    # Check if request was successful
    if response.status_code == 200:
        print(f"Successfully fetched {url}")
    else:
        print(f"Failed to fetch page. Status code: {response.status_code}")
        return None

    # Parse HTML content
    soup = BeautifulSoup(response.content, 'lxml')

    # Extract the page title
    title = soup.find('title')

    if title:
        return title.get_text()
    else:
        return "No title found"

# Test the scraper
url = "https://www.buanacoding.com"
page_title = scrape_page_title(url)
print(f"Page Title: {page_title}")
```

Run this with `python first_scraper.py`. You should see the page title printed.

**Let's break down what's happening:**

1. `requests.get(url)` sends an HTTP GET request and returns a Response object
2. `response.status_code` tells us if the request succeeded (200 means success)
3. `response.content` contains the raw HTML as bytes
4. `BeautifulSoup(response.content, 'lxml')` parses the HTML into a navigable tree structure
5. `soup.find('title')` searches for the first `<title>` tag
6. `title.get_text()` extracts the text content inside the tag

This is the foundation of every scraper: fetch HTML, parse it, extract data. Everything else is variations on this theme.

## Extracting Data: Finding Elements with BeautifulSoup

BeautifulSoup provides multiple ways to find elements. Let's explore the most useful methods:

**Find a single element:**

```python
# Find by tag name
h1 = soup.find('h1')

# Find by class
product = soup.find('div', class_='product-card')

# Find by ID
header = soup.find(id='main-header')

# Find by multiple attributes
link = soup.find('a', {'class': 'btn', 'data-id': '123'})
```

**Find all matching elements:**

```python
# Find all paragraphs
paragraphs = soup.find_all('p')

# Find all elements with a specific class
products = soup.find_all('div', class_='product')

# Find all links
links = soup.find_all('a')

# Limit results
first_five_links = soup.find_all('a', limit=5)
```

**Extracting text and attributes:**

```python
element = soup.find('a', class_='product-link')

# Get text content
text = element.get_text()
# Or: text = element.text

# Get attribute value
href = element.get('href')
# Or: href = element['href']

# Get all attributes as dictionary
all_attrs = element.attrs
```

**Navigating the tree:**

```python
# Get parent element
parent = element.parent

# Get all children
children = element.children  # Returns iterator
child_list = list(element.children)

# Get next sibling
next_elem = element.next_sibling

# Find within a parent (scoped search)
product_div = soup.find('div', class_='product')
price_within_product = product_div.find('span', class_='price')
```

## Building a Real Scraper: Blog Article Extractor

Let's build something actually useful: a scraper that extracts article titles, publication dates, and links from a blog.

**Create `blog_scraper.py`:**

```python
import requests
from bs4 import BeautifulSoup
import time

def scrape_blog_articles(url):
    """Scrape article information from a blog homepage."""

    # Set a custom user-agent to be polite
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }

    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()  # Raise exception for bad status codes
    except requests.exceptions.RequestException as e:
        print(f"Error fetching {url}: {e}")
        return []

    soup = BeautifulSoup(response.content, 'lxml')

    # Find all article containers (adjust selectors for your target site)
    articles = soup.find_all('article', class_='post')

    scraped_data = []

    for article in articles:
        # Extract title
        title_elem = article.find('h2', class_='post-title')
        title = title_elem.get_text(strip=True) if title_elem else 'No title'

        # Extract link
        link_elem = article.find('a')
        link = link_elem.get('href') if link_elem else None

        # Extract date
        date_elem = article.find('time', class_='post-date')
        date = date_elem.get('datetime') if date_elem else 'No date'

        # Extract excerpt
        excerpt_elem = article.find('p', class_='excerpt')
        excerpt = excerpt_elem.get_text(strip=True) if excerpt_elem else ''

        scraped_data.append({
            'title': title,
            'url': link,
            'date': date,
            'excerpt': excerpt
        })

    return scraped_data

def save_to_file(data, filename='articles.txt'):
    """Save scraped articles to a text file."""
    with open(filename, 'w', encoding='utf-8') as f:
        for idx, article in enumerate(data, 1):
            f.write(f"{idx}. {article['title']}\n")
            f.write(f"   URL: {article['url']}\n")
            f.write(f"   Date: {article['date']}\n")
            f.write(f"   Excerpt: {article['excerpt'][:100]}...\n")
            f.write("\n")
    print(f"Saved {len(data)} articles to {filename}")

# Test the scraper
if __name__ == "__main__":
    blog_url = "https://www.buanacoding.com/blog"

    print(f"Scraping {blog_url}...")
    articles = scrape_blog_articles(blog_url)

    if articles:
        print(f"Found {len(articles)} articles")
        save_to_file(articles)

        # Print first article as sample
        print("\nSample article:")
        print(f"Title: {articles[0]['title']}")
        print(f"URL: {articles[0]['url']}")
    else:
        print("No articles found. Check your selectors.")
```

**Important notes:**

1. **Selectors are site-specific**: The classes like `post-title` and `excerpt` need to match the actual HTML structure of your target site. Inspect the page source to find the correct selectors.

2. **User-Agent header**: We're identifying ourselves as a browser. The default `python-requests/x.x.x` user-agent gets blocked by many sites.

3. **Error handling**: Always wrap requests in try-except blocks. Networks fail, servers go down, and your scraper should handle that gracefully.

4. **Being polite**: We'll add delays between requests soon--don't hammer servers.

## Handling Pagination: Scraping Multiple Pages

Most blogs and e-commerce sites split content across pages. Let's scrape all pages automatically:

```python
def scrape_multiple_pages(base_url, num_pages):
    """Scrape articles from multiple pages."""
    all_articles = []

    for page_num in range(1, num_pages + 1):
        # Construct URL for current page
        # Common patterns:
        # - https://site.com/blog/page/2
        # - https://site.com/blog?page=2
        # - https://site.com/blog/2

        url = f"{base_url}/page/{page_num}"  # Adjust pattern as needed

        print(f"Scraping page {page_num}...")
        articles = scrape_blog_articles(url)
        all_articles.extend(articles)

        # Be polite: add delay between requests
        time.sleep(2)  # 2 second delay

        # Stop if page returned no articles (we've hit the end)
        if not articles:
            print(f"No more articles found at page {page_num}")
            break

    return all_articles

# Usage
all_articles = scrape_multiple_pages("https://www.buanacoding.com/blog", num_pages=5)
print(f"Total articles scraped: {len(all_articles)}")
```

The key here is identifying the pagination pattern. Open your target site, click through a few pages, and watch how the URL changes. Then replicate that pattern in your code.

## Extracting Product Data: E-commerce Scraper

Let's build a more complex scraper for e-commerce data--products with names, prices, ratings, and images:

```python
import requests
from bs4 import BeautifulSoup
import csv
import time

def scrape_products(url):
    """Scrape product information from an e-commerce page."""

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }

    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}")
        return []

    soup = BeautifulSoup(response.content, 'lxml')

    # Find all product cards
    products = soup.find_all('div', class_='product-card')

    scraped_products = []

    for product in products:
        # Extract product name
        name_elem = product.find('h3', class_='product-name')
        name = name_elem.get_text(strip=True) if name_elem else 'N/A'

        # Extract price
        price_elem = product.find('span', class_='price')
        price_text = price_elem.get_text(strip=True) if price_elem else 'N/A'
        # Clean price: remove currency symbols and convert to float
        price = clean_price(price_text)

        # Extract rating
        rating_elem = product.find('div', class_='rating')
        rating = rating_elem.get('data-rating') if rating_elem else 'N/A'

        # Extract image URL
        img_elem = product.find('img')
        image_url = img_elem.get('src') if img_elem else 'N/A'

        # Extract product URL
        link_elem = product.find('a', class_='product-link')
        product_url = link_elem.get('href') if link_elem else 'N/A'

        # Make relative URLs absolute
        if product_url and not product_url.startswith('http'):
            product_url = f"https://example.com{product_url}"

        scraped_products.append({
            'name': name,
            'price': price,
            'rating': rating,
            'image': image_url,
            'url': product_url
        })

    return scraped_products

def clean_price(price_text):
    """Convert price text to float."""
    import re
    # Remove currency symbols and commas
    price_clean = re.sub(r'[^\d.]', '', price_text)
    try:
        return float(price_clean)
    except ValueError:
        return 0.0

def save_to_csv(products, filename='products.csv'):
    """Save products to CSV file."""
    if not products:
        print("No products to save")
        return

    keys = products[0].keys()

    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=keys)
        writer.writeheader()
        writer.writerows(products)

    print(f"Saved {len(products)} products to {filename}")

# Usage
if __name__ == "__main__":
    url = "https://example-ecommerce.com/products"
    products = scrape_products(url)

    if products:
        save_to_csv(products)
        print(f"Scraped {len(products)} products successfully")
    else:
        print("No products found")
```

This scraper demonstrates several important techniques:

- Cleaning extracted data (removing currency symbols from prices)
- Converting relative URLs to absolute URLs
- Exporting data to CSV for easy analysis
- Using regex to extract numbers from messy text

## Being Ethical: Respecting Robots.txt and Rate Limits

Here's the thing nobody likes to talk about: scraping can be rude if done carelessly. Websites cost money to run, and aggressive scrapers can cause real harm. Let's be responsible.

**Always check robots.txt:**

Every site has a `robots.txt` file at the root (e.g., `https://example.com/robots.txt`) that tells crawlers which paths are allowed:

```
User-agent: *
Disallow: /admin/
Disallow: /api/
Crawl-delay: 10
```

This means: don't scrape `/admin/` or `/api/`, and wait 10 seconds between requests.

**Check robots.txt programmatically:**

```python
import requests

def check_robots_txt(base_url):
    """Fetch and display robots.txt content."""
    robots_url = f"{base_url}/robots.txt"
    try:
        response = requests.get(robots_url)
        if response.status_code == 200:
            print(response.text)
        else:
            print(f"No robots.txt found (status {response.status_code})")
    except requests.exceptions.RequestException as e:
        print(f"Error fetching robots.txt: {e}")

check_robots_txt("https://www.buanacoding.com")
```

**Implement rate limiting:**

```python
import time
from datetime import datetime

class RateLimiter:
    """Simple rate limiter to control request frequency."""

    def __init__(self, requests_per_second=1):
        self.delay = 1.0 / requests_per_second
        self.last_request = None

    def wait(self):
        """Wait if necessary to maintain rate limit."""
        if self.last_request:
            elapsed = time.time() - self.last_request
            if elapsed < self.delay:
                time.sleep(self.delay - elapsed)
        self.last_request = time.time()

# Usage
rate_limiter = RateLimiter(requests_per_second=0.5)  # 1 request every 2 seconds

for url in urls_to_scrape:
    rate_limiter.wait()
    response = requests.get(url)
    # ... process response
```

**Best practices summary:**

- Start conservatively: 1 request every 10-15 seconds
- Respect robots.txt directives
- Use realistic User-Agent headers
- Implement retries with exponential backoff
- Cache responses to avoid repeat requests
- Scrape during off-peak hours if possible
- Include contact info in your User-Agent so webmasters can reach you

## Handling Common Challenges and Anti-Scraping Measures

Real-world scraping is messier than tutorials let on. Here's how to handle common issues:

**1. Websites that block the default User-Agent:**

```python
from fake_useragent import UserAgent

ua = UserAgent()

headers = {
    'User-Agent': ua.random,  # Randomize user agent
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://google.com',
}

response = requests.get(url, headers=headers)
```

**2. Session cookies and persistent connections:**

```python
session = requests.Session()
session.headers.update(headers)

# Cookies persist across requests
response1 = session.get(url1)
response2 = session.get(url2)  # Cookies from response1 are sent
```

**3. Handling timeouts and retries:**

```python
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

def create_session():
    """Create a session with retry logic."""
    session = requests.Session()

    retry = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[500, 502, 503, 504]
    )

    adapter = HTTPAdapter(max_retries=retry)
    session.mount('http://', adapter)
    session.mount('https://', adapter)

    return session

session = create_session()
response = session.get(url, timeout=10)
```

**4. Dealing with missing or inconsistent data:**

```python
def safe_extract(soup, selector, attribute=None, default='N/A'):
    """Safely extract data with fallback."""
    elem = soup.find(*selector) if isinstance(selector, tuple) else soup.find(selector)

    if elem:
        if attribute:
            return elem.get(attribute, default)
        return elem.get_text(strip=True)
    return default

# Usage
title = safe_extract(soup, ('h1', {'class': 'title'}))
price = safe_extract(soup, ('span', {'class': 'price'}), default='0.00')
```

**5. Parsing relative URLs correctly:**

```python
from urllib.parse import urljoin

base_url = "https://example.com/products/"
relative_url = "../images/product.jpg"

absolute_url = urljoin(base_url, relative_url)
# Result: https://example.com/images/product.jpg
```

## Storing Your Scraped Data Effectively

You've scraped data--now what? Let's look at storage options:

**CSV export (best for tabular data):**

```python
import csv

def export_to_csv(data, filename):
    """Export list of dictionaries to CSV."""
    if not data:
        return

    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=data[0].keys())
        writer.writeheader()
        writer.writerows(data)

export_to_csv(scraped_products, 'products.csv')
```

**JSON export (preserves nested structures):**

```python
import json

def export_to_json(data, filename):
    """Export data to JSON file."""
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

export_to_json(scraped_products, 'products.json')
```

**SQLite database (queryable, efficient):**

```python
import sqlite3

def store_in_database(products):
    """Store products in SQLite database."""
    conn = sqlite3.connect('products.db')
    cursor = conn.cursor()

    # Create table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            price REAL,
            rating TEXT,
            url TEXT UNIQUE,
            scraped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # Insert products
    for product in products:
        try:
            cursor.execute('''
                INSERT OR REPLACE INTO products (name, price, rating, url)
                VALUES (?, ?, ?, ?)
            ''', (product['name'], product['price'], product['rating'], product['url']))
        except sqlite3.Error as e:
            print(f"Error inserting {product['name']}: {e}")

    conn.commit()
    conn.close()

store_in_database(scraped_products)
```

**Using pandas for data manipulation:**

```python
import pandas as pd

# Convert to DataFrame
df = pd.DataFrame(scraped_products)

# Clean and analyze
df['price'] = pd.to_numeric(df['price'], errors='coerce')
df = df.dropna(subset=['price'])  # Remove rows with missing prices

# Calculate statistics
print(f"Average price: ${df['price'].mean():.2f}")
print(f"Price range: ${df['price'].min():.2f} - ${df['price'].max():.2f}")

# Export
df.to_csv('products_cleaned.csv', index=False)
df.to_excel('products.xlsx', index=False)
```

## Building a Complete News Aggregator

Let's tie everything together with a production-ready news scraper:

```python
import requests
from bs4 import BeautifulSoup
import csv
from datetime import datetime
import time
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('scraper.log'),
        logging.StreamHandler()
    ]
)

class NewsAggregator:
    """Scrape news headlines from multiple sources."""

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
        self.articles = []

    def scrape_source(self, url, selectors):
        """Scrape a single news source."""
        try:
            logging.info(f"Scraping {url}")
            response = self.session.get(url, timeout=15)
            response.raise_for_status()

            soup = BeautifulSoup(response.content, 'lxml')
            articles = soup.select(selectors['article_container'])

            for article in articles:
                headline = article.select_one(selectors['headline'])
                link = article.select_one(selectors['link'])

                if headline and link:
                    self.articles.append({
                        'headline': headline.get_text(strip=True),
                        'url': link.get('href'),
                        'source': url,
                        'scraped_at': datetime.now().isoformat()
                    })

            logging.info(f"Scraped {len(articles)} articles from {url}")
            time.sleep(3)  # Be polite

        except requests.exceptions.RequestException as e:
            logging.error(f"Error scraping {url}: {e}")
        except Exception as e:
            logging.error(f"Unexpected error: {e}")

    def scrape_all_sources(self, sources):
        """Scrape multiple news sources."""
        for source in sources:
            self.scrape_source(source['url'], source['selectors'])

    def export_results(self, filename='news.csv'):
        """Export scraped articles to CSV."""
        if not self.articles:
            logging.warning("No articles to export")
            return

        with open(filename, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=self.articles[0].keys())
            writer.writeheader()
            writer.writerows(self.articles)

        logging.info(f"Exported {len(self.articles)} articles to {filename}")

# Configuration for different news sources
news_sources = [
    {
        'url': 'https://news.ycombinator.com',
        'selectors': {
            'article_container': '.athing',
            'headline': '.titleline > a',
            'link': '.titleline > a'
        }
    },
    # Add more sources here
]

# Run the aggregator
if __name__ == "__main__":
    aggregator = NewsAggregator()
    aggregator.scrape_all_sources(news_sources)
    aggregator.export_results()

    print(f"Successfully scraped {len(aggregator.articles)} articles")
```

This scraper demonstrates production patterns:

- Logging for debugging and monitoring
- Session management for efficiency
- Graceful error handling
- Configurable selectors for multiple sources
- Structured output with timestamps

## When BeautifulSoup Isn't Enough: JavaScript-Heavy Sites

BeautifulSoup only sees the HTML the server sends--it doesn't execute JavaScript. If a site loads content dynamically (most modern single-page apps do), you'll need different tools.

**Check if you actually need JavaScript rendering:**

Open your browser's DevTools (F12), go to the Network tab, and look for XHR/Fetch requests. Often sites load data via JSON APIs that you can call directly--this is faster and more reliable than rendering JavaScript.

**Example: Calling an API directly instead of scraping:**

```python
# Instead of scraping the rendered HTML...
response = requests.get('https://site.com/products?page=1&limit=100')
data = response.json()  # If the endpoint returns JSON

# You get structured data directly
for product in data['results']:
    print(product['name'], product['price'])
```

**When you do need JavaScript rendering, use Selenium:**

```python
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# Setup (install: pip install selenium)
driver = webdriver.Chrome()  # Or Firefox, Edge, etc.

try:
    driver.get('https://example.com')

    # Wait for elements to load
    wait = WebDriverWait(driver, 10)
    products = wait.until(
        EC.presence_of_all_elements_located((By.CLASS_NAME, 'product-card'))
    )

    # Extract data
    for product in products:
        name = product.find_element(By.CLASS_NAME, 'name').text
        price = product.find_element(By.CLASS_NAME, 'price').text
        print(name, price)
finally:
    driver.quit()
```

Selenium is powerful but much slower than Requests+BeautifulSoup. Use it sparingly, and consider [deploying your scrapers with Docker](/2025/08/install-docker-on-ubuntu-24-04-with-compose-v2-and-rootless.html) if they need browser automation in production.

## Debugging Your Scrapers When They Break

Scrapers break constantly--websites change their HTML structure without warning. Here's how to debug effectively:

**1. Save the HTML for offline testing:**

```python
response = requests.get(url)
with open('debug.html', 'w', encoding='utf-8') as f:
    f.write(response.text)

# Then test parsing locally without hitting the website
with open('debug.html', 'r', encoding='utf-8') as f:
    soup = BeautifulSoup(f.read(), 'lxml')
```

**2. Print the actual HTML you're parsing:**

```python
print(soup.prettify())  # Formatted HTML
print(soup.find('div', class_='product'))  # Specific element
```

**3. Check what your selectors actually find:**

```python
products = soup.find_all('div', class_='product')
print(f"Found {len(products)} products")

if not products:
    # Selector might be wrong
    print("No products found. Checking alternative selectors...")
    alt_products = soup.find_all('div', class_='item')
    print(f"Found {len(alt_products)} items with class 'item'")
```

**4. Validate extracted data immediately:**

```python
def validate_product(product):
    """Check if extracted product data is valid."""
    issues = []

    if not product.get('name'):
        issues.append("Missing name")
    if not product.get('price') or product['price'] <= 0:
        issues.append("Invalid price")
    if product.get('url') and not product['url'].startswith('http'):
        issues.append("Invalid URL")

    if issues:
        logging.warning(f"Product validation failed: {issues}")
        return False
    return True

# Use validation
if validate_product(scraped_product):
    products.append(scraped_product)
```

**5. Use logging extensively:**

```python
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

logger.debug(f"Fetching {url}")
logger.info(f"Found {len(products)} products")
logger.warning(f"Missing price for product: {product_name}")
logger.error(f"Failed to parse page: {e}")
```

## Scheduling Your Scrapers to Run Automatically

Once your scraper works, you'll want to run it regularly without manual intervention. If you're on Linux, [cron jobs are perfect for scheduling automated tasks](/2025/10/how-to-automate-tasks-cron-jobs-shell-scripts-linux.html).

**Basic cron job (runs daily at 3 AM):**

```bash
# Open crontab editor
crontab -e

# Add this line (adjust paths)
0 3 * * * /usr/bin/python3 /path/to/your/scraper.py >> /path/to/scraper.log 2>&1
```

**Or use Python's schedule library:**

```python
import schedule
import time

def job():
    """Run the scraper."""
    print(f"Starting scraper at {datetime.now()}")
    # Your scraping code here

# Schedule job
schedule.every().day.at("03:00").do(job)
schedule.every().hour.do(job)  # Or every hour
schedule.every(30).minutes.do(job)  # Or every 30 minutes

# Keep script running
while True:
    schedule.run_pending()
    time.sleep(60)  # Check every minute
```

For production deployments, containerize with Docker and use proper job schedulers like cron, systemd timers, or cloud services like AWS Lambda for serverless scraping.

## What To Do Next: Taking Your Scraping Further

You've learned the fundamentals--here's how to level up:

**1. Build a data pipeline:** Scrape data, clean it, store it in a database, and [serve it via an API using FastAPI](/2025/08/fastapi-tutorial-build-rest-api-from-scratch-beginner-guide.html).

**2. Add monitoring and alerts:** Track scraper success rates and get notified when things break. Use tools like Sentry for error tracking.

**3. Scale up with Scrapy:** For large-scale scraping (thousands of pages), the Scrapy framework provides concurrency, middleware, and built-in best practices.

**4. Learn about browser automation:** Selenium and Playwright let you scrape JavaScript-heavy sites, fill forms, and interact with pages.

**5. Explore data analysis:** Use pandas to analyze your scraped data, create visualizations, and extract insights.

**6. Deploy to the cloud:** Run your scrapers on VPS servers with [proper HTTPS setup](/2025/08/nginx-certbot-ubuntu-24-04-free-https.html) for production reliability.

**7. Stay secure:** If you're handling scraped data containing sensitive information, review [security best practices](/2025/08/phishing-signs-fake-email-examples-how-to-avoid.html) to keep data safe.

## The Bottom Line

Web scraping transformed how I work, and I hope this guide does the same for you. The ability to programmatically gather data opens up countless possibilities--market research, price monitoring, content aggregation, dataset building for machine learning, and so much more.

Remember: scrape responsibly, respect website owners, and always consider whether an official API exists before scraping. When done ethically, web scraping is an incredibly powerful skill that will serve you throughout your career.

Start with simple projects and gradually increase complexity. Scrape sites you're genuinely interested in--the best way to learn is by solving real problems. And when your scrapers break (they will), don't get discouraged. Websites change, and adapting scrapers is part of the game.

Now go automate some tedious data collection and reclaim your time. What's the first thing you're going to scrape?
