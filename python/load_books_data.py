"""
ETL Script: Load Books Data from CSV
Parses the Goodreads CSV and loads books, authors, and genres into the normalized schema
"""

import pandas as pd
import mysql.connector
from mysql.connector import Error
import re
from datetime import datetime
from db_connection import get_connection, close_connection


def clean_text(text):
    """Clean text data by removing extra whitespace and handling nulls"""
    if pd.isna(text) or text == '' or text == 'null':
        return None
    return str(text).strip()


def parse_author_list(author_str):
    """Parse comma-separated author names into a list"""
    if pd.isna(author_str) or author_str == '':
        return []
    # Split by comma and clean each name
    authors = [a.strip() for a in str(author_str).split(',')]
    return [a for a in authors if a and a != ''][:3]  # Take first 3 authors


def parse_genre_list(genre_str):
    """Parse comma-separated genres into a list (take first 5 genres)

    The Goodreads CSV has a known corruption: the genres column contains
    a full alphabetical dump of all genres (repeated twice) before the
    actual book-specific genres. We skip the prefix and extract real genres.
    """
    if pd.isna(genre_str) or genre_str == '':
        return []

    # Split by comma and clean
    all_tokens = [g.strip() for g in str(genre_str).split(',')]

    # The corrupted prefix is 29 genres repeated twice = 58 tokens
    # Real genres start after that. Skip the prefix:
    CORRUPTED_PREFIX_LENGTH = 58
    if len(all_tokens) > CORRUPTED_PREFIX_LENGTH:
        real_genres = all_tokens[CORRUPTED_PREFIX_LENGTH:]
    else:
        # If shorter than expected, fall back to the whole list
        real_genres = all_tokens

    # Take only first 5 unique real genres
    unique_genres = []
    seen = set()
    for g in real_genres:
        if g and g != '' and g not in seen:
            unique_genres.append(g)
            seen.add(g)
            if len(unique_genres) >= 5:
                break

    return unique_genres


def parse_date(date_str):
    """Parse date strings into MySQL DATE format"""
    if pd.isna(date_str) or date_str == '':
        return None

    try:
        # Handle various date formats from Goodreads
        date_str = str(date_str).strip()

        # Try common patterns
        patterns = [
            r'(\w+)\s+(\d{1,2})(?:st|nd|rd|th)?\s+(\d{4})',  # "September 16th 2006"
            r'(\w+)\s+(\d{4})',  # "September 2004"
            r'(\d{4})',  # Just year "2004"
        ]

        for pattern in patterns:
            match = re.search(pattern, date_str)
            if match:
                groups = match.groups()
                if len(groups) == 3:
                    month_str, day, year = groups
                    month_num = datetime.strptime(month_str, '%B').month
                    return f"{year}-{month_num:02d}-{int(day):02d}"
                elif len(groups) == 2:
                    month_str, year = groups
                    month_num = datetime.strptime(month_str, '%B').month
                    return f"{year}-{month_num:02d}-01"
                elif len(groups) == 1:
                    year = groups[0]
                    return f"{year}-01-01"

        return None
    except:
        return None


def generate_price(avg_rating, num_pages):
    """Generate realistic book prices based on rating and pages"""
    base_price = 299.00  # Base price in INR

    # Adjust for rating
    if pd.notna(avg_rating) and avg_rating > 0:
        rating_factor = (avg_rating / 5.0) * 200
    else:
        rating_factor = 0

    # Adjust for page count
    if pd.notna(num_pages) and num_pages > 0:
        page_factor = min(num_pages / 10, 300)
    else:
        page_factor = 100

    price = base_price + rating_factor + page_factor
    return round(price, 2)


def generate_stock(num_ratings):
    """Generate stock levels based on popularity"""
    if pd.isna(num_ratings) or num_ratings == 0:
        return 5
    elif num_ratings < 1000:
        return 10
    elif num_ratings < 10000:
        return 25
    elif num_ratings < 100000:
        return 50
    else:
        return 100


