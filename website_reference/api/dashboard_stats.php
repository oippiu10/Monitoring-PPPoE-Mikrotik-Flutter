<?php
/**
 * Dashboard Statistics API
 * Returns overview statistics for dashboard
 */

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/auth/require_auth.php';
require_once __DIR__ . '/mikrotik_cache.php';
require_once __DIR__ . '/routerosAPI.php';

$router_id = trim($_GET['router_id'] ?? '');

if (empty($router_id)) {
    echo json_encode([
        'success' => false,
        'message' => 'Parameter router_id wajib untuk memfilter data.'
    ]);
    exit;
}

$cache = new MikrotikCache($conn);
$router_id_esc = $conn->real_escape_string($router_id);

// --- Resolving ID & Connection Info ---
$routerInfo = null;
if (is_numeric($router_id)) {
    $rLookup = $conn->query("SELECT * FROM mikrotik_routers WHERE id = $router_id_esc LIMIT 1");
    if ($rLookup && $row = $rLookup->fetch_assoc()) {
        $routerInfo = $row;
    }
} else {
    // Try lookup by software_id or name
    $rLookup = $conn->query("SELECT * FROM mikrotik_routers WHERE (software_id = '$router_id_esc' OR name = '$router_id_esc') LIMIT 1");
    if ($rLookup && $row = $rLookup->fetch_assoc()) {
        $routerInfo = $row;
    }
}

// Gunakan software_id jika ada, karena tabel users dan payments menggunakan software_id
if ($routerInfo && !empty($routerInfo['software_id'])) {
    $router_id = $routerInfo['software_id'];
}
$router_id_esc = $conn->real_escape_string($router_id);

