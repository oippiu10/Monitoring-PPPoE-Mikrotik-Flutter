<?php
ob_start();
/**
 * Get Activity Logs API
 */
if (session_status() === PHP_SESSION_NONE) { session_start(); }
while (ob_get_level() > 1) ob_end_clean();
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/auth/require_auth.php';

$limit  = intval($_GET['limit']  ?? 50);
$page   = intval($_GET['page']   ?? 1);
$offset = intval($_GET['offset'] ?? (($page - 1) * $limit));
$type   = $_GET['type'] ?? $_GET['action'] ?? 'all'; // all | login | action

if ($limit > 200) $limit = 200;

try {
    // Cek apakah tabel ada
    $check = $conn->query("SHOW TABLES LIKE 'admin_activity_logs'");
    if ($check->num_rows === 0) {
        echo json_encode(['success' => true, 'data' => [], 'total' => 0, 'message' => 'Tabel log belum ada']);
        exit;
    }

    $whereClause = '';
    $filterAction = null;
    if ($type === 'login') {
        $whereClause = "WHERE l.action = 'login'";
    } elseif ($type !== 'all') {
        $whereClause = "WHERE l.action = ?";
        $filterAction = $type;
    }

    $sql = "SELECT 
                l.id,
                l.action,
                l.description,
                l.ip_address,
                l.user_id,
                l.created_at,
                COALESCE(a.username, u.username, CONCAT('User#', l.user_id)) as username,
                COALESCE(a.full_name, u.full_name) as full_name
            FROM admin_activity_logs l
            LEFT JOIN administrators a ON l.user_id = a.id
            LEFT JOIN admin_users u ON l.user_id = u.id
            $whereClause
            ORDER BY l.created_at DESC
            LIMIT ? OFFSET ?";

    $stmt = $conn->prepare($sql);
    if ($filterAction !== null) {
        $stmt->bind_param('sii', $filterAction, $limit, $offset);
    } else {
        $stmt->bind_param('ii', $limit, $offset);
    }
    $stmt->execute();
    $result = $stmt->get_result();

    $logs = [];
    while ($row = $result->fetch_assoc()) {
        $logs[] = $row;
    }

    // Total count
    $countSql = "SELECT COUNT(*) as total FROM admin_activity_logs $whereClause";
    $countStmt = $conn->prepare($countSql);
    if ($filterAction !== null) {
        $countStmt->bind_param('s', $filterAction);
    }
    $countStmt->execute();
    $countRes = $countStmt->get_result();
    $total = $countRes ? $countRes->fetch_assoc()['total'] : 0;

    echo json_encode([
        'success' => true,
        'data'    => $logs,
        'total'   => (int)$total,
        'limit'   => $limit,
        'offset'  => $offset
    ]);

} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
