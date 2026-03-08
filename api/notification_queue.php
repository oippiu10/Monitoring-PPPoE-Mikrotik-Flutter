<?php
/**
 * Notification Queue API
 * Handles notification triggers from admin panel and checks from mobile app
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
 * Trigger new notification (Admin action)
 */
function triggerNotification($conn, $data) {
    $type = $data['type'] ?? 'update';
    $title = $data['title'] ?? 'Update Tersedia 🚀';
    $message = $data['message'] ?? 'Update terbaru tersedia untuk diunduh';
    $version = $data['version'] ?? null;
    $buildNumber = $data['build_number'] ?? null;
    $expiresAt = $data['expires_at'] ?? null; // Optional expiry date
    
    $stmt = $conn->prepare("
        INSERT INTO notification_queue 
        (notification_type, title, message, version, build_number, expires_at, is_active)
        VALUES (?, ?, ?, ?, ?, ?, 1)
    ");
    
    $stmt->bind_param(
        "ssssis",
        $type,
        $title,
        $message,
        $version,
        $buildNumber,
        $expiresAt
    );
    
    if ($stmt->execute()) {
        $notificationId = $conn->insert_id;
        
        return [
            'success' => true,
            'notification_id' => $notificationId,
            'message' => 'Notifikasi berhasil di-trigger'
        ];
    } else {
        return [
            'success' => false,
            'error' => 'Gagal menyimpan notifikasi: ' . $stmt->error
        ];
    }
}

/**
 * Check for new notifications (App action)
 */
function checkNotifications($conn, $deviceId) {
    // Get active notifications that this device hasn't read yet
    $stmt = $conn->prepare("
        SELECT nq.* 
        FROM notification_queue nq
        LEFT JOIN notification_reads nr 
            ON nq.id = nr.notification_id AND nr.device_id = ?
        WHERE nq.is_active = 1
        AND (nq.expires_at IS NULL OR nq.expires_at > NOW())
        AND nr.id IS NULL
        ORDER BY nq.created_at DESC
        LIMIT 1
    ");
    
    $stmt->bind_param("s", $deviceId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        return [
            'success' => true,
            'has_notification' => true,
            'notification' => [
                'id' => $row['id'],
                'type' => $row['notification_type'],
                'title' => $row['title'],
                'message' => $row['message'],
                'version' => $row['version'],
                'build_number' => $row['build_number'],
                'created_at' => $row['created_at']
            ]
        ];
    } else {
        return [
            'success' => true,
            'has_notification' => false,
            'notification' => null
        ];
    }
}

/**
 * Mark notification as read (App action)
 */
function markNotificationRead($conn, $deviceId, $notificationId) {
    $stmt = $conn->prepare("
        INSERT INTO notification_reads (device_id, notification_id)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE read_at = NOW()
    ");
    
    $stmt->bind_param("si", $deviceId, $notificationId);
    
    if ($stmt->execute()) {
        return [
            'success' => true,
            'message' => 'Notifikasi ditandai sudah dibaca'
        ];
    } else {
        return [
            'success' => false,
            'error' => 'Gagal menandai notifikasi: ' . $stmt->error
        ];
    }
}

/**
 * Get notification statistics (Admin action)
 */
function getNotificationStats($conn) {
    // Total active notifications
    $result = $conn->query("
        SELECT COUNT(*) as total_active
        FROM notification_queue
        WHERE is_active = 1
        AND (expires_at IS NULL OR expires_at > NOW())
    ");
    $totalActive = $result->fetch_assoc()['total_active'];
    
    // Total reads
    $result = $conn->query("
        SELECT COUNT(*) as total_reads
        FROM notification_reads
    ");
    $totalReads = $result->fetch_assoc()['total_reads'];
    
    // Latest notification
    $result = $conn->query("
        SELECT * FROM notification_queue
        WHERE is_active = 1
        ORDER BY created_at DESC
        LIMIT 1
    ");
    $latestNotification = $result->fetch_assoc();
    
    return [
        'success' => true,
        'stats' => [
            'total_active' => $totalActive,
            'total_reads' => $totalReads,
            'latest_notification' => $latestNotification
        ]
    ];
}

/**
 * Deactivate old notifications (Admin action)
 */
function deactivateNotification($conn, $notificationId) {
    $stmt = $conn->prepare("
        UPDATE notification_queue
        SET is_active = 0
        WHERE id = ?
    ");
    
    $stmt->bind_param("i", $notificationId);
    
    if ($stmt->execute()) {
        return [
            'success' => true,
            'message' => 'Notifikasi dinonaktifkan'
        ];
    } else {
        return [
            'success' => false,
            'error' => 'Gagal menonaktifkan notifikasi: ' . $stmt->error
        ];
    }
}

// Main request handler
try {
    $action = $_GET['action'] ?? $_POST['action'] ?? '';
    
    switch ($action) {
        case 'trigger':
            // Admin trigger new notification
            $data = json_decode(file_get_contents('php://input'), true);
            if (!$data) {
                $data = $_POST;
            }
            echo json_encode(triggerNotification($conn, $data));
            break;
            
        case 'check':
            // App check for new notifications
            $deviceId = $_GET['device_id'] ?? '';
            if (empty($deviceId)) {
                echo json_encode([
                    'success' => false,
                    'error' => 'device_id required'
                ]);
                break;
            }
            echo json_encode(checkNotifications($conn, $deviceId));
            break;
            
        case 'mark_read':
            // App mark notification as read
            $data = json_decode(file_get_contents('php://input'), true);
            if (!$data) {
                $data = $_POST;
            }
            $deviceId = $data['device_id'] ?? '';
            $notificationId = $data['notification_id'] ?? 0;
            
            if (empty($deviceId) || empty($notificationId)) {
                echo json_encode([
                    'success' => false,
                    'error' => 'device_id and notification_id required'
                ]);
                break;
            }
            echo json_encode(markNotificationRead($conn, $deviceId, $notificationId));
            break;
            
        case 'stats':
            // Admin get notification statistics
            echo json_encode(getNotificationStats($conn));
            break;
            
        case 'deactivate':
            // Admin deactivate notification
            $notificationId = $_POST['notification_id'] ?? $_GET['notification_id'] ?? 0;
            if (empty($notificationId)) {
                echo json_encode([
                    'success' => false,
                    'error' => 'notification_id required'
                ]);
                break;
            }
            echo json_encode(deactivateNotification($conn, $notificationId));
            break;
            
        default:
            echo json_encode([
                'success' => false,
                'error' => 'Invalid action. Available: trigger, check, mark_read, stats, deactivate'
            ]);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

$conn->close();
?>
