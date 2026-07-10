<?php
// NOTE: Jangan panggil header() di sini karena beberapa file memanggil session_start() sebelum include config.php
// Header akan di-set di masing-masing endpoint
date_default_timezone_set('Asia/Jakarta');

// Load environment variables from api/.env or project root .env if available.
foreach ([__DIR__ . '/.env', dirname(__DIR__) . '/.env'] as $envFile) {
  if (!file_exists($envFile)) {
    continue;
  }

  $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
  foreach ($lines as $line) {
    $line = trim($line);
    if ($line === '' || strpos($line, '#') === 0 || strpos($line, '=') === false) {
      continue;
    }

    [$key, $value] = explode('=', $line, 2);
    $key = trim($key);
    $value = trim($value, " \t\n\r\0\x0B\"'");

    if ($key !== '' && !array_key_exists($key, $_ENV)) {
      $_ENV[$key] = $value;
    }
  }
}

// ─── PHP Settings & Performance ─────────────────────────────────────────────
ini_set('memory_limit', '256M'); // Handle large user lists (4000+)
ini_set('max_execution_time', 300); // 5 minutes
error_reporting(E_ALL & ~E_NOTICE & ~E_DEPRECATED);
ini_set('display_errors', 0); // Don't break JSON output
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error.log'); // Simpan error ke file lokal


// ─── Database Configuration ──────────────────────────────────────────────────
// Use 127.0.0.1 instead of localhost to force TCP connection instead of socket
$host = $_ENV['DB_HOST'] ?? getenv('DB_HOST') ?: '127.0.0.1';
$db = $_ENV['DB_NAME'] ?? getenv('DB_NAME') ?: 'pppoe_monitor';
$user = $_ENV['DB_USER'] ?? getenv('DB_USER') ?: 'root';
$pass = $_ENV['DB_PASS'] ?? getenv('DB_PASS') ?: 'yahahahusein112';
  
$conn = mysqli_init();
mysqli_options($conn, MYSQLI_OPT_CONNECT_TIMEOUT, 5); // 5 seconds timeout
if (!@mysqli_real_connect($conn, $host, $user, $pass, $db)) {
    error_log('Database connection failed: ' . mysqli_connect_error());
    http_response_code(500);
    die(json_encode([
        'success' => false,
        'message' => 'Database connection failed',
        'type' => 'db_error'
    ]));
}
mysqli_set_charset($conn, 'utf8mb4');

