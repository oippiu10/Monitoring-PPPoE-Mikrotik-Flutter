<?php
/**
 * Device Token Operations API
 * Handles device registration and update check tracking
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle OPTIONS request for CORS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/config.php';

/**
 * Get database connection
 */
function getConnection() {
    try {
        $conn = new PDO(
            "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
            DB_USER,
            DB_PASS,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false
            ]
        );
        return $conn;
    } catch (PDOException $e) {
        throw new Exception("Database connection failed: " . $e->getMessage());
    }
}

/**
 * Register or update device token
 */
function registerDevice($data) {
    $conn = getConnection();
    
    $deviceId = $data['device_id'] ?? null;
    $deviceModel = $data['device_model'] ?? null;
    $appVersion = $data['app_version'] ?? null;
    $buildNumber = $data['build_number'] ?? null;
    
    if (!$deviceId) {
        throw new Exception("device_id is required");
    }
    
    // Check if device exists
    $stmt = $conn->prepare("SELECT id FROM device_tokens WHERE device_id = ?");
    $stmt->execute([$deviceId]);
    $exists = $stmt->fetch();
    
    if ($exists) {
        // Update existing device
        $stmt = $conn->prepare("
            UPDATE device_tokens 
            SET device_model = ?, 
                app_version = ?, 
                build_number = ?,
                updated_at = NOW()
            WHERE device_id = ?
        ");
        $stmt->execute([$deviceModel, $appVersion, $buildNumber, $deviceId]);
        
        return [
            'success' => true,
            'message' => 'Device updated successfully',
            'device_id' => $deviceId,
            'action' => 'updated'
        ];
    } else {
        // Insert new device
        $stmt = $conn->prepare("
            INSERT INTO device_tokens 
            (device_id, device_model, app_version, build_number, created_at, updated_at) 
            VALUES (?, ?, ?, ?, NOW(), NOW())
        ");
        $stmt->execute([$deviceId, $deviceModel, $appVersion, $buildNumber]);
        
        return [
            'success' => true,
            'message' => 'Device registered successfully',
            'device_id' => $deviceId,
            'action' => 'registered'
        ];
    }
}

/**
 * Update last check timestamp
 */
function updateLastCheck($data) {
    $conn = getConnection();
    
    $deviceId = $data['device_id'] ?? null;
    
    if (!$deviceId) {
        throw new Exception("device_id is required");
    }
    
    $stmt = $conn->prepare("
        UPDATE device_tokens 
        SET last_check_update = NOW(),
            updated_at = NOW()
        WHERE device_id = ?
    ");
    $stmt->execute([$deviceId]);
    
    return [
        'success' => true,
        'message' => 'Last check updated',
        'device_id' => $deviceId,
        'timestamp' => date('Y-m-d H:i:s')
    ];
}

/**
 * Get all registered devices (for admin)
 */
function getAllDevices() {
    $conn = getConnection();
    
    $stmt = $conn->query("
        SELECT 
            device_id,
            device_model,
            app_version,
            build_number,
            last_check_update,
            notification_enabled,
            created_at,
            updated_at
        FROM device_tokens 
        ORDER BY updated_at DESC
    ");
    
    $devices = $stmt->fetchAll();
    
    return [
        'success' => true,
        'total' => count($devices),
        'devices' => $devices
    ];
}

/**
 * Get device statistics
 */
function getDeviceStats() {
    $conn = getConnection();
    
    // Total devices
    $stmt = $conn->query("SELECT COUNT(*) as total FROM device_tokens");
    $total = $stmt->fetch()['total'];
    
    // Active in last 24 hours
    $stmt = $conn->query("
        SELECT COUNT(*) as active_24h 
        FROM device_tokens 
        WHERE last_check_update > DATE_SUB(NOW(), INTERVAL 24 HOUR)
    ");
    $active24h = $stmt->fetch()['active_24h'];
    
    // Active in last 7 days
    $stmt = $conn->query("
        SELECT COUNT(*) as active_7d 
        FROM device_tokens 
        WHERE last_check_update > DATE_SUB(NOW(), INTERVAL 7 DAY)
    ");
    $active7d = $stmt->fetch()['active_7d'];
    
    // Notifications enabled
    $stmt = $conn->query("
        SELECT COUNT(*) as notif_enabled 
        FROM device_tokens 
        WHERE notification_enabled = 1
    ");
    $notifEnabled = $stmt->fetch()['notif_enabled'];
    
    return [
        'success' => true,
        'stats' => [
            'total_devices' => (int)$total,
            'active_24h' => (int)$active24h,
            'active_7d' => (int)$active7d,
            'notification_enabled' => (int)$notifEnabled
        ]
    ];
}

/**
 * Toggle notification setting for device
 */
function toggleNotification($data) {
    $conn = getConnection();
    
    $deviceId = $data['device_id'] ?? null;
    $enabled = $data['enabled'] ?? true;
    
    if (!$deviceId) {
        throw new Exception("device_id is required");
    }
    
    $stmt = $conn->prepare("
        UPDATE device_tokens 
        SET notification_enabled = ?,
            updated_at = NOW()
        WHERE device_id = ?
    ");
    $stmt->execute([$enabled ? 1 : 0, $deviceId]);
    
    return [
        'success' => true,
        'message' => 'Notification setting updated',
        'device_id' => $deviceId,
        'enabled' => (bool)$enabled
    ];
}

/**
 * Main request handler
 */
try {
    $action = $_GET['action'] ?? $_POST['action'] ?? null;
    
    if (!$action) {
        throw new Exception("Action parameter is required");
    }
    
    // Get request body for POST requests
    $requestBody = file_get_contents('php://input');
    $data = json_decode($requestBody, true) ?? [];
    
    // Merge with POST data
    $data = array_merge($_POST, $data);
    
    $response = null;
    
    switch ($action) {
        case 'register':
            $response = registerDevice($data);
            break;
            
        case 'update_last_check':
            $response = updateLastCheck($data);
            break;
            
        case 'get_all':
            $response = getAllDevices();
            break;
            
        case 'stats':
            $response = getDeviceStats();
            break;
            
        case 'toggle_notification':
            $response = toggleNotification($data);
            break;
            
        default:
            throw new Exception("Invalid action: $action");
    }
    
    http_response_code(200);
    echo json_encode($response, JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ], JSON_PRETTY_PRINT);
}
