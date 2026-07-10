<?php
/**
 * Get All Users Paginated — Web Admin Panel
 * Membaca dari tabel users MySQL, digabung dengan data Mikrotik live.
 */
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
error_reporting(0);

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/routerosAPI.php';
require_once __DIR__ . '/mikrotik_cache.php';

$page    = max(1, intval($_GET['page']    ?? 1));
$perPage = max(5, min(100, intval($_GET['per_page'] ?? 20)));
$search  = trim($_GET['search']  ?? '');
$profile = trim($_GET['profile'] ?? '');
$odp     = trim($_GET['odp'] ?? '');
$statusFilter = trim($_GET['status']  ?? ''); // 'active'/'disabled'/''

// Sorting logic
$validSorts = ['id', 'username', 'tanggal_dibuat', 'redaman', 'wa', 'tanggal_tagihan', 'profile', 'odp_id'];
$sortBy = isset($_GET['sort_by']) && in_array(strtolower($_GET['sort_by']), $validSorts) ? strtolower($_GET['sort_by']) : 'username';
$sortOrder = isset($_GET['sort_order']) && strtolower($_GET['sort_order']) === 'desc' ? 'DESC' : 'ASC';

// --- Mikrotik Fetch ---
$mtSecrets = [];
$mtActive = [];
$mtProfiles = [];
$routerHost = trim($_GET['router_host'] ?? '');
$routerId = trim($_GET['router_id'] ?? '');

if ($routerHost !== '') {
    $routerPort = intval($_GET['router_port'] ?? 8728);
    $routerUser = trim($_GET['router_user'] ?? 'admin');
    $routerPass = trim($_GET['router_pass'] ?? '');

    $cache = new MikrotikCache($conn);

    $apiCall = function($cmd) use ($routerHost, $routerPort, $routerUser, $routerPass) {
        $api = new RouterosAPI();
        $api->port = $routerPort;
        if ($api->connect($routerHost, $routerUser, $routerPass)) {
            $res = $api->comm($cmd);
            $api->disconnect();
            return $res;
        }
        return [];
    };

    $sRes = $cache->getOrFetch("mt_{$routerHost}_{$routerPort}_ppp_secret", 2, function() use ($apiCall) { return $apiCall('/ppp/secret/print'); });
    $aRes = $cache->getOrFetch("mt_{$routerHost}_{$routerPort}_ppp_active", 1, function() use ($apiCall) { return $apiCall('/ppp/active/print'); });
    $pRes = $cache->getOrFetch("mt_{$routerHost}_{$routerPort}_ppp_profile", 10, function() use ($apiCall) { return $apiCall('/ppp/profile/print'); });
    
    $mtSecrets = is_array($sRes['data'] ?? null) ? $sRes['data'] : [];
    $mtActive = is_array($aRes['data'] ?? null) ? $aRes['data'] : [];
    $mtProfiles = is_array($pRes['data'] ?? null) ? $pRes['data'] : [];
}

$secretMap = [];
$totalDisabled = 0;
foreach ($mtSecrets as $sec) {
    $secretMap[$sec['name']] = $sec;
    if (($sec['disabled'] ?? 'false') === 'true') {
        $totalDisabled++;
    }
}
$activeMap = [];
foreach ($mtActive as $act) {
    if (isset($act['name'])) $activeMap[$act['name']] = $act;
}
$profileMap = [];
foreach ($mtProfiles as $prof) {
    if (isset($prof['name'])) $profileMap[$prof['name']] = $prof;
}
$totalActive = count($activeMap);

