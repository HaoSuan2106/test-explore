use exploremy_dev;

-- MODULE 1: User Authentication & Profile Management

-- Users table
CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,users
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    username VARCHAR(50) NOT NULL,
    profile_picture_url VARCHAR(500) DEFAULT NULL,
    city VARCHAR(100) DEFAULT NULL,
    age INT DEFAULT NULL,
    gender ENUM('Male','Female','Prefer not to say') DEFAULT NULL,
    account_status VARCHAR(30) NOT NULL DEFAULT 'pending_verification',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
 
-- Email verification token table (depends on users)
CREATE TABLE IF NOT EXISTS email_verification_token (
    token_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at DATETIME NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    pending_email VARCHAR(255) DEFAULT NULL,

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,

    INDEX idx_evt_user_id (user_id)
);
 
-- Password reset token table (depends on users)
CREATE TABLE IF NOT EXISTS password_reset_token (
    token_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at DATETIME NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
 
    INDEX idx_prt_user_id (user_id)
);
 
-- User session table (depends on users)
CREATE TABLE IF NOT EXISTS user_session (
    session_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    session_token VARCHAR(500) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
 
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
 
    INDEX idx_session_user_id (user_id)
);