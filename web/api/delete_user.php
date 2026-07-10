<?php
/**
 * Delete User — Hapus user PPPoE dari DB dan Mikrotik
 */
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/routerosAPI.php';
require_once __DIR__ . '/mikrotik_cache.php';

$input    = json_decode(file_get_contents('php://input'), true);

$username = trim($input['username'] ?? '');

$routerHost = $input['router_host'] ?? null;
$routerPort = intval($input['router_port'] ?? 8728);
$routerUser = $input['router_user'] ?? 'admin';
$routerPass = $input['router_pass'] ?? '';

try {
    // Ambil user_id terlebih dahulu
    $stmtId = $conn->prepare("SELECT id FROM users WHERE username = ?");
    $stmtId->bind_param('s', $username);
    $stmtId->execute();
    $resId = $stmtId->get_result();
    $userId = $resId->num_rows > 0 ? $resId->fetch_assoc()['id'] : null;
    $stmtId->close();

    // Hapus payments terkait (menggunakan user_id)
    if ($userId) {
        $stmt2 = $conn->prepare("DELETE FROM payments WHERE user_id = ?");
        $stmt2->bind_param('i', $userId);
        $stmt2->execute();
        $stmt2->close();
    }

    // Hapus dari DB
    $stmt = $conn->prepare("DELETE FROM users WHERE username = ?");
    $stmt->bind_param('s', $username);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close();

    // Sync hapus ke Mikrotik jika ada router config
    if ($routerHost) {
        $api = new RouterosAPI();
        $api->port = $routerPort;
        if ($api->connect($routerHost, $routerUser, $routerPass)) {
            $secrets = $api->comm('/ppp/secret/print', ['?name' => $username]);
            if (!empty($secrets[0]['.id'])) {
                $api->comm('/ppp/secret/remove', ['numbers' => $secrets[0]['.id']]);
            }
            $api->disconnect();
            (new MikrotikCache($conn))->invalidate("mt_{$routerHost}_{$routerPort}_ppp_secret");
        }
    }

    if ($affected === 0) {
        echo json_encode(['success'=>false,'message'=>"User '$username' tidak ditemukan di database"]);
    } else {
        echo json_encode(['success'=>true,'message'=>"User $username berhasil dihapus"]);
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success'=>false,'message'=>'Server error: '.$e->getMessage()]);
}
?>
