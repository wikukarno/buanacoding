---
title: "Python Automation Scripts Every Developer Should Know (Save Hours Weekly)"
date: 2025-10-28T10:00:00+07:00
draft: false
url: /2025/10/python-automation-scripts-every-developer-should-know.html
tags:
  - Python
  - Automation
  - Productivity
  - Scripts
  - Tutorial
description: "Master 10+ Python automation scripts that save hours every week. Learn file organization, Excel/PDF manipulation, email automation, web scraping, image processing, and scheduled tasks with ready-to-use code examples."
keywords: ["python automation", "automation scripts", "python productivity", "file automation", "excel automation python", "pdf automation", "email automation", "python scripts", "task automation"]
featured: false
faq:
  - question: "What are the best Python libraries for automation and which should I learn first?"
    answer: "Start with os, shutil, and pathlib for file operations--they are built-in and handle 80% of tasks. Add pandas for Excel/CSV work (10-100x faster than manual), then openpyxl for Excel formatting. Use PyPDF2 for PDFs, Pillow for images, requests for web tasks, and schedule for running scripts periodically. Master file and data automation first since they save the most time immediately."
  - question: "How do I schedule Python scripts to run automatically without keeping my computer on?"
    answer: "Use cron on Linux/Mac (crontab -e) or Task Scheduler on Windows for local scheduling. For 24/7 operation, deploy to a $5 VPS like DigitalOcean with cron jobs. Cloud functions (AWS Lambda, Google Cloud Functions) work for lightweight tasks. GitHub Actions offers free scheduled workflows. Always add logging and email alerts so you know when automation breaks."
  - question: "How can I automate Excel tasks in Python and when should I use pandas vs openpyxl?"
    answer: "Use pandas for data work: reading, cleaning, calculations, filtering, and simple exports. It is fast and great for bulk operations. Use openpyxl when you need formatting control: fonts, colors, charts, formulas, or editing existing files. Best approach: pandas for data processing, then openpyxl for final formatting touches. Xlsxwriter works for creating new formatted files from scratch but cannot edit existing ones."
  - question: "What is the best way to handle errors and make my automation scripts reliable for production use?"
    answer: "Wrap risky operations in try-except blocks with specific exceptions. Use Python's logging module (not print) to log errors with timestamps. Add email/Slack alerts for failures. Implement retry logic with exponential backoff for network issues. Validate inputs before processing and outputs after. Use environment variables for config, never hardcode paths or credentials. Test error handling by deliberately breaking things in development."
  - question: "How do I safely handle credentials and API keys in automation scripts?"
    answer: "Never hardcode credentials. Use environment variables (os.getenv) or python-dotenv with .env files (gitignored). For production, use secret managers like AWS Secrets Manager or Azure Key Vault. Store config files with chmod 600 permissions outside your repo. Create separate API keys per automation with minimal permissions. Rotate credentials regularly and monitor logs for accidental exposure."
  - question: "What are some beginner-friendly automation projects that provide immediate value?"
    answer: "File organizer for Downloads folder (by type/date). Excel data cleaner (remove dupes, fill nulls, calculate totals). Daily email reporter with summary data. Automated backups with date stamps. Screenshot renamer and organizer. Website uptime monitor with email alerts. Batch image resizer for social media. Invoice generator from timesheet CSV. Start with whichever solves your biggest daily pain point."
---

Last month, I spent four hours copying data from PDFs into Excel spreadsheets for a client report. Four hours of my life, gone, doing something a computer could do in four seconds. I kept thinking--there has to be a better way.

That weekend, I wrote a simple Python script. Ten lines of code. Now that same task runs automatically every Monday morning while I drink coffee. The script has saved me over 30 hours since I wrote it, and honestly, that is not even my best automation.

If you have ever found yourself doing the same boring computer task over and over, this tutorial is for you. We are going to build practical Python automation scripts that actually save time. No theory, no fluff--just real scripts you can use tomorrow to get hours of your life back.

After you master these automation basics, you can [build web scrapers to collect data automatically](/2025/10/how-to-build-web-scraper-python-beautifulsoup-requests.html) or [schedule your scripts to run on autopilot with cron jobs](/2025/10/how-to-automate-tasks-cron-jobs-shell-scripts-linux.html).

<!--readmore-->

## Why Every Developer Needs Automation Skills

