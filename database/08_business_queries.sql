-- =====================================================
-- BUSINESS QUERIES (30 queries)
-- Online Bookstore Database
-- =====================================================
-- These answer real business questions a manager would ask.
-- Concepts covered: JOINs, GROUP BY, HAVING, subqueries,
-- correlated subqueries, CTEs, CASE, date functions, aggregates,
-- set operations, and multi-table analytics.

USE online_book_store;

-- -----------------------------------------------------
-- SECTION A: CATALOG & INVENTORY
-- -----------------------------------------------------

-- Q1: What are the 10 most expensive books in the catalog?
SELECT book_id, title, price, stock
FROM books
ORDER BY price DESC
LIMIT 10;

-- Q2: How many books do we carry in each language?
SELECT language, COUNT(*) AS book_count
FROM books
GROUP BY language
ORDER BY book_count DESC;

-- Q3: Which authors have the most books in our catalog? (JOIN + GROUP BY)
SELECT a.author_name, COUNT(ba.book_id) AS total_books
FROM authors a
JOIN book_authors ba ON a.author_id = ba.author_id
GROUP BY a.author_id, a.author_name
ORDER BY total_books DESC
LIMIT 15;

-- Q4: What is the average price and rating per category? (JOIN + aggregates)
SELECT
    c.category_name,
    COUNT(DISTINCT bc.book_id) AS book_count,
    ROUND(AVG(b.price), 2) AS avg_price,
    ROUND(AVG(b.avg_rating), 2) AS avg_rating
FROM categories c
JOIN book_categories bc ON c.category_id = bc.category_id
JOIN books b ON bc.book_id = b.book_id
GROUP BY c.category_id, c.category_name
HAVING book_count >= 5
ORDER BY avg_rating DESC;

-- Q5: Which books are out of stock or critically low? (CASE)
SELECT
    book_id, title, stock,
    CASE
        WHEN stock = 0 THEN 'OUT OF STOCK'
        WHEN stock <= 5 THEN 'CRITICAL'
        WHEN stock <= 15 THEN 'LOW'
        ELSE 'HEALTHY'
    END AS stock_status
FROM books
WHERE stock <= 15
ORDER BY stock ASC
LIMIT 20;

-- Q6: What is the total inventory value (price x stock)?
SELECT
    COUNT(*) AS total_titles,
    SUM(stock) AS total_units,
    ROUND(SUM(price * stock), 2) AS total_inventory_value
FROM books;

-- Q7: Which books are highly rated but rarely reviewed? (multiple conditions)
SELECT book_id, title, avg_rating, num_ratings, num_reviews
FROM books
WHERE avg_rating >= 4.5
  AND num_reviews < 100
  AND num_ratings > 0
ORDER BY avg_rating DESC, num_ratings DESC
LIMIT 15;

-- Q8: How many books were published each decade? (date functions)
SELECT
    CONCAT(FLOOR(YEAR(publish_date) / 10) * 10, 's') AS decade,
    COUNT(*) AS book_count
FROM books
WHERE publish_date IS NOT NULL
GROUP BY decade
ORDER BY decade;

-- -----------------------------------------------------
-- SECTION B: SALES & REVENUE
-- -----------------------------------------------------

-- Q9: What is our total revenue and order count? (aggregate)
SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_books_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status != 'Cancelled';

-- Q10: What is the monthly revenue trend? (date grouping)
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status != 'Cancelled'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;

-- Q11: Which are the top 10 best-selling books by revenue? (JOIN + GROUP BY)
SELECT
    b.book_id,
    b.title,
    SUM(oi.quantity) AS copies_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
FROM books b
JOIN order_items oi ON b.book_id = oi.book_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.status != 'Cancelled'
GROUP BY b.book_id, b.title
ORDER BY revenue DESC
LIMIT 10;

-- Q12: What is the average order value (AOV)?
SELECT ROUND(AVG(order_total), 2) AS avg_order_value
FROM (
    SELECT o.order_id, SUM(oi.quantity * oi.unit_price) AS order_total
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status != 'Cancelled'
    GROUP BY o.order_id
) AS order_totals;

