<?php
/**
 * Dashboard Statistics API
 * Returns overview statistics for dashboard
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once __DIR__ . '/config.php';

try {
    // Get total users from database
    $totalUsersQuery = "SELECT COUNT(*) as total FROM users";
    $totalUsersResult = $conn->query($totalUsersQuery);
    $totalUsers = $totalUsersResult->fetch_assoc()['total'] ?? 0;
    
    // Get online users (active status)
    $onlineUsersQuery = "SELECT COUNT(*) as online FROM users WHERE status = 'active'";
    $onlineUsersResult = $conn->query($onlineUsersQuery);
    $onlineUsers = $onlineUsersResult->fetch_assoc()['online'] ?? 0;
    
    // Get revenue this month
    $currentMonth = date('Y-m');
    $revenueQuery = "SELECT COALESCE(SUM(amount), 0) as revenue 
                     FROM payments 
                     WHERE DATE_FORMAT(payment_date, '%Y-%m') = '$currentMonth' 
                     AND status = 'paid'";
    $revenueResult = $conn->query($revenueQuery);
    $revenue = $revenueResult->fetch_assoc()['revenue'] ?? 0;
    
    // Get pending payments
    $pendingQuery = "SELECT COUNT(*) as pending 
                     FROM payments 
                     WHERE status = 'pending' OR status IS NULL OR status = 'unpaid'";
    $pendingResult = $conn->query($pendingQuery);
    $pendingPayments = $pendingResult->fetch_assoc()['pending'] ?? 0;
    
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
    
    // Get user status distribution
    $statusQuery = "SELECT 
                        SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as online,
                        SUM(CASE WHEN status = 'inactive' OR status IS NULL THEN 1 ELSE 0 END) as offline,
                        SUM(CASE WHEN status = 'disabled' THEN 1 ELSE 0 END) as disabled
                    FROM users";
    $statusResult = $conn->query($statusQuery);
    $statusData = $statusResult->fetch_assoc();
    
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
