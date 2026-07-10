<?php
/**
 * Get Activity Logs API
 */
session_start();
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');

require_once __DIR__ . '/config.php';

$limit  = intval($_GET['limit']  ?? 50);
$offset = intval($_GET['offset'] ?? 0);
$type   = $_GET['type'] ?? 'all'; // all | login | action

if ($limit > 200) $limit = 200;

try {
    // Cek apakah tabel ada
    $check = $conn->query("SHOW TABLES LIKE 'admin_activity_logs'");
    if ($check->num_rows === 0) {
        echo json_encode(['success' => true, 'data' => [], 'total' => 0, 'message' => 'Tabel log belum ada']);
        exit;
    }

    $whereClause = '';
    if ($type === 'login') {
        $whereClause = "WHERE l.action = 'login'";
    } elseif ($type !== 'all') {
        $stmt_where = $conn->prepare("WHERE l.action = ?");
    }

    $sql = "SELECT 
                l.id,
                l.action,
                l.description,
                l.ip_address,
                l.created_at,
                u.username,
                u.full_name
            FROM admin_activity_logs l
            LEFT JOIN admin_users u ON l.user_id = u.id
            $whereClause
            ORDER BY l.created_at DESC
            LIMIT ? OFFSET ?";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ii", $limit, $offset);
    $stmt->execute();
    $result = $stmt->get_result();

    $logs = [];
    while ($row = $result->fetch_assoc()) {
        $logs[] = $row;
    }

    // Total count
    $countSql = "SELECT COUNT(*) as total FROM admin_activity_logs $whereClause";
    $countRes = $conn->query($countSql);
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