// Auto-migrate ODP columns if they don't exist
$resOdpCols = $conn->query("SHOW COLUMNS FROM odp");
if ($resOdpCols) {
    $odpCols = [];
    while ($r = $resOdpCols->fetch_assoc()) {
        $odpCols[] = $r['Field'];
    }
    if (!in_array('capacity', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN capacity INT DEFAULT 8 AFTER lng");
    }
    if (!in_array('type', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN type VARCHAR(50) DEFAULT 'splitter' AFTER capacity");
    }
    if (!in_array('splitter_type', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN splitter_type VARCHAR(50) DEFAULT '1:8' AFTER type");
    }
    if (!in_array('ratio_used', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN ratio_used INT DEFAULT 0 AFTER splitter_type");
    }
    if (!in_array('ratio_total', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN ratio_total INT DEFAULT 8 AFTER ratio_used");
    }
    if (!in_array('gpon_type', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN gpon_type VARCHAR(50) DEFAULT 'GPON' AFTER ratio_total");
    }
    if (!in_array('rx_power', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN rx_power VARCHAR(50) DEFAULT NULL AFTER gpon_type");
    }
    if (!in_array('odp_type_flag', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN odp_type_flag VARCHAR(50) DEFAULT 'ratio' AFTER rx_power");
    }
    // Auto-sync odp_type_flag dengan type agar konsisten
    $conn->query("UPDATE odp SET odp_type_flag = type WHERE odp_type_flag != type OR odp_type_flag IS NULL");
    if (!in_array('location', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN location VARCHAR(255) DEFAULT '' AFTER name");
    }
    if (!in_array('maps_link', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN maps_link VARCHAR(255) DEFAULT '' AFTER location");
    }
}

// Auto-migrate Cable Colors table
$conn->query("CREATE TABLE IF NOT EXISTS `cable_colors` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `router_id` VARCHAR(100) NOT NULL DEFAULT '',
    `name` VARCHAR(100) NOT NULL,
    `color_code` VARCHAR(20) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

// Check and add cable_color_id to odc table
$resOdcCols = $conn->query("SHOW COLUMNS FROM odc");
if ($resOdcCols) {
    $odcCols = [];
    while ($r = $resOdcCols->fetch_assoc()) {
        $odcCols[] = $r['Field'];
    }
    if (!in_array('cable_color_id', $odcCols)) {
        $conn->query("ALTER TABLE odc ADD COLUMN `cable_color_id` INT DEFAULT NULL AFTER `router_id`");
    }
    if (!in_array('core_number', $odcCols)) {
        $conn->query("ALTER TABLE odc ADD COLUMN `core_number` INT DEFAULT NULL AFTER `cable_color_id`");
    }
}

// Check and add cable_color_id to odp table
if (isset($odpCols)) {
    if (!in_array('cable_color_id', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN `cable_color_id` INT DEFAULT NULL AFTER `odc_id`");
    }
    if (!in_array('core_number', $odpCols)) {
        $conn->query("ALTER TABLE odp ADD COLUMN `core_number` INT DEFAULT NULL AFTER `cable_color_id`");
    }
}

// Auto-migrate users columns if they don't exist
$resUserCols = $conn->query("SHOW COLUMNS FROM users");
if ($resUserCols) {
    $userCols = [];
    while ($r = $resUserCols->fetch_assoc()) {
        $userCols[] = $r['Field'];
    }
    if (!in_array('odp_id', $userCols)) {
        $conn->query("ALTER TABLE users ADD COLUMN odp_id INT DEFAULT NULL");
    }
    if (!in_array('odp_port', $userCols)) {
        $conn->query("ALTER TABLE users ADD COLUMN odp_port INT DEFAULT NULL");
    }
    if (!in_array('tipe_langganan', $userCols)) {
        $conn->query("ALTER TABLE users ADD COLUMN tipe_langganan VARCHAR(20) DEFAULT 'pascabayar'");
    }
    if (!in_array('redaman', $userCols)) {
        $conn->query("ALTER TABLE users ADD COLUMN redaman VARCHAR(50) DEFAULT NULL");
    }
    if (!in_array('alamat', $userCols)) {
        $conn->query("ALTER TABLE users ADD COLUMN alamat TEXT DEFAULT NULL");
    }
    if (!in_array('wa', $userCols)) {
        $conn->query("ALTER TABLE users ADD COLUMN wa VARCHAR(50) DEFAULT NULL");
    }
    if (!in_array('maps', $userCols)) {
        $conn->query("ALTER TABLE users ADD COLUMN maps VARCHAR(500) DEFAULT NULL");
    }
    if (!in_array('lat', $userCols)) {
        $conn->query("ALTER TABLE users ADD COLUMN lat DECIMAL(10,7) DEFAULT NULL");
    }
    if (!in_array('lng', $userCols)) {
        $conn->query("ALTER TABLE users ADD COLUMN lng DECIMAL(10,7) DEFAULT NULL");
    }
    
    // Auto-migrate tanggal_tagihan if it's DATE (legacy bug)
    $resTagihanType = $conn->query("SHOW COLUMNS FROM users WHERE Field = 'tanggal_tagihan'");
    if ($resTagihanType && $row = $resTagihanType->fetch_assoc()) {
        if (strpos(strtolower($row['Type']), 'date') !== false) {
            $conn->query("ALTER TABLE users MODIFY tanggal_tagihan INT DEFAULT NULL");
        }
    }
}

// Auto-migrate expenses table
$conn->query("CREATE TABLE IF NOT EXISTS `expenses` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `router_id` VARCHAR(100) NOT NULL DEFAULT '',
    `category` VARCHAR(100) NOT NULL,
    `amount` DECIMAL(15,2) NOT NULL DEFAULT 0,
    `note` TEXT,
    `spent_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `created_by` VARCHAR(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

$resExpenseCols = $conn->query("SHOW COLUMNS FROM expenses");
if ($resExpenseCols) {
    $expCols = [];
    while ($r = $resExpenseCols->fetch_assoc()) {
        $expCols[] = $r['Field'];
    }
    if (!in_array('created_by', $expCols)) {
        $conn->query("ALTER TABLE expenses ADD COLUMN `created_by` VARCHAR(100) DEFAULT NULL AFTER `spent_at`");
    }
    if (!in_array('receipt_image', $expCols)) {
        $conn->query("ALTER TABLE expenses ADD COLUMN `receipt_image` VARCHAR(255) DEFAULT NULL AFTER `created_by`");
    }
}

// Ensure upload directory exists for receipts
$uploadsDir = __DIR__ . '/uploads/receipts';
if (!file_exists($uploadsDir)) {
    @mkdir($uploadsDir, 0777, true);
}

