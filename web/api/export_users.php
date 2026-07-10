<?php
/**
 * Export Users to CSV
 */
header('Access-Control-Allow-Origin: *');
error_reporting(0);

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/routerosAPI.php';
require_once __DIR__ . '/mikrotik_cache.php';

$search  = trim($_GET['search']  ?? '');
$profile = trim($_GET['profile'] ?? '');
$statusFilter = trim($_GET['status']  ?? ''); // 'active'/'disabled'/''

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
foreach ($mtSecrets as $sec) {
    $secretMap[$sec['name']] = $sec;
}
$activeMap = [];
foreach ($mtActive as $act) {
    if (isset($act['name'])) $activeMap[$act['name']] = $act;
}
$profileMap = [];
foreach ($mtProfiles as $prof) {
    if (isset($prof['name'])) $profileMap[$prof['name']] = $prof;
}

// --- Fetch DB and export ---
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

    $whereSQL = $where ? 'WHERE ' . implode(' AND ', $where) : '';
    
    $dataSQL  = "SELECT
                    u.username, u.profile, u.wa,
                    u.alamat, u.tanggal_tagihan, u.tanggal_dibuat
                 FROM users u
                 $whereSQL
                 ORDER BY u.username ASC";
                 
    $dataStmt = $conn->prepare($dataSQL);
    if ($types) {
        $dataStmt->bind_param($types, ...$params);
    }
    $dataStmt->execute();
    $result = $dataStmt->get_result();

    $exportData = [];
    while ($row = $result->fetch_assoc()) {
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
        
        $passStatusFilter = true;
        if ($statusFilter === 'active' && !$isOnline) $passStatusFilter = false;
        if ($statusFilter === 'disabled' && $row['disabled'] !== 'yes') $passStatusFilter = false;
        
        if ($passStatusFilter) {
            $exportData[] = [
                $row['username'],
                $row['profile'],
                $row['alamat'],
                $row['wa'],
                $row['tanggal_tagihan'],
                $row['remote-address'],
                $row['status'],
                $row['disabled'],
                $row['rate-limit']
            ];
        }
    }
    $dataStmt->close();

    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename="Users_Export_' . date('Y-m-d_His') . '.csv"');
    
    $out = fopen('php://output', 'w');
    fputcsv($out, ['Username', 'Profile', 'Alamat', 'No. WhatsApp', 'Tanggal Tagihan', 'IP Address', 'Aktif', 'Disabled', 'Rate Limit']);
    
    foreach ($exportData as $d) {
        fputcsv($out, $d);
    }
    fclose($out);
    exit;

} catch (Exception $e) {
    http_response_code(500);
    echo "Error: " . $e->getMessage();
}
?>
