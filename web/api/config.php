<?php
header('Content-Type: application/json; charset=UTF-8');

// Load environment variables if .env file exists
if (file_exists(__DIR__ . '/.env')) {
    $lines = file(__DIR__ . '/.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos($line, '#') === 0) continue; // Skip comments
        list($key, $value) = explode('=', $line, 2);
        $_ENV[trim($key)] = trim($value);
    }
}

// Database configuration with environment variable support
// Use 127.0.0.1 instead of localhost to force TCP connection instead of socket
$host = $_ENV['DB_HOST'] ?? getenv('DB_HOST') ?: '127.0.0.1/phpmyadmin';
$db   = $_ENV['DB_NAME'] ?? getenv('DB_NAME') ?: 'pppoe_monitor';
$user = $_ENV['DB_USER'] ?? getenv('DB_USER') ?: 'root';
$pass = $_ENV['DB_PASS'] ?? getenv('DB_PASS') ?: 'yahahahusein112'; // CHANGE THIS IN PRODUCTION!

$conn = new mysqli($host, $user, $pass, $db);
if ($conn->connect_error) {
  http_response_code(500);
  die(json_encode(['success' => false, 'message' => 'DB connect failed: ' . $conn->connect_error]));
}
mysqli_set_charset($conn, 'utf8mb4');







