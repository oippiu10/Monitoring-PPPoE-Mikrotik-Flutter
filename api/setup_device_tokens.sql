-- Device Tokens Table
-- Stores device information for update notifications

CREATE TABLE IF NOT EXISTS device_tokens (
  id INT AUTO_INCREMENT PRIMARY KEY,
  device_id VARCHAR(255) UNIQUE NOT NULL,
  device_model VARCHAR(255),
  app_version VARCHAR(50),
  build_number INT,
  last_check_update DATETIME,
  notification_enabled TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_device_id (device_id),
  INDEX idx_last_check (last_check_update),
  INDEX idx_notification_enabled (notification_enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add some helpful comments
ALTER TABLE device_tokens 
  COMMENT = 'Stores device tokens for update notification system';
