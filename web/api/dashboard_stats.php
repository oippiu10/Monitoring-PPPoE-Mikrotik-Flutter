<?php
/**
 * Dashboard Statistics API
 * Returns overview statistics for dashboard
 */

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');

require_once __DIR__ . '/config.php';

$router_id = trim($_GET['router_id'] ?? '');
$whereUser = $router_id !== '' ? "WHERE router_id = '" . $conn->real_escape_string($router_id) . "'" : "";
$wherePayment = $router_id !== '' ? "WHERE u.router_id = '" . $conn->real_escape_string($router_id) . "'" : "";
$andPayment = $router_id !== '' ? "AND u.router_id = '" . $conn->real_escape_string($router_id) . "'" : "";

try {
    // Total User
    $sumQuery = "SELECT COUNT(*) as total_users FROM users $whereUser";
    $sumRes = $conn->query($sumQuery);
    $totalUsers = $sumRes ? $sumRes->fetch_assoc()['total_users'] : 0;

    // Total Revenue (Bulan Ini)
    $bulanIni = date('Y-m');
    $revQuery = "
        SELECT SUM(p.amount) as revenue
        FROM payments p
        JOIN users u ON p.user_id = u.id
        WHERE DATE_FORMAT(p.payment_date, '%Y-%m') = '$bulanIni' $andPayment
    ";
    $revRes = $conn->query($revQuery);
    $revenue = $revRes ? $revRes->fetch_assoc()['revenue'] : 0;

    // Total Active User & Inactive di-Bypass karena kolom disabled/status tidak ada di MySQL
    // Akan diambil secara live via Mikrotik API di frontend
    $onlineUsers = 0;
    
    // Belum Bayar (Belum ada catatan di tabel payments untuk bulan ini)
    $unpaidQuery = "
        SELECT COUNT(u.id) as pending
        FROM users u
        LEFT JOIN payments p ON p.user_id = u.id 
            AND DATE_FORMAT(p.payment_date, '%Y-%m') = '$bulanIni'
        WHERE p.id IS NULL $andPayment
    ";
    $unpaidRes = $conn->query($unpaidQuery);
    $pendingPayments = $unpaidRes ? $unpaidRes->fetch_assoc()['pending'] : 0;
    
    // Get traffic data (last 7 days) - demo for now
    $trafficData = [];
    $days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for ($i = 0; $i < 7; $i++) {
        $trafficData[] = [
            'date' => $days[$i],
            'upload' => rand(50, 100),
            'download' => rand(20, 90)
        ];
    }
    
    // Status distribution di bypass
    $statusData = ['online' => 0, 'offline' => 0, 'disabled' => 0];
    
    // Get recent activities from admin logs
    $activitiesQuery = "SELECT 
                            CONCAT(u.username, ' - ', al.action) as action,
                            CASE 
                                WHEN TIMESTAMPDIFF(MINUTE, al.created_at, NOW()) < 1 THEN 'Just now'
                                WHEN TIMESTAMPDIFF(MINUTE, al.created_at, NOW()) < 60 THEN CONCAT(TIMESTAMPDIFF(MINUTE, al.created_at, NOW()), ' minutes ago')
                                WHEN TIMESTAMPDIFF(HOUR, al.created_at, NOW()) < 24 THEN CONCAT(TIMESTAMPDIFF(HOUR, al.created_at, NOW()), ' hours ago')
                                ELSE CONCAT(TIMESTAMPDIFF(DAY, al.created_at, NOW()), ' days ago')
                            END as time,
                            CASE al.action
                                WHEN 'login' THEN 'sign-in-alt'
                                WHEN 'logout' THEN 'sign-out-alt'
                                WHEN 'add_user' THEN 'user-plus'
                                WHEN 'delete_user' THEN 'user-minus'
                                WHEN 'payment' THEN 'dollar-sign'
                                ELSE 'info-circle'
                            END as icon,
                            CASE al.action
                                WHEN 'login' THEN 'blue'
                                WHEN 'logout' THEN 'gray'
                                WHEN 'add_user' THEN 'green'
                                WHEN 'delete_user' THEN 'red'
                                WHEN 'payment' THEN 'orange'
                                ELSE 'blue'
                            END as color
                        FROM admin_activity_logs al
                        LEFT JOIN admin_users u ON al.user_id = u.id
                        ORDER BY al.created_at DESC
                        LIMIT 10";
    $activitiesResult = $conn->query($activitiesQuery);
    $activities = [];
    while ($row = $activitiesResult->fetch_assoc()) {
        $activities[] = $row;
    }
    
    // If no activities, show default message
    if (empty($activities)) {
        $activities = [
            [
                'action' => 'System initialized',
                'time' => 'Just now',
                'icon' => 'check-circle',
                'color' => 'green'
            ]
        ];
    }
    
    $conn->close();
    
    echo json_encode([
        'success' => true,
        'data' => [
            'total_users' => (int)$totalUsers,
            'online_users' => (int)$onlineUsers,
            'revenue' => (float)$revenue,
            'pending_payments' => (int)$pendingPayments,
            'traffic_data' => $trafficData,
            'status_distribution' => [
                'online' => (int)($statusData['online'] ?? 0),
                'offline' => (int)($statusData['offline'] ?? 0),
                'disabled' => (int)($statusData['disabled'] ?? 0)
            ],
            'recent_activities' => $activities
        ],
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}
?>
