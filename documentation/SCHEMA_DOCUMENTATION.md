# Database Schema Documentation — Online Bookstore

Complete reference for every table, following the professional per-table template.
Database engine: **MySQL 8.0**. Naming convention: **snake_case, plural table names**.

---

## Entity Relationship Overview

```
                          ┌──────────────┐
                          │   authors    │
                          └──────┬───────┘
                                 │ 1
                                 │
                          ┌──────┴───────┐        ┌──────────────┐
                          │ book_authors │        │  categories  │
                          │  (junction)  │        └──────┬───────┘
                          └──────┬───────┘               │ 1
                                 │ M                      │
                            M    │                   ┌────┴──────────┐
        ┌────────────┐  ┌────────┴─────┐   M         │book_categories│
        │  reviews   │M─│    books     │─────────────┤  (junction)   │
        └─────┬──────┘  └──────┬───────┘             └───────────────┘
              │ M              │ M
              │                │
              │ M       ┌──────┴───────┐   M    ┌──────────────┐
        ┌─────┴──────┐  │ order_items  │────────│    orders    │
        │ wishlists  │  └──────────────┘   M  1 └──────┬───────┘
        └─────┬──────┘                            1    │ M
              │ M                                       │
              │            ┌──────────────┐            │
              └────────────┤  customers   ├────────────┘
                       M  1 └──────┬───────┘ 1
                                   │ 1
                                   │
                            ┌──────┴───────┐
                            │   payments   │  (1 order → 1 payment)
                            └──────────────┘
```

**Relationship cardinalities:**
- `books` ↔ `authors` : **many-to-many** (via `book_authors`)
- `books` ↔ `categories` : **many-to-many** (via `book_categories`)
- `customers` → `orders` : **one-to-many**
- `orders` → `order_items` : **one-to-many**
- `books` → `order_items` : **one-to-many**
- `orders` → `payments` : **one-to-one**
- `customers` → `reviews` → `books` : customer writes many reviews; book has many reviews
- `customers` → `wishlists` → `books` : many-to-many via wishlists

---

## Table 1: `books`
| Attribute | Value |
|-----------|-------|
| **Purpose** | Core catalog entity — one row per book title sold by the store |
| **Primary Key** | `book_id` (INT) — sourced from the Goodreads dataset |
| **Foreign Keys** | None (referenced by many tables) |
| **Relationships** | 1-to-many with `order_items`, `reviews`, `wishlists`; many-to-many with `authors` and `categories` |
| **Business Purpose** | Everything the store sells; the anchor of all sales and rating analytics |

**Columns:** `book_id` (INT, PK), `title` (VARCHAR 255, NOT NULL), `description` (TEXT),
`isbn` (VARCHAR 20, UNIQUE), `isbn13` (VARCHAR 20, UNIQUE), `language` (VARCHAR 50),
`num_pages` (INT), `publish_date` (DATE), `first_publish_date` (DATE), `series` (VARCHAR 255),
`avg_rating` (DECIMAL 3,2), `num_ratings` (INT), `num_reviews` (INT), `price` (DECIMAL 8,2, NOT NULL),
`stock` (INT, default 0).

---

## Table 2: `authors`
| Attribute | Value |
|-----------|-------|
| **Purpose** | Distinct authors who write the books |
| **Primary Key** | `author_id` (INT, AUTO_INCREMENT) |
| **Foreign Keys** | None |
| **Relationships** | Many-to-many with `books` via `book_authors` |
| **Business Purpose** | Enables author-level analytics (revenue by author, catalog depth) without duplicating names |

**Columns:** `author_id` (INT, PK), `author_name` (VARCHAR 255, NOT NULL).

---

## Table 3: `book_authors`
| Attribute | Value |
|-----------|-------|
| **Purpose** | Junction table resolving the many-to-many between books and authors |
| **Primary Key** | Composite `(book_id, author_id)` |
| **Foreign Keys** | `book_id → books.book_id`; `author_id → authors.author_id` (both ON DELETE CASCADE) |
| **Relationships** | Bridges `books` and `authors` |
| **Business Purpose** | A book can have multiple authors; an author can write many books |

---

## Table 4: `categories`
| Attribute | Value |
|-----------|-------|
| **Purpose** | Distinct genres/categories a book can belong to |
| **Primary Key** | `category_id` (INT, AUTO_INCREMENT) |
| **Foreign Keys** | None |
| **Relationships** | Many-to-many with `books` via `book_categories` |
| **Business Purpose** | Powers genre-based browsing and category revenue analysis |

**Columns:** `category_id` (INT, PK), `category_name` (VARCHAR 100, NOT NULL, UNIQUE).

---

## Table 5: `book_categories`
| Attribute | Value |
|-----------|-------|
| **Purpose** | Junction table resolving many-to-many between books and categories |
| **Primary Key** | Composite `(book_id, category_id)` |
| **Foreign Keys** | `book_id → books.book_id`; `category_id → categories.category_id` (both CASCADE) |
| **Relationships** | Bridges `books` and `categories` |
| **Business Purpose** | A book belongs to several genres; a genre contains many books |

---

