<?php
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/routerosAPI.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$router_id = $_GET['router_id'] ?? null;
if (!$router_id) {
    echo json_encode(['success' => false, 'message' => 'Router ID wajib diisi', 'logs' => ["[!] ERROR: Router ID wajib diisi"]]);
    exit();
}

$stmt = $conn->prepare("SELECT host, port, username, password FROM mikrotik_routers WHERE id = ?");
$stmt->bind_param("i", $router_id);
$stmt->execute();
$router = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$router) {
    echo json_encode(['success' => false, 'message' => 'Router tidak ditemukan', 'logs' => ["[!] ERROR: Router tidak ditemukan di database"]]);
    exit();
}

$host = $router['host'];
$port = intval($router['port'] ?? 8728);
$username = $router['username'];
$password = $router['password'];

$logs = [];
function addLog($msg) {
    global $logs;
    $time = date('g:i:s A');
    $logs[] = "[$time] $msg";
}

addLog("Menghubungkan ke $host:$port...");

try {
    $api = new RouterosAPI();
    $api->port = $port;
    $api->timeout = 5;

    addLog("Mencoba login sebagai '$username'...");

    if ($api->connect($host, $username, $password)) {
        addLog("✅ Login berhasil!");
        
        addLog("Mengambil informasi sistem...");
        $resource = $api->comm('/system/resource/print');
        $license  = $api->comm('/system/license/print');
        
        $board = $resource[0]['board-name'] ?? 'Unknown';
        $ver   = $resource[0]['version'] ?? 'Unknown';
        $sid   = $license[0]['software-id'] ?? 'Unknown';
        
        addLog("✅ Info Router: $board (RouterOS v$ver)");
        addLog("✅ Software ID: $sid");
        
        addLog("Mengetes komunikasi data...");
        $interfaces = $api->comm('/interface/print');
        $count = count($interfaces);
        addLog("✅ API Test: Ditemukan $count interface");
        
        $api->disconnect();
        addLog("✅ Koneksi ditutup dengan aman. Semua pengujian lulus.");

        echo json_encode([
            'success' => true,
            'logs' => $logs
        ]);
    } else {
        addLog("❌ Gagal login! Cek IP, Port API, Username, dan Password.");
        addLog("[!] ERROR: Connection refused / timeout / wrong credentials.");
        echo json_encode(['success' => false, 'logs' => $logs]);
    }
} catch (Exception $e) {
    addLog("[!] ERROR: " . $e->getMessage());
    echo json_encode(['success' => false, 'logs' => $logs]);
}
?>
