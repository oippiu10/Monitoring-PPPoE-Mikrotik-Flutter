-- Setup Notification Queue Table
-- This table stores notifications triggered from admin panel

CREATE TABLE IF NOT EXISTS notification_queue (
  id INT AUTO_INCREMENT PRIMARY KEY,
  notification_type VARCHAR(50) DEFAULT 'update' COMMENT 'Type: update, announcement, etc',
  title VARCHAR(255) NOT NULL COMMENT 'Notification title',
  message TEXT NOT NULL COMMENT 'Notification message/body',
  version VARCHAR(50) COMMENT 'App version (for update notifications)',
  build_number INT COMMENT 'Build number (for update notifications)',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'When notification was created',
  expires_at DATETIME COMMENT 'When notification expires (NULL = never)',
  is_active TINYINT(1) DEFAULT 1 COMMENT '1 = active, 0 = inactive',
  INDEX idx_active (is_active),
  INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Queue for push notifications from admin panel';

-- Setup Notification Reads Tracking Table
-- This table tracks which devices have already seen which notifications

CREATE TABLE IF NOT EXISTS notification_reads (
  id INT AUTO_INCREMENT PRIMARY KEY,
  device_id VARCHAR(255) NOT NULL COMMENT 'Device unique identifier',
  notification_id INT NOT NULL COMMENT 'Reference to notification_queue.id',
  read_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'When device read the notification',
  UNIQUE KEY unique_device_notification (device_id, notification_id),
  FOREIGN KEY (notification_id) REFERENCES notification_queue(id) ON DELETE CASCADE,
  INDEX idx_device (device_id),
  INDEX idx_notification (notification_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Track which devices have seen which notifications';
