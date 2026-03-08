<?php
/**
 * Check Session Middleware
 * Include this file in pages that require authentication
 */

session_start();

require_once '../config.php';

function checkAuth() {
    global $conn;
    
    // Check if session exists
    if (!isset($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
        header('Location: ../web/login.html');
        exit();
    }
    
    // Check session timeout (30 minutes)
    $timeout = 1800; // 30 minutes
    if (isset($_SESSION['login_time']) && (time() - $_SESSION['login_time'] > $timeout)) {
        session_unset();
        session_destroy();
        header('Location: ../web/login.html');
        exit();
    }
    
    // Verify user still exists and is active
    if (isset($_SESSION['user_id'])) {
        $stmt = $conn->prepare("SELECT is_active FROM admin_users WHERE id = ?");
        $stmt->bind_param("i", $_SESSION['user_id']);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();
        
        if (!$user || !$user['is_active']) {
            session_unset();
            session_destroy();
            header('Location: ../web/login.html');
            exit();
        }
    }
    
    // Update last activity time
    $_SESSION['login_time'] = time();
    
    return true;
}

function getUsername() {
    return $_SESSION['username'] ?? 'Unknown';
}

function getUserFullName() {
    return $_SESSION['full_name'] ?? $_SESSION['username'] ?? 'User';
}

function getUserRole() {
    return $_SESSION['role'] ?? 'operator';
}

function isLoggedIn() {
    return isset($_SESSION['logged_in']) && $_SESSION['logged_in'] === true;
}
?>