Look, I get it--writing a script to automate something takes time upfront. Sometimes it feels faster to just do the task manually. But here is the math that changed my mind: if a task takes 5 minutes and you do it daily, that is 30 hours per year. Spend one hour writing automation, save 29 hours annually. And that is just one task.

The real magic happens when you start seeing automation opportunities everywhere. That spreadsheet you update every Monday? Automate it. Those files you rename and organize? Automate it. The report you email to your boss? Definitely automate it.

Python makes automation accessible. You do not need to be a programming genius. If you can write a loop and call a function, you can automate 90% of repetitive computer work. The standard library has most of what you need, and the remaining tools are a pip install away.

Plus, automation compounds. You write a script once, use it forever. Share it with teammates, multiply the benefit. Chain scripts together, build workflows. Before you know it, you have automated away hours of weekly drudgery and can focus on work that actually matters.

## Setting Up Your Automation Environment

Let me get your environment ready for automation. I always create a dedicated automation project to keep scripts organized.

**Create your automation workspace:**

```bash
mkdir python-automation
cd python-automation
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

**Install essential automation libraries:**

```bash
# File and data manipulation
pip install pandas openpyxl xlsxwriter

# PDF handling
pip install PyPDF2 reportlab

# Image processing
pip install Pillow

# Web and email
pip install requests beautifulsoup4

# Scheduling
pip install schedule

# Utilities
pip install python-dotenv  # For managing credentials safely
```

**Create a basic project structure:**

```bash
automation/
├── scripts/          # Your automation scripts
├── data/            # Input files
├── output/          # Generated files
├── logs/            # Script logs
└── config/          # Configuration files
```

This structure keeps everything organized. Scripts read from data/, write to output/, and log to logs/. Clean separation makes debugging easier.

**Verify your setup:**

```python
import pandas as pd
import PyPDF2
from PIL import Image
import requests
import schedule

print("All libraries imported successfully!")
print("Ready to automate!")
```

If that runs without errors, you are ready to start automating.

## File Organization: Never Manually Sort Files Again

Let me show you my most-used automation: organizing messy folders automatically. This script sorts files by type, renames them with dates, and cleans up duplicates.

**Smart file organizer:**

```python
import os
import shutil
from pathlib import Path
from datetime import datetime
import hashlib

def organize_files(source_dir, dest_dir):
    """
    Organize files by type into categorized folders.
    Handles duplicates and renames files with timestamps.
    """

    # Define file categories
    categories = {
        'Images': ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.svg', '.webp'],
        'Documents': ['.pdf', '.doc', '.docx', '.txt', '.odt', '.rtf'],
        'Spreadsheets': ['.xlsx', '.xls', '.csv', '.ods'],
        'Archives': ['.zip', '.rar', '.7z', '.tar', '.gz'],
        'Videos': ['.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv'],
        'Audio': ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a'],
        'Code': ['.py', '.js', '.html', '.css', '.java', '.cpp', '.go'],
    }

    # Create destination directories
    for category in categories.keys():
        Path(dest_dir, category).mkdir(parents=True, exist_ok=True)

    # Track moved files
    moved_count = 0
    skipped_count = 0

    # Process each file in source directory
    for filename in os.listdir(source_dir):
        file_path = Path(source_dir, filename)

        # Skip directories
        if file_path.is_dir():
            continue

        # Get file extension
        ext = file_path.suffix.lower()

        # Find matching category
        destination_category = None
        for category, extensions in categories.items():
            if ext in extensions:
                destination_category = category
                break

        # Default to 'Others' if no category matches
        if not destination_category:
            destination_category = 'Others'
            Path(dest_dir, 'Others').mkdir(exist_ok=True)

        # Create new filename with date prefix
        date_prefix = datetime.now().strftime('%Y%m%d')
        new_filename = f"{date_prefix}_{filename}"
        dest_path = Path(dest_dir, destination_category, new_filename)

        # Handle duplicate filenames
        counter = 1
        while dest_path.exists():
            name_part = file_path.stem
            new_filename = f"{date_prefix}_{name_part}_{counter}{ext}"
            dest_path = Path(dest_dir, destination_category, new_filename)
            counter += 1

        # Move file
        try:
            shutil.move(str(file_path), str(dest_path))
            moved_count += 1
            print(f"Moved: {filename} -> {destination_category}/{new_filename}")
        except Exception as e:
            print(f"Error moving {filename}: {e}")
            skipped_count += 1

    print(f"\nOrganization complete!")
    print(f"Files moved: {moved_count}")
    print(f"Files skipped: {skipped_count}")

