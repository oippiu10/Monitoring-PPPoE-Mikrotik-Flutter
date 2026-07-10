<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Matikan error reporting di produksi
error_reporting(E_ALL);
ini_set('display_errors', 0);

// ============================================
// KONFIGURASI DATABASE
// ==================== +
// 0
// ====================
require_once __DIR__ . '/config.php';
// Pastikan config.php memiliki objek $conn yang valid


// Menerima input JSON dari aplikasi Flutter
$inputJSON = file_get_contents('php://input');
$input = json_decode($inputJSON, TRUE);

$action       = isset($_GET['action']) ? $_GET['action'] : '';
$license_code = isset($input['license_code']) ? trim($input['license_code']) : (isset($_GET['license_code']) ? trim($_GET['license_code']) : '');
$router_id    = isset($input['router_id'])    ? trim($input['router_id'])    : '';  // ID Asli Mikrotik

if (empty($license_code)) {
    echo json_encode(['status' => false, 'message' => 'invalid_request']);
    exit;
}

$license_code = $conn->real_escape_string($license_code);
$router_id    = $conn->real_escape_string($router_id);

// FITUR EXPORT UNTUK P2P AUTO-SYNC ANTAR SERVER
if ($action === 'export') {
    $q = $conn->query("SELECT license_code, is_active, expired_at FROM app_licenses WHERE license_code = '$license_code' LIMIT 1");
    if ($q->num_rows > 0) {
        echo json_encode(['status' => true, 'data' => $q->fetch_assoc()]);
    } else {
        echo json_encode(['status' => false]);
    }
    exit;
}



// Validasi lisensi ke tabel app_licenses
$query = "SELECT is_active, expired_at FROM app_licenses WHERE license_code = '$license_code' LIMIT 1";
$result = $conn->query($query);

if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    
    // Cek apakah lisensi diblokir
    if ($row['is_active'] == 0) {
        echo json_encode([
            'status' => false,
            'message' => 'blocked'
        ]);
        exit;
    }
    
    // Cek apakah lisensi expired
    $expired_date = strtotime($row['expired_at']);
    $today = strtotime(date('Y-m-d'));
    
    if ($today > $expired_date) {
        echo json_encode([
            'status' => false,
            'message' => 'expired'
        ]);
        exit;
    }
    
    // Lolos semua, valid!
    // Update router_id dan catat waktu terakhir aktif
    $now = date('Y-m-d H:i:s');
    $conn->query("UPDATE app_licenses SET router_id = '$router_id', last_seen = '$now' WHERE license_code = '$license_code'");

    echo json_encode([
        'status'  => true,
        'message' => 'valid'
    ]);
} else {
    // Lisensi tidak ditemukan di DB Lokal. 
    // AUTO-SYNC: Coba tarik dari server partner
    $host = $_SERVER['HTTP_HOST'] ?? '';
    $partner_url = '';
    
    // Tentukan URL partner
    if (strpos($host, 'marzuq') !== false) {
        $partner_url = 'http://cmmnetwork.online/api/check_license.php?action=export&license_code=' . urlencode($license_code);
    } else {
        $partner_url = 'http://billing.marzuqnetwork.online/api2/check_license.php?action=export&license_code=' . urlencode($license_code);
    }
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $partner_url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_TIMEOUT, 3); // Timeout cepat agar tidak lag
    $partner_response = curl_exec($ch);
    curl_close($ch);
    
    $sync_success = false;
    if ($partner_response) {
        $partner_data = json_decode($partner_response, true);
        if (isset($partner_data['status']) && $partner_data['status'] === true && isset($partner_data['data'])) {
            $p_data = $partner_data['data'];
            $p_code = $conn->real_escape_string($p_data['license_code']);
            $p_active = (int)$p_data['is_active'];
            $p_exp = $conn->real_escape_string($p_data['expired_at']);
            
            // Simpan ke DB Lokal (Sync Berhasil)
            $conn->query("INSERT IGNORE INTO app_licenses (license_code, is_active, expired_at, router_id, last_seen) 
                          VALUES ('$p_code', $p_active, '$p_exp', '$router_id', NOW())");
            $sync_success = true;
        }
    }
    
    if ($sync_success) {
        // Ulangi pengecekan setelah disinkron
        if ($p_active == 0) {
            echo json_encode(['status' => false, 'message' => 'blocked']);
            exit;
        }
        if (strtotime(date('Y-m-d')) > strtotime($p_exp)) {
            echo json_encode(['status' => false, 'message' => 'expired']);
            exit;
        }
        echo json_encode(['status' => true, 'message' => 'valid']);
        exit;
    }

    // Jika di partner juga tidak ada, masukkan ke pending
    $conn->query("CREATE TABLE IF NOT EXISTS pending_requests (
        id INT AUTO_INCREMENT PRIMARY KEY,
        license_code VARCHAR(100) NOT NULL,
        router_id VARCHAR(100) DEFAULT NULL,
        attempt_count INT DEFAULT 1,
        first_seen DATETIME DEFAULT NOW(),
        last_seen DATETIME DEFAULT NOW(),
        UNIQUE KEY uq_license (license_code)
    )");
    $conn->query("INSERT INTO pending_requests (license_code, router_id, first_seen, last_seen)
        VALUES ('$license_code', '$router_id', NOW(), NOW())
        ON DUPLICATE KEY UPDATE
            router_id = '$router_id',
            last_seen = NOW(),
            attempt_count = attempt_count + 1");

    echo json_encode([
        'status' => false,
        'message' => 'unregistered'
    ]);
}

$conn->close();
?>
