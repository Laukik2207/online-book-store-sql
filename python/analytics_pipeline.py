"""
Analytics Pipeline - Online Bookstore
Comprehensive EDA, KPI calculation, and insights generation
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from datetime import datetime
import sys
import warnings
warnings.filterwarnings('ignore')

# Ensure UTF-8 output so currency symbols print correctly on Windows consoles
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

from db_connection import get_connection, close_connection

# Professional color palette (colorblind-safe, validated)
COLORS = {
    'primary': '#0066CC',      # Blue
    'secondary': '#00AA88',    # Teal
    'accent': '#CC6600',       # Orange
    'neutral': '#666666',      # Gray
    'success': '#00AA00',      # Green
    'warning': '#FF9900',      # Amber
    'critical': '#DD3333',     # Red
    'bg': '#FFFFFF',
    'text': '#1A1A1A'
}

# Set clean matplotlib style
plt.style.use('seaborn-v0_8-darkgrid')
plt.rcParams['figure.figsize'] = (12, 7)
plt.rcParams['font.size'] = 11
plt.rcParams['axes.labelsize'] = 12
plt.rcParams['axes.titlesize'] = 14
plt.rcParams['xtick.labelsize'] = 10
plt.rcParams['ytick.labelsize'] = 10
plt.rcParams['legend.fontsize'] = 10
plt.rcParams['figure.titlesize'] = 16


def fetch_data(connection, query):
    """Execute SQL and return DataFrame"""
    return pd.read_sql(query, connection)


def save_chart(fig, filename, dpi=150):
    """Save chart with consistent format"""
    filepath = f'output/charts/{filename}'
    fig.tight_layout()
    fig.savefig(filepath, dpi=dpi, bbox_inches='tight', facecolor='white')
    print(f"  Saved: {filepath}")
    plt.close(fig)


def calculate_kpis(conn):
    """Calculate and return key performance indicators"""
    print("\n=== CALCULATING KPIs ===")

    kpis = {}

    # Business health metrics
    query = """
    SELECT
        (SELECT COUNT(*) FROM books) AS total_books,
        (SELECT COUNT(*) FROM customers) AS total_customers,
        (SELECT COUNT(*) FROM orders WHERE status != 'Cancelled') AS total_orders,
        (SELECT ROUND(SUM(oi.quantity * oi.unit_price), 2)
         FROM orders o JOIN order_items oi ON o.order_id = oi.order_id
         WHERE o.status != 'Cancelled') AS total_revenue,
        (SELECT COUNT(*) FROM reviews) AS total_reviews
    """
    df = fetch_data(conn, query)
    kpis.update(df.iloc[0].to_dict())

    # Customer metrics
    query = """
    SELECT
        ROUND(AVG(lifetime_value), 2) AS avg_customer_ltv,
        ROUND(AVG(total_orders), 2) AS avg_orders_per_customer,
        COUNT(CASE WHEN total_orders > 1 THEN 1 END) * 100.0 / COUNT(*) AS repeat_rate
    FROM vw_customer_metrics
    WHERE total_orders > 0
    """
    df = fetch_data(conn, query)
    kpis.update(df.iloc[0].to_dict())

    # Revenue metrics
    query = """
    SELECT
        ROUND(AVG(order_total), 2) AS avg_order_value,
        ROUND(SUM(order_total) / COUNT(DISTINCT customer_id), 2) AS revenue_per_customer
    FROM (
        SELECT o.customer_id, o.order_id, SUM(oi.quantity * oi.unit_price) AS order_total
        FROM orders o JOIN order_items oi ON o.order_id = oi.order_id
        WHERE o.status != 'Cancelled'
        GROUP BY o.customer_id, o.order_id
    ) t
    """
    df = fetch_data(conn, query)
    kpis.update(df.iloc[0].to_dict())

    # Catalog metrics
    query = """
    SELECT
        ROUND(AVG(price), 2) AS avg_book_price,
        ROUND(AVG(avg_rating), 2) AS avg_book_rating,
        SUM(stock) AS total_inventory_units
    FROM books
    WHERE avg_rating IS NOT NULL
    """
    df = fetch_data(conn, query)
    kpis.update(df.iloc[0].to_dict())

    print(f"  Total Revenue: ₹{kpis['total_revenue']:,.2f}")
    print(f"  Total Orders: {kpis['total_orders']:,}")
    print(f"  Average Order Value: ₹{kpis['avg_order_value']:,.2f}")
    print(f"  Repeat Customer Rate: {kpis['repeat_rate']:.1f}%")

    return kpis


def chart_monthly_revenue(conn):
    """Line chart: Monthly revenue trend"""
    print("\nGenerating: Monthly Revenue Trend")

    query = "SELECT * FROM vw_monthly_revenue ORDER BY month"
    df = fetch_data(conn, query)

    fig, ax = plt.subplots(figsize=(12, 6))
    ax.plot(df['month'], df['total_revenue'], marker='o', linewidth=2.5,
            color=COLORS['primary'], markersize=8, markeredgecolor='white', markeredgewidth=2)

    ax.set_title('Monthly Revenue Trend', fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel('Month', fontsize=12)
    ax.set_ylabel('Revenue (₹)', fontsize=12)
    ax.grid(axis='y', alpha=0.3, linewidth=0.8)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    # Format y-axis as currency
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'₹{x/1000:.0f}K'))
    plt.xticks(rotation=45, ha='right')

    save_chart(fig, '01_monthly_revenue.png')


def chart_top_books(conn):
    """Bar chart: Top 10 books by revenue"""
    print("\nGenerating: Top 10 Books by Revenue")

    query = """
    SELECT title, total_revenue
    FROM vw_popular_books
    WHERE total_revenue > 0
    ORDER BY total_revenue DESC
    LIMIT 10
    """
    df = fetch_data(conn, query)

    fig, ax = plt.subplots(figsize=(12, 7))
    bars = ax.barh(df['title'], df['total_revenue'], color=COLORS['secondary'], edgecolor='white', linewidth=1.5)

    ax.set_title('Top 10 Books by Revenue', fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel('Revenue (₹)', fontsize=12)
    ax.set_ylabel('')
    ax.invert_yaxis()
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(axis='x', alpha=0.3, linewidth=0.8)

    # Add value labels
    for bar in bars:
        width = bar.get_width()
        ax.text(width, bar.get_y() + bar.get_height()/2, f'₹{width:,.0f}',
                ha='left', va='center', fontsize=9, color=COLORS['text'], fontweight='bold')

    save_chart(fig, '02_top_books_revenue.png')


def chart_category_distribution(conn):
    """Pie chart: Top 10 categories by book count"""
    print("\nGenerating: Category Distribution")

    query = """
    SELECT c.category_name, COUNT(bc.book_id) AS book_count
    FROM categories c
    JOIN book_categories bc ON c.category_id = bc.category_id
    GROUP BY c.category_id, c.category_name
    ORDER BY book_count DESC
    LIMIT 10
    """
    df = fetch_data(conn, query)

    fig, ax = plt.subplots(figsize=(10, 10))
    colors = [COLORS['primary'], COLORS['secondary'], COLORS['accent'],
              '#4477AA', '#66CCEE', '#228833', '#CCBB44', '#EE6677', '#AA3377', '#BBBBBB']

    wedges, texts, autotexts = ax.pie(df['book_count'], labels=df['category_name'],
                                        autopct='%1.1f%%', startangle=90, colors=colors,
                                        textprops={'fontsize': 10})

    # Make percentage text bold
    for autotext in autotexts:
        autotext.set_color('white')
        autotext.set_fontweight('bold')
        autotext.set_fontsize(10)

    ax.set_title('Top 10 Categories by Book Count', fontsize=16, fontweight='bold', pad=20)

    save_chart(fig, '03_category_distribution.png')


def chart_customer_segmentation(conn):
    """Bar chart: Customer spending tiers"""
    print("\nGenerating: Customer Segmentation by Spending")

    query = """
    SELECT
        CASE
            WHEN SUM(oi.quantity * oi.unit_price) >= 10000 THEN 'High Value (₹10K+)'
            WHEN SUM(oi.quantity * oi.unit_price) >= 5000 THEN 'Medium Value (₹5-10K)'
            ELSE 'Low Value (<₹5K)'
        END AS spending_tier,
        COUNT(DISTINCT c.customer_id) AS customer_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status != 'Cancelled'
    GROUP BY c.customer_id
    """
    df = fetch_data(conn, query)
    df = df.groupby('spending_tier')['customer_count'].sum().reset_index()
    df = df.sort_values('customer_count', ascending=False)

    fig, ax = plt.subplots(figsize=(10, 6))
    bars = ax.bar(df['spending_tier'], df['customer_count'],
                   color=[COLORS['success'], COLORS['warning'], COLORS['accent']],
                   edgecolor='white', linewidth=2)

    ax.set_title('Customer Segmentation by Spending', fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel('Spending Tier', fontsize=12)
    ax.set_ylabel('Number of Customers', fontsize=12)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(axis='y', alpha=0.3, linewidth=0.8)

    # Add value labels
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2, height, f'{int(height)}',
                ha='center', va='bottom', fontsize=11, fontweight='bold')

    save_chart(fig, '04_customer_segmentation.png')


def chart_order_status(conn):
    """Donut chart: Order status distribution"""
    print("\nGenerating: Order Status Distribution")

    query = """
    SELECT status, COUNT(*) AS order_count
    FROM orders
    GROUP BY status
    ORDER BY order_count DESC
    """
    df = fetch_data(conn, query)

    fig, ax = plt.subplots(figsize=(10, 8))
    colors_map = {
        'Delivered': COLORS['success'],
        'Shipped': COLORS['primary'],
        'Processing': COLORS['warning'],
        'Pending': COLORS['accent'],
        'Cancelled': COLORS['critical']
    }
    colors = [colors_map.get(status, COLORS['neutral']) for status in df['status']]

    wedges, texts, autotexts = ax.pie(df['order_count'], labels=df['status'],
                                        autopct='%1.1f%%', startangle=90, colors=colors,
                                        pctdistance=0.85, textprops={'fontsize': 11})

    # Draw circle for donut
    centre_circle = plt.Circle((0, 0), 0.70, fc='white')
    ax.add_artist(centre_circle)

    for autotext in autotexts:
        autotext.set_color('white')
        autotext.set_fontweight('bold')
        autotext.set_fontsize(11)

    ax.set_title('Order Status Distribution', fontsize=16, fontweight='bold', pad=20)

    save_chart(fig, '05_order_status.png')


def chart_payment_methods(conn):
    """Bar chart: Payment method popularity"""
    print("\nGenerating: Payment Method Distribution")

    query = """
    SELECT payment_method, COUNT(*) AS count, ROUND(SUM(amount), 2) AS total_amount
    FROM payments
    WHERE payment_status = 'Completed'
    GROUP BY payment_method
    ORDER BY count DESC
    """
    df = fetch_data(conn, query)

    fig, ax = plt.subplots(figsize=(10, 6))
    bars = ax.bar(df['payment_method'], df['count'], color=COLORS['primary'],
                   edgecolor='white', linewidth=2)

    ax.set_title('Payment Method Distribution', fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel('Payment Method', fontsize=12)
    ax.set_ylabel('Transaction Count', fontsize=12)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(axis='y', alpha=0.3, linewidth=0.8)
    plt.xticks(rotation=15, ha='right')

    # Add value labels
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2, height, f'{int(height)}',
                ha='center', va='bottom', fontsize=10, fontweight='bold')

    save_chart(fig, '06_payment_methods.png')


def generate_kpi_dashboard(kpis):
    """Create a visual KPI dashboard"""
    print("\nGenerating: KPI Dashboard")

    fig = plt.figure(figsize=(14, 10))
    fig.suptitle('Online Bookstore - Key Performance Indicators', fontsize=20, fontweight='bold', y=0.98)

    # Define KPI tiles
    tiles = [
        ('Total Revenue', f"₹{kpis['total_revenue']:,.2f}", COLORS['success']),
        ('Total Orders', f"{int(kpis['total_orders']):,}", COLORS['primary']),
        ('Avg Order Value', f"₹{kpis['avg_order_value']:,.2f}", COLORS['accent']),
        ('Total Customers', f"{int(kpis['total_customers']):,}", COLORS['secondary']),
        ('Avg Customer LTV', f"₹{kpis['avg_customer_ltv']:,.2f}", COLORS['warning']),
        ('Repeat Rate', f"{kpis['repeat_rate']:.1f}%", COLORS['success']),
        ('Total Books', f"{int(kpis['total_books']):,}", COLORS['neutral']),
        ('Avg Book Price', f"₹{kpis['avg_book_price']:,.2f}", COLORS['accent']),
        ('Avg Rating', f"{kpis['avg_book_rating']:.2f} / 5.0", COLORS['primary']),
        ('Total Reviews', f"{int(kpis['total_reviews']):,}", COLORS['secondary']),
        ('Inventory Units', f"{int(kpis['total_inventory_units']):,}", COLORS['neutral']),
        ('Revenue/Customer', f"₹{kpis['revenue_per_customer']:,.2f}", COLORS['warning'])
    ]

    # Create 3x4 grid
    for idx, (label, value, color) in enumerate(tiles):
        ax = fig.add_subplot(3, 4, idx + 1)
        ax.axis('off')

        # Draw colored background box
        rect = mpatches.FancyBboxPatch((0.05, 0.2), 0.9, 0.6, boxstyle="round,pad=0.05",
                                        edgecolor=color, facecolor=color, alpha=0.15, linewidth=3)
        ax.add_patch(rect)

        # Add text
        ax.text(0.5, 0.65, value, ha='center', va='center',
                fontsize=20, fontweight='bold', color=color)
        ax.text(0.5, 0.35, label, ha='center', va='center',
                fontsize=12, color=COLORS['text'], wrap=True)

        ax.set_xlim(0, 1)
        ax.set_ylim(0, 1)

    save_chart(fig, '00_kpi_dashboard.png', dpi=120)


if __name__ == "__main__":
    print("=" * 60)
    print("ONLINE BOOKSTORE ANALYTICS PIPELINE")
    print("=" * 60)

    conn = get_connection()

    if conn:
        try:
            # Calculate KPIs
            kpis = calculate_kpis(conn)

            # Export KPIs to CSV for reporting
            kpi_df = pd.DataFrame([
                {'kpi': k, 'value': v} for k, v in kpis.items()
            ])
            kpi_df.to_csv('output/results/kpi_summary.csv', index=False)
            print("\n  Saved: output/results/kpi_summary.csv")

            # Generate charts
            print("\n=== GENERATING VISUALIZATIONS ===")
            generate_kpi_dashboard(kpis)
            chart_monthly_revenue(conn)
            chart_top_books(conn)
            chart_category_distribution(conn)
            chart_customer_segmentation(conn)
            chart_order_status(conn)
            chart_payment_methods(conn)

            print("\n✓ Analytics pipeline completed successfully!")
            print(f"  All charts saved to: output/charts/")

        except Exception as e:
            print(f"\n✗ Error: {e}")
            import traceback
            traceback.print_exc()

        finally:
            close_connection(conn)
    else:
        print("Failed to connect to database")