-- Q13: Which categories generate the most revenue? (multi-JOIN)
SELECT
    c.category_name,
    SUM(oi.quantity) AS copies_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
FROM categories c
JOIN book_categories bc ON c.category_id = bc.category_id
JOIN order_items oi ON bc.book_id = oi.book_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.status != 'Cancelled'
GROUP BY c.category_id, c.category_name
ORDER BY revenue DESC
LIMIT 10;

-- Q14: What is the order status distribution? (GROUP BY + percentage)
SELECT
    status,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS percentage
FROM orders
GROUP BY status
ORDER BY order_count DESC;

-- Q15: Which payment methods are most popular? (JOIN + GROUP BY)
SELECT
    payment_method,
    COUNT(*) AS transaction_count,
    ROUND(SUM(amount), 2) AS total_amount,
    ROUND(AVG(amount), 2) AS avg_transaction
FROM payments
WHERE payment_status = 'Completed'
GROUP BY payment_method
ORDER BY total_amount DESC;


-- -----------------------------------------------------
-- SECTION C: CUSTOMER ANALYTICS
-- -----------------------------------------------------

-- Q16: Who are our top 10 customers by lifetime value? (JOIN + GROUP BY)
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS lifetime_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status != 'Cancelled'
GROUP BY c.customer_id, customer_name
ORDER BY lifetime_value DESC
LIMIT 10;

-- Q17: How many customers have never placed an order? (LEFT JOIN + NULL)
SELECT COUNT(*) AS customers_without_orders
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

-- Q18: Which customers spent more than the average customer? (correlated subquery)
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status != 'Cancelled'
GROUP BY c.customer_id, customer_name
HAVING total_spent > (
    SELECT AVG(cust_total)
    FROM (
        SELECT SUM(oi2.quantity * oi2.unit_price) AS cust_total
        FROM orders o2
        JOIN order_items oi2 ON o2.order_id = oi2.order_id
        WHERE o2.status != 'Cancelled'
        GROUP BY o2.customer_id
    ) AS averages
)
ORDER BY total_spent DESC;

-- Q19: What is the customer segmentation by spending tier? (CASE + subquery)
SELECT
    spending_tier,
    COUNT(*) AS customer_count
FROM (
    SELECT
        c.customer_id,
        CASE
            WHEN SUM(oi.quantity * oi.unit_price) >= 10000 THEN 'High Value'
            WHEN SUM(oi.quantity * oi.unit_price) >= 5000 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS spending_tier
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status != 'Cancelled'
    GROUP BY c.customer_id
) AS segments
GROUP BY spending_tier
ORDER BY customer_count DESC;

-- Q20: How many repeat customers do we have (more than 1 order)?
SELECT
    COUNT(*) AS repeat_customers
FROM (
    SELECT customer_id
    FROM orders
    WHERE status != 'Cancelled'
    GROUP BY customer_id
    HAVING COUNT(order_id) > 1
) AS repeats;

-- Q21: What is each customer's most recent order? (correlated subquery)
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    o.order_id,
    o.order_date,
    o.status
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_date = (
    SELECT MAX(o2.order_date)
    FROM orders o2
    WHERE o2.customer_id = c.customer_id
)
ORDER BY o.order_date DESC
LIMIT 15;


-- -----------------------------------------------------
-- SECTION D: REVIEWS & ENGAGEMENT
-- -----------------------------------------------------

-- Q22: What is the distribution of review ratings? (GROUP BY)
SELECT
    rating,
    COUNT(*) AS review_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM reviews), 2) AS percentage
FROM reviews
GROUP BY rating
ORDER BY rating DESC;

-- Q23: Which books have the most reviews from our customers? (JOIN + GROUP BY)
SELECT
    b.book_id,
    b.title,
    COUNT(r.review_id) AS review_count,
    ROUND(AVG(r.rating), 2) AS avg_customer_rating
