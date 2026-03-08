<?php
/**
 * Simple Login - Guaranteed to Work
 * This is a simplified version for testing
 */

// Session configuration
ini_set('session.cookie_httponly', 1);
session_start();

// Headers
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// Only POST allowed
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(['success' => false, 'message' => 'Method not allowed']));
}

// Get input
$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    die(json_encode(['success' => false, 'message' => 'Invalid JSON']));
}

$username = trim($input['username'] ?? '');
$password = trim($input['password'] ?? '');

// Validate
if (empty($username) || empty($password)) {
    die(json_encode(['success' => false, 'message' => 'Username dan password harus diisi']));
}

// Connect to database
try {
    $conn = new mysqli('127.0.0.1', 'root', 'yahahahusein112', 'pppoe_monitor');
    
    if ($conn->connect_error) {
        die(json_encode([
            'success' => false, 
            'message' => 'Database connection failed',
            'error' => $conn->connect_error
        ]));
    }
    
    // Get user
    $stmt = $conn->prepare("SELECT * FROM admin_users WHERE username = ? AND is_active = 1");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    
    if (!$user) {
        $conn->close();
        die(json_encode(['success' => false, 'message' => 'Username tidak ditemukan']));
    }
    
    // Verify password
    if (!password_verify($password, $user['password'])) {
        $conn->close();
        die(json_encode(['success' => false, 'message' => 'Password salah']));
    }
    
    // Create session
    $_SESSION['logged_in'] = true;
    $_SESSION['user_id'] = $user['id'];
    $_SESSION['username'] = $user['username'];
    $_SESSION['role'] = $user['role'];
    $_SESSION['full_name'] = $user['full_name'];
    $_SESSION['login_time'] = time();
    
    // Update last login
    $conn->query("UPDATE admin_users SET last_login = NOW() WHERE id = " . $user['id']);
    
    $conn->close();
    
    // Success!
    echo json_encode([
        'success' => true,
        'message' => 'Login berhasil',
        'data' => [
            'username' => $user['username'],
            'full_name' => $user['full_name'],
            'role' => $user['role'],
            'session_id' => session_id()
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error',
        'error' => $e->getMessage()
    ]);
}
?>
