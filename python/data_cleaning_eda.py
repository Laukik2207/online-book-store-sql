"""
Data Cleaning & Exploratory Data Analysis (EDA)
Extracts data from MySQL, performs cleaning/validation, exports cleaned CSVs,
and prints EDA findings. This is the data-preparation stage of the pipeline.
"""

import pandas as pd
import numpy as np
import sys
import warnings
warnings.filterwarnings('ignore')

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

from db_connection import get_connection, close_connection


def extract_books(conn):
    """Pull the full book catalog into a DataFrame."""
    query = """
        SELECT book_id, title, language, num_pages, publish_date,
               avg_rating, num_ratings, num_reviews, price, stock
        FROM books
    """
    return pd.read_sql(query, conn)


def extract_sales(conn):
    """Pull order-line-level sales data (one row per book per order)."""
    query = """
        SELECT o.order_id, o.customer_id, o.order_date, o.status,
               oi.book_id, oi.quantity, oi.unit_price,
               (oi.quantity * oi.unit_price) AS line_total
        FROM orders o
        JOIN order_items oi ON o.order_id = oi.order_id
    """
    return pd.read_sql(query, conn)


def clean_books(df):
    """Clean and validate the books DataFrame."""
    print("\n=== CLEANING: books ===")
    print(f"  Rows before: {len(df)}")

    # 1. Missing values report
    print("  Missing values per column:")
    for col, n in df.isnull().sum().items():
        if n > 0:
            print(f"    {col}: {n}")

    # 2. Duplicates
    dupes = df.duplicated(subset=['book_id']).sum()
    print(f"  Duplicate book_ids: {dupes}")
    df = df.drop_duplicates(subset=['book_id'])

    # 3. Type correctness
    df['publish_date'] = pd.to_datetime(df['publish_date'], errors='coerce')
    df['price'] = pd.to_numeric(df['price'], errors='coerce')

    # 4. Validation: no negative prices / pages, ratings within 0-5
    df = df[df['price'] > 0]
    df.loc[df['num_pages'] < 0, 'num_pages'] = np.nan
    df.loc[(df['avg_rating'] < 0) | (df['avg_rating'] > 5), 'avg_rating'] = np.nan

    # 5. Feature engineering: price band + publish decade
    df['price_band'] = pd.cut(
        df['price'], bins=[0, 300, 500, 700, np.inf],
        labels=['Budget (<300)', 'Mid (300-500)', 'Premium (500-700)', 'Luxury (700+)']
    )
    df['publish_decade'] = (df['publish_date'].dt.year // 10 * 10)

    print(f"  Rows after: {len(df)}")
    return df


def clean_sales(df):
    """Clean and validate the sales DataFrame."""
    print("\n=== CLEANING: sales ===")
    print(f"  Rows before: {len(df)}")

    df['order_date'] = pd.to_datetime(df['order_date'], errors='coerce')

    # Exclude cancelled orders from revenue analysis
    df = df[df['status'] != 'Cancelled']

    # Validation: quantity and price must be positive
    df = df[(df['quantity'] > 0) & (df['unit_price'] > 0)]

    # Feature engineering: order month for trend analysis
    df['order_month'] = df['order_date'].dt.to_period('M').astype(str)

    print(f"  Rows after (excl. cancelled): {len(df)}")
    return df


def run_eda(books, sales):
    """Print exploratory data analysis findings."""
    print("\n" + "=" * 50)
    print("EXPLORATORY DATA ANALYSIS")
    print("=" * 50)

    print("\n--- BOOKS: shape & summary ---")
    print(f"  Catalog size: {len(books)} books")
    print(f"  Price range: ₹{books['price'].min():.2f} - ₹{books['price'].max():.2f}")
    print(f"  Avg price: ₹{books['price'].mean():.2f} | Median: ₹{books['price'].median():.2f}")
    print(f"  Avg rating: {books['avg_rating'].mean():.2f} / 5.0")
    print(f"  Total inventory units: {int(books['stock'].sum()):,}")

    print("\n--- BOOKS: price band distribution ---")
    print(books['price_band'].value_counts().to_string())

    print("\n--- SALES: summary ---")
    print(f"  Order lines: {len(sales)}")
    print(f"  Total revenue: ₹{sales['line_total'].sum():,.2f}")
    print(f"  Avg line value: ₹{sales['line_total'].mean():.2f}")
    print(f"  Books sold (units): {int(sales['quantity'].sum()):,}")

    print("\n--- SALES: monthly revenue ---")
    monthly = sales.groupby('order_month')['line_total'].sum().round(2)
    print(monthly.to_string())

    print("\n--- SALES: status distribution ---")
    print(sales['status'].value_counts().to_string())


def export_cleaned(books, sales):
    """Save cleaned DataFrames to CSV for reporting/backup."""
    books.to_csv('data/cleaned/books_cleaned.csv', index=False)
    sales.to_csv('data/cleaned/sales_cleaned.csv', index=False)
    print("\n  Exported: data/cleaned/books_cleaned.csv")
    print("  Exported: data/cleaned/sales_cleaned.csv")


if __name__ == "__main__":
    print("=" * 60)
    print("DATA CLEANING & EDA PIPELINE")
    print("=" * 60)

    conn = get_connection()
    if conn:
        try:
            books_raw = extract_books(conn)
            sales_raw = extract_sales(conn)

            books = clean_books(books_raw)
            sales = clean_sales(sales_raw)

            run_eda(books, sales)
            export_cleaned(books, sales)

            print("\n✓ Data cleaning & EDA completed successfully!")
        except Exception as e:
            print(f"\n✗ Error: {e}")
            import traceback
            traceback.print_exc()
        finally:
            close_connection(conn)
    else:
        print("Failed to connect to database")