# Usage
organize_files('/path/to/messy/downloads', '/path/to/organized/files')
```

This script saved me countless hours. I run it on my Downloads folder weekly, and chaos becomes order instantly.

**Enhanced version with duplicate detection:**

```python
def get_file_hash(filepath):
    """Calculate MD5 hash of file content to detect duplicates."""
    hash_md5 = hashlib.md5()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def remove_duplicate_files(directory):
    """Find and remove duplicate files based on content hash."""
    hashes = {}
    duplicates = []

    for filename in os.listdir(directory):
        filepath = Path(directory, filename)

        if filepath.is_file():
            file_hash = get_file_hash(filepath)

            if file_hash in hashes:
                duplicates.append(filepath)
                print(f"Duplicate found: {filename}")
            else:
                hashes[file_hash] = filepath

    # Remove duplicates
    for dup in duplicates:
        dup.unlink()  # Delete file
        print(f"Deleted duplicate: {dup.name}")

    print(f"\nRemoved {len(duplicates)} duplicate files")

# Usage
remove_duplicate_files('/path/to/folder')
```

Run this before organizing to clean up duplicate downloads and screenshots that pile up.

## Excel Automation: Stop Manual Spreadsheet Work

Excel automation is where Python really shines. Here are scripts I use constantly for data work.

**Merge multiple Excel files:**

```python
import pandas as pd
from pathlib import Path

def merge_excel_files(folder_path, output_file):
    """
    Merge all Excel files in a folder into one consolidated file.
    Assumes all files have the same structure.
    """

    all_data = []

    # Read all Excel files
    for excel_file in Path(folder_path).glob('*.xlsx'):
        df = pd.read_excel(excel_file)
        # Add source filename column
        df['Source_File'] = excel_file.name
        all_data.append(df)
        print(f"Read {len(df)} rows from {excel_file.name}")

    # Combine all dataframes
    merged_df = pd.concat(all_data, ignore_index=True)

    # Write to output file
    merged_df.to_excel(output_file, index=False)
    print(f"\nMerged {len(all_data)} files into {output_file}")
    print(f"Total rows: {len(merged_df)}")

    return merged_df

# Usage
merge_excel_files('monthly_reports/', 'annual_report.xlsx')
```

I use this to combine monthly sales reports into yearly summaries. Saves hours compared to copy-pasting manually.

**Clean and format Excel data:**

```python
def clean_excel_data(input_file, output_file):
    """
    Clean messy Excel data: remove duplicates, fill nulls, format dates.
    """

    # Read Excel file
    df = pd.read_excel(input_file)
    initial_rows = len(df)

    # Remove duplicate rows
    df = df.drop_duplicates()
    print(f"Removed {initial_rows - len(df)} duplicate rows")

    # Remove rows where all values are null
    df = df.dropna(how='all')

    # Fill null values in specific columns
    if 'Status' in df.columns:
        df['Status'].fillna('Pending', inplace=True)

    # Clean column names (remove spaces, lowercase)
    df.columns = df.columns.str.strip().str.lower().str.replace(' ', '_')

    # Format date columns
    date_columns = [col for col in df.columns if 'date' in col.lower()]
    for col in date_columns:
        df[col] = pd.to_datetime(df[col], errors='coerce')

    # Sort by first column
    df = df.sort_values(by=df.columns[0])

    # Write clean data
    df.to_excel(output_file, index=False)
    print(f"Cleaned data saved to {output_file}")
    print(f"Final row count: {len(df)}")

    return df

# Usage
clean_excel_data('messy_data.xlsx', 'clean_data.xlsx')
```

**Generate formatted reports with openpyxl:**

```python
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter

