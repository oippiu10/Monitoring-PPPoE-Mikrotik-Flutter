<?php
/**
 * Login API Endpoint
 * Handles user authentication for web admin panel
 */

// Start session with proper configuration
ini_set('session.cookie_httponly', 1);
ini_set('session.use_only_cookies', 1);
ini_set('session.cookie_samesite', 'Lax');

session_start();

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Only allow POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Method not allowed'
    ]);
    exit();
}

try {
    // Load config
    require_once __DIR__ . '/../config.php';
    
    // Check database connection
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception('Database connection failed');
    }
    
    // Get JSON input
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Invalid JSON input');
    }
    
    $username = $input['username'] ?? '';
    $password = $input['password'] ?? '';
    $remember = $input['remember'] ?? false;
    
    // Validation
    if (empty($username) || empty($password)) {
        echo json_encode([
            'success' => false,
            'message' => 'Username dan password harus diisi'
        ]);
        exit();
    }
    
    // Check user in database
    $stmt = $conn->prepare("SELECT * FROM admin_users WHERE username = ? AND is_active = 1");
    if (!$stmt) {
        throw new Exception('Database query failed');
    }
    
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    
    if (!$user) {
        echo json_encode([
            'success' => false,
            'message' => 'Username tidak ditemukan atau tidak aktif'
        ]);
        exit();
    }
    
    // Verify password
    if (!password_verify($password, $user['password'])) {
        echo json_encode([
            'success' => false,
            'message' => 'Password salah'
        ]);
        exit();
    }
    
    // Create session
    $_SESSION['logged_in'] = true;
    $_SESSION['user_id'] = $user['id'];
    $_SESSION['username'] = $user['username'];
    $_SESSION['role'] = $user['role'];
    $_SESSION['full_name'] = $user['full_name'];
    $_SESSION['login_time'] = time();
    $_SESSION['user_agent'] = $_SERVER['HTTP_USER_AGENT'] ?? '';
    
    // Update last login
    $updateStmt = $conn->prepare("UPDATE admin_users SET last_login = NOW() WHERE id = ?");
    if ($updateStmt) {
        $updateStmt->bind_param("i", $user['id']);
        $updateStmt->execute();
    }
    
    // Set remember me cookie
    if ($remember) {
        try {
            $token = bin2hex(random_bytes(32));
            $expires = time() + (86400 * 30);
            
            $tokenStmt = $conn->prepare("INSERT INTO admin_sessions (user_id, token, ip_address, user_agent, expires_at) VALUES (?, ?, ?, ?, FROM_UNIXTIME(?))");
            if ($tokenStmt) {
                $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
                $ua = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
                $tokenStmt->bind_param("isssi", $user['id'], $token, $ip, $ua, $expires);
                $tokenStmt->execute();
                
                setcookie('remember_token', $token, $expires, '/', '', false, true);
            }
        } catch (Exception $e) {
            // Continue even if remember me fails
        }
    }
    
    // Log activity
    try {
        $logStmt = $conn->prepare("INSERT INTO admin_activity_logs (user_id, action, description, ip_address, user_agent) VALUES (?, 'login', 'User logged in successfully', ?, ?)");
        if ($logStmt) {
            $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
            $ua = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
            $logStmt->bind_param("iss", $user['id'], $ip, $ua);
            $logStmt->execute();
        }
    } catch (Exception $e) {
        // Continue even if logging fails
    }
    
    if (isset($conn)) {
        $conn->close();
    }
    
    // Success response
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
    // Log error
    error_log("Login error: " . $e->getMessage());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan koneksi. Silakan coba lagi.',
        'error' => $e->getMessage() // Remove in production
    ]);
}
?>
