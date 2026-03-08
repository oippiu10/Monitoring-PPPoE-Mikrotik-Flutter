<?php
/**
 * Login API Endpoint - DEBUG VERSION
 * Rename this to login.php to use for debugging
 * Shows detailed error messages
 */

session_start();

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 0); // Don't display, but log

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// Log function
function logError($message) {
    error_log("[LOGIN DEBUG] " . $message);
}

try {
    // Check config file
    $configPath = __DIR__ . '/../config.php';
    if (!file_exists($configPath)) {
        throw new Exception("Config file not found at: $configPath");
    }
    
    require_once $configPath;
    logError("Config loaded successfully");
    
    // Check database connection
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn->connect_error ?? 'Connection object not created'));
    }
    logError("Database connected");
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan koneksi. Silakan coba lagi.',
        'debug' => $e->getMessage() // Remove this in production
    ]);
    exit();
}

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

// Get JSON input
$rawInput = file_get_contents('php://input');
logError("Raw input: " . $rawInput);

$input = json_decode($rawInput, true);

if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid JSON input',
        'debug' => json_last_error_msg()
    ]);
    exit();
}

$username = $input['username'] ?? '';
$password = $input['password'] ?? '';
$remember = $input['remember'] ?? false;

logError("Login attempt for user: $username");

// Validation
if (empty($username) || empty($password)) {
    echo json_encode([
        'success' => false,
        'message' => 'Username dan password harus diisi'
    ]);
    exit();
}

try {
    // Check if table exists
    $tableCheck = $conn->query("SHOW TABLES LIKE 'admin_users'");
    if ($tableCheck->num_rows === 0) {
        throw new Exception("Table 'admin_users' not found. Please run setup_web_admin.sql");
    }
    logError("Table admin_users exists");
    
    // Check user in database
    $stmt = $conn->prepare("SELECT * FROM admin_users WHERE username = ? AND is_active = 1");
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    
    logError("User query executed. Found: " . ($user ? 'Yes' : 'No'));
    
    if (!$user) {
        echo json_encode([
            'success' => false,
            'message' => 'Username tidak ditemukan atau tidak aktif',
            'debug' => "User '$username' not found in database"
        ]);
        exit();
    }
    
    // Verify password
    logError("Verifying password...");
    if (!password_verify($password, $user['password'])) {
        echo json_encode([
            'success' => false,
            'message' => 'Password salah',
            'debug' => 'Password verification failed'
        ]);
        exit();
    }
    
    logError("Password verified successfully");
    
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
    $updateStmt->bind_param("i", $user['id']);
    $updateStmt->execute();
    
    // Set remember me cookie
    if ($remember) {
        $token = bin2hex(random_bytes(32));
        $expires = time() + (86400 * 30);
        
        $tokenStmt = $conn->prepare("INSERT INTO admin_sessions (user_id, token, ip_address, user_agent, expires_at) VALUES (?, ?, ?, ?, FROM_UNIXTIME(?))");
        $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        $ua = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
        $tokenStmt->bind_param("isssi", $user['id'], $token, $ip, $ua, $expires);
        $tokenStmt->execute();
        
        setcookie('remember_token', $token, $expires, '/');
    }
    
    // Log activity
    $logStmt = $conn->prepare("INSERT INTO admin_activity_logs (user_id, action, description, ip_address, user_agent) VALUES (?, 'login', 'User logged in successfully', ?, ?)");
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $ua = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
    $logStmt->bind_param("iss", $user['id'], $ip, $ua);
    $logStmt->execute();
    
    $conn->close();
    
    logError("Login successful for user: $username");
    
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
    logError("Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Terjadi kesalahan server',
        'debug' => $e->getMessage(), // Remove this in production
        'trace' => $e->getTraceAsString() // Remove this in production
    ]);
}
?>