def create_formatted_report(data, output_file):
    """
    Create a professionally formatted Excel report.
    """

    wb = Workbook()
    ws = wb.active
    ws.title = "Report"

    # Add title
    ws['A1'] = "Monthly Sales Report"
    ws['A1'].font = Font(size=16, bold=True)
    ws['A1'].alignment = Alignment(horizontal='center')
    ws.merge_cells('A1:D1')

    # Add headers
    headers = ['Product', 'Units Sold', 'Revenue', 'Profit']
    for col, header in enumerate(headers, 1):
        cell = ws.cell(row=3, column=col)
        cell.value = header
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill(start_color="366092", end_color="366092", fill_type="solid")
        cell.alignment = Alignment(horizontal='center')

    # Add data rows
    for row_idx, row_data in enumerate(data, 4):
        for col_idx, value in enumerate(row_data, 1):
            ws.cell(row=row_idx, column=col_idx, value=value)

    # Auto-adjust column widths
    for col in range(1, len(headers) + 1):
        column_letter = get_column_letter(col)
        ws.column_dimensions[column_letter].width = 15

    # Add totals row
    last_row = len(data) + 4
    ws.cell(row=last_row, column=1, value="TOTAL")
    ws.cell(row=last_row, column=1).font = Font(bold=True)

    # Add SUM formulas
    for col in range(2, len(headers) + 1):
        col_letter = get_column_letter(col)
        ws.cell(row=last_row, column=col).value = f"=SUM({col_letter}4:{col_letter}{last_row-1})"
        ws.cell(row=last_row, column=col).font = Font(bold=True)

    wb.save(output_file)
    print(f"Formatted report saved to {output_file}")

# Usage
sales_data = [
    ['Product A', 150, 15000, 5000],
    ['Product B', 200, 30000, 12000],
    ['Product C', 100, 8000, 2500],
]
create_formatted_report(sales_data, 'sales_report.xlsx')
```

This creates professional reports with formatting, formulas, and styling. Way better than manually formatting in Excel.

## PDF Automation: Merge, Split, and Extract

PDF manipulation is tedious manually but trivial with Python. Here are my go-to PDF scripts.

**Merge multiple PDFs:**

```python
import PyPDF2
from pathlib import Path

def merge_pdfs(pdf_files, output_file):
    """
    Merge multiple PDF files into one.
    """

    pdf_merger = PyPDF2.PdfMerger()

    for pdf_file in pdf_files:
        print(f"Adding {pdf_file}")
        pdf_merger.append(pdf_file)

    pdf_merger.write(output_file)
    pdf_merger.close()
    print(f"\nMerged {len(pdf_files)} PDFs into {output_file}")

# Usage
pdf_files = ['chapter1.pdf', 'chapter2.pdf', 'chapter3.pdf']
merge_pdfs(pdf_files, 'complete_book.pdf')
```

**Split PDF into individual pages:**

```python
def split_pdf(input_pdf, output_folder):
    """
    Split PDF into separate files, one per page.
    """

    Path(output_folder).mkdir(exist_ok=True)

    with open(input_pdf, 'rb') as file:
        pdf_reader = PyPDF2.PdfReader(file)
        num_pages = len(pdf_reader.pages)

        for page_num in range(num_pages):
            pdf_writer = PyPDF2.PdfWriter()
            pdf_writer.add_page(pdf_reader.pages[page_num])

            output_filename = Path(output_folder, f'page_{page_num + 1}.pdf')
            with open(output_filename, 'wb') as output_file:
                pdf_writer.write(output_file)

            print(f"Created {output_filename}")

        print(f"\nSplit {num_pages} pages from {input_pdf}")

# Usage
split_pdf('document.pdf', 'pages/')
```

**Extract text from PDF:**

```python
def extract_text_from_pdf(pdf_file, output_txt):
    """
    Extract all text from PDF and save to text file.
    """

    with open(pdf_file, 'rb') as file:
        pdf_reader = PyPDF2.PdfReader(file)
        text_content = []

        for page_num, page in enumerate(pdf_reader.pages, 1):
            text = page.extract_text()
            text_content.append(f"--- Page {page_num} ---\n{text}\n")

        full_text = '\n'.join(text_content)

        with open(output_txt, 'w', encoding='utf-8') as txt_file:
            txt_file.write(full_text)

        print(f"Extracted text from {len(pdf_reader.pages)} pages")
        print(f"Saved to {output_txt}")

# Usage
extract_text_from_pdf('document.pdf', 'extracted_text.txt')
```

These three scripts handle 90% of my PDF automation needs.

## Email Automation: Send Reports Automatically

Automating emails saves tons of time for reports, notifications, and updates.

**Send simple text emails:**

```python
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os

