<?php
/**
 * ODP API — CRUD Manajemen ODP
 */
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/auth/require_auth.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$method = $_SERVER['REQUEST_METHOD'];
if ($method !== 'GET') {
    require_admin_role(['admin', 'administrator', 'operator'], 'Akses ditolak. Hanya admin/operator yang boleh mengubah ODP.');
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

            $sql = "SELECT o.*, 
                           c.name AS cable_color_name, 
                           c.color_code AS cable_color_code,
                           odc.name AS odc_name,
                           parent.name AS parent_odp_name
                    FROM odp o 
                    LEFT JOIN cable_colors c ON o.cable_color_id = c.id 
                    LEFT JOIN odc odc ON o.odc_id = odc.id
                    LEFT JOIN odp parent ON o.parent_id = parent.id
                    WHERE o.router_id = ? 
                    ORDER BY o.name ASC";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("s", $router_id);
            $stmt->execute();
            $res = $stmt->get_result();
            
            $odps = [];
            while ($row = $res->fetch_assoc()) {
                // Hitung jumlah pelanggan di ODP ini (jika odp_id di users menyimpan nama ODP atau ID ODP?)
                // Dari schema users sebelumnya, odp_id adalah int. Jadi dia menyimpan ID ODP.
                $id_odp = $row['id'];
                $uStmt = $conn->prepare("SELECT username, redaman, odp_port FROM users WHERE odp_id = ?");
                $uStmt->bind_param("i", $id_odp);
                $uStmt->execute();
                $uRes = $uStmt->get_result();
                $users_data = [];
                while($uRow = $uRes->fetch_assoc()) {
                    $users_data[] = [
                        'username' => $uRow['username'],
                        'redaman' => $uRow['redaman'] ?: '-',
                        'odp_port' => $uRow['odp_port'] ? intval($uRow['odp_port']) : null
                    ];
                }
                $row['total_users'] = count($users_data);
                $row['users_list'] = $users_data;
                $uStmt->close();

                // Cast variables for JSON integrity
                $row['id'] = intval($row['id']);
                $row['parent_id'] = $row['parent_id'] !== null ? intval($row['parent_id']) : null;
                $row['odc_id'] = $row['odc_id'] !== null ? intval($row['odc_id']) : null;
                $row['cable_color_id'] = $row['cable_color_id'] !== null ? intval($row['cable_color_id']) : null;
                $row['core_number'] = $row['core_number'] !== null ? intval($row['core_number']) : null;
                $row['lat'] = $row['lat'] !== null ? floatval($row['lat']) : null;
                $row['lng'] = $row['lng'] !== null ? floatval($row['lng']) : null;
                $row['ratio_used'] = $row['ratio_used'] !== null ? intval($row['ratio_used']) : 0;
                $row['ratio_total'] = $row['ratio_total'] !== null ? intval($row['ratio_total']) : 8;

                $odps[] = $row;
            }
            echo json_encode(['success' => true, 'data' => $odps]);
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

            $stmt = $conn->prepare("INSERT INTO odp (router_id, name, location, maps_link, lat, lng, type, splitter_type, ratio_used, ratio_total, gpon_type, rx_power, odp_type_flag, parent_id, odc_id, cable_color_id, core_number) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $gpon_type = $input['gpon_type'] ?? 'GPON';
            $rx_power = $input['rx_power'] ?? null;
            $odp_type_flag = $input['odp_type_flag'] ?? 'ratio';
            $parent_id = isset($input['parent_id']) && $input['parent_id'] !== '' ? intval($input['parent_id']) : null;
            $odc_id = isset($input['odc_id']) && $input['odc_id'] !== '' ? intval($input['odc_id']) : null;
            $cable_color_id = isset($input['cable_color_id']) && $input['cable_color_id'] !== '' ? intval($input['cable_color_id']) : null;
            $core_number = isset($input['core_number']) && $input['core_number'] !== '' ? intval($input['core_number']) : null;
            $stmt->bind_param("ssssddssiisssiiii", 
                $router_id, 
                $input['name'], 
                $input['location'], 
                $input['maps_link'],
                $input['lat'],
                $input['lng'],
                $input['type'], 
                $input['splitter_type'], 
                $input['ratio_used'], 
                $input['ratio_total'],
                $gpon_type,
                $rx_power,
                $odp_type_flag,
                $parent_id,
                $odc_id,
                $cable_color_id,
                $core_number
            );
            $stmt->execute();
            echo json_encode(['success' => true, 'id' => $conn->insert_id]);
            break;

        case 'PUT':
            $input = json_decode(file_get_contents('php://input'), true);
            if (!$input || empty($input['id'])) {
                throw new Exception("ID ODP wajib");
            }

            $stmt = $conn->prepare("UPDATE odp SET name=?, location=?, maps_link=?, lat=?, lng=?, type=?, splitter_type=?, ratio_used=?, ratio_total=?, gpon_type=?, rx_power=?, odp_type_flag=?, parent_id=?, odc_id=?, cable_color_id=?, core_number=? WHERE id=?");
            $gpon_type = $input['gpon_type'] ?? 'GPON';
            $rx_power = $input['rx_power'] ?? null;
            $odp_type_flag = $input['odp_type_flag'] ?? 'ratio';
            $parent_id = isset($input['parent_id']) && $input['parent_id'] !== '' ? intval($input['parent_id']) : null;
            $odc_id = isset($input['odc_id']) && $input['odc_id'] !== '' ? intval($input['odc_id']) : null;
            $cable_color_id = isset($input['cable_color_id']) && $input['cable_color_id'] !== '' ? intval($input['cable_color_id']) : null;
            $core_number = isset($input['core_number']) && $input['core_number'] !== '' ? intval($input['core_number']) : null;
            $stmt->bind_param("sssddssiisssiiiii", 
                $input['name'], 
                $input['location'], 
                $input['maps_link'], 
                $input['lat'],
                $input['lng'],
                $input['type'], 
                $input['splitter_type'], 
                $input['ratio_used'], 
                $input['ratio_total'],
                $gpon_type,
                $rx_power,
                $odp_type_flag,
                $parent_id,
                $odc_id,
                $cable_color_id,
                $core_number,
                $input['id']
            );
            $stmt->execute();
            echo json_encode(['success' => true]);
            break;

        case 'DELETE':
            $id = intval($_GET['id'] ?? 0);
            if ($id <= 0) throw new Exception("ID tidak valid");

            $stmt = $conn->prepare("DELETE FROM odp WHERE id = ?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
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
