-- =====================================================
-- WINDOW FUNCTIONS (Advanced Analytics)
-- Online Bookstore Database
-- =====================================================
-- Window functions allow ranking, running totals, and row-to-row
-- comparisons without collapsing groups. Required for modern analytics.

USE online_book_store;

-- -----------------------------------------------------
-- RANKING & TOP-N ANALYSIS
-- -----------------------------------------------------

-- WF1: Rank books by revenue within each category (RANK + PARTITION BY)
SELECT
    c.category_name,
    b.title,
    SUM(oi.quantity * oi.unit_price) AS revenue,
    RANK() OVER (
        PARTITION BY c.category_name
        ORDER BY SUM(oi.quantity * oi.unit_price) DESC
    ) AS revenue_rank
FROM categories c
JOIN book_categories bc ON c.category_id = bc.category_id
JOIN books b ON bc.book_id = b.book_id
JOIN order_items oi ON b.book_id = oi.book_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.status != 'Cancelled'
GROUP BY c.category_name, b.book_id, b.title
ORDER BY c.category_name, revenue_rank
LIMIT 50;

-- WF2: Top 3 best-selling books per category (ROW_NUMBER for exact top-N)
WITH ranked_books AS (
    SELECT
        c.category_name,
        b.title,
        SUM(oi.quantity) AS copies_sold,
        ROW_NUMBER() OVER (
            PARTITION BY c.category_name
            ORDER BY SUM(oi.quantity) DESC
        ) AS row_num
    FROM categories c
    JOIN book_categories bc ON c.category_id = bc.category_id
    JOIN books b ON bc.book_id = b.book_id
    JOIN order_items oi ON b.book_id = oi.book_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.status != 'Cancelled'
    GROUP BY c.category_name, b.book_id, b.title
)
SELECT category_name, title, copies_sold, row_num AS category_rank
FROM ranked_books
WHERE row_num <= 3
ORDER BY category_name, row_num;

-- WF3: Customer spending quartiles (NTILE for segmentation)
SELECT
    customer_id,
    customer_name,
    total_spent,
    NTILE(4) OVER (ORDER BY total_spent DESC) AS spending_quartile,
    CASE NTILE(4) OVER (ORDER BY total_spent DESC)
        WHEN 1 THEN 'Top 25% (Platinum)'
        WHEN 2 THEN 'Top 50% (Gold)'
        WHEN 3 THEN 'Top 75% (Silver)'
        ELSE 'Bottom 25% (Bronze)'
    END AS tier
FROM (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        SUM(oi.quantity * oi.unit_price) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status != 'Cancelled'
    GROUP BY c.customer_id, customer_name
) AS customer_totals
ORDER BY total_spent DESC;

-- WF4: Dense rank books by rating (DENSE_RANK - no gaps after ties)
SELECT
    book_id,
    title,
    avg_rating,
    num_ratings,
    DENSE_RANK() OVER (ORDER BY avg_rating DESC, num_ratings DESC) AS rating_rank
FROM books
WHERE avg_rating IS NOT NULL
  AND num_ratings >= 100
ORDER BY rating_rank
LIMIT 20;


-- -----------------------------------------------------
-- RUNNING TOTALS & CUMULATIVE METRICS
-- -----------------------------------------------------