def send_email(to_email, subject, body):
    """
    Send a simple text email.
    """

    # Email configuration (use environment variables for security)
    from_email = os.getenv('EMAIL_USER')
    password = os.getenv('EMAIL_PASSWORD')
    smtp_server = 'smtp.gmail.com'
    smtp_port = 587

    # Create message
    msg = MIMEMultipart()
    msg['From'] = from_email
    msg['To'] = to_email
    msg['Subject'] = subject

    msg.attach(MIMEText(body, 'plain'))

    # Send email
    try:
        server = smtplib.SMTP(smtp_server, smtp_port)
        server.starttls()
        server.login(from_email, password)
        server.send_message(msg)
        server.quit()
        print(f"Email sent successfully to {to_email}")
    except Exception as e:
        print(f"Failed to send email: {e}")

# Usage (set environment variables first)
send_email('recipient@example.com', 'Weekly Report', 'Here is this week's summary...')
```

**Send emails with attachments:**

```python
from email.mime.base import MIMEBase
from email import encoders

def send_email_with_attachment(to_email, subject, body, attachment_path):
    """
    Send email with file attachment.
    """

    from_email = os.getenv('EMAIL_USER')
    password = os.getenv('EMAIL_PASSWORD')

    msg = MIMEMultipart()
    msg['From'] = from_email
    msg['To'] = to_email
    msg['Subject'] = subject

    msg.attach(MIMEText(body, 'plain'))

    # Attach file
    with open(attachment_path, 'rb') as attachment:
        part = MIMEBase('application', 'octet-stream')
        part.set_payload(attachment.read())

    encoders.encode_base64(part)
    part.add_header(
        'Content-Disposition',
        f'attachment; filename= {Path(attachment_path).name}',
    )

    msg.attach(part)

    # Send
    try:
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(from_email, password)
        server.send_message(msg)
        server.quit()
        print(f"Email with attachment sent to {to_email}")
    except Exception as e:
        print(f"Failed to send email: {e}")

# Usage
send_email_with_attachment('boss@company.com', 'Weekly Report',
                          'Please find attached this week's report.',
                          'report.xlsx')
```

**Send formatted HTML emails:**

```python
from email.mime.text import MIMEText

def send_html_email(to_email, subject, html_content):
    """
    Send formatted HTML email.
    """

    from_email = os.getenv('EMAIL_USER')
    password = os.getenv('EMAIL_PASSWORD')

    msg = MIMEMultipart('alternative')
    msg['From'] = from_email
    msg['To'] = to_email
    msg['Subject'] = subject

    # Attach HTML content
    html_part = MIMEText(html_content, 'html')
    msg.attach(html_part)

    # Send
    try:
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(from_email, password)
        server.send_message(msg)
        server.quit()
        print(f"HTML email sent to {to_email}")
    except Exception as e:
        print(f"Failed to send email: {e}")

# Usage with formatted content
html = """
<html>
  <body>
    <h2>Weekly Sales Report</h2>
    <p>Here are this week's highlights:</p>
    <ul>
      <li>Total Sales: $50,000</li>
      <li>New Customers: 25</li>
      <li>Conversion Rate: 3.5%</li>
    </ul>
    <p>Great work team!</p>
  </body>
</html>
"""
send_html_email('team@company.com', 'Weekly Sales Report', html)
```

I use email automation for daily reports, error notifications, and backup confirmations.

## Image Processing: Batch Resize, Watermark, Convert

Image manipulation is tedious when done manually but instant with Python.

**Batch resize images:**

```python
from PIL import Image
from pathlib import Path

def batch_resize_images(input_folder, output_folder, width=800):
    """
    Resize all images in folder while maintaining aspect ratio.
    """

    Path(output_folder).mkdir(exist_ok=True)

    image_extensions = ['.jpg', '.jpeg', '.png', '.bmp', '.gif']
    processed = 0

    for image_file in Path(input_folder).iterdir():
        if image_file.suffix.lower() in image_extensions:
            try:
                img = Image.open(image_file)

                # Calculate new height maintaining aspect ratio
                aspect_ratio = img.height / img.width
                new_height = int(width * aspect_ratio)

                # Resize
                resized_img = img.resize((width, new_height), Image.LANCZOS)

                # Save
                output_path = Path(output_folder, image_file.name)
                resized_img.save(output_path)

                print(f"Resized: {image_file.name}")
                processed += 1
            except Exception as e:
                print(f"Error processing {image_file.name}: {e}")

    print(f"\nResized {processed} images")

# Usage
batch_resize_images('original_photos/', 'resized_photos/', width=1200)
```

**Add watermark to images:**

```python
from PIL import Image, ImageDraw, ImageFont

def add_watermark(image_path, watermark_text, output_path):
    """
    Add text watermark to image.
    """

    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)

    # Calculate watermark position (bottom right)
    font = ImageFont.load_default()
    text_bbox = draw.textbbox((0, 0), watermark_text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]

    margin = 10
    x = img.width - text_width - margin
    y = img.height - text_height - margin

    # Add semi-transparent watermark
    draw.text((x, y), watermark_text, fill=(255, 255, 255, 128), font=font)

    img.save(output_path)
    print(f"Added watermark to {output_path}")

