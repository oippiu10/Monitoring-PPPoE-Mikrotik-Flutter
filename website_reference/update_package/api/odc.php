<?php
/**
 * ODC API — CRUD Manajemen ODC (Optical Distribution Cabinet)
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
    require_admin_role(['admin', 'administrator', 'operator'], 'Akses ditolak. Hanya admin/operator yang boleh mengubah ODC.');
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

            $sql = "SELECT o.*, c.name AS cable_color_name, c.color_code AS cable_color_code 
                    FROM odc o 
                    LEFT JOIN cable_colors c ON o.cable_color_id = c.id 
                    WHERE o.router_id = ? 
                    ORDER BY o.name ASC";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("s", $router_id);
            $stmt->execute();
            $res = $stmt->get_result();
            
            $odcs = [];
            while ($row = $res->fetch_assoc()) {
                $odcs[] = [
                    'id' => intval($row['id']),
                    'router_id' => $row['router_id'],
                    'name' => $row['name'],
                    'location' => $row['location'],
                    'maps_link' => $row['maps_link'],
                    'lat' => $row['lat'] !== null ? floatval($row['lat']) : null,
                    'lng' => $row['lng'] !== null ? floatval($row['lng']) : null,
                    'capacity' => $row['capacity'] !== null ? intval($row['capacity']) : null,
                    'notes' => $row['notes'],
                    'cable_color_id' => $row['cable_color_id'] !== null ? intval($row['cable_color_id']) : null,
                    'cable_color_name' => $row['cable_color_name'],
                    'cable_color_code' => $row['cable_color_code'],
                    'core_number' => $row['core_number'] !== null ? intval($row['core_number']) : null
                ];
            }
            echo json_encode(['success' => true, 'data' => $odcs]);
            break;
 
        case 'POST':
            $input = json_decode(file_get_contents('php://input'), true);
            if (!$input || empty($input['name']) || empty($input['router_id'])) {
                throw new Exception("Data tidak lengkap (name, router_id wajib)");
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
 
            $stmt = $conn->prepare("INSERT INTO odc (router_id, name, location, maps_link, lat, lng, capacity, notes, cable_color_id, core_number) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $capacity = isset($input['capacity']) ? intval($input['capacity']) : 12;
            $notes = $input['notes'] ?? '';
            $cable_color_id = isset($input['cable_color_id']) && $input['cable_color_id'] !== '' ? intval($input['cable_color_id']) : null;
            $core_number = isset($input['core_number']) && $input['core_number'] !== '' ? intval($input['core_number']) : null;
            $stmt->bind_param("ssssddisii", 
                $router_id, 
                $input['name'], 
                $input['location'], 
                $input['maps_link'],
                $input['lat'],
                $input['lng'],
                $capacity,
                $notes,
                $cable_color_id,
                $core_number
            );
            $stmt->execute();
            log_admin_activity($conn, 'odc_create', "Tambah ODC: {$input['name']}", (int)($_SESSION['admin_id'] ?? 0));
            echo json_encode(['success' => true, 'id' => $conn->insert_id]);
            break;
 
        case 'PUT':
            $input = json_decode(file_get_contents('php://input'), true);
            if (!$input || empty($input['id'])) {
                throw new Exception("ID ODC wajib");
            }
 
            $stmt = $conn->prepare("UPDATE odc SET name=?, location=?, maps_link=?, lat=?, lng=?, capacity=?, notes=?, cable_color_id=?, core_number=? WHERE id=?");
            $capacity = isset($input['capacity']) ? intval($input['capacity']) : 12;
            $notes = $input['notes'] ?? '';
            $cable_color_id = isset($input['cable_color_id']) && $input['cable_color_id'] !== '' ? intval($input['cable_color_id']) : null;
            $core_number = isset($input['core_number']) && $input['core_number'] !== '' ? intval($input['core_number']) : null;
            $stmt->bind_param("sssddisiii", 
                $input['name'], 
                $input['location'], 
                $input['maps_link'], 
                $input['lat'],
                $input['lng'],
                $capacity,
                $notes,
                $cable_color_id,
                $core_number,
                $input['id']
            );
            $stmt->execute();
            log_admin_activity($conn, 'odc_update', "Update ODC: {$input['name']}", (int)($_SESSION['admin_id'] ?? 0));
            echo json_encode(['success' => true]);
            break;

        case 'DELETE':
            $id = intval($_GET['id'] ?? 0);
            if ($id <= 0) throw new Exception("ID tidak valid");

            $stmt = $conn->prepare("DELETE FROM odc WHERE id = ?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            log_admin_activity($conn, 'odc_delete', "Hapus ODC ID: {$id}", (int)($_SESSION['admin_id'] ?? 0));
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
