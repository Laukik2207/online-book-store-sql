-- =====================================================
-- STORED PROCEDURES
-- Online Bookstore Database
-- =====================================================
-- Procedures encapsulate multi-step business logic with parameters

USE online_book_store;

DELIMITER $$

-- =====================================================
-- PROCEDURE 1: Place New Order
-- =====================================================
-- Places a complete order with multiple books, calculates total,
-- creates payment record, and updates stock levels
-- Demonstrates: transactions, error handling, cursor, calculations

DROP PROCEDURE IF EXISTS sp_place_order$$

CREATE PROCEDURE sp_place_order(
    IN p_customer_id INT,
    IN p_book_ids VARCHAR(500),      -- Comma-separated book IDs: "1,5,12"
    IN p_quantities VARCHAR(500),     -- Comma-separated quantities: "2,1,3"
    IN p_payment_method VARCHAR(50),
    OUT p_order_id INT,
    OUT p_total_amount DECIMAL(10,2),
    OUT p_message VARCHAR(255)
)
proc_place: BEGIN
    DECLARE v_book_id INT;
    DECLARE v_quantity INT;
    DECLARE v_price DECIMAL(8,2);
    DECLARE v_stock INT;
    DECLARE v_book_idx INT DEFAULT 1;
    DECLARE v_book_count INT;
    DECLARE v_item_total DECIMAL(10,2);
    DECLARE v_error_occurred BOOLEAN DEFAULT FALSE;

    -- Declare handler for any SQL exception
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Error occurred during order processing';
        SET p_order_id = NULL;
        SET p_total_amount = 0;
    END;

    -- Start transaction
    START TRANSACTION;

    -- Validate customer exists
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = p_customer_id) THEN
        SET p_message = 'Customer not found';
        SET p_order_id = NULL;
        SET p_total_amount = 0;
        ROLLBACK;
        LEAVE proc_place;
    END IF;

    -- Create the order
    INSERT INTO orders (customer_id, order_date, status)
    VALUES (p_customer_id, NOW(), 'Pending');

    SET p_order_id = LAST_INSERT_ID();
    SET p_total_amount = 0;

    -- Count how many books are being ordered
    SET v_book_count = (LENGTH(p_book_ids) - LENGTH(REPLACE(p_book_ids, ',', '')) + 1);

    -- Process each book
    WHILE v_book_idx <= v_book_count DO
        -- Extract book_id and quantity
        SET v_book_id = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(p_book_ids, ',', v_book_idx), ',', -1) AS UNSIGNED);
        SET v_quantity = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(p_quantities, ',', v_book_idx), ',', -1) AS UNSIGNED);

        -- Validate book exists and has sufficient stock
        SELECT price, stock INTO v_price, v_stock
        FROM books
        WHERE book_id = v_book_id;

        IF v_price IS NULL THEN
            SET p_message = CONCAT('Book ID ', v_book_id, ' not found');
            ROLLBACK;
            LEAVE proc_place;
        END IF;

        IF v_stock < v_quantity THEN
            SET p_message = CONCAT('Insufficient stock for book ID ', v_book_id);
            ROLLBACK;
            LEAVE proc_place;
        END IF;

        -- Insert order item
        -- NOTE: stock validation and decrement are handled automatically by
        -- triggers trg_prevent_overselling (BEFORE INSERT) and
        -- trg_reduce_stock_on_order (AFTER INSERT). We deliberately do NOT
        -- decrement stock here to avoid double-counting.
        INSERT INTO order_items (order_id, book_id, quantity, unit_price)
        VALUES (p_order_id, v_book_id, v_quantity, v_price);

        -- Add to total
        SET v_item_total = v_price * v_quantity;
        SET p_total_amount = p_total_amount + v_item_total;

        SET v_book_idx = v_book_idx + 1;
    END WHILE;

    -- Create payment record
    INSERT INTO payments (order_id, amount, payment_method, payment_status)
    VALUES (p_order_id, p_total_amount, p_payment_method,
            CASE WHEN p_payment_method = 'Cash on Delivery' THEN 'Pending' ELSE 'Completed' END);

    -- Update order status
    UPDATE orders
    SET status = 'Processing'
    WHERE order_id = p_order_id;

    COMMIT;
    SET p_message = 'Order placed successfully';

END$$


-- =====================================================
-- PROCEDURE 2: Calculate Customer Loyalty Tier
-- =====================================================
-- Assigns loyalty tier based on lifetime spending
-- Demonstrates: business logic, CASE statements, calculations

DROP PROCEDURE IF EXISTS sp_calculate_loyalty_tier$$

CREATE PROCEDURE sp_calculate_loyalty_tier(
    IN p_customer_id INT,
    OUT p_loyalty_tier VARCHAR(20),
    OUT p_lifetime_value DECIMAL(10,2),
    OUT p_discount_percentage DECIMAL(5,2),
    OUT p_message VARCHAR(255)
)
BEGIN
    -- Calculate lifetime value
    SELECT COALESCE(SUM(oi.quantity * oi.unit_price), 0)
    INTO p_lifetime_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = p_customer_id
      AND o.status != 'Cancelled';

    -- Assign tier based on spending
    SET p_loyalty_tier = CASE
        WHEN p_lifetime_value >= 50000 THEN 'Platinum'
        WHEN p_lifetime_value >= 25000 THEN 'Gold'
        WHEN p_lifetime_value >= 10000 THEN 'Silver'
        WHEN p_lifetime_value >= 5000 THEN 'Bronze'
        ELSE 'Regular'
    END;

    -- Assign discount based on tier
    SET p_discount_percentage = CASE p_loyalty_tier
        WHEN 'Platinum' THEN 20.00
        WHEN 'Gold' THEN 15.00
        WHEN 'Silver' THEN 10.00
        WHEN 'Bronze' THEN 5.00
        ELSE 0.00
    END;

    SET p_message = CONCAT('Customer tier: ', p_loyalty_tier,
                          ' with ', p_discount_percentage, '% discount');
