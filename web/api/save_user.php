<?php
/**
 * Save User — Tambah/Edit/Enable/Disable user PPPoE
 * Operasi dilakukan via Mikrotik API dan disinkronisasi ke database
 */
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/routerosAPI.php';
require_once __DIR__ . '/mikrotik_cache.php';

$input = json_decode(file_get_contents('php://input'), true);
if (!$input) { echo json_encode(['success'=>false,'message'=>'Data tidak valid']); exit; }

$action   = $input['action']   ?? 'add';
$username = trim($input['username'] ?? '');

if (!$username) {
    echo json_encode(['success'=>false,'message'=>'Username wajib diisi']); exit;
}

// Ambil konfigurasi router dari localStorage-equivalent: gunakan router pertama dari DB
// atau bisa juga dari POST body jika dikirim
$routerHost = $input['router_host'] ?? null;
$routerPort = intval($input['router_port'] ?? 8728);
$routerUser = $input['router_user'] ?? 'admin';
$routerPass = $input['router_pass'] ?? '';

// Jika router tidak dikirim dari body, cari dari localStorage via session / atau gunakan
// default yang disimpan? Untuk sekarang: skip Mikrotik, hanya update DB
// (Mikrotik sync bisa dilakukan manual via Sync button)
$syncMikrotik = ($routerHost !== null && $routerHost !== '');

try {
    // ── HANDLE ENABLE/DISABLE ──
    if ($action === 'enable' || $action === 'disable') {
        $disabled = ($action === 'disable') ? 'yes' : 'no';

        // Update DB
        $stmt = $conn->prepare("UPDATE users SET disabled = ?, updated_at = NOW() WHERE username = ?");
        $stmt->bind_param('ss', $disabled, $username);
        $stmt->execute();
        $stmt->close();

        // Sync ke Mikrotik jika ada konfigurasi router
        if ($syncMikrotik) {
            $api = new RouterosAPI();
            $api->port = $routerPort;
            if ($api->connect($routerHost, $routerUser, $routerPass)) {
                // Cari .id user PPPoE
                $secrets = $api->comm('/ppp/secret/print', ['?name' => $username]);
                if (!empty($secrets[0]['.id'])) {
                    $id = $secrets[0]['.id'];
                    if ($action === 'disable') {
                        $api->comm('/ppp/secret/disable', ['numbers' => $id]);
                    } else {
                        $api->comm('/ppp/secret/enable',  ['numbers' => $id]);
                    }
                }
                $api->disconnect();
                // Invalidasi cache
                (new MikrotikCache($conn))->invalidate("mt_{$routerHost}_{$routerPort}_ppp_secret");
            }
        }

        echo json_encode(['success'=>true,'message'=>"User $username berhasil " . ($action === 'disable' ? 'dinonaktifkan' : 'diaktifkan')]);
        exit;
    }

    // ── HANDLE ADD / EDIT ──
    $password = $input['password'] ?? '';
    $profile  = $input['profile']  ?? '';
    $disabled = ($input['disabled'] ?? 'no') === 'yes' ? 'yes' : 'no';
    $nama     = $input['nama']     ?? '';
    $noTelp   = $input['no_telp']  ?? '';
    $alamat   = $input['alamat']   ?? '';
    $tanggalTagihan = intval($input['tanggal_tagihan'] ?? 0);
    $remoteAddr     = $input['remote_address'] ?? '';

    if ($action === 'add') {
        if (!$password || !$profile) {
            echo json_encode(['success'=>false,'message'=>'Password dan profile wajib diisi']); exit;
        }
        // Cek sudah ada?
        $chk = $conn->prepare("SELECT id FROM users WHERE username = ?");
        $chk->bind_param('s',$username); $chk->execute();
        if ($chk->get_result()->num_rows > 0) {
            echo json_encode(['success'=>false,'message'=>"Username '$username' sudah ada"]); exit;
        }
        $chk->close();

        $routerId = $input['router_id'] ?? '';
        $stmt = $conn->prepare("INSERT INTO users (router_id,username,password,profile,disabled,wa,tanggal_dibuat) VALUES (?,?,?,?,?,?,NOW())");
        $stmt->bind_param('ssssss', $routerId, $username, $password, $profile, $disabled, $noTelp);
        $stmt->execute(); $stmt->close();
    } else {
        // EDIT — update field yang dikirim
        $sets  = ['profile=?','disabled=?','updated_at=NOW()'];
        $vals  = [$profile, $disabled];
        $types = 'ss';
        if ($password) { $sets[] = 'password=?'; $vals[] = $password; $types .= 's'; }
        if ($noTelp)   { $sets[] = 'wa=?';       $vals[] = $noTelp;   $types .= 's'; }
        $vals[] = $username; $types .= 's';
        $sql = "UPDATE users SET " . implode(',', $sets) . " WHERE username = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$vals);
        $stmt->execute(); $stmt->close();
    }

    // Sync ke Mikrotik jika ada konfigurasi
    if ($syncMikrotik) {
        $api = new RouterosAPI();
        $api->port = $routerPort;
        if ($api->connect($routerHost, $routerUser, $routerPass)) {
            $secrets = $api->comm('/ppp/secret/print', ['?name' => $username]);
            if ($action === 'add' && empty($secrets)) {
                $params = ['name' => $username, 'password' => $password, 'profile' => $profile, 'service' => 'pppoe'];
                if ($remoteAddr) $params['remote-address'] = $remoteAddr;
                $api->comm('/ppp/secret/add', $params);
            } elseif (!empty($secrets[0]['.id'])) {
                $params = ['numbers' => $secrets[0]['.id'], 'profile' => $profile];
                if ($password) $params['password'] = $password;
                if ($remoteAddr) $params['remote-address'] = $remoteAddr;
                $api->comm('/ppp/secret/set', $params);
            }
            $api->disconnect();
            (new MikrotikCache($conn))->invalidate("mt_{$routerHost}_{$routerPort}_ppp_secret");
        }
    }

    echo json_encode(['success'=>true,'message'=>'User berhasil ' . ($action === 'add' ? 'ditambahkan' : 'diperbarui')]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success'=>false,'message'=>'Server error: '.$e->getMessage()]);
}
?>
