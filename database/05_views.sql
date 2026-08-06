-- =====================================================
-- VIEWS
-- Online Bookstore Database
-- =====================================================
-- Views provide reusable, readable abstractions over complex queries

USE online_book_store;

-- =====================================================
-- VIEW 1: Book Details with Authors and Categories
-- =====================================================
-- Denormalized view joining books with their authors and categories
-- Useful for product catalog displays and search results

CREATE OR REPLACE VIEW vw_book_details AS
SELECT
    b.book_id,
    b.title,
    b.description,
    GROUP_CONCAT(DISTINCT a.author_name ORDER BY a.author_name SEPARATOR ', ') AS authors,
    GROUP_CONCAT(DISTINCT c.category_name ORDER BY c.category_name SEPARATOR ', ') AS categories,
    b.series,
    b.isbn,
    b.isbn13,
    b.language,
    b.publish_date,
    b.first_publish_date,
    b.num_pages,
    b.avg_rating,
    b.num_ratings,
    b.num_reviews,
    b.price,
    b.stock
FROM books b
LEFT JOIN book_authors ba ON b.book_id = ba.book_id
LEFT JOIN authors a ON ba.author_id = a.author_id
LEFT JOIN book_categories bc ON b.book_id = bc.book_id
LEFT JOIN categories c ON bc.category_id = c.category_id
GROUP BY
    b.book_id, b.title, b.description, b.series, b.isbn, b.isbn13,
    b.language, b.publish_date, b.first_publish_date, b.num_pages,
    b.avg_rating, b.num_ratings, b.num_reviews, b.price, b.stock;

-- Test the view
SELECT * FROM vw_book_details LIMIT 5;


-- =====================================================
-- VIEW 2: Order Summary with Customer and Payment Details
-- =====================================================
-- Complete order information joining orders, customers, payments, and items
-- Useful for order management and customer service dashboards

CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
    o.order_id,
    o.order_date,
    o.status AS order_status,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    c.phone,
    COUNT(DISTINCT oi.order_item_id) AS total_items,
    SUM(oi.quantity) AS total_quantity,
    SUM(oi.quantity * oi.unit_price) AS order_total,
    p.payment_id,
    p.payment_method,
    p.payment_status,
    p.payment_date
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN payments p ON o.order_id = p.order_id
GROUP BY
    o.order_id, o.order_date, o.status, c.customer_id, c.first_name,
    c.last_name, c.email, c.phone, p.payment_id, p.payment_method,
    p.payment_status, p.payment_date;

-- Test the view
SELECT * FROM vw_order_summary ORDER BY order_date DESC LIMIT 10;


-- =====================================================
-- VIEW 3: Customer Purchase History
-- =====================================================
-- Aggregated customer metrics for CRM and loyalty programs
-- Shows lifetime value, order frequency, and recent activity

CREATE OR REPLACE VIEW vw_customer_metrics AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    c.created_at AS registration_date,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS lifetime_value,
    COALESCE(AVG(oi.quantity * oi.unit_price), 0) AS avg_order_value,
    MAX(o.order_date) AS last_order_date,
    DATEDIFF(CURDATE(), MAX(o.order_date)) AS days_since_last_order,
    COUNT(DISTINCT r.review_id) AS total_reviews,
    COALESCE(AVG(r.rating), 0) AS avg_rating_given,
    COUNT(DISTINCT w.wishlist_id) AS wishlist_items
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN reviews r ON c.customer_id = r.customer_id
LEFT JOIN wishlists w ON c.customer_id = w.customer_id
GROUP BY
    c.customer_id, c.first_name, c.last_name, c.email, c.created_at;

-- Test the view
SELECT * FROM vw_customer_metrics
ORDER BY lifetime_value DESC
LIMIT 10;


-- =====================================================
-- VIEW 4: Popular Books Dashboard
-- =====================================================
-- Books ranked by various popularity metrics
-- Useful for homepage featured sections and recommendations

CREATE OR REPLACE VIEW vw_popular_books AS
SELECT
    b.book_id,
    b.title,
    GROUP_CONCAT(DISTINCT a.author_name SEPARATOR ', ') AS authors,
    b.avg_rating,
    b.num_ratings,
    b.num_reviews,
    b.price,
    b.stock,
    COUNT(DISTINCT oi.order_item_id) AS times_ordered,
    COALESCE(SUM(oi.quantity), 0) AS total_copies_sold,
    COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS total_revenue,
    COUNT(DISTINCT w.wishlist_id) AS times_wishlisted,
    COUNT(DISTINCT r.review_id) AS review_count
FROM books b
LEFT JOIN book_authors ba ON b.book_id = ba.book_id
LEFT JOIN authors a ON ba.author_id = a.author_id
LEFT JOIN order_items oi ON b.book_id = oi.book_id
LEFT JOIN wishlists w ON b.book_id = w.book_id
LEFT JOIN reviews r ON b.book_id = r.book_id
GROUP BY
    b.book_id, b.title, b.avg_rating, b.num_ratings,
    b.num_reviews, b.price, b.stock;

-- Test the view
SELECT * FROM vw_popular_books
ORDER BY total_revenue DESC
LIMIT 10;


-- =====================================================
-- VIEW 5: Revenue by Month
-- =====================================================
-- Monthly revenue trends for business reporting
-- Includes order count and average order value per month

CREATE OR REPLACE VIEW vw_monthly_revenue AS
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    YEAR(o.order_date) AS year,
    MONTH(o.order_date) AS month_num,
    MONTHNAME(o.order_date) AS month_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_books_sold,
    SUM(oi.quantity * oi.unit_price) AS total_revenue,
    AVG(oi.quantity * oi.unit_price) AS avg_order_value,
    COUNT(DISTINCT o.customer_id) AS unique_customers
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status != 'Cancelled'
GROUP BY
    DATE_FORMAT(o.order_date, '%Y-%m'),
    YEAR(o.order_date),
    MONTH(o.order_date),
    MONTHNAME(o.order_date)
ORDER BY month;

-- Test the view
SELECT * FROM vw_monthly_revenue;


-- =====================================================
-- VIEW 6: Low Stock Alert
-- =====================================================
-- Books that need restocking based on sales velocity
-- Useful for inventory management

CREATE OR REPLACE VIEW vw_low_stock_alert AS
SELECT
    b.book_id,
    b.title,
    GROUP_CONCAT(DISTINCT a.author_name SEPARATOR ', ') AS authors,
    b.stock AS current_stock,
    COALESCE(COUNT(DISTINCT oi.order_item_id), 0) AS times_ordered,
    COALESCE(SUM(oi.quantity), 0) AS total_sold,
    b.price,
    CASE
        WHEN b.stock = 0 THEN 'OUT OF STOCK'
        WHEN b.stock <= 5 THEN 'CRITICAL'
        WHEN b.stock <= 15 THEN 'LOW'
        ELSE 'NORMAL'
    END AS stock_status
FROM books b
LEFT JOIN book_authors ba ON b.book_id = ba.book_id
LEFT JOIN authors a ON ba.author_id = a.author_id
LEFT JOIN order_items oi ON b.book_id = oi.book_id
GROUP BY
    b.book_id, b.title, b.stock, b.price
HAVING stock_status IN ('OUT OF STOCK', 'CRITICAL', 'LOW')
ORDER BY
    FIELD(stock_status, 'OUT OF STOCK', 'CRITICAL', 'LOW'),
    total_sold DESC;

-- Test the view
SELECT * FROM vw_low_stock_alert LIMIT 20;


SELECT 'All 6 views created successfully!' AS Status;
