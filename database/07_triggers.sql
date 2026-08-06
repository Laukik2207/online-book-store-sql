-- =====================================================
-- TRIGGERS
-- Online Bookstore Database
-- =====================================================
-- Triggers automate actions in response to data changes.
-- We also create an audit/log table that some triggers write to.

USE online_book_store;

-- =====================================================
-- SUPPORTING TABLE: Stock Audit Log
-- =====================================================
-- Records every stock change for traceability

CREATE TABLE IF NOT EXISTS stock_audit_log (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    old_stock INT,
    new_stock INT,
    change_amount INT,
    change_reason VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

-- =====================================================
-- SUPPORTING TABLE: Order Audit Log
-- =====================================================
-- Records order status changes over time

CREATE TABLE IF NOT EXISTS order_status_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);


DELIMITER $$

-- =====================================================
-- TRIGGER 1: Auto-decrement stock on new order item
-- =====================================================
-- When a book is added to an order, automatically reduce its stock
-- and log the change. Demonstrates: AFTER INSERT automation.

DROP TRIGGER IF EXISTS trg_reduce_stock_on_order$$

CREATE TRIGGER trg_reduce_stock_on_order
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    DECLARE v_old_stock INT;

    -- Get current stock
    SELECT stock INTO v_old_stock
    FROM books
    WHERE book_id = NEW.book_id;

    -- Reduce stock by ordered quantity
    UPDATE books
    SET stock = stock - NEW.quantity
    WHERE book_id = NEW.book_id;

    -- Log the stock change
    INSERT INTO stock_audit_log (book_id, old_stock, new_stock, change_amount, change_reason)
    VALUES (NEW.book_id, v_old_stock, v_old_stock - NEW.quantity,
            -NEW.quantity, CONCAT('Order item added (order_id: ', NEW.order_id, ')'));
END$$


-- =====================================================
-- TRIGGER 2: Prevent overselling (stock cannot go negative)
-- =====================================================
-- Before inserting an order item, verify sufficient stock exists.
-- Demonstrates: BEFORE INSERT validation with SIGNAL.

DROP TRIGGER IF EXISTS trg_prevent_overselling$$

CREATE TRIGGER trg_prevent_overselling
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
    DECLARE v_available_stock INT;

    SELECT stock INTO v_available_stock
    FROM books
    WHERE book_id = NEW.book_id;

    IF v_available_stock < NEW.quantity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Insufficient stock: cannot fulfill requested quantity';
    END IF;
END$$


-- =====================================================
-- TRIGGER 3: Log order status changes
-- =====================================================
-- When an order's status changes, record it in the audit log.
-- Demonstrates: AFTER UPDATE with OLD vs NEW comparison.

DROP TRIGGER IF EXISTS trg_log_order_status$$

CREATE TRIGGER trg_log_order_status
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    -- Only log if status actually changed
    IF OLD.status != NEW.status THEN
        INSERT INTO order_status_log (order_id, old_status, new_status)
        VALUES (NEW.order_id, OLD.status, NEW.status);
    END IF;
END$$


-- =====================================================
-- TRIGGER 4: Auto-update book rating after new review
-- =====================================================
-- When a review is added, recalculate the book's average rating
-- and review count. Demonstrates: AFTER INSERT with aggregation.

DROP TRIGGER IF EXISTS trg_update_rating_on_review$$

CREATE TRIGGER trg_update_rating_on_review
AFTER INSERT ON reviews
FOR EACH ROW
BEGIN
    DECLARE v_avg_rating DECIMAL(3,2);
    DECLARE v_review_count INT;

    -- Recalculate average rating and review count
    SELECT AVG(rating), COUNT(*)
    INTO v_avg_rating, v_review_count
    FROM reviews
    WHERE book_id = NEW.book_id;

    -- Update the book
    UPDATE books
    SET avg_rating = v_avg_rating,
        num_reviews = v_review_count
    WHERE book_id = NEW.book_id;
END$$


-- =====================================================
-- TRIGGER 5: Restore stock when order item is deleted
-- =====================================================
-- If an order item is removed, put the stock back and log it.
-- Demonstrates: AFTER DELETE automation.

DROP TRIGGER IF EXISTS trg_restore_stock_on_delete$$

CREATE TRIGGER trg_restore_stock_on_delete
AFTER DELETE ON order_items
FOR EACH ROW
BEGIN
    DECLARE v_old_stock INT;

    SELECT stock INTO v_old_stock
    FROM books
    WHERE book_id = OLD.book_id;

    -- Restore the stock
    UPDATE books
    SET stock = stock + OLD.quantity
    WHERE book_id = OLD.book_id;

    -- Log the restoration
    INSERT INTO stock_audit_log (book_id, old_stock, new_stock, change_amount, change_reason)
    VALUES (OLD.book_id, v_old_stock, v_old_stock + OLD.quantity,
            OLD.quantity, CONCAT('Order item removed (order_id: ', OLD.order_id, ')'));
END$$

DELIMITER ;


-- =====================================================
-- TEST THE TRIGGERS
-- =====================================================

-- Test Trigger 1 & 2: Stock reduction and overselling prevention
-- First, check current stock of a book
SELECT book_id, title, stock FROM books WHERE book_id = 5;

-- This will reduce stock (trigger 1 fires, trigger 2 validates)
-- INSERT INTO order_items (order_id, book_id, quantity, unit_price)
-- VALUES (1, 5, 2, 350.00);

-- Check stock after (should be reduced by 2)
-- SELECT book_id, title, stock FROM books WHERE book_id = 5;

-- Check the audit log
-- SELECT * FROM stock_audit_log ORDER BY audit_id DESC LIMIT 5;

-- Test Trigger 3: Order status logging
-- UPDATE orders SET status = 'Shipped' WHERE order_id = 1;
-- SELECT * FROM order_status_log ORDER BY log_id DESC LIMIT 5;


SELECT 'All 5 triggers created successfully!' AS Status;