# Usage
add_watermark('photo.jpg', '© 2025 Your Name', 'photo_watermarked.jpg')
```

**Convert image formats in batch:**

```python
def batch_convert_images(input_folder, output_folder, output_format='PNG'):
    """
    Convert all images to specified format.
    """

    Path(output_folder).mkdir(exist_ok=True)

    for image_file in Path(input_folder).glob('*'):
        if image_file.suffix.lower() in ['.jpg', '.jpeg', '.png', '.bmp']:
            try:
                img = Image.open(image_file)

                # Convert RGBA to RGB if saving as JPEG
                if output_format.upper() == 'JPEG' and img.mode == 'RGBA':
                    img = img.convert('RGB')

                output_filename = image_file.stem + f'.{output_format.lower()}'
                output_path = Path(output_folder, output_filename)

                img.save(output_path, output_format)
                print(f"Converted: {image_file.name} -> {output_filename}")
            except Exception as e:
                print(f"Error converting {image_file.name}: {e}")

# Usage
batch_convert_images('jpg_images/', 'png_images/', 'PNG')
```

These scripts handle image preparation for websites, social media, and documentation.

## Scheduling: Run Scripts Automatically

The schedule library makes it easy to run scripts periodically without cron or Task Scheduler.

**Basic scheduling:**

```python
import schedule
import time

def job():
    print(f"Running scheduled task at {datetime.now()}")
    # Your automation code here

# Schedule examples
schedule.every(10).minutes.do(job)
schedule.every().hour.do(job)
schedule.every().day.at("10:30").do(job)
schedule.every().monday.do(job)
schedule.every().wednesday.at("13:15").do(job)

# Keep script running
while True:
    schedule.run_pending()
    time.sleep(1)
```

**Real-world scheduled automation:**

```python
import schedule
import time
from datetime import datetime

def backup_files():
    """Daily backup at 2 AM."""
    print(f"[{datetime.now()}] Starting backup...")
    # Your backup logic here
    print("Backup complete!")

def send_daily_report():
    """Send email report at 9 AM."""
    print(f"[{datetime.now()}] Sending daily report...")
    # Your report generation and email logic
    print("Report sent!")

def clean_temp_files():
    """Clean temp files every hour."""
    print(f"[{datetime.now()}] Cleaning temp files...")
    # Your cleanup logic
    print("Cleanup complete!")

# Schedule tasks
schedule.every().day.at("02:00").do(backup_files)
schedule.every().day.at("09:00").do(send_daily_report)
schedule.every().hour.do(clean_temp_files)

print("Scheduler started. Press Ctrl+C to exit.")

# Run scheduler
while True:
    schedule.run_pending()
    time.sleep(60)  # Check every minute
```

For production, deploy this to a server or use system schedulers like cron for reliability. Check our guide on [automating tasks with cron jobs and shell scripts](/2025/10/how-to-automate-tasks-cron-jobs-shell-scripts-linux.html) for production scheduling.

## Web Scraping for Data Collection

Web scraping automates data collection from websites. Combined with scheduling, you can build automated data pipelines.

**Basic web scraper:**

```python
import requests
from bs4 import BeautifulSoup
import csv
from datetime import datetime

def scrape_product_prices(url):
    """
    Scrape product prices from e-commerce site.
    """

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }

    response = requests.get(url, headers=headers)
    soup = BeautifulSoup(response.content, 'lxml')

    products = []

    # Adjust selectors for your target site
    for item in soup.find_all('div', class_='product-card'):
        name = item.find('h3', class_='product-name').text.strip()
        price = item.find('span', class_='price').text.strip()

        products.append({
            'name': name,
            'price': price,
            'scraped_at': datetime.now().isoformat()
        })

    return products

