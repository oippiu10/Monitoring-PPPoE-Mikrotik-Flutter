-- ================================================
-- Admin Users Table for Web Panel Authentication
-- ================================================

CREATE TABLE IF NOT EXISTS admin_users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    full_name VARCHAR(100),
    role ENUM('admin', 'operator') DEFAULT 'operator',
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    INDEX idx_username (username),
    INDEX idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default admin user
-- Password: admin123 (hashed with bcrypt)
INSERT INTO admin_users (username, password, email, full_name, role) 
VALUES (
    'admin', 
    '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'admin@mikrotik-monitor.local',
    'Administrator',
    'admin'
) ON DUPLICATE KEY UPDATE username=username;

-- Insert demo operator user
-- Password: demo123 (hashed with bcrypt)
INSERT INTO admin_users (username, password, email, full_name, role) 
VALUES (
    'demo', 
    '$2y$10$7KJZxlkJ5qH.Uj8YvZxO0eF8rKqVxJ5qH.Uj8YvZxO0eF8rKqVxJ5',
    'demo@mikrotik-monitor.local',
    'Demo User',
    'operator'
) ON DUPLICATE KEY UPDATE username=username;

-- ================================================
-- Session Table for Remember Me Functionality
-- ================================================

CREATE TABLE IF NOT EXISTS admin_sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    token VARCHAR(64) UNIQUE NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES admin_users(id) ON DELETE CASCADE,
    INDEX idx_token (token),
    INDEX idx_user_id (user_id),
    INDEX idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ================================================
-- Activity Logs for Admin Actions
-- ================================================

CREATE TABLE IF NOT EXISTS admin_activity_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    description TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES admin_users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_action (action),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ================================================
-- Grant Permissions (if needed)
-- ================================================

-- GRANT ALL PRIVILEGES ON pppoe_monitor.* TO 'pppoe_user'@'localhost';
-- FLUSH PRIVILEGES;
