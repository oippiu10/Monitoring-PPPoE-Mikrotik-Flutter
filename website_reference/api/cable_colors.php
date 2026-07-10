<?php
/**
 * Cable Colors API — CRUD Manajemen Warna Kabel
 */
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/auth/require_auth.php';
require_once __DIR__ . '/auth/activity_log.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$method = $_SERVER['REQUEST_METHOD'];
if ($method !== 'GET') {
    require_admin_role(['admin', 'administrator', 'operator'], 'Akses ditolak. Hanya admin/operator yang boleh mengubah Warna Kabel.');
}

try {
    switch ($method) {
        case 'GET':
            $router_id = $_GET['router_id'] ?? '';
            if (!$router_id) {
                throw new Exception("router_id wajib diisi");
            }

            // Resolve software_id jika numeric ID dikirim
            $stmtR = $conn->prepare("SELECT software_id FROM mikrotik_routers WHERE software_id = ? OR id = ? LIMIT 1");
            $stmtR->bind_param("ss", $router_id, $router_id);
            $stmtR->execute();
            $resR = $stmtR->get_result();
            if ($rowR = $resR->fetch_assoc()) {
                if (!empty($rowR['software_id'])) {
                    $router_id = $rowR['software_id'];
                }
            }
            $stmtR->close();

            $sql = "SELECT * FROM cable_colors WHERE router_id = ? ORDER BY id ASC";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("s", $router_id);
            $stmt->execute();
            $res = $stmt->get_result();
            
            $colors = [];
            while ($row = $res->fetch_assoc()) {
                $colors[] = [
                    'id' => intval($row['id']),
                    'router_id' => $row['router_id'],
                    'name' => $row['name'],
                    'color_code' => $row['color_code'],
                    'created_at' => $row['created_at']
                ];
            }
            $stmt->close();

            if (count($colors) === 0) {
                // Seed standard 12-core fiber colors
                $defaultColors = [
                    ['BIRU', '#0000FF'],
                    ['ORANYE', '#FFA500'],
                    ['HIJAU', '#008000'],
                    ['COKLAT', '#8B4513'],
                    ['ABU', '#808080'],
                    ['PUTIH', '#FFFFFF'],
                    ['MERAH', '#FF0000'],
                    ['HITAM', '#000000'],
                    ['KUNING', '#FFFF00'],
                    ['VIOLET', '#7F00FF'],
                    ['PINK', '#FFC0CB'],
                    ['TOSKA', '#30D5C8']
                ];

                foreach ($defaultColors as $defColor) {
                    $stmtIns = $conn->prepare("INSERT INTO cable_colors (router_id, name, color_code) VALUES (?, ?, ?)");
                    $stmtIns->bind_param("sss", $router_id, $defColor[0], $defColor[1]);
                    $stmtIns->execute();
                    $stmtIns->close();
                }

                // Query again to get populated values
                $stmt = $conn->prepare($sql);
                $stmt->bind_param("s", $router_id);
                $stmt->execute();
                $res = $stmt->get_result();
                $colors = [];
                while ($row = $res->fetch_assoc()) {
                    $colors[] = [
                        'id' => intval($row['id']),
                        'router_id' => $row['router_id'],
                        'name' => $row['name'],
                        'color_code' => $row['color_code'],
                        'created_at' => $row['created_at']
                    ];
                }
                $stmt->close();
            }

            echo json_encode(['success' => true, 'data' => $colors]);
            break;

        case 'POST':
            $input = json_decode(file_get_contents('php://input'), true);
            if (!$input || empty($input['name']) || empty($input['color_code']) || empty($input['router_id'])) {
                throw new Exception("Data tidak lengkap (name, color_code, router_id wajib)");
            }

            $router_id = $input['router_id'];
            // Resolve software_id
            $stmtR = $conn->prepare("SELECT software_id FROM mikrotik_routers WHERE software_id = ? OR id = ? LIMIT 1");
            $stmtR->bind_param("ss", $router_id, $router_id);
            $stmtR->execute();
            $resR = $stmtR->get_result();
            if ($rowR = $resR->fetch_assoc()) {
                if (!empty($rowR['software_id'])) $router_id = $rowR['software_id'];
            }
            $stmtR->close();

            $stmt = $conn->prepare("INSERT INTO cable_colors (router_id, name, color_code) VALUES (?, ?, ?)");
            $stmt->bind_param("sss", 
                $router_id, 
                $input['name'], 
                $input['color_code']
            );
            $stmt->execute();
            $stmt->close();
            log_admin_activity($conn, 'cable_color_create', "Tambah warna kabel: {$input['name']}", (int)($_SESSION['admin_id'] ?? 0));
            echo json_encode(['success' => true, 'id' => $conn->insert_id]);
            break;

        case 'PUT':
            $input = json_decode(file_get_contents('php://input'), true);
            if (!$input || empty($input['id']) || empty($input['name']) || empty($input['color_code'])) {
                throw new Exception("Data tidak lengkap (id, name, color_code wajib)");
            }

            $stmt = $conn->prepare("UPDATE cable_colors SET name = ?, color_code = ? WHERE id = ?");
            $stmt->bind_param("ssi", 
                $input['name'], 
                $input['color_code'], 
                $input['id']
            );
            $stmt->execute();
            $stmt->close();
            log_admin_activity($conn, 'cable_color_update', "Update warna kabel: {$input['name']}", (int)($_SESSION['admin_id'] ?? 0));
            echo json_encode(['success' => true]);
            break;

        case 'DELETE':
            $id = intval($_GET['id'] ?? 0);
            if ($id <= 0) throw new Exception("ID tidak valid");

            // Sebelum menghapus, set cable_color_id menjadi NULL di odc dan odp
            $conn->query("UPDATE odc SET cable_color_id = NULL WHERE cable_color_id = $id");
            $conn->query("UPDATE odp SET cable_color_id = NULL WHERE cable_color_id = $id");

            $stmt = $conn->prepare("DELETE FROM cable_colors WHERE id = ?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            $stmt->close();
            log_admin_activity($conn, 'cable_color_delete', "Hapus warna kabel ID: {$id}", (int)($_SESSION['admin_id'] ?? 0));
            echo json_encode(['success' => true]);
            break;

        default:
            http_response_code(405);
            echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