def save_to_csv(data, filename):
    """Save scraped data to CSV."""
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=data[0].keys())
        writer.writeheader()
        writer.writerows(data)

# Usage
products = scrape_product_prices('https://example.com/products')
save_to_csv(products, f'prices_{datetime.now().strftime("%Y%m%d")}.csv')
```

For more web scraping techniques, check the full guide on [building web scrapers with BeautifulSoup and Requests](/2025/10/how-to-build-web-scraper-python-beautifulsoup-requests.html).

## Putting It All Together: A Complete Automation Workflow

Let me show you how to combine these scripts into a complete automation workflow. This example generates and emails a daily report automatically.

**Complete automated reporting system:**

```python
import pandas as pd
from pathlib import Path
from datetime import datetime
import schedule
import time

def generate_daily_report():
    """
    Complete workflow: collect data, process, format, and email.
    """

    print(f"[{datetime.now()}] Starting daily report generation...")

    # Step 1: Collect data (could be from database, API, or files)
    data = {
        'Product': ['Product A', 'Product B', 'Product C'],
        'Sales': [150, 200, 180],
        'Revenue': [15000, 30000, 25000]
    }
    df = pd.DataFrame(data)

    # Step 2: Process and analyze
    df['Profit'] = df['Revenue'] * 0.3
    total_revenue = df['Revenue'].sum()
    total_profit = df['Profit'].sum()

    # Step 3: Generate Excel report
    output_file = f'reports/daily_report_{datetime.now().strftime("%Y%m%d")}.xlsx'
    Path('reports').mkdir(exist_ok=True)

    with pd.ExcelWriter(output_file, engine='openpyxl') as writer:
        df.to_excel(writer, sheet_name='Sales Data', index=False)

        # Add summary sheet
        summary = pd.DataFrame({
            'Metric': ['Total Revenue', 'Total Profit', 'Number of Products'],
            'Value': [total_revenue, total_profit, len(df)]
        })
        summary.to_excel(writer, sheet_name='Summary', index=False)

    print(f"Report generated: {output_file}")

    # Step 4: Send email with attachment
    send_report_email(output_file, total_revenue, total_profit)

    print(f"[{datetime.now()}] Daily report complete!")

def send_report_email(report_file, revenue, profit):
    """Send report via email."""

    subject = f"Daily Sales Report - {datetime.now().strftime('%Y-%m-%d')}"

    body = f"""
    Daily Sales Report

    Summary:
    - Total Revenue: ${revenue:,.2f}
    - Total Profit: ${profit:,.2f}

    Detailed report attached.

    Automated report generated by Python
    """

    # Use email function from earlier
    send_email_with_attachment(
        to_email='manager@company.com',
        subject=subject,
        body=body,
        attachment_path=report_file
    )

# Schedule to run daily at 8 AM
schedule.every().day.at("08:00").do(generate_daily_report)

print("Daily report automation started")
print("Will run every day at 8:00 AM")

while True:
    schedule.run_pending()
    time.sleep(60)
```

This complete workflow collects data, processes it, generates a formatted Excel report, and emails it automatically. Run it on a server, and you never have to manually create reports again.

## Best Practices for Production Automation

Making automation reliable for production requires attention to detail. Here is what I have learned from maintaining automated systems.

**1. Error handling and logging:**

```python
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'logs/automation_{datetime.now().strftime("%Y%m%d")}.log'),
        logging.StreamHandler()
    ]
)

def safe_automation_task():
    """Template for reliable automation with proper error handling."""

    logging.info("Starting automation task")

    try:
        # Your automation code here
        result = perform_task()
        logging.info(f"Task completed successfully: {result}")
        return result

    except FileNotFoundError as e:
        logging.error(f"File not found: {e}")
        send_error_notification("File missing", str(e))

    except Exception as e:
        logging.error(f"Unexpected error: {e}", exc_info=True)
        send_error_notification("Automation failed", str(e))

    finally:
        logging.info("Automation task finished")

def send_error_notification(title, message):
    """Send email alert when automation fails."""
    send_email(
        to_email=os.getenv('ADMIN_EMAIL'),
        subject=f"Automation Error: {title}",
        body=f"An error occurred in automation:\n\n{message}"
    )
