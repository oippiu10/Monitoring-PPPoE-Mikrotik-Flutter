<?php
/**
 * Logout API Endpoint
 */

session_start();
header('Content-Type: application/json');

// Destroy session
session_unset();
session_destroy();

// Remove remember me cookie
setcookie('remember_token', '', time() - 3600, '/');

echo json_encode([
    'success' => true,
    'message' => 'Logout berhasil'
]);
?>