END$$


-- =====================================================
-- PROCEDURE 3: Generate Monthly Sales Report
-- =====================================================
-- Generates comprehensive sales statistics for a given month
-- Demonstrates: aggregations, date functions, multiple outputs

DROP PROCEDURE IF EXISTS sp_monthly_sales_report$$

CREATE PROCEDURE sp_monthly_sales_report(
    IN p_year INT,
    IN p_month INT,
    OUT p_total_orders INT,
    OUT p_total_revenue DECIMAL(10,2),
    OUT p_avg_order_value DECIMAL(10,2),
    OUT p_unique_customers INT,
    OUT p_books_sold INT
)
BEGIN
    SELECT
        COUNT(DISTINCT o.order_id),
        COALESCE(SUM(oi.quantity * oi.unit_price), 0),
        COALESCE(AVG(oi.quantity * oi.unit_price), 0),
        COUNT(DISTINCT o.customer_id),
        COALESCE(SUM(oi.quantity), 0)
    INTO
        p_total_orders,
        p_total_revenue,
        p_avg_order_value,
        p_unique_customers,
        p_books_sold
    FROM orders o
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    WHERE YEAR(o.order_date) = p_year
      AND MONTH(o.order_date) = p_month
      AND o.status != 'Cancelled';
END$$


-- =====================================================
-- PROCEDURE 4: Update Book Ratings
-- =====================================================
-- Recalculates average rating for a book based on all reviews
-- Demonstrates: aggregation, UPDATE based on calculation

DROP PROCEDURE IF EXISTS sp_update_book_rating$$

CREATE PROCEDURE sp_update_book_rating(
    IN p_book_id INT,
    OUT p_old_rating DECIMAL(3,2),
    OUT p_new_rating DECIMAL(3,2),
    OUT p_review_count INT
)
BEGIN
    -- Get old rating
    SELECT avg_rating INTO p_old_rating
    FROM books
    WHERE book_id = p_book_id;

    -- Calculate new rating from reviews
    SELECT
        COALESCE(AVG(rating), 0),
        COUNT(*)
    INTO p_new_rating, p_review_count
    FROM reviews
    WHERE book_id = p_book_id;

    -- Update the book
    UPDATE books
    SET avg_rating = p_new_rating,
        num_reviews = p_review_count
    WHERE book_id = p_book_id;
END$$


-- =====================================================
-- PROCEDURE 5: Process Book Return
-- =====================================================
-- Handles book return: updates stock, refunds payment, changes status
-- Demonstrates: complex transaction with multiple table updates

DROP PROCEDURE IF EXISTS sp_process_return$$

CREATE PROCEDURE sp_process_return(
    IN p_order_id INT,
    OUT p_refund_amount DECIMAL(10,2),
    OUT p_message VARCHAR(255)
)
proc_return: BEGIN
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_payment_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Error processing return';
        SET p_refund_amount = 0;
    END;

    START TRANSACTION;

    -- Validate order exists and is eligible for return
    SELECT status INTO v_order_status
    FROM orders
    WHERE order_id = p_order_id;

    IF v_order_status IS NULL THEN
        SET p_message = 'Order not found';
        SET p_refund_amount = 0;
        ROLLBACK;
        LEAVE proc_return;
    END IF;

    IF v_order_status NOT IN ('Delivered', 'Shipped') THEN
        SET p_message = 'Order not eligible for return';
        SET p_refund_amount = 0;
        ROLLBACK;
        LEAVE proc_return;
    END IF;

    -- Calculate refund amount
    SELECT SUM(quantity * unit_price) INTO p_refund_amount
    FROM order_items
    WHERE order_id = p_order_id;

    -- Restore stock for all books in the order
    UPDATE books b
    JOIN order_items oi ON b.book_id = oi.book_id
    SET b.stock = b.stock + oi.quantity
    WHERE oi.order_id = p_order_id;

    -- Update order status
    UPDATE orders
    SET status = 'Cancelled'
    WHERE order_id = p_order_id;

    -- Update payment status
    UPDATE payments
    SET payment_status = 'Refunded'
    WHERE order_id = p_order_id;

    COMMIT;
    SET p_message = CONCAT('Return processed successfully. Refund: ₹', p_refund_amount);
END$$

DELIMITER ;


-- =====================================================
-- TEST THE PROCEDURES
-- =====================================================

-- Test 1: Place an order
CALL sp_place_order(1, '1,2,3', '2,1,1', 'Credit Card', @order_id, @total, @msg);
SELECT @order_id AS OrderID, @total AS Total, @msg AS Message;

-- Test 2: Calculate loyalty tier
CALL sp_calculate_loyalty_tier(1, @tier, @ltv, @discount, @msg);
SELECT @tier AS Tier, @ltv AS LifetimeValue, @discount AS Discount, @msg AS Message;

-- Test 3: Monthly sales report
CALL sp_monthly_sales_report(2024, 7, @orders, @revenue, @avg, @customers, @books);
SELECT @orders AS TotalOrders, @revenue AS Revenue, @avg AS AvgOrderValue,
       @customers AS UniqueCustomers, @books AS BooksSold;

-- Test 4: Update book rating
CALL sp_update_book_rating(1, @old, @new, @count);
SELECT @old AS OldRating, @new AS NewRating, @count AS ReviewCount;


SELECT 'All 5 stored procedures created successfully!' AS Status;