```

**2. Configuration management:**

```python
import json
from pathlib import Path

def load_config(config_file='config.json'):
    """Load configuration from external file."""

    with open(config_file, 'r') as f:
        config = json.load(f)

    return config

# config.json example:
{
  "input_folder": "/path/to/data",
  "output_folder": "/path/to/output",
  "email_recipients": ["user1@example.com", "user2@example.com"],
  "schedule_time": "08:00",
  "enable_notifications": true
}
```

**3. Retry logic for reliability:**

```python
import time

def retry_on_failure(func, max_attempts=3, delay=5):
    """
    Retry function on failure with exponential backoff.
    """

    for attempt in range(1, max_attempts + 1):
        try:
            return func()
        except Exception as e:
            if attempt == max_attempts:
                logging.error(f"Failed after {max_attempts} attempts: {e}")
                raise

            wait_time = delay * (2 ** (attempt - 1))  # Exponential backoff
            logging.warning(f"Attempt {attempt} failed, retrying in {wait_time}s: {e}")
            time.sleep(wait_time)

# Usage
result = retry_on_failure(lambda: risky_operation())
```

These patterns make automation robust enough for production use.

## Common Pitfalls and How to Avoid Them

I have made plenty of mistakes with automation. Here are the biggest ones and how to avoid them.

**Path issues:** Always use absolute paths or Path objects. Relative paths break when scripts run from different directories or via schedulers.

```python
# Bad
with open('data.csv', 'r') as f:
    # This breaks when run from cron

# Good
from pathlib import Path
script_dir = Path(__file__).parent
data_file = script_dir / 'data' / 'data.csv'
with open(data_file, 'r') as f:
    # Works everywhere
```

**Hardcoded credentials:** Never put passwords or API keys in code. Use environment variables or config files with restricted permissions.

```python
# Bad
password = 'mypassword123'

# Good
import os
password = os.getenv('EMAIL_PASSWORD')
if not password:
    raise ValueError("EMAIL_PASSWORD environment variable not set")
```

**No error notifications:** Automations fail silently and you discover it weeks later. Always add email or Slack alerts for failures.

**Overcomplicating:** Start simple. A 20-line script that works beats a complex framework you never finish.

**Not testing error cases:** Test what happens when files are missing, networks fail, or data is malformed. Handle these gracefully.

## What to Automate Next

You have learned the fundamentals. Here is where to go next based on your needs.

**For data analysts:** Automate report generation end-to-end. Pull data from databases or APIs, process with pandas, generate visualizations, create formatted Excel or PDF reports, and email stakeholders automatically.

**For developers:** Automate your development workflow. Scripts for environment setup, dependency updates, running test suites, deploying to servers, and generating documentation save hours weekly.

**For content creators:** Automate image processing pipelines. Batch resize, watermark, convert formats, and upload to cloud storage. Add [web scraping](/2025/10/how-to-build-web-scraper-python-beautifulsoup-requests.html) to collect content ideas.

**For system administrators:** Automate server monitoring, log analysis, backup verification, and disk cleanup. Combine with [cron jobs](/2025/10/how-to-automate-tasks-cron-jobs-shell-scripts-linux.html) for scheduled maintenance.

**For e-commerce:** Automate inventory updates, price monitoring, order processing, and customer communication. Web scraping competitors combined with email automation creates powerful workflows.

The best automation solves your actual problems. Look at your daily routine and ask: what am I doing repeatedly that a computer could handle? Start there.

## Wrapping Up

Automation changed how I work. I used to spend hours on tedious tasks. Now those tasks run themselves while I focus on work that actually matters. The scripts in this guide save me 10-15 hours weekly, and I keep finding new things to automate.

Start small. Pick one annoying task from your daily routine and automate it. Get that working, then move to the next. Build a collection of scripts that compound into serious time savings. Share them with teammates and multiply the benefit.

Remember: the goal is not perfect code, it is saving time. A crude script that works is infinitely better than a beautiful one you never finish. Write something quick and dirty, use it for a while, then refactor if needed.

Python makes automation accessible. You do not need to be an expert. Basic Python plus the scripts in this guide handle most automation needs. The hard part is not the code, it is identifying what to automate and actually doing it.

So what are you going to automate first? Pick something that annoys you daily and write a script this weekend. Future you will thank you.

Now go reclaim some time.
