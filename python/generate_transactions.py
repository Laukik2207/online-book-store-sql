"""
Generate Transactional Data
Creates order_items, payments, reviews, and wishlists referencing real book_ids.
Run AFTER load_books_data.py and 03_generate_sample_data.sql (customers + orders).
"""

import random
from db_connection import get_connection, close_connection

# Deterministic output so the dataset is reproducible
random.seed(42)

PAYMENT_METHODS = ['Credit Card', 'Debit Card', 'UPI', 'Net Banking', 'Cash on Delivery']
REVIEW_TEXTS = [
    "Absolutely loved this book, couldn't put it down!",
    "A compelling read with well-developed characters.",
    "Good story but the pacing was a bit slow in the middle.",
    "One of the best books I have read this year.",
    "Interesting premise but the ending felt rushed.",
    "Beautifully written and deeply moving.",
    "Not my cup of tea, but well written nonetheless.",
    "A must-read for fans of the genre.",
    "Engaging from start to finish. Highly recommended.",
    "Decent read, though a bit predictable.",
]


def get_valid_book_ids(cursor, limit=100):
    """Fetch a pool of real book_ids that exist in the books table."""
    cursor.execute("SELECT book_id, price FROM books ORDER BY num_ratings DESC LIMIT %s", (limit,))
    return cursor.fetchall()  # list of (book_id, price)


def generate_order_items(connection):
    """Create 1-4 order items per existing order using real books."""
    cursor = connection.cursor()

    book_pool = get_valid_book_ids(cursor, limit=100)
    if not book_pool:
        print("No books found. Run load_books_data.py first.")
        cursor.close()
        return

    cursor.execute("SELECT order_id FROM orders ORDER BY order_id")
    order_ids = [row[0] for row in cursor.fetchall()]

    items_created = 0
    for order_id in order_ids:
        num_items = random.randint(1, 4)
        chosen = random.sample(book_pool, min(num_items, len(book_pool)))
        for book_id, price in chosen:
            quantity = random.randint(1, 3)
            cursor.execute(
                """INSERT INTO order_items (order_id, book_id, quantity, unit_price)
                   VALUES (%s, %s, %s, %s)""",
                (order_id, book_id, quantity, float(price))
            )
            items_created += 1

    connection.commit()
    print(f"Created {items_created} order items across {len(order_ids)} orders")
    cursor.close()


def generate_payments(connection):
    """Create one payment per order, matching the order total."""
    cursor = connection.cursor()

    # Compute each order's total from its items
    cursor.execute("""
        SELECT o.order_id, o.status, SUM(oi.quantity * oi.unit_price) AS total
        FROM orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        GROUP BY o.order_id, o.status
    """)
    orders = cursor.fetchall()

    payments_created = 0
    for order_id, status, total in orders:
        method = random.choice(PAYMENT_METHODS)
        # Payment status follows order status
        if status in ('Delivered', 'Shipped'):
            pay_status = 'Completed'
        elif status == 'Cancelled':
            pay_status = 'Refunded'
        elif status == 'Processing':
            pay_status = 'Completed'
        else:  # Pending
            pay_status = 'Pending' if method == 'Cash on Delivery' else 'Completed'

        cursor.execute(
            """INSERT INTO payments (order_id, amount, payment_method, payment_status)
               VALUES (%s, %s, %s, %s)""",
            (order_id, float(total), method, pay_status)
        )
        payments_created += 1

    connection.commit()
    print(f"Created {payments_created} payments")
    cursor.close()


def generate_reviews(connection):
    """Create reviews from customers for books (one review per customer-book pair)."""
    cursor = connection.cursor()

    book_pool = [b[0] for b in get_valid_book_ids(cursor, limit=100)]
    cursor.execute("SELECT customer_id FROM customers ORDER BY customer_id")
    customer_ids = [row[0] for row in cursor.fetchall()]

    reviews_created = 0
    for customer_id in customer_ids:
        num_reviews = random.randint(0, 3)
        reviewed_books = random.sample(book_pool, min(num_reviews, len(book_pool)))
        for book_id in reviewed_books:
            rating = random.choices([1, 2, 3, 4, 5], weights=[5, 10, 20, 35, 30])[0]
            review_text = random.choice(REVIEW_TEXTS)
            try:
                cursor.execute(
                    """INSERT INTO reviews (customer_id, book_id, rating, review_text)
                       VALUES (%s, %s, %s, %s)""",
                    (customer_id, book_id, rating, review_text)
                )
                reviews_created += 1
            except Exception:
                pass  # skip duplicate customer-book review

    connection.commit()
    print(f"Created {reviews_created} reviews")
    cursor.close()


def generate_wishlists(connection):
    """Create wishlist entries for customers (one entry per customer-book pair)."""
    cursor = connection.cursor()

    book_pool = [b[0] for b in get_valid_book_ids(cursor, limit=100)]
    cursor.execute("SELECT customer_id FROM customers ORDER BY customer_id")
    customer_ids = [row[0] for row in cursor.fetchall()]

    wishlist_created = 0
    for customer_id in customer_ids:
        num_items = random.randint(0, 5)
        wished_books = random.sample(book_pool, min(num_items, len(book_pool)))
        for book_id in wished_books:
            try:
                cursor.execute(
                    """INSERT INTO wishlists (customer_id, book_id)
                       VALUES (%s, %s)""",
                    (customer_id, book_id)
                )
                wishlist_created += 1
            except Exception:
                pass  # skip duplicate

    connection.commit()
    print(f"Created {wishlist_created} wishlist entries")
    cursor.close()


if __name__ == "__main__":
    print("=" * 60)
    print("GENERATING TRANSACTIONAL DATA")
    print("=" * 60)

    conn = get_connection()
    if conn:
        try:
            generate_order_items(conn)
            generate_payments(conn)
            generate_reviews(conn)
            generate_wishlists(conn)
            print("\nTransactional data generation completed successfully!")
        except Exception as e:
            print(f"\nError: {e}")
            conn.rollback()
        finally:
            close_connection(conn)
    else:
        print("Failed to connect to database")
