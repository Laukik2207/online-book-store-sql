-- =====================================================
-- INDEXES
-- Online Bookstore Database
-- =====================================================
-- Indexing strategy: index foreign keys and columns frequently
-- used in WHERE / JOIN / ORDER BY clauses on large tables.
-- Primary keys and UNIQUE columns are already indexed automatically.

USE online_book_store;

-- Books: title is frequently searched; publish_date & avg_rating used for filtering/sorting reports
CREATE INDEX idx_books_title        ON books(title);
CREATE INDEX idx_books_publish_date ON books(publish_date);
CREATE INDEX idx_books_avg_rating   ON books(avg_rating);
CREATE INDEX idx_books_price        ON books(price);

-- Junction tables: speed up joins from book -> author / category
CREATE INDEX idx_book_authors_author   ON book_authors(author_id);
CREATE INDEX idx_book_categories_cat    ON book_categories(category_id);

-- Orders: heavily filtered by customer and date in reporting queries
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date     ON orders(order_date);
CREATE INDEX idx_orders_status   ON orders(status);

-- Order items: joined on order_id and book_id for revenue reports
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_book  ON order_items(book_id);

-- Payments: filtered by status and date
CREATE INDEX idx_payments_status ON payments(payment_status);
CREATE INDEX idx_payments_date   ON payments(payment_date);

-- Reviews: aggregated by book; filtered by rating
CREATE INDEX idx_reviews_book   ON reviews(book_id);
CREATE INDEX idx_reviews_rating ON reviews(rating);

SELECT 'Indexes created successfully!' AS Status;