FROM books b
JOIN reviews r ON b.book_id = r.book_id
GROUP BY b.book_id, b.title
ORDER BY review_count DESC
LIMIT 10;

-- Q24: Which books are most wishlisted but low in stock? (JOIN + HAVING)
SELECT
    b.book_id,
    b.title,
    b.stock,
    COUNT(w.wishlist_id) AS wishlist_count
FROM books b
JOIN wishlists w ON b.book_id = w.book_id
GROUP BY b.book_id, b.title, b.stock
HAVING b.stock <= 25
ORDER BY wishlist_count DESC
LIMIT 15;

-- Q25: What percentage of customers have written at least one review?
SELECT
    ROUND(
        (SELECT COUNT(DISTINCT customer_id) FROM reviews) * 100.0 /
        (SELECT COUNT(*) FROM customers),
    2) AS pct_customers_reviewed;


-- -----------------------------------------------------
-- SECTION E: ADVANCED ANALYTICS (CTEs & Subqueries)
-- -----------------------------------------------------

-- Q26: Books that are wishlisted but never ordered (set difference via NOT IN)
SELECT DISTINCT
    b.book_id,
    b.title,
    COUNT(w.wishlist_id) AS wishlist_count
FROM books b
JOIN wishlists w ON b.book_id = w.book_id
WHERE b.book_id NOT IN (SELECT DISTINCT book_id FROM order_items)
GROUP BY b.book_id, b.title
ORDER BY wishlist_count DESC
LIMIT 10;

-- Q27: Revenue contribution by top authors (CTE)
WITH author_revenue AS (
    SELECT
        a.author_id,
        a.author_name,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM authors a
    JOIN book_authors ba ON a.author_id = ba.author_id
    JOIN order_items oi ON ba.book_id = oi.book_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.status != 'Cancelled'
    GROUP BY a.author_id, a.author_name
)
SELECT
    author_name,
    ROUND(revenue, 2) AS revenue,
    ROUND(revenue * 100.0 / (SELECT SUM(revenue) FROM author_revenue), 2) AS pct_of_total
FROM author_revenue
ORDER BY revenue DESC
LIMIT 10;

-- Q28: Month-over-month revenue growth (CTE + self comparison)
WITH monthly AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status != 'Cancelled'
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT
    m1.month,
    ROUND(m1.revenue, 2) AS revenue,
    ROUND(m1.revenue - m2.revenue, 2) AS mom_change,
    ROUND((m1.revenue - m2.revenue) * 100.0 / m2.revenue, 2) AS mom_growth_pct
FROM monthly m1
LEFT JOIN monthly m2
    ON PERIOD_DIFF(REPLACE(m1.month, '-', ''), REPLACE(m2.month, '-', '')) = 1
ORDER BY m1.month;

-- Q29: Books priced above the average price in their category (correlated subquery)
SELECT
    b.book_id,
    b.title,
    c.category_name,
    b.price
FROM books b
JOIN book_categories bc ON b.book_id = bc.book_id
JOIN categories c ON bc.category_id = c.category_id
WHERE b.price > (
    SELECT AVG(b2.price)
    FROM books b2
    JOIN book_categories bc2 ON b2.book_id = bc2.book_id
    WHERE bc2.category_id = bc.category_id
)
ORDER BY c.category_name, b.price DESC
LIMIT 20;

-- Q30: Overall business health dashboard (multiple subqueries)
SELECT
    (SELECT COUNT(*) FROM books) AS total_books,
    (SELECT COUNT(*) FROM customers) AS total_customers,
    (SELECT COUNT(*) FROM orders WHERE status != 'Cancelled') AS total_orders,
    (SELECT ROUND(SUM(oi.quantity * oi.unit_price), 2)
     FROM orders o JOIN order_items oi ON o.order_id = oi.order_id
     WHERE o.status != 'Cancelled') AS total_revenue,
    (SELECT COUNT(*) FROM reviews) AS total_reviews,
    (SELECT ROUND(AVG(rating), 2) FROM reviews) AS avg_review_rating;


SELECT 'All 30 business queries executed successfully!' AS Status;