try {
    // Total User (Registered in DB)
    $sumQuery = "SELECT COUNT(*) as total_users FROM users WHERE router_id = '$router_id_esc'";
    $sumRes = $conn->query($sumQuery);
    $totalUsers = $sumRes ? $sumRes->fetch_assoc()['total_users'] : 0;

    // Total Revenue (Bulan Ini)
    $bulanIni = date('Y-m');
    $revQuery = "
        SELECT SUM(amount) as revenue
        FROM payments
        WHERE DATE_FORMAT(payment_date, '%Y-%m') = '$bulanIni' AND router_id = '$router_id_esc'
    ";
    $revRes = $conn->query($revQuery);
    $revenue = $revRes ? $revRes->fetch_assoc()['revenue'] : 0;

    // Fetch Active PPP Sessions & Secrets from MikroTik (with Cache)
    $activeSessions = [];
    $onlineUsersCount = 0;
    $totalSecrets = 0;
    $profileDistribution = [];

    if ($routerInfo) {
        try {
            // Fungsi fetch: langsung konek ke MikroTik secara on-demand
            $fetchFromMk = function($command) use ($routerInfo) {
                $api = new RouterosAPI();
                $api->port = intval($routerInfo['port'] ?? 8728);
                $api->timeout = 5;
                if ($api->connect($routerInfo['host'], $routerInfo['username'], $routerInfo['password'])) {
                    $data = $api->comm($command);
                    $api->disconnect();
                    return $data;
                }
                return [];
            };

            // PPP Active
            $resActive = $cache->getOrFetch("mt_{$router_id}_ppp_active", 10, function() use ($fetchFromMk) {
                return $fetchFromMk('/ppp/active/print') ?? [];
            });
            $allActive = is_array($resActive['data'] ?? null) ? $resActive['data'] : [];
            $onlineUsersCount = count($allActive);

            if (!empty($allActive)) {
                // Sort by uptime (newest first) before slicing
                usort($allActive, function($a, $b) {
                    $parse = function($uptime) {
                        if (!$uptime) return 0;
                        $total = 0;
                        if (preg_match('/(\d+)w/', $uptime, $m)) $total += $m[1] * 604800;
                        if (preg_match('/(\d+)d/', $uptime, $m)) $total += $m[1] * 86400;
                        if (preg_match('/(\d+)h/', $uptime, $m)) $total += $m[1] * 3600;
                        if (preg_match('/(\d+)m/', $uptime, $m)) $total += $m[1] * 60;
                        if (preg_match('/(\d+)s/', $uptime, $m)) $total += $m[1];
                        // Also handle HH:MM:SS
                        if (strpos($uptime, ':') !== false) {
                            $parts = explode(':', $uptime);
                            $timePart = end($parts);
                            if (preg_match('/(\d+):(\d+):(\d+)/', $timePart, $m)) {
                                $total += $m[1] * 3600 + $m[2] * 60 + $m[3];
                            }
                        }
                        return $total;
                    };
                    return $parse($a['uptime'] ?? '') - $parse($b['uptime'] ?? '');
                });
            }

            $activeSessions = array_slice($allActive, 0, 10);

            // PPP Secret
            $resSecret = $cache->getOrFetch("mt_{$router_id}_ppp_secret", 300, function() use ($fetchFromMk) {
                return $fetchFromMk('/ppp/secret/print') ?? [];
            });
            $secretsData = is_array($resSecret['data'] ?? null) ? $resSecret['data'] : [];
            $totalSecrets = count($secretsData);
            
            // Calculate Profile Distribution
            foreach ($secretsData as $s) {
                $profName = $s['profile'] ?? 'default';
                if (!isset($profileDistribution[$profName])) {
                    $profileDistribution[$profName] = 0;
                }
                $profileDistribution[$profName]++;
            }

            // MikroTik Logs
            $resLogs = $cache->getOrFetch("mt_{$router_id}_log", 20, function() use ($fetchFromMk) {
                $all = $fetchFromMk('/log/print');
                return is_array($all) ? array_slice($all, -500) : [];
            });
            $mikrotikLogs = array_reverse(is_array($resLogs['data'] ?? null) ? $resLogs['data'] : []);
            $mikrotikLogs = array_slice($mikrotikLogs, 0, 100);
        } catch (Exception $eMk) {
            // Log MikroTik error but continue with DB data
            error_log("MikroTik Fetch Error: " . $eMk->getMessage());
        }
    }

    // Belum Bayar
    $bulan_num = intval(date('m'));
    $tahun_num = intval(date('Y'));
    
    $unpaidQuery = "
        SELECT COUNT(u.id) as pending
        FROM users u
        LEFT JOIN invoices inv ON inv.user_id = u.id AND inv.month = $bulan_num AND inv.year = $tahun_num AND inv.router_id = u.router_id
        LEFT JOIN payments p ON p.user_id = u.id 
            AND DATE_FORMAT(p.payment_date, '%Y-%m') = '$bulanIni'
        WHERE p.id IS NULL AND (inv.status IS NULL OR inv.status != 'isolir') AND u.router_id = '$router_id_esc'
    ";
    $unpaidRes = $conn->query($unpaidQuery);
    $pendingPayments = $unpaidRes ? $unpaidRes->fetch_assoc()['pending'] : 0;

    // Revenue & Expense History (Last 6 Months)
    $revenueHistoryQuery = "
        SELECT DATE_FORMAT(payment_date, '%Y-%m') as month, SUM(amount) as total
        FROM payments
        WHERE router_id = '$router_id_esc' AND payment_date >= DATE_SUB(CURDATE(), INTERVAL 5 MONTH)
        GROUP BY month
    ";
    $revHistRes = $conn->query($revenueHistoryQuery);

    $expenseHistoryQuery = "
        SELECT DATE_FORMAT(spent_at, '%Y-%m') as month, SUM(amount) as total
        FROM expenses
        WHERE router_id = '$router_id_esc' AND spent_at >= DATE_SUB(CURDATE(), INTERVAL 5 MONTH)
        GROUP BY month
    ";
    $expHistRes = $conn->query($expenseHistoryQuery);

    $historyData = [];
    
    // Initialize 6 months history
    for ($i = 5; $i >= 0; $i--) {
        $m = date('Y-m', strtotime("-$i months"));
        $historyData[$m] = [
            'month' => date('M Y', strtotime($m . '-01')),
            'revenue' => 0,
            'expense' => 0
        ];
    }

    if ($revHistRes) {
        while ($r = $revHistRes->fetch_assoc()) {
            if (isset($historyData[$r['month']])) {
                $historyData[$r['month']]['revenue'] = (float)$r['total'];
            }
        }
    }
    if ($expHistRes) {
        while ($r = $expHistRes->fetch_assoc()) {
            if (isset($historyData[$r['month']])) {
                $historyData[$r['month']]['expense'] = (float)$r['total'];
            }
        }
    }
    
    $revenueHistory = array_values($historyData);

    // Get recent activities
    $activitiesQuery = "SELECT 
                            u.username,
                            al.action,
                            al.created_at as raw_time
                        FROM admin_activity_logs al
                        LEFT JOIN admin_users u ON al.user_id = u.id
                        ORDER BY al.created_at DESC
                        LIMIT 5";
    $activitiesResult = $conn->query($activitiesQuery);
    $activities = [];
    if ($activitiesResult) {
        while ($row = $activitiesResult->fetch_assoc()) {
            $user = !empty($row['username']) ? $row['username'] : 'System';
            $action = !empty($row['action']) ? $row['action'] : 'Background Task';
            
            $activities[] = [
                'action' => $user . ' - ' . $action,
                'time' => date('H:i', strtotime($row['raw_time']))
            ];
        }
    }

    // JSON response
    $response = [
        'success' => true,
        'data' => [
            'total_users' => (int) $totalUsers,
            'total_secrets' => (int) $totalSecrets,
            'online_users' => (int) $onlineUsersCount,
            'revenue' => (float) $revenue,
            'pending_payments' => (int) $pendingPayments,
            'profile_distribution' => $profileDistribution,
            'revenue_history' => $revenueHistory,
            'active_sessions' => $activeSessions,
            'recent_activities' => $activities,
            'mikrotik_logs' => $mikrotikLogs ?? []
        ],
        'timestamp' => date('Y-m-d H:i:s')
    ];

    echo json_encode($response);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}
?>