def load_books_from_csv(csv_path, connection, limit=2000):
    """
    Main ETL function to load books from CSV into MySQL

    Args:
        csv_path: Path to Goodreads CSV file
        connection: MySQL connection object
        limit: Number of books to load (default 2000 for reasonable demo)
    """
    cursor = connection.cursor()

    print(f"Reading CSV file: {csv_path}")
    # Read CSV with proper handling for complex data
    df = pd.read_csv(csv_path, nrows=limit)
    print(f"Loaded {len(df)} books from CSV")

    # Track statistics
    books_loaded = 0
    authors_added = 0
    genres_added = 0

    # Cache for authors and genres to avoid duplicates
    author_cache = {}
    genre_cache = {}

    try:
        # Step 1: Load unique authors
        print("\nStep 1: Loading authors...")
        all_authors = set()
        for idx, row in df.iterrows():
            authors = parse_author_list(row['author'])
            all_authors.update(authors)

        for author_name in all_authors:
            if author_name:
                try:
                    cursor.execute(
                        "INSERT INTO authors (author_name) VALUES (%s)",
                        (author_name,)
                    )
                    author_id = cursor.lastrowid
                    author_cache[author_name] = author_id
                    authors_added += 1
                except mysql.connector.IntegrityError:
                    # Author already exists, fetch ID
                    cursor.execute("SELECT author_id FROM authors WHERE author_name = %s", (author_name,))
                    result = cursor.fetchone()
                    if result:
                        author_cache[author_name] = result[0]

        connection.commit()
        print(f"Loaded {authors_added} unique authors")

        # Step 2: Load unique genres
        print("\nStep 2: Loading genres...")
        all_genres = set()
        for idx, row in df.iterrows():
            genres = parse_genre_list(row['genres'])
            all_genres.update(genres)

        for genre_name in all_genres:
            if genre_name:
                try:
                    cursor.execute(
                        "INSERT INTO categories (category_name) VALUES (%s)",
                        (genre_name,)
                    )
                    genre_id = cursor.lastrowid
                    genre_cache[genre_name] = genre_id
                    genres_added += 1
                except mysql.connector.IntegrityError:
                    # Genre already exists, fetch ID
                    cursor.execute("SELECT category_id FROM categories WHERE category_name = %s", (genre_name,))
                    result = cursor.fetchone()
                    if result:
                        genre_cache[genre_name] = result[0]

        connection.commit()
        print(f"Loaded {genres_added} unique genres")

        # Step 3: Load books
        print("\nStep 3: Loading books...")
        for idx, row in df.iterrows():
            try:
                # Skip if no title or essential data missing
                if pd.isna(row['title']) or pd.isna(row['bookId']):
                    continue

                # Prepare book data
                book_id = int(row['bookId'])
                title = clean_text(row['title'])
                description = clean_text(row['description'])
                isbn = clean_text(row['isbn'])
                isbn13 = clean_text(row['isbn13'])
                language = clean_text(row['language']) if pd.notna(row['language']) else 'English'
                series = clean_text(row['series'])

                # Parse dates
                publish_date = parse_date(row['publish_date'])
                first_publish_date = parse_date(row['first_publish_date'])

                # Numeric fields
                num_pages = int(row['num_pages']) if pd.notna(row['num_pages']) and row['num_pages'] > 0 else None
                num_ratings = int(row['num_ratings']) if pd.notna(row['num_ratings']) else 0
                num_reviews = int(row['num_reviews']) if pd.notna(row['num_reviews']) else 0
                avg_rating = float(row['avg_rating']) if pd.notna(row['avg_rating']) else None

                # Generate price and stock
                price = generate_price(avg_rating, num_pages)
                stock = generate_stock(num_ratings)

                # Insert book
                cursor.execute("""
                    INSERT INTO books (
                        book_id, title, description, isbn, isbn13, language,
                        num_pages, publish_date, first_publish_date, series,
                        avg_rating, num_ratings, num_reviews, price, stock
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    book_id, title, description, isbn, isbn13, language,
                    num_pages, publish_date, first_publish_date, series,
                    avg_rating, num_ratings, num_reviews, price, stock
                ))

                # Link authors to book
                authors = parse_author_list(row['author'])
                for author_name in authors:
                    if author_name in author_cache:
                        author_id = author_cache[author_name]
                        try:
                            cursor.execute(
                                "INSERT INTO book_authors (book_id, author_id) VALUES (%s, %s)",
                                (book_id, author_id)
                            )
                        except mysql.connector.IntegrityError:
                            pass  # Link already exists

                # Link genres to book
                genres = parse_genre_list(row['genres'])
                for genre_name in genres:
                    if genre_name in genre_cache:
                        genre_id = genre_cache[genre_name]
                        try:
                            cursor.execute(
                                "INSERT INTO book_categories (book_id, category_id) VALUES (%s, %s)",
                                (book_id, genre_id)
                            )
                        except mysql.connector.IntegrityError:
                            pass  # Link already exists

                books_loaded += 1

                if books_loaded % 100 == 0:
                    print(f"  Loaded {books_loaded} books...")
                    connection.commit()

            except Exception as e:
                print(f"Error loading book {row.get('bookId', 'unknown')}: {e}")
                continue

        connection.commit()
        print(f"\nSuccessfully loaded {books_loaded} books!")
        print(f"Summary:")
        print(f"  - Authors: {len(author_cache)}")
        print(f"  - Genres: {len(genre_cache)}")
        print(f"  - Books: {books_loaded}")

    except Exception as e:
        print(f"Error during ETL process: {e}")
        connection.rollback()
        raise

    finally:
        cursor.close()


if __name__ == "__main__":
    print("=" * 60)
    print("ONLINE BOOKSTORE - ETL SCRIPT")
    print("Loading Books Data from Goodreads CSV")
    print("=" * 60)

    # Get database connection
    conn = get_connection()

    if conn:
        try:
            # Load books (loading 2000 books for demo purposes)
            load_books_from_csv(
                csv_path='dataset/Goodreadss Books.csv',
                connection=conn,
                limit=2000
            )
            print("\nETL Process completed successfully!")

        except Exception as e:
            print(f"\nETL Process failed: {e}")

        finally:
            close_connection(conn)
    else:
        print("Failed to establish database connection")
