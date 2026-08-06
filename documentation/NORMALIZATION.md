# Database Normalization — Online Bookstore

This document demonstrates how the Online Bookstore schema was normalized from an
**Unnormalized Form (UNF)** through to **Third Normal Form (3NF)**, showing the
anomaly removed at each step. The source data (a flat Goodreads CSV where each row
mixed a book with its comma-separated authors and genres) is the natural UNF starting
point.

---

## Starting Point — The Raw Flat File (UNF)

The Goodreads dataset arrives as one wide table where a single book row contains
repeating groups (multiple authors and multiple genres crammed into one cell):

| bookId | title | author | genres | isbn | language | avg_rating | price |
|--------|-------|--------|--------|------|----------|------------|-------|
| 2 | Harry Potter and the Order of the Phoenix | J.K. Rowling, **Mary GrandPré** | Fantasy, Fiction, **Young Adult** | 043935806X | English | 4.50 | 899 |
| 3 | Harry Potter and the Sorcerer's Stone | J.K. Rowling, **Mary GrandPré** | Fantasy, Fiction, **Classics** | 0590353403 | English | 4.47 | 599 |

**Problems with this UNF table:**
- `author` and `genres` hold **repeating groups** (comma-separated lists) — not atomic.
- The same author ("Mary GrandPré") and genre ("Fantasy") are **repeated** across many rows → update anomalies.
- If we delete the last book by an author, we lose the author entirely → deletion anomaly.
- We cannot add a new author who has not yet published a book → insertion anomaly.

---

## Step 1 — First Normal Form (1NF)

**Rule:** Eliminate repeating groups; every column must hold a single atomic value;
each row must be unique (identified by a primary key).

We break the multi-valued `author` and `genres` cells into individual rows, giving one
row per (book, author) and one row per (book, genre) combination.

**Books (atomic columns, `book_id` as PK):**

| book_id | title | isbn | language | avg_rating | price |
|---------|-------|------|----------|------------|-------|
| 2 | Harry Potter and the Order of the Phoenix | 043935806X | English | 4.50 | 899 |
| 3 | Harry Potter and the Sorcerer's Stone | 0590353403 | English | 4.47 | 599 |

**Book-Author rows (atomic):**

| book_id | author_name |
|---------|-------------|
| 2 | J.K. Rowling |
| 2 | Mary GrandPré |
| 3 | J.K. Rowling |
| 3 | Mary GrandPré |

**Book-Genre rows (atomic):**

| book_id | genre_name |
|---------|------------|
| 2 | Fantasy |
| 2 | Fiction |
| 3 | Fantasy |
| 3 | Classics |

**Anomaly removed:** repeating groups are gone; every field is now atomic and each
row is uniquely identifiable.

---

## Step 2 — Second Normal Form (2NF)

**Rule:** Be in 1NF **and** remove partial dependencies — no non-key column may depend
on only *part* of a composite primary key.

The `book_authors` bridge above has a composite key `(book_id, author_name)`. Storing
`author_name` (and any future author attribute like nationality) directly here means
author facts depend only on the author, not on the whole `(book_id, author_name)` key —
a partial dependency. We fix this by giving authors their own table with a surrogate key.

**authors** (author facts live here, keyed by `author_id`):

| author_id | author_name |
|-----------|-------------|
| 1 | J.K. Rowling |
| 2 | Mary GrandPré |

**book_authors** (pure junction, composite PK `(book_id, author_id)`):

| book_id | author_id |
|---------|-----------|
| 2 | 1 |
| 2 | 2 |
| 3 | 1 |
| 3 | 2 |

The same treatment applies to genres → **categories** + **book_categories**.

**Anomaly removed:** an author's details are stored **once**. Renaming "J.K. Rowling"
now touches a single row instead of every book she wrote (update anomaly gone). Authors
can exist independently of books (insertion anomaly gone).

---

## Step 3 — Third Normal Form (3NF)

**Rule:** Be in 2NF **and** remove transitive dependencies — no non-key column may
depend on another non-key column.

In the original flat file, order data would have looked like this:

| order_id | customer_name | customer_email | customer_phone | book_title | unit_price | quantity |
|----------|---------------|----------------|----------------|------------|------------|----------|

Here `customer_email` and `customer_phone` depend on `customer_name` (really, on the
customer), **not** on `order_id`. That is a transitive dependency: `order_id → customer → email`.
The same holds for book attributes depending on the book rather than the order line.

We resolve this by extracting customers and books into their own tables and referencing
them by foreign key:

**customers** (customer facts, keyed by `customer_id`):

| customer_id | first_name | last_name | email | phone |
|-------------|-----------|-----------|-------|-------|
| 1 | Aarav | Sharma | aarav.sharma@email.com | 9876543210 |

**orders** (references the customer, no customer detail duplicated):

| order_id | customer_id | order_date | status |
|----------|-------------|------------|--------|
| 1 | 1 | 2024-01-05 | Delivered |

**order_items** (references order + book; stores only line-specific facts):

| order_item_id | order_id | book_id | quantity | unit_price |
|---------------|----------|---------|----------|------------|
| 1 | 1 | 2 | 2 | 899.00 |

Note `unit_price` is deliberately kept on `order_items` (not read from `books`) because
it records the **price at time of purchase** — a genuine line-level fact, not a transitive
copy of the current book price.

**Anomaly removed:** a customer's email/phone is stored once in `customers`. Updating a
phone number no longer risks inconsistent copies scattered across their orders.

---

## Final 3NF Schema (11 tables)

| # | Table | Type | Purpose |
|---|-------|------|---------|
| 1 | `books` | Master | Core catalog: title, ISBN, price, stock, ratings |
| 2 | `authors` | Master | Distinct authors |
| 3 | `book_authors` | Junction | Resolves many-to-many books ↔ authors |
| 4 | `categories` | Master | Distinct genres/categories |
| 5 | `book_categories` | Junction | Resolves many-to-many books ↔ categories |
| 6 | `customers` | Master | Registered customers |
| 7 | `orders` | Transaction | Order headers (customer, date, status) |
| 8 | `order_items` | Transaction | Order line items (book, qty, price at purchase) |
| 9 | `payments` | Transaction | One payment per order |
| 10 | `reviews` | Transaction | Customer reviews of books |
| 11 | `wishlists` | Transaction | Books saved by customers |

*(Plus two audit tables — `stock_audit_log`, `order_status_log` — populated by triggers.)*

**Every table is in 3NF:** each has a defined primary key, every non-key attribute
depends on the whole key and nothing but the key, and all many-to-many relationships are
resolved through junction tables.