// --- Fetch all matching DB users ---
try {
    $where  = [];
    $params = [];
    $types  = '';
    
    if ($routerId !== '') {
        $where[] = 'u.router_id = ?';
        $params[] = $routerId;
        $types .= 's';
    }

    if ($search !== '') {
        $where[] = '(u.username LIKE ? OR u.profile LIKE ? OR u.wa LIKE ? OR u.alamat LIKE ?)';
        $like    = "%$search%";
        $params  = array_merge($params, [$like, $like, $like, $like]);
        $types  .= 'ssss';
    }
    if ($profile !== '') {
        $where[] = 'u.profile = ?';
        $params[] = $profile;
        $types   .= 's';
    }
    if ($odp !== '') {
        $where[] = 'u.odp_id = ?';
        $params[] = $odp;
        $types   .= 's';
    }

    $whereSQL = $where ? 'WHERE ' . implode(' AND ', $where) : '';
    
    $dataSQL  = "SELECT
                    u.id, u.username, u.password, u.profile, u.wa, u.maps, u.lat, u.lng, u.foto,
                    DATE_FORMAT(u.tanggal_dibuat, '%Y-%m-%d %H:%i:%s') as tanggal_dibuat, u.odp_id, u.created_at, u.updated_at, u.alamat, u.redaman, u.tanggal_tagihan
                 FROM users u
                 $whereSQL
                 ORDER BY u.$sortBy $sortOrder";
                 
    $dataStmt = $conn->prepare($dataSQL);
    if ($types) {
        $dataStmt->bind_param($types, ...$params);
    }
    $dataStmt->execute();
    $result = $dataStmt->get_result();

    $allFilteredUsers = [];
    $dbTotal = 0;
    while ($row = $result->fetch_assoc()) {
        $dbTotal++;
        $uname = $row['username'];
        $row['remote-address'] = '-';
        $row['rate-limit'] = '-';
        $row['disabled'] = 'no';
        $row['status'] = 'offline';
        
        if (isset($secretMap[$uname])) {
            $sec = $secretMap[$uname];
            $row['remote-address'] = $sec['remote-address'] ?? '-';
            $row['disabled'] = (($sec['disabled'] ?? 'false') === 'true') ? 'yes' : 'no';
            
            $pname = $sec['profile'] ?? '';
            if (isset($profileMap[$pname]) && !empty($profileMap[$pname]['rate-limit'])) {
                $row['rate-limit'] = $profileMap[$pname]['rate-limit'];
            }
        }
        
        $isOnline = isset($activeMap[$uname]);
        if ($isOnline) {
            $row['remote-address'] = $activeMap[$uname]['address'] ?? $row['remote-address'];
            $row['status'] = 'online';
        }
        
        // Check filtering
        $passStatusFilter = true;
        if ($statusFilter === 'active' && !$isOnline) $passStatusFilter = false;
        if ($statusFilter === 'disabled' && $row['disabled'] !== 'yes') $passStatusFilter = false;
        
        if ($passStatusFilter) {
            $allFilteredUsers[] = $row;
        }
    }
    $dataStmt->close();

    // Limit / Offset
    $totalFiltered = count($allFilteredUsers);
    $offset = ($page - 1) * $perPage;
    $paginatedUsers = array_slice($allFilteredUsers, $offset, $perPage);

    // Profile list
    $profiles = array_values(array_unique(array_map(function($p) { return $p['name']; }, $mtProfiles)));
    if (empty($profiles)) {
        // fallback to DB profiles if mikrotik empty
        $profileRes = $conn->query("SELECT DISTINCT profile FROM users WHERE profile IS NOT NULL AND profile != '' ORDER BY profile");
        while ($pr = $profileRes->fetch_assoc()) $profiles[] = $pr['profile'];
    }

    // ODP List
    $odps = [];
    $odpRes = $conn->query("SELECT DISTINCT odp_id FROM users WHERE odp_id IS NOT NULL AND odp_id != '' ORDER BY odp_id");
    while ($or = $odpRes->fetch_assoc()) $odps[] = $or['odp_id'];

    // Unpaid count
    $bulan = date('Y-m');
    $unpaidRes = $conn->query("
        SELECT COUNT(DISTINCT u.username) as unpaid
        FROM users u
        LEFT JOIN payments p ON p.user_id = u.id
            AND DATE_FORMAT(p.payment_date, '%Y-%m') = '$bulan'
        WHERE p.id IS NULL
    ");
    $unpaid = ($unpaidRes ? $unpaidRes->fetch_assoc()['unpaid'] : 0) ?? 0;

    echo json_encode([
        'success'  => true,
        'data'     => $paginatedUsers,
        'total'    => $totalFiltered,
        'page'     => $page,
        'per_page' => $perPage,
        'profiles' => $profiles,
        'odps'     => $odps,
        'unpaid'   => (int)$unpaid,
        'active'   => $totalActive,
        'disabled' => $totalDisabled,
        'total_all' => $dbTotal, // Total user in DB matching search/router (ignoring status)
    ], JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
