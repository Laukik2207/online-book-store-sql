CREATE TABLE authors (
    author_id INT AUTO_INCREMENT PRIMARY KEY,
    author_name VARCHAR(255) NOT NULL
);

DESCRIBE authors;

CREATE TABLE books (
    book_id INT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    isbn VARCHAR(20) UNIQUE,
    isbn13 VARCHAR(20) UNIQUE,
    language VARCHAR(50),
    num_pages INT,
    publish_date DATE,
    first_publish_date DATE,
    series VARCHAR(255),
    avg_rating DECIMAL(3,2),
    num_ratings INT DEFAULT 0,
    num_reviews INT DEFAULT 0,
    price DECIMAL(8,2) NOT NULL,
    stock INT DEFAULT 0
);

CREATE TABLE book_authors (
    book_id INT,
    author_id INT,

    PRIMARY KEY (book_id, author_id),

    FOREIGN KEY (book_id)
        REFERENCES books(book_id)
        ON DELETE CASCADE,

    FOREIGN KEY (author_id)
        REFERENCES authors(author_id)
        ON DELETE CASCADE
);