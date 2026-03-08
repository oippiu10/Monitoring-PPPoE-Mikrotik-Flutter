<?php
/**
 * Auto-Detect dan Merge Semua Router Duplikat
 * 
 * Script ini akan:
 * 1. Mendeteksi semua router ID yang duplikat (format lama: RB-xxx@IP:port)
 * 2. Mencari router ID yang valid (license ID: serial-number atau software-id)
 * 3. Merge semua data dari ID duplikat ke ID yang valid
 * 4. Hapus entry duplikat
 * 
 * Usage:
 * - GET: Lihat preview router yang akan di-merge (dry-run)
 * - POST: Jalankan merge (dengan parameter confirm=true)
 */

ini_set('display_errors', 0);
error_reporting(E_ALL);

// Set error handler
set_error_handler(function($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

// Function untuk return error response
function returnError($error, $httpCode = 500) {
    http_response_code($httpCode);
    header("Content-Type: application/json; charset=UTF-8");
    echo json_encode([
        "success" => false,
        "error" => $error,
        "timestamp" => date('Y-m-d H:i:s')
    ]);
    exit();
}

// Set headers
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    require_once __DIR__ . '/config.php';
    
    if (!isset($conn) || $conn === null) {
        returnError("Database connection failed", 500);
    }
    
    if ($conn->connect_error) {
        returnError("Database connection error: " . $conn->connect_error, 500);
    }
    
    // Fungsi untuk cek apakah router_id adalah format lama (fallback)
    function isLegacyRouterId($routerId) {
        // Format lama: RB-xxx@IP:port atau IP:port
        return preg_match('/^RB-.+@.+:\d+$/', $routerId) || preg_match('/^\d+\.\d+\.\d+\.\d+:\d+$/', $routerId);
    }
    
    // Fungsi untuk cek apakah router_id adalah license ID yang valid
    function isValidLicenseId($routerId) {
        // License ID Mikrotik format: XXXX-XXXX (4 huruf/angka - 4 huruf/angka)
        // Contoh: 03FK-Q7XE, BI5L-CWRV, J81D-TL9Q, HHJH-UFWL
        // Total 8-9 karakter (termasuk dash)
        if (preg_match('/^[A-Z0-9]{4}-[A-Z0-9]{4}$/', $routerId)) {
            return true;
        }
        
        // Fallback: jika tidak mengandung @ atau : dan panjangnya 8-10 karakter
        if (!isLegacyRouterId($routerId) && strlen($routerId) >= 8 && strlen($routerId) <= 10) {
            return true;
        }
        
        return false;
    }
    
    // 1. Ambil semua router_id unik dari database
    $routerQuery = "
        SELECT DISTINCT router_id 
        FROM users 
        WHERE router_id IS NOT NULL AND router_id != ''
        ORDER BY router_id
    ";
    
    $routerResult = $conn->query($routerQuery);
    if (!$routerResult) {
        throw new Exception("Query router_id gagal: " . $conn->error);
    }
    
    $allRouterIds = [];
    while ($row = $routerResult->fetch_assoc()) {
        $allRouterIds[] = $row['router_id'];
    }
    
    // 2. Kelompokkan router berdasarkan username/password yang sama
    // Asumsi: router yang sama akan punya username/password yang sama
    $groupQuery = "
        SELECT 
            router_id,
            username,
            password,
            COUNT(*) as user_count,
            MIN(created_at) as first_seen,
            MAX(updated_at) as last_updated
        FROM users
        WHERE router_id IS NOT NULL AND router_id != ''
        GROUP BY router_id, username, password
        HAVING COUNT(*) > 0
        ORDER BY username, password, router_id
    ";
    
    $groupResult = $conn->query($groupQuery);
    if (!$groupResult) {
        throw new Exception("Query grouping gagal: " . $conn->error);
    }
    
    // Kelompokkan berdasarkan username+password
    $routerGroups = [];
    while ($row = $groupResult->fetch_assoc()) {
        $key = $row['username'] . '|' . $row['password'];
        if (!isset($routerGroups[$key])) {
            $routerGroups[$key] = [];
        }
        $routerGroups[$key][] = $row;
    }
    
    // 3. Identifikasi duplikat dan tentukan router_id yang valid
    $mergeActions = [];
    
    foreach ($routerGroups as $key => $routers) {
        if (count($routers) <= 1) {
            continue; // Tidak ada duplikat
        }
        
        // Cari router_id yang valid (license ID)
        $validRouterId = null;
        $legacyRouterIds = [];
        
        foreach ($routers as $router) {
            if (isValidLicenseId($router['router_id'])) {
                $validRouterId = $router['router_id'];
            } else {
                $legacyRouterIds[] = $router['router_id'];
            }
        }
        
        // Jika tidak ada valid router_id, skip (semua legacy atau semua valid)
        if ($validRouterId === null) {
            // Jika semua legacy, pilih yang pertama sebagai primary
            if (count($legacyRouterIds) > 1) {
                $validRouterId = $legacyRouterIds[0];
                array_shift($legacyRouterIds);
            } else {
                continue;
            }
        }
        
        // Jika ada legacy router_id, tambahkan ke merge actions
        if (!empty($legacyRouterIds)) {
            list($username, $password) = explode('|', $key);
            $mergeActions[] = [
                'username' => $username,
                'password' => $password,
                'valid_router_id' => $validRouterId,
                'legacy_router_ids' => $legacyRouterIds,
                'routers' => $routers
            ];
        }
    }
    
    // 4. Jika GET request, tampilkan preview
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $preview = [];
        foreach ($mergeActions as $action) {
            $preview[] = [
                'username' => $action['username'],
                'valid_router_id' => $action['valid_router_id'],
                'will_merge_from' => $action['legacy_router_ids'],
                'total_legacy_ids' => count($action['legacy_router_ids'])
            ];
        }
        
        echo json_encode([
            'success' => true,
            'mode' => 'preview',
            'total_merge_actions' => count($mergeActions),
            'merge_actions' => $preview,
            'instruction' => 'Kirim POST request dengan body {"confirm": true} untuk menjalankan merge'
        ], JSON_PRETTY_PRINT);
        exit();
    }
    
    // 5. Jika POST request, jalankan merge
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $rawInput = file_get_contents("php://input");
        $data = json_decode($rawInput, true);
        
        if (!isset($data['confirm']) || $data['confirm'] !== true) {
            returnError("Konfirmasi diperlukan. Kirim {\"confirm\": true} untuk melanjutkan", 400);
        }
        
        $conn->begin_transaction();
        
        $totalMerged = 0;
        $totalDeleted = 0;
        $errors = [];
        
        foreach ($mergeActions as $action) {
            $validRouterId = $action['valid_router_id'];
            
            foreach ($action['legacy_router_ids'] as $legacyRouterId) {
                try {
                    // Strategi baru: Hapus entry duplikat langsung
                    // Karena username sudah ada di license ID yang benar
                    
                    // 1. Cari username yang TIDAK ada di valid router_id, lalu UPDATE
                    $updateQuery = "
                        UPDATE users 
                        SET router_id = ?, updated_at = NOW()
                        WHERE router_id = ?
                        AND username NOT IN (
                            SELECT username FROM (
                                SELECT username FROM users WHERE router_id = ?
                            ) AS temp
                        )
                    ";
                    $stmt = $conn->prepare($updateQuery);
                    $stmt->bind_param("sss", $validRouterId, $legacyRouterId, $validRouterId);
                    $stmt->execute();
                    $affected = $stmt->affected_rows;
                    $totalMerged += $affected;
                    $stmt->close();
                    
                    // 2. Hapus entry yang username-nya SUDAH ADA di valid router_id
                    $deleteQuery = "
                        DELETE FROM users
                        WHERE router_id = ?
                        AND username IN (
                            SELECT username FROM (
                                SELECT username FROM users WHERE router_id = ?
                            ) AS temp
                        )
                    ";
                    $stmt = $conn->prepare($deleteQuery);
                    $stmt->bind_param("ss", $legacyRouterId, $validRouterId);
                    $stmt->execute();
                    $deleted = $stmt->affected_rows;
                    $totalDeleted += $deleted;
                    $stmt->close();
                    
                    // 3. Update payments (hanya yang user-nya masih ada)
                    $paymentsQuery = "
                        UPDATE payments p
                        INNER JOIN users u ON p.user_id = u.id
                        SET p.router_id = ?
                        WHERE u.router_id = ?
                    ";
                    $stmt = $conn->prepare($paymentsQuery);
                    $stmt->bind_param("ss", $validRouterId, $validRouterId);
                    $stmt->execute();
                    $stmt->close();
                    
                    // 4. Update ODP
                    $odpQuery = "UPDATE odp SET router_id = ? WHERE router_id = ?";
                    $stmt = $conn->prepare($odpQuery);
                    $stmt->bind_param("ss", $validRouterId, $legacyRouterId);
                    $stmt->execute();
                    $stmt->close();
                    
                } catch (Exception $e) {
                    $errors[] = "Error merge {$legacyRouterId} -> {$validRouterId}: " . $e->getMessage();
                }
            }
        }
        
        $conn->commit();
        
        $result = [
            'success' => true,
            'mode' => 'execute',
            'stats' => [
                'total_merge_actions' => count($mergeActions),
                'users_merged' => $totalMerged,
                'duplicates_deleted' => $totalDeleted
            ]
        ];
        
        if (!empty($errors)) {
            $result['warnings'] = $errors;
        }
        
        echo json_encode($result, JSON_PRETTY_PRINT);
    }
    
} catch (Exception $e) {
    if (isset($conn) && $conn->in_transaction) {
        $conn->rollback();
    }
    error_log("AUTO_MERGE_ERROR: " . $e->getMessage() . " | File: " . $e->getFile() . " | Line: " . $e->getLine());
    returnError("Fatal error: " . $e->getMessage(), 500);
} catch (Error $e) {
    if (isset($conn) && $conn->in_transaction) {
        $conn->rollback();
    }
    error_log("AUTO_MERGE_PHP_ERROR: " . $e->getMessage() . " | File: " . $e->getFile() . " | Line: " . $e->getLine());
    returnError("Fatal PHP error: " . $e->getMessage(), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>