## Table 6: `customers`
| Attribute | Value |
|-----------|-------|
| **Purpose** | Registered customers of the store |
| **Primary Key** | `customer_id` (INT, AUTO_INCREMENT) |
| **Foreign Keys** | None (referenced by orders, reviews, wishlists) |
| **Relationships** | 1-to-many with `orders`, `reviews`, `wishlists` |
| **Business Purpose** | Anchors all customer analytics: LTV, segmentation, retention |

**Columns:** `customer_id` (INT, PK), `first_name` (VARCHAR 100, NOT NULL),
`last_name` (VARCHAR 100, NOT NULL), `email` (VARCHAR 255, NOT NULL, UNIQUE),
`phone` (VARCHAR 20), `created_at` (TIMESTAMP, default CURRENT_TIMESTAMP).

---

## Table 7: `orders`
| Attribute | Value |
|-----------|-------|
| **Purpose** | Order header — one row per order placed by a customer |
| **Primary Key** | `order_id` (INT, AUTO_INCREMENT) |
| **Foreign Keys** | `customer_id → customers.customer_id` (CASCADE) |
| **Relationships** | Many-to-one with `customers`; one-to-many with `order_items`; one-to-one with `payments` |
| **Business Purpose** | The central transaction record for all sales reporting |

**Columns:** `order_id` (INT, PK), `customer_id` (INT, FK, NOT NULL),
`order_date` (TIMESTAMP, default CURRENT_TIMESTAMP),
`status` (ENUM: Pending, Processing, Shipped, Delivered, Cancelled).

---

## Table 8: `order_items`
| Attribute | Value |
|-----------|-------|
| **Purpose** | Line items within an order — one row per book in an order |
| **Primary Key** | `order_item_id` (INT, AUTO_INCREMENT) |
| **Foreign Keys** | `order_id → orders.order_id`; `book_id → books.book_id` (both CASCADE) |
| **Relationships** | Many-to-one with both `orders` and `books` |
| **Business Purpose** | The grain of revenue analysis; stores `unit_price` = price at time of purchase |

**Columns:** `order_item_id` (INT, PK), `order_id` (INT, FK, NOT NULL),
`book_id` (INT, FK, NOT NULL), `quantity` (INT, NOT NULL, CHECK > 0),
`unit_price` (DECIMAL 8,2, NOT NULL).

---

## Table 9: `payments`
| Attribute | Value |
|-----------|-------|
| **Purpose** | Payment record for an order |
| **Primary Key** | `payment_id` (INT, AUTO_INCREMENT) |
| **Foreign Keys** | `order_id → orders.order_id` (CASCADE), UNIQUE |
| **Relationships** | One-to-one with `orders` |
| **Business Purpose** | Tracks payment method and status for financial reporting and refunds |

**Columns:** `payment_id` (INT, PK), `order_id` (INT, FK, NOT NULL, UNIQUE),
`amount` (DECIMAL 10,2, NOT NULL),
`payment_method` (ENUM: Credit Card, Debit Card, UPI, Net Banking, Cash on Delivery),
`payment_status` (ENUM: Pending, Completed, Failed, Refunded),
`payment_date` (TIMESTAMP, default CURRENT_TIMESTAMP).

---

## Table 10: `reviews`
| Attribute | Value |
|-----------|-------|
| **Purpose** | Customer-written reviews and ratings of books |
| **Primary Key** | `review_id` (INT, AUTO_INCREMENT) |
| **Foreign Keys** | `customer_id → customers.customer_id`; `book_id → books.book_id` (both CASCADE) |
| **Constraints** | `rating` CHECK BETWEEN 1 AND 5; UNIQUE `(customer_id, book_id)` — one review per customer per book |
| **Relationships** | Many-to-one with both `customers` and `books` |
| **Business Purpose** | Feeds book rating recalculation (via trigger) and engagement metrics |

**Columns:** `review_id` (INT, PK), `customer_id` (INT, FK, NOT NULL),
`book_id` (INT, FK, NOT NULL), `rating` (INT, NOT NULL, CHECK 1–5),
`review_text` (TEXT), `review_date` (TIMESTAMP, default CURRENT_TIMESTAMP).

---

## Table 11: `wishlists`
| Attribute | Value |
|-----------|-------|
| **Purpose** | Books a customer has saved for later |
| **Primary Key** | `wishlist_id` (INT, AUTO_INCREMENT) |
| **Foreign Keys** | `customer_id → customers.customer_id`; `book_id → books.book_id` (both CASCADE) |
| **Constraints** | UNIQUE `(customer_id, book_id)` — a book appears once per customer's wishlist |
| **Relationships** | Many-to-one with both `customers` and `books` |
| **Business Purpose** | Signals demand; used to flag wishlisted-but-low-stock and wishlisted-but-never-ordered books |

**Columns:** `wishlist_id` (INT, PK), `customer_id` (INT, FK, NOT NULL),
`book_id` (INT, FK, NOT NULL), `added_at` (TIMESTAMP, default CURRENT_TIMESTAMP).

---

## Audit Tables (populated by triggers)

**`stock_audit_log`** — records every stock change (book_id, old/new stock, change amount, reason, timestamp).
**`order_status_log`** — records every order status transition (order_id, old status, new status, timestamp).
