"""
Database Connection Module
Provides reusable connection functionality for MySQL database.

Credentials are read from environment variables so they are never committed
to source control. Set them once in your shell before running scripts:

    Windows (cmd):   set DB_PASSWORD=your_password
    Windows (bash):  export DB_PASSWORD=your_password

Alternatively, copy db_config.example.py to db_config.py (git-ignored) and
fill in your credentials there.
"""

import os
import mysql.connector
from mysql.connector import Error

# Try to load local, git-ignored config as a fallback (optional)
try:
    import db_config
    _DEFAULTS = {
        "host": getattr(db_config, "HOST", "localhost"),
        "user": getattr(db_config, "USER", "root"),
        "password": getattr(db_config, "PASSWORD", ""),
        "database": getattr(db_config, "DATABASE", "online_book_store"),
    }
except ImportError:
    _DEFAULTS = {
        "host": "localhost",
        "user": "root",
        "password": "",
        "database": "online_book_store",
    }


def get_connection():
    """
    Establish and return a MySQL database connection.

    Reads credentials from environment variables (DB_HOST, DB_USER,
    DB_PASSWORD, DB_NAME), falling back to db_config.py, then to defaults.

    Returns:
        connection: MySQL connection object if successful, None otherwise
    """
    try:
        connection = mysql.connector.connect(
            host=os.environ.get("DB_HOST", _DEFAULTS["host"]),
            user=os.environ.get("DB_USER", _DEFAULTS["user"]),
            password=os.environ.get("DB_PASSWORD", _DEFAULTS["password"]),
            database=os.environ.get("DB_NAME", _DEFAULTS["database"]),
        )

        if connection.is_connected():
            db_info = connection.get_server_info()
            print(f"Successfully connected to MySQL Server version {db_info}")
            return connection

    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None


def close_connection(connection):
    """Safely close the database connection."""
    if connection and connection.is_connected():
        connection.close()
        print("MySQL connection closed")


if __name__ == "__main__":
    # Test connection
    conn = get_connection()
    if conn:
        cursor = conn.cursor()
        cursor.execute("SELECT DATABASE();")
        record = cursor.fetchone()
        print(f"Connected to database: {record[0]}")
        cursor.close()
        close_connection(conn)
