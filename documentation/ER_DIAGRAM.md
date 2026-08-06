# Entity Relationship Diagram — Online Bookstore

This ER diagram renders natively on GitHub (Mermaid). It shows all 11 core tables,
their primary/foreign keys, and the cardinality of every relationship.

```mermaid
erDiagram
    authors {
        int author_id PK
        varchar author_name
    }
    books {
        int book_id PK
        varchar title
        varchar isbn UK
        varchar isbn13 UK
        varchar language
        int num_pages
        date publish_date
        decimal avg_rating
        int num_ratings
        decimal price
        int stock
    }
    categories {
        int category_id PK
        varchar category_name UK
    }
    book_authors {
        int book_id PK,FK
        int author_id PK,FK
    }
    book_categories {
        int book_id PK,FK
        int category_id PK,FK
    }
    customers {
        int customer_id PK
        varchar first_name
        varchar last_name
        varchar email UK
        varchar phone
        timestamp created_at
    }
    orders {
        int order_id PK
        int customer_id FK
        timestamp order_date
        enum status
    }
    order_items {
        int order_item_id PK
        int order_id FK
        int book_id FK
        int quantity
        decimal unit_price
    }
    payments {
        int payment_id PK
        int order_id FK,UK
        decimal amount
        enum payment_method
        enum payment_status
        timestamp payment_date
    }
    reviews {
        int review_id PK
        int customer_id FK
        int book_id FK
        int rating
        text review_text
        timestamp review_date
    }
    wishlists {
        int wishlist_id PK
        int customer_id FK
        int book_id FK
        timestamp added_at
    }

    books ||--o{ book_authors : "written by"
    authors ||--o{ book_authors : "writes"
    books ||--o{ book_categories : "classified as"
    categories ||--o{ book_categories : "contains"
    customers ||--o{ orders : "places"
    orders ||--o{ order_items : "contains"
    books ||--o{ order_items : "appears in"
    orders ||--|| payments : "paid by"
    customers ||--o{ reviews : "writes"
    books ||--o{ reviews : "receives"
    customers ||--o{ wishlists : "saves"
    books ||--o{ wishlists : "saved in"
```

## Relationship Summary

| From | To | Cardinality | Via |
|------|-----|-------------|-----|
| books | authors | many-to-many | `book_authors` |
| books | categories | many-to-many | `book_categories` |
| customers | orders | one-to-many | direct FK |
| orders | order_items | one-to-many | direct FK |
| books | order_items | one-to-many | direct FK |
| orders | payments | one-to-one | direct FK (UNIQUE) |
| customers | reviews | one-to-many | direct FK |
| books | reviews | one-to-many | direct FK |
| customers | wishlists | one-to-many | direct FK |
| books | wishlists | one-to-many | direct FK |

## How to Regenerate in MySQL Workbench

For a formal image export (optional):
1. Open MySQL Workbench → **Database → Reverse Engineer** (Ctrl+R)
2. Select the `online_book_store` schema
3. Workbench auto-generates the EER diagram
4. **File → Export → Export as PNG** and save to `documentation/er_diagram.png`

> **Legend:** `||` = exactly one, `o{` = zero-or-many. PK = primary key,
> FK = foreign key, UK = unique key.