-- WF5: Running total of daily revenue (SUM OVER with frame)
SELECT
    DATE(o.order_date) AS order_date,
    SUM(oi.quantity * oi.unit_price) AS daily_revenue,
    SUM(SUM(oi.quantity * oi.unit_price)) OVER (
        ORDER BY DATE(o.order_date)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status != 'Cancelled'
GROUP BY DATE(o.order_date)
ORDER BY order_date;

-- WF6: Running count of orders per customer (COUNT OVER)
SELECT
    o.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    o.order_id,
    o.order_date,
    COUNT(*) OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS order_number
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.status != 'Cancelled'
ORDER BY o.customer_id, o.order_date
LIMIT 50;

-- WF7: Cumulative books sold per book (running inventory depletion)
SELECT
    b.book_id,
    b.title,
    o.order_date,
    oi.quantity,
    SUM(oi.quantity) OVER (
        PARTITION BY b.book_id
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sold
FROM books b
JOIN order_items oi ON b.book_id = oi.book_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.status != 'Cancelled'
  AND b.book_id IN (1, 2, 3, 4, 5)  -- Top 5 books for demo
ORDER BY b.book_id, o.order_date;


-- -----------------------------------------------------
-- MOVING AVERAGES & TRENDS
-- -----------------------------------------------------

-- WF8: 7-day moving average of daily orders (AVG OVER with frame)
SELECT
    order_date,
    daily_orders,
    ROUND(AVG(daily_orders) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_7day
FROM (
    SELECT
        DATE(order_date) AS order_date,
        COUNT(*) AS daily_orders
    FROM orders
    WHERE status != 'Cancelled'
    GROUP BY DATE(order_date)
) AS daily
ORDER BY order_date;

-- WF9: 30-day rolling revenue (sum of last 30 days at each point)
SELECT
    order_date,
    daily_revenue,
    ROUND(SUM(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_30day_revenue
FROM (
    SELECT
        DATE(o.order_date) AS order_date,
        SUM(oi.quantity * oi.unit_price) AS daily_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status != 'Cancelled'
    GROUP BY DATE(o.order_date)
) AS daily
ORDER BY order_date;


-- -----------------------------------------------------
-- PERIOD-OVER-PERIOD COMPARISONS (LAG / LEAD)
-- -----------------------------------------------------

-- WF10: Month-over-month revenue growth (LAG for prior period)
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status != 'Cancelled'
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT
    month,
    ROUND(revenue, 2) AS current_revenue,
    ROUND(LAG(revenue) OVER (ORDER BY month), 2) AS previous_month_revenue,
    ROUND(revenue - LAG(revenue) OVER (ORDER BY month), 2) AS revenue_change,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0 /
        NULLIF(LAG(revenue) OVER (ORDER BY month), 0),
    2) AS growth_percentage
FROM monthly_revenue
ORDER BY month;

-- WF11: Compare current order to customer's previous order (LAG)
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    o.order_id,
    o.order_date,
    SUM(oi.quantity * oi.unit_price) AS order_value,
    LAG(o.order_date) OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date
    ) AS previous_order_date,
    LAG(SUM(oi.quantity * oi.unit_price)) OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date
    ) AS previous_order_value,
    DATEDIFF(
        o.order_date,
        LAG(o.order_date) OVER (PARTITION BY o.customer_id ORDER BY o.order_date)
    ) AS days_since_last_order
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status != 'Cancelled'
GROUP BY o.customer_id, c.first_name, c.last_name, o.order_id, o.order_date
ORDER BY o.customer_id, o.order_date
LIMIT 30;

-- WF12: Look ahead to next order (LEAD)
SELECT
    customer_id,
    order_id,
    order_date,
    LEAD(order_date) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS next_order_date,
    LEAD(order_id) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS next_order_id
FROM orders
WHERE status != 'Cancelled'
ORDER BY customer_id, order_date
LIMIT 30;


-- -----------------------------------------------------
-- FIRST & LAST VALUE (boundary analysis)
-- -----------------------------------------------------

-- WF13: Each customer's first and most recent order (FIRST_VALUE & LAST_VALUE)
SELECT DISTINCT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    FIRST_VALUE(o.order_date) OVER (
        PARTITION BY c.customer_id
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS first_order_date,
    LAST_VALUE(o.order_date) OVER (
        PARTITION BY c.customer_id
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS most_recent_order_date,
    DATEDIFF(
        LAST_VALUE(o.order_date) OVER (
            PARTITION BY c.customer_id
            ORDER BY o.order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ),
        FIRST_VALUE(o.order_date) OVER (
            PARTITION BY c.customer_id
            ORDER BY o.order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        )
    ) AS customer_lifetime_days
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status != 'Cancelled'
ORDER BY c.customer_id
LIMIT 20;

-- WF14: Highest and lowest price paid per book across all orders
SELECT DISTINCT
    b.book_id,
    b.title,
    FIRST_VALUE(oi.unit_price) OVER (
        PARTITION BY b.book_id
        ORDER BY oi.unit_price DESC
    ) AS highest_price_sold,
    FIRST_VALUE(oi.unit_price) OVER (
        PARTITION BY b.book_id
        ORDER BY oi.unit_price ASC
    ) AS lowest_price_sold,
    b.price AS current_price
FROM books b
JOIN order_items oi ON b.book_id = oi.book_id
ORDER BY b.book_id
LIMIT 20;


-- -----------------------------------------------------
-- COMPLEX ANALYTICS (combining multiple window functions)
-- -----------------------------------------------------

-- WF15: Customer loyalty analysis - comprehensive window function showcase
WITH customer_metrics AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.quantity * oi.unit_price) AS lifetime_value,
        MIN(o.order_date) AS first_order,
        MAX(o.order_date) AS last_order
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status != 'Cancelled'
    GROUP BY c.customer_id, customer_name
)
SELECT
    customer_id,
    customer_name,
    total_orders,
    ROUND(lifetime_value, 2) AS lifetime_value,
    first_order,
    last_order,
    -- Rank by lifetime value
    RANK() OVER (ORDER BY lifetime_value DESC) AS value_rank,
    -- Percentile by spending
    NTILE(10) OVER (ORDER BY lifetime_value DESC) AS value_decile,
    -- Running total of LTV for top customers
    ROUND(SUM(lifetime_value) OVER (
        ORDER BY lifetime_value DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS cumulative_ltv,
    -- Percent of total revenue
    ROUND(lifetime_value * 100.0 / SUM(lifetime_value) OVER (), 2) AS pct_of_total_revenue
FROM customer_metrics
ORDER BY lifetime_value DESC
LIMIT 20;


SELECT 'All 15 window function queries executed successfully!' AS Status;